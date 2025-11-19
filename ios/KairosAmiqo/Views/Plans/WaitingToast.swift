import SwiftUI

/// Toast message shown when user accepts a plan but consensus hasn't been reached yet
/// Shows "Waiting for X others..." and auto-dismisses after 3 seconds
struct WaitingToast: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            // Toast card at top
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: KairosAuth.IconSize.badge))
                    .foregroundColor(KairosAuth.Color.accent)
                    .accessibilityHidden(true)
                
                Text(message)
                    .font(KairosAuth.Typography.body)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
                        .padding(KairosAuth.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                    .fill(
                        LinearGradient(
                            colors: [
                                KairosAuth.Color.accent.opacity(0.15),  // Mint 15% (top)
                                KairosAuth.Color.teal.opacity(0.12)     // Teal 12% (bottom)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Glassmorphic blur effect
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                            .fill(.ultraThinMaterial)  // iOS system blur
                    )
                    .overlay(
                        // Mint glow border
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        KairosAuth.Color.accent.opacity(0.8),
                                        KairosAuth.Color.teal.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: KairosAuth.Color.accent.opacity(0.3), radius: 20, y: 8)  // Mint glow shadow
            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
            .padding(.top, 100) // Below navigation bar
            
            Spacer() // Push everything else down
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(KairosAuth.Animation.uiUpdate, value: isShowing)
        .allowsHitTesting(false) // Don't block touches to content below
    }
}

#Preview {
    WaitingToast(
        message: "Response sent! Waiting for 3 others...",
        isShowing: .constant(true)
    )
    .background(
        Color.black,
        ignoresSafeAreaEdges: .all
    )
}
