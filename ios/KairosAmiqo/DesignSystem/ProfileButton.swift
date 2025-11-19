import SwiftUI

/// Reusable profile button for toolbar navigation.
/// Presents ProfileView sheet when tapped.
/// See /docs/00-CANONICAL/ios-amiqo.md §Design System - KairosAuth components
struct ProfileButton: ToolbarContent {
    @ObservedObject var vm: AppVM
    @Binding var isPresented: Bool
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: {
                isPresented = true
            }) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: KairosAuth.IconSize.profileButton))
                    .foregroundColor(KairosAuth.Color.accent)
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("Preview Content")
            .toolbar {
                ProfileButton(vm: AppVM(), isPresented: .constant(false))
            }
    }
    .preferredColorScheme(.dark)
}
