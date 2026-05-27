import SwiftUI

struct OnboardingView: View {
    @ObservedObject var profileStore: UserProfileStore
    var onComplete: () -> Void

    @State private var step = 0
    @State private var name = ""
    @State private var rideLocation = ""
    @State private var selectedBrand = ""
    @State private var selectedModel = ""
    @State private var selectedYear = ""
    @State private var animateIn = false
    @FocusState private var nameFocused: Bool
    @FocusState private var locationFocused: Bool

    let currentYear = Calendar.current.component(.year, from: Date())
    var years: [String] { (2005...currentYear).reversed().map { String($0) } }
    var models: [String] { BikeBrandData.models(for: selectedBrand) }

    var canProceed: Bool {
        switch step {
        case 0: return name.trimmingCharacters(in: .whitespaces).count >= 2
        case 1: return !rideLocation.isEmpty
        case 2: return !selectedBrand.isEmpty && !selectedModel.isEmpty && !selectedYear.isEmpty
        default: return true
        }
    }

    var body: some View {
        ZStack {
            Color.motoBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                progressDots
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                // Step content
                Group {
                    switch step {
                    case 0: stepName
                    case 1: stepLocation
                    case 2: stepBike
                    default: EmptyView()
                    }
                }
                .id(step) // forces re-render for animation
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Continue button
                continueBtn
                    .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .onAppear { nameFocused = true }
    }

    // MARK: - Progress dots
    var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i == step ? Color.motoOrange : i < step ? Color.motoOrange.opacity(0.4) : Color.motoBorder)
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
    }

    // MARK: - Step 1: Name
    var stepName: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text("What's your\nname?")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                Text("We'll use it to personalize your experience.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.motoMuted)
            }
            .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 8) {
                Text("FIRST NAME").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    .padding(.horizontal, 28)
                TextField("", text: $name)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($nameFocused)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.motoCard)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(nameFocused ? Color.motoOrange : Color.motoBorder, lineWidth: 1.5))
                    .padding(.horizontal, 24)
                    .submitLabel(.continue)
                    .onSubmit { if canProceed { advance() } }
            }
        }
    }

    // MARK: - Step 2: Ride Location
    var stepLocation: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Where do\nyou ride?")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                Text("Helps tailor your diagnosis and jetting advice.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.motoMuted)
            }
            .padding(.horizontal, 28)

            // Quick picks
            VStack(alignment: .leading, spacing: 10) {
                Text("QUICK PICK").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    .padding(.horizontal, 28)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(popularRideSpots, id: \.self) { spot in
                            Button { rideLocation = spot; locationFocused = false } label: {
                                Text(spot)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(rideLocation == spot ? .white : .motoMuted)
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(rideLocation == spot ? Color.motoOrange : Color.motoCard)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20)
                                        .stroke(rideLocation == spot ? Color.motoOrange : Color.motoBorder, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 24)
                }
            }

            // Or type custom
            VStack(alignment: .leading, spacing: 8) {
                Text("OR TYPE YOUR OWN").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                    .padding(.horizontal, 28)
                TextField("e.g. Hungry Valley, Baja California…", text: $rideLocation)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .focused($locationFocused)
                    .padding(.horizontal, 20).padding(.vertical, 16)
                    .background(Color.motoCard).cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(locationFocused ? Color.motoOrange : Color.motoBorder, lineWidth: 1.5))
                    .padding(.horizontal, 24)
                    .submitLabel(.continue)
                    .onSubmit { if canProceed { advance() } }
            }
        }
    }

    // MARK: - Step 3: Bike
    var stepBike: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("What's your\nbike?")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                Text("Saves your bike for every scan and diagnosis.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.motoMuted)
            }
            .padding(.horizontal, 28)

            VStack(spacing: 12) {
                // Brand
                pickerRow("BRAND", systemImage: "tag") {
                    Picker("Brand", selection: $selectedBrand) {
                        Text("Select brand").tag("")
                        ForEach(BikeBrandData.sortedBrands, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: selectedBrand) { _, _ in selectedModel = "" }
                }

                // Model — only enabled after brand picked
                pickerRow("MODEL", systemImage: "gear") {
                    Picker("Model", selection: $selectedModel) {
                        Text(selectedBrand.isEmpty ? "Pick brand first" : "Select model").tag("")
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                    }
                    .disabled(selectedBrand.isEmpty)
                }

                // Year
                pickerRow("YEAR", systemImage: "calendar") {
                    Picker("Year", selection: $selectedYear) {
                        Text("Select year").tag("")
                        ForEach(years, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .padding(.horizontal, 24)

            // Preview
            if !selectedBrand.isEmpty && !selectedModel.isEmpty && !selectedYear.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18)).foregroundColor(Color(hex: "#4ade80"))
                    Text("\(selectedYear) \(selectedBrand) \(selectedModel)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.2), value: selectedModel)
            }
        }
    }

    func pickerRow<Content: View>(_ label: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
            HStack {
                Image(systemName: systemImage).font(.system(size: 14)).foregroundColor(.motoOrange).frame(width: 20)
                content()
                    .pickerStyle(.menu)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.motoCard).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.motoBorder, lineWidth: 1))
        }
    }

    // MARK: - Continue button
    var continueBtn: some View {
        Button {
            if step < 2 { advance() }
            else { complete() }
        } label: {
            HStack(spacing: 8) {
                Text(step < 2 ? "Continue" : "Let's Ride")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                Image(systemName: step < 2 ? "arrow.right" : "flag.checkered")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(canProceed ? .white : .motoMuted)
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(canProceed ? Color.motoOrange : Color.motoCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(canProceed ? Color.clear : Color.motoBorder, lineWidth: 1))
        }
        .disabled(!canProceed)
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.2), value: canProceed)
    }

    func advance() {
        nameFocused = false; locationFocused = false
        withAnimation { step += 1 }
        if step == 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { locationFocused = true } }
    }

    func complete() {
        let profile = UserProfile(
            name: name.trimmingCharacters(in: .whitespaces),
            rideLocation: rideLocation,
            bikeBrand: selectedBrand,
            bikeModel: selectedModel,
            bikeYear: selectedYear,
            hasCompletedOnboarding: true
        )
        profileStore.save(profile)
        withAnimation(.easeInOut(duration: 0.4)) { onComplete() }
    }
}

#Preview {
    OnboardingView(profileStore: UserProfileStore(), onComplete: {})
}
