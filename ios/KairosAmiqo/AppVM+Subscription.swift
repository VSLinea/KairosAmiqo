import Foundation
import SwiftUI

// MARK: - Subscription & Billing Extension (Task 29)

extension AppVM {
    
    // MARK: - Free Tier Plan Limits
    
    /// Check if user can create a new plan based on free tier limits
    /// Free tier: 15 plans/month OR 60 days trial OR 30 plans total (whichever comes first)
    /// Plus tier: Unlimited
    func canCreatePlan() -> Bool {
        guard !isPlusUser else { 
            print("✅ Plus user - unlimited plans")
            return true 
        }
        
        // Check 1: Monthly limit
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())!.start
        
        // Parse date_created strings to Date for comparison
        let iso8601 = ISO8601DateFormatter()
        let plansThisMonth = items.filter { negotiation in
            guard let dateString = negotiation.date_created ?? negotiation.created_at,
                  let date = iso8601.date(from: dateString) else {
                return false
            }
            return date >= startOfMonth
        }.count
        
        print("📊 [PAYWALL] Plans this month: \(plansThisMonth)/\(freeTierMonthlyPlanLimit)")
        if plansThisMonth >= freeTierMonthlyPlanLimit {
            print("🚫 [PAYWALL] Monthly limit hit!")
            return false
        }
        
        // Check 2: Trial period
        let daysSinceSignup = calendar.dateComponents([.day], from: userSignupDate, to: Date()).day ?? 0
        print("📊 [PAYWALL] Days since signup: \(daysSinceSignup)/\(freeTierTrialDays)")
        if daysSinceSignup > freeTierTrialDays {
            print("🚫 [PAYWALL] Trial expired!")
            return false
        }
        
        // Check 3: Total cap
        print("📊 [PAYWALL] Total plans: \(items.count)/\(freeTierTotalPlanCap)")
        if items.count >= freeTierTotalPlanCap {
            print("🚫 [PAYWALL] Total limit hit!")
            return false
        }
        
        print("✅ [PAYWALL] Can create plan")
        return true
    }
    
    /// Get reason why plan creation is blocked (for paywall messaging)
    /// Returns user-friendly message explaining which limit was hit
    func getPaywallReason() -> String {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())!.start
        
        // Parse date_created strings to Date for comparison
        let iso8601 = ISO8601DateFormatter()
        let plansThisMonth = items.filter { negotiation in
            guard let dateString = negotiation.date_created ?? negotiation.created_at,
                  let date = iso8601.date(from: dateString) else {
                return false
            }
            return date >= startOfMonth
        }.count
        
        if plansThisMonth >= freeTierMonthlyPlanLimit {
            return "You've reached \(freeTierMonthlyPlanLimit) plans this month. Wait until next month or upgrade to Plus for unlimited plans."
        }
        
        let daysSinceSignup = calendar.dateComponents([.day], from: userSignupDate, to: Date()).day ?? 0
        if daysSinceSignup > freeTierTrialDays {
            return "Your \(freeTierTrialDays)-day trial has ended. Upgrade to Plus to continue creating plans."
        }
        
        if items.count >= freeTierTotalPlanCap {
            return "You've created \(freeTierTotalPlanCap) plans total. Upgrade to Plus for unlimited plans."
        }
        
        return "Upgrade to Plus for unlimited plans"
    }
    
    // MARK: - AI Counter Limits (Task 29 - Option C)
    
    /// Check if user can use AI-powered counter proposals
    /// Free tier: 5 AI counters/month
    /// Plus tier: Unlimited
    func canUseAI() -> Bool {
        guard !isPlusUser else {
            print("✅ [AI] Plus user - unlimited AI counters")
            return true
        }
        
        let aiCountersUsed = getAICountersUsedThisMonth()
        print("📊 [AI] AI counters used this month: \(aiCountersUsed)/\(freeTierAICounterLimit)")
        
        if aiCountersUsed >= freeTierAICounterLimit {
            print("🚫 [AI] AI counter limit hit!")
            return false
        }
        
        print("✅ [AI] Can use AI counter")
        return true
    }
    
    /// Get count of AI counters used this month
    func getAICountersUsedThisMonth() -> Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())!.start
        
        return aiCounterTimestamps.filter { $0 >= startOfMonth }.count
    }
    
    /// Get the free tier AI counter limit
    func getAICounterLimit() -> Int {
        return freeTierAICounterLimit
    }
    
    /// Record that user used an AI counter action
    func recordAICounterUsed() {
        var timestamps = aiCounterTimestamps
        timestamps.append(Date())
        aiCounterTimestamps = timestamps
        
        let used = getAICountersUsedThisMonth()
        print("📊 [AI] AI counter recorded. Total this month: \(used)/\(freeTierAICounterLimit)")
    }
    
    /// Get reason why AI counter is blocked (for paywall messaging)
    func getAIPaywallReason() -> String {
        let _ = getAICountersUsedThisMonth()
        return "You've used all \(freeTierAICounterLimit) AI-powered counters this month. Upgrade to Plus for unlimited AI negotiations."
    }
}
