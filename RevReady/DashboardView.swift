import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppStateManager
    var store: ScanHistoryStore { appState.historyStore }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                primaryAction
                secondaryActions
                recentScansSection
                moreToolsSection
            }
        }
        .background(Color.motoBg)
    }

    // MARK: - Header
    var header: some View {
        let profile = appState.profileStore
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                if profile.isOnboarded {
                    // Personalised greeting
                    HStack(spacing: 6) {
                        Text(profile.greeting + ",")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.motoMuted)
                        Text(profile.firstName)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.motoOrange)
                    }
                    Text(profile.fullBikeName.isEmpty ? "RevReady" : profile.fullBikeName)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                } else {
                    HStack(spacing: 0) {
                        Text("RevReady")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("DIAGS")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.motoOrange)
                    }
                    Text(appState.selectedBikeString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.motoMuted)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                // History badge
                Button { appState.navigate(to: .history) } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14)).foregroundColor(.motoMuted)
                            .frame(width: 36, height: 36)
                            .background(Color.motoCard).clipShape(Circle())
                            .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
                        if store.scans.count > 0 {
                            Text("\(min(store.scans.count, 9))")
                                .font(.system(size: 8, weight: .black)).foregroundColor(.white)
                                .frame(width: 14, height: 14)
                                .background(Color.motoOrange).clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                // Bike picker — uses full BikeBrandData list, saves to profile
                Menu {
                    ForEach(BikeBrandData.sortedBrands, id: \.self) { brand in
                        Menu(brand) {
                            ForEach(BikeBrandData.models(for: brand), id: \.self) { model in
                                Button("\(brand) \(model)") {
                                    appState.selectedBikeString = "\(brand) \(model)"
                                    // Persist back to profile (keep year if already set)
                                    if var p = appState.profileStore.profile {
                                        p.bikeBrand = brand
                                        p.bikeModel = model
                                        appState.profileStore.save(p)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(appState.selectedBikeString.components(separatedBy: " ").first ?? "Bike")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.motoMuted)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.motoMuted)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.motoCard).cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.motoBorder, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 18)
    }

    // MARK: - Primary Action (biggest, most important)
    var primaryAction: some View {
        VStack(spacing: 12) {
            // Hero diagnose card
            Button { appState.navigate(to: .symptoms) } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#ef4444").opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color(hex: "#ef4444"))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Diagnose a Problem")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Describe symptom · AI ranks causes")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.motoMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.motoOrange)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.motoCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: "#ef4444").opacity(0.35), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            // AI camera scan — second most important
            Button { appState.resetScan(); appState.navigate(to: .camera) } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.motoOrange.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.motoOrange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Visual Inspection")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Photo your bike · AI finds issues")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.motoMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.motoOrange)
                }
                .padding(18)
                .background(Color.motoCard)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.motoOrange.opacity(0.35), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Secondary Actions (medium weight)
    var secondaryActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("TOOLS")
            HStack(spacing: 10) {
                SecondaryTile(
                    icon: "list.clipboard.fill",
                    label: "Maintenance",
                    color: Color(hex: "#4ade80")
                ) { appState.navigate(to: .maintenance) }

                SecondaryTile(
                    icon: "wrench.adjustable.fill",
                    label: "Repair Guides",
                    color: Color(hex: "#3b82f6")
                ) { appState.navigate(to: .repairGuides) }

                SecondaryTile(
                    icon: "magnifyingglass.circle.fill",
                    label: "Pre-Purchase",
                    color: Color(hex: "#f59e0b")
                ) { appState.navigate(to: .prePurchase) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Recent Scans
    var recentScansSection: some View {
        VStack(spacing: 0) {
            if !store.scans.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionLabel("RECENT SCANS")
                        Spacer()
                        Button { appState.navigate(to: .history) } label: {
                            Text("See all →")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.motoOrange)
                        }
                    }.padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        ForEach(store.scans.prefix(2)) { scan in
                            Button { appState.navigate(to: .history) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(scan.bikeModel)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text(scan.formattedDate)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.motoMuted)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(scan.healthScore)")
                                            .font(.system(size: 20, weight: .black, design: .monospaced))
                                            .foregroundColor(scan.healthColor)
                                        Text(scan.findingCount == 0 ? "Clean" : "\(scan.findingCount) issue\(scan.findingCount != 1 ? "s" : "")")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.motoMuted)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Color.motoCard).cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - More Tools (low priority, collapsed feel)
    var moreToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("MORE TOOLS")
            VStack(spacing: 1) {
                ToolRow(icon: "book.closed.fill", color: Color(hex: "#a78bfa"), label: "Bike Specs", subtitle: "OEM specs & service intervals") {
                    appState.navigate(to: .specs)
                }
                Divider().background(Color.motoBorder).padding(.leading, 56)
                ToolRow(icon: "flame.fill", color: Color(hex: "#f97316"), label: "Jetting Calculator", subtitle: "Altitude & temperature compensation") {
                    appState.navigate(to: .jetCalc)
                }
            }
            .background(Color.motoCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.motoMuted)
    }
}

// MARK: - Secondary Tile (medium)
struct SecondaryTile: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.motoText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.motoCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - Tool Row (low priority list)
struct ToolRow: View {
    let icon: String; let color: Color; let label: String; let subtitle: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.motoMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.motoDim)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }.buttonStyle(.plain)
    }
}

// MARK: - Gauge Card (kept for SensorsView)
struct GaugeCard: View {
    let icon: String, label: String, value: String, unit: String
    let fill: Double, barColor: Color, animate: Bool
    var isWarning = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 18))
                .foregroundColor(isWarning ? Color(hex: "#ef4444") : .motoOrange)
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(isWarning ? Color(hex: "#ef4444") : .white)
                Text(unit).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.motoBorder).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(barColor)
                        .frame(width: animate ? g.size.width * fill : 0, height: 3)
                        .animation(.easeOut(duration: 1.0).delay(0.2), value: animate)
                }
            }.frame(height: 3)
        }
        .padding(14).background(Color.motoCard).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.motoBorder, lineWidth: 1))
    }
}

#Preview { DashboardView().environmentObject(AppStateManager()) }
