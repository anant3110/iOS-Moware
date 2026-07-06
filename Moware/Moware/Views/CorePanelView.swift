import SwiftUI

struct CorePanelView: View {
    let device: CoreDeviceState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(phaseColor)
                    .frame(width: 10, height: 10)
                Text(device.displayName)
                    .font(.headline)
                Spacer()
                Text("\(device.framesReceived) frames")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(phaseDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(device.latestSampleBySource.keys.sorted(), id: \.self) { sourceIndex in
                if let sample = device.latestSampleBySource[sourceIndex] {
                    SourceCard(sample: sample, packetsPerSecond: device.packetRateBySource[sourceIndex] ?? 0)
                }
            }

            if let error = device.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var phaseColor: Color {
        switch device.phase {
        case .streaming: .green
        case .disconnected: .red
        default: .yellow
        }
    }

    private var phaseDescription: String {
        switch device.phase {
        case .discovered: "Discovered"
        case .connecting: "Connecting…"
        case .discoveringServices: "Discovering services…"
        case .discoveringCharacteristics: "Discovering characteristics…"
        case .subscribing: "Subscribing…"
        case .requestingStream: "Requesting stream…"
        case .streaming: "Streaming"
        case .disconnected: "Disconnected"
        }
    }
}

private struct SourceCard: View {
    let sample: RawIMUSample
    let packetsPerSecond: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Source \(sample.sourceIndex)")
                    .font(.caption.bold())
                Spacer()
                Text(String(format: "%.0f pkt/s", packetsPerSecond))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "quat  i: %+.3f  j: %+.3f  k: %+.3f  w: %+.3f",
                        sample.quatI, sample.quatJ, sample.quatK, sample.quatReal))
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(String(format: "accel x: %+.2f  y: %+.2f  z: %+.2f",
                        sample.accelX, sample.accelY, sample.accelZ))
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(String(format: "grav  x: %+.2f  y: %+.2f  z: %+.2f",
                        sample.gravityX, sample.gravityY, sample.gravityZ))
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }
}

extension CorePanelView {
    static var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 10, height: 10)
            Text("Waiting for core…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
