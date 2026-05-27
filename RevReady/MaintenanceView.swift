import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var showAddItem = false
    @State private var showHoursEditor = false
    @State private var hoursInput = ""

    var store: MaintenanceStore { appState.maintenanceStore }
    var log: MaintenanceLog? { store.logs.first(where: { $0.bikeModel == appState.selectedBikeString }) }

    var defaultItems: [MaintenanceItem] {
        let bike = appState.selectedBikeString
        let specs = BikeSpecs.database[bike]
        return [
            MaintenanceItem(id: UUID(), name: "Engine Oil & Filter", category: .engine, intervalHours: 10, lastServiceHours: 0, notes: specs?.oilType ?? "Check manual"),
            MaintenanceItem(id: UUID(), name: "Air Filter Clean", category: .engine, intervalHours: 10, lastServiceHours: 0, notes: specs?.airFilterInterval ?? ""),
            MaintenanceItem(id: UUID(), name: "Top End Inspection", category: .engine, intervalHours: 80, lastServiceHours: 0, notes: specs?.topEndInterval ?? ""),
            MaintenanceItem(id: UUID(), name: "Bottom End Inspection", category: .engine, intervalHours: 200, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Chain Lubrication", category: .drivetrain, intervalHours: 5, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Chain Tension Check", category: .drivetrain, intervalHours: 5, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Sprocket Inspection", category: .drivetrain, intervalHours: 30, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Fork Oil Change", category: .suspension, intervalHours: 40, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Rear Shock Service", category: .suspension, intervalHours: 80, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Brake Fluid", category: .brakes, intervalHours: 50, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Brake Pad Check", category: .brakes, intervalHours: 10, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Coolant Change", category: .cooling, intervalHours: 100, lastServiceHours: 0, notes: ""),
            MaintenanceItem(id: UUID(), name: "Spark Plug", category: .electrical, intervalHours: 30, lastServiceHours: 0, notes: BikeSpecs.database[bike]?.sparkPlug ?? ""),
        ]
    }

    var currentLog: MaintenanceLog {
        if let l = log { return l }
        return MaintenanceLog(id: UUID(), bikeModel: appState.selectedBikeString,
                              engineHours: store.currentHours, items: defaultItems, lastUpdated: Date())
    }

    var overdueItems: [MaintenanceItem] { currentLog.items.filter { $0.isOverdue } }

    var body: some View {
        VStack(spacing: 0) {
            NavBar("Maintenance Tracker", subtitle: appState.selectedBikeString, onBack: { appState.navigate(to: .dashboard) },
                   trailing: AnyView(Button { showHoursEditor = true } label: {
                       HStack(spacing: 4) {
                           Image(systemName: "timer").font(.system(size: 13)).foregroundColor(.motoOrange)
                           Text("\(Int(store.currentHours))h").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
                       }
                       .padding(.horizontal, 10).padding(.vertical, 6).background(Color.motoOrange.opacity(0.1)).cornerRadius(10)
                   }))
            ScrollView {
                VStack(spacing: 14) {
                    // Hours bar
                    engineHoursCard

                    // Overdue alert
                    if !overdueItems.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Color(hex: "#ef4444"))
                            Text("\(overdueItems.count) item\(overdueItems.count != 1 ? "s" : "") overdue!")
                                .font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#ef4444"))
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#1a0a0a")).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#ef4444").opacity(0.4), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }

                    // Grouped by category
                    ForEach(MaintenanceCategory.allCases, id: \.self) { cat in
                        let items = currentLog.items.filter { $0.category == cat }
                        if !items.isEmpty {
                            categorySection(cat, items: items)
                        }
                    }
                }.padding(.top, 4).padding(.bottom, 40)
            }
        }
        .background(Color.motoBg.ignoresSafeArea())
        .alert("Update Engine Hours", isPresented: $showHoursEditor) {
            TextField("Hours", text: $hoursInput).keyboardType(.decimalPad)
            Button("Save") {
                if let h = Double(hoursInput) { store.updateHours(h) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enter current engine hours") }
        .onAppear {
            hoursInput = String(format: "%.0f", store.currentHours)
            if log == nil { store.save(currentLog) }
        }
    }

    var engineHoursCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ENGINE HOURS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", store.currentHours))
                        .font(.system(size: 36, weight: .black, design: .monospaced)).foregroundColor(.white)
                    Text("hrs").font(.system(size: 14, design: .monospaced)).foregroundColor(.motoMuted)
                }
            }
            Spacer()
            Button {
                store.updateHours(store.currentHours + 1)
                hoursInput = String(format: "%.0f", store.currentHours)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundColor(.motoOrange)
                    Text("+1 hr").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                }
            }
        }
        .padding(16).background(Color.motoCard).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.motoBorder, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    func categorySection(_ cat: MaintenanceCategory, items: [MaintenanceItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon).font(.system(size: 12)).foregroundColor(.motoOrange)
                Text(cat.rawValue.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
            }.padding(.horizontal, 20)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    MaintenanceRow(item: item) {
                        guard let l = log else { return }
                        store.markServiced(logId: l.id, itemId: item.id)
                    }
                }
            }.padding(.horizontal, 16)
        }
    }
}

struct MaintenanceRow: View {
    let item: MaintenanceItem; let onService: () -> Void
    var barColor: Color {
        item.isOverdue ? Color(hex: "#ef4444") : item.percentUsed > 0.8 ? Color(hex: "#f59e0b") : Color(hex: "#4ade80")
    }
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if item.isOverdue {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11)).foregroundColor(Color(hex: "#ef4444"))
                    }
                    Text(item.name).font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(item.isOverdue ? Color(hex: "#ef4444") : .white)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.motoBorder).frame(height: 3)
                        RoundedRectangle(cornerRadius: 2).fill(barColor)
                            .frame(width: g.size.width * min(item.percentUsed, 1.0), height: 3)
                    }
                }.frame(height: 3)
                Text(item.isOverdue ? "OVERDUE by \(Int(abs(item.hoursUntilDue)))h" :
                        "Due in \(String(format: "%.0f", item.hoursUntilDue))h · every \(Int(item.intervalHours))h")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(item.isOverdue ? Color(hex: "#ef4444") : .motoMuted)
            }
            Spacer()
            Button(action: onService) {
                Text("Done").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.motoOrange).cornerRadius(8)
            }
        }
        .padding(12).background(Color.motoCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(item.isOverdue ? Color(hex: "#ef4444").opacity(0.4) : Color.motoBorder, lineWidth: 1))
    }
}

#Preview { MaintenanceView().environmentObject(AppStateManager()) }
