import Foundation

enum CoreConnectionPhase: Equatable {
    case discovered
    case connecting
    case discoveringServices
    case discoveringCharacteristics
    case subscribing
    case requestingStream
    case streaming
    case disconnected
}

/// Per-peripheral state, keyed by `CBPeripheral.identifier`. Kept around
/// across disconnects (not removed) so its UI panel doesn't disappear.
@Observable
final class CoreDeviceState: Identifiable {
    let id: UUID
    var displayName: String
    var phase: CoreConnectionPhase = .discovered
    var lastError: String?
    var latestFrame: SourceTimeStreamFrame?
    /// Latest sample per physical IMU source index, so the UI can render one
    /// stable card per source rather than reshuffling with each packet.
    private(set) var latestSampleBySource: [UInt8: RawIMUSample] = [:]
    /// Rolling packets/sec per source, computed from a 1-second sliding window.
    private(set) var packetRateBySource: [UInt8: Double] = [:]
    var framesReceived: Int = 0
    var rssi: Int?

    private var receiveTimestampsBySource: [UInt8: [Date]] = [:]

    init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    func apply(_ frame: SourceTimeStreamFrame) {
        latestFrame = frame
        let now = Date()
        let windowStart = now.addingTimeInterval(-1)

        for sample in frame.samples {
            latestSampleBySource[sample.sourceIndex] = sample

            var timestamps = receiveTimestampsBySource[sample.sourceIndex] ?? []
            timestamps.append(now)
            timestamps.removeAll { $0 < windowStart }
            receiveTimestampsBySource[sample.sourceIndex] = timestamps
            packetRateBySource[sample.sourceIndex] = Double(timestamps.count)
        }

        framesReceived += 1
    }
}
