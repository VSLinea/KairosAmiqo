//
//  GuestResponseView.swift
//  KairosAmiqo
//
//  Guest response flow for Universal Links (Task 16)
//  Handles https://kairos.app/p/{token} deep links
//

import SwiftUI

struct GuestResponseView: View {
    let token: String
    @ObservedObject var vm: AppVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var invitationData: GuestInvitationData?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    VStack(spacing: KairosAuth.Spacing.medium) {
                        ProgressView()
                            .tint(KairosAuth.Color.accent)
                        Text("Loading invitation...")
                            .font(KairosAuth.Typography.body)
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: KairosAuth.Spacing.large) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: KairosAuth.IconSize.heroIcon))
                            .foregroundStyle(KairosAuth.Color.error)
                            .accessibilityHidden(true)
                        
                        Text(error)
                            .font(KairosAuth.Typography.cardTitle)
                            .foregroundStyle(KairosAuth.Color.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.kairosPrimary)
                    }
                } else if let invitation = invitationData {
                    ScrollView {
                        VStack(spacing: KairosAuth.Spacing.large) {
                            // Plan header
                            VStack(spacing: KairosAuth.Spacing.small) {
                                Text(invitation.title)
                                    .font(KairosAuth.Typography.cardTitle)
                                    .foregroundStyle(KairosAuth.Color.primaryText)
                                
                                Text("Organized by \(invitation.initiatorName)")  // TODO(Phase 4): Rename to organizerName
                                    .font(KairosAuth.Typography.itemSubtitle)
                                    .foregroundStyle(KairosAuth.Color.secondaryText)
                            }
                            .padding(.top, KairosAuth.Spacing.large)
                            
                            // TODO(Phase 4): Add plan details (time options, venue options)
                            // TODO(Phase 4): Add response buttons (accept/decline/counter)
                            
                            Text("Guest response UI coming in Phase 4+")
                                .font(KairosAuth.Typography.body)
                                .foregroundStyle(KairosAuth.Color.tertiaryText)
                                .padding()
                            
                            Button("Close") {
                                dismiss()
                            }
                            .buttonStyle(.kairosSecondary)
                        }
                        .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                    }
                }
            }
            .background(
                KairosAuth.Color.backgroundGradient(),
                ignoresSafeAreaEdges: .all
            )
            .navigationTitle("Guest Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.close))
                            .foregroundStyle(KairosAuth.Color.secondaryText)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .task {
            await loadGuestInvitation()
        }
    }
    
    private func loadGuestInvitation() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch guest plan data from backend
            let (data, response) = try await vm.directusClient.get(path: "/api/guest/plan/\(token)")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "GuestResponse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            if httpResponse.statusCode == 404 {
                errorMessage = "Invitation not found or link expired"
                isLoading = false
                return
            }
            
            if httpResponse.statusCode != 200 {
                errorMessage = "Failed to load invitation (HTTP \(httpResponse.statusCode))"
                isLoading = false
                return
            }
            
            // Decode response
            let decoder = JSONDecoder()
            let guestInvitation = try decoder.decode(GuestInvitationData.self, from: data)

            invitationData = guestInvitation
            isLoading = false
            
            print("[GuestResponse] ✅ Loaded invitation: \(guestInvitation.title)")
            
        } catch {
            print("[GuestResponse] ❌ Error loading invitation: \(error)")
            errorMessage = "Failed to load invitation. Please try again."
            isLoading = false
        }
    }
}

// MARK: - Guest Invitation Data Model

struct GuestInvitationData: Codable {
    let id: String
    let title: String
    let initiatorName: String  // TODO(Phase 4): Derive from owner UUID lookup, not separate field
    let timeOptions: [String]
    let venueOptions: [String]
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title
        case initiatorName = "initiator_name"  // Legacy - should be "owner_name" derived from owner UUID
        case timeOptions = "time_options"
        case venueOptions = "venue_options"
        case expiresAt = "expires_at"
    }
}
