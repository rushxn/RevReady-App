import SwiftUI

struct ResultView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var animated  = false
    @State private var expanded: Set<UUID> = []
    // FEATURE 4: share sheet
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var result: DiagnosticResult? { appState.diagnosticResult }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navBar
                if let r = result {
                    scores(r)
                    aiBox(r)
                    if let note = r.confidenceNote { confidenceCard(note) }
                    if appState.capturedPhotos.count < 3 { rescanNudge }
                    findingsSection(r)
                    buttons
                }
            }
        }
        .background(Color.motoBg.ignoresSafeArea())
        .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.2)) { animated = true } }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: Nav
    var navBar: some View {
        HStack {
            Button { appState.navigate(to: .dashboard); appState.resetScan() } label: {
                Image(systemName: "arrow.left").font(.system(size: 16, weight: .bold)).foregroundColor(.motoText)
                    .frame(width: 36, height: 36).background(Color.motoCard).clipShape(Circle())
                    .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan Results").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text("\(appState.capturedPhotos.count) photo\(appState.capturedPhotos.count != 1 ? "s" : "") · \(appState.selectedBikeString)")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
            }.padding(.leading, 4)
            Spacer()
            // FEATURE 4: share button
            Button { prepareAndShare() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.motoOrange)
                    .frame(width: 36, height: 36).background(Color.motoCard).clipShape(Circle())
                    .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 14)
    }

    // MARK: Score cards
    func scores(_ r: DiagnosticResult) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("BIKE HEALTH").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(r.healthScore)").font(.system(size: 30, weight: .black, design: .monospaced)).foregroundColor(r.healthColor)
                    Text("/100").font(.system(size: 13, design: .monospaced)).foregroundColor(.motoDim)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.motoBorder).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(r.healthColor)
                            .frame(width: animated ? g.size.width * Double(r.healthScore)/100 : 0, height: 3)
                            .animation(.easeOut(duration: 0.9), value: animated)
                    }
                }.frame(height: 3)
                Text("visual estimate only")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.motoDim)
                    .padding(.top, 2)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.motoCard).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.motoBorder, lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("STATUS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                Text(r.urgency).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(r.urgencyColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(r.urgencyColor).frame(width: 6, height: 6)
                    Text("\(r.findings.count) issue\(r.findings.count != 1 ? "s" : "")")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.motoCard).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.motoBorder, lineWidth: 1))
        }
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    // MARK: AI summary
    func aiBox(_ r: DiagnosticResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "brain").font(.system(size: 11)).foregroundColor(.motoOrange)
                Text("AI VISUAL ANALYSIS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
            }
            Text(r.summary).font(.system(size: 13, design: .monospaced)).foregroundColor(.motoText).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.motoSurface).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
            LinearGradient(colors: [Color.motoOrange.opacity(0.5), Color.motoBorder],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 14)
    }

    // MARK: Rescan nudge (shown when < 3 photos)
    var rescanNudge: some View {
        let count = appState.capturedPhotos.count
        let extra = 3 - count
        return Button {
            appState.resetScan()
            appState.navigate(to: .camera)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.motoOrange.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 16)).foregroundColor(.motoOrange)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Want a more accurate score?")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("You used \(count) photo\(count != 1 ? "s" : ""). Add \(extra) more from different angles — engine, exhaust, chain, forks — for a better reading.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.motoMuted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.motoOrange)
            }
            .padding(14)
            .background(Color.motoCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.motoOrange.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: Confidence note
    func confidenceCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "camera.badge.exclamationmark")
                .font(.system(size: 15)).foregroundColor(Color(hex: "#f59e0b"))
                .padding(.top, 1)
            Text(note)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "#f59e0b"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#f59e0b").opacity(0.07))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#f59e0b").opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    // MARK: Findings
    func findingsSection(_ r: DiagnosticResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if r.findings.isEmpty {
                allClear
            } else {
                Text("FINDINGS").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    .padding(.horizontal, 20)
                ForEach(r.findings) { f in
                    FindingCard(finding: f, isExpanded: expanded.contains(f.id)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expanded.contains(f.id) { expanded.remove(f.id) } else { expanded.insert(f.id) }
                        }
                    }.padding(.horizontal, 16)
                }
            }
        }.padding(.bottom, 14)
    }

    var allClear: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "#4ade80").opacity(0.1)).frame(width: 64, height: 64)
                Image(systemName: "checkmark.seal.fill").font(.system(size: 28)).foregroundColor(Color(hex: "#4ade80"))
            }
            Text("No issues detected").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(Color(hex: "#4ade80"))
            Text("Your bike looks sound. Ready to ride.")
                .font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
        .background(Color(hex: "#0a1a0a")).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#1a3a1a"), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: Buttons
    var buttons: some View {
        VStack(spacing: 10) {
            Button { appState.resetScan(); appState.navigate(to: .camera) } label: {
                Label("Scan Again", systemImage: "camera.viewfinder")
                    .font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.motoOrange).cornerRadius(14)
            }
            Button { appState.navigate(to: .history) } label: {
                Label("View Scan History", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.motoText)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.motoCard).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
            }
        }.padding(.horizontal, 16).padding(.bottom, 44)
    }

    // MARK: FEATURE 4 — Build share text
    func prepareAndShare() {
        guard let r = result else { return }
        var text = "🏍️ RevReady Scan Report\n"
        text += "Bike: \(appState.selectedBikeString)\n"
        text += "Health Score: \(r.healthScore)/100\n"
        text += "Status: \(r.urgency)\n\n"
        text += "Summary:\n\(r.summary)\n"
        if !r.findings.isEmpty {
            text += "\nFindings (\(r.findings.count)):\n"
            for (i, f) in r.findings.enumerated() {
                text += "\n\(i+1). \(f.name) [\(f.severity.rawValue)]\n"
                text += "   \(f.description)\n"
                text += "   Fix: \(f.action)\n"
                if let diy = f.diyCost, let shop = f.shopCost {
                    text += "   Cost: \(diy) DIY · \(shop) shop\n"
                }
            }
        }
        text += "\nGenerated by RevReady"
        shareItems = [text]
        showShare = true
    }
}

// MARK: - Finding Card (FEATURE 2: cost + DIY badge)
struct FindingCard: View {
    let finding: DiagnosticFinding
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 10) {
                    Circle().fill(finding.severity.color).frame(width: 8, height: 8)
                        .shadow(color: finding.severity.glowColor, radius: 4)
                    Text(finding.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(finding.part.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(Color.motoBorder).cornerRadius(6)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.motoMuted)
                }

                // FEATURE 2: Cost row (always visible)
                if let diy = finding.diyCost, let shop = finding.shopCost {
                    HStack(spacing: 8) {
                        // DIY badge
                        HStack(spacing: 4) {
                            Image(systemName: finding.canDIY == true ? "wrench.and.screwdriver.fill" : "building.2.fill")
                                .font(.system(size: 9))
                            Text(finding.canDIY == true ? "DIY \(diy)" : "Shop \(shop)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(finding.canDIY == true ? Color(hex: "#4ade80") : Color(hex: "#f59e0b"))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((finding.canDIY == true ? Color(hex: "#4ade80") : Color(hex: "#f59e0b")).opacity(0.12))
                        .cornerRadius(8)

                        if finding.canDIY == true {
                            Text("Shop: \(shop)")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.motoMuted)
                        } else {
                            Text("DIY parts: \(diy)")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.motoMuted)
                        }
                    }
                    .padding(.top, 8)
                }

                // Expanded detail
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        Divider().background(Color.motoBorder).padding(.top, 10)
                        Text(finding.description)
                            .font(.system(size: 12, design: .monospaced)).foregroundColor(.motoText).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver").font(.system(size: 11)).foregroundColor(.motoOrange)
                            Text(finding.action)
                                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(finding.severity.color).frame(width: 6, height: 6)
                            Text("\(finding.severity.rawValue) severity")
                                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(finding.severity.color)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(finding.severity.color.opacity(0.1)).cornerRadius(8)
                    }
                }
            }
            .padding(14).background(Color.motoCard).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isExpanded ? finding.severity.color.opacity(0.4) : Color.motoBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FEATURE 4: Share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

#Preview { ResultView().environmentObject(AppStateManager()) }
