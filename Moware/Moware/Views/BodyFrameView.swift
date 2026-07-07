import SwiftUI

/// Renders the combined BodyFrame — the rolling latest-value snapshot
/// assembled from both Nexus cores — refreshed on `assembler`'s own 10ms
/// cadence, independent of either device's BLE arrival timing.
struct BodyFrameView: View {
    let assembler: BodyFrameAssembler

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Body Frame (combined, 10ms)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(assembler.latestSnapshot, id: \.sourceIndex) { packet in
                SourceCard(sample: packet, detail: "t: \(packet.alignedTimestamp)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .task {
            await assembler.startEmissionLoop()
        }
    }
}
