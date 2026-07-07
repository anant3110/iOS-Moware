import Foundation

/// Combines IMU samples arriving from both Nexus cores (Lower and Upper)
/// into one logical BodyFrame, keyed by the firmware's globally-unique
/// source byte. Acts as a rolling latest-value cache — a new packet for a
/// source overwrites the old one, never cleared/reset — snapshotted onto
/// `latestSnapshot` on a fixed cadence decoupled from BLE arrival timing.
@MainActor
@Observable
final class BodyFrameAssembler {
    /// Descriptive expectation (10 sources across both cores combined), not
    /// an enforced invariant.
    static let expectedSourceCount = 10

    private(set) var latestSnapshot: [BodySourcePacket] = []
    private var cache: [UInt8: BodySourcePacket] = [:]
    private var hasWarnedExcessSources = false

    /// Per-device (peripheral identifier) offset added to that device's raw
    /// timestamps to align them to the phone's monotonic clock. Each core's
    /// `timestamp` free-runs since ITS OWN boot, so the two cores' raw values
    /// have no shared origin — this offset is what actually fixes the
    /// "one core's timestamps lag the other's" symptom. Captured once from
    /// the first frame received after each (re)connect (see
    /// `resetCalibration(for:)`), assuming the firmware's tick unit is ~1ms;
    /// this is a first-order correction for clock origin, not for any slow
    /// drift between the two independent oscillators.
    private var clockOffsetByDevice: [UUID: Int64] = [:]

    func ingest(_ frame: SourceTimeStreamFrame, deviceID: UUID) {
        let offset = clockOffsetByDevice[deviceID] ?? {
            let nowMs = Int64(ProcessInfo.processInfo.systemUptime * 1000)
            let calibrated = nowMs - Int64(frame.baseTimestamp)
            clockOffsetByDevice[deviceID] = calibrated
            return calibrated
        }()

        for (index, sample) in frame.samples.enumerated() {
            let rawTimestamp = frame.absoluteTimestamp(forSampleAt: index)
            let alignedTimestamp = Int64(rawTimestamp) + offset
            cache[sample.sourceIndex] = BodySourcePacket(
                sample: sample,
                rawTimestamp: rawTimestamp,
                alignedTimestamp: alignedTimestamp
            )
        }

        // OPEN ITEM: the firmware's global source-numbering scheme (which
        // bytes Lower vs. Upper emit, totaling exactly 10 disjoint values)
        // is asserted but unverified against real hardware. This is a soft
        // tripwire, not a crash, in case that assumption is wrong.
        if cache.count > Self.expectedSourceCount, !hasWarnedExcessSources {
            hasWarnedExcessSources = true
            print("""
                BodyFrameAssembler: observed \(cache.count) unique source indices, \
                more than the expected \(Self.expectedSourceCount). Verify the \
                firmware's global source-numbering scheme.
                """)
        }
    }

    /// Call when a device (re)connects so its clock is recalibrated from
    /// scratch — a real power-cycle would reset its raw counter, making a
    /// previously-cached offset wrong.
    func resetCalibration(for deviceID: UUID) {
        clockOffsetByDevice[deviceID] = nil
    }

    func startEmissionLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(10))
            latestSnapshot = cache.values.sorted { $0.sourceIndex < $1.sourceIndex }
        }
    }
}
