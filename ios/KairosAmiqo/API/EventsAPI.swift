import Foundation

// MARK: - Directus Event DTOs

struct EventDTO: Identifiable, Codable {
    let id: UUID // Client-generated UUID for offline support
    var title: String
    var starts_at: String? // Server sends "starts_at", not "start_utc", and it's nullable
    var ends_at: String? // Optional end time
    var status: String?
    var date_created: String?
    var date_updated: String?
    var owner: UUID? // UUID of the owner
    var ics_url: String? // URL to ICS file for sharing
    var negotiation_id: UUID? // Link to parent negotiation
    var venue: VenueInfo? // Venue details
    var participants: [ParticipantInfo]? // List of participants
    var calendar_synced: Bool? // Calendar sync status

    // Nested venue structure (matches mock server)
    struct VenueInfo: Codable {
        let id: UUID // Changed from String to UUID
        let name: String
        let address: String
        let lat: Double?
        let lon: Double?
    }

    // Nested participant structure (matches mock server)
    struct ParticipantInfo: Codable {
        let user_id: UUID // Changed from String to UUID
        let name: String
    }

    var startDate: Date? {
        guard let starts_at = starts_at else { return nil }

        // Try standard format first (2025-10-09T13:35:00Z)
        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        if let date = standardFormatter.date(from: starts_at) {
            return date
        }

        // Fallback to fractional seconds format (2025-10-09T13:35:00.000Z)
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: starts_at)
    }

    var endDate: Date? {
        // Try parsing ends_at if available
        if let ends_at = ends_at {
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardFormatter.date(from: ends_at) {
                return date
            }

            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: ends_at) {
                return date
            }
        }

        // Fallback: default to 1 hour after start
        guard let startDate = startDate else { return nil }
        return startDate.addingTimeInterval(3600)
    }
}

// MARK: - Events API Response Models

struct EventsListResp: Codable {
    let data: [EventDTO]
}

struct EventsCreateReq: Codable {
    var title: String
    var starts_at: String? // Match server field name
    var status: String?
    // Remove end_utc and venue since server doesn't expect them
}

struct EventsCreateResp: Codable {
    let data: EventDTO
}

// MARK: - Event Status Management

extension AppVM {
    /// Valid event status transitions
    private func isValidStatusTransition(from currentStatus: String, to newStatus: String) -> Bool {
        switch (currentStatus, newStatus) {
        case ("draft", "confirmed"), // Draft can be confirmed
             ("draft", "cancelled"), // Draft can be cancelled
             ("confirmed", "cancelled"): // Confirmed can be cancelled
            return true
        case let (same, new) where same == new:
            return true // Always allow setting same status
        default:
            return false
        }
    }
}

// MARK: - Events API on AppVM

@MainActor
extension AppVM {
    /// Fetches the current list of events from the server
    func fetchEvents() async {
        eventsState = .loading
        errorMessage = nil

        do {
            guard jwt != nil else {
                throw EventsError.authenticationRequired
            }

            let (data, resp) = try await authedRequest(
                "/items/events",
                method: "GET",
                query: [
                    URLQueryItem(name: "sort[]", value: "-date_created"),  // Directus standard field
                    URLQueryItem(name: "limit", value: "50")
                ],
                baseOverride: Config.eventsBase
            )

            // Debug: Print server response to understand data structure
            if let httpResponse = resp as? HTTPURLResponse {
                print("DEBUG: Response status:", httpResponse.statusCode)
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG: Server response:")
                print(jsonString)
            }

            // Check auth first
            if jwt == nil {
                throw EventsError.authenticationRequired
            }

            // Always try to decode Directus error first
            if let errorResponse = try? JSONDecoder().decode(DirectusAPIError.self, from: data),
               let firstError = errorResponse.errors?.first,
               let message = firstError.message {
                // Handle specific error codes
                if let code = firstError.extensions?.code {
                    switch code {
                    case "INVALID_CREDENTIALS", "TOKEN_EXPIRED":
                        handleAuthFailure()
                        throw EventsError.authenticationRequired
                    default:
                        break
                    }
                }

                throw EventsError.serverError(message)
            }

            // Check HTTP status
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw EventsError.serverError("Failed to load events")
            }

            // Parse successful response
            let decoded = try JSONDecoder().decode(EventsListResp.self, from: data)
            events = decoded.data
            eventsState = events.isEmpty ? .empty : .loaded
            errorMessage = nil

        } catch let decodingError as DecodingError {
            eventsState = .error("Invalid data format received from server")
            errorMessage = decodingError.localizedDescription
        } catch {
            let eventsError = EventsError.from(error)
            eventsState = .error(eventsError.localizedDescription)
            errorMessage = nil
        }
    }

    /// Creates a new event on the server
    func createEvent(title: String, start: Date = .now, end _: Date? = nil) async -> Bool {
        do {
            guard !title.isEmpty else {
                throw EventsError.invalidEvent
            }

            guard jwt != nil else {
                throw EventsError.authenticationRequired
            }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]

            let body = EventsCreateReq(
                title: title,
                starts_at: iso.string(from: start),
                status: "draft"
            )

            let payload = try JSONEncoder().encode(body)
            let (data, resp) = try await authedRequest(
                "/items/events",
                method: "POST",
                jsonBody: payload,
                baseOverride: Config.eventsBase
            )

            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                // Try to extract error message from response data
                if let errorString = String(data: data, encoding: .utf8) {
                    eventsState = .error("Failed to create event: \(errorString)")
                } else {
                    eventsState = .error("Failed to create event")
                }
                return false
            }

            _ = try JSONDecoder().decode(EventsCreateResp.self, from: data)
            print("DEBUG: Event created successfully, fetching events...")
            await fetchEvents() // This will update eventsState to .loading then .loaded
            print("DEBUG: Events fetched, returning true")
            return true

        } catch {
            let eventsError = EventsError.from(error)
            eventsState = .error(eventsError.localizedDescription)
            return false
        }
    }

    /// Updates the status of an existing event
    func updateEventStatus(_ eventId: UUID, status: String) async throws {
        guard jwt != nil else {
            throw EventsError.authenticationRequired
        }

        guard events.contains(where: { $0.id == eventId }) else {
            throw EventsError.invalidEvent
        }

        let payload = try JSONEncoder().encode(["status": status])
        let (data, resp) = try await authedRequest(
            "/items/events/\(eventId)",
            method: "PATCH",
            jsonBody: payload,
            baseOverride: Config.eventsBase
        )

        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            // Try to extract error message from response data
            if let errorString = String(data: data, encoding: .utf8) {
                throw EventsError.serverError("Failed to update event: \(errorString)")
            }
            throw EventsError.serverError("Failed to update event")
        }

        let updated = try JSONDecoder().decode(EventsCreateResp.self, from: data).data
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index] = updated
        }

        if status == "confirmed" {
            guard calendarPermissionStatus == .authorized else {
                throw EventsError.calendarAccessDenied
            }
            await addEventToCalendar(updated)
        }
    }
}
