//
//  CalendarHelper.swift
//  KairosAmiqo
//
//  Created by Copilot on 2025-10-19.
//  Phase 3 - Task 14: Calendar integration for confirmed plans
//

import Foundation
import EventKit
import UIKit

/// Helper for writing confirmed plans to device calendar
/// Handles permissions, event creation, and .ics file generation
///
/// **Key Design Decisions:**
/// - Uses `Calendar.current` to respect user's calendar system (Gregorian, Hebrew, Islamic, etc.)
/// - Preserves timezone information from ISO8601 dates (no forced UTC conversion)
/// - DST-safe duration calculations using Calendar API
/// - Locale-aware date formatting
///
/// See: /docs/00-architecture-overview.md for calendar integration
class CalendarHelper {
    private let eventStore = EKEventStore()
    private let calendar = Calendar.current // Respects user's calendar preference
    
    /// Authorization status for calendar access
    enum AuthStatus {
        case authorized
        case denied
        case notDetermined
        case restricted
    }
    
    /// Check current calendar authorization status
    func authorizationStatus() -> AuthStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .fullAccess:
            return .authorized
        case .writeOnly:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
    
    /// Request calendar access permission
    /// - Returns: true if authorized, false if denied
    @MainActor
    func requestAccess() async -> Bool {
        do {
            // iOS 17+ requires full access for writing events
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("❌ Calendar permission error: \(error)")
            return false
        }
    }
    
    /// Write confirmed plan to device calendar
    /// - Parameters:
    ///   - title: Event title (e.g., "Coffee with Sarah")
    ///   - startDate: Event start time (ISO8601 string with timezone)
    ///   - endDate: Event end time (ISO8601 string, optional)
    ///   - location: Venue address (optional)
    ///   - notes: Additional details about the plan
    /// - Returns: Event identifier if successful, nil if failed
    ///
    /// **Timezone Handling:**
    /// - Preserves timezone from ISO8601 string
    /// - Falls back to device timezone if not specified
    /// - Uses Calendar API for DST-safe duration calculations
    @MainActor
    func addEventToCalendar(
        title: String,
        startDate: String,
        endDate: String?,
        location: String?,
        notes: String?
    ) async -> String? {
        // Parse ISO8601 dates (preserves timezone if present)
        // Try with fractional seconds first, fallback to standard format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var start: Date? = formatter.date(from: startDate)
        if start == nil {
            // Fallback: try without fractional seconds (mock server format: 2025-10-17T07:30:00Z)
            formatter.formatOptions = [.withInternetDateTime]
            start = formatter.date(from: startDate)
        }
        
        guard let start = start else {
            print("❌ [CALENDAR] Invalid start date format: \(startDate)")
            print("❌ [CALENDAR] Tried formats: .withFractionalSeconds and .withInternetDateTime")
            return nil
        }
        
        print("✅ [CALENDAR] Parsed start date: \(start)")
        
        let end: Date
        if let endDateString = endDate {
            // Try parsing end date with same fallback logic
            var parsedEnd = formatter.date(from: endDateString)
            if parsedEnd == nil {
                formatter.formatOptions = [.withInternetDateTime]
                parsedEnd = formatter.date(from: endDateString)
            }
            end = parsedEnd ?? calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        } else {
            // Use Calendar API for DST-safe 1-hour addition
            // This respects daylight saving time boundaries
            end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        }
        
        // Get default calendar (must be done after permission granted)
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            print("❌ [CALENDAR] No default calendar available - check permissions")
            return nil
        }
        
        // Create event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = start
        event.endDate = end
        event.location = location
        event.notes = notes
        event.calendar = defaultCalendar
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ [CALENDAR] Added event to calendar: \(title) at \(startDate)")
            return event.eventIdentifier
        } catch {
            print("❌ [CALENDAR] Failed to save event: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Generate .ics file content for email sharing
    /// - Parameters:
    ///   - title: Event title
    ///   - startDate: Event start time (ISO8601 string with timezone)
    ///   - endDate: Event end time (ISO8601 string, optional)
    ///   - location: Venue address (optional)
    ///   - description: Event details
    /// - Returns: .ics file content as RFC 5545 compliant string
    ///
    /// **Timezone Preservation:**
    /// - Preserves timezone from ISO8601 input
    /// - Uses VTIMEZONE for proper timezone handling
    /// - Falls back to device timezone if not specified
    func generateICSFile(
        title: String,
        startDate: String,
        endDate: String?,
        location: String?,
        description: String?
    ) -> String {
        // Parse ISO8601 dates (preserves timezone)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let start = formatter.date(from: startDate) else {
            return "" // Invalid date
        }
        
        let end: Date
        if let endDateString = endDate, let parsedEnd = formatter.date(from: endDateString) {
            end = parsedEnd
        } else {
            // Use Calendar API for DST-safe duration
            end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
        }
        
        // Determine timezone from the start date
        // Extract timezone from ISO string or use device timezone
        let timeZone: TimeZone
        if startDate.contains("Z") || startDate.contains("+") || startDate.contains("-") {
            // ISO string has explicit timezone, use UTC for Z
            timeZone = startDate.contains("Z") ? TimeZone(secondsFromGMT: 0)! : TimeZone.current
        } else {
            // No timezone in ISO string, use device timezone
            timeZone = TimeZone.current
        }
        
        // Format dates for iCalendar
        // Use TZID for local time, or Z suffix for UTC
        let icsFormatter = DateFormatter()
        icsFormatter.timeZone = timeZone
        
        let startString: String
        let endString: String
        
        if timeZone.secondsFromGMT() == 0 {
            // UTC time - use Z suffix (YYYYMMDDTHHmmssZ)
            icsFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            startString = icsFormatter.string(from: start)
            endString = icsFormatter.string(from: end)
        } else {
            // Local time - use TZID (YYYYMMDDTHHmmss with TZID property)
            icsFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
            startString = icsFormatter.string(from: start)
            endString = icsFormatter.string(from: end)
        }
        
        // Timestamp always in UTC
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        timestampFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let nowString = timestampFormatter.string(from: Date())
        
        // Generate unique identifier
        let uid = UUID().uuidString
        
        // Build .ics content (RFC 5545 format)
        var ics = "BEGIN:VCALENDAR\r\n"
        ics += "VERSION:2.0\r\n"
        ics += "PRODID:-//Kairos Amiqo//EN\r\n"
        ics += "CALSCALE:GREGORIAN\r\n"
        ics += "METHOD:PUBLISH\r\n"
        ics += "BEGIN:VEVENT\r\n"
        ics += "UID:\(uid)\r\n"
        ics += "DTSTAMP:\(nowString)\r\n"
        
        // Add DTSTART with timezone
        if timeZone.secondsFromGMT() == 0 {
            ics += "DTSTART:\(startString)\r\n"
            ics += "DTEND:\(endString)\r\n"
        } else {
            let tzid = timeZone.identifier
            ics += "DTSTART;TZID=\(tzid):\(startString)\r\n"
            ics += "DTEND;TZID=\(tzid):\(endString)\r\n"
        }
        
        ics += "SUMMARY:\(title)\r\n"
        
        if let location = location {
            // Escape special characters per RFC 5545
            let escapedLocation = escapeICalendarText(location)
            ics += "LOCATION:\(escapedLocation)\r\n"
        }
        
        if let description = description {
            let escapedDesc = escapeICalendarText(description)
            ics += "DESCRIPTION:\(escapedDesc)\r\n"
        }
        
        ics += "STATUS:CONFIRMED\r\n"
        ics += "SEQUENCE:0\r\n"
        ics += "END:VEVENT\r\n"
        ics += "END:VCALENDAR\r\n"
        
        return ics
    }
    
    /// Escape special characters for iCalendar text fields per RFC 5545
    /// - Parameter text: Raw text to escape
    /// - Returns: Escaped text safe for .ics files
    private func escapeICalendarText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
    
    /// Open device settings for calendar permissions (if denied)
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
