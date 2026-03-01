import Foundation

// MARK: - API Client
@MainActor
class TikwmAPIClient: ObservableObject {
    static let shared = TikwmAPIClient()
    
    // MARK: - Configuration
    private let baseURL = "https://tikwm.com/api/"
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var lastError: TikwmAPIError?
    
    // MARK: - Debug Logging
    #if DEBUG
    private let enableDebugLogging = true
    #else
    private let enableDebugLogging = false
    #endif
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        // Set reasonable headers
        config.httpAdditionalHeaders = [
            "User-Agent": "TikSave/1.0 (macOS)",
            "Accept": "application/json",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        
        self.session = URLSession(configuration: config)
        
        self.jsonDecoder = JSONDecoder()
        // Don't use snake_case conversion since we handle it manually with CodingKeys
    }
    
    // MARK: - Public Methods
    
    /// Fetch TikTok video metadata from URL
    /// - Parameter url: TikTok video URL
    /// - Returns: TikwmData containing video metadata
    func fetchVideoMetadata(from url: String) async throws -> TikwmData {
        // Validate input URL
        try validateTikTokURL(url)
        
        // Build request URL with proper encoding
        let requestURL = try buildRequestURL(from: url)
        
        debugLog("Request URL: \(requestURL.absoluteString)")
        
        isLoading = true
        lastError = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let (data, response) = try await session.data(from: requestURL)
            
            // Log response details
            if let httpResponse = response as? HTTPURLResponse {
                debugLog("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            // Log raw response body for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                let truncatedResponse = rawResponse.count > 500 ? String(rawResponse.prefix(500)) + "..." : rawResponse
                debugLog("Raw Response: \(truncatedResponse)")
            } else {
                debugLog("Raw Response: [Unable to decode as UTF-8]")
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TikwmAPIError.invalidResponse("Not an HTTP response")
            }
            
            // Check HTTP status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw TikwmAPIError.httpError(httpResponse.statusCode)
            }
            
            // Check for empty response
            guard !data.isEmpty else {
                throw TikwmAPIError.emptyResponse
            }
            
            // Decode JSON response
            let tikwmResponse = try decodeResponse(data: data)
            
            // Check API response code
            guard tikwmResponse.code == 0 else {
                throw TikwmAPIError.apiError(tikwmResponse.msg)
            }
            
            // Check if data exists
            guard let responseData = tikwmResponse.data else {
                throw TikwmAPIError.invalidResponse("Missing data field in API response")
            }
            
            debugLog("Successfully decoded TikTok metadata for ID: \(responseData.id)")
            return responseData
            
        } catch let error as TikwmAPIError {
            lastError = error
            throw error
        } catch {
            let apiError = TikwmAPIError.networkError(underlying: error)
            lastError = apiError
            throw apiError
        }
    }
    
    // MARK: - Private Methods
    
    /// Validate TikTok URL format
    private func validateTikTokURL(_ url: String) throws {
        guard !url.isEmpty else {
            throw TikwmAPIError.invalidURL("URL cannot be empty")
        }
        
        guard let nsURL = URL(string: url) else {
            throw TikwmAPIError.invalidURL("Invalid URL format")
        }
        
        guard nsURL.isTikTokURL else {
            throw TikwmAPIError.invalidURL("URL must be a valid TikTok URL (tiktok.com, vt.tiktok.com, or vm.tiktok.com)")
        }
    }
    
    /// Build request URL with proper percent-encoding
    private func buildRequestURL(from tiktokURL: String) throws -> URL {
        // Encode the TikTok URL for use as query parameter
        guard let encodedURL = tiktokURL.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) else {
            throw TikwmAPIError.urlEncodingFailed
        }
        
        let urlString = "\(baseURL)?url=\(encodedURL)"
        
        guard let finalURL = URL(string: urlString) else {
            throw TikwmAPIError.invalidURL("Failed to build request URL")
        }
        
        return finalURL
    }
    
    /// Decode JSON response with error handling
    private func decodeResponse(data: Data) throws -> TikwmResponse {
        do {
            let response = try jsonDecoder.decode(TikwmResponse.self, from: data)
            return response
        } catch {
            // Get raw response for error reporting
            let rawBody = String(data: data, encoding: .utf8) ?? "[Unable to decode as UTF-8]"
            let truncatedBody = rawBody.count > 500 ? String(rawBody.prefix(500)) + "..." : rawBody
            
            throw TikwmAPIError.decodeError(rawBody: truncatedBody)
        }
    }
    
    /// Debug logging helper
    internal func debugLog(_ message: String) {
        guard enableDebugLogging else { return }
        print("[TikwmAPIClient] \(message)")
    }
    
    // MARK: - Public Utility Methods
    
    /// Validate TikTok URL without making API call
    /// - Parameter url: URL to validate
    /// - Returns: True if valid TikTok URL format
    func validateTikTokURLFormat(_ url: String) -> Bool {
        guard let nsURL = URL(string: url) else { return false }
        return nsURL.isTikTokURL
    }
    
    /// Extract video ID from TikTok URL
    /// - Parameter url: TikTok URL
    /// - Returns: Video ID if found
    func extractVideoID(from url: String) -> String? {
        guard let nsURL = URL(string: url) else { return nil }
        return nsURL.extractTikTokID
    }
}

// MARK: - Mock Client for Testing
class MockTikwmAPIClient: TikwmAPIClient {
    private let shouldSucceed: Bool
    private let mockData: TikwmData?
    private let mockError: TikwmAPIError?
    private let delay: TimeInterval
    
    init(
        shouldSucceed: Bool = true,
        mockData: TikwmData? = nil,
        mockError: TikwmAPIError? = nil,
        delay: TimeInterval = 0.5
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockData = mockData
        self.mockError = mockError
        self.delay = delay
        super.init()
    }
    
    override func fetchVideoMetadata(from url: String) async throws -> TikwmData {
        isLoading = true
        defer { isLoading = false }
        
        debugLog("Mock fetch for URL: \(url)")
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if shouldSucceed, let mockData = mockData {
            lastError = nil
            debugLog("Mock success for ID: \(mockData.id)")
            return mockData
        } else if let mockError = mockError {
            lastError = mockError
            debugLog("Mock error: \(mockError.localizedDescription)")
            throw mockError
        } else {
            let error = TikwmAPIError.apiError("Mock error: No data available")
            lastError = error
            debugLog("Mock error: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Sample Mock Data
extension TikwmData {
    static let mock = TikwmData(
        id: "7602969456771386655",
        region: "US",
        title: "#fouyou #fyp",
        duration: 78,
        play: "https://example.com/video.mp4",
        wmplay: "https://example.com/video_wm.mp4",
        size: 14444151,
        wmSize: 13459355,
        cover: "https://example.com/cover.jpg",
        originCover: "https://example.com/origin_cover.webp",
        images: [
            "https://example.com/photo1.jpg",
            "https://example.com/photo2.jpg"
        ],
        music: "https://example.com/music.mp3",
        musicInfo: MusicInfo(
            id: "music123",
            title: "Sample Song",
            author: "Sample Artist",
            duration: 78,
            original: true,
            cover: "https://example.com/music_cover.jpg"
        ),
        playCount: 4937409,
        diggCount: 81141,
        commentCount: 952,
        shareCount: 19573,
        downloadCount: 1038,
        collectCount: 6951,
        createTime: 1770204288,
        isAd: false,
        author: Author(
            id: "author123",
            uniqueId: "aynomugqa8",
            nickname: "Boom",
            avatar: "https://example.com/avatar.jpg"
        )
    )
}
