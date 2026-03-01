import Foundation

// MARK: - API Errors
enum TikwmAPIError: Error, LocalizedError {
    case invalidURL(String? = nil)
    case urlEncodingFailed
    case networkError(underlying: Error)
    case httpError(Int)
    case invalidResponse(String? = nil)
    case apiError(String)
    case decodeError(rawBody: String)
    case rateLimitExceeded
    case serviceUnavailable
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let message):
            if let message = message {
                return "Invalid TikTok URL: \(message)"
            }
            return "Invalid TikTok URL provided"
        case .urlEncodingFailed:
            return "Failed to encode URL for API request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP error: \(code) - \(HTTPURLResponse.localizedString(forStatusCode: code))"
        case .invalidResponse(let message):
            if let message = message {
                return "Invalid server response: \(message)"
            }
            return "Invalid response from server"
        case .apiError(let message):
            return "API error: \(message)"
        case .decodeError(let rawBody):
            return "Failed to decode response. Server returned: \(rawBody)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serviceUnavailable:
            return "Service temporarily unavailable. Please try again later."
        case .emptyResponse:
            return "Server returned empty response"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidURL, .urlEncodingFailed:
            return "Please check the TikTok URL and try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .httpError(let code):
            if code >= 500 {
                return "Server error. Please try again later."
            } else if code == 429 {
                return "Too many requests. Please wait and try again."
            } else {
                return "Request failed. Please check the URL and try again."
            }
        case .invalidResponse, .apiError, .decodeError:
            return "The service may be experiencing issues. Please try again later."
        case .rateLimitExceeded:
            return "Wait a few minutes before making another request."
        case .serviceUnavailable:
            return "The service is temporarily down. Please try again later."
        case .emptyResponse:
            return "Server returned no data. Please try again."
        }
    }
}

// MARK: - HTTPURLResponse Extension
extension HTTPURLResponse {
    static func localizedString(forStatusCode statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        default: return "HTTP Error \(statusCode)"
        }
    }
}
