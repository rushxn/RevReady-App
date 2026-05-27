import SwiftUI
import UIKit
import CoreBluetooth

struct SensorsView: View {
    @StateObject private var obd = OBD2Manager()
    @State private var isDemoMode = false
    @State private var demoTimer: Timer? = nil
    @State private var animate = false
    @State private var selectedTab = 0  // 0=Gauges, 1=Faults
    @State private var latchedFaults: [Fault] = []  // stays until cleared

    // Demo values
    @State private var demoRPM: Int = 0
    @State private var demoCoolant: Int = 0
    @State private var demoThrottle: Double = 0
    @State private var demoBattery: Double = 0
    @State private var demoOilTemp: Int = 0
    @State private var demoEngineHrs: Double = 47.3

    var isLive: Bool { obd.connectionState == .connected }
    var isConnecting: Bool {
        obd.connectionState == .scanning ||
        obd.connectionState == .connecting ||
        obd.connectionState == .initializing
    }

    // Current sensor values (real or demo)
    var currentRPM: Int       { isDemoMode ? demoRPM       : obd.rpm }
    var currentCoolant: Int   { isDemoMode ? demoCoolant   : obd.coolantTemp }
    var currentOilTemp: Int   { isDemoMode ? demoOilTemp   : obd.oilTemp }
    var currentBattery: Double{ isDemoMode ? demoBattery   : obd.batteryVoltage }
    var currentThrottle: Double{ isDemoMode ? demoThrottle : obd.throttlePosition }
    var currentEngHrs: Double { isDemoMode ? demoEngineHrs : Double(obd.engineSeconds) / 3600.0 }

    var liveFaults: [Fault] {
        guard isDemoMode || isLive else { return [] }
        return FaultAnalyzer.analyze(
            rpm: currentRPM, coolant: currentCoolant,
            oilTemp: currentOilTemp, battery: currentBattery,
            throttle: currentThrottle, engineHours: currentEngHrs
        )
    }

    // Faults shown in UI — latched so they don't flicker away
    var faults: [Fault] { latchedFaults.isEmpty ? liveFaults : latchedFaults }

    var healthScore: Int { FaultAnalyzer.healthScore(faults: faults) }
    var criticalCount: Int { faults.filter { $0.severity == .critical }.count }
    var warningCount:  Int { faults.filter { $0.severity == .warning  }.count }

    func latchNewFaults() {
        let live = liveFaults
        for f in live {
            if !latchedFaults.contains(where: { $0.code == f.code }) {
                latchedFaults.append(f)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isDemoMode || isLive {
                connectedContent
            } else {
                unpairedView
            }
        }
        .background(Color.motoBg.ignoresSafeArea())
        .onDisappear { stopDemo(); obd.disconnect() }
        .onChange(of: obd.rpm) { _, _ in latchNewFaults() }
        .onChange(of: demoRPM) { _, _ in latchNewFaults() }
    }

    // MARK: Header
    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Live Sensors")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Circle()
                        .fill(isDemoMode ? Color(hex: "#f59e0b") : obd.connectionState.color)
                        .frame(width: 7, height: 7)
                    Text(isDemoMode ? "Demo — 2020 CRF250R" : obd.statusMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.motoMuted)
                }
            }
            Spacer()
            if isDemoMode || isLive {
                // Health score badge
                HStack(spacing: 6) {
                    Text("\(healthScore)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(healthScore >= 80 ? Color(hex: "#4ade80") :
                                         healthScore >= 50 ? Color(hex: "#f59e0b") : Color(hex: "#ef4444"))
                    Text("health")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.motoMuted)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.motoCard).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.motoBorder, lineWidth: 1))
                .padding(.trailing, 8)

                Button { isDemoMode ? stopDemo() : obd.disconnect() } label: {
                    Text(isDemoMode ? "Stop" : "Disconnect")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.motoMuted)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.motoCard).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.motoBorder, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
    }

    // MARK: Debug tab
    var debugTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("BLE DEBUG LOG")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.motoMuted)
                    Spacer()
                    Button { obd.debugLog = [] } label: {
                        Text("Clear")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.motoOrange)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 8)
                if obd.debugLog.isEmpty {
                    Text("No logs yet — connect to adapter")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.motoMuted)
                        .padding(.horizontal, 16)
                } else {
                    ForEach(obd.debugLog.indices, id: \.self) { i in
                        Text(obd.debugLog[i])
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(
                                obd.debugLog[i].contains("←") ? Color(hex: "#4ade80") :
                                obd.debugLog[i].contains("→") ? Color(hex: "#f59e0b") :
                                obd.debugLog[i].contains("⚠️") ? Color(hex: "#ef4444") :
                                .motoText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.vertical, 1)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: Connected content (gauges + faults)
    var connectedContent: some View {
        VStack(spacing: 0) {
            // Fault alert bar — only shows if faults exist
            if !faults.isEmpty {
                faultAlertBar
            }

            // Tab switcher
            HStack(spacing: 0) {
                tabBtn("Gauges", idx: 0, icon: "speedometer")
                tabBtn("Faults (\(faults.count))", idx: 1, icon: faults.isEmpty ? "checkmark.shield" : "exclamationmark.triangle.fill")
                tabBtn("Debug", idx: 2, icon: "terminal")
            }
            .padding(.horizontal, 16).padding(.bottom, 10)

            if selectedTab == 0 {
                gaugesTab
            } else if selectedTab == 1 {
                faultsTab
            } else {
                debugTab
            }
        }
    }

    func tabBtn(_ label: String, idx: Int, icon: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = idx } } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .foregroundColor(selectedTab == idx ? .white : .motoMuted)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(selectedTab == idx ? Color.motoOrange : Color.motoCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Fault alert bar
    var faultAlertBar: some View {
        HStack(spacing: 10) {
            if criticalCount > 0 {
                alertPill("\(criticalCount) Critical", Color(hex: "#ef4444"))
            }
            if warningCount > 0 {
                alertPill("\(warningCount) Warning", Color(hex: "#f59e0b"))
            }
            Spacer()
            Button { selectedTab = 1 } label: {
                Text("View Faults →")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(criticalCount > 0 ? Color(hex: "#ef4444") : Color(hex: "#f59e0b"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(criticalCount > 0 ? Color(hex: "#1a0808") : Color(hex: "#1a1200"))
        .overlay(Rectangle()
            .fill(criticalCount > 0 ? Color(hex: "#ef4444") : Color(hex: "#f59e0b"))
            .frame(height: 2), alignment: .top)
        .padding(.bottom, 8)
    }

    func alertPill(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1)).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: Gauges tab
    var gaugesTab: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                GaugeCard(icon: "speedometer", label: "ENGINE RPM",
                          value: currentRPM > 0 ? "\(currentRPM)" : "—", unit: "rpm",
                          fill: Double(currentRPM) / 13500,
                          barColor: .motoOrange, animate: animate)
                GaugeCard(icon: "thermometer.medium", label: "COOLANT",
                          value: currentCoolant > 0 ? "\(currentCoolant)" : "—", unit: "°C",
                          fill: Double(max(currentCoolant - 20, 0)) / 90,
                          barColor: Color(hex: "#f48c06"), animate: animate,
                          isWarning: currentCoolant >= 100)
                GaugeCard(icon: "battery.75", label: "BATTERY",
                          value: currentBattery > 0 ? String(format: "%.1f", currentBattery) : "—", unit: "V",
                          fill: max(0, (currentBattery - 11.5) / 3.3),
                          barColor: Color(hex: "#4ade80"), animate: animate,
                          isWarning: currentBattery <= 12.2)
                GaugeCard(icon: "gauge.with.needle", label: "THROTTLE",
                          value: String(format: "%.0f", currentThrottle), unit: "%",
                          fill: currentThrottle / 100,
                          barColor: Color(hex: "#a78bfa"), animate: animate)
                GaugeCard(icon: "thermometer.sun", label: "OIL TEMP",
                          value: currentOilTemp > 0 ? "\(currentOilTemp)" : "—", unit: "°C",
                          fill: Double(max(currentOilTemp - 20, 0)) / 110,
                          barColor: Color(hex: "#ef4444"), animate: animate,
                          isWarning: currentOilTemp >= 120)
                GaugeCard(icon: "timer", label: "ENGINE HRS",
                          value: String(format: "%.1f", currentEngHrs), unit: "hrs",
                          fill: min(currentEngHrs / 100, 1.0),
                          barColor: Color(hex: "#3b82f6"), animate: animate)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { animate = true } }
    }

    // MARK: Faults tab
    var faultsTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !latchedFaults.isEmpty {
                    Button { latchedFaults = [] } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash").font(.system(size: 12))
                            Text("Clear All Faults")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.motoMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.motoCard).cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.motoBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                if faults.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 40)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48)).foregroundColor(Color(hex: "#4ade80"))
                        Text("No faults detected")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("All sensor readings are within\nnormal operating range.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.motoMuted)
                            .multilineTextAlignment(.center).lineSpacing(4)
                    }.frame(maxWidth: .infinity)
                } else {
                    ForEach(faults) { fault in
                        FaultCard(fault: fault)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 32)
        }
    }

    // MARK: Unpaired view
    var unpairedView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 12)
                ZStack {
                    Circle().fill(Color.motoCard).frame(width: 90, height: 90)
                        .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
                    if isConnecting {
                        ProgressView().tint(.motoOrange).scaleEffect(1.4)
                    } else {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 34)).foregroundColor(.motoMuted)
                    }
                }
                VStack(spacing: 6) {
                    Text(isConnecting ? obd.statusMessage : "No device connected")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    if !isConnecting {
                        Text("Run obd_emulator.py on your Mac\nthen tap Scan below.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.motoMuted)
                            .multilineTextAlignment(.center).lineSpacing(4)
                    }
                }
                if !isConnecting {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SETUP").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                        instructionRow("1", "pip3 install pyobjc-framework-CoreBluetooth")
                        instructionRow("2", "python3 obd_emulator.py")
                        instructionRow("3", "Tap Scan — select Rushan's MacBook")
                    }
                    .padding(14).background(Color.motoCard).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                }
                if !obd.discoveredDevices.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FOUND DEVICES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.motoMuted)
                        ForEach(obd.discoveredDevices, id: \.identifier) { device in
                            let displayName = obd.deviceNames[device.identifier] ?? device.name ?? "Unknown"
                            Button { obd.connect(to: device) } label: {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .foregroundColor(.motoOrange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayName)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text("Tap to connect as OBD2 adapter")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.motoOrange)
                                    }
                                    Spacer()
                                    Text("Connect →")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(.motoOrange)
                                }
                                .padding(12).background(Color.motoCard).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.motoOrange.opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 16)
                }
                VStack(spacing: 10) {
                    Button {
                        if isConnecting { obd.disconnect() } else { obd.startScan() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isConnecting ? "stop.circle" : "antenna.radiowaves.left.and.right")
                                .font(.system(size: 16, weight: .bold))
                            Text(isConnecting ? "Stop Scanning" : "Scan for Adapter")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(isConnecting ? Color(hex: "#ef4444") : Color.motoOrange)
                        .cornerRadius(14)
                    }
                    Button { startDemo() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle").font(.system(size: 16, weight: .bold))
                            Text("Preview Demo Mode")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.motoMuted)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.motoCard).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                    }
                }.padding(.horizontal, 16).padding(.bottom, 40)
            }
        }
    }

    // MARK: Demo logic
    func startDemo() {
        isDemoMode = true; animate = false
        withAnimation(.easeOut(duration: 0.9)) { animate = true }
        demoRPM = 1420; demoCoolant = 28; demoThrottle = 8
        demoBattery = 13.1; demoOilTemp = 25; demoEngineHrs = 47.3
        var tick = 0
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            tick += 1
            let c = tick % 60
            let t: Double = c<10 ? 8 : c<16 ? 45 : c<28 ? 72 : c<32 ? 95 : c<40 ? 55 : c<46 ? 20 : 8
            self.demoThrottle += (t - self.demoThrottle) * 0.3 + Double.random(in: -2...2)
            self.demoThrottle = max(5, min(100, self.demoThrottle))
            let tr = self.demoThrottle < 12 ? 1420 : Int(5800 + self.demoThrottle * 75)
            self.demoRPM += Int(Double(tr - self.demoRPM) * 0.25) + Int.random(in: -60...60)
            self.demoRPM = max(1380, min(13500, self.demoRPM))
            let wt = 88.0 + Double(self.demoRPM) / 13500.0 * 8
            if self.demoCoolant < Int(wt) { self.demoCoolant += 1 }
            self.demoCoolant += Int.random(in: -1...1)
            self.demoCoolant = max(20, min(108, self.demoCoolant))
            let ot = self.demoCoolant + 8 + Int(Double(self.demoRPM) / 13500.0 * 12)
            self.demoOilTemp += (ot - self.demoOilTemp) > 0 ? 1 : -1
            self.demoOilTemp = max(20, min(130, self.demoOilTemp))
            self.demoBattery += Double.random(in: -0.05...0.08)
            self.demoBattery = max(12.0, min(14.8, self.demoBattery))
            self.demoEngineHrs += 0.5 / 3600
        }
    }

    func stopDemo() {
        demoTimer?.invalidate(); demoTimer = nil
        isDemoMode = false; animate = false
        demoRPM = 0; demoCoolant = 0; demoThrottle = 0; demoBattery = 0; demoOilTemp = 0
    }

    func instructionRow(_ num: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(num).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundColor(.white)
                .frame(width: 22, height: 22).background(Color.motoOrange).clipShape(Circle())
            Text(text).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoText)
            Spacer()
        }
    }
}

// MARK: - Fault Card
struct FaultCard: View {
    let fault: Fault
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Tappable header ──
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(fault.severity.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: fault.severity.icon)
                        .font(.system(size: 20))
                        .foregroundColor(fault.severity.color)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(fault.code)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(fault.severity.color)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(fault.severity.color.opacity(0.12))
                            .cornerRadius(6)
                        Text(fault.diyCategory.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(fault.diyCategory.color)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(fault.diyCategory.color.opacity(0.12))
                            .cornerRadius(6)
                    }
                    Text(fault.title)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("\(fault.sensor): \(fault.sensorValue)  ·  \(fault.estimatedTime)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.motoMuted)
                }
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.motoOrange)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
            }

            // ── Expanded detail ──
            if expanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider().background(Color.motoBorder)

                    // Symptom
                    VStack(alignment: .leading, spacing: 5) {
                        Label("SYMPTOM", systemImage: "eye")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.motoMuted)
                        Text(fault.symptom)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.motoText).lineSpacing(3)
                    }

                    // Cause
                    VStack(alignment: .leading, spacing: 5) {
                        Label("PROBABLE CAUSE", systemImage: "wrench.adjustable")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.motoMuted)
                        Text(fault.cause)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.motoText).lineSpacing(3)
                    }

                    // Action
                    VStack(alignment: .leading, spacing: 5) {
                        Label("ACTION", systemImage: "arrow.right.circle.fill")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(fault.severity.color)
                        Text(fault.action)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white).lineSpacing(3)
                    }
                    .padding(12)
                    .background(fault.severity.color.opacity(0.07))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(fault.severity.color.opacity(0.2), lineWidth: 1))

                    // DIY section
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Label(fault.diyCategory.rawValue.uppercased(),
                                  systemImage: fault.diyCategory.icon)
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(fault.diyCategory.color)
                            Spacer()
                            Text(fault.partsCost)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.motoMuted)
                        }

                        // Tools
                        if !fault.toolsNeeded.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TOOLS NEEDED")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.motoMuted)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                                    ForEach(fault.toolsNeeded, id: \.self) { tool in
                                        HStack(spacing: 5) {
                                            Circle().fill(fault.diyCategory.color).frame(width: 5, height: 5)
                                            Text(tool)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.motoText)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }

                        // Steps
                        if !fault.diySteps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("STEPS")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.motoMuted)
                                ForEach(Array(fault.diySteps.enumerated()), id: \.offset) { i, step in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("\(i+1)")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                            .frame(width: 20, height: 20)
                                            .background(fault.diyCategory.color.opacity(0.25))
                                            .clipShape(Circle())
                                        Text(step)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.motoText).lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(fault.diyCategory.color.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(fault.diyCategory.color.opacity(0.2), lineWidth: 1))

                    // YouTube button
                    if let url = fault.youtubeURL {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5).fill(Color(hex: "#ef4444"))
                                    .frame(width: 30, height: 22)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white)
                            }
                            Text("Watch repair tutorial on YouTube")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12)).foregroundColor(.motoMuted)
                        }
                        .padding(12)
                        .background(Color(hex: "#ef4444").opacity(0.08))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#ef4444").opacity(0.25), lineWidth: 1))
                        .contentShape(Rectangle())
                        .onTapGesture { UIApplication.shared.open(url) }
                    }

                    // Parts price comparison
                    if !fault.partsSources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PARTS PRICE COMPARISON")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.motoMuted)
                            ForEach(fault.partsSources) { source in
                                if let url = source.searchURL {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(source.store)
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(source.storeColor)
                                            Text(source.partName)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.motoMuted)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text(source.estimatedPrice)
                                            .font(.system(size: 13, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 10)).foregroundColor(.motoDim)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 9)
                                    .background(Color.motoBg)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.motoBorder, lineWidth: 1))
                                    .contentShape(Rectangle())
                                    .onTapGesture { UIApplication.shared.open(url) }
                                }
                            }
                            Text("* Prices estimated. Tap to search live listings.")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.motoDim)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
        .background(Color.motoCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(expanded ? fault.severity.color.opacity(0.5) : Color.motoBorder, lineWidth: 1))
    }
}
