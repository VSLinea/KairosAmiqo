import SwiftUI

struct SplashView: View {
    @ObservedObject var vm: AppVM
    @State private var contentOpacity: Double = 0

    /// Original Amiqo brand gradient - hardcoded to ensure consistent branding regardless of user theme
    private var originalAmiqoGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                SwiftUI.Color(red: 0.18, green: 0.20, blue: 0.66), // Deep blue (original gradientStart)
                SwiftUI.Color(red: 0.180, green: 0.600, blue: 0.749) // Blue-teal (original gradientEnd)
            ]),
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()

                // Branding section
                VStack(spacing: 32) { // Hardcoded spacing for consistency
                    // Amiqo app icon
                    Image("AmiqoAppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180) // Hardcoded icon size (original splashIcon value)
                        .scaledToFit()
                        .shadow(color: SwiftUI.Color.black.opacity(0.10), radius: 24, y: 8) // Hardcoded shadow
                        .accessibilityHidden(true)

                    // Title
                    VStack(spacing: 0) {
                        Text("Kairos")
                            .font(KairosAuth.Typography.brandName)
                            .foregroundColor(.white) // Always white, theme-independent
                        Text("Amiqo")
                            .font(KairosAuth.Typography.appName)
                            .foregroundColor(.white) // Always white, theme-independent
                            .padding(.top, 2)
                    }
                }
                .opacity(contentOpacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Kairos Amiqo")

                // Loading indicator - always white for brand consistency
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.6)
                    .padding(.top, 32)
                    .opacity(contentOpacity)
                    .accessibilityLabel("Loading Kairos Amiqo")
                    .accessibilityHint("Please wait")

                Spacer()

                // Privacy motto  
                // Current: Honest messaging about agent conversation privacy
                // Future: "End-to-end encrypted. Zero-knowledge privacy." when Task 30 complete
                Text("Private conversations with your AI invite partner")
                    .font(KairosAuth.Typography.body)
                    .foregroundColor(SwiftUI.Color.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .opacity(contentOpacity)
                    .accessibilityLabel("Private conversations with your AI invite partner")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            originalAmiqoGradient,
            ignoresSafeAreaEdges: .all
        )
        .onAppear {
            // Hardcoded splash fade animation for consistency (original splashFade value)
            withAnimation(.easeOut(duration: 0.8)) {
                contentOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView(vm: AppVM(forPreviews: true))
}
