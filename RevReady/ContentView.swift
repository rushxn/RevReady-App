import SwiftUI

class AppStateManager: ObservableObject {
    @Published var currentScreen: AppScreen = .dashboard
    @Published var selectedBikeModel: BikeModel = .ktm450  // legacy fallback only
    @Published var selectedBikeString: String = "KTM 450 EXC-F"
    @Published var selectedPart: BikePart   = .engine
    @Published var capturedPhotos: [CapturedPhoto] = []
    @Published var diagnosticResult: DiagnosticResult? = nil
    @Published var loadingProgress: Int  = 0
    @Published var loadingStatus: String = ""
    @Published var currentModel: String  = ""
    @Published var retryCount: Int       = 0
    @Published var errorMessage: String? = nil
    @Published var selectedTab: Tab      = .home
    @Published var loadingSteps: [LoadingStep] = [
        LoadingStep(title: "Uploading photos to AI engine"),
        LoadingStep(title: "Identifying bike components"),
        LoadingStep(title: "Scanning for wear & damage"),
        LoadingStep(title: "Cross-referencing service data"),
        LoadingStep(title: "Generating diagnosis report"),
    ]
    let historyStore     = ScanHistoryStore()
    let maintenanceStore = MaintenanceStore()
    let profileStore     = UserProfileStore()

    init() {
        // Sync bike from saved profile on every launch
        let store = UserProfileStore()
        if store.isOnboarded, let p = store.profile, !p.bikeBrand.isEmpty {
            _selectedBikeString = Published(initialValue: "\(p.bikeYear) \(p.bikeBrand) \(p.bikeModel)")
        }
    }

    func navigate(to screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) { currentScreen = screen }
    }

    func resetScan() {
        capturedPhotos = []; diagnosticResult = nil; errorMessage = nil
        loadingProgress = 0; loadingStatus = ""; currentModel = ""; retryCount = 0
        for i in loadingSteps.indices { loadingSteps[i].isDone = false; loadingSteps[i].isActive = false }
    }

    @Published var slowConnectionWarning = false

    func updateLoadingProgress(_ p: Int) {
        DispatchQueue.main.async {
            if p == -1 {
                // Slow connection signal
                self.slowConnectionWarning = true
                self.loadingStatus = "⚡ Slow connection — still working, please wait…"
                return
            }
            self.loadingProgress = p
            let idx = min(p / 20, self.loadingSteps.count - 1)
            for i in self.loadingSteps.indices {
                self.loadingSteps[i].isDone   = i < idx
                self.loadingSteps[i].isActive = i == idx
            }
        }
    }

    @MainActor func runAnalysis() async {
        guard !capturedPhotos.isEmpty else { return }
        navigate(to: .loading)
        retryCount = 0; loadingStatus = ""; slowConnectionWarning = false
        currentModel = AnthropicService.modelChain.first ?? ""
        for i in loadingSteps.indices { loadingSteps[i].isDone = false; loadingSteps[i].isActive = i == 0 }
        do {
            let result = try await AnthropicService.analyzeBike(
                photos: capturedPhotos, bikeModel: selectedBikeString,
                progressCallback: { [weak self] p in self?.updateLoadingProgress(p) },
                retryCallback: { [weak self] model, attempt, delay in
                    DispatchQueue.main.async {
                        self?.currentModel = model; self?.retryCount = attempt + 1
                        let short = model.components(separatedBy: "-").prefix(2).joined(separator: "-")
                        self?.loadingStatus = "\(short) busy — retrying in \(Int(delay))s…"
                    }
                }
            )
            diagnosticResult = result
            loadingStatus = ""; slowConnectionWarning = false
            for i in loadingSteps.indices { loadingSteps[i].isDone = true; loadingSteps[i].isActive = false }
            historyStore.save(SavedScan.from(result: result, bikeString: selectedBikeString))
            try? await Task.sleep(nanoseconds: 400_000_000)
            navigate(to: .result)
        } catch AnthropicError.notBike(let msg) {
            // Not a bike image — go back to camera with clear message
            errorMessage = msg
            navigate(to: .camera)
        } catch {
            errorMessage = error.localizedDescription
            navigate(to: .camera)
        }
    }
}

// MARK: - Tab
enum Tab: String, CaseIterable {
    case home, diagnose, maintenance, sensors
    var label: String {
        switch self {
        case .home:        return "Home"
        case .diagnose:    return "Diagnose"
        case .maintenance: return "Maintain"
        case .sensors:     return "Sensors"
        }
    }
    var icon: String {
        switch self {
        case .home:        return "house.fill"
        case .diagnose:    return "waveform.path.ecg"
        case .maintenance: return "list.clipboard.fill"
        case .sensors:     return "bolt.fill"
        }
    }
}

// MARK: - Root View
struct ContentView: View {
    @StateObject private var appState = AppStateManager()
    @State private var showSplash = true
    @State private var showOnboarding = false

    // Screens that cover the full app (no tab bar)
    var isFullScreen: Bool {
        switch appState.currentScreen {
        case .camera, .loading, .result, .history, .symptoms,
             .specs, .prePurchase, .repairGuides, .jetCalc, .maintenance:
            return true
        case .dashboard, .sensors:
            return false
        }
    }

    var body: some View {
        ZStack {
            Color.motoBg.ignoresSafeArea()

            if isFullScreen {
                // Full-screen flows — no tab bar
                fullScreenContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                // Tab bar navigation
                tabContent
            }

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                    // Show onboarding after splash if not yet done
                    if !appState.profileStore.isOnboarded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { showOnboarding = true }
                        }
                    }
                }
                .zIndex(10).transition(.opacity)
            }

            if showOnboarding {
                OnboardingView(profileStore: appState.profileStore) {
                    withAnimation { showOnboarding = false }
                }
                .zIndex(9)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentScreen)
        .animation(.easeInOut(duration: 0.3), value: appState.selectedTab)
    }

    var fullScreenContent: some View {
        Group {
            switch appState.currentScreen {
            case .camera:      CameraView().environmentObject(appState)
            case .loading:     LoadingView().environmentObject(appState)
            case .result:      ResultView().environmentObject(appState)
            case .history:     HistoryView().environmentObject(appState)
            case .symptoms:    SymptomDiagnoserView().environmentObject(appState)
            case .specs:       SpecsView().environmentObject(appState)
            case .maintenance: MaintenanceView().environmentObject(appState)
            case .prePurchase: PrePurchaseView().environmentObject(appState)
            case .repairGuides: RepairGuidesView().environmentObject(appState)
            case .jetCalc:     JetCalcView().environmentObject(appState)
            case .sensors:     SensorsView().environmentObject(appState)
            default:           DashboardView().environmentObject(appState)
            }
        }
    }

    var tabContent: some View {
        VStack(spacing: 0) {
            // Tab page content
            Group {
                switch appState.selectedTab {
                case .home:        DashboardView().environmentObject(appState)
                case .diagnose:    SymptomDiagnoserView().environmentObject(appState)
                case .maintenance: MaintenanceView().environmentObject(appState)
                case .sensors:     SensorsView().environmentObject(appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab Bar
            TabBarView(selectedTab: $appState.selectedTab)
        }
    }
}

// MARK: - Tab Bar
struct TabBarView: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: selectedTab == tab ? 22 : 20,
                                          weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? .motoOrange : .motoMuted)
                            .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                        Text(tab.label)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .regular,
                                          design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .motoOrange : .motoMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
            }
        }
        .padding(.bottom, 4)
        .background(Color.motoBg)
        .overlay(
            Rectangle()
                .fill(Color.motoBorder)
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - Shared NavBar
struct NavBar: View {
    let title: String; let subtitle: String?
    let onBack: () -> Void; let trailing: AnyView?
    init(_ title: String, subtitle: String? = nil, onBack: @escaping () -> Void, trailing: AnyView? = nil) {
        self.title = title; self.subtitle = subtitle; self.onBack = onBack; self.trailing = trailing
    }
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.motoText)
                    .frame(width: 36, height: 36).background(Color.motoCard).clipShape(Circle())
                    .overlay(Circle().stroke(Color.motoBorder, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 18, weight: .black, design: .monospaced)).foregroundColor(.white)
                if let sub = subtitle {
                    Text(sub).font(.system(size: 11, design: .monospaced)).foregroundColor(.motoMuted)
                }
            }.padding(.leading, 4)
            Spacer()
            trailing
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
    }
}

struct CapturedPhoto: Identifiable {
    let id = UUID(); let image: UIImage; let part: BikePart
}

#Preview { ContentView() }
