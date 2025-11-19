//
//  PlusPaywallView.swift
//  KairosAmiqo
//
//  Created by AI Agent on 2025-11-03.
//  Task 29: Plus Tier Paywall
//  100% KairosAuth design token coverage
//

import SwiftUI
import StoreKit

struct PlusPaywallView: View {
    @ObservedObject var storeManager: StoreKitManager
    @Environment(\.dismiss) var dismiss
    
    let reason: String // Why paywall was shown
    
    @State private var selectedPeriod: SubscriptionPeriod = .yearly
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KairosAuth.Spacing.large) {
                    
                    // MARK: - Header
                    headerSection
                    
                    // MARK: - Reason (why blocked)
                    reasonSection
                    
                    // MARK: - Pricing Toggle
                    pricingToggle
                    
                    // MARK: - Feature Comparison
                    featureComparison
                    
                    // MARK: - Purchase Buttons
                    purchaseButtons
                    
                    // MARK: - Restore Link
                    restoreButton
                    
                    Spacer()
                }
                .padding(KairosAuth.Spacing.horizontalPadding)
            }
            .background(
                LinearGradient(
                    colors: [KairosAuth.Color.gradientStart, KairosAuth.Color.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: KairosAuth.IconSize.close))
                            .foregroundColor(KairosAuth.Color.secondaryText)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Dismiss the paywall")
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: KairosAuth.IconSize.heroIcon))
                .foregroundColor(KairosAuth.Color.accent)
                .accessibilityHidden(true)
            
            Text("Unlock Unlimited Invites")
                .font(KairosAuth.Typography.cardTitle)
                .foregroundColor(KairosAuth.Color.primaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, KairosAuth.Spacing.large)
    }
    
    private var reasonSection: some View {
        VStack(spacing: KairosAuth.Spacing.small) {
            // Prominent alert-style message
            HStack(spacing: KairosAuth.Spacing.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: KairosAuth.IconSize.itemIcon))
                    .foregroundColor(KairosAuth.Color.warning)
                    .accessibilityHidden(true)
                
                Text(reason)
                    .font(KairosAuth.Typography.itemTitle)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(KairosAuth.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                    .fill(KairosAuth.Color.warning.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                    .stroke(KairosAuth.Color.warning.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, KairosAuth.Spacing.horizontalPadding)
    }
    
    private var pricingToggle: some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            // Monthly option
            periodButton(period: .monthly, price: "$6.99/mo")
            
            // Yearly option (with badge)
            ZStack(alignment: .topTrailing) {
                periodButton(period: .yearly, price: "$59/yr")
                
                // "Save 15%" badge
                Text("Save 15%")
                    .font(KairosAuth.Typography.statusBadge)
                    .foregroundColor(KairosAuth.Color.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KairosAuth.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.small))
                    .offset(x: 10, y: -8)
            }
        }
        .padding(.vertical, KairosAuth.Spacing.medium)
    }
    
    private func periodButton(period: SubscriptionPeriod, price: String) -> some View {
        Button {
            withAnimation(KairosAuth.Animation.uiUpdate) {
                selectedPeriod = period
            }
        } label: {
            VStack(spacing: KairosAuth.Spacing.small) {
                Text(period.displayName)
                    .font(KairosAuth.Typography.buttonLabel)
                Text(price)
                    .font(KairosAuth.Typography.itemSubtitle)
            }
            .foregroundColor(
                selectedPeriod == period ? KairosAuth.Color.primaryText : KairosAuth.Color.secondaryText
            )
            .frame(maxWidth: .infinity)
            .padding(KairosAuth.Spacing.cardPadding)
            .background(
                selectedPeriod == period ? KairosAuth.Color.cardBackground : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairosAuth.Radius.card)
                    .stroke(
                        selectedPeriod == period ? KairosAuth.Color.accent : KairosAuth.Color.cardBorder,
                        lineWidth: selectedPeriod == period ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
        }
    }
    
    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: KairosAuth.Spacing.medium) {
            Text("Plus Features")
                .font(KairosAuth.Typography.cardTitle)
                .foregroundColor(KairosAuth.Color.primaryText)
            
            featureRow(icon: "infinity", text: "Unlimited invites per month", included: true)
            featureRow(icon: "sparkles", text: "Unlimited AI suggestions", included: true)
            featureRow(icon: "headphones", text: "Priority support", included: true)
            featureRow(icon: "star.fill", text: "Early access to new features", included: true)
            
            Divider()
                .background(KairosAuth.Color.cardBorder)
                .padding(.vertical, KairosAuth.Spacing.small)
            
            Text("Free Tier (After Trial)")
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.secondaryText)
            
            featureRow(icon: "number", text: "15 invites per month", included: false)
            featureRow(icon: "clock", text: "60-day trial period", included: false)
            featureRow(icon: "chart.bar", text: "30 invites total limit", included: false)
        }
        .padding(KairosAuth.Spacing.cardPadding)
        .background(KairosAuth.Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.card))
    }
    
    private func featureRow(icon: String, text: String, included: Bool) -> some View {
        HStack(spacing: KairosAuth.Spacing.medium) {
            Image(systemName: icon)
                .font(.system(size: KairosAuth.IconSize.itemIcon))
                .foregroundColor(included ? KairosAuth.Color.accent : KairosAuth.Color.secondaryText)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            Text(text)
                .font(KairosAuth.Typography.itemSubtitle)
                .foregroundColor(KairosAuth.Color.primaryText)
            
            Spacer()
        }
    }
    
    private var purchaseButtons: some View {
        VStack(spacing: KairosAuth.Spacing.medium) {
            if let product = selectedProduct {
                Button {
                    Task {
                        try? await storeManager.purchase(product)
                        // Dismiss on successful purchase
                        if storeManager.subscriptionStatus.isPlusUser {
                            dismiss()
                        }
                    }
                } label: {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Subscribe - \(product.displayPrice)")
                    }
                }
                .font(KairosAuth.Typography.buttonLabel)
                .foregroundColor(KairosAuth.Color.primaryText)
                .padding(.horizontal, KairosAuth.Spacing.large)
                .padding(.vertical, KairosAuth.Spacing.buttonVertical)
                .frame(maxWidth: .infinity)
                .background(KairosAuth.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: KairosAuth.Radius.button))
                .disabled(storeManager.isPurchasing)
            } else {
                ProgressView()
                    .tint(KairosAuth.Color.accent)
            }
            
            if let error = storeManager.purchaseError {
                Text(error)
                    .font(KairosAuth.Typography.bodySmall)
                    .foregroundColor(KairosAuth.Color.accent)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                try? await storeManager.restorePurchases()
                // Dismiss if restore successful
                if storeManager.subscriptionStatus.isPlusUser {
                    dismiss()
                }
            }
        } label: {
            Text("Restore Purchases")
                .font(KairosAuth.Typography.linkPrimary)
                .foregroundColor(KairosAuth.Color.accent)
        }
        .padding(.bottom, KairosAuth.Spacing.large)
    }
    
    // MARK: - Helpers
    
    private var selectedProduct: Product? {
        storeManager.availableProducts.first { product in
            if selectedPeriod == .monthly {
                return product.id == StoreKitManager.ProductID.monthlyPlus.rawValue
            } else {
                return product.id == StoreKitManager.ProductID.yearlyPlus.rawValue
            }
        }
    }
    
    enum SubscriptionPeriod {
        case monthly
        case yearly
        
        var displayName: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PlusPaywallView(
        storeManager: StoreKitManager(),
    reason: "You've reached 15 invites this month"
    )
}
