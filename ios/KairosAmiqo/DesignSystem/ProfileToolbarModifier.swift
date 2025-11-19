//
//  ProfileToolbarModifier.swift
//  KairosAmiqo
//
//  Centralized profile button toolbar injection
//  Applied at app level to all main screens
//  See /docs/00-architecture-overview.md for design system
//

import SwiftUI

/// Adds profile button to navigation toolbar
/// Applied at RootTabView level for consistent app-wide profile access
/// See architecture decision: Profile is app-level chrome, managed centrally
struct ProfileToolbarModifier: ViewModifier {
    @ObservedObject var vm: AppVM
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: vm.openProfile) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.profileButton))
                            .foregroundColor(KairosAuth.Color.accent)
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("View your profile, settings, and help")
                }
            }
    }
}

extension View {
    /// Apply profile button to toolbar
    /// - Parameter vm: AppVM instance managing profile state
    /// - Returns: View with profile button in top-right toolbar
    func profileToolbar(vm: AppVM) -> some View {
        modifier(ProfileToolbarModifier(vm: vm))
    }
}

// MARK: - Preview

#Preview("Profile Button in Toolbar") {
    @Previewable @State var vm: AppVM = {
        let vm = AppVM(forPreviews: true)
        vm.jwt = "PREVIEW_TOKEN"
        return vm
    }()
    
    NavigationStack {
        Text("Content with Profile Button")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KairosAuth.Color.backgroundGradient())
    }
    .profileToolbar(vm: vm)
}
