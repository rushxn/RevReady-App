import SwiftUI
import Foundation

// MARK: - User Profile
struct UserProfile: Codable {
    var name: String
    var rideLocation: String
    var bikeBrand: String
    var bikeModel: String
    var bikeYear: String
    var hasCompletedOnboarding: Bool
}

// MARK: - Bike Brand / Model data
struct BikeBrandData {
    static let brands: [String: [String]] = [
        "KTM": ["125 SX", "150 SX", "250 SX", "250 SX-F", "300 XC-W", "350 SX-F",
                "450 SX-F", "450 EXC-F", "500 EXC-F"],
        "Honda": ["CRF125F", "CRF150R", "CRF250R", "CRF250RX", "CRF300L",
                  "CRF450R", "CRF450RX", "CRF450L"],
        "Yamaha": ["YZ85", "YZ125", "YZ250", "YZ250F", "YZ250X",
                   "YZ450F", "WR250F", "WR450F"],
        "Husqvarna": ["TC 125", "TC 250", "FC 250", "FC 350", "FC 450",
                      "TX 300", "FE 350", "FE 450", "FE 501"],
        "Kawasaki": ["KX85", "KX100", "KX112", "KX250", "KX450",
                     "KLX300R", "KLX450R"],
        "Suzuki": ["RM85", "RM-Z250", "RM-Z450", "DR-Z400S"],
        "Beta": ["125 RR", "200 RR", "250 RR", "300 RR", "350 RR", "430 RR", "480 RR"],
        "Sherco": ["125 SE", "250 SE", "300 SE", "250 SEF", "300 SEF", "450 SEF"],
        "GasGas": ["MC 125", "MC 250F", "MC 450F", "EC 250", "EC 300", "EX 350F", "EX 450F"],
        "TM Racing": ["MX 125", "MX 250F", "MX 450F", "EN 250", "EN 300"],
    ]

    static var sortedBrands: [String] { brands.keys.sorted() }

    static func models(for brand: String) -> [String] {
        brands[brand] ?? []
    }
}

// MARK: - Popular Ride Spots (for quick pick)
let popularRideSpots = [
    "Local Trails", "Motocross Track", "Desert", "Sand Dunes",
    "Woods / Enduro", "Mountains", "Carnegie SVRA", "Glen Helen",
    "Pala Raceway", "Fox Raceway", "Milestone MX", "Lake Elsinore"
]

// MARK: - Profile Store
class UserProfileStore: ObservableObject {
    @Published var profile: UserProfile?
    private let key = "dbd_user_profile"

    init() { load() }

    var isOnboarded: Bool { profile?.hasCompletedOnboarding == true }

    var firstName: String {
        profile?.name.components(separatedBy: " ").first ?? "Rider"
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default:      return "Hey"
        }
    }

    var fullBikeName: String {
        guard let p = profile else { return "" }
        return "\(p.bikeYear) \(p.bikeBrand) \(p.bikeModel)"
    }

    func save(_ profile: UserProfile) {
        self.profile = profile
        if let d = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    func reset() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key),
              let p = try? JSONDecoder().decode(UserProfile.self, from: d)
        else { return }
        profile = p
    }
}
