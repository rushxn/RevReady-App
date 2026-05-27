import SwiftUI

struct SplashView: View {
    @State private var opacity     = 0.0
    @State private var logoOpacity = 0.0
    @State private var logoOffset  = 30.0
    @State private var isDone      = false

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            // Full-bleed background photo
            Image("launch")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(opacity)

            // Dark gradient overlay — bottom heavy so logo pops
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(opacity)

            // Logo + tagline
            VStack(spacing: 8) {
                Spacer()

                // App name
                HStack(spacing: 0) {
                    Text("RevReady")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("DIAGS")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(Color(hex: "#e85d04"))
                }
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)

                Text("AI-Powered Diagnostics")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(2)

                // Location badge
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#e85d04"))
                    Text("Carnegie SVRA")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)

                Spacer().frame(height: 52)
            }
            .opacity(logoOpacity)
            .offset(y: logoOffset)
        }
        .onAppear { animate() }
    }

    func animate() {
        // Fade photo in
        withAnimation(.easeIn(duration: 0.6)) {
            opacity = 1.0
        }
        // Slide logo up + fade in
        withAnimation(.easeOut(duration: 0.7).delay(0.4)) {
            logoOpacity = 1.0
            logoOffset  = 0
        }
        // After 2.6s total, fade everything out and call onFinished
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeInOut(duration: 0.5)) {
                opacity     = 0
                logoOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onFinished()
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
