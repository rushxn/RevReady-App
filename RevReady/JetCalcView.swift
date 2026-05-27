import SwiftUI

struct JetCalcView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var elevation: Double = 0       // feet
    @State private var temperature: Double = 70    // °F
    @State private var humidity: Double = 50       // %
    @State private var baseMainJet: Double = 180
    @State private var basePilotJet: Double = 48
    @State private var isTwoStroke = false

    var airDensityFactor: Double {
        let altFactor = 1.0 - (elevation / 1000.0) * 0.03
        let tempFactor = 1.0 - (temperature - 60.0) / 100.0 * 0.02
        let humFactor  = 1.0 - (humidity / 100.0) * 0.012
        return altFactor * tempFactor * humFactor
    }

    var recommendedMainJet: Int { Int(baseMainJet * airDensityFactor / 2.5) * (isTwoStroke ? 2 : 2) }
    var recommendedPilotJet: Int { Int(basePilotJet * airDensityFactor) }

    var adjustedMain: Int {
        let raw = baseMainJet * airDensityFactor
        return Int((raw / 2).rounded()) * 2
    }
    var adjustedPilot: Int {
        let raw = basePilotJet * airDensityFactor
        return Int(raw.rounded())
    }
    var mainDelta: Int { adjustedMain - Int(baseMainJet) }
    var pilotDelta: Int { adjustedPilot - Int(basePilotJet) }

    var condition: String {
        if elevation > 5000 && temperature > 85 { return "Very lean conditions — go significantly smaller" }
        if elevation > 3000 { return "High altitude — leaner jetting needed" }
        if elevation < 500 && temperature < 50 { return "Dense air — slightly richer jetting" }
        return "Moderate conditions"
    }

    var body: some View {
        VStack(spacing: 0) {
            NavBar("Jetting Calculator", subtitle: "Altitude & temperature compensation", onBack: { appState.navigate(to: .dashboard) })
            ScrollView {
                VStack(spacing: 16) {
                    // Stroke type toggle
                    HStack(spacing: 0) {
                        Button { isTwoStroke = false } label: {
                            Text("4-Stroke").font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(!isTwoStroke ? .white : .motoMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(!isTwoStroke ? Color.motoOrange : Color.motoCard)
                        }
                        Button { isTwoStroke = true } label: {
                            Text("2-Stroke").font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(isTwoStroke ? .white : .motoMuted)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(isTwoStroke ? Color.motoOrange : Color.motoCard)
                        }
                    }
                    .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Base jets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BASE JETTING (SEA LEVEL, 70°F)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                        sliderRow("Main Jet", value: $baseMainJet, range: isTwoStroke ? 100...300 : 140...220, step: isTwoStroke ? 2 : 2, unit: "")
                        sliderRow("Pilot Jet", value: $basePilotJet, range: isTwoStroke ? 25...60 : 35...60, step: 2, unit: "")
                    }.padding(14).background(Color.motoCard).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Conditions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RIDING CONDITIONS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                        sliderRow("Elevation", value: $elevation, range: 0...14000, step: 500, unit: "ft")
                        sliderRow("Temperature", value: $temperature, range: 20...110, step: 5, unit: "°F")
                        sliderRow("Humidity", value: $humidity, range: 0...100, step: 5, unit: "%")
                    }.padding(14).background(Color.motoCard).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Results
                    VStack(spacing: 10) {
                        Text("RECOMMENDED JETTING").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 10) {
                            jetResultCard("MAIN JET", value: adjustedMain, delta: mainDelta)
                            jetResultCard("PILOT JET", value: adjustedPilot, delta: pilotDelta)
                        }

                        // Air density bar
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("AIR DENSITY").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                                Spacer()
                                Text(String(format: "%.1f%%", airDensityFactor * 100))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
                            }
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.motoBorder)
                                    RoundedRectangle(cornerRadius: 3).fill(Color.motoOrange)
                                        .frame(width: g.size.width * airDensityFactor)
                                }
                            }.frame(height: 6)
                        }

                        // Condition note
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").font(.system(size: 14)).foregroundColor(.motoOrange)
                            Text(condition).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoText).lineSpacing(2)
                        }
                        .padding(12).background(Color.motoOrange.opacity(0.06)).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoOrange.opacity(0.2), lineWidth: 1))

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TUNING NOTES").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            tuningNote("Pilot jet affects idle and 0–1/4 throttle response")
                            tuningNote("Main jet affects 3/4–full throttle")
                            tuningNote("Needle clip affects 1/4–3/4 throttle (raise clip = richer)")
                            if isTwoStroke { tuningNote("2-stroke: adjust premix ratio to quality of fuel too") }
                        }.padding(12).background(Color.motoCard).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                    }.padding(.horizontal, 16)

                }.padding(.top, 4).padding(.bottom, 40)
            }
        }.background(Color.motoBg.ignoresSafeArea())
    }

    func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted)
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
            }
            Slider(value: value, in: range, step: step).tint(.motoOrange)
        }
    }

    func jetResultCard(_ label: String, value: Int, delta: Int) -> some View {
        VStack(spacing: 6) {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
            Text("\(value)").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundColor(.white)
            HStack(spacing: 3) {
                Image(systemName: delta < 0 ? "arrow.down" : delta > 0 ? "arrow.up" : "minus")
                    .font(.system(size: 10, weight: .bold))
                Text(delta == 0 ? "No change" : "\(abs(delta)) from base")
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(delta < 0 ? Color(hex: "#4ade80") : delta > 0 ? Color(hex: "#f59e0b") : .motoMuted)
        }
        .frame(maxWidth: .infinity).padding(14).background(Color.motoCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
    }

    func tuningNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(Color.motoOrange).frame(width: 5, height: 5).padding(.top, 5)
            Text(text).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoText).lineSpacing(2)
        }
    }
}

#Preview { JetCalcView().environmentObject(AppStateManager()) }
