import Foundation

/// Represents all possible errors from the Events API
enum APIError: LocalizedError {
    case networkError(underlying: Error)
    case invalidResponse
    case serverError(code: Int, message: String)
    case authenticationRequired
    case invalidToken
    case encodingError
    case decodingError(String)
    case validationError(String)

    var errorDescription: String? {
        switch self {
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case let .serverError(code, message):
            return "Server error (\(code)): \(message)"
        case .authenticationRequired:
            return "Please sign in to continue"
        case .invalidToken:
            return "Your session has expired. Please sign in again."
        case .encodingError:
            return "Failed to encode request"
        case let .decodingError(details):
            return "Failed to decode response: \(details)"
        case let .validationError(reason):
            return reason
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .invalidToken, .authenticationRequired:
            return "Tap here to sign in again."
        case .serverError:
            return "Please try again later. If the problem persists, contact support."
        default:
            return nil
        }
    }
}

/// Represents errors specific to event operations
enum EventError: LocalizedError {
    case invalidStatusTransition(from: String, to: String)
    case eventNotFound(id: String)
    case invalidEventData(reason: String)
    case calendarAccessDenied
    case calendarError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .invalidStatusTransition(from, to):
            return "Cannot change event status from '\(from)' to '\(to)'"
        case let .eventNotFound(id):
            return "Event not found: \(id)"
        case let .invalidEventData(reason):
            return "Invalid event data: \(reason)"
        case .calendarAccessDenied:
            return "Calendar access is required for this operation"
        case let .calendarError(error):
            return "Calendar error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .calendarAccessDenied:
            return "Open Settings to grant calendar access"
        case .invalidStatusTransition:
            return "Contact support if you need to perform this operation"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
}
