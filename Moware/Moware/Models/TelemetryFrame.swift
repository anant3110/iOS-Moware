import Foundation

/// One decoded IMU sample from a single physical sensor chip, one of 15
/// aggregated inside a `SourceTimeStreamFrame` packet.
struct RawIMUSample: Sendable {
    let frameIndex: Int
    /// OPEN ITEM: unit (ms vs ticks) relative to `baseTimestamp` is unconfirmed.
    let timeOffset: UInt8
    /// Index of the physical IMU chip that produced this frame.
    let sourceIndex: UInt8

    let quatI: Double
    let quatJ: Double
    let quatK: Double
    let quatReal: Double

    /// Linear acceleration (m/s^2, excludes gravity), from the BNO08x's
    /// `BNO_getLinAccel{X,Y,Z}`.
    let accelX: Double
    let accelY: Double
    let accelZ: Double

    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double
}

/// One decoded 229-byte notification from the Nexus response characteristic,
/// aggregating 15 I2C frames.
struct SourceTimeStreamFrame: Sendable {
    /// uint32, big-endian, timestamp of the first of the 15 I2C frames.
    let baseTimestamp: UInt32
    let samples: [RawIMUSample]

    /// ASSUMES `timeOffset` shares `baseTimestamp`'s unit — unverified.
    func absoluteTimestamp(forSampleAt index: Int) -> UInt32 {
        baseTimestamp &+ UInt32(samples[index].timeOffset)
    }
}
