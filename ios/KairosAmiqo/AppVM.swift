import EventKit
import Security
import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit // For UIImpactFeedbackGenerator (Task 12 - haptic feedback)
#endif
import AuthenticationServices

// Use EventDTO for API layer and Event for domain model

// Minimal model to detect TOKEN_EXPIRED from Directus responses
private struct APIErrorBody: Codable {
    struct ErrorItem: Codable {
        struct Extensions: Codable { let code: String? }
        let message: String
        let extensions: Extensions?
    }

    let errors: [ErrorItem]
}

struct EventBucket: Identifiable {
    enum Kind: String, CaseIterable {
        case today
        case tomorrow
        case thisWeek
        case later
        case upcoming
        case past

        static var displayOrder: [Kind] { [.today, .tomorrow, .thisWeek, .later, .upcoming, .past] }

        var title: String {
            switch self {
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .thisWeek: return "This Week"
            case .later: return "Later"
            case .upcoming: return "Upcoming"
            case .past: return "Past"
            }
        }
    }

    let kind: Kind
    let events: [EventDTO]

    var id: String { kind.rawValue }
    var title: String { kind.title }
}

@MainActor
final class AppVM: NSObject, ObservableObject {
    // MARK: - Services
    
    private let cache = CacheManager()
    private let calendarHelper = CalendarHelper()
    
    // MARK: - Subscription & Billing (Task 29)
    
    /// StoreKit manager for in-app purchases
    @Published var storeManager = StoreKitManager()
    
    /// User signup date (for 60-day trial calculation)
    @Published var userSignupDate: Date = Date()
    
    /// Computed: Is user on Plus tier?
    var isPlusUser: Bool {
        storeManager.subscriptionStatus.isPlusUser
    }
    
    /// Track AI-powered counter actions this month (free tier: 5/month limit)
    /// Stored as timestamps to allow monthly reset calculation
    var aiCounterTimestamps: [Date] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "aiCounterTimestamps"),
                  let timestamps = try? JSONDecoder().decode([Date].self, from: data) else {
                return []
            }
            return timestamps
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "aiCounterTimestamps")
            }
        }
    }
    
    // MARK: - Free Tier Cost Control Constants (Task 29)
    
    // ⚠️ COST CONTROL PARAMETERS - Adjust these to control AI spend
    // Current limits balance user engagement vs developer costs
    // Monitor actual usage and adjust if costs exceed budget
    
    /// Free tier: Plans created per month (initiating new conversations)
    /// Cost impact: Plan creation uses AI for venue suggestions, time optimization
    /// Recommended range: 10-20 plans/month
    /// Current: 15 plans/month
    let freeTierMonthlyPlanLimit = 15
    
    /// Free tier: AI-powered counters per month (responding with AI suggestions)
    /// Cost impact: Each counter = 1 AI session (~$0.0002 per session with GPT-4o-mini)
    /// Recommended range: 3-10 counters/month
    /// Current: 5 counters/month
    /// ⚠️ REDUCE THIS FIRST if costs are too high (try 3 counters)
    let freeTierAICounterLimit = 5
    
    /// Free tier: Trial period in days
    /// After this period, user must upgrade to create plans
    /// Current: 60 days (2 months)
    let freeTierTrialDays = 60
    
    /// Free tier: Total plans cap (lifetime)
    /// Prevents long-term free users from accumulating unlimited plans
    /// Current: 30 plans total
    let freeTierTotalPlanCap = 30
    
    // COST SCENARIOS (for monitoring):
    // At 10,000 users with 5% conversion (500 paying):
    //
    // Revenue: 500 × $6.99 = $3,495/month
    // Apple cut (30%): -$1,049
    // Net revenue: $2,446/month
    //
    // AI Costs (OpenAI GPT-4o-mini at $0.0002/session):
    // - Paying users: 500 × 20 sessions × $0.0002 = $2/month
    // - Free users: 9,500 × 20 sessions × $0.0002 = $38/month
    // Total AI cost: $40/month
    //
    // NET PROFIT: $2,446 - $40 = $2,406/month = $28,872/year ✅
    //
    // Break-even: Need ~170 paying users to cover free tier costs
    // Self-hosting makes sense at: 100,000+ users (saves ~$400/month)
    
    // MARK: - Analytics (Task 30)
    
    private let analytics = AnalyticsService.shared
    
    // MARK: - Published State

    // Auth / Negotiations (existing)
    @Published var jwt: String?
    @Published var items: [Negotiation] = []
    @Published var lastCreated: Negotiation?
    @Published var error: String?
    @Published var busy = false

    // Calendar State
    @Published var calendarPermissionStatus: CalendarAccessStatus = .notDetermined

    /// Represents the current state of calendar access permissions
    ///
    /// This enum provides a platform-independent way to handle calendar access states,
    /// abstracting away the underlying EventKit authorization status differences
    /// across iOS versions.
    enum CalendarAccessStatus {
        /// Initial state, user hasn't been asked for permission
        case notDetermined
        /// User explicitly denied access
        case denied
        /// Access is restricted at the system level
        case restricted
        /// User granted full access to calendar
        case authorized
        /// User granted write-only access (iOS 17+)
        case writeOnly
        /// User granted full access (iOS 17+)
        case fullAccess

        init(from ekStatus: EKAuthorizationStatus) {
            switch ekStatus {
            case .notDetermined:
                self = .notDetermined
            case .denied:
                self = .denied
            case .restricted:
                self = .restricted
            case .authorized:
                self = .authorized
            case .fullAccess:
                self = .fullAccess
            case .writeOnly:
                self = .writeOnly
            @unknown default:
                print("Warning: Unknown EKAuthorizationStatus case: \(ekStatus.rawValue)")
                // Default to most restrictive for unknown status
                self = .restricted
            }
        }
    }

    // Events state (used by EventsView and EventsAPI extension)
    @Published var events: [EventDTO] = []
    @Published var errorMessage: String?

    // Intent templates (used by CreateProposalFlow)
    @Published var intentTemplates: [IntentTemplate] = []
    
    // Kairos friends (used by ParticipantsStep)
    @Published var friends: [KairosFriend] = []
    
    // Current user (Phase 3 - for ownership checks in modals)
    @Published var currentUser: KairosFriend? = nil

    // Accept action state (Task 12)
    @Published var isAccepting = false
    @Published var acceptError: String?
    
    // Counter action state (Task 13)
    @Published var isCountering = false
    @Published var counterError: String?
    
    // Decline/withdraw state (Task 13)
    @Published var isDeclining = false
    @Published var declineError: String?

    // Owner actions (Task 14) - Plan creator permissions
    @Published var isFinalizing = false
    @Published var finalizeError: String?
    @Published var isCancellingPlan = false
    @Published var cancelPlanError: String?
    @Published var isDeletingPlan = false
    @Published var deletePlanError: String?

    // Event management actions (Task 14)
    @Published var isCancellingEvent = false
    @Published var cancelEventError: String?
    @Published var isLeavingEvent = false
    @Published var leaveEventError: String?
    
    // Calendar confirmation state (Task 14)
    @Published var showCalendarToast = false
    @Published var calendarToastMessage: String?
    @Published var isAddingToCalendar = false
    @Published var calendarError: String?
    @Published var showConfirmationSheet = false
    @Published var confirmedEvent: EventDTO?
    
    // Waiting for others state (Task 14 - multi-participant flow)
    @Published var showWaitingMessage = false
    @Published var waitingMessageText: String?

    // Unified loading state for lists
    enum LoadState: Equatable {
        case idle, loading, loaded, empty, error(String)
        
        static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.empty, .empty):
                return true
            case (.error, .error):
                return true // Treat all errors as equal for state comparison
            default:
                return false
            }
        }
    }
    @Published var eventsState: LoadState = .idle
    @Published var itemsState: LoadState = .idle

    enum LaunchPhase: Equatable { case initializing, onboarding, dashboard, ready }
    @Published var launchPhase: LaunchPhase = .initializing
    @Published var hasCompletedOnboarding = false
    @Published var showLoginSheet = false

    // Apple Sign-In state
    @Published var isConnectingWithApple = false
    @Published var appleSignInError: String?

    // Google Sign-In state (SUSPENDED - Phase 4)
    // @Published var isConnectingWithGoogle = false
    // @Published var googleSignInError: String?

    // Dashboard state
    @Published var hasSeenTutorialHint = false
    @Published var expandedCards: Set<String> = []

    // Unified Create Plan Flow state (shared between Dashboard templates & Plans tab)
    @Published var showingCreateProposal = false
    @Published var showConversationalPlanFlow = false // Conversational AI planning (Phase 3)
    @Published var selectedTemplate: IntentTemplate?
    @Published var planDraftForEditing: Negotiation?

    // Deep linking state (Task 16 - plan navigation from URL scheme/Universal Links)
    @Published var selectedDeepLinkedPlanId: UUID?
    @Published var showDeepLinkedPlan = false
    @Published var guestResponseToken: String?
    @Published var showGuestResponseSheet = false
    
    // Places state (Phase 5 - POI discovery & learned locations)
    @Published var pois: [POI] = []
    @Published var learnedPlaces: [LearnedPlace] = []
    @Published var favoritePOIs: Set<UUID> = [] // POI IDs
    @Published var selectedPOI: POI?
    @Published var showPOIDetail = false
    @Published var placesState: LoadState = .idle
    
    // Profile Modal (App-level presentation)
    @Published var showingProfile = false
    
    // Location Services (Phase 5 - Task 25: Near Me feature)
    /// User's current location for distance calculations and "Near Me" filter
    /// See: /docs/apple-index.md → "CLLocationCoordinate2D" (iOS 2.0+)
    @Published var userLocation: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()
    
    // AI Proposals (Task 28 - External LLM Integration)
    /// Loading state for AI proposal generation
    @Published var isLoadingAI: Bool = false
    /// Show paywall when free user attempts AI feature
    @Published var showPaywall: Bool = false
    /// AI service manager (OpenAI primary, fallback providers in Phase 2)
    private let aiService = AIServiceManager()
    
    // Agent-to-Agent Negotiation (Task 28 - Week 1 Days 5-7)
    /// User's encrypted agent preferences (learned patterns, autonomy settings, veto rules)
    /// Decrypted on-device, server cannot read plaintext
    @Published var agentPreferences: AgentPreferences?
    /// Loading state for agent preferences
    @Published var isLoadingAgentPreferences = false
    
    /// Preference learning service
    private lazy var learningService = PreferenceLearningService(
        userId: UUID(), // TODO: Use actual user ID from auth
        directusClient: directusClient
    )
    /// User agent manager for autonomous negotiation
    private var agentManager: UserAgentManager?

    enum PrimaryTab: Equatable { case dashboard, proposals, events, places, amiqo }
    @Published var primaryTab: PrimaryTab = .dashboard

    func markLaunchReady() {
        launchPhase = .ready
    }

    func showDashboard() {
        launchPhase = .dashboard
    }

    func selectTab(_ tab: PrimaryTab) {
        primaryTab = tab
        launchPhase = .ready
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
        markLaunchReady()
        
        // Task 29: Load subscription status after auth
        Task {
            await storeManager.checkSubscriptionStatus()
        }
    }

    // MARK: - Dashboard Helpers

    func dismissTutorialHint() {
        hasSeenTutorialHint = true
        UserDefaults.standard.set(true, forKey: "hasSeenTutorialHint")
    }

    func toggleCardExpansion(_ cardId: String) {
        if expandedCards.contains(cardId) {
            expandedCards.remove(cardId)
        } else {
            expandedCards.insert(cardId)
        }
    }

    func isCardExpanded(_ cardId: String) -> Bool {
        expandedCards.contains(cardId)
    }

    func beginEditing(plan: Negotiation) {
        planDraftForEditing = plan
        showingCreateProposal = true
    }

    // Centralized UI error mapping
    func mapError(_ error: Error) -> String {
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .notConnectedToInternet: return "No internet connection."
            case .timedOut: return "Request timed out."
            default: break
            }
        }
        return (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String
            ?? "Something went wrong. Please try again."
    }

    /// Present a short-lived toast message using the existing calendar toast UI.
    /// Keeps auto-dismiss behaviour consistent across features.
    /// Present a toast notification with smooth fade-out animation
    /// - Parameters:
    ///   - message: Text to display
    ///   - duration: How long to show toast before fading out (default: 5 seconds)
    func presentToast(_ message: String, duration: UInt64 = 5_000_000_000) {
        calendarToastMessage = message
        showCalendarToast = true

        Task { [weak self, message] in
            try? await Task.sleep(nanoseconds: duration)
            await MainActor.run {
                guard let self else { return }
                if self.calendarToastMessage == message {
                    // Trigger smooth fade-out (animation handled in KairosAmiqoApp)
                    self.showCalendarToast = false
                }
            }
        }
    }

    /// Extract a user-friendly error message from server payloads.
    /// Handles JSON envelopes from Directus and plain-text/HTML fallback from Express.
    private func serverMessage(from data: Data?, fallback: String) -> String {
        guard let data, !data.isEmpty else { return fallback }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return error
            }
            if let errors = object["errors"] as? [[String: Any]] {
                for entry in errors {
                    if let message = entry["message"] as? String, !message.isEmpty {
                        return message
                    }
                }
            }
            if let dataDict = object["data"] as? [String: Any],
               let message = dataDict["message"] as? String,
               !message.isEmpty {
                return message
            }
        }

        if let string = String(data: data, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()
            if lowercased.contains("<!doctype") || lowercased.contains("<html") {
                return fallback
            }
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return fallback
    }

    /// Called when authentication is no longer valid
    func handleAuthFailure() {
        // For now, reuse the existing sign-out path to clear state safely
        signOut()
    }
    
    // MARK: - Profile Management (App-level)
    
    /// Open profile modal from any screen
    func openProfile() {
        showingProfile = true
    }
    
    /// Close profile modal (called programmatically if needed)
    func closeProfile() {
        showingProfile = false
    }
    
    // MARK: - Current User Management (Phase 3)
    
    /// Load current user data - for now uses mock test user
    /// Phase 4+: Parse from JWT or fetch from /users/me
    func loadCurrentUser() async {
        // TODO(Kairos): Phase 4 - Parse user ID from JWT or fetch from /users/me
        // For Phase 3, use fixed test user ID that matches mock data
        let testUserId = UUID(uuidString: "660e8400-e29b-41d4-a716-446655440001")!
        
        currentUser = KairosFriend(
            user_id: testUserId,
            name: "You",
            username: "testuser",
            last_plan_together: nil,
            plans_count: 0
        )
        
        print("✅ [DEBUG] currentUser loaded: \(testUserId)")
        
        // Task 29: Load user signup date from Directus (or mock for now)
        // TODO(Kairos): Phase 4 - Fetch from /users/me endpoint
        // For now, use a test signup date for trial calculation
        // In production, this would come from user.date_created field
        if let savedSignupDate = UserDefaults.standard.object(forKey: "userSignupDate") as? Date {
            userSignupDate = savedSignupDate
        } else {
            // First time - set signup date to now
            userSignupDate = Date()
            UserDefaults.standard.set(userSignupDate, forKey: "userSignupDate")
        }
        print("✅ [DEBUG] userSignupDate loaded: \(userSignupDate)")
    }

    let defaultEmail = "mobile.tester@example.com"
    let defaultPassword = "Test123!"

    // Clients must NOT be private because the Events API lives in an extension
    lazy var directusClient = HTTPClient(base: Config.directusBase)
    lazy var flowsClient = HTTPClient(base: Config.nodeRedBase)

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Initializers

    // Designated initializer with a preview-safe mode to avoid Keychain/network in SwiftUI previews
    init(forPreviews: Bool = false) {
        // Initialize location manager for "Near Me" feature (Phase 5 - Task 25)
        /// See: /docs/apple-index.md → "CLLocationManager" (iOS 2.0+)
        // Note: Must be initialized before super.init() as it's a stored property
        
        // Call super.init() BEFORE accessing any properties (required for NSObject subclass)
        super.init()
        
        // Now we can safely set up the location manager delegate
        locationManager.delegate = self
        
        if forPreviews {
            // Do not touch Keychain/URLSession in previews; provide stubbed state
            jwt = "PREVIEW_TOKEN"
            items = []

            // Test events with different statuses and times
            let now = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            events = [
                EventDTO(
                    id: UUID(),
                    title: "Client Meeting",
                    starts_at: iso.string(from: tomorrow),
                    status: "pending",
                    date_created: iso.string(from: now),
                    date_updated: nil,
                    owner: UUID()
                ),
                EventDTO(
                    id: UUID(),
                    title: "Team Lunch",
                    starts_at: iso.string(from: nextWeek),
                    status: "confirmed",
                    date_created: iso.string(from: now),
                    date_updated: nil,
                    owner: UUID()
                )
            ]
            errorMessage = nil
            hasCompletedOnboarding = false // Force onboarding screen in simulator
            launchPhase = .onboarding
            return
        }

    #if DEBUG
    // DEBUG ONLY: Reset onboarding flag on each build for testing
    // Set to false to test "returning user" flow
    let resetOnboardingForTesting = true
    if resetOnboardingForTesting {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    #endif

    // Cache initialization and cleanup
    cache.cleanupStale() // Remove items >7 days old
    cache.clearAllSynced() // Remove items marked as synced
    
    // Load pending items into UI (will be synced in bootstrapSession)
    items = cache.getPendingPlans()
    if !items.isEmpty {
        print("📦 Loaded \(items.count) pending plans from cache")
    }

    // Log app open event (Task 30)
    analytics.logEvent(type: "app_open", data: [:])

    Task { await bootstrapSession() }
    }

    // Helper to auto-detect when running in Xcode Previews
    static var forPreviews: AppVM {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        return AppVM(forPreviews: isPreview)
    }

    // MARK: - Helpers

    func url(_ path: String, jsonMode: Bool = false) -> URL {
        var base = Config.directusBase.appending(path: path)
        if jsonMode {
            var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
            comps.queryItems = [URLQueryItem(name: "mode", value: "json")]
            base = comps.url!
        }
        return base
    }

    private func bearerRequest(_ url: URL, method: String = "GET", jsonBody: Data? = nil) throws -> URLRequest {
        // Phase 0-3: Development mode - skip authentication
        // Phase 4+: Production Directus requires JWT
        #if DEBUG
        // Development: Allow unauthenticated requests for testing
        // This matches the mock server behavior but works with Directus
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = jsonBody
        
        // If we have a token, include it (for testing auth flows)
        if let token = jwt {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("� [DEBUG] Authenticated request: \(url.absoluteString)")
        } else {
            print("🔓 [DEBUG] Unauthenticated request (DEV mode): \(url.absoluteString)")
        }
        return req
        #else
        // Production: require JWT
        guard let token = jwt else { throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"]) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = jsonBody
        return req
        #endif
    }

    private func containsTokenExpired(in data: Data) -> Bool {
        if let decoded = try? JSONDecoder().decode(APIErrorBody.self, from: data) {
            return decoded.errors.contains { $0.extensions?.code == "TOKEN_EXPIRED" }
        }
        return false
    }

    private func dataAutorefresh(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, resp) = try await URLSession.shared.data(for: request)

        // Try refresh on 401 or TOKEN_EXPIRED payloads
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 || containsTokenExpired(in: data) {
            do {
                try await refreshToken()
            } catch {
                // Hard fail: clear session and surface a gentle error
                signOut()
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Please sign in again"])
            }
            var retried = request
            retried.setValue("Bearer \(jwt ?? "")", forHTTPHeaderField: "Authorization")
            return try await URLSession.shared.data(for: retried)
        }
        return (data, resp)
    }

    /// Helper usable from extensions to perform an authenticated request with automatic refresh
    func authedRequest(
        _ path: String,
        method: String = "GET",
        query: [URLQueryItem]? = nil,
        jsonBody: Data? = nil,
        baseOverride: URL? = nil
    ) async throws -> (Data, URLResponse) {
        var u = (baseOverride ?? Config.directusBase).appending(path: path)
        if let query {
            var comps = URLComponents(url: u, resolvingAgainstBaseURL: false)!
            comps.queryItems = query
            u = comps.url!
        }
        let req = try bearerRequest(u, method: method, jsonBody: jsonBody)
        return try await dataAutorefresh(for: req)
    }

    // MARK: - Auth
    // ⚠️ Auth methods moved to AppVM+Auth.swift
    // - login(email:password:)
    // - signInWithApple()
    // - checkAppleSignInStatus()
    // - refreshToken()
    // - signOut()
    // - clearAllState()
    // - bootstrapSession()

    // MARK: - Cache Sync
    
    /// Clear all cached plans (for debugging/development)
    @MainActor
    func clearCachedPlans() {
        cache.clearAll()
        print("🧹 Cleared all cached plans from Settings")
    }
    
    /// DEBUG: Generate test plans to test free tier limits
    @MainActor
    func generateTestPlans(count: Int) {
        let titles = ["Coffee", "Lunch", "Dinner", "Movie", "Drinks", "Walk", "Gym", "Study", "Gaming", "Shopping"]
        
        for i in 0..<count {
            let plan = Negotiation(
                id: UUID(),
                title: "\(titles[i % titles.count]) #\(i + 1)",
                status: "draft",
                started_at: nil,
                date_created: ISO8601DateFormatter().string(from: Date()),
                created_at: nil,
                updated_at: nil,
                date_updated: ISO8601DateFormatter().string(from: Date()),
                round: 1,
                owner: currentUser?.id,
                intent_category: nil,
                participants: [],
                state: nil,
                proposed_slots: [],
                proposed_venues: [],
                expires_at: nil
            )
            items.append(plan)
        }
        
        itemsState = items.isEmpty ? .empty : .loaded
        print("🧪 Generated \(count) test plans (total: \(items.count))")
    }
    
    /// Sync pending plans to server (offline → online)
    /// Runs with timeout to prevent blocking app launch
    func syncPendingPlans() async {
        let pending = cache.loadPending()
        guard !pending.isEmpty else { return }
        
        print("🔄 Syncing \(pending.count) pending plans to server...")
        
        for (id, cachedItem) in pending {
            // Add 5-second timeout per plan to prevent hanging
            do {
                try await withTimeout(seconds: 5) {
                    // Re-POST the cached raw JSON to server
                    let client = HTTPClient(base: Config.plansBase)
                    let (data, response) = try await client.post(path: "/negotiate/start", body: cachedItem.rawJSON)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw NSError(domain: "Kairos", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server error during sync"])
                    }
                    
                    // Parse server response
                    let serverPlan = try JSONDecoder().decode(Negotiation.self, from: data)
                    
                    // ✅ SUCCESS: Remove from cache
                    self.cache.removeSynced(id)
                    
                    // Update UI with server version
                    await MainActor.run {
                        if let index = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[index] = serverPlan
                        }
                    }
                    
                    print("✅ Synced plan: \(id)")
                }
            } catch {
                print("⚠️ Failed to sync plan \(id): \(error). Will retry later.")
                // Keep in cache for next sync attempt
            }
        }
    }
    
    /// Run async operation with timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "Kairos", code: -1001, userInfo: [NSLocalizedDescriptionKey: "Request timed out after \(seconds)s"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Plans API (renamed from Negotiations)

    /// Fetch plans (user-facing terminology for negotiations)
    func fetchPlans() async throws {
        print("🔄 [DEBUG] fetchPlans() called - current state: \(itemsState)")
        
        // Save current state in case request is cancelled
        let previousState = itemsState
        
        error = nil; busy = true
        defer { 
            busy = false
            print("🏁 [DEBUG] fetchPlans() completed - final state: \(itemsState)")
        }
        itemsState = .loading

        // Build query parameters - fetch ALL negotiations where user is a participant
        let queryItems = [
            URLQueryItem(name: "sort", value: "-date_created"),  // Directus standard field
            URLQueryItem(name: "limit", value: "100")  // Increased for testing with 30 invitations
        ]
        
        // NOTE: We fetch ALL negotiations and filter client-side by participants array
        // Directus JSON filtering for nested arrays is complex, so we do it in-app
        // This is acceptable for MVP with <100 active negotiations per user
        if jwt != nil, let userId = currentUser?.user_id {
            print("📊 [DEBUG] Fetching all negotiations - will filter client-side for user: \(userId.uuidString)")
        } else {
            print("⚠️ [DEBUG] No JWT - fetching all plans (development mode)")
        }

        // DEBUG: Log the full URL being requested
        var urlComponents = URLComponents(url: Config.negotiationsBase.appending(path: "/items/negotiations"), resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = queryItems
        if let finalURL = urlComponents.url {
            print("🌐 [DEBUG] Request URL: \(finalURL.absoluteString)")
        }

        do {
            let (data, resp) = try await authedRequest(
                "/items/negotiations",
                query: queryItems,
                baseOverride: Config.negotiationsBase
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("❌ [DEBUG] Plans fetch failed: \(body)")
                itemsState = .error(body.isEmpty ? "Failed to load plans." : body)
                throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: body])
            }

            // DEBUG: Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 [DEBUG] Raw response (\(data.count) bytes): \(responseString.prefix(500))...")
            }

            let allNegotiations = try JSONDecoder().decode(DirectusListEnvelope<Negotiation>.self, from: data).data
            print("✅ [DEBUG] Fetched \(allNegotiations.count) total negotiations from API")
            
            // CLIENT-SIDE FILTER: Only keep negotiations where current user is a participant
            if let userId = currentUser?.user_id {
                items = allNegotiations.filter { negotiation in
                    // Check if user is in participants array
                    if let participants = negotiation.participants {
                        let isParticipant = participants.contains { participant in
                            participant.user_id == userId  // UUID to UUID comparison
                        }
                        if isParticipant {
                            print("   ✓ Including: \(negotiation.title ?? "Untitled") (user is participant)")
                        }
                        return isParticipant
                    }
                    print("   ⚠️ Skipping: \(negotiation.title ?? "Untitled") (no participants array)")
                    return false
                }
                print("📊 [DEBUG] Filtered to \(items.count) negotiations where user is participant")
            } else {
                // No user logged in - keep all (development mode)
                items = allNegotiations
                print("⚠️ [DEBUG] No user filter applied (development mode)")
            }
            
            itemsState = items.isEmpty ? .empty : .loaded
            error = nil
        } catch {
            // Network error (timeout, cancelled, no connection, etc.)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("⚠️ [DEBUG] Request cancelled - reverting to previous state: \(previousState)")
                itemsState = previousState  // Restore state from before the request
                return // Don't throw for cancellations
            }
            
            // Other errors (decoding, network failures, etc.)
            print("❌ [DEBUG] Fetch error: \(error)")
            
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   Value not found for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .dataCorrupted(let context):
                    print("   Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    print("   Debug: \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error: \(decodingError)")
                }
            }
            throw error
        }
    }

    /// Fetch intent templates from Directus
    /// Contract: GET /items/intent_templates → { "data": [IntentTemplate] }
    func fetchIntentTemplates() async throws {
        error = nil
        
        let client = HTTPClient(base: Config.directusBase)
        
        do {
            let (data, resp) = try await client.get(path: "/items/intent_templates")
            
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: body.isEmpty ? "Failed to load intent templates." : body])
            }
            
            intentTemplates = try JSONDecoder().decode(DirectusListEnvelope<IntentTemplate>.self, from: data).data
            print("✅ Loaded \(intentTemplates.count) intent templates")
        } catch {
            // Gracefully handle missing endpoint (not implemented in Directus yet)
            // Intent templates are optional - UI will work without them
            print("⚠️ Failed to load intent templates (endpoint may not exist): \(error.localizedDescription)")
            intentTemplates = [] // Empty array, UI will still work
        }
    }

    /// Fetch Kairos friends from Directus app_users collection
    /// Contract: GET /items/app_users → { "data": [KairosFriend] }
    /// Migration: Changed from /api/friends to /items/app_users (2025-11-05)
    func fetchFriends() async throws {
        error = nil
        
        // TODO: Replace with actual user ID from auth state when implemented
        // Using UUID of "You (Test User)" from mock data to ensure proper filtering
        let _ = "660e8400-e29b-41d4-a716-446655440001"  // Reserved for future filtering
        
        // Use Directus endpoint - no query parameter needed, all users returned
        let client = HTTPClient(base: Config.plansBase)
        let (data, resp) = try await client.get(path: "/items/app_users")
        
        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: body.isEmpty ? "Failed to load friends." : body])
        }
        
        friends = try JSONDecoder().decode(DirectusListEnvelope<KairosFriend>.self, from: data).data
        print("✅ Loaded \(friends.count) friends")
    }

    /// Start a new plan (user-facing terminology)
    func startPlan(title: String) async {
        error = nil; busy = true
        defer { busy = false }
        do {
            struct Body: Codable { let title: String; let status: String }
            let (data, resp) = try await flowsClient.postJSON(path: "/negotiate/start", body: Body(title: title, status: "started"))
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "Server error"
                throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: body])
            }
            let decoded = try JSONDecoder().decode(DirectusEnvelope<Negotiation>.self, from: data)
            lastCreated = decoded.data
            items.insert(decoded.data, at: 0)
            try await fetchPlans()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    /// Create a full plan with participants, times, and venues
    /// Phase 0-1: Creates local mock data; Phase 4+: Will POST to backend
    func createProposal(
        intent: IntentTemplate,
        participants: [PlanParticipant],
        times: [ProposedSlot],
        venues: [VenueInfo]
    ) async throws -> Negotiation {
        error = nil
        busy = true
        defer { busy = false }

        // Build Codable payload (not dictionary)
        struct CreateProposalPayload: Codable {
            let owner: String
            let participants: [ParticipantPayload]
            let intent_category: String
            let proposed_slots: [SlotPayload]
            let proposed_venues: [VenuePayload]
            let duration_minutes: Int
            
            struct ParticipantPayload: Codable {
                let user_id: String
                let name: String
                let status: String
            }
            
            struct SlotPayload: Codable {
                let time: String
                let venue: VenuePayload?
            }
            
            struct VenuePayload: Codable {
                let id: String?
                let name: String
                let address: String?
                let lat: Double?
                let lon: Double?
            }
        }
        
        let payload = CreateProposalPayload(
            owner: currentUser?.user_id.uuidString ?? "",
            participants: participants.map { p in
                CreateProposalPayload.ParticipantPayload(
                    user_id: p.user_id.uuidString,
                    name: p.name,
                    status: p.status
                )
            },
            intent_category: intent.backendCategory,
            proposed_slots: times.map { t in
                CreateProposalPayload.SlotPayload(
                    time: t.time,
                    venue: t.venue.map { v in
                        CreateProposalPayload.VenuePayload(
                            id: v.id?.uuidString,
                            name: v.name,
                            address: v.address,
                            lat: v.lat,
                            lon: v.lon
                        )
                    }
                )
            },
            proposed_venues: venues.map { v in
                CreateProposalPayload.VenuePayload(
                    id: v.id?.uuidString,
                    name: v.name,
                    address: v.address,
                    lat: v.lat,
                    lon: v.lon
                )
            },
            duration_minutes: intent.duration_minutes
        )

        let client = HTTPClient(base: Config.plansBase)

        do {
            let jsonData = try JSONEncoder().encode(payload)

            // POST to /negotiate/start
            let (data, response) = try await client.post(path: "/negotiate/start", body: jsonData)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "Kairos", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
            }

            // Parse response
            let created = try JSONDecoder().decode(Negotiation.self, from: data)

            // Add to local items array
            await MainActor.run {
                items.insert(created, at: 0)
                lastCreated = created
                error = nil
            }

            print("✅ Created plan: \(created.id) - \(created.title ?? "Untitled")")
            
            // Log analytics event (Task 30)
            analytics.logEvent(
                type: "plan_created",
                data: [
                    "intent_type": intent.backendCategory,
                    "participant_count": participants.count,
                    "time_slot_count": times.count,
                    "venue_count": venues.count
                ]
            )
            
            // ✅ NO CACHE NEEDED (went straight to server)
            return created

        } catch {
            // Fallback: create mock negotiation if server fails (offline mode)
            print("⚠️ Server unavailable, creating local plan: \(error)")

            let now = ISO8601DateFormatter().string(from: Date())
            let mockNegotiation = Negotiation(
                id: UUID(),
                title: intent.displayTitle,
                status: "started",
                started_at: now,
                date_created: now,
                intent_category: intent.backendCategory,
                participants: participants,
                state: "active",
                proposed_slots: times,
                proposed_venues: venues,
                expires_at: nil
            )

            await MainActor.run {
                items.insert(mockNegotiation, at: 0)
                lastCreated = mockNegotiation
                self.error = "Created offline - will sync when connected"
            }
            
            // 💾 Save to cache for sync when online
            cache.savePending(mockNegotiation)
            
            return mockNegotiation
        }
    }

    // MARK: - Legacy API (backward compatibility)

    /// @deprecated Use fetchPlans() instead
    func fetchNegotiations() async throws {
        try await fetchPlans()
    }

    /// @deprecated Use startPlan(title:) instead
    func startNegotiation(title: String) async {
        await startPlan(title: title)
    }

    func updateTitle(item: Negotiation, newTitle: String) async {
        error = nil; busy = true
        defer { busy = false }
        do {
            struct Patch: Codable { let title: String }
            let body = try JSONEncoder().encode(Patch(title: newTitle))
            let (data, resp) = try await authedRequest(
                "/items/negotiations/\(item.id)",
                method: "PATCH",
                jsonBody: body,
                baseOverride: Config.plansBase
            )
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let bodyS = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: bodyS])
            }
            try await fetchPlans()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func delete(item: Negotiation) async {
        deletePlanError = nil
        isDeletingPlan = true
        defer { isDeletingPlan = false }

        do {
            let client = HTTPClient(base: Config.negotiationsBase)
            let (data, resp) = try await client.delete(
                path: "/items/negotiations/\(item.id.uuidString)"
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unable to delete plan"
                deletePlanError = message
                return
            }

            try await fetchPlans()

        } catch {
            print("❌ [DELETE PLAN] Error: \(error)")
            deletePlanError = error.localizedDescription
        }
    }

    /// Refresh plans without surfacing transient errors in the UI
    func fetchPlansSilently() async {
        do {
            try await fetchPlans()
        } catch {
            // Keep UI calm; errors are already handled inside fetchPlans()
            print("fetchPlansSilently error:", error)
        }
    }

    /// @deprecated Use fetchPlansSilently() instead
    func fetchNegotiationsSilently() async {
        await fetchPlansSilently()
    }

    // MARK: - Accept Action (Task 12)

    /// Accept a specific proposal (slot + venue combination)
    /// Triggers confetti animation and haptic feedback on success
    /// Auto-finalizes if all participants have accepted
    ///
    /// Contract: POST /items/negotiations/:id/accept
    /// Body: { "slot_index": 0, "venue_index": 0, "user_id": "uuid" }
    /// Response: { "state": "awaiting_replies"|"confirmed", "message": "...", "auto_finalized": bool }
    func acceptProposal(planId: UUID, slotIndex: Int, venueIndex: Int) async {
        acceptError = nil
        isAccepting = true
        defer { isAccepting = false }
        
        guard let userId = currentUser?.user_id else {
            acceptError = "User not loaded"
            print("❌ [ACCEPT] No currentUser available")
            return
        }
        
        print("🎯 [ACCEPT] Accepting proposal - plan: \(planId), slot: \(slotIndex), venue: \(venueIndex)")
        
        do {
            // Build request body
            let body: [String: Any] = [
                "slot_index": slotIndex,
                "venue_index": venueIndex,
                "user_id": userId.uuidString
            ]
            
            let client = HTTPClient(base: Config.negotiationsBase)
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            
            let (data, resp) = try await client.post(
                path: "/items/negotiations/\(planId.uuidString)/accept",
                body: jsonData,
                headers: ["Content-Type": "application/json"]
            )
            
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let httpCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [ACCEPT] HTTP error: \(httpCode) - \(errorBody)")
                acceptError = errorBody
                return
            }
            
            // Parse response
            struct AcceptResponse: Codable {
                struct ResponseData: Codable {
                    let negotiation: Negotiation
                    let event: EventDTO?
                    let all_accepted: Bool
                }
                let data: ResponseData
            }
            
            let response = try JSONDecoder().decode(AcceptResponse.self, from: data)
            print("✅ [ACCEPT] Success - All accepted: \(response.data.all_accepted)")
            
            // Haptic feedback - success impact
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Show confirmation sheet OR waiting message based on consensus
            if let event = response.data.event {
                // Consensus reached! Event created.
                await MainActor.run {
                    confirmedEvent = event
                    showConfirmationSheet = true
                }
                print("🎉 [ACCEPT] Consensus reached! Showing confirmation sheet with event: \(event.title)")
                
                // Log analytics event (Task 30)
                analytics.logEvent(type: "plan_finalized", data: [:])
            } else {
                // No consensus yet - waiting for others
                let negotiation = response.data.negotiation
                let acceptedCount = negotiation.participants?.filter { $0.status == "accepted" }.count ?? 0
                let totalCount = negotiation.participants?.count ?? 0
                let waitingCount = totalCount - acceptedCount
                
                await MainActor.run {
                    waitingMessageText = waitingCount == 1 
                        ? "Response sent! Waiting for 1 other person..."
                        : "Response sent! Waiting for \(waitingCount) others..."
                    showWaitingMessage = true
                }
                print("⏳ [ACCEPT] Waiting for \(waitingCount) other participants - no event created yet")
                
                // Auto-dismiss waiting message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.showWaitingMessage = false
                }
            }
            
            // Refresh plans to show updated state
            try await fetchNegotiations()
            
            print("🎉 [ACCEPT] Plan updated successfully - all accepted: \(response.data.all_accepted)")
            
        } catch {
            print("❌ [ACCEPT] Error: \(error)")
            acceptError = error.localizedDescription
        }
    }
    
    /// Counter a proposal with new time slots and/or venues (Task 13)
    /// - Parameters:
    ///   - planId: Negotiation UUID
    ///   - newSlots: Array of ISO8601 time strings (optional)
    ///   - newVenues: Array of venue objects (optional)
    @MainActor
    func counterProposal(planId: UUID, newSlots: [String]? = nil, newVenues: [[String: Any]]? = nil) async {
        // Task 29: Check AI counter limits for free tier
        guard canUseAI() else {
            counterError = getAIPaywallReason()
            print("🚫 [COUNTER] AI limit hit - showing paywall")
            // Trigger paywall via error message (UI will detect this)
            return
        }
        
        counterError = nil
        isCountering = true
        defer { isCountering = false }
        
        guard let userId = currentUser?.user_id else {
            counterError = "User not loaded"
            print("❌ [COUNTER] No currentUser available")
            return
        }
        
        print("🔄 [COUNTER] Countering proposal - plan: \(planId)")
        
        // Record AI usage (after guard checks pass)
        recordAICounterUsed()
        
        // Log analytics event (Task 30)
        analytics.logEvent(type: "ai_proposal_used", data: [:])
        
        do {
            // Build request body
            var body: [String: Any] = [
                "user_id": userId.uuidString
            ]
            
            if let slots = newSlots {
                body["new_slots"] = slots
                print("   📅 New slots: \(slots.count)")
            }
            
            if let venues = newVenues {
                body["new_venues"] = venues
                print("   📍 New venues: \(venues.count)")
            }
            
            let client = HTTPClient(base: Config.negotiationsBase)
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            
            let (data, resp) = try await client.post(
                path: "/items/negotiations/\(planId.uuidString)/counter",
                body: jsonData,
                headers: ["Content-Type": "application/json"]
            )
            
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let message = serverMessage(
                    from: data,
                    fallback: "Unable to send counter proposal. Verify the mock server is running."
                )
                counterError = message
                presentToast(message)
                return
            }
            
            // Parse response - mock server returns {data: {negotiation, round, max_rounds, is_final_round}}
            struct CounterEnvelope: Codable {
                struct Payload: Codable {
                    let negotiation: Negotiation
                    let round: Int
                    let max_rounds: Int
                    let is_final_round: Bool
                }
                let data: Payload
            }
            
            let decoded = try JSONDecoder().decode(CounterEnvelope.self, from: data)
            print("✅ [COUNTER] Success - Round: \(decoded.data.round)/\(decoded.data.max_rounds)")
            
            if decoded.data.is_final_round {
                presentToast("Counter sent (final round)")
            } else {
                presentToast("Counter sent")
            }
            
            // Haptic feedback - light impact for counter
            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            
            // Refresh plans to show updated state
            try await fetchPlans()
            
        } catch {
            print("❌ [COUNTER] Error: \(error)")
            let message = mapError(error)
            counterError = message
            presentToast(message)
        }
    }
    
    /// Decline or withdraw from a plan during negotiation (Task 13 – decline/withdraw matrix)
    /// - Parameters:
    ///   - planId: Negotiation identifier
    ///   - reason: Optional context for decline (e.g., "withdraw")
    @MainActor
    func declinePlan(planId: UUID, reason: String? = nil) async {
        declineError = nil
        isDeclining = true
        defer { isDeclining = false }

        guard let userId = currentUser?.user_id else {
            declineError = "User not loaded"
            print("❌ [DECLINE] No currentUser available")
            return
        }

        print("⛔️ [DECLINE] Declining plan: \(planId) reason: \(reason ?? "none")")

        do {
            var body: [String: Any] = [
                "user_id": userId.uuidString
            ]

            if let reason, !reason.isEmpty {
                body["reason"] = reason
            }

            let client = HTTPClient(base: Config.negotiationsBase)
            let jsonData = try JSONSerialization.data(withJSONObject: body)

            let (data, resp) = try await client.post(
                path: "/items/negotiations/\(planId.uuidString)/decline",
                body: jsonData,
                headers: ["Content-Type": "application/json"]
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let httpCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [DECLINE] HTTP error: \(httpCode) - \(errorBody)")
                declineError = errorBody
                return
            }

            print("✅ [DECLINE] Decline recorded successfully")

            try await fetchPlans()

        } catch {
            print("❌ [DECLINE] Error: \(error)")
            declineError = error.localizedDescription
        }
    }

    // MARK: - Owner Actions (Task 14) - Plan Creator Permissions

    struct NegotiationResponsesEnvelope: Codable {
        struct ResponseData: Codable {
            struct ParticipantResponse: Codable, Identifiable {
                var id: UUID { user_id }
                let user_id: UUID
                let name: String
                let status: String
                let responded_at: String?
                let selected_slot: Int?
                let selected_venue: Int?
            }

            struct Stats: Codable {
                let total: Int
                let accepted: Int
                let countered: Int
                let declined: Int
                let pending: Int
            }

            let negotiation_id: UUID
            let round: Int?
            let state: String?
            let responses: [ParticipantResponse]
            let stats: Stats
        }

        let data: ResponseData
    }

    func fetchResponses(planId: UUID) async throws -> NegotiationResponsesEnvelope.ResponseData {
        let client = HTTPClient(base: Config.negotiationsBase)
        let (data, resp) = try await client.get(
            path: "/items/negotiations/\(planId.uuidString)/responses",
            headers: ["Accept": "application/json"]
        )

        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "Negotiations", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let decoded = try JSONDecoder().decode(NegotiationResponsesEnvelope.self, from: data)
        return decoded.data
    }

    @MainActor
    func finalizePlan(planId: UUID, slotIndex: Int, venueIndex: Int) async {
        finalizeError = nil
        isFinalizing = true
        defer { isFinalizing = false }

        do {
            let body: [String: Any] = [
                "selected_slot_index": slotIndex,
                "selected_venue_index": venueIndex
            ]

            let client = HTTPClient(base: Config.negotiationsBase)
            let payload = try JSONSerialization.data(withJSONObject: body)

            let (data, resp) = try await client.post(
                path: "/items/negotiations/\(planId.uuidString)/finalize",
                body: payload,
                headers: ["Content-Type": "application/json"]
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unable to finalize"
                finalizeError = message
                return
            }

            struct FinalizeEnvelope: Codable {
                struct Payload: Codable {
                    let event: EventDTO
                    let negotiation: Negotiation
                }
                let data: Payload
            }

            let decoded = try JSONDecoder().decode(FinalizeEnvelope.self, from: data)

            confirmedEvent = decoded.data.event
            showConfirmationSheet = true

            try await fetchPlans()

        } catch {
            print("❌ [FINALIZE] Error: \(error)")
            finalizeError = error.localizedDescription
        }
    }

    @MainActor
    func cancelPlan(planId: UUID) async {
        cancelPlanError = nil
        isCancellingPlan = true
        defer { isCancellingPlan = false }

        do {
            let client = HTTPClient(base: Config.negotiationsBase)
            let (data, resp) = try await client.post(
                path: "/items/negotiations/\(planId.uuidString)/cancel",
                body: Data("{}".utf8),
                headers: ["Content-Type": "application/json"]
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let message = serverMessage(
                    from: data,
                    fallback: "Unable to cancel plan. Verify the mock server is running."
                )
                cancelPlanError = message
                presentToast(message)
                return
            }

            print("✅ [CANCEL PLAN] Plan cancelled successfully")
            try await fetchPlans()
            presentToast("Plan cancelled")

        } catch {
            print("❌ [CANCEL PLAN] Error: \(error)")
            let message = mapError(error)
            cancelPlanError = message
            presentToast(message)
        }
    }

    @MainActor
    func cancelEvent(eventId: UUID) async {
        cancelEventError = nil
        isCancellingEvent = true
        defer { isCancellingEvent = false }

        do {
            let client = HTTPClient(base: Config.eventsBase)
            let (data, resp) = try await client.post(
                path: "/items/events/\(eventId.uuidString)/cancel",
                body: Data("{}".utf8),
                headers: ["Content-Type": "application/json"]
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let message = serverMessage(
                    from: data,
                    fallback: "Unable to cancel event. Verify the mock server is running."
                )
                cancelEventError = message
                presentToast(message)
                return
            }

            struct EventEnvelope: Codable { let data: EventDTO }
            let updated = try JSONDecoder().decode(EventEnvelope.self, from: data).data

            if let index = events.firstIndex(where: { $0.id == updated.id }) {
                events[index] = updated
            } else {
                events.append(updated)
            }

            if let negotiationId = updated.negotiation_id,
               let planIndex = items.firstIndex(where: { $0.id == negotiationId }) {
                items[planIndex].state = "cancelled"
                items[planIndex].status = "cancelled"
            }

            presentToast("Event cancelled")

        } catch {
            print("❌ [CANCEL EVENT] Error: \(error)")
            let message = mapError(error)
            cancelEventError = message
            presentToast(message)
        }
    }

    @MainActor
    func leaveEvent(eventId: UUID) async {
        leaveEventError = nil
        isLeavingEvent = true
        defer { isLeavingEvent = false }

        guard let userId = currentUser?.user_id else {
            leaveEventError = "User not loaded"
            presentToast("User not loaded")
            return
        }

        do {
            let client = HTTPClient(base: Config.eventsBase)
            let (data, resp) = try await client.delete(
                path: "/items/events/\(eventId.uuidString)/participants/\(userId.uuidString)"
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                let message = serverMessage(
                    from: data,
                    fallback: "Unable to leave event. Verify the mock server is running."
                )
                leaveEventError = message
                presentToast(message)
                return
            }

            struct EventEnvelope: Codable { let data: EventDTO }
            let updated = try JSONDecoder().decode(EventEnvelope.self, from: data).data

            if let index = events.firstIndex(where: { $0.id == updated.id }) {
                let stillParticipant = updated.participants?.contains(where: { $0.user_id == userId }) ?? false
                if stillParticipant {
                    events[index] = updated
                } else {
                    events.remove(at: index)
                }
            }

            if let negotiationId = updated.negotiation_id,
               let planIndex = items.firstIndex(where: { $0.id == negotiationId }) {
                if var participants = items[planIndex].participants {
                    for idx in participants.indices {
                        if participants[idx].user_id == userId {
                            let original = participants[idx]
                            participants[idx] = PlanParticipant(
                                user_id: original.user_id,
                                name: original.name,
                                email: original.email,
                                phone: original.phone,
                                status: "withdrawn"
                            )
                        }
                    }
                    items[planIndex].participants = participants
                }
            }

            presentToast("You left the event")

        } catch {
            print("❌ [LEAVE EVENT] Error: \(error)")
            let message = mapError(error)
            leaveEventError = message
            presentToast(message)
        }
    }
    
    // MARK: - Calendar Integration (Task 14)
    
    /// Add confirmed plan to device calendar
    /// - Parameter event: EventDTO with confirmed details
    @MainActor
    func addEventToCalendar(_ event: EventDTO) async {
        calendarError = nil
        isAddingToCalendar = true
        defer { isAddingToCalendar = false }
        
        print("🔵 [CALENDAR] Starting calendar add for: \(event.title)")
        
        // Check/request permission
        let status = calendarHelper.authorizationStatus()
        print("🔵 [CALENDAR] Current status: \(status)")
        
        if status == .denied || status == .restricted {
            calendarError = "Calendar access denied. Please enable in Settings."
            print("❌ [CALENDAR] Permission denied or restricted")
            return
        }
        
        if status == .notDetermined {
            print("🔵 [CALENDAR] Requesting permission...")
            let granted = await calendarHelper.requestAccess()
            if !granted {
                calendarError = "Calendar permission required"
                print("❌ [CALENDAR] Permission not granted by user")
                return
            }
            print("✅ [CALENDAR] Permission granted")
            
            // Update status to reflect granted permission
            let helperStatus = calendarHelper.authorizationStatus()
            switch helperStatus {
            case .authorized:
                calendarPermissionStatus = .authorized
            case .denied:
                calendarPermissionStatus = .denied
            case .notDetermined:
                calendarPermissionStatus = .notDetermined
            case .restricted:
                calendarPermissionStatus = .restricted
            }
            print("✅ [CALENDAR] Updated status to: \(calendarPermissionStatus)")
        }
        
        // Build event details
        let title = event.title
        let location = event.venue?.name
        let notes = "Confirmed plan via Kairos Amiqo"
        
        guard let startsAt = event.starts_at else {
            calendarError = "Event has no start time"
            print("❌ [CALENDAR] Missing start time")
            return
        }
        
        print("🔵 [CALENDAR] Adding event: \(title)")
        print("🔵 [CALENDAR] Start: \(startsAt)")
        print("🔵 [CALENDAR] Location: \(location ?? "none")")
        
        // Add to calendar
        if let eventId = await calendarHelper.addEventToCalendar(
            title: title,
            startDate: startsAt,
            endDate: event.ends_at,
            location: location,
            notes: notes
        ) {
            print("✅ [CALENDAR] Event added successfully: \(eventId)")
            presentToast("Added to calendar ✓")
        } else {
            calendarError = "Unable to add event. Check Calendar app permissions in Settings."
            print("❌ [CALENDAR] Failed to add event - check logs above for details")
            presentToast("Failed to add to calendar")
        }
    }
    
    /// Generate .ics file for email sharing
    /// - Parameter event: EventDTO with confirmed details
    /// - Returns: .ics file content as string
    func generateICSFile(for event: EventDTO) -> String {
        let title = event.title
        let location = event.venue?.name
        let description = "Confirmed plan via Kairos Amiqo"
        
        guard let startsAt = event.starts_at else {
            return "" // Cannot create .ics without start date
        }
        
        return calendarHelper.generateICSFile(
            title: title,
            startDate: startsAt,
            endDate: event.ends_at,
            location: location,
            description: description
        )
    }

    // MARK: - Utils

    /// Buckets events using the UX grouping rules (see /docs/events-screen-redesign.md)
    func bucketEventsByStartDate(now: Date = .now, calendar: Calendar = .current) -> [EventBucket] {
        var grouped: [EventBucket.Kind: [EventDTO]] = [:]

        for event in events {
            let kind = bucketKind(for: event, now: now, calendar: calendar)
            grouped[kind, default: []].append(event)
        }

        return EventBucket.Kind.displayOrder.compactMap { kind in
            guard var bucketEvents = grouped[kind], !bucketEvents.isEmpty else { return nil }

            switch kind {
            case .today, .tomorrow, .thisWeek, .later:
                let fallback = Date.distantFuture
                bucketEvents.sort { ($0.startDate ?? fallback) < ($1.startDate ?? fallback) }
            case .past:
                let fallback = Date.distantPast
                bucketEvents.sort { ($0.startDate ?? fallback) > ($1.startDate ?? fallback) }
            case .upcoming:
                break
            }

            return EventBucket(kind: kind, events: bucketEvents)
        }
    }

    /// Convenience accessor for SwiftUI views to read grouped buckets
    var eventBuckets: [EventBucket] { bucketEventsByStartDate() }

    private func bucketKind(for event: EventDTO, now: Date, calendar: Calendar) -> EventBucket.Kind {
        guard let start = event.startDate else {
            return .upcoming
        }

        let startOfToday = calendar.startOfDay(for: now)

        if start < startOfToday {
            return .past
        }

        if calendar.isDate(start, inSameDayAs: now) {
            return .today
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
           calendar.isDate(start, inSameDayAs: tomorrow) {
            return .tomorrow
        }

        if calendar.isDate(start, equalTo: now, toGranularity: .weekOfYear) {
            return .thisWeek
        }

        return .later
    }

    func fmt(_ isoString: String?) -> String {
        guard let isoString,
              let d = iso.date(from: isoString)
        else { return "-" }
        return d.formatted(date: .numeric, time: .shortened)
    }

    // MARK: - Deep Linking (Task 16)
    
    /// Handle deep links from URL schemes (kairos://plan/{id}) or Universal Links (https://kairos.app/p/{token})
    /// 
    /// Supported URL formats:
    /// - `kairos://plan/{plan_id}` - Open authenticated user's plan
    /// - `https://kairos.app/p/{guest_token}` - Open guest response flow
    func handleDeepLink(url: URL) {
        print("[DeepLink] Received URL: \(url.absoluteString)")
        
        // Extract path components
        let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
        
        // Handle URL scheme: kairos://plan/{id}
        if url.scheme == "kairos" {
            if pathComponents.count >= 2 && pathComponents[0] == "plan" {
                let planIdString = pathComponents[1]
                print("[DeepLink] Navigating to plan: \(planIdString)")
                
                // Analytics: Log deep link open
                #if DEBUG
                print("[Analytics] Deep link opened: kairos://plan/\(planIdString)")
                #endif
                
                // Convert string ID to UUID
                if let planUUID = UUID(uuidString: planIdString) {
                    // Search for plan in items
                    if items.contains(where: { $0.id == planUUID }) {
                        // Plan found - navigate to Proposals tab and show it
                        DispatchQueue.main.async {
                            self.primaryTab = .proposals
                            self.selectedDeepLinkedPlanId = planUUID
                            self.showDeepLinkedPlan = true
                        }
                        print("[DeepLink] ✅ Plan found: \(planUUID)")
                    } else {
                        // Plan not found - show error toast
                        DispatchQueue.main.async {
                            self.calendarToastMessage = "Plan not found"
                            self.showCalendarToast = true
                        }
                        print("[DeepLink] ❌ Plan not found in items: \(planUUID)")
                    }
                } else {
                    // Invalid UUID format
                    DispatchQueue.main.async {
                        self.calendarToastMessage = "Invalid plan link"
                        self.showCalendarToast = true
                    }
                    print("[DeepLink] ❌ Invalid UUID format: \(planIdString)")
                }
            }
            return
        }
        
        // Handle Universal Links: https://kairos.app/p/{token}
        if url.host == "kairos.app" || url.host == "www.kairos.app" || url.host == "localhost" {
            if pathComponents.count >= 2 && pathComponents[0] == "p" {
                let token = pathComponents[1]
                print("[DeepLink] Guest link received with token: \(token)")
                
                // Analytics: Log guest deep link
                #if DEBUG
                print("[Analytics] Deep link opened: guest response /p/\(token)")
                #endif
                
                // Store token and show guest response flow
                DispatchQueue.main.async {
                    self.guestResponseToken = token
                    self.showGuestResponseSheet = true
                }
                print("[DeepLink] ✅ Guest response sheet triggered for token: \(token)")
            }
            return
        }
        
        print("[DeepLink] ⚠️ Unrecognized URL scheme or host: \(url)")
    }
    
    // MARK: - Places & POI (Phase 5)
    
    /// Load places data (POI + learned locations)
    /// Phase 5: Mock server (8056) for POI data when USE_MOCK=1
    func loadPlacesData() async {
        guard placesState != .loading else { return }
        
        placesState = .loading
        
        do {
            // Load POIs from configured Places API (mock or Directus)
            let client = HTTPClient(base: Config.placesBase)
            let (data, _) = try await client.get(path: "/items/poi")
            let envelope = try JSONDecoder().decode(DirectusListEnvelope<POI>.self, from: data)
            
            await MainActor.run {
                self.pois = envelope.data
                self.placesState = envelope.data.isEmpty ? .empty : .loaded
            }
            
            // Load learned places (mock data for Phase 5)
            await loadLearnedPlaces()
            
        } catch {
            await MainActor.run {
                self.placesState = .error(error.localizedDescription)
                print("[Places] ❌ Load error: \(error)")
            }
        }
    }
    
    /// Load learned places (auto-detected frequent locations)
    /// Phase 5: Fetches from mock server /api/places/learned
    /// Phase 6+: Real place learning from location history
    private func loadLearnedPlaces() async {
        do {
            let client = HTTPClient(base: Config.placesBase)
            let (data, _) = try await client.get(path: "/api/places/learned")
            let places = try JSONDecoder().decode([LearnedPlace].self, from: data)
            
            await MainActor.run {
                self.learnedPlaces = places
                print("[Places] ✅ Loaded \(places.count) learned places")
            }
        } catch {
            await MainActor.run {
                print("[Places] ❌ Failed to load learned places: \(error)")
                // Keep existing mock data on error (offline support)
            }
        }
    }
    
    /// Add new learned place
    /// Phase 5: POST to /api/places/learned
    func addLearnedPlace(label: String, address: String, lat: Double, lon: Double, icon: String, isPrivate: Bool) async {
        do {
            let client = HTTPClient(base: Config.placesBase)
            
            let payload: [String: Any] = [
                "label": label,
                "address": address,
                "lat": lat,
                "lon": lon,
                "icon": icon,
                "isPrivate": isPrivate
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await client.post(path: "/api/places/learned", body: jsonData)
            
            // Debug: Check response status
            if let httpResponse = response as? HTTPURLResponse {
                print("[Places] 📡 POST status: \(httpResponse.statusCode)")
            }
            
            let newPlace = try JSONDecoder().decode(LearnedPlace.self, from: data)
            
            await MainActor.run {
                self.learnedPlaces.append(newPlace)
                print("[Places] ✅ Added learned place: \(newPlace.label)")
            }
        } catch {
            await MainActor.run {
                print("[Places] ❌ Failed to add learned place: \(error)")
            }
        }
    }
    
    /// Update existing learned place
    /// Phase 5: PUT to /api/places/learned/:id
    func updateLearnedPlace(id: UUID, label: String?, address: String?, lat: Double?, lon: Double?, icon: String?, isPrivate: Bool?) async {
        do {
            var payload: [String: Any] = [:]
            if let label = label { payload["label"] = label }
            if let address = address { payload["address"] = address }
            if let lat = lat { payload["lat"] = lat }
            if let lon = lon { payload["lon"] = lon }
            if let icon = icon { payload["icon"] = icon }
            if let isPrivate = isPrivate { payload["isPrivate"] = isPrivate }
            
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            
            // Manual HTTP request for PUT (HTTPClient doesn't have .put method)
            guard let url = URL(string: "\(Config.placesBase)/api/places/learned/\(id.uuidString)") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let updatedPlace = try JSONDecoder().decode(LearnedPlace.self, from: data)
            
            await MainActor.run {
                if let index = self.learnedPlaces.firstIndex(where: { $0.id == id }) {
                    self.learnedPlaces[index] = updatedPlace
                    print("[Places] ✅ Updated learned place: \(updatedPlace.label)")
                }
            }
        } catch {
            await MainActor.run {
                print("[Places] ❌ Failed to update learned place: \(error)")
            }
        }
    }
    
    /// Delete learned place
    /// Phase 5: DELETE to /api/places/learned/:id
    func deleteLearnedPlace(_ place: LearnedPlace) async {
        do {
            // Manual HTTP request for DELETE
            guard let url = URL(string: "\(Config.placesBase)/api/places/learned/\(place.id)") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 {
                await MainActor.run {
                    self.learnedPlaces.removeAll { $0.id == place.id }
                    print("[Places] ✅ Deleted learned place: \(place.label)")
                }
            }
        } catch {
            await MainActor.run {
                print("[Places] ❌ Failed to delete learned place: \(error)")
            }
        }
    }
    
    /// Toggle favorite status for a POI
    func toggleFavorite(poi: POI) async {
        await MainActor.run {
            if favoritePOIs.contains(poi.id) {
                favoritePOIs.remove(poi.id)
                print("[Places] ❌ Removed favorite: \(poi.name)")
            } else {
                favoritePOIs.insert(poi.id)
                print("[Places] ❤️ Added favorite: \(poi.name)")
            }
        }
        
        // TODO(Phase 6): Sync favorites to backend
        // POST /items/poi_ratings with isFavorite flag
    }
    
    /// Check if POI is favorited
    func isFavorite(poi: POI) -> Bool {
        favoritePOIs.contains(poi.id)
    }
    
    // MARK: - AI Proposals (Task 28)
    
    /// Generate AI proposal for a plan (Plus tier only)
    /// See: Architecture documentation for LLM provider details
    /// Cost: ~$0.002 per request with GPT-3.5-turbo
    /// - Parameter plan: Draft plan to generate suggestions for
    @MainActor
    func generateAIProposal(for plan: DraftPlan) async {
        // 1. Check Plus tier (Task 29 dependency)
        guard isPlusUser else {
            showPaywall = true
            return
        }
        
        // 2. Build constraints from plan
        // Extract time preference from proposed slots if available
        let timePreference: String
        if let firstTime = plan.times.first?.time {
            timePreference = firstTime
        } else {
            timePreference = "flexible"
        }
        
        let constraints: [String: Any] = [
            "time": timePreference,
            "budget": "mid",  // TODO(Task 29): Get from user preferences
            "radius": 5.0     // TODO(Task 29): Get from user preferences
        ]
        
        // 3. Call AI service
        isLoadingAI = true
        defer { isLoadingAI = false }
        
        do {
            let proposal = try await aiService.generateProposal(
                intent: plan.intent?.name ?? "Social",
                participants: plan.participants.map { $0.name },
                constraints: constraints
            )
            
            // 4. Update plan with AI suggestions
            // TODO(Phase 2): Wire into DraftPlan model
            // plan.aiSuggestedTimes = proposal.timeSlots
            // plan.aiSuggestedVenues = proposal.venues
            // plan.aiExplanation = proposal.explanation
            
            print("[AI] ✅ Generated proposal with confidence: \(proposal.confidence)")
            print("[AI] Times: \(proposal.timeSlots.count), Venues: \(proposal.venues.count)")
            print("[AI] Explanation: \(proposal.explanation)")
            
            // Show success feedback
            presentToast("✨ AI suggestions generated!")
            
        } catch AIServiceError.rateLimitExceeded {
            errorMessage = "AI request limit reached. Please try again later."
        } catch {
            errorMessage = "AI suggestions unavailable: \(error.localizedDescription)"
            print("[AI] ❌ Error: \(error)")
        }
    }
}

// MARK: - Agent Preferences & Veto Rules (Task 28 - Week 1 Day 5)

extension AppVM {
    /// Load encrypted agent preferences from Directus
    /// Called at app launch after successful auth
    func loadAgentPreferences() async {
        guard jwt != nil else {
            print("⚠️ Cannot load agent preferences: Not authenticated")
            return
        }
        
        isLoadingAgentPreferences = true
        defer { isLoadingAgentPreferences = false }
        
        do {
            // TODO: Get actual user ID from auth
            let userId = UUID() // Placeholder
            
            // Fetch encrypted preferences from Directus
            let path = "/items/user_agent_preferences?filter[user_id][_eq]=\(userId.uuidString)"
            let (data, _) = try await directusClient.get(path: path)
            
            struct PreferencesResponse: Codable {
                struct PreferencesRecord: Codable {
                    let id: UUID
                    let userId: UUID
                    let encryptedData: String
                    
                    enum CodingKeys: String, CodingKey {
                        case id
                        case userId = "user_id"
                        case encryptedData = "encrypted_data"
                    }
                }
                let data: [PreferencesRecord]
            }
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(PreferencesResponse.self, from: data)
            
            guard let record = response.data.first else {
                print("ℹ️ No agent preferences found - will create on first save")
                // Initialize with defaults
                agentPreferences = AgentPreferences(userId: userId)
                return
            }
            
            // Decrypt preferences
            guard let encryptedData = Data(base64Encoded: record.encryptedData) else {
                throw AppVMError.decryptionFailed
            }
            
            let masterKey = try KeychainManager.loadOrGenerateUserMasterKey()
            let decryptedData = try E2EEManager.decrypt(encryptedData, with: masterKey)
            
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .iso8601
            agentPreferences = try jsonDecoder.decode(AgentPreferences.self, from: decryptedData)
            
            print("✅ Loaded agent preferences: \(agentPreferences?.learnedPatterns.negotiationCount ?? 0) negotiations analyzed")
            
        } catch {
            print("❌ Failed to load agent preferences: \(error)")
            errorMessage = "Could not load agent preferences"
        }
    }
    
    /// Save encrypted agent preferences to Directus (with explicit preferences parameter)
    /// - Parameter preferences: Agent preferences to save
    func saveAgentPreferences(_ preferences: AgentPreferences) async {
        agentPreferences = preferences
        
        do {
            try await saveAgentPreferences()
        } catch {
            print("❌ Failed to save agent preferences: \(error)")
            await MainActor.run {
                errorMessage = "Could not save agent preferences"
            }
        }
    }
    
    /// Save encrypted agent preferences to Directus
    func saveAgentPreferences() async throws {
        guard let preferences = agentPreferences else {
            throw AppVMError.noAgentPreferences
        }
        
        isLoadingAgentPreferences = true
        defer { isLoadingAgentPreferences = false }
        
        // Encode preferences to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(preferences)
        
        // Encrypt with user's master key
        let masterKey = try KeychainManager.loadOrGenerateUserMasterKey()
        
        let encryptedData = try E2EEManager.encrypt(jsonData, with: masterKey)
        let base64Encrypted = encryptedData.base64EncodedString()
        
        // Upload to Directus (create or update)
        let payload: [String: Any] = [
            "user_id": preferences.userId.uuidString,
            "encrypted_data": base64Encrypted,
            "date_updated": ISO8601DateFormatter().string(from: Date())
        ]
        
        // Check if record exists
        let path = "/items/user_agent_preferences?filter[user_id][_eq]=\(preferences.userId.uuidString)"
        let (existingData, _) = try await directusClient.get(path: path)
        
        struct ExistingResponse: Codable {
            struct Record: Codable {
                let id: UUID
            }
            let data: [Record]
        }
        
        let decoder = JSONDecoder()
        let existingResponse = try decoder.decode(ExistingResponse.self, from: existingData)
        
        if let existingRecord = existingResponse.data.first {
            // Update existing
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            _ = try await directusClient.patch(
                path: "/items/user_agent_preferences/\(existingRecord.id.uuidString)",
                body: payloadData
            )
            print("✅ Updated agent preferences")
        } else {
            // Create new
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            _ = try await directusClient.post(
                path: "/items/user_agent_preferences",
                body: payloadData
            )
            print("✅ Created agent preferences")
        }
    }
    
    /// Add new veto rule
    func addVetoRule(type: VetoRuleType, value: String) {
        guard var preferences = agentPreferences else {
            print("⚠️ Cannot add veto rule: No agent preferences")
            return
        }
        
        let newRule = VetoRule(type: type, value: value)
        preferences.vetoRules.append(newRule)
        preferences.dateUpdated = Date()
        
        agentPreferences = preferences
        
        Task {
            do {
                try await saveAgentPreferences()
                print("✅ Added veto rule: \(type.rawValue)")
            } catch {
                print("❌ Failed to save veto rule: \(error)")
                errorMessage = "Could not save veto rule"
            }
        }
    }
    
    /// Toggle veto rule active state
    func toggleVetoRule(id: UUID, isActive: Bool) {
        guard var preferences = agentPreferences else { return }
        
        if let index = preferences.vetoRules.firstIndex(where: { $0.id == id }) {
            preferences.vetoRules[index].isActive = isActive
            preferences.dateUpdated = Date()
            agentPreferences = preferences
            
            Task {
                do {
                    try await saveAgentPreferences()
                    print("✅ Toggled veto rule \(id): \(isActive)")
                } catch {
                    print("❌ Failed to toggle veto rule: \(error)")
                    errorMessage = "Could not update veto rule"
                }
            }
        }
    }
    
    /// Delete veto rule
    func deleteVetoRule(id: UUID) {
        guard var preferences = agentPreferences else { return }
        
        preferences.vetoRules.removeAll { $0.id == id }
        preferences.dateUpdated = Date()
        agentPreferences = preferences
        
        Task {
            do {
                try await saveAgentPreferences()
                print("✅ Deleted veto rule \(id)")
            } catch {
                print("❌ Failed to delete veto rule: \(error)")
                errorMessage = "Could not delete veto rule"
            }
        }
    }
    
    /// Get AI usage stats (if agent decision service enabled)
    @MainActor
    func getAIUsageStats() -> (used: Int, limit: Int)? {
        return agentManager?.getAIUsageStats()
    }
    
    /// Update learned patterns from negotiation history
    /// Call after plan confirmed or on app launch
    func updateLearnedPatterns() async {
        guard let preferences = agentPreferences else {
            print("ℹ️ No agent preferences to update")
            return
        }
        
        do {
            let updatedPreferences = try await learningService.updateLearnedPatterns(
                from: items,
                events: events,
                currentPreferences: preferences
            )
            
            agentPreferences = updatedPreferences
            print("✅ Updated learned patterns")
            
        } catch {
            print("❌ Failed to update learned patterns: \(error)")
        }
    }
    
    /// Reset all learned patterns (user action from settings)
    /// Clears favorite venues, preferred times, category preferences
    /// Preserves autonomy settings and veto rules
    func resetLearnedPatterns() async {
        guard var preferences = agentPreferences else {
            print("⚠️ No agent preferences to reset")
            return
        }
        
        // Reset learned patterns to empty state
        preferences.learnedPatterns = LearnedPatterns()
        preferences.dateUpdated = Date()
        agentPreferences = preferences
        
        do {
            try await saveAgentPreferences()
            print("✅ Reset all learned patterns")
        } catch {
            print("❌ Failed to reset learned patterns: \(error)")
            await MainActor.run {
                errorMessage = "Could not reset learned patterns"
            }
        }
    }
    
    // MARK: - Agent Manager Methods (Task 28 - Week 2 Days 8-9)
    
    /// Initialize agent manager with current preferences
    /// Call after loading agent preferences
    /// - Parameter openAIKey: OpenAI API key (optional - enables AI decisions)
    func initializeAgentManager(openAIKey: String? = nil) {
        guard let preferences = agentPreferences,
              let userId = currentUser?.user_id else {
            print("⚠️ Cannot initialize agent manager: Missing preferences or user ID")
            return
        }
        
        // Get OpenAI key from environment or parameter
        // TODO: Store in secure Config or fetch from backend
        let apiKey = openAIKey ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        
        agentManager = UserAgentManager(
            userId: userId,
            preferences: preferences,
            directusClient: directusClient,
            openAIKey: apiKey  // NEW: Pass OpenAI key for AI decisions
        )
        
        if apiKey != nil {
            print("✅ Agent manager initialized with AI decision service")
        } else {
            print("✅ Agent manager initialized (heuristic-only mode)")
        }
    }
    
    /// Handle incoming agent proposal (from other user's agent)
    /// - Parameters:
    ///   - proposal: Proposal data from other agent
    ///   - negotiationId: Negotiation UUID
    ///   - fromUserId: Sender user ID
    ///   - round: Current negotiation round
    func handleAgentProposal(
        _ proposal: ProposalData,
        negotiationId: UUID,
        fromUserId: UUID,
        round: Int
    ) async {
        guard let manager = agentManager else {
            print("⚠️ Agent manager not initialized")
            return
        }
        
        busy = true
        defer { busy = false }
        
        do {
            // Evaluate proposal
            let decision = try await manager.evaluateProposal(proposal)
            
            print("🤖 Agent decision: \(decision.action) (confidence: \(decision.confidence))")
            print("   Reasoning: \(decision.reasoning)")
            
            // Take action based on decision
            switch decision.action {
            case .accept:
                // Send accept message
                let acceptMessage = AgentMessagePayload(
                    type: .accept,
                    proposalData: nil,
                    counterData: nil,
                    finalData: nil,
                    reasoning: decision.reasoning,
                    confidence: decision.confidence
                )
                
                try await manager.sendMessage(
                    acceptMessage,
                    to: fromUserId,
                    negotiation: negotiationId,
                    round: round + 1
                )
                
                presentToast("✅ Your agent accepted the plan!")
                
            case .counter:
                // Send counter-proposal
                guard let counter = decision.suggestedAlternatives else {
                    print("❌ No counter-proposal generated")
                    return
                }
                
                let counterMessage = AgentMessagePayload(
                    type: .counterProposal,
                    proposalData: nil,
                    counterData: counter,
                    finalData: nil,
                    reasoning: decision.reasoning,
                    confidence: decision.confidence
                )
                
                try await manager.sendMessage(
                    counterMessage,
                    to: fromUserId,
                    negotiation: negotiationId,
                    round: round + 1
                )
                
                presentToast("🔄 Your agent sent a counter-proposal")
                
            case .escalate:
                // Escalate to user for manual review
                presentToast("⬆️ Agent needs your input on this plan")
                
                // TODO: Show notification or badge in Plans tab
                // TODO: Navigate to plan detail view
            }
            
        } catch {
            print("❌ Failed to handle agent proposal: \(error)")
            errorMessage = "Agent failed to process proposal"
        }
    }
    
    /// Send agent proposal to another user
    /// - Parameters:
    ///   - negotiationId: Negotiation UUID
    ///   - toUserId: Recipient user ID
    ///   - venues: Proposed venues
    ///   - timeSlots: Proposed time slots
    func sendAgentProposal(
        negotiationId: UUID,
        toUserId: UUID,
        venues: [VenueData],
        timeSlots: [TimeSlotData]
    ) async {
        guard let manager = agentManager else {
            print("⚠️ Agent manager not initialized")
            return
        }
        
        busy = true
        defer { busy = false }
        
        do {
            let proposal = ProposalData(
                timeSlots: timeSlots,
                venues: venues,
                reasoning: "Based on your preferences",
                confidence: 0.8
            )
            
            let message = AgentMessagePayload(
                type: .proposal,
                proposalData: proposal,
                counterData: nil,
                finalData: nil,
                reasoning: "Initial proposal from your agent",
                confidence: 0.8
            )
            
            try await manager.sendMessage(
                message,
                to: toUserId,
                negotiation: negotiationId,
                round: 1
            )
            
            presentToast("📤 Agent sent proposal")
            
        } catch {
            print("❌ Failed to send agent proposal: \(error)")
            errorMessage = "Could not send agent proposal"
        }
    }

    // MARK: - Subscription & Free Tier (moved to AppVM+Subscription.swift)
}

// MARK: - AppVM Errors

enum AppVMError: Error, LocalizedError {
    case noAgentPreferences
    case encryptionKeyNotFound
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .noAgentPreferences:
            return "Agent preferences not initialized"
        case .encryptionKeyNotFound:
            return "Encryption key not found. Please log in again."
        case .decryptionFailed:
            return "Could not decrypt agent preferences"
        }
    }
}

// MARK: - Location Services (Phase 5 - Task 25)

/// Extension for location services to support "Near Me" feature
/// See: /docs/apple-index.md → "CLLocationManagerDelegate" (iOS 2.0+)
extension AppVM: CLLocationManagerDelegate {
    /// Request user location for "Near Me" feature
    /// See: /docs/apple-index.md → "CLLocationManager.requestWhenInUseAuthorization()" (iOS 8.0+)
    /// See: /docs/apple-index.md → "CLLocationManager.requestLocation()" (iOS 9.0+)
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    /// Receive location updates from CLLocationManager
    /// See: /docs/apple-index.md → "CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)" (iOS 2.0+)
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.userLocation = location.coordinate
            print("[Location] ✅ Updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    /// Handle location errors
    /// See: /docs/apple-index.md → "CLLocationManagerDelegate.locationManager(_:didFailWithError:)" (iOS 2.0+)
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] ❌ Failed: \(error.localizedDescription)")
    }
}
