import Foundation

/// Common IMU readout fields, shared by `RawIMUSample` and `BodySourcePacket`
/// so display code (e.g. the source card view) can work with either.
protocol IMUReadable {
    var sourceIndex: UInt8 { get }
    var quatI: Double { get }
    var quatJ: Double { get }
    var quatK: Double { get }
    var quatReal: Double { get }
    var accelX: Double { get }
    var accelY: Double { get }
    var accelZ: Double { get }
    var gravityX: Double { get }
    var gravityY: Double { get }
    var gravityZ: Double { get }
}

extension RawIMUSample: IMUReadable {}

/// A single source's IMU reading resolved out of a `SourceTimeStreamFrame`,
/// with its absolute timestamp computed and the per-packet framing (frame
/// index, relative offset) dropped since it's no longer needed once resolved.
struct BodySourcePacket: IMUReadable, Sendable, Equatable {
    let sourceIndex: UInt8
    /// Raw device timestamp, straight off the firmware — a free-running
    /// counter since THAT device's own boot. Not comparable across the two
    /// cores; kept around for diagnostics.
    let rawTimestamp: UInt32
    /// `rawTimestamp` shifted by a per-device offset calibrated against the
    /// phone's own monotonic clock, so values from both cores can be
    /// compared/sorted meaningfully. See `BodyFrameAssembler`.
    let alignedTimestamp: Int64

    let quatI: Double
    let quatJ: Double
    let quatK: Double
    let quatReal: Double

    let accelX: Double
    let accelY: Double
    let accelZ: Double

    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double

    init(sample: RawIMUSample, rawTimestamp: UInt32, alignedTimestamp: Int64) {
        sourceIndex = sample.sourceIndex
        self.rawTimestamp = rawTimestamp
        self.alignedTimestamp = alignedTimestamp
        quatI = sample.quatI
        quatJ = sample.quatJ
        quatK = sample.quatK
        quatReal = sample.quatReal
        accelX = sample.accelX
        accelY = sample.accelY
        accelZ = sample.accelZ
        gravityX = sample.gravityX
        gravityY = sample.gravityY
        gravityZ = sample.gravityZ
    }
}
