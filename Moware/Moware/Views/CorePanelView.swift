import SwiftUI

struct CorePanelView: View {
    let device: CoreDeviceState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(device.latestSampleBySource.keys.sorted(), id: \.self) { sourceIndex in
                if let sample = device.latestSampleBySource[sourceIndex] {
                    SourceCard(
                        sample: sample,
                        detail: String(format: "%.0f pkt/s", device.packetRateBySource[sourceIndex] ?? 0)
                    )
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
}

struct SourceCard: View {
    let sample: any IMUReadable
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Source \(sample.sourceIndex)")
                    .font(.caption.bold())
                Spacer()
                Text(detail)
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
