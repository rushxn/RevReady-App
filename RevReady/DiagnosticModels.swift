import SwiftUI
import Foundation

// MARK: - Bike Models
enum BikeModel: String, CaseIterable, Codable {
    case ktm450     = "KTM 450 EXC-F"
    case honda450   = "Honda CRF450R"
    case yamaha250  = "Yamaha YZ250F"
    case husqvarna  = "Husqvarna FC450"
    case kawasaki   = "Kawasaki KX250"
    case suzuki     = "Suzuki RM-Z450"
    case yamaha125  = "Yamaha YZ125"
    case ktm300     = "KTM 300 XC-W"
    case honda250   = "Honda CRF250R"
    case beta300    = "Beta 300 RR"
}

// MARK: - Bike Parts
enum BikePart: String, CaseIterable, Codable {
    case engine     = "Engine"
    case exhaust    = "Exhaust"
    case suspension = "Suspension"
    case chain      = "Chain"
    case brakes     = "Brakes"
    case airFilter  = "Air Filter"
    case frame      = "Frame"
    case forks      = "Forks"

    var icon: String {
        switch self {
        case .engine:     return "gear"
        case .exhaust:    return "flame"
        case .suspension: return "arrow.up.and.down"
        case .chain:      return "link"
        case .brakes:     return "hand.raised"
        case .airFilter:  return "wind"
        case .frame:      return "rectangle.3.group"
        case .forks:      return "arrow.down.to.line"
        }
    }

    var photoTip: String {
        switch self {
        case .engine:     return "Get close to the engine cases. Capture the base gasket area, cylinder head, and any wet/oily spots. Use a flashlight for dark areas."
        case .exhaust:    return "Photograph the header pipe joint at the cylinder head, full pipe length, and silencer. Look for blue/black discoloration or carbon buildup."
        case .suspension: return "Capture fork legs from front and side. Look for oil streaks below dust seals. For the rear, show the shock body and linkage."
        case .chain:      return "Photograph chain from the side with slack visible. Capture a sprocket — worn teeth look like hooks or shark fins."
        case .brakes:     return "Show the brake caliper and rotor together. Capture pad thickness through the caliper window. Both front and rear if possible."
        case .airFilter:  return "Remove seat/tank to access airbox. Photograph filter from above and side. Dirty filters appear dark brown or black."
        case .frame:      return "Focus on headstock, swingarm pivot, and welds. Capture full frame from both sides looking for cracks or bends."
        case .forks:      return "Photograph lower leg and slider junction. Capture oil residue on inner tube above seal. Both forks if possible."
        }
    }
}

// MARK: - Severity
enum Severity: String, Codable {
    case high = "High", medium = "Medium", low = "Low", unknown = "Unknown"
    init(from decoder: Decoder) throws {
        let raw = (try decoder.singleValueContainer().decode(String.self)).lowercased()
        if raw.contains("high") || raw.contains("critical") { self = .high }
        else if raw.contains("med") || raw.contains("moderate") { self = .medium }
        else if raw.contains("low") || raw.contains("minor") { self = .low }
        else { self = .unknown }
    }
    var color: Color {
        switch self {
        case .high: return Color(hex: "#ef4444")
        case .medium: return Color(hex: "#f59e0b")
        case .low: return Color(hex: "#4ade80")
        case .unknown: return Color(hex: "#888888")
        }
    }
    var glowColor: Color { color.opacity(0.4) }
}

// MARK: - Diagnostic Finding
struct DiagnosticFinding: Codable, Identifiable {
    var id = UUID()
    let name: String
    let part: String
    let severity: Severity
    let description: String
    let action: String
    let diyCost: String?
    let shopCost: String?
    let canDIY: Bool?
    enum CodingKeys: String, CodingKey { case name, part, severity, description, action, diyCost, shopCost, canDIY }
}

// MARK: - Diagnostic Result
struct DiagnosticResult: Codable {
    let healthScore: Int
    let summary: String
    let findings: [DiagnosticFinding]
    let urgency: String
    let photoQuality: String?  // "Good" | "Limited" | "Poor"

    var healthColor: Color {
        healthScore >= 80 ? Color(hex: "#4ade80") :
        healthScore >= 55 ? Color(hex: "#f59e0b") : Color(hex: "#ef4444")
    }
    var urgencyColor: Color {
        let u = urgency.lowercased()
        return u.contains("not") ? Color(hex: "#ef4444") : u.contains("caution") ? Color(hex: "#f59e0b") : Color(hex: "#4ade80")
    }
    // Confidence label based on photo quality and number of findings
    var confidenceNote: String? {
        guard let q = photoQuality else { return nil }
        switch q.lowercased() {
        case let s where s.contains("poor"):
            return "Low confidence — photos too unclear for reliable assessment. Try closer, better-lit shots."
        case let s where s.contains("limited"):
            return "Partial assessment — some areas unclear. More photos would improve accuracy."
        default:
            return nil
        }
    }
}

// MARK: - Symptom Diagnosis
struct SymptomCause: Codable, Identifiable {
    var id = UUID()
    let cause: String
    let likelihood: Int
    let description: String
    let difficulty: String
    let estimatedCost: String
    let toolsNeeded: [String]
    let safeToRide: Bool
    enum CodingKeys: String, CodingKey { case cause, likelihood, description, difficulty, estimatedCost, toolsNeeded, safeToRide }
}

struct SymptomDiagnosisResult: Codable {
    let symptom: String
    let causes: [SymptomCause]
    let immediateAction: String
    let safeToRide: Bool
}

// MARK: - Maintenance Item
enum MaintenanceCategory: String, CaseIterable, Codable {
    case engine = "Engine", suspension = "Suspension", drivetrain = "Drivetrain"
    case brakes = "Brakes", cooling = "Cooling", electrical = "Electrical"
    var icon: String {
        switch self {
        case .engine: return "gear"; case .suspension: return "arrow.up.and.down"
        case .drivetrain: return "link"; case .brakes: return "hand.raised"
        case .cooling: return "thermometer.medium"; case .electrical: return "bolt"
        }
    }
}

struct MaintenanceItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var category: MaintenanceCategory
    var intervalHours: Double
    var lastServiceHours: Double
    var notes: String
    var isOverdue: Bool { MaintenanceItem.currentHours - lastServiceHours >= intervalHours }
    var hoursUntilDue: Double { intervalHours - (MaintenanceItem.currentHours - lastServiceHours) }
    var percentUsed: Double { min((MaintenanceItem.currentHours - lastServiceHours) / intervalHours, 1.0) }
    static var currentHours: Double = 0
}

// MARK: - Bike Specs
struct BikeSpecs {
    let model: String
    let oilCapacity: String
    let oilType: String
    let sparkPlug: String
    let sparkPlugGap: String
    let valveClearanceIntake: String
    let valveClearanceExhaust: String
    let coolantType: String
    let coolantCapacity: String
    let chainSize: String
    let chainLinks: Int
    let frontSprocket: Int
    let rearSprocket: Int
    let tirePressuref: String
    let tirePressureR: String
    let topEndInterval: String
    let bottomEndInterval: String
    let airFilterInterval: String
    let commonIssues: [String]
    let fuelMix: String?

    static let database: [String: BikeSpecs] = [
        "KTM 450 EXC-F": BikeSpecs(
            model: "KTM 450 EXC-F", oilCapacity: "1.0L w/ filter", oilType: "10W-50 4-stroke",
            sparkPlug: "NGK LKAR8A-9", sparkPlugGap: "0.9mm",
            valveClearanceIntake: "0.10–0.15mm", valveClearanceExhaust: "0.20–0.25mm",
            coolantType: "KTM Coolant Ready Mix", coolantCapacity: "0.9L",
            chainSize: "520", chainLinks: 118, frontSprocket: 14, rearSprocket: 50,
            tirePressuref: "12–15 psi", tirePressureR: "12–15 psi",
            topEndInterval: "80–100 hrs", bottomEndInterval: "200+ hrs",
            airFilterInterval: "10–15 hrs",
            commonIssues: ["Stator failure", "Hot start issues", "Coolant hose cracking"],
            fuelMix: nil),
        "Honda CRF450R": BikeSpecs(
            model: "Honda CRF450R", oilCapacity: "1.1L w/ filter", oilType: "Honda HP4M 10W-40",
            sparkPlug: "NGK SILZKR7C11S", sparkPlugGap: "1.0mm",
            valveClearanceIntake: "0.10–0.15mm", valveClearanceExhaust: "0.20–0.25mm",
            coolantType: "Pro Honda HP Coolant", coolantCapacity: "1.15L",
            chainSize: "520", chainLinks: 114, frontSprocket: 13, rearSprocket: 48,
            tirePressuref: "13–15 psi", tirePressureR: "13–15 psi",
            topEndInterval: "60–80 hrs", bottomEndInterval: "150+ hrs",
            airFilterInterval: "10 hrs",
            commonIssues: ["Titanium valve wear", "Cam chain tensioner noise", "Power valve issues"],
            fuelMix: nil),
        "Yamaha YZ250F": BikeSpecs(
            model: "Yamaha YZ250F", oilCapacity: "0.95L w/ filter", oilType: "Yamalube 4 10W-40",
            sparkPlug: "NGK LMAR8A-9", sparkPlugGap: "0.9mm",
            valveClearanceIntake: "0.10–0.15mm", valveClearanceExhaust: "0.17–0.22mm",
            coolantType: "Yamaha Coolant", coolantCapacity: "0.95L",
            chainSize: "520", chainLinks: 114, frontSprocket: 13, rearSprocket: 48,
            tirePressuref: "12–14 psi", tirePressureR: "12–14 psi",
            topEndInterval: "60–80 hrs", bottomEndInterval: "150+ hrs",
            airFilterInterval: "10 hrs",
            commonIssues: ["Stator failure at high hours", "Radiator damage prone", "Coolant loss"],
            fuelMix: nil),
        "Yamaha YZ125": BikeSpecs(
            model: "Yamaha YZ125", oilCapacity: "N/A (2-stroke)", oilType: "Yamalube 2R premix",
            sparkPlug: "NGK BR9EG", sparkPlugGap: "0.7mm",
            valveClearanceIntake: "N/A (2-stroke)", valveClearanceExhaust: "N/A (2-stroke)",
            coolantType: "Yamaha Coolant", coolantCapacity: "0.95L",
            chainSize: "520", chainLinks: 114, frontSprocket: 13, rearSprocket: 48,
            tirePressuref: "12–14 psi", tirePressureR: "12–14 psi",
            topEndInterval: "30–40 hrs", bottomEndInterval: "80–100 hrs",
            airFilterInterval: "5–10 hrs",
            commonIssues: ["Power valve sticking", "Reed valve wear", "Piston wear"],
            fuelMix: "32:1 to 40:1 premix"),
        "KTM 300 XC-W": BikeSpecs(
            model: "KTM 300 XC-W", oilCapacity: "N/A (2-stroke)", oilType: "Motorex Cross Power 2T",
            sparkPlug: "NGK IRIWAY8", sparkPlugGap: "0.7mm",
            valveClearanceIntake: "N/A (2-stroke)", valveClearanceExhaust: "N/A (2-stroke)",
            coolantType: "KTM Coolant Ready Mix", coolantCapacity: "1.0L",
            chainSize: "520", chainLinks: 118, frontSprocket: 14, rearSprocket: 50,
            tirePressuref: "12–15 psi", tirePressureR: "12–15 psi",
            topEndInterval: "40–60 hrs", bottomEndInterval: "100+ hrs",
            airFilterInterval: "8–12 hrs",
            commonIssues: ["Power valve O-ring leak", "Water pump seal", "Reeds"],
            fuelMix: "50:1 premix")
    ]
}

// MARK: - Maintenance Store
struct MaintenanceLog: Codable, Identifiable {
    let id: UUID
    var bikeModel: String
    var engineHours: Double
    var items: [MaintenanceItem]
    var lastUpdated: Date
}

class MaintenanceStore: ObservableObject {
    @Published var logs: [MaintenanceLog] = []
    @Published var currentHours: Double = 0
    private let key = "dbd_maintenance"
    init() { load() }

    func save(_ log: MaintenanceLog) {
        if let i = logs.firstIndex(where: { $0.id == log.id }) { logs[i] = log }
        else { logs.append(log) }
        persist()
    }

    func updateHours(_ h: Double) { currentHours = h; MaintenanceItem.currentHours = h; persist() }
    func markServiced(logId: UUID, itemId: UUID) {
        guard let li = logs.firstIndex(where: { $0.id == logId }) else { return }
        if let ii = logs[li].items.firstIndex(where: { $0.id == itemId }) {
            logs[li].items[ii].lastServiceHours = currentHours
        }
        persist()
    }

    private func persist() {
        let d = try? JSONEncoder().encode(logs)
        UserDefaults.standard.set(d, forKey: key)
        UserDefaults.standard.set(currentHours, forKey: "dbd_hours")
    }
    private func load() {
        currentHours = UserDefaults.standard.double(forKey: "dbd_hours")
        MaintenanceItem.currentHours = currentHours
        guard let d = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([MaintenanceLog].self, from: d)
        else { return }
        logs = saved
    }
}

// MARK: - Saved Scan
struct SavedScan: Codable, Identifiable {
    let id: UUID; let date: Date; let bikeModel: String
    let healthScore: Int; let urgency: String; let summary: String
    let findingCount: Int; let findings: [DiagnosticFinding]
    static func from(result: DiagnosticResult, bikeString: String) -> SavedScan {
        SavedScan(id: UUID(), date: Date(), bikeModel: bikeString,
                  healthScore: result.healthScore, urgency: result.urgency,
                  summary: result.summary, findingCount: result.findings.count, findings: result.findings)
    }
    var healthColor: Color {
        healthScore >= 70 ? Color(hex: "#4ade80") : healthScore >= 40 ? Color(hex: "#f59e0b") : Color(hex: "#ef4444")
    }
    var formattedDate: String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

class ScanHistoryStore: ObservableObject {
    @Published private(set) var scans: [SavedScan] = []
    private let key = "dbd_scan_history"
    init() { load() }
    func save(_ scan: SavedScan) { scans.insert(scan, at: 0); if scans.count > 20 { scans = Array(scans.prefix(20)) }; persist() }
    func delete(at offsets: IndexSet) { scans.remove(atOffsets: offsets); persist() }
    func clear() { scans = []; persist() }
    private func persist() { if let d = try? JSONEncoder().encode(scans) { UserDefaults.standard.set(d, forKey: key) } }
    private func load() { guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode([SavedScan].self, from: d) else { return }; scans = s }
}

// MARK: - Pre-Purchase Checklist
struct InspectionItem: Identifiable {
    let id = UUID()
    let category: String
    let item: String
    let how: String
    var status: InspectionStatus = .unchecked
}
enum InspectionStatus: String, CaseIterable { case unchecked, pass, fail, warning }

// MARK: - App Screen
enum AppScreen { case dashboard, camera, loading, result, history, symptoms, specs, maintenance, prePurchase, repairGuides, jetCalc, sensors }

// MARK: - Loading Step
struct LoadingStep: Identifiable {
    let id = UUID(); let title: String
    var isDone = false; var isActive = false
}

// MARK: - Color helpers
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,255,255,255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
    static let motoOrange = Color(hex: "#e85d04"), motoBg = Color(hex: "#080808")
    static let motoSurface = Color(hex: "#0f0f0f"), motoCard = Color(hex: "#141414")
    static let motoBorder = Color(hex: "#1e1e1e"), motoText = Color(hex: "#cccccc")
    static let motoMuted = Color(hex: "#555555"), motoDim = Color(hex: "#333333")
}
