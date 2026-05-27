import SwiftUI

struct PrePurchaseView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var items: [InspectionItem] = Self.defaultItems()
    @State private var verdict: String? = nil

    var passCount: Int  { items.filter { $0.status == .pass }.count }
    var failCount: Int  { items.filter { $0.status == .fail }.count }
    var warnCount: Int  { items.filter { $0.status == .warning }.count }
    var doneCount: Int  { items.filter { $0.status != .unchecked }.count }
    var total: Int      { items.count }

    var body: some View {
        VStack(spacing: 0) {
            NavBar("Pre-Purchase Check", subtitle: "Buyer's inspection checklist", onBack: { appState.navigate(to: .dashboard) })
            ScrollView {
                VStack(spacing: 14) {
                    // Progress summary
                    summaryCard

                    // Checklist by category
                    let categories = Array(Set(items.map { $0.category })).sorted()
                    ForEach(categories, id: \.self) { cat in
                        categorySection(cat)
                    }

                    // Verdict
                    if doneCount == total { verdictCard }

                    Button { items = Self.defaultItems(); verdict = nil } label: {
                        Label("Reset Checklist", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.motoCard).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                    }.padding(.horizontal, 16)
                }.padding(.top, 4).padding(.bottom, 40)
            }
        }.background(Color.motoBg.ignoresSafeArea())
    }

    var summaryCard: some View {
        HStack(spacing: 0) {
            statPill("\(passCount)", "Pass", Color(hex: "#4ade80"))
            statPill("\(warnCount)", "Warn", Color(hex: "#f59e0b"))
            statPill("\(failCount)", "Fail", Color(hex: "#ef4444"))
            statPill("\(total - doneCount)", "Left", Color(hex: "#888"))
        }
        .padding(12).background(Color.motoCard).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    func statPill(_ val: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(val).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
        }.frame(maxWidth: .infinity)
    }

    func categorySection(_ cat: String) -> some View {
        return VStack(alignment: .leading, spacing: 8) {
            Text(cat.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                .padding(.horizontal, 20)
            VStack(spacing: 8) {
                ForEach($items.filter { $0.wrappedValue.category == cat }) { $item in
                    InspectionRow(item: $item)
                }
            }.padding(.horizontal, 16)
        }
    }

    var verdictCard: some View {
        let isPass = failCount == 0
        let hasWarnings = warnCount > 0
        let title = isPass ? (hasWarnings ? "BUY / NEGOTIATE" : "BUY") : "WALK AWAY"
        let msg = isPass
            ? (hasWarnings ? "Minor issues found — use as negotiation leverage. Get a price reduction for repairs." : "Bike passed all checks. Looks like a solid purchase.")
            : "Critical failures found. This bike needs significant work. Walk away or price accordingly."
        let color: Color = isPass ? (hasWarnings ? Color(hex: "#f59e0b") : Color(hex: "#4ade80")) : Color(hex: "#ef4444")
        return VStack(spacing: 10) {
            Text(title).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundColor(color)
            Text(msg).font(.system(size: 13, design: .monospaced)).foregroundColor(.motoText).lineSpacing(4).multilineTextAlignment(.center)
            if hasWarnings && isPass {
                Text("Estimated repair cost: check findings above")
                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
            }
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(color.opacity(0.08)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.4), lineWidth: 2))
        .padding(.horizontal, 16)
    }

    static func defaultItems() -> [InspectionItem] {
        [
            InspectionItem(category: "Frame & Structure", item: "Frame for cracks/bends", how: "Inspect headstock, swingarm pivot, down tube. Look for cracks at welds."),
            InspectionItem(category: "Frame & Structure", item: "Subframe straight", how: "Step back and look from behind — should be dead straight."),
            InspectionItem(category: "Frame & Structure", item: "VIN plate present & legible", how: "Check frame VIN matches title documents."),
            InspectionItem(category: "Engine", item: "Starts first or second kick", how: "Cold start test. Should start without excessive effort."),
            InspectionItem(category: "Engine", item: "Idles smoothly", how: "Let warm up 3–5 min. Should idle without choke, no hanging revs."),
            InspectionItem(category: "Engine", item: "No smoke at idle", how: "White smoke = coolant. Blue = oil burning. Some initial smoke OK."),
            InspectionItem(category: "Engine", item: "No unusual engine noise", how: "Listen for rod knock, valve tick, piston slap, chain rattle."),
            InspectionItem(category: "Engine", item: "Oil is clean, correct level", how: "Check sight glass or dipstick. Dark/milky oil = bad sign."),
            InspectionItem(category: "Engine", item: "No coolant leaks", how: "Inspect hose clamps, radiator, water pump. Look for white residue."),
            InspectionItem(category: "Top End", item: "Compression feels strong", how: "Kick through slowly — should feel firm resistance."),
            InspectionItem(category: "Top End", item: "No blow-by at oil cap", how: "Remove oil cap at idle — minimal smoke = good."),
            InspectionItem(category: "Suspension", item: "Forks not leaking", how: "Look for oil film on inner tubes above dust seals."),
            InspectionItem(category: "Suspension", item: "Fork legs straight", how: "Sight down from above — both legs should be parallel."),
            InspectionItem(category: "Suspension", item: "Rear shock rebounds correctly", how: "Push down on seat and release — should rebound smoothly, not bounce."),
            InspectionItem(category: "Drivetrain", item: "Chain within spec", how: "Lift chain at rear sprocket — should lift 1/2\" max. Check for tight links."),
            InspectionItem(category: "Drivetrain", item: "Sprocket teeth not hooked", how: "Look at front and rear sprocket teeth — should be square, not shark-fin shaped."),
            InspectionItem(category: "Drivetrain", item: "Clutch engages/disengages cleanly", how: "Ride test or hand test — no slipping or dragging."),
            InspectionItem(category: "Brakes", item: "Front brake firm", how: "Squeeze lever — should feel firm with good bite."),
            InspectionItem(category: "Brakes", item: "Rear brake firm", how: "Press pedal — should have resistance and bite."),
            InspectionItem(category: "Brakes", item: "Rotors not warped or scored", how: "Spin wheels and look at rotors — should be smooth, not grooved."),
            InspectionItem(category: "Wheels & Tyres", item: "Spokes tight — no broken", how: "Tap each spoke with screwdriver handle — dull thud = loose. All same pitch = good."),
            InspectionItem(category: "Wheels & Tyres", item: "Tyre tread and condition", how: "Check tread depth and look for cracking, bead damage."),
            InspectionItem(category: "Wheels & Tyres", item: "Wheel bearings smooth", how: "Grab wheel and wiggle side to side — no play allowed."),
            InspectionItem(category: "Plastics & Controls", item: "Bars/triple clamp not bent", how: "Sit on bike and look straight ahead — bars should align with wheel."),
            InspectionItem(category: "Plastics & Controls", item: "All controls function", how: "Test throttle return, levers, perches, kill switch, hot start."),
        ]
    }
}

struct InspectionRow: View {
    @Binding var item: InspectionItem
    @State private var showHow = false

    var statusColor: Color {
        switch item.status {
        case .pass: return Color(hex: "#4ade80")
        case .fail: return Color(hex: "#ef4444")
        case .warning: return Color(hex: "#f59e0b")
        case .unchecked: return Color.motoMuted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.item).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    if showHow {
                        Text(item.how).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoText).lineSpacing(2)
                            .padding(.top, 4)
                    }
                }
                Spacer()
                Button { withAnimation { showHow.toggle() } } label: {
                    Image(systemName: "questionmark.circle").font(.system(size: 14)).foregroundColor(.motoMuted)
                }
            }.padding(.bottom, 8)

            HStack(spacing: 6) {
                statusButton(.pass, "Pass", Color(hex: "#4ade80"))
                statusButton(.warning, "Note", Color(hex: "#f59e0b"))
                statusButton(.fail, "Fail", Color(hex: "#ef4444"))
            }
        }
        .padding(12).background(Color.motoCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            item.status == .unchecked ? Color.motoBorder : statusColor.opacity(0.4), lineWidth: 1))
    }

    func statusButton(_ s: InspectionStatus, _ label: String, _ c: Color) -> some View {
        Button { item.status = item.status == s ? .unchecked : s } label: {
            Text(label).font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(item.status == s ? .white : c)
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(item.status == s ? c : c.opacity(0.1)).cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(c.opacity(0.3), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

#Preview { PrePurchaseView().environmentObject(AppStateManager()) }
