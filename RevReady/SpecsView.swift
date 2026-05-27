import SwiftUI

struct SpecsView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedBike: String = ""

    var specs: BikeSpecs? { BikeSpecs.database[selectedBike] }

    var body: some View {
        VStack(spacing: 0) {
            NavBar("Bike Specs", subtitle: "OEM specifications database", onBack: { appState.navigate(to: .dashboard) })
            ScrollView {
                VStack(spacing: 14) {
                    // Bike picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SELECT BIKE").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(BikeSpecs.database.keys.sorted()), id: \.self) { key in
                                    Button { selectedBike = key } label: {
                                        Text(key).font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(selectedBike == key ? .white : .motoMuted)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(selectedBike == key ? Color.motoOrange : Color.motoCard)
                                            .cornerRadius(20)
                                            .overlay(RoundedRectangle(cornerRadius: 20)
                                                .stroke(selectedBike == key ? Color.motoOrange : Color.motoBorder, lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, 16)
                        }
                    }

                    if let s = specs {
                        specsContent(s)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed").font(.system(size: 40)).foregroundColor(.motoMuted)
                            Text("Select a bike above to view specs").font(.system(size: 13, design: .monospaced)).foregroundColor(.motoMuted)
                        }.frame(maxWidth: .infinity).padding(.vertical, 60)
                    }
                }.padding(.top, 4).padding(.bottom, 40)
            }
        }.background(Color.motoBg.ignoresSafeArea())
        .onAppear { selectedBike = appState.selectedBikeString }
    }

    func specsContent(_ s: BikeSpecs) -> some View {
        VStack(spacing: 12) {
            if let fuel = s.fuelMix {
                SpecBanner(icon: "flame.fill", color: Color(hex: "#ef4444"), title: "2-STROKE PREMIX", value: fuel)
            }
            SpecSection(title: "ENGINE OIL") {
                SpecRow("Capacity", s.oilCapacity)
                SpecRow("Oil Type", s.oilType)
                SpecRow("Spark Plug", s.sparkPlug)
                SpecRow("Plug Gap", s.sparkPlugGap)
            }
            if s.fuelMix == nil {
                SpecSection(title: "VALVE CLEARANCES") {
                    SpecRow("Intake", s.valveClearanceIntake)
                    SpecRow("Exhaust", s.valveClearanceExhaust)
                }
            }
            SpecSection(title: "COOLING") {
                SpecRow("Coolant Type", s.coolantType)
                SpecRow("Capacity", s.coolantCapacity)
            }
            SpecSection(title: "DRIVETRAIN") {
                SpecRow("Chain Size", s.chainSize)
                SpecRow("Chain Links", "\(s.chainLinks)")
                SpecRow("Front Sprocket", "\(s.frontSprocket)T")
                SpecRow("Rear Sprocket", "\(s.rearSprocket)T")
            }
            SpecSection(title: "TYRES & PRESSURES") {
                SpecRow("Front Pressure", s.tirePressuref)
                SpecRow("Rear Pressure", s.tirePressureR)
            }
            SpecSection(title: "SERVICE INTERVALS") {
                SpecRow("Top End", s.topEndInterval)
                SpecRow("Bottom End", s.bottomEndInterval)
                SpecRow("Air Filter", s.airFilterInterval)
            }
            SpecSection(title: "KNOWN ISSUES") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(s.commonIssues, id: \.self) { issue in
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: "#f59e0b")).frame(width: 6, height: 6)
                            Text(issue).font(.system(size: 13, design: .monospaced)).foregroundColor(.motoText)
                        }
                    }
                }
            }
        }.padding(.horizontal, 16)
    }
}

struct SpecBanner: View {
    let icon: String; let color: Color; let title: String; let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(color)
                Text(value).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1)).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct SpecSection<Content: View>: View {
    let title: String; @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
            VStack(spacing: 0) { content() }
                .padding(12).background(Color.motoCard).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
        }
    }
}

struct SpecRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted)
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 7)
        .overlay(Divider().background(Color.motoBorder).padding(.leading, 0), alignment: .bottom)
    }
}

#Preview { SpecsView().environmentObject(AppStateManager()) }
