//
//  CounterSheet.swift
//  KairosAmiqo
//
//  Counter proposal sheet with quick chips and custom picker (Task 13)
//

import SwiftUI

struct CounterSheet: View {
    @ObservedObject var vm: AppVM
    let plan: Negotiation
    @Binding var isPresented: Bool
    
    @State private var selectedChip: CounterChip? = nil
    @State private var showCustomPicker = false
    @State private var customDate = Date()
    
    enum CounterChip: String, CaseIterable {
        case plusOneHour = "+1 Hour"
        case tomorrow = "Tomorrow"
        case differentTime = "Different Time"
        
        var icon: String {
            switch self {
            case .plusOneHour: return "clock.arrow.circlepath"
            case .tomorrow: return "calendar.badge.plus"
            case .differentTime: return "clock.badge.questionmark"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairosAuth.Spacing.large) {
                    header

                    quickChips

                    if showCustomPicker {
                        customPicker
                    }

                    if let error = vm.counterError {
                        VStack(alignment: .leading, spacing: KairosAuth.Spacing.xs) {
                            HStack(spacing: KairosAuth.Spacing.small) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: KairosAuth.IconSize.badge))
                                    .accessibilityHidden(true)
                                Text(error)
                                    .font(KairosAuth.Typography.bodySmall)
                            }
                            .foregroundColor(KairosAuth.Color.statusDeclined)
                            
                            if error.contains("Maximum rounds") || error.contains("max") {
                                Text("Tip: Start a new invitation to continue coordinating.")
                                    .font(KairosAuth.Typography.bodySmall)
                                    .foregroundColor(KairosAuth.Color.secondaryText)
                            }
                        }
                        .padding(KairosAuth.Spacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: KairosAuth.Radius.item)
                                .fill(KairosAuth.Color.statusDeclined.opacity(0.1))
                        )
                    }

                    Button(action: submitCounter) {
                        if vm.isCountering {
                            ProgressView()
                                .tint(KairosAuth.Color.buttonText)
                        } else {
                            Text("Send Counter Invite")
                                .font(KairosAuth.Typography.buttonLabel)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.kairosPrimary)
                    .disabled(selectedChip == nil || vm.isCountering)
                }
                .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
                .padding(.vertical, KairosAuth.Spacing.extraLarge)
            }
            .background(
                LinearGradient(
                    colors: [KairosAuth.Color.gradientStart, KairosAuth.Color.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                ignoresSafeAreaEdges: .all
            )
            .navigationTitle("Counter Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .font(KairosAuth.Typography.buttonLabel)
                        .foregroundColor(KairosAuth.Color.primaryText)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Round indicator
            if let round = plan.round, round > 0 {
                let isFinalRound = (round >= 2) // Max 2 rounds
                HStack(spacing: KairosAuth.Spacing.xs) {
                    Image(systemName: isFinalRound ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: KairosAuth.IconSize.badge))
                        .accessibilityHidden(true)
                    Text(isFinalRound ? "Final Round" : "Round \(round)")
                        .font(KairosAuth.Typography.statusBadge)
                }
                .foregroundColor(isFinalRound ? KairosAuth.Color.statusDeclined : KairosAuth.Color.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((isFinalRound ? KairosAuth.Color.statusDeclined : KairosAuth.Color.accent).opacity(0.15))
                )
            }
            
            Text("Counter Invite")
                .font(KairosAuth.Typography.cardTitle)
                .foregroundColor(KairosAuth.Color.primaryText)

            Text("Suggest a different time or place")
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickChips: some View {
        VStack(spacing: KairosAuth.Spacing.medium) {
            ForEach(CounterChip.allCases, id: \.self) { chip in
                Button(action: {
                    withAnimation(KairosAuth.Animation.uiUpdate) {
                        selectedChip = chip
                        showCustomPicker = (chip == .differentTime)
                    }
                }) {
                    HStack(spacing: KairosAuth.Spacing.rowSpacing) {
                        Image(systemName: chip.icon)
                            .font(.system(size: KairosAuth.IconSize.itemIcon))
                            .foregroundColor(KairosAuth.Color.accent)
                            .accessibilityHidden(true)

                        Text(chip.rawValue)
                            .font(KairosAuth.Typography.buttonLabel)
                            .foregroundColor(KairosAuth.Color.primaryText)

                        Spacer()

                        if selectedChip == chip {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(KairosAuth.Color.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(KairosAuth.Spacing.cardPadding)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                            .fill(selectedChip == chip ? KairosAuth.Color.selectedBackground : KairosAuth.Color.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                            .stroke(selectedChip == chip ? KairosAuth.Color.accent : KairosAuth.Color.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
    }
    }

    private var customPicker: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.small) {
            Text("Select Time")
                .font(KairosAuth.Typography.itemTitle)
                .foregroundColor(KairosAuth.Color.primaryText)

            DatePicker("", selection: $customDate, in: Date()...)
                .datePickerStyle(.graphical)
                .tint(KairosAuth.Color.accent)
                .labelsHidden()
        }
        .padding(KairosAuth.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .fill(KairosAuth.Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                .stroke(KairosAuth.Color.cardBorder, lineWidth: 1)
        )
        
    }
    
    private func submitCounter() {
        guard let chip = selectedChip else { return }
        
        Task {
            // Calculate new time based on chip selection
            var newTime: Date?
            
            switch chip {
            case .plusOneHour:
                if let firstSlot = plan.proposed_slots?.first,
                   let slotDate = DateFormatting.parseISO8601(firstSlot.time) {
                    newTime = Calendar.current.date(byAdding: .hour, value: 1, to: slotDate)
                }
            case .tomorrow:
                if let firstSlot = plan.proposed_slots?.first,
                   let slotDate = DateFormatting.parseISO8601(firstSlot.time) {
                    newTime = Calendar.current.date(byAdding: .day, value: 1, to: slotDate)
                }
            case .differentTime:
                newTime = customDate
            }

            guard let newTime = newTime else {
                print("❌ Failed to calculate new time")
                return
            }

            let newSlotString = DateFormatting.toISO8601String(newTime)

            // Send counter proposal
            await vm.counterProposal(
                planId: plan.id,
                newSlots: [newSlotString],
                newVenues: nil // For now, keep same venues
            )
            
            // Close sheet and show feedback if successful
            if vm.counterError == nil {
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Show success toast
                await MainActor.run {
                    vm.presentToast("Counter sent! \(plan.participants?.first?.name ?? "Organizer") will be notified.")
                }
                
                isPresented = false
            }
        }
    }
}
