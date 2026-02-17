import Foundation

enum AppError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String)
    case missingImages
    case decodingFailure(String)
    case encodingFailure(String)
    case oauthFailure(String)
    case storageFailure(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration."
        case .invalidResponse:
            return "Invalid server response."
        case let .httpStatus(code, body):
            return "Server error (\(code)): \(body)"
        case .missingImages:
            return "The model returned no images for this request."
        case let .decodingFailure(reason):
            return "Unable to decode response: \(reason)"
        case let .encodingFailure(reason):
            return "Unable to encode request: \(reason)"
        case let .oauthFailure(reason):
            return "OpenRouter OAuth failed: \(reason)"
        case let .storageFailure(reason):
            return "Local storage error: \(reason)"
        case let .unknown(reason):
            return "Unexpected error: \(reason)"
        }
    }
}
