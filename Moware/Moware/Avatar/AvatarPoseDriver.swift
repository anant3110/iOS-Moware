import Foundation
import SceneKit
import simd

/// Converts live IMU quaternions into joint-local rotations relative to a
/// user-triggered calibration pose (typically standing in the rig's bind
/// T-pose). Ports the gravity-corrected calibration algorithm from the
/// companion Android/Three.js implementation (`index.html`, at the project
/// root) — see `processCalibrationFrame`/`updateMotionFrame` there — with
/// one deliberate deviation: that implementation's calibration-time
/// correction is NOT a full conjugation (an intermediate `Q_g * sensorQuat`
/// product is computed and then silently discarded before the real
/// assignment, apparently a leftover from iterating on the formula), while
/// its runtime correction IS a full conjugation. That asymmetry means
/// calibrating and then immediately re-applying the same sensor reading
/// does NOT reproduce bind pose — confirmed both algebraically and by a
/// visible pose jump the instant Calibrate was tapped. Using a full
/// conjugation in both places (below) fixes this: it makes calibrating with
/// a given reading and then applying that same reading exactly reproduce
/// bind pose, as intended.
@MainActor
final class AvatarPoseDriver {
    /// "calibrationPacket" in the reference implementation: maps a
    /// gravity-corrected live sensor quaternion straight to the joint's
    /// world-space orientation.
    private var calibrationOffsets: [UInt8: simd_quatf] = [:]
    /// "Q_g" in the reference implementation: the gravity-to-up alignment
    /// captured at calibration time and reused (not recomputed) every frame.
    private var gravityAlignments: [UInt8: simd_quatf] = [:]

    var isCalibrated: Bool { !calibrationOffsets.isEmpty }

    /// Call while the user is standing in the avatar's neutral/bind pose.
    /// Only captures offsets for sources present in `snapshot` right now —
    /// does NOT require all 10 (a core may be disconnected).
    func calibrate(from snapshot: [BodySourcePacket], bindPoseGlobal: [UInt8: simd_quatf]) {
        for packet in snapshot {
            guard let restOrientation = bindPoseGlobal[packet.sourceIndex] else { continue }

            let sensorQuat = Self.remappedQuaternion(packet)

            let remappedGravity = AvatarSensorRemap.gravity(
                x: Float(packet.gravityX), y: Float(packet.gravityY), z: Float(packet.gravityZ),
                source: packet.sourceIndex
            )
            let gravityDirection = simd_normalize(remappedGravity)
            let gravityAlignment = Self.rotation(from: SIMD3<Float>(0, 1, 0), to: gravityDirection)

            // Full conjugation, matching `apply`'s runtime correction (see
            // the class doc comment for why this differs from the
            // reference implementation).
            let tPoseCorrected = (gravityAlignment * sensorQuat) * gravityAlignment.inverse
            let calibrationOffset = restOrientation * tPoseCorrected.inverse

            calibrationOffsets[packet.sourceIndex] = calibrationOffset
            gravityAlignments[packet.sourceIndex] = gravityAlignment
        }
    }

    /// Computes each mapped joint's target WORLD orientation, then converts
    /// it to that joint's LOCAL orientation relative to its parent — unlike
    /// the reference implementation, which copies the world-space target
    /// straight into each bone's local `.quaternion` (its own
    /// parent-relative conversion function, `applyGlobalQuaternionToBone`,
    /// is defined but never actually called in its live code path). Skipping
    /// that conversion only produces correct results for a bone with no
    /// parent; for every other joint it silently drops/double-counts the
    /// parent's own bind rotation, which is what caused the reported "snaps
    /// into a completely different yaw" symptom. Parent orientations are all
    /// captured before any node in this batch is mutated (matching this
    /// codebase's own `parentWorldQuats` pre-capture idea), so a child's
    /// conversion basis doesn't depend on iteration order within the batch.
    func apply(_ snapshot: [BodySourcePacket], to jointNodes: [UInt8: SCNNode]) {
        var parentWorldOrientations: [UInt8: simd_quatf] = [:]
        for packet in snapshot {
            guard let node = jointNodes[packet.sourceIndex] else { continue }
            parentWorldOrientations[packet.sourceIndex] = node.parent?.simdWorldOrientation
                ?? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }

        for packet in snapshot {
            guard let node = jointNodes[packet.sourceIndex],
                  let calibrationOffset = calibrationOffsets[packet.sourceIndex],
                  let gravityAlignment = gravityAlignments[packet.sourceIndex],
                  let parentWorldOrientation = parentWorldOrientations[packet.sourceIndex] else { continue }

            let streamingQuat = Self.remappedQuaternion(packet)

            // Full conjugation here (unlike calibration above) — matches
            // the reference implementation's runtime path exactly.
            let streamingCorrected = (gravityAlignment * streamingQuat) * gravityAlignment.inverse
            let globalOrientation = calibrationOffset * streamingCorrected

            node.simdOrientation = parentWorldOrientation.inverse * globalOrientation
        }
    }

    private static func remappedQuaternion(_ packet: BodySourcePacket) -> simd_quatf {
        let remapped = AvatarSensorRemap.quaternion(
            i: Float(packet.quatI), j: Float(packet.quatJ), k: Float(packet.quatK), real: Float(packet.quatReal),
            source: packet.sourceIndex
        )
        return simd_quatf(ix: remapped.x, iy: remapped.y, iz: remapped.z, r: remapped.w).normalized
    }

    /// Shortest-arc rotation taking unit vector `a` to unit vector `b`,
    /// matching Three.js's `Quaternion.setFromUnitVectors`.
    private static func rotation(from a: SIMD3<Float>, to b: SIMD3<Float>) -> simd_quatf {
        let dot = simd_dot(a, b)
        if dot > 0.999_999 {
            return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        if dot < -0.999_999 {
            var axis = simd_cross(SIMD3<Float>(1, 0, 0), a)
            if simd_length(axis) < 1e-6 {
                axis = simd_cross(SIMD3<Float>(0, 1, 0), a)
            }
            return simd_quatf(angle: .pi, axis: simd_normalize(axis))
        }
        let axis = simd_normalize(simd_cross(a, b))
        return simd_quatf(angle: acos(dot), axis: axis)
    }
}
