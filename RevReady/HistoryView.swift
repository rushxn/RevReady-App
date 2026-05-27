import SwiftUI

// MARK: - FEATURE 3: Scan History Screen
struct HistoryView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var showClearConfirm = false
    @State private var selectedScan: SavedScan? = nil

    var store: ScanHistoryStore { appState.historyStore }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if store.scans.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        healthTrendChart
                        scanList
                    }
                }
            }
        }
        .background(Color.motoBg.ignoresSafeArea())
        .sheet(item: $selectedScan) { scan in
            ScanDetailSheet(scan: scan)
        }
        .confirmationDialog("Clear all scan history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) { store.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Nav
    var navBar: some View {
        HStack {
            Button { appState.navigate(to: .dashboard) } label: {
                Image(systemName: "arrow.left").font(.system(size: 16, weight: .bold)).foregroundColor(.motoText)
                    .frame(width: 36, height: 36).background(Color.motoCard).clipShape(Circle())
                    .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Scan History").font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white)
                Text("\(store.scans.count) saved scan\(store.scans.count != 1 ? "s" : "")")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
            }.padding(.leading, 4)
            Spacer()
            if !store.scans.isEmpty {
                Button { showClearConfirm = true } label: {
                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.motoMuted)
                        .frame(width: 36, height: 36).background(Color.motoCard).clipShape(Circle())
                        .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
    }

    // MARK: Health trend mini-chart
    var healthTrendChart: some View {
        let scans = Array(store.scans.prefix(8).reversed())
        guard scans.count >= 2 else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("HEALTH TREND")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    .padding(.horizontal, 20)
                GeometryReader { geo in
                    let w = geo.size.width - 32
                    let h: CGFloat = 80
                    let pts = scans.enumerated().map { i, s -> CGPoint in
                        let x = w / CGFloat(max(scans.count - 1, 1)) * CGFloat(i)
                        let y = h - (CGFloat(s.healthScore) / 100.0 * h)
                        return CGPoint(x: x + 16, y: y + 10)
                    }
                    ZStack {
                        // Line
                        Path { path in
                            guard let first = pts.first else { return }
                            path.move(to: first)
                            pts.dropFirst().forEach { path.addLine(to: $0) }
                        }
                        .stroke(Color.motoOrange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        // Dots
                        ForEach(Array(pts.enumerated()), id: \.offset) { i, pt in
                            Circle().fill(scans[i].healthColor).frame(width: 8, height: 8)
                                .position(pt)
                        }

                        // Labels
                        ForEach(Array(pts.enumerated()), id: \.offset) { i, pt in
                            Text("\(scans[i].healthScore)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.motoMuted)
                                .position(x: pt.x, y: pt.y - 14)
                        }
                    }
                    .frame(height: h + 30)
                }
                .frame(height: 110)
                .padding(.horizontal, 0)
            }
            .padding(.bottom, 6)
        )
    }

    // MARK: Scan list
    var scanList: some View {
        VStack(spacing: 8) {
            Text("ALL SCANS")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            ForEach(store.scans) { scan in
                Button { selectedScan = scan } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scan.bikeModel)
                                .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                            HStack(spacing: 8) {
                                Text(scan.formattedDate)
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
                                if scan.findingCount > 0 {
                                    Text("· \(scan.findingCount) issue\(scan.findingCount != 1 ? "s" : "")")
                                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(scan.healthScore)")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundColor(scan.healthColor)
                            Text(scan.findingCount == 0 ? "Clean" : scan.urgency)
                                .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
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
        .padding(.bottom, 40)
    }

    // MARK: Empty state
    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.motoCard).frame(width: 80, height: 80)
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 32)).foregroundColor(.motoMuted)
            }
            Text("No scans yet").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.white)
            Text("Complete a visual scan and\nyour results will appear here.")
                .font(.system(size: 13, design: .monospaced)).foregroundColor(.motoMuted).multilineTextAlignment(.center)
            Button { appState.resetScan(); appState.navigate(to: .camera) } label: {
                Label("Start First Scan", systemImage: "camera.viewfinder")
                    .font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.motoOrange).cornerRadius(14)
            }.padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Scan detail bottom sheet
struct ScanDetailSheet: View {
    let scan: SavedScan
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    // Score
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HEALTH SCORE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(scan.healthScore)").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundColor(scan.healthColor)
                                Text("/100").font(.system(size: 13, design: .monospaced)).foregroundColor(.motoMuted)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("STATUS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            Text(scan.urgency).font(.system(size: 13, weight: .black, design: .monospaced)).foregroundColor(.motoOrange)
                        }
                    }
                    .padding(14).background(Color.motoCard).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.motoBorder, lineWidth: 1))

                    // Summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SUMMARY").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                        Text(scan.summary).font(.system(size: 13, design: .monospaced)).foregroundColor(.motoText).lineSpacing(4)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.motoCard).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))

                    // Findings
                    if !scan.findings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FINDINGS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            ForEach(scan.findings) { f in
                                HStack(spacing: 10) {
                                    Circle().fill(f.severity.color).frame(width: 8, height: 8)
                                    Text(f.name).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                    Spacer()
                                    Text(f.part.uppercased()).font(.system(size: 9, design: .monospaced)).foregroundColor(.motoMuted)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(Color.motoSurface).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.motoBorder, lineWidth: 1))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.motoBg)
            .navigationTitle(scan.bikeModel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.motoOrange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview { HistoryView().environmentObject(AppStateManager()) }
