import Foundation

/// Centralized date formatting utilities for Kairos Amiqo
///
/// **Apple Docs-Grounded:**
/// - Ref: https://developer.apple.com/documentation/foundation/date/formatstyle
/// - Ref: https://developer.apple.com/documentation/foundation/dateformatter
///
/// **Localization:**
/// - Automatically respects user's region (US: MM/DD/YYYY, EU: DD/MM/YYYY)
/// - Automatically respects 12/24-hour preference
/// - Automatically respects calendar system (Gregorian, Hebrew, Islamic, etc.)
///
/// **Availability:** iOS 15+ (Date.FormatStyle)
///
/// **Usage:**
/// ```swift
/// // Parse ISO8601 from backend
/// guard let date = DateFormatting.parseISO8601("2025-10-17T07:30:00Z") else { return }
///
/// // Display to user (auto-localized)
/// Text(DateFormatting.formatEventDateTime(date))
/// // US: "Fri, Oct 17 at 10:30 AM"
/// // EU: "ven. 17 oct. à 10:30"
/// ```
@available(iOS 15, *)
enum DateFormatting {
    
    // MARK: - Parsing (Backend → App)
    
    /// Parse ISO8601 date string from backend (with or without fractional seconds)
    ///
    /// **Supported formats:**
    /// - `2025-10-17T07:30:00Z` (mock server)
    /// - `2025-10-17T07:30:00.000Z` (Directus)
    /// - `2025-10-17T07:30:00+02:00` (with timezone offset)
    ///
    /// - Parameter isoString: ISO8601 date string
    /// - Returns: Date object if valid, nil otherwise
    static func parseISO8601(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        
        // Try with fractional seconds first
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date
        }
        
        // Fallback: without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }
    
    // MARK: - Display Formatting (App → User)
    
    /// Format date for event cards and lists
    ///
    /// **Output examples:**
    /// - US 12-hour: "Fri, Oct 17 at 10:30 AM"
    /// - US 24-hour: "Fri, Oct 17 at 10:30"
    /// - EU 12-hour: "ven. 17 oct. à 10:30"
    /// - EU 24-hour: "ven. 17 oct. à 10:30"
    ///
    /// **Localization:**
    /// - Weekday abbreviation (Fri / ven.)
    /// - Month abbreviation (Oct / oct.)
    /// - Date order (Oct 17 / 17 oct.)
    /// - 12/24-hour clock based on device settings
    ///
    /// - Parameter date: Date to format
    /// - Returns: Localized date/time string
    static func formatEventDateTime(_ date: Date) -> String {
        // Use FormatStyle for automatic localization
        return date.formatted(
            .dateTime
                .weekday(.abbreviated)    // Fri, Mon, etc.
                .month(.abbreviated)      // Oct, Jan, etc.
                .day()                    // 17, 1, etc.
                .hour()                   // Respects 12/24-hour preference
                .minute()                 // :30, :00, etc.
        )
    }
    
    /// Format date for confirmation sheet (full date + time)
    ///
    /// **Output examples:**
    /// - US: "Friday, Oct 17 at 10:30 AM"
    /// - EU: "vendredi 17 oct. à 10:30"
    ///
    /// - Parameter date: Date to format
    /// - Returns: Localized long-form date/time string
    static func formatConfirmationDateTime(_ date: Date) -> String {
        return date.formatted(
            .dateTime
                .weekday(.wide)           // Friday, Monday, etc.
                .month(.abbreviated)      // Oct, Jan, etc. (changed from .wide)
                .day()                    // 17, 1, etc.
                .hour()                   // Respects 12/24-hour preference
                .minute()
        )
    }
    
    /// Format date for list headers (date only, no time)
    ///
    /// **Output examples:**
    /// - US: "Oct 17, 2025"
    /// - EU: "17 oct. 2025"
    ///
    /// - Parameter date: Date to format
    /// - Returns: Localized date string
    static func formatDateOnly(_ date: Date) -> String {
        return date.formatted(
            .dateTime
                .month(.abbreviated)
                .day()
                .year()
        )
    }
    
    /// Format time only (no date)
    ///
    /// **Output examples:**
    /// - US 12-hour: "10:30 AM"
    /// - US 24-hour: "10:30"
    /// - EU: "10:30"
    ///
    /// - Parameter date: Date to format
    /// - Returns: Localized time string
    static func formatTimeOnly(_ date: Date) -> String {
        return date.formatted(
            .dateTime
                .hour()
                .minute()
        )
    }
    
    /// Format relative date (Today, Tomorrow, Yesterday, or date)
    ///
    /// **Output examples:**
    /// - Today → "Today at 10:30 AM"
    /// - Tomorrow → "Tomorrow at 10:30 AM"
    /// - Future → "Fri, Oct 17 at 10:30 AM"
    ///
    /// - Parameter date: Date to format
    /// - Returns: Localized relative date/time string
    static func formatRelativeDateTime(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today at \(formatTimeOnly(date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatTimeOnly(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(formatTimeOnly(date))"
        } else {
            return formatEventDateTime(date)
        }
    }
    
    // MARK: - API Output (App → Backend)
    
    /// Convert Date to ISO8601 string for backend API
    ///
    /// **Output format:** `2025-10-17T07:30:00Z` (UTC timezone)
    ///
    /// - Parameter date: Date to convert
    /// - Returns: ISO8601 string
    static func toISO8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
