//
//  PreferenceLearningService.swift
//  KairosAmiqo
//
//  Task 28: Agent-to-Agent Negotiation - Preference Learning Engine
//  Week 1, Day 5: Pattern extraction and continuous learning
//
//  Created: 2025-11-01
//  See: /AGENT-TO-AGENT-IMPLEMENTATION-PLAN.md
//  See: /.github/apple-docs-grounded-mode.md (Foundation.Date iOS 2.0+, Foundation.UUID iOS 6.0+)
//

import Foundation
import CryptoKit

/// Service that analyzes user behavior to learn preferences for agent decision-making
/// Continuously updates AgentPreferences based on confirmed plans
///
/// **Learning Algorithm:**
/// - Frequency-based scoring (0.0-1.0) for venues, times, categories
/// - Exponential moving average for smooth updates
/// - Recency weighting (newer plans have higher weight)
///
/// **Data Sources:**
/// - Confirmed negotiations (status = "confirmed")
/// - Accepted event invites (calendar_synced = true)
/// - User explicit feedback (future: thumbs up/down)
///
/// **Privacy:**
/// - All learning happens on-device
/// - AgentPreferences encrypted before upload to Directus
/// - Server never sees plaintext patterns
///
/// @available(iOS 15.0, *)
final class PreferenceLearningService {
    
    // MARK: - Properties
    
    /// Directus client for uploading encrypted preferences
    private let directusClient: HTTPClient
    
    /// Current user ID
    private let userId: UUID
    
    /// Alpha for exponential moving average (0.0-1.0)
    /// Higher = more weight on recent data
    /// Default: 0.3 (30% new, 70% historical)
    private let learningRate: Double = 0.3
    
    /// Minimum negotiations before trusting patterns
    /// Below this threshold, patterns are low-confidence
    /// Default: 5
    private let minSampleSize: Int = 5
    
    // MARK: - Initialization
    
    /// Initialize preference learning service
    /// - Parameters:
    ///   - userId: Current user UUID
    ///   - directusClient: HTTP client for Directus API
    init(userId: UUID, directusClient: HTTPClient) {
        self.userId = userId
        self.directusClient = directusClient
    }
    
    // MARK: - Public API
    
    /// Analyze negotiation history and update learned patterns
    /// Call this after:
    /// - Plan confirmed (user accepted proposal)
    /// - App launch (daily background refresh)
    /// - Settings → Agent Preferences → "Refresh Patterns" button
    ///
    /// - Parameters:
    ///   - negotiations: All negotiations for this user
    ///   - events: All events for this user (for calendar analysis)
    ///   - currentPreferences: Current agent preferences (will be updated)
    /// - Returns: Updated agent preferences with new learned patterns
    /// - Throws: If analysis fails or update to Directus fails
    @MainActor
    func updateLearnedPatterns(
        from negotiations: [Negotiation],
        events: [EventDTO],
        currentPreferences: AgentPreferences
    ) async throws -> AgentPreferences {
        print("🧠 PreferenceLearningService: Starting pattern analysis...")
        print("   Negotiations: \(negotiations.count), Events: \(events.count)")
        
        // Step 1: Extract patterns from confirmed plans
        let venueScores = analyzeVenuePreferences(from: negotiations)
        let timeScores = analyzeTimePreferences(from: negotiations)
        let categoryScores = analyzeCategoryPreferences(from: negotiations)
        let durationPrefs = analyzeDurationPreferences(from: negotiations)
        let friendScores = analyzeFriendAffinityScores(from: negotiations)
        
        // Step 2: Merge with existing patterns using exponential moving average
        var updatedPatterns = currentPreferences.learnedPatterns
        updatedPatterns.favoriteVenues = mergeScores(
            existing: updatedPatterns.favoriteVenues,
            new: venueScores
        )
        updatedPatterns.preferredTimes = mergeIntScores(
            existing: updatedPatterns.preferredTimes,
            new: timeScores
        )
        updatedPatterns.categoryPreferences = mergeScores(
            existing: updatedPatterns.categoryPreferences,
            new: categoryScores
        )
        updatedPatterns.preferredDurations = mergeDurations(
            existing: updatedPatterns.preferredDurations,
            new: durationPrefs
        )
        updatedPatterns.friendAffinityScores = mergeScores(
            existing: updatedPatterns.friendAffinityScores,
            new: friendScores
        )
        
        // Step 3: Update metadata
        updatedPatterns.negotiationCount = negotiations.filter { $0.status == "confirmed" }.count
        updatedPatterns.lastUpdated = Date()
        
        // Step 4: Create updated preferences
        var newPreferences = currentPreferences
        newPreferences.learnedPatterns = updatedPatterns
        newPreferences.dateUpdated = Date()
        
        // Step 5: Upload encrypted preferences to Directus
        try await savePreferences(newPreferences)
        
        print("✅ PreferenceLearningService: Patterns updated successfully")
        print("   Venues: \(updatedPatterns.favoriteVenues.count)")
        print("   Times: \(updatedPatterns.preferredTimes.count)")
        print("   Categories: \(updatedPatterns.categoryPreferences.count)")
        print("   Friends: \(updatedPatterns.friendAffinityScores.count)")
        
        return newPreferences
    }
    
    /// Check if veto rule would block a proposed time
    /// - Parameters:
    ///   - time: Proposed start time
    ///   - duration: Plan duration in minutes
    ///   - venueId: Proposed venue UUID
    ///   - vetoRules: User's active veto rules
    /// - Returns: `nil` if allowed, error message if blocked
    func checkVetoRules(
        time: Date,
        duration: Int,
        venueId: UUID?,
        vetoRules: [VetoRule]
    ) -> String? {
        let activeRules = vetoRules.filter { $0.isActive }
        
        for rule in activeRules {
            if let violation = evaluateVetoRule(rule, time: time, duration: duration, venueId: venueId) {
                return violation
            }
        }
        
        return nil // No violations
    }
    
    /// Calculate confidence score for learned patterns
    /// - Parameter patterns: Learned patterns to evaluate
    /// - Returns: Confidence score (0.0-1.0)
    ///   - 0.0-0.3: Low confidence (< 5 negotiations)
    ///   - 0.3-0.7: Medium confidence (5-20 negotiations)
    ///   - 0.7-1.0: High confidence (20+ negotiations)
    func calculateConfidence(for patterns: LearnedPatterns) -> Double {
        let count = patterns.negotiationCount
        
        if count < minSampleSize {
            // Low confidence: Scale linearly from 0.0 to 0.3
            return Double(count) / Double(minSampleSize) * 0.3
        } else if count < 20 {
            // Medium confidence: Scale from 0.3 to 0.7
            let normalized = Double(count - minSampleSize) / Double(20 - minSampleSize)
            return 0.3 + (normalized * 0.4)
        } else {
            // High confidence: Scale from 0.7 to 1.0 (capped at 1.0)
            let normalized = min(Double(count - 20) / 30.0, 1.0)
            return 0.7 + (normalized * 0.3)
        }
    }
    
    // MARK: - Private Analysis Methods
    
    /// Analyze venue preferences from confirmed negotiations
    /// - Parameter negotiations: All negotiations
    /// - Returns: Venue scores (key = poi_id, value = preference 0.0-1.0)
    private func analyzeVenuePreferences(from negotiations: [Negotiation]) -> [UUID: Double] {
        let confirmed = negotiations.filter { $0.status == "confirmed" }
        guard !confirmed.isEmpty else { return [:] }
        
        // Extract all venues from confirmed plans
        var venueCounts: [UUID: Int] = [:]
        for negotiation in confirmed {
            if let venues = negotiation.proposed_venues {
                for venue in venues {
                    if let venueId = venue.id { // VenueInfo.id is the POI UUID
                        venueCounts[venueId, default: 0] += 1
                    }
                }
            }
        }
        
        // Convert counts to frequency scores
        let total = Double(confirmed.count)
        var scores: [UUID: Double] = [:]
        for (venueId, count) in venueCounts {
            scores[venueId] = Double(count) / total
        }
        
        return scores
    }
    
    /// Analyze time preferences from confirmed negotiations
    /// - Parameter negotiations: All negotiations
    /// - Returns: Time scores (key = hour 0-23, value = preference 0.0-1.0)
    private func analyzeTimePreferences(from negotiations: [Negotiation]) -> [Int: Double] {
        let confirmed = negotiations.filter { $0.status == "confirmed" }
        guard !confirmed.isEmpty else { return [:] }
        
        // Extract hours from confirmed plan start times
        var hourCounts: [Int: Int] = [:]
        let calendar = Calendar.current
        
        for negotiation in confirmed {
            if let slots = negotiation.proposed_slots {
                for slot in slots {
                    // ProposedSlot.time is String (ISO8601), use computed .date property
                    if let timeDate = slot.date {
                        let hour = calendar.component(.hour, from: timeDate)
                        hourCounts[hour, default: 0] += 1
                    }
                }
            }
        }
        
        // Convert counts to frequency scores
        let total = Double(confirmed.count)
        var scores: [Int: Double] = [:]
        for (hour, count) in hourCounts {
            scores[hour] = Double(count) / total
        }
        
        return scores
    }
    
    /// Analyze category preferences from confirmed negotiations
    /// - Parameter negotiations: All negotiations
    /// - Returns: Category scores (key = category, value = preference 0.0-1.0)
    private func analyzeCategoryPreferences(from negotiations: [Negotiation]) -> [String: Double] {
        let confirmed = negotiations.filter { $0.status == "confirmed" }
        guard !confirmed.isEmpty else { return [:] }
        
        // Extract categories (intent_category field)
        var categoryCounts: [String: Int] = [:]
        for negotiation in confirmed {
            if let category = negotiation.intent_category {
                categoryCounts[category, default: 0] += 1
            }
        }
        
        // Convert counts to frequency scores
        let total = Double(confirmed.count)
        var scores: [String: Double] = [:]
        for (category, count) in categoryCounts {
            scores[category] = Double(count) / total
        }
        
        return scores
    }
    
    /// Analyze preferred durations by category
    /// - Parameter negotiations: All negotiations
    /// - Returns: Duration preferences (key = category, value = avg minutes)
    private func analyzeDurationPreferences(from negotiations: [Negotiation]) -> [String: Int] {
        let confirmed = negotiations.filter { $0.status == "confirmed" }
        guard !confirmed.isEmpty else { return [:] }
        
        // Group durations by category
        var categoryDurations: [String: [Int]] = [:]
        
        for negotiation in confirmed {
            guard let category = negotiation.intent_category,
                  let slots = negotiation.proposed_slots,
                  let _ = slots.first else { continue }
            
            // Calculate duration (assume 60 min default if no end time)
            let duration = 60 // TODO: Extract from proposed_venues or calculate from time slots
            
            categoryDurations[category, default: []].append(duration)
        }
        
        // Calculate average duration per category
        var avgDurations: [String: Int] = [:]
        for (category, durations) in categoryDurations {
            let avg = durations.reduce(0, +) / durations.count
            avgDurations[category] = avg
        }
        
        return avgDurations
    }
    
    /// Analyze friend affinity scores
    /// - Parameter negotiations: All negotiations
    /// - Returns: Friend scores (key = friend_user_id, value = affinity 0.0-1.0)
    private func analyzeFriendAffinityScores(from negotiations: [Negotiation]) -> [UUID: Double] {
        let confirmed = negotiations.filter { $0.status == "confirmed" }
        guard !confirmed.isEmpty else { return [:] }
        
        // Extract all participants except current user
        var friendCounts: [UUID: Int] = [:]
        
        for negotiation in confirmed {
            if let participants = negotiation.participants {
                for participant in participants {
                    let friendId = participant.user_id
                    guard friendId != userId else { continue }
                    
                    friendCounts[friendId, default: 0] += 1
                }
            }
        }
        
        // Convert counts to frequency scores
        let total = Double(confirmed.count)
        var scores: [UUID: Double] = [:]
        for (friendId, count) in friendCounts {
            scores[friendId] = Double(count) / total
        }
        
        return scores
    }
    
    // MARK: - Score Merging (Exponential Moving Average)
    
    /// Merge existing scores with new scores using exponential moving average
    /// - Parameters:
    ///   - existing: Current scores
    ///   - new: Newly analyzed scores
    /// - Returns: Merged scores with EMA applied
    private func mergeScores<K: Hashable>(
        existing: [K: Double],
        new: [K: Double]
    ) -> [K: Double] {
        var merged = existing
        
        for (key, newScore) in new {
            if let existingScore = existing[key] {
                // EMA: new_value = α × new + (1 - α) × old
                merged[key] = learningRate * newScore + (1 - learningRate) * existingScore
            } else {
                // First time seeing this item
                merged[key] = newScore
            }
        }
        
        return merged
    }
    
    /// Merge integer-keyed scores (for time preferences)
    private func mergeIntScores(
        existing: [Int: Double],
        new: [Int: Double]
    ) -> [Int: Double] {
        var merged = existing
        
        for (key, newScore) in new {
            if let existingScore = existing[key] {
                merged[key] = learningRate * newScore + (1 - learningRate) * existingScore
            } else {
                merged[key] = newScore
            }
        }
        
        return merged
    }
    
    /// Merge duration preferences (simple average, not EMA)
    private func mergeDurations(
        existing: [String: Int],
        new: [String: Int]
    ) -> [String: Int] {
        var merged = existing
        
        for (category, newDuration) in new {
            if let existingDuration = existing[category] {
                // Simple average (not EMA) for durations
                merged[category] = (existingDuration + newDuration) / 2
            } else {
                merged[category] = newDuration
            }
        }
        
        return merged
    }
    
    // MARK: - Veto Rule Evaluation
    
    /// Evaluate single veto rule against proposed time
    /// - Returns: Error message if rule violated, nil if allowed
    private func evaluateVetoRule(
        _ rule: VetoRule,
        time: Date,
        duration: Int,
        venueId: UUID?
    ) -> String? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let weekday = calendar.component(.weekday, from: time)
        
        switch rule.type {
        case .neverBefore:
            if let minHour = Int(rule.value), hour < minHour {
                return "Veto: Never schedule before \(minHour):00"
            }
            
        case .neverAfter:
            if let maxHour = Int(rule.value), hour >= maxHour {
                return "Veto: Never schedule after \(maxHour):00"
            }
            
        case .neverOnDays:
            // Parse JSON array of day names
            if let data = rule.value.data(using: .utf8),
               let days = try? JSONDecoder().decode([String].self, from: data) {
                let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
                let currentDay = dayNames[weekday - 1]
                
                if days.contains(currentDay) {
                    return "Veto: Never schedule on \(currentDay.capitalized)"
                }
            }
            
        case .neverAtVenue:
            if let blockedVenueId = UUID(uuidString: rule.value),
               venueId == blockedVenueId {
                return "Veto: Never schedule at this venue"
            }
            
        case .maxDuration:
            if let maxDuration = Int(rule.value), duration > maxDuration {
                return "Veto: Plan duration (\(duration)min) exceeds max (\(maxDuration)min)"
            }
            
        case .respectCalendar:
            // TODO: Implement calendar conflict check with EventKit
            // For now, return nil (not implemented)
            break
            
        case .neverInvite:
            // TODO: Check if blocked friend is in participant list
            // Requires participant data in function signature
            break
            
        case .custom:
            // TODO: Implement custom rule evaluation
            // Requires JSON parsing of rule definition
            break
        }
        
        return nil
    }
    
    // MARK: - Persistence
    
    /// Save encrypted agent preferences to Directus
    /// - Parameter preferences: Agent preferences to save
    /// - Throws: If encryption or upload fails
    private func savePreferences(_ preferences: AgentPreferences) async throws {
        // Step 1: Encode preferences to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(preferences)
        
        // Step 2: Encrypt with user's master key (load from Keychain)
        let masterKey = try await KeychainManager.loadOrGenerateUserMasterKey()
        
        let encryptedData = try await E2EEManager.encrypt(jsonData, with: masterKey)
        let base64Encrypted = encryptedData.base64EncodedString()
        
        // Step 3: Upload to Directus
        let payload: [String: Any] = [
            "user_id": preferences.userId.uuidString,
            "encrypted_data": base64Encrypted,
            "date_updated": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Check if preferences already exist
        let existingPath = "/items/user_agent_preferences?filter[user_id][_eq]=\(preferences.userId.uuidString)"
        let (existingData, _) = try await directusClient.get(path: existingPath)
        
        struct PreferencesResponse: Codable {
            let data: [AgentPreferencesRecord]
        }
        
        struct AgentPreferencesRecord: Codable {
            let id: UUID
        }
        
        let decoder = JSONDecoder()
        let existingResponse = try decoder.decode(PreferencesResponse.self, from: existingData)
        
        if let existingRecord = existingResponse.data.first {
            // Update existing
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            _ = try await directusClient.patch(
                path: "/items/user_agent_preferences/\(existingRecord.id.uuidString)",
                body: payloadData
            )
            print("✅ Updated existing agent preferences: \(existingRecord.id)")
        } else {
            // Create new
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            _ = try await directusClient.post(
                path: "/items/user_agent_preferences",
                body: payloadData
            )
            print("✅ Created new agent preferences")
        }
    }
}

// MARK: - Errors

enum PreferenceLearningError: Error, LocalizedError {
    case encryptionKeyNotFound
    case invalidVetoRuleFormat
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .encryptionKeyNotFound:
            return "Encryption key not found. Please log in again."
        case .invalidVetoRuleFormat:
            return "Veto rule has invalid format."
        case .insufficientData:
            return "Not enough negotiation history to learn patterns."
        }
    }
}
