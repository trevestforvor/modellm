import Foundation

enum HFAPIError: Error, LocalizedError {
    case httpError(Int)
    case rateLimited
    case decodingError(Error)
    case networkError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "HF API returned HTTP \(code)"
        case .rateLimited:
            return "Too many requests — try again in a moment."
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid API URL"
        }
    }
}
