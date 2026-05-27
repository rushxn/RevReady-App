import SwiftUI

struct RepairGuide: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let difficulty: String
    let estimatedTime: String
    let toolsNeeded: [String]
    let steps: [GuideStep]
    let torqueSpecs: [String: String]
    let warnings: [String]
}

struct GuideStep: Identifiable {
    let id = UUID()
    let step: Int
    let title: String
    let detail: String
    let tip: String?
}

struct RepairGuidesView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var selectedGuide: RepairGuide? = nil
    @State private var selectedCategory = "All"
    @State private var currentStep = 0

    let categories = ["All", "Engine", "Suspension", "Brakes", "Drivetrain", "Carb/Fuel"]

    var filteredGuides: [RepairGuide] {
        if selectedCategory == "All" { return guides }
        return guides.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavBar("Repair Guides", subtitle: "Step-by-step walkthroughs", onBack: {
                if selectedGuide != nil { selectedGuide = nil; currentStep = 0 }
                else { appState.navigate(to: .dashboard) }
            })
            if let guide = selectedGuide { guideDetail(guide) }
            else { guideList }
        }.background(Color.motoBg.ignoresSafeArea())
    }

    var guideList: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button { selectedCategory = cat } label: {
                            Text(cat).font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(selectedCategory == cat ? .white : .motoMuted)
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(selectedCategory == cat ? Color.motoOrange : Color.motoCard)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategory == cat ? Color.motoOrange : Color.motoBorder, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }.padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredGuides) { guide in
                        Button { selectedGuide = guide; currentStep = 0 } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(guide.title).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                    HStack(spacing: 10) {
                                        diffTag(guide.difficulty)
                                        HStack(spacing: 3) {
                                            Image(systemName: "clock").font(.system(size: 10)).foregroundColor(.motoMuted)
                                            Text(guide.estimatedTime).font(.system(size: 10, design: .monospaced)).foregroundColor(.motoMuted)
                                        }
                                        HStack(spacing: 3) {
                                            Image(systemName: "list.bullet").font(.system(size: 10)).foregroundColor(.motoMuted)
                                            Text("\(guide.steps.count) steps").font(.system(size: 10, design: .monospaced)).foregroundColor(.motoMuted)
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(.motoMuted)
                            }
                            .padding(14).background(Color.motoCard).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 40)
            }
        }
    }

    func diffTag(_ d: String) -> some View {
        let c: Color = d == "Easy" ? Color(hex:"#4ade80") : d == "Moderate" ? Color(hex:"#f59e0b") : d == "Hard" ? Color(hex:"#ef4444") : Color(hex:"#a78bfa")
        return Text(d).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(c)
            .padding(.horizontal, 6).padding(.vertical, 2).background(c.opacity(0.12)).cornerRadius(6)
    }

    func guideDetail(_ guide: RepairGuide) -> some View {
        VStack(spacing: 0) {
            // Step progress
            HStack(spacing: 6) {
                ForEach(0..<guide.steps.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= currentStep ? Color.motoOrange : Color.motoBorder)
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }.padding(.horizontal, 16).padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 14) {
                    if currentStep == 0 {
                        // Overview
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                diffTag(guide.difficulty)
                                Text(guide.estimatedTime).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
                                Spacer()
                            }
                            if !guide.warnings.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("WARNINGS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#ef4444"))
                                    ForEach(guide.warnings, id: \.self) { w in
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundColor(Color(hex: "#ef4444"))
                                            Text(w).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoText).lineSpacing(2)
                                        }
                                    }
                                }.padding(12).background(Color(hex: "#1a0a0a")).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#ef4444").opacity(0.3), lineWidth: 1))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TOOLS NEEDED").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                    ForEach(guide.toolsNeeded, id: \.self) { tool in
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle").font(.system(size: 12)).foregroundColor(.motoOrange)
                                            Text(tool).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoText)
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }.padding(12).background(Color.motoCard).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                            if !guide.torqueSpecs.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("TORQUE SPECS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                                    ForEach(Array(guide.torqueSpecs.keys.sorted()), id: \.self) { k in
                                        HStack {
                                            Text(k).font(.system(size: 12, design: .monospaced)).foregroundColor(.motoMuted)
                                            Spacer()
                                            Text(guide.torqueSpecs[k] ?? "").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.motoOrange)
                                        }
                                    }
                                }.padding(12).background(Color.motoCard).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.motoBorder, lineWidth: 1))
                            }
                        }.padding(.horizontal, 16)
                    } else {
                        let step = guide.steps[currentStep - 1]
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(Color.motoOrange).frame(width: 32, height: 32)
                                    Text("\(step.step)").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                                }
                                Text(step.title).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.white)
                            }
                            Text(step.detail).font(.system(size: 14, design: .monospaced)).foregroundColor(.motoText).lineSpacing(5)
                            if let tip = step.tip {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill").font(.system(size: 14)).foregroundColor(Color(hex: "#f59e0b"))
                                    Text(tip).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: "#f59e0b")).lineSpacing(3)
                                }
                                .padding(10).background(Color(hex: "#f59e0b").opacity(0.08)).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#f59e0b").opacity(0.2), lineWidth: 1))
                            }
                        }.padding(.horizontal, 16)
                    }
                }.padding(.bottom, 100)
            }

            // Navigation
            HStack(spacing: 10) {
                if currentStep > 0 {
                    Button { currentStep -= 1 } label: {
                        Image(systemName: "arrow.left").font(.system(size: 16, weight: .bold)).foregroundColor(.motoText)
                            .frame(width: 50, height: 50).background(Color.motoCard).cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
                    }
                }
                Button {
                    if currentStep < guide.steps.count { currentStep += 1 }
                    else { selectedGuide = nil; currentStep = 0 }
                } label: {
                    Text(currentStep == 0 ? "Start Guide" : currentStep == guide.steps.count ? "Complete ✓" : "Next Step →")
                        .font(.system(size: 14, weight: .black, design: .monospaced)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(currentStep == guide.steps.count ? Color(hex: "#4ade80") : Color.motoOrange).cornerRadius(14)
                }
            }.padding(.horizontal, 16).padding(.vertical, 12).background(Color.motoBg)
        }
    }

    let guides: [RepairGuide] = [
        RepairGuide(title: "Air Filter Clean & Re-oil", category: "Engine", difficulty: "Easy", estimatedTime: "20 min",
            toolsNeeded: ["Filter cleaner/petrol", "Filter oil", "Rubber gloves", "Bucket"],
            steps: [
                GuideStep(step: 1, title: "Remove filter", detail: "Remove seat and tank. Undo airbox lid bolts or clips. Pull filter straight up from airbox, being careful not to drop dirt into carb/throttle body intake.", tip: "Block the carb intake with a rag before removing the filter."),
                GuideStep(step: 2, title: "Wash filter", detail: "Work filter cleaner through the foam from inside-out using your hands. Rinse with water. Repeat until runoff is clean. Do NOT wring — squeeze gently.", tip: nil),
                GuideStep(step: 3, title: "Dry completely", detail: "Allow filter to air dry completely — at least 1 hour. Applying oil to a wet filter traps moisture and reduces filtration. You can blow dry from inside-out on low heat.", tip: "Never use compressed air — it tears the foam."),
                GuideStep(step: 4, title: "Apply filter oil", detail: "Work filter oil into the foam evenly with your hands. The filter should be uniformly amber/orange — no dry spots, no pooling. Let sit 10 min for oil to wick through.", tip: nil),
                GuideStep(step: 5, title: "Reinstall", detail: "Apply grease to the filter rim/airbox sealing surface. Seat filter firmly — no gaps. Secure lid, reinstall tank and seat. Check for any displaced clamps.", tip: "A poorly seated filter lets unfiltered air in — destroys the engine."),
            ],
            torqueSpecs: [:],
            warnings: ["Never run without an air filter — engine damage in minutes"]),
        RepairGuide(title: "Spark Plug Replacement", category: "Engine", difficulty: "Easy", estimatedTime: "15 min",
            toolsNeeded: ["Correct spark plug", "Plug socket (18mm or 21mm)", "Torque wrench", "Anti-seize compound", "Gap gauge"],
            steps: [
                GuideStep(step: 1, title: "Let engine cool", detail: "Never remove a spark plug from a hot engine. Allow 30 min minimum. A hot aluminium head can strip threads if plug is removed while hot.", tip: nil),
                GuideStep(step: 2, title: "Remove plug cap and plug", detail: "Pull plug cap straight off — do not yank by the wire. Use correct spark plug socket (deep, rubber-lined) and ratchet. Turn counterclockwise.", tip: "If plug is seized, apply penetrating oil and wait 10 minutes."),
                GuideStep(step: 3, title: "Inspect old plug", detail: "Read the plug: light tan/grey = good mixture. Black/sooty = rich. White/blistered = lean. Oily = oil burning. This diagnosis is as important as replacement.", tip: nil),
                GuideStep(step: 4, title: "Check gap on new plug", detail: "Use feeler gauge to verify new plug gap matches spec. Most 4-stroke MX bikes: 0.9mm. Adjust by bending ground electrode slightly if needed.", tip: nil),
                GuideStep(step: 5, title: "Install new plug", detail: "Apply tiny amount of anti-seize to threads. Thread in by hand to avoid cross-threading. Once finger-tight, use torque wrench.", tip: "Cross-threading a spark plug is an expensive mistake — always start by hand."),
            ],
            torqueSpecs: ["Spark plug": "12–15 Nm (new plug: 27 Nm)"],
            warnings: ["Check manufacturer torque spec — over-torquing strips aluminium head threads"]),
        RepairGuide(title: "Chain & Sprocket Replacement", category: "Drivetrain", difficulty: "Moderate", estimatedTime: "1.5–2 hrs",
            toolsNeeded: ["Chain breaker tool", "Chain riveting tool", "New chain (with master link)", "Front & rear sprocket", "Sprocket socket", "Torque wrench", "Chain measuring tool"],
            steps: [
                GuideStep(step: 1, title: "Position bike and remove chain guard", detail: "Support bike on stand. Remove rear chain guard bolts. Loosen rear axle fully and push wheel forward to give maximum chain slack.", tip: nil),
                GuideStep(step: 2, title: "Break old chain", detail: "Use chain breaker tool to push a pin out of a link. Remove chain from sprockets. Inspect sprocket teeth — if hooked like shark fins, replace now.", tip: "Always replace chain AND sprockets together for maximum life."),
                GuideStep(step: 3, title: "Remove front sprocket", detail: "Remove front sprocket cover. Lock rear brake to hold shaft. Remove sprocket nut (usually left-hand thread — turns clockwise to remove). Note: often very tight.", tip: "Lock nut direction varies by brand — check your manual."),
                GuideStep(step: 4, title: "Remove rear sprocket", detail: "Remove rear wheel. Unscrew the 6 sprocket nuts. Replace sprocket, applying threadlocker to bolts.", tip: nil),
                GuideStep(step: 5, title: "Install new chain", detail: "Route new chain through swingarm, over front sprocket, and around rear. Connect with master link — ensure clip faces forward (away from direction of travel).", tip: "Rivet-type master links are stronger than clip-type for MX use."),
                GuideStep(step: 6, title: "Adjust chain tension", detail: "Move wheel to correct tension: typically 35–45mm sag at tightest point of chain travel. Tighten axle. Recheck tension with weight on bike.", tip: nil),
            ],
            torqueSpecs: ["Rear axle nut": "90–110 Nm", "Rear sprocket bolts": "35–40 Nm", "Front sprocket nut": "70–80 Nm"],
            warnings: ["Clip master link faces FORWARD or it can come undone at speed — dangerous", "Re-check chain tension after first 15 min of riding a new chain"]),
        RepairGuide(title: "Brake Bleed (Front)", category: "Brakes", difficulty: "Moderate", estimatedTime: "30–45 min",
            toolsNeeded: ["DOT 4 or 5.1 brake fluid", "8mm spanner", "Clear plastic hose", "Catch bottle", "Syringe (optional)", "Rags"],
            steps: [
                GuideStep(step: 1, title: "Prepare reservoir", detail: "Remove master cylinder cap and diaphragm. Top up fluid to MAX line. Keep reservoir topped up throughout — if it runs dry you'll introduce air.", tip: "Brake fluid is hygroscopic — use fresh fluid from a sealed container."),
                GuideStep(step: 2, title: "Attach bleed hose", detail: "Attach clear hose to caliper bleed nipple. Put other end in a catch bottle with some fluid already in it (prevents air being sucked back).", tip: nil),
                GuideStep(step: 3, title: "Pump and bleed", detail: "Pull brake lever slowly 3–4 times to build pressure. Hold lever in. Open bleed nipple 1/4 turn — fluid and bubbles exit. Close nipple. Release lever. Repeat.", tip: "Never open nipple without lever pulled in — air enters immediately."),
                GuideStep(step: 4, title: "Repeat until clear", detail: "Continue until no bubbles are visible in the clear hose. Fluid should come out clean and bubble-free. This may take 20–30 pumps.", tip: nil),
                GuideStep(step: 5, title: "Final tighten and test", detail: "Tighten bleed nipple with lever released. Top up reservoir to MAX. Install diaphragm and cap. Test brake feel — should be firm with no sponginess.", tip: "Clean up all brake fluid immediately — it strips paint and damages plastics."),
            ],
            torqueSpecs: ["Bleed nipple": "5–8 Nm"],
            warnings: ["DOT 4 and DOT 5 ARE NOT COMPATIBLE — check your bike's spec", "Brake fluid removes paint instantly — protect all surfaces"]),
        RepairGuide(title: "Fork Oil Change", category: "Suspension", difficulty: "Moderate", estimatedTime: "1–1.5 hrs",
            toolsNeeded: ["Fork oil (correct spec)", "Measuring cylinder", "Fork seal driver", "Snap ring pliers", "Large flat screwdriver", "Drain pan", "17mm socket"],
            steps: [
                GuideStep(step: 1, title: "Remove forks", detail: "Loosen fork clamp bolts (top and bottom triple clamp). Support front end. Pull forks down and out. Mark left and right if different setup.", tip: nil),
                GuideStep(step: 2, title: "Drain old oil", detail: "Remove top cap. Invert fork over drain pan and pump the inner tube to expel all oil. Allow 10 min to fully drain. Note condition of old oil — very dark = overdue.", tip: nil),
                GuideStep(step: 3, title: "Disassemble (if needed for seal change)", detail: "Remove dust seal. Extract snap ring with snap ring pliers. Pull inner tube from outer tube. Slide off oil seal, washer, and bushings.", tip: "Lay parts out in order on a clean rag."),
                GuideStep(step: 4, title: "Clean and inspect", detail: "Wipe all components clean. Inspect inner tube for pitting, scratches, or bends (replace if damaged). Clean outer tube thoroughly.", tip: nil),
                GuideStep(step: 5, title: "Fill with correct oil", detail: "Reassemble fork (new seals if replacing). Fill with exactly the specified volume of correct weight oil. Use measuring cylinder — oil height affects handling significantly.", tip: "Check your specific model's oil height spec — typically measured from top of fork with spring removed and fully compressed."),
                GuideStep(step: 6, title: "Reinstall forks", detail: "Insert forks to correct height in triple clamp (check spec — typically 0–5mm above top clamp). Tighten clamp bolts to torque spec. Check alignment.", tip: nil),
            ],
            torqueSpecs: ["Triple clamp bolts (upper)": "15–20 Nm", "Triple clamp bolts (lower)": "20–25 Nm", "Top cap": "15–25 Nm"],
            warnings: ["Wrong oil volume/weight dramatically affects handling — measure precisely", "Bent inner tubes cannot be repaired — inspect carefully before reinstalling"]),
        RepairGuide(title: "Pilot Jet Clean (Carb)", category: "Carb/Fuel", difficulty: "Easy", estimatedTime: "30–45 min",
            toolsNeeded: ["JIS screwdrivers (not Phillips!)", "Carb cleaner spray", "Compressed air", "Small wire or drill bit (same size as jet hole)", "Drain pan"],
            steps: [
                GuideStep(step: 1, title: "Access carb", detail: "Turn fuel off. Loosen clamps on airboot and intake manifold. Disconnect throttle cables and choke. Remove carb from bike.", tip: "Take photos before disconnecting cables — helps with reassembly."),
                GuideStep(step: 2, title: "Drain float bowl", detail: "Loosen float bowl drain screw (bottom of carb). Drain fuel into pan. Remove float bowl screws. Note: JIS screwdrivers are essential — Phillips WILL strip these.", tip: "JIS screwdrivers look like Phillips but have a different tip — worth buying a set."),
                GuideStep(step: 3, title: "Remove pilot jet", detail: "Pilot jet is the small brass jet (typically 35–55 size). Carefully unscrew with flat screwdriver. Note the size stamped on it.", tip: "The pilot jet affects idle and 0–1/4 throttle. Main jet is the larger one."),
                GuideStep(step: 4, title: "Clean jet and passages", detail: "Spray carb cleaner through jet hole. Confirm you can see light through the tiny hole. Use compressed air. NEVER use wire to ream the jet hole — enlarges it.", tip: "If you can't clear the blockage, replace the jet — they're $5."),
                GuideStep(step: 5, title: "Clean float bowl and passages", detail: "Spray all passages in carb body with carb cleaner and compressed air. Clean float bowl. Inspect float for damage or fuel inside it.", tip: nil),
                GuideStep(step: 6, title: "Reassemble and test", detail: "Reinstall jet, bowl, and carb. Reconnect cables and hoses. Start and test idle quality. A clean pilot jet should allow smooth idle without choke when warm.", tip: "If still boggy, check needle clip position and fuel screw setting."),
            ],
            torqueSpecs: [:],
            warnings: ["JIS vs Phillips — using Phillips strips carb screws immediately", "Never use wire to clean jet holes — even 1 size up causes rich condition"]),
    ]
}

#Preview { RepairGuidesView().environmentObject(AppStateManager()) }
