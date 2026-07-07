import Foundation
import GLTFKit2
import SceneKit
import simd

/// Loads the bundled Mixamo-rigged glTF/GLB avatar once and converts it to a
/// SceneKit scene, then resolves the confirmed source -> joint-name mapping
/// into actual SCNNodes for fast per-frame mutation.
///
/// Uses GLTFKit2 (SPM dependency), not Apple's Model I/O: Model I/O's glTF
/// importer does not actually recognize either the binary `.glb` container
/// or the JSON `.gltf` variant by extension in practice (confirmed via a
/// runtime "unknown extension" error for both) — despite being commonly
/// assumed to support glTF 2.0. GLTFKit2 is a mature, widely-used glTF 2.0
/// loader (built on Khronos's own `cgltf`) with a first-class SceneKit
/// bridge (`SCNScene(gltfAsset:)`), so it loads the original `.glb` directly.
@MainActor
final class AvatarModel {
    private static let resourceName = "TweekModel"
    private static let resourceExtension = "glb"

    let scene: SCNScene
    /// glTF exports carry no camera of their own and land at wildly
    /// different scales/positions depending on the tool that made them, so
    /// SceneKit's fallback default camera usually doesn't frame the model at
    /// all. This camera is positioned from the loaded rig's actual bounding
    /// box so the avatar is always in view regardless of its native units.
    let cameraNode: SCNNode
    /// Only contains entries for joint names that were actually found in the
    /// loaded rig — sources whose mapped joint name wasn't found are simply
    /// absent here (see the warning printed at load time), not a crash.
    private(set) var jointNodes: [UInt8: SCNNode] = [:]
    /// Each mapped joint's world-space orientation in the rig's rest/bind
    /// pose, captured once at load time before any pose driving happens.
    /// Needed by `AvatarPoseDriver`'s calibration math (mirrors
    /// `bindPoseGlobal` in the reference `index.html` implementation).
    private(set) var bindPoseGlobalOrientations: [UInt8: simd_quatf] = [:]

    /// Returns nil (rather than trapping) if the resource is missing or
    /// fails to parse — this is the sole truly-unrecoverable case; a joint
    /// name not resolving is not fatal (see below).
    init?() {
        guard let url = Bundle.main.url(
            forResource: Self.resourceName,
            withExtension: Self.resourceExtension
        ) else {
            print("AvatarModel: no \(Self.resourceName).\(Self.resourceExtension) found in bundle.")
            return nil
        }

        let asset: GLTFAsset
        do {
            asset = try GLTFAsset(url: url, options: [:])
        } catch {
            print("AvatarModel: failed to parse glTF asset: \(error)")
            return nil
        }

        let loadedScene = SCNScene(gltfAsset: asset)
        scene = loadedScene

        let (minBound, maxBound) = loadedScene.rootNode.boundingBox
        let center = SCNVector3(
            (minBound.x + maxBound.x) / 2,
            (minBound.y + maxBound.y) / 2,
            (minBound.z + maxBound.z) / 2
        )
        let extent = SCNVector3(
            maxBound.x - minBound.x,
            maxBound.y - minBound.y,
            maxBound.z - minBound.z
        )
        let maxDimension = max(extent.x, max(extent.y, extent.z))
        let distance = maxDimension > 0 ? maxDimension * 1.5 : 3

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(center.x, center.y, center.z + distance)
        camera.look(at: center)
        loadedScene.rootNode.addChildNode(camera)
        cameraNode = camera

        for (source, jointName) in AvatarJointMapping.sourceToJointName {
            guard let node = loadedScene.rootNode.childNode(
                withName: jointName,
                recursively: true
            ) else {
                print("AvatarModel: joint '\(jointName)' (source \(source)) not found in rig.")
                continue
            }
            jointNodes[source] = node
            bindPoseGlobalOrientations[source] = node.simdWorldOrientation
        }
    }
}
