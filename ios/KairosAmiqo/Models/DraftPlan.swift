//
//  DraftPlan.swift
//  KairosAmiqo
//
//  Auto-save draft plan state to UserDefaults
//  Persists across app restarts, works offline
//

import Foundation

/// Draft plan state for Create Plan flow
/// Auto-saved to UserDefaults on every change
struct DraftPlan: Codable {
    let id: String
    let createdAt: Date
    var participants: [PlanParticipant]
    var intent: IntentTemplate?
    var times: [ProposedSlot]
    var venues: [VenueInfo]
    var currentStep: Int

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        participants: [PlanParticipant] = [],
        intent: IntentTemplate? = nil,
        times: [ProposedSlot] = [],
        venues: [VenueInfo] = [],
        currentStep: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.participants = participants
        self.intent = intent
        self.times = times
        self.venues = venues
        self.currentStep = currentStep
    }

    /// Check if draft has any meaningful content
    var hasContent: Bool {
        !participants.isEmpty || intent != nil || !times.isEmpty || !venues.isEmpty
    }

    /// Check if draft is complete enough to send
    var isComplete: Bool {
        !participants.isEmpty && intent != nil
    }
}

// MARK: - Persistence

extension DraftPlan {
    private static let key = "kairos.draftPlan"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Save draft to UserDefaults
    func save() {
        guard let encoded = try? Self.encoder.encode(self) else {
            print("⚠️ DraftPlan: Failed to encode")
            return
        }
        UserDefaults.standard.set(encoded, forKey: Self.key)
        print("💾 DraftPlan: Saved (\(participants.count) participants, step \(currentStep))")
    }

    /// Load draft from UserDefaults
    static func load() -> DraftPlan? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let draft = try? decoder.decode(DraftPlan.self, from: data) else {
            return nil
        }
        print("📂 DraftPlan: Loaded (\(draft.participants.count) participants, step \(draft.currentStep))")
        return draft
    }

    /// Clear saved draft
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        print("🗑️ DraftPlan: Cleared")
    }

    /// Check if draft exists without loading
    static var exists: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }
}
