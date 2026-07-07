import CoreBluetooth

/// GATT layout for the Nexus core peripheral firmware (Zephyr/nRF Connect SDK).
enum NexusProtocol {
    static let serviceUUID = CBUUID(string: "EA902000-9196-4499-8E9F-0BAA5772AEC1")
    static let requestCharacteristicUUID = CBUUID(string: "EA902001-9196-4499-8E9F-0BAA5772AEC1")
    static let responseCharacteristicUUID = CBUUID(string: "EA902002-9196-4499-8E9F-0BAA5772AEC1")

    static let advertisedNamePrefix = "UltraCore"
}

/// Mirrors the firmware's `core_mode_t` opcode values, written to the
/// request characteristic to control the peripheral's mode.
enum CoreModeOpcode: UInt8 {
    case null = 0x00
    case calibration = 0x01
    case stream = 0x02
    case sync = 0x03
    /// Aligns the peripheral's local clock with a global/central time reference.
    /// OPEN ITEM: payload beyond the opcode byte is unconfirmed.
    case epoch = 0x99
    /// OPEN ITEM: payload beyond the opcode byte is unconfirmed.
    case setSession = 0xB0

    /// First build sends the opcode byte alone for every case.
    var payload: Data { Data([rawValue]) }
}
