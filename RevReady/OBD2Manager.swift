import Foundation
import CoreBluetooth
import SwiftUI

class OBD2Manager: NSObject, ObservableObject {

    // MARK: Published sensor values
    @Published var rpm: Int = 0
    @Published var coolantTemp: Int = 0
    @Published var throttlePosition: Double = 0
    @Published var batteryVoltage: Double = 0
    @Published var oilTemp: Int = 0
    @Published var engineSeconds: Int = 0

    // MARK: Debug log — visible in app
    @Published var debugLog: [String] = []

    // MARK: Connection state
    @Published var connectionState: ConnectionState = .disconnected
    @Published var statusMessage: String = "Ready to scan"
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var deviceNames: [UUID: String] = [:]

    enum ConnectionState {
        case disconnected, scanning, connecting, initializing, connected, error
        var label: String {
            switch self {
            case .disconnected:  return "Not connected"
            case .scanning:      return "Scanning…"
            case .connecting:    return "Connecting…"
            case .initializing:  return "Initializing adapter…"
            case .connected:     return "Connected · Live data"
            case .error:         return "Connection error"
            }
        }
        var color: Color {
            switch self {
            case .connected:     return Color(hex: "#4ade80")
            case .scanning, .connecting, .initializing: return Color(hex: "#f59e0b")
            case .error:         return Color(hex: "#ef4444")
            case .disconnected:  return Color(hex: "#555555")
            }
        }
    }

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    // Universal setup — works on any OBD2 vehicle (cars + EFI bikes)
    // ATSP0 = auto-detect protocol (tries all protocols)
    // ATST FF = maximum timeout so slow ECUs have time to respond
    // ATAT1 = adaptive timing mode 1
    private let setupCommands = ["ATZ", "ATE0", "ATH0", "ATL0", "ATS0", "ATAT1", "ATST FF", "ATSP0"]
    private var setupIndex = 0

    private var pollTimer: Timer?
    private let pidQueue: [String] = ["010C", "0105", "0111", "0142", "015C", "011F"]
    private var pidIndex = 0
    private var responseBuffer = ""

    private func log(_ msg: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        DispatchQueue.main.async {
            self.debugLog.insert("[\(time)] \(msg)", at: 0)
            if self.debugLog.count > 50 { self.debugLog = Array(self.debugLog.prefix(50)) }
        }
        print("[OBD2] \(msg)")
    }

    override init() { super.init() }

    private func ensureCentralManager() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        }
    }

    func startScan() {
        ensureCentralManager()
        if centralManager?.state != .poweredOn {
            statusMessage = "Waiting for Bluetooth…"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.startScan() }
            return
        }
        discoveredDevices = []
        deviceNames = [:]
        connectionState = .scanning
        statusMessage = "Scanning…"
        log("Scan started")
        centralManager?.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self, self.connectionState == .scanning else { return }
            self.centralManager?.stopScan()
            self.connectionState = .disconnected
            self.statusMessage = "No adapters found"
            self.log("Scan timed out")
        }
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager?.stopScan()
        connectionState = .connecting
        statusMessage = "Connecting…"
        connectedPeripheral = peripheral
        log("Connecting to \(peripheral.name ?? peripheral.identifier.uuidString)")
        centralManager?.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let p = connectedPeripheral { centralManager?.cancelPeripheralConnection(p) }
        pollTimer?.invalidate(); pollTimer = nil
        reset()
        log("Disconnected")
    }

    private func reset() {
        rpm = 0; coolantTemp = 0; throttlePosition = 0
        batteryVoltage = 0; oilTemp = 0; engineSeconds = 0
        writeCharacteristic = nil; notifyCharacteristic = nil
        connectedPeripheral = nil; setupIndex = 0; pidIndex = 0
        responseBuffer = ""
        connectionState = .disconnected
        statusMessage = "Disconnected"
    }

    private func runSetupSequence() {
        connectionState = .initializing
        statusMessage = "Initializing adapter…"
        setupIndex = 0
        log("Starting setup sequence in 2s")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.sendNextSetupCommand()
        }
    }

    private func sendNextSetupCommand() {
        guard setupIndex < setupCommands.count else {
            log("Setup complete — starting polling")
            startPolling()
            return
        }
        let cmd = setupCommands[setupIndex]
        log("→ \(cmd)")
        sendCommand(cmd)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.setupIndex += 1
            self?.sendNextSetupCommand()
        }
    }

    private func startPolling() {
        connectionState = .connected
        statusMessage = "Connected · Live data"
        log("Polling started")
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollNextPID()
        }
    }

    private func pollNextPID() {
        let pid = pidQueue[pidIndex % pidQueue.count]
        pidIndex += 1
        sendCommand(pid)
    }

    private func sendCommand(_ cmd: String) {
        guard let char = writeCharacteristic,
              let data = (cmd + "\r").data(using: .utf8) else {
            log("⚠️ sendCommand failed — no write char")
            return
        }
        if char.properties.contains(.writeWithoutResponse) {
            connectedPeripheral?.writeValue(data, for: char, type: .withoutResponse)
        } else {
            connectedPeripheral?.writeValue(data, for: char, type: .withResponse)
        }
    }

    private func parseResponse(_ raw: String) {
        let clean = raw
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard !clean.isEmpty else { return }
        log("← \(clean)")

        // Skip AT command echoes and status messages
        let skip = ["OK", "ELM", "ATZ", "ATE", "ATH", "ATS", "ATL", "ATSP",
                    "NO DATA", "UNABLE", "BUS", "ERROR", "STOPPED", "SEARCHING"]
        if skip.contains(where: { clean.uppercased().contains($0) }) { return }
        if clean.contains("?") { return }

        // Try to parse each line separately
        let lines = clean.components(separatedBy: " ").filter { !$0.isEmpty }

        // Look for "41 XX ..." pattern anywhere in the response
        for i in 0..<lines.count {
            guard lines[i] == "41", i + 1 < lines.count else { continue }
            let pidStr = lines[i + 1]
            guard let pid = UInt8(pidStr, radix: 16) else { continue }
            let dataBytes = lines[(i+2)...].compactMap { UInt8($0, radix: 16) }

            switch pid {
            case 0x0C:
                if dataBytes.count >= 2 {
                    rpm = (Int(dataBytes[0]) * 256 + Int(dataBytes[1])) / 4
                    log("RPM = \(rpm)")
                }
            case 0x05:
                if !dataBytes.isEmpty {
                    coolantTemp = Int(dataBytes[0]) - 40
                    log("Coolant = \(coolantTemp)°C")
                }
            case 0x11:
                if !dataBytes.isEmpty {
                    throttlePosition = Double(dataBytes[0]) * 100.0 / 255.0
                    log("Throttle = \(Int(throttlePosition))%")
                }
            case 0x42:
                if dataBytes.count >= 2 {
                    batteryVoltage = Double(Int(dataBytes[0]) * 256 + Int(dataBytes[1])) / 1000.0
                    log("Battery = \(String(format: "%.1f", batteryVoltage))V")
                }
            case 0x5C:
                if !dataBytes.isEmpty {
                    oilTemp = Int(dataBytes[0]) - 40
                    log("Oil = \(oilTemp)°C")
                }
            case 0x1F:
                if dataBytes.count >= 2 {
                    engineSeconds = Int(dataBytes[0]) * 256 + Int(dataBytes[1])
                    log("EngineSeconds = \(engineSeconds)")
                }
            default:
                break
            }
            break
        }
    }

    var engineHoursFormatted: String {
        String(format: "%.1f", Double(engineSeconds) / 3600.0)
    }
}

// MARK: - CBCentralManagerDelegate
extension OBD2Manager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
            log("Bluetooth ON")
        case .poweredOff:
            statusMessage = "Bluetooth is off"
            connectionState = .error
            log("Bluetooth OFF")
        case .unauthorized:
            statusMessage = "Bluetooth permission denied"
            connectionState = .error
            log("Bluetooth unauthorized")
        default:
            log("Bluetooth state: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? ""
        let label = name.isEmpty ? "Unknown (\(peripheral.identifier.uuidString.prefix(8)))" : name
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredDevices.append(peripheral)
            deviceNames[peripheral.identifier] = label
            statusMessage = "Found: \(label)"
            log("Found: \(label)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        statusMessage = "Discovering services…"
        log("Connected — discovering services")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        pollTimer?.invalidate(); pollTimer = nil
        reset()
        log("Peripheral disconnected: \(error?.localizedDescription ?? "none")")
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .error
        statusMessage = "Failed to connect"
        log("Failed: \(error?.localizedDescription ?? "unknown")")
    }
}

// MARK: - CBPeripheralDelegate
extension OBD2Manager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let err = error { log("Service discovery error: \(err)"); return }
        let services = peripheral.services?.map { $0.uuid.uuidString } ?? []
        log("Services: \(services.joined(separator: ", "))")
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let err = error { log("Char discovery error: \(err)"); return }
        service.characteristics?.forEach { char in
            log("Char: \(char.uuid) props: \(char.properties.rawValue)")
            if (char.properties.contains(.notify) || char.properties.contains(.indicate)),
               notifyCharacteristic == nil {
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
                log("✓ Notify char: \(char.uuid)")
            }
            if (char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse)),
               writeCharacteristic == nil {
                writeCharacteristic = char
                log("✓ Write char: \(char.uuid)")
            }
        }
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            log("Both chars found — running setup")
            runSetupSequence()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error { log("Value error: \(err)"); return }
        guard let data = characteristic.value else { log("nil data received"); return }

        // Try UTF-8 first, then latin1
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? data.map { String(format: "%02X", $0) }.joined(separator: " ")

        responseBuffer += text
        // Parse when we get a prompt or newline
        if responseBuffer.contains(">") || responseBuffer.contains("\r") {
            let toProcess = responseBuffer
            responseBuffer = ""
            parseResponse(toProcess)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let err = error { log("Write error: \(err)") }
    }
}
