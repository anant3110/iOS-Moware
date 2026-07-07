import Foundation

/// Per-source axis remapping for the raw IMU quaternion/gravity readings,
/// ported verbatim from the validated `parseQuaternion`/`parseGravity`
/// functions in the companion Android/Three.js implementation
/// (`index.html`, at the project root). These corrections encode each
/// sensor's physical mounting orientation and were derived empirically —
/// do not "simplify" or re-derive them from first principles.
enum AvatarSensorRemap {
    /// Input/output order is (i, j, k, real) i.e. (x, y, z, w).
    static func quaternion(i: Float, j: Float, k: Float, real: Float, source: UInt8) -> SIMD4<Float> {
        switch source {
        case 0, 1: SIMD4(-j, -k, -i, -real)
        case 5, 6: SIMD4(k, j, -i, real)
        case 7, 8: SIMD4(-k, j, i, real)
        default: SIMD4(i, j, k, real)
        }
    }

    static func gravity(x: Float, y: Float, z: Float, source: UInt8) -> SIMD3<Float> {
        switch source {
        case 0, 1: SIMD3(-y, -z, -x)
        case 5, 6: SIMD3(z, y, -x)
        case 7, 8: SIMD3(-z, y, x)
        default: SIMD3(x, y, z)
        }
    }
}
