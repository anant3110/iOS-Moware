import Foundation

/// Maps a BLE source index (0...9, globally unique across both Nexus cores)
/// to the Mixamo bone name it drives on the loaded avatar rig.
/// Confirmed mapping — do not reorder/relabel without re-confirming against
/// the physical sensor layout.
///
/// This particular export uses the colon-prefixed `mixamorig:` naming
/// convention (confirmed by dumping TweekModel.glb's embedded node list —
/// the un-prefixed `mixamorigRightArm` form some Mixamo pipelines produce
/// does not exist in this file).
enum AvatarJointMapping {
    static let sourceToJointName: [UInt8: String] = [
        0: "mixamorig:RightArm",
        1: "mixamorig:RightForeArm",
        2: "mixamorig:LeftArm",
        3: "mixamorig:LeftForeArm",
        4: "mixamorig:Spine2",
        5: "mixamorig:RightUpLeg",
        6: "mixamorig:RightLeg",
        7: "mixamorig:LeftUpLeg",
        8: "mixamorig:LeftLeg",
        9: "mixamorig:Hips",
    ]
}
