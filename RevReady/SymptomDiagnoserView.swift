import SwiftUI

struct SymptomDiagnoserView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var symptomText = ""
    @State private var additionalContext = ""
    @State private var isLoading = false
    @State private var result: SymptomDiagnosisResult? = nil
    @State private var errorMsg: String? = nil
    @State private var loadingProgress = 0.0

    let quickSymptoms = [
        "Won't start", "Dies at idle", "Bogs under throttle",
        "White smoke", "Overheating", "Clicking noise", "Hard to kick",
        "Loses power at high RPM", "Fuel leak", "Starts only with choke"
    ]

    var body: some View {
        VStack(spacing: 0) {
            NavBar("Symptom Diagnoser", subtitle: appState.selectedBikeString,
                   onBack: { appState.navigate(to: .dashboard) })
            if let r = result { resultView(r) }
            else if isLoading { loadingView }
            else { inputView }
        }
        .background(Color.motoBg.ignoresSafeArea())
    }

    // MARK: Input
    var inputView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick picks
                VStack(alignment: .leading, spacing: 10) {
                    Text("QUICK SYMPTOMS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(quickSymptoms, id: \.self) { s in
                            Button { symptomText = s } label: {
                                Text(s).font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(symptomText == s ? .white : .motoText)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(symptomText == s ? Color.motoOrange : Color.motoCard)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(symptomText == s ? Color.motoOrange : Color.motoBorder, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(.horizontal, 16)

                // Custom input
                VStack(alignment: .leading, spacing: 8) {
                    Text("OR DESCRIBE SYMPTOM").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    ZStack(alignment: .topLeading) {
                        if symptomText.isEmpty {
                            Text("e.g. 'sputters at half throttle and smells rich'")
                                .font(.system(size: 13, design: .monospaced)).foregroundColor(.motoMuted).padding(12)
                        }
                        TextEditor(text: $symptomText)
                            .font(.system(size: 13, design: .monospaced)).foregroundColor(.white)
                            .frame(minHeight: 70).padding(8)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Color.motoCard).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                }.padding(.horizontal, 16)

                // Extra context
                VStack(alignment: .leading, spacing: 8) {
                    Text("ADDITIONAL CONTEXT (OPTIONAL)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    ZStack(alignment: .topLeading) {
                        if additionalContext.isEmpty {
                            Text("e.g. 'cold only, carb bike, recent top end rebuild, sea level'")
                                .font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted).padding(12)
                        }
                        TextEditor(text: $additionalContext)
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.white)
                            .frame(minHeight: 60).padding(8).scrollContentBackground(.hidden)
                    }
                    .background(Color.motoCard).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                }.padding(.horizontal, 16)

                if let err = errorMsg {
                    Text(err).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: "#ef4444"))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#1a0a0a")).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#3a1a1a"), lineWidth: 1))
                        .padding(.horizontal, 16)
                }

                Button {
                    guard !symptomText.isEmpty else { return }
                    Task { await diagnose() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg").font(.system(size: 17, weight: .bold))
                        Text(symptomText.isEmpty ? "Select or Describe a Symptom" : "Diagnose: \"\(symptomText.prefix(25))\(symptomText.count > 25 ? "…" : "")\"")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(symptomText.isEmpty ? .motoMuted : .white)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(symptomText.isEmpty ? Color.motoCard : Color(hex: "#ef4444")).cornerRadius(16)
                }
                .disabled(symptomText.isEmpty)
                .padding(.horizontal, 16).padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: symptomText.isEmpty)
            }.padding(.top, 4)
        }
    }

    // MARK: Loading
    var loadingView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(Color.motoBorder, lineWidth: 3).frame(width: 72, height: 72)
                Circle().trim(from: 0, to: CGFloat(loadingProgress))
                    .stroke(Color(hex: "#ef4444"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 72, height: 72).rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                Image(systemName: "waveform.path.ecg").font(.system(size: 24)).foregroundColor(Color(hex: "#ef4444"))
            }
            VStack(spacing: 6) {
                Text("Analyzing Symptom…").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text("Ranking probable causes").font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted)
            }
            Spacer()
        }.background(Color.motoBg)
    }

    // MARK: Results
    func resultView(_ r: SymptomDiagnosisResult) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // Safe to ride banner
                HStack(spacing: 12) {
                    Image(systemName: r.safeToRide ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .font(.system(size: 24)).foregroundColor(r.safeToRide ? Color(hex: "#4ade80") : Color(hex: "#ef4444"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.safeToRide ? "Safe to ride with caution" : "DO NOT RIDE")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(r.safeToRide ? Color(hex: "#4ade80") : Color(hex: "#ef4444"))
                        Text(r.immediateAction).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoText).lineSpacing(2)
                    }
                }
                .padding(14).background(Color.motoCard).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(r.safeToRide ? Color(hex: "#4ade80").opacity(0.3) : Color(hex: "#ef4444").opacity(0.3), lineWidth: 1))

                Text("PROBABLE CAUSES").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(r.causes) { cause in CauseCard(cause: cause) }

                Button { result = nil; errorMsg = nil } label: {
                    Label("Diagnose Another Symptom", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "#ef4444")).cornerRadius(14)
                }
            }.padding(16).padding(.bottom, 24)
        }
    }

    func diagnose() async {
        isLoading = true; errorMsg = nil; loadingProgress = 0
        let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()
        var prog = 0.0
        let cancellable = timer.sink { _ in if prog < 0.9 { prog += 0.012; loadingProgress = prog } }
        defer { cancellable.cancel() }
        do {
            let r = try await AnthropicService.diagnoseSymptom(
                symptom: symptomText, bikeModel: appState.selectedBikeString,
                additionalContext: additionalContext,
                progressCallback: { _ in }
            )
            loadingProgress = 1.0
            try? await Task.sleep(nanoseconds: 300_000_000)
            result = r
        } catch { errorMsg = error.localizedDescription }
        isLoading = false
    }
}

struct CauseCard: View {
    let cause: SymptomCause
    @State private var expanded = false
    var likelihoodColor: Color {
        cause.likelihood >= 50 ? Color(hex: "#ef4444") : cause.likelihood >= 25 ? Color(hex: "#f59e0b") : Color(hex: "#4ade80")
    }
    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    // Likelihood ring
                    ZStack {
                        Circle().stroke(Color.motoBorder, lineWidth: 2.5).frame(width: 42, height: 42)
                        Circle().trim(from: 0, to: CGFloat(cause.likelihood) / 100)
                            .stroke(likelihoodColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 42, height: 42).rotationEffect(.degrees(-90))
                        Text("\(cause.likelihood)%").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cause.cause).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        HStack(spacing: 8) {
                            diffBadge(cause.difficulty)
                            Text(cause.estimatedCost).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
                        }
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundColor(.motoMuted)
                }
                if expanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider().background(Color.motoBorder).padding(.top, 10)
                        Text(cause.description).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoText).lineSpacing(3)
                        if !cause.toolsNeeded.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TOOLS NEEDED").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                                    ForEach(cause.toolsNeeded, id: \.self) { tool in
                                        HStack(spacing: 4) {
                                            Image(systemName: "wrench").font(.system(size: 9)).foregroundColor(.motoMuted)
                                            Text(tool).font(.system(size: 10, design: .monospaced)).foregroundColor(.motoText)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                        HStack(spacing: 6) {
                            Image(systemName: cause.safeToRide ? "checkmark.circle" : "xmark.circle")
                                .foregroundColor(cause.safeToRide ? Color(hex: "#4ade80") : Color(hex: "#ef4444"))
                            Text(cause.safeToRide ? "Safe to ride while investigating" : "Stop riding — fix first")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(cause.safeToRide ? Color(hex: "#4ade80") : Color(hex: "#ef4444"))
                        }
                    }
                }
            }
            .padding(14).background(Color.motoCard).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(expanded ? likelihoodColor.opacity(0.4) : Color.motoBorder, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    func diffBadge(_ d: String) -> some View {
        let c: Color = d == "Easy" ? Color(hex:"#4ade80") : d == "Moderate" ? Color(hex:"#f59e0b") : d == "Hard" ? Color(hex:"#ef4444") : Color(hex:"#a78bfa")
        return Text(d).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(c)
            .padding(.horizontal, 6).padding(.vertical, 2).background(c.opacity(0.12)).cornerRadius(6)
    }
}

#Preview { SymptomDiagnoserView().environmentObject(AppStateManager()) }
