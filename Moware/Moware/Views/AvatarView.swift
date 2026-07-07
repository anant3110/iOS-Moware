import SceneKit
import SwiftUI

/// Displays the loaded avatar and drives its pose live from the combined
/// BodyFrame snapshot. Reads `assembler.latestSnapshot` (already emitted on
/// its own ~10ms cadence by whichever view keeps `startEmissionLoop()`
/// running) — does NOT start its own emission loop, to avoid a second
/// redundant loop instance running against the same shared assembler.
struct AvatarView: View {
    let assembler: BodyFrameAssembler

    @State private var avatarModel = AvatarModel()
    @State private var poseDriver = AvatarPoseDriver()

    var body: some View {
        VStack(spacing: 8) {
            if let avatarModel {
                SceneView(
                    scene: avatarModel.scene,
                    pointOfView: avatarModel.cameraNode,
                    options: [.autoenablesDefaultLighting, .allowsCameraControl]
                )
                .frame(height: 400)
                .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: assembler.latestSnapshot) { _, snapshot in
                    poseDriver.apply(snapshot, to: avatarModel.jointNodes)
                }

                Button("Calibrate (stand in T-pose)") {
                    poseDriver.calibrate(
                        from: assembler.latestSnapshot,
                        bindPoseGlobal: avatarModel.bindPoseGlobalOrientations
                    )
                }
                .buttonStyle(.borderedProminent)

                if !poseDriver.isCalibrated {
                    Text("Not calibrated yet — pose will not track until you calibrate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "Avatar not loaded",
                    systemImage: "figure.stand",
                    description: Text("Check that the .glb asset is bundled correctly.")
                )
            }
        }
        .padding()
    }
}
