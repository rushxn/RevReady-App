import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var rotation = 0.0
    @State private var pulse    = 1.0

    var isRetrying: Bool { appState.retryCount > 0 }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Spinner ring
            ZStack {
                Circle()
                    .stroke(Color.motoBorder, lineWidth: 3)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(isRetrying ? Color(hex: "#f59e0b") : Color.motoOrange,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isRetrying)

                Image(systemName: isRetrying ? "arrow.clockwise" : "brain.head.profile")
                    .font(.system(size: 26))
                    .foregroundColor(isRetrying ? Color(hex: "#f59e0b") : Color.motoOrange)
                    .scaleEffect(pulse)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever()) { pulse = 1.15 }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isRetrying)
            }

            // Title + subtitle
            VStack(spacing: 8) {
                Text(isRetrying ? "API Busy — Retrying…" : appState.slowConnectionWarning ? "Still Working…" : "AI Scanning Your Bike")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(isRetrying ? Color(hex: "#f59e0b") : appState.slowConnectionWarning ? Color(hex: "#3b82f6") : .white)
                    .animation(.easeInOut(duration: 0.3), value: isRetrying)

                if appState.slowConnectionWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Slow connection — results may take longer than usual")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(Color(hex: "#3b82f6"))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color(hex: "#3b82f6").opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#3b82f6").opacity(0.3), lineWidth: 1))
                    .transition(.opacity)
                } else if isRetrying, !appState.loadingStatus.isEmpty {
                    Text(appState.loadingStatus)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#f59e0b").opacity(0.8))
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else {
                    Text("Analyzing \(appState.capturedPhotos.count) photo\(appState.capturedPhotos.count != 1 ? "s" : "") · \(appState.selectedBikeString)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.motoMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.loadingStatus)

            // Retry badge
            if isRetrying {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .bold))
                    Text("Auto-retrying with backoff")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(hex: "#f59e0b"))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(hex: "#f59e0b").opacity(0.1))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#f59e0b").opacity(0.3), lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
            }

            // Step list
            VStack(spacing: 8) {
                ForEach(Array(appState.loadingSteps.enumerated()), id: \.element.id) { i, step in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(step.isDone ? Color.motoOrange : step.isActive ? Color.motoBorder : Color.motoSurface)
                                .frame(width: 22, height: 22)
                            if step.isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black)).foregroundColor(.white)
                            } else if step.isActive {
                                Circle().fill(Color.motoOrange).frame(width: 7, height: 7)
                            } else {
                                Text("\(i + 1)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.motoMuted)
                            }
                        }
                        Text(step.title)
                            .font(.system(size: 13, weight: step.isActive ? .bold : .regular, design: .monospaced))
                            .foregroundColor(step.isDone ? .motoOrange : step.isActive ? .white : .motoDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if step.isDone {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14)).foregroundColor(.motoOrange)
                        } else if step.isActive {
                            ProgressView().progressViewStyle(.circular).scaleEffect(0.7).tint(.motoOrange)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        step.isActive ? Color.motoOrange.opacity(0.07) :
                        step.isDone   ? Color.motoOrange.opacity(0.04) : Color.motoSurface
                    )
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            step.isActive ? Color.motoOrange.opacity(0.3) :
                            step.isDone   ? Color.motoOrange.opacity(0.15) : Color.motoBorder,
                            lineWidth: 1
                        )
                    )
                    .animation(.easeInOut(duration: 0.3), value: step.isDone)
                    .animation(.easeInOut(duration: 0.3), value: step.isActive)
                }
            }
            .padding(.horizontal, 24)

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.motoBorder)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isRetrying ? Color(hex: "#f59e0b") : Color.motoOrange)
                            .frame(width: g.size.width * Double(appState.loadingProgress) / 100)
                            .animation(.easeInOut(duration: 0.4), value: appState.loadingProgress)
                    }
                }.frame(height: 4)
                HStack {
                    if isRetrying {
                        Text("Attempt \(appState.retryCount + 1) of 4")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#f59e0b"))
                    } else {
                        Spacer()
                    }
                    Spacer()
                    Text("\(appState.loadingProgress)%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(isRetrying ? Color(hex: "#f59e0b") : .motoOrange)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.motoBg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: isRetrying)
    }
}

#Preview {
    LoadingView().environmentObject({
        let s = AppStateManager()
        s.loadingProgress = 55
        s.retryCount = 1
        s.loadingStatus = "API busy — retrying in 4s (attempt 2/4)…"
        s.loadingSteps[0].isDone = true
        s.loadingSteps[1].isDone = true
        s.loadingSteps[2].isActive = true
        return s
    }())
}
