import CoreBluetooth
import Foundation

/// Owns the CoreBluetooth central lifecycle for both Nexus core peripherals:
/// scan -> connect -> discover services/characteristics -> subscribe ->
/// request streaming -> decode notifications -> publish per-peripheral state.
@MainActor
@Observable
final class NexusCentralManager: NSObject {
    private var central: CBCentralManager!
    private(set) var bluetoothState: CBManagerState = .unknown
    private(set) var devices: [UUID: CoreDeviceState] = [:]

    private var peripherals: [UUID: CBPeripheral] = [:]
    private var requestCharacteristics: [UUID: CBCharacteristic] = [:]

    var orderedDevices: [CoreDeviceState] {
        devices.values.sorted { $0.displayName < $1.displayName }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard central.state == .poweredOn else { return }
        // Scanning with a service-UUID filter would miss this peripheral: a
        // 128-bit custom service UUID doesn't fit in the legacy 31-byte
        // advertising packet alongside the full local name, so the firmware
        // only advertises the name. Filter by name prefix instead.
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        central.stopScan()
    }
}

extension NexusCentralManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier

        if let existing = devices[id] {
            existing.rssi = RSSI.intValue
            return
        }

        guard devices.count < NexusProtocol.maxConnectedPeripherals else { return }

        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Unknown"

        guard name.hasPrefix(NexusProtocol.advertisedNamePrefix) else { return }

        let device = CoreDeviceState(id: id, displayName: name)
        device.rssi = RSSI.intValue
        devices[id] = device
        peripherals[id] = peripheral
        peripheral.delegate = self

        device.phase = .connecting
        central.connect(peripheral, options: nil)

        if devices.count == NexusProtocol.maxConnectedPeripherals {
            stopScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = devices[peripheral.identifier] else { return }
        device.phase = .discoveringServices
        peripheral.discoverServices([NexusProtocol.serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard let device = devices[peripheral.identifier] else { return }
        device.lastError = error?.localizedDescription
        device.phase = .disconnected
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard let device = devices[peripheral.identifier] else { return }
        device.phase = .disconnected
        device.lastError = error?.localizedDescription
        central.connect(peripheral, options: nil)
    }
}

extension NexusCentralManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let device = devices[peripheral.identifier] else { return }
        if let error {
            device.lastError = error.localizedDescription
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == NexusProtocol.serviceUUID }) else {
            return
        }
        device.phase = .discoveringCharacteristics
        peripheral.discoverCharacteristics(
            [NexusProtocol.requestCharacteristicUUID, NexusProtocol.responseCharacteristicUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let device = devices[peripheral.identifier] else { return }
        if let error {
            device.lastError = error.localizedDescription
            return
        }
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics where characteristic.uuid == NexusProtocol.requestCharacteristicUUID {
            requestCharacteristics[peripheral.identifier] = characteristic
        }

        guard let responseCharacteristic = characteristics.first(where: {
            $0.uuid == NexusProtocol.responseCharacteristicUUID
        }) else {
            return
        }

        device.phase = .subscribing
        peripheral.setNotifyValue(true, for: responseCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let device = devices[peripheral.identifier] else { return }
        guard characteristic.uuid == NexusProtocol.responseCharacteristicUUID else { return }

        if let error {
            device.lastError = error.localizedDescription
            return
        }
        guard characteristic.isNotifying,
              let requestCharacteristic = requestCharacteristics[peripheral.identifier] else {
            return
        }

        device.phase = .requestingStream
        peripheral.writeValue(CoreModeOpcode.stream.payload, for: requestCharacteristic, type: .withResponse)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let device = devices[peripheral.identifier] else { return }
        guard characteristic.uuid == NexusProtocol.requestCharacteristicUUID else { return }

        if let error {
            device.lastError = error.localizedDescription
            return
        }
        device.phase = .streaming
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let device = devices[peripheral.identifier] else { return }
        guard characteristic.uuid == NexusProtocol.responseCharacteristicUUID else { return }

        if let error {
            device.lastError = error.localizedDescription
            return
        }
        guard let data = characteristic.value else { return }

        do {
            device.apply(try TelemetryFrameDecoder.decode(data))
        } catch {
            device.lastError = "\(error)"
        }
    }
}
