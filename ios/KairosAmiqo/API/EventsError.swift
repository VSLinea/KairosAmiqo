import Foundation

enum EventsError: LocalizedError {
    case authenticationRequired
    case networkError
    case serverError(String)
    case invalidEvent
    case calendarAccessDenied

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Please sign in"
        case .networkError:
            return "Check your internet connection"
        case let .serverError(message):
            return message
        case .invalidEvent:
            return "Invalid event details"
        case .calendarAccessDenied:
            return "Calendar access required"
        }
    }

    static func from(_ error: Error) -> EventsError {
        if error is URLError {
            return .networkError
        }
        if let apiError = error as? EventsError {
            return apiError
        }
        return .serverError(error.localizedDescription)
    }
}
