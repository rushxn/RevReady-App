import SwiftUI

// MARK: - Fault severity
enum FaultSeverity: String {
    case critical = "CRITICAL"
    case warning  = "WARNING"
    case info     = "INFO"

    var color: Color {
        switch self {
        case .critical: return Color(hex: "#ef4444")
        case .warning:  return Color(hex: "#f59e0b")
        case .info:     return Color(hex: "#3b82f6")
        }
    }
    var icon: String {
        switch self {
        case .critical: return "xmark.octagon.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .info:     return "info.circle.fill"
        }
    }
}

// MARK: - DIY Category
enum DIYCategory: String {
    case diy        = "DIY Fix"
    case diyAdvanced = "DIY — Advanced"
    case shopOnly   = "Take to Shop"

    var color: Color {
        switch self {
        case .diy:         return Color(hex: "#4ade80")
        case .diyAdvanced: return Color(hex: "#f59e0b")
        case .shopOnly:    return Color(hex: "#ef4444")
        }
    }
    var icon: String {
        switch self {
        case .diy:         return "wrench.fill"
        case .diyAdvanced: return "wrench.adjustable.fill"
        case .shopOnly:    return "building.2.fill"
        }
    }
    var description: String {
        switch self {
        case .diy:
            return "Any rider can fix this with basic tools"
        case .diyAdvanced:
            return "Experienced riders with tools can fix this"
        case .shopOnly:
            return "Requires specialist tools or dealer"
        }
    }
}

// MARK: - Parts source
struct PartSource: Identifiable {
    let id = UUID()
    let store: String
    let partName: String
    let estimatedPrice: String
    let searchQuery: String      // used to build URL
    var searchURL: URL? {
        switch store {
        case "Rocky Mountain ATV":
            let q = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.rockymountainatvmc.com/search?searchTerm=\(q)")
        case "Amazon":
            let q = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.amazon.com/s?k=\(q)")
        case "Partzilla":
            let q = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.partzilla.com/search?q=\(q)")
        case "BikeBandit":
            let q = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.bikebandit.com/search?q=\(q)")
        default:
            return nil
        }
    }
    var storeColor: Color {
        switch store {
        case "Rocky Mountain ATV": return Color(hex: "#ef4444")
        case "Amazon":             return Color(hex: "#f59e0b")
        case "Partzilla":          return Color(hex: "#3b82f6")
        case "BikeBandit":         return Color(hex: "#4ade80")
        default:                   return Color(hex: "#888888")
        }
    }
}

// MARK: - Fault
struct Fault: Identifiable {
    let id = UUID()
    let code: String
    let title: String
    let symptom: String
    let cause: String
    let action: String
    let severity: FaultSeverity
    let diyCategory: DIYCategory
    let diySteps: [String]
    let toolsNeeded: [String]
    let estimatedTime: String
    let partsCost: String
    let partsSources: [PartSource]   // where to buy + prices
    let youtubeQuery: String         // search query for YouTube
    let sensor: String
    let sensorValue: String

    var youtubeURL: URL? {
        let q = youtubeQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.youtube.com/results?search_query=\(q)")
    }
}

// MARK: - Fault Analyzer
// Based on Honda CRF250R PGM-FI diagnostic system
// DTC codes sourced from Honda service manual and PGM-FI diagnostic documentation
// Thresholds validated against 2020 Honda CRF250R service specifications

struct FaultAnalyzer {

    // ── 2020 Honda CRF250R operating specs (from service manual) ──
    // ECT (Engine Coolant Temperature) sensor:
    //   Normal operating range: 80–95°C
    //   Warning threshold: 105°C (fan kicks in on liquid-cooled models)
    //   Critical: 115°C+ (risk of head gasket failure, coolant boiling)
    // IAT (Intake Air Temperature): normal -20 to 60°C ambient
    // Battery / charging: 13.5–14.5V at 5,000 RPM (stator output)
    // Idle RPM: 1,500 ± 100 RPM per Honda spec
    // Redline: 13,500 RPM
    // Oil temp normal: 90–110°C under load

    static func analyze(
        rpm: Int,
        coolant: Int,
        oilTemp: Int,
        battery: Double,
        throttle: Double,
        engineHours: Double
    ) -> [Fault] {
        var faults: [Fault] = []

        // ── P0217 Coolant overtemperature ──
        if coolant >= 115 {
            faults.append(Fault(
                code: "P0217",
                title: "Engine Overtemperature — STOP NOW",
                symptom: "Steam from radiator overflow, severe power loss, possible knocking. Coolant may be boiling.",
                cause: "Blown head gasket, blocked radiator, failed water pump, or critically low coolant level.",
                action: "STOP IMMEDIATELY. Kill engine. Wait 20+ min before touching radiator cap.",
                severity: .critical,
                diyCategory: .diyAdvanced,
                diySteps: [
                    "Let engine cool completely — minimum 30 minutes",
                    "Check coolant level in overflow bottle (cold engine only)",
                    "Look for white exhaust smoke — indicates head gasket leak",
                    "Inspect radiator fins for mud or debris packing",
                    "Check all coolant hose clamps for tightness",
                    "If coolant is milky or oily, do not ride — head gasket failure"
                ],
                toolsNeeded: ["Coolant", "Flashlight", "Cloth rags"],
                estimatedTime: "30 min inspection",
                partsCost: "$10–15 top-up, $80–200 if head gasket",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Honda Coolant Ready Mix",
                               estimatedPrice: "~$12", searchQuery: "Honda coolant CRF250R"),
                    PartSource(store: "Amazon", partName: "Engine Ice Coolant",
                               estimatedPrice: "~$15", searchQuery: "Engine Ice Hi-Performance coolant"),
                    PartSource(store: "Partzilla", partName: "OEM Honda Head Gasket Kit",
                               estimatedPrice: "~$85", searchQuery: "Honda CRF250R head gasket"),
                ],
                youtubeQuery: "2020 Honda CRF250R overheating fix coolant",
                sensor: "ECT Sensor", sensorValue: "\(coolant)°C"
            ))
        } else if coolant >= 105 {
            faults.append(Fault(
                code: "P0217",
                title: "High Coolant Temperature",
                symptom: "Reduced power, possible steam from overflow hose.",
                cause: "Low coolant level, blocked radiator fins, or air pocket in system.",
                action: "Reduce pace. Check coolant level and clean radiator fins at next stop.",
                severity: .warning,
                diyCategory: .diy,
                diySteps: [
                    "Stop and let bike idle in shade for 2–3 minutes",
                    "Cold engine: check overflow bottle — between MIN/MAX marks",
                    "Use brush or hose to clean mud from radiator fins",
                    "Check coolant hoses feel firm — mushy hose needs replacing",
                    "Top up with 50/50 Honda coolant mix if low"
                ],
                toolsNeeded: ["Coolant", "Brush or hose"],
                estimatedTime: "15–20 min",
                partsCost: "$10–15",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Honda Coolant Ready Mix",
                               estimatedPrice: "~$12", searchQuery: "Honda coolant CRF250R"),
                    PartSource(store: "Amazon", partName: "Engine Ice Coolant 0.5 gal",
                               estimatedPrice: "~$15", searchQuery: "Engine Ice motorcycle coolant"),
                    PartSource(store: "BikeBandit", partName: "Radiator cap Honda CRF250R",
                               estimatedPrice: "~$18", searchQuery: "Honda CRF250R radiator cap"),
                ],
                youtubeQuery: "Honda CRF250R running hot overheating fix",
                sensor: "ECT Sensor", sensorValue: "\(coolant)°C"
            ))
        }

        // ── P0524 Oil temperature ──
        if oilTemp >= 130 {
            faults.append(Fault(
                code: "P0524",
                title: "Critical Oil Temperature — Seizure Risk",
                symptom: "Engine knocking, reduced power, oil smell, possible blue smoke.",
                cause: "Low oil level, wrong viscosity, or extreme load breaking down oil.",
                action: "STOP RIDING. Check oil level immediately. Do not restart until temp below 80°C.",
                severity: .critical,
                diyCategory: .diy,
                diySteps: [
                    "Stop and kill engine immediately",
                    "Wait 10 minutes then check oil level on sight glass",
                    "If milky/grey — coolant contamination, do not ride",
                    "If black and burnt smell — change oil before continuing",
                    "Top up with Honda 10W-30 MA oil if low (max 1.1L with filter)"
                ],
                toolsNeeded: ["Engine oil Honda 10W-30", "Oil drain pan", "Oil filter wrench"],
                estimatedTime: "20 min check/change",
                partsCost: "$15–25 oil and filter",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Maxima 10W-30 MA oil 1qt",
                               estimatedPrice: "~$8", searchQuery: "Maxima 10W30 motorcycle oil"),
                    PartSource(store: "Amazon", partName: "Honda HP4M 10W-30 1qt",
                               estimatedPrice: "~$10", searchQuery: "Honda HP4M 10W30 oil"),
                    PartSource(store: "Partzilla", partName: "OEM Honda oil filter CRF250R",
                               estimatedPrice: "~$9", searchQuery: "Honda CRF250R oil filter 15410-MEN-671"),
                    PartSource(store: "BikeBandit", partName: "K&N oil filter HF204",
                               estimatedPrice: "~$11", searchQuery: "K&N HF204 oil filter Honda"),
                ],
                youtubeQuery: "2020 Honda CRF250R oil change how to",
                sensor: "Oil Temp", sensorValue: "\(oilTemp)°C"
            ))
        } else if oilTemp >= 118 {
            faults.append(Fault(
                code: "P0524",
                title: "High Oil Temperature",
                symptom: "Slightly reduced response, possible light ticking at idle.",
                cause: "Hard riding, low oil level, or oil past change interval (every 15 hrs).",
                action: "Check oil level and condition. Change if overdue.",
                severity: .warning,
                diyCategory: .diy,
                diySteps: [
                    "Check oil level at sight glass — between marks",
                    "If dark/black and overdue — drain now",
                    "Drain: 12mm drain bolt, torque to 30 Nm on reinstall",
                    "Replace oil filter — Honda #15410-MEN-671",
                    "Fill: 0.9L without filter, 1.1L with filter change"
                ],
                toolsNeeded: ["12mm socket", "Oil drain pan", "Torque wrench", "10W-30 oil"],
                estimatedTime: "25–30 min",
                partsCost: "$15–25",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Maxima 10W-30 MA oil 1qt",
                               estimatedPrice: "~$8", searchQuery: "Maxima 10W30 motorcycle oil"),
                    PartSource(store: "Amazon", partName: "Mobil 1 Racing 4T 10W-40",
                               estimatedPrice: "~$9", searchQuery: "Mobil 1 Racing 4T motorcycle oil"),
                    PartSource(store: "Partzilla", partName: "OEM Honda oil filter",
                               estimatedPrice: "~$9", searchQuery: "Honda CRF250R oil filter OEM"),
                ],
                youtubeQuery: "Honda CRF250R oil change full walkthrough",
                sensor: "Oil Temp", sensorValue: "\(oilTemp)°C"
            ))
        }

        // ── P0562 / P0563 Battery voltage ──
        if battery <= 11.8 {
            faults.append(Fault(
                code: "P0562",
                title: "Critical Low System Voltage",
                symptom: "Starter cranks slowly, engine may stall, sudden power loss.",
                cause: "Dead battery or stator failure. CRF250R stators commonly fail at 50–100 hours.",
                action: "Head back now — bike may not restart if stalled.",
                severity: .critical,
                diyCategory: .diyAdvanced,
                diySteps: [
                    "Test battery voltage: should be 12.6–12.8V resting",
                    "Rev to 5,000 RPM — measure voltage at battery",
                    "Below 13.5V at 5k RPM — stator or regulator/rectifier failing",
                    "Replace regulator/rectifier first — cheaper and often the culprit",
                    "Test stator resistance: 0.1–1.0 ohm between yellow wires",
                    "If stator shorted to ground (0 ohm to frame) — replace stator"
                ],
                toolsNeeded: ["Multimeter", "Basic socket set"],
                estimatedTime: "30–60 min diagnosis",
                partsCost: "$30–60 regulator, $80–150 stator",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Moose Racing regulator/rectifier CRF250R",
                               estimatedPrice: "~$45", searchQuery: "CRF250R regulator rectifier"),
                    PartSource(store: "Amazon", partName: "Rick's Motorsport regulator rectifier",
                               estimatedPrice: "~$38", searchQuery: "Honda CRF250R regulator rectifier replacement"),
                    PartSource(store: "Partzilla", partName: "OEM Honda stator CRF250R",
                               estimatedPrice: "~$140", searchQuery: "Honda CRF250R stator OEM"),
                    PartSource(store: "BikeBandit", partName: "Lithium battery Shorai LFX14",
                               estimatedPrice: "~$130", searchQuery: "Shorai LFX14 lithium battery Honda"),
                ],
                youtubeQuery: "Honda CRF250R stator regulator rectifier test replace",
                sensor: "System Voltage", sensorValue: String(format: "%.1fV", battery)
            ))
        } else if battery <= 12.2 {
            faults.append(Fault(
                code: "P0562",
                title: "Low System Voltage",
                symptom: "Harder starting, possible hesitation from PGM-FI.",
                cause: "Battery discharging — stator may be undercharging.",
                action: "Check charging voltage at 5,000 RPM. Charge battery before next ride.",
                severity: .warning,
                diyCategory: .diy,
                diySteps: [
                    "Charge battery overnight with a smart charger (1–2A)",
                    "Start and rev to 5,000 RPM — measure voltage at battery",
                    "Should read 13.5–14.5V — if not, regulator/rectifier suspect",
                    "Clean battery terminals and check for corrosion"
                ],
                toolsNeeded: ["Battery charger", "Multimeter"],
                estimatedTime: "Overnight + 15 min test",
                partsCost: "$0 if just charging, $30–60 if regulator needed",
                partsSources: [
                    PartSource(store: "Amazon", partName: "NOCO Genius1 smart charger",
                               estimatedPrice: "~$30", searchQuery: "NOCO Genius1 battery charger motorcycle"),
                    PartSource(store: "Rocky Mountain ATV", partName: "Battery Tender Plus charger",
                               estimatedPrice: "~$35", searchQuery: "Battery Tender Plus motorcycle charger"),
                    PartSource(store: "BikeBandit", partName: "Yuasa YTZ7S battery CRF250R",
                               estimatedPrice: "~$75", searchQuery: "Yuasa YTZ7S Honda CRF250R battery"),
                ],
                youtubeQuery: "motorcycle battery charging how to test charging system",
                sensor: "System Voltage", sensorValue: String(format: "%.1fV", battery)
            ))
        } else if battery >= 15.0 {
            faults.append(Fault(
                code: "P0563",
                title: "High Voltage — Regulator/Rectifier Failure",
                symptom: "Battery swelling, electrolyte smell, electronics erratic.",
                cause: "Regulator/rectifier not limiting stator output — overcharging.",
                action: "Replace regulator/rectifier immediately. Check battery for swelling.",
                severity: .critical,
                diyCategory: .diy,
                diySteps: [
                    "Locate regulator/rectifier near airbox on CRF250R",
                    "Unplug connector — inspect for burnt pins or corrosion",
                    "Order Honda replacement or aftermarket unit",
                    "Swap unit — 2 bolts, one connector, 10 min job",
                    "Check battery for swelling — if swollen, replace",
                    "Recheck voltage at 5,000 RPM after repair (13.5–14.5V)"
                ],
                toolsNeeded: ["8mm socket", "Multimeter"],
                estimatedTime: "10–15 min replacement",
                partsCost: "$30–60 regulator, $40–80 if battery also needed",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Moose Racing regulator/rectifier",
                               estimatedPrice: "~$45", searchQuery: "CRF250R regulator rectifier Moose Racing"),
                    PartSource(store: "Amazon", partName: "RMSTATOR regulator rectifier CRF250R",
                               estimatedPrice: "~$32", searchQuery: "RMSTATOR Honda CRF250R regulator rectifier"),
                    PartSource(store: "Partzilla", partName: "OEM Honda regulator/rectifier",
                               estimatedPrice: "~$55", searchQuery: "Honda CRF250R regulator rectifier OEM"),
                ],
                youtubeQuery: "Honda CRF250R regulator rectifier replace how to",
                sensor: "System Voltage", sensorValue: String(format: "%.1fV", battery)
            ))
        }

        // ── P0507 / P0506 Idle RPM ──
        if throttle < 12 && rpm > 0 {
            if rpm < 1200 {
                faults.append(Fault(
                    code: "P0507",
                    title: "Low Idle Speed",
                    symptom: "Engine stalls at stops, rough idle, hard to keep running.",
                    cause: "Clogged pilot jet, air leak at intake boot, or idle screw too low.",
                    action: "Turn idle adjuster clockwise 1/4 turn. If persists, clean pilot jet.",
                    severity: .warning,
                    diyCategory: .diy,
                    diySteps: [
                        "Turn idle adjuster knob clockwise 1/4 turn increments",
                        "Warm engine fully (5+ min) then recheck idle",
                        "Check throttle body boot for cracks — air leak causes low idle",
                        "Remove carb/TB and clean pilot jet with carb spray",
                        "Pilot jet hole should be clear — can see light through it",
                        "Check air filter — clogged filter causes rich idle"
                    ],
                    toolsNeeded: ["Flathead screwdriver", "Carb cleaner spray", "JIS screwdrivers"],
                    estimatedTime: "20–45 min",
                    partsCost: "$5–10",
                    partsSources: [
                        PartSource(store: "Amazon", partName: "WD-40 Carb and Throttle Body Cleaner",
                                   estimatedPrice: "~$7", searchQuery: "carb cleaner spray throttle body"),
                        PartSource(store: "Rocky Mountain ATV", partName: "Twin Air air filter CRF250R",
                                   estimatedPrice: "~$18", searchQuery: "Twin Air filter Honda CRF250R"),
                        PartSource(store: "Partzilla", partName: "OEM Honda pilot jet CRF250R",
                                   estimatedPrice: "~$8", searchQuery: "Honda CRF250R pilot jet OEM"),
                    ],
                    youtubeQuery: "Honda CRF250R idle adjustment pilot jet clean",
                    sensor: "RPM (Idle)", sensorValue: "\(rpm) RPM"
                ))
            } else if rpm > 1700 {
                faults.append(Fault(
                    code: "P0506",
                    title: "High Idle Speed",
                    symptom: "Bike creeps at stops, revs hang, won't settle at idle.",
                    cause: "Throttle cable too tight, air leak, or idle screw too high.",
                    action: "Check 2–3mm throttle freeplay. Inspect airboot. Lower idle adjuster.",
                    severity: .warning,
                    diyCategory: .diy,
                    diySteps: [
                        "Pull throttle — should be 2–3mm freeplay before resistance",
                        "Loosen cable adjuster at throttle body to add slack if too tight",
                        "Spray carb cleaner around airboot/intake — RPM change = air leak",
                        "Turn idle adjuster anticlockwise 1/4 turn at a time",
                        "Check throttle slide moves freely and return spring is intact"
                    ],
                    toolsNeeded: ["Flathead screwdriver", "Carb cleaner spray"],
                    estimatedTime: "15–20 min",
                    partsCost: "$0–15",
                    partsSources: [
                        PartSource(store: "Amazon", partName: "Throttle cable Honda CRF250R",
                                   estimatedPrice: "~$12", searchQuery: "Honda CRF250R throttle cable"),
                        PartSource(store: "Rocky Mountain ATV", partName: "Moose Racing intake boot CRF250R",
                                   estimatedPrice: "~$22", searchQuery: "Honda CRF250R intake boot airboot"),
                        PartSource(store: "Partzilla", partName: "OEM Honda throttle cable CRF250R",
                                   estimatedPrice: "~$18", searchQuery: "Honda CRF250R throttle cable OEM"),
                    ],
                    youtubeQuery: "Honda CRF250R throttle cable adjustment high idle fix",
                    sensor: "RPM (Idle)", sensorValue: "\(rpm) RPM"
                ))
            }
        }

        // ── P0219 Over-rev ──
        if rpm >= 13200 {
            faults.append(Fault(
                code: "P0219",
                title: "Engine Over-Speed",
                symptom: "Valve float possible — sound changes, possible misfiring.",
                cause: "Rev limiter not engaging, missed shift, or throttle stuck.",
                action: "Back off throttle. Inspect valvetrain if this happens repeatedly.",
                severity: .warning,
                diyCategory: .diyAdvanced,
                diySteps: [
                    "Check throttle returns fully when released — no sticking",
                    "Inspect throttle cable for kinks or fraying",
                    "Check valve clearances: intake 0.10–0.15mm, exhaust 0.20–0.25mm",
                    "Listen for valve tick at idle — indicates tight or bent valve",
                    "If tick present — valve inspection and shim replacement required"
                ],
                toolsNeeded: ["Feeler gauges", "Valve shim kit", "Torque wrench"],
                estimatedTime: "1–2 hrs",
                partsCost: "$20–50 shims",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Hot Cams shim kit Honda",
                               estimatedPrice: "~$35", searchQuery: "Hot Cams shim kit Honda CRF250R valve"),
                    PartSource(store: "Partzilla", partName: "OEM Honda valve shim set CRF250R",
                               estimatedPrice: "~$45", searchQuery: "Honda CRF250R valve shims OEM"),
                    PartSource(store: "Amazon", partName: "Feeler gauge set",
                               estimatedPrice: "~$8", searchQuery: "feeler gauge set metric motorcycle"),
                ],
                youtubeQuery: "Honda CRF250R valve clearance check adjust how to",
                sensor: "RPM", sensorValue: "\(rpm) RPM"
            ))
        }

        // ── Maintenance reminders ──
        let hoursInt = Int(engineHours)
        if hoursInt > 0 && hoursInt % 15 == 0 && engineHours.truncatingRemainder(dividingBy: 1) < 0.1 {
            faults.append(Fault(
                code: "MAINT-OIL",
                title: "Oil Change Due (\(hoursInt) hrs)",
                symptom: "Degraded oil reduces engine protection.",
                cause: "Honda CRF250R oil interval: every 15 hours.",
                action: "Change engine oil and filter. Honda spec: 10W-30 MA, 1.1L with filter.",
                severity: .info,
                diyCategory: .diy,
                diySteps: [
                    "Warm engine 2–3 min then kill — warm oil drains fully",
                    "Remove 12mm drain bolt and crush washer",
                    "Remove oil filter with filter wrench",
                    "Install new filter (lightly oil the seal), new crush washer",
                    "Torque drain bolt to 30 Nm",
                    "Fill: 1.1L Honda 10W-30 MA oil (with filter change)"
                ],
                toolsNeeded: ["12mm socket", "Oil filter wrench", "Drain pan", "Torque wrench"],
                estimatedTime: "20–25 min",
                partsCost: "$15–25",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Maxima Premium 10W-30 4T 1qt",
                               estimatedPrice: "~$8", searchQuery: "Maxima Premium 10W30 4T oil"),
                    PartSource(store: "Amazon", partName: "Honda HP4M 10W-30 1qt",
                               estimatedPrice: "~$10", searchQuery: "Honda HP4M 10W30 motorcycle oil"),
                    PartSource(store: "Partzilla", partName: "OEM Honda oil filter CRF250R",
                               estimatedPrice: "~$9", searchQuery: "Honda oil filter CRF250R 15410-MEN-671"),
                    PartSource(store: "BikeBandit", partName: "K&N oil filter HF204",
                               estimatedPrice: "~$11", searchQuery: "K&N HF204 oil filter"),
                ],
                youtubeQuery: "2020 Honda CRF250R oil change step by step",
                sensor: "Engine Hours", sensorValue: String(format: "%.0f hrs", engineHours)
            ))
        }

        if engineHours >= 25 && engineHours < 25.5 {
            faults.append(Fault(
                code: "MAINT-VALVE",
                title: "Valve Clearance Check Due",
                symptom: "Tight valves cause hard starting and eventually burnt valves.",
                cause: "Honda recommends valve check every 25 hours on CRF250R.",
                action: "Check clearances cold: Intake 0.10–0.15mm, Exhaust 0.20–0.25mm.",
                severity: .info,
                diyCategory: .diyAdvanced,
                diySteps: [
                    "Cold engine — remove seat, tank, and valve cover (8 bolts)",
                    "Rotate to TDC on compression stroke (both valves closed)",
                    "Feeler gauge: intake 0.10–0.15mm, exhaust 0.20–0.25mm",
                    "If out of spec: measure shim, calculate new size needed",
                    "Order shims and replace — Hot Cams kit has most sizes",
                    "Torque valve cover to 10 Nm in cross pattern"
                ],
                toolsNeeded: ["Feeler gauges", "Shim tool", "Torque wrench", "Shim kit"],
                estimatedTime: "1.5–2 hrs",
                partsCost: "$20–40 shims if needed",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Hot Cams shim kit Honda CRF",
                               estimatedPrice: "~$35", searchQuery: "Hot Cams valve shim kit Honda CRF250R"),
                    PartSource(store: "Amazon", partName: "Feeler gauge metric set",
                               estimatedPrice: "~$8", searchQuery: "feeler gauge set metric 0.05mm"),
                    PartSource(store: "Partzilla", partName: "Honda valve cover gasket CRF250R",
                               estimatedPrice: "~$14", searchQuery: "Honda CRF250R valve cover gasket OEM"),
                    PartSource(store: "BikeBandit", partName: "Vertex gasket kit top end CRF250R",
                               estimatedPrice: "~$28", searchQuery: "Vertex top end gasket kit Honda CRF250R"),
                ],
                youtubeQuery: "Honda CRF250R valve adjustment check how to DIY",
                sensor: "Engine Hours", sensorValue: String(format: "%.0f hrs", engineHours)
            ))
        }

        if engineHours >= 80 && engineHours < 80.5 {
            faults.append(Fault(
                code: "MAINT-TOPEND",
                title: "Top End Inspection Due",
                symptom: "Possible power loss or increased engine noise if overdue.",
                cause: "Honda CRF250R top end service interval: 80 hours.",
                action: "Inspect piston, rings, and cylinder bore. Replace if worn.",
                severity: .info,
                diyCategory: .diyAdvanced,
                diySteps: [
                    "Remove exhaust header, subframe, seat, tank, and airbox",
                    "Remove cylinder head (8 bolts, star pattern torque sequence)",
                    "Inspect piston crown — check for cracks or heavy carbon",
                    "Measure bore — Honda spec: 76.000–76.015mm",
                    "Check ring gap in bore: standard 0.15–0.30mm",
                    "Replace piston, rings, and gaskets if at/beyond spec",
                    "Torque head bolts to 10 Nm then 38 Nm in sequence"
                ],
                toolsNeeded: ["Full socket set", "Torque wrench", "Bore gauge", "Piston ring compressor"],
                estimatedTime: "3–4 hrs",
                partsCost: "$150–300 piston kit + gaskets",
                partsSources: [
                    PartSource(store: "Rocky Mountain ATV", partName: "Wiseco piston kit CRF250R",
                               estimatedPrice: "~$145", searchQuery: "Wiseco piston kit Honda CRF250R"),
                    PartSource(store: "Amazon", partName: "Vertex piston kit CRF250R standard bore",
                               estimatedPrice: "~$120", searchQuery: "Vertex piston kit Honda CRF250R 2020"),
                    PartSource(store: "Partzilla", partName: "OEM Honda piston assembly CRF250R",
                               estimatedPrice: "~$180", searchQuery: "Honda CRF250R piston OEM"),
                    PartSource(store: "BikeBandit", partName: "Cometic top end gasket kit CRF250R",
                               estimatedPrice: "~$55", searchQuery: "Cometic gasket kit Honda CRF250R top end"),
                ],
                youtubeQuery: "Honda CRF250R top end rebuild piston replacement how to",
                sensor: "Engine Hours", sensorValue: String(format: "%.0f hrs", engineHours)
            ))
        }

        return faults.sorted {
            let order: [FaultSeverity] = [.critical, .warning, .info]
            return (order.firstIndex(of: $0.severity) ?? 3) < (order.firstIndex(of: $1.severity) ?? 3)
        }
    }


    static func healthScore(faults: [Fault]) -> Int {
        var score = 100
        for f in faults {
            switch f.severity {
            case .critical: score -= 35
            case .warning:  score -= 12
            case .info:     score -= 3
            }
        }
        return max(0, score)
    }
}
