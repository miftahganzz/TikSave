import Foundation

// MARK: - TikTok Profile Models

struct TikTokProfile: Codable, Identifiable {
    var id: String { username }
    let name: String
    let username: String
    let bio: String
    let joined: String
    let avatar: String
    let verified: Bool
    let isPrivate: Bool
    let lastModifiedName: String
    let followers: Int
    let following: Int
    let likes: Int
    let videos: Int
    let friends: Int
    
    enum CodingKeys: String, CodingKey {
        case name, username, bio, joined, avatar, verified
        case isPrivate = "is_private"
        case lastModifiedName = "last_modified_name"
        case followers, following, likes, videos, friends
    }
    
    var formattedFollowers: String {
        formatNumber(followers)
    }
    
    var formattedFollowing: String {
        formatNumber(following)
    }
    
    var formattedLikes: String {
        formatNumber(likes)
    }
    
    var formattedVideos: String {
        formatNumber(videos)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if number >= 1_000_000 {
            let millions = Double(number) / 1_000_000.0
            return String(format: "%.1fM", millions)
        } else if number >= 1_000 {
            let thousands = Double(number) / 1_000.0
            return String(format: "%.1fK", thousands)
        } else {
            return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
        }
    }
}

// MARK: - TikTok Profile API Client

class TikTokProfileAPIClient: ObservableObject {
    static let shared = TikTokProfileAPIClient()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://tiktok-roasting.vercel.app/api/tiktok-profile"
    
    func fetchProfile(username: String) async throws -> TikTokProfile {
        guard !username.isEmpty else {
            throw TikTokProfileError.emptyUsername
        }
        
        // Clean username (remove @ if present)
        let cleanUsername = username.replacingOccurrences(of: "@", with: "")
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw TikTokProfileError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "username", value: cleanUsername)
        ]
        
        guard let url = urlComponents.url else {
            throw TikTokProfileError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TikTokProfileError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TikTokProfileError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let profile = try JSONDecoder().decode(TikTokProfile.self, from: data)
            return profile
        } catch {
            throw TikTokProfileError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum TikTokProfileError: LocalizedError {
    case emptyUsername
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyUsername:
            return "Please enter a username"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        }
    }
}
