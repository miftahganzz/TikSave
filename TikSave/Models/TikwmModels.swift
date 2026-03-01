import Foundation
import AppKit
import UserNotifications

// MARK: - TikWM API Response Models (Defensive)
struct TikwmResponse: Codable {
    let code: Int
    let msg: String
    let processedTime: Double?
    let data: TikwmData?
    
    enum CodingKeys: String, CodingKey {
        case code, msg, data
        case processedTime = "processed_time"
    }
}

struct TikwmData: Codable, Identifiable {
    let id: String
    let region: String?
    let title: String?
    let duration: Int?
    let play: String?
    let wmplay: String?
    let size: Int?
    let wmSize: Int?
    let cover: String?
    let originCover: String?
    let images: [String]? // photomode support
    let music: String?
    let musicInfo: MusicInfo?
    let playCount: Int?
    let diggCount: Int?
    let commentCount: Int?
    let shareCount: Int?
    let downloadCount: Int?
    let collectCount: Int?
    let createTime: Int?
    let isAd: Bool?
    let author: Author?
    
    enum CodingKeys: String, CodingKey {
        case id, region, title, duration, play, wmplay, size, cover, music, author
        case wmSize = "wm_size"
        case originCover = "origin_cover"
        case images
        case musicInfo = "music_info"
        case playCount = "play_count"
        case diggCount = "digg_count"
        case commentCount = "comment_count"
        case shareCount = "share_count"
        case downloadCount = "download_count"
        case collectCount = "collect_count"
        case createTime = "create_time"
        case isAd = "is_ad"
    }
}

struct Author: Codable, Identifiable {
    let id: String?
    let uniqueId: String?
    let nickname: String?
    let avatar: String?
    
    enum CodingKeys: String, CodingKey {
        case id, nickname, avatar
        case uniqueId = "unique_id"
    }
}

struct MusicInfo: Codable {
    let id: String?
    let title: String?
    let author: String?
    let duration: Int?
    let original: Bool?
    let cover: String?
}

// MARK: - Download Item Model
struct DownloadItem: Codable, Identifiable {
    let id: UUID
    let sourceURL: String
    var status: DownloadStatus
    var progress: Double
    var downloadedBytes: Int64
    var totalBytes: Int64?
    var speed: Double // bytes per second
    var timeRemaining: TimeInterval?
    var localFileURL: URL?
    var errorMessage: String?
    var createdAt: Date
    var completedAt: Date?
    var tikwmData: TikwmData?
    var downloadFormat: DownloadFormat
    
    init(sourceURL: String, downloadFormat: DownloadFormat = .noWatermark) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.status = .waiting
        self.progress = 0.0
        self.downloadedBytes = 0
        self.totalBytes = nil
        self.speed = 0.0
        self.timeRemaining = nil
        self.localFileURL = nil
        self.errorMessage = nil
        self.createdAt = Date()
        self.completedAt = nil
        self.tikwmData = nil
        self.downloadFormat = downloadFormat
    }
}

enum DownloadStatus: String, Codable, CaseIterable {
    case waiting = "waiting"
    case fetching = "fetching"
    case ready = "ready"
    case downloading = "downloading"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .fetching: return "Fetching"
        case .ready: return "Ready"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isDownloading: Bool {
        self == .downloading
    }
    
    var isCompleted: Bool {
        self == .completed
    }
    
    var isFailed: Bool {
        self == .failed
    }
    
    var canPause: Bool {
        self == .downloading
    }
    
    var canResume: Bool {
        self == .paused
    }
    
    var canCancel: Bool {
        self == .waiting || self == .fetching || self == .ready || self == .downloading || self == .paused
    }
    
    var canRetry: Bool {
        self == .failed
    }
}

enum DownloadFormat: String, Codable, CaseIterable {
    case noWatermark = "no_watermark"
    case watermark = "watermark"
    case audio = "audio"
    case images = "images"
    
    var displayName: String {
        switch self {
        case .noWatermark: return "Video (No Watermark)"
        case .watermark: return "Video (With Watermark)"
        case .audio: return "Audio Only"
        case .images: return "Images (Photo Mode)"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .noWatermark, .watermark: return "mp4"
        case .audio: return "mp3"
        case .images: return "images"
        }
    }
}

// MARK: - Collection Model
struct Collection: Codable, Identifiable {
    let id: UUID
    var name: String
    var urls: [String]
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String, urls: [String] = [], tags: [String] = []) {
        self.id = UUID()
        self.name = name
        self.urls = urls
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - App Settings
struct AppSettings: Codable, Equatable {
    var defaultOutputFolder: URL
    var filenameTemplate: String
    var autoFetchOnPaste: Bool
    var autoDownloadAfterFetch: Bool
    var autoHandsFree: Bool
    var autoLaunchOnLogin: Bool
    var hideDockIcon: Bool
    var saveAudioAlso: Bool
    var downloadConcurrency: Int
    var watermarkDefault: Bool
    var thumbnailCacheSize: Int64 // bytes
    var clearHistoryOnExit: Bool
    var retryAttempts: Int
    // Smart file naming & organization
    var organizeByType: Bool
    var createSubfolders: Bool
    var customSubfolderPattern: String
    // Metadata embedding
    var embedMetadata: Bool
    var embedThumbnailAsCover: Bool
    var notificationSound: NotificationSound = .system
    var useCustomNotificationSound: Bool = false
    var activeCustomSoundID: UUID?
    var customNotificationSounds: [CustomNotificationSound] = []
    
    // Available filename templates
    static let filenameTemplates = [
        "{author_unique_id}_{id}_{title_sanitized}": "Author_ID_VideoID_Title",
        "{title_sanitized}_{id}": "Title_VideoID",
        "{author_name}_{title_sanitized}": "AuthorName_Title",
        "{timestamp}_{author_name}_{title_sanitized}": "Timestamp_Author_Title",
        "{date}_{id}_{title_sanitized}": "Date_VideoID_Title",
        "{music_title}_{author_name}": "MusicTitle_Author",
        "{author_unique_id}_{duration}_{title_sanitized}": "AuthorID_Duration_Title",
        "{play_count}_{digg_count}_{title_sanitized}": "Plays_Diggs_Title",
        "{author_name}_{music_title}": "Author_MusicTitle",
        "{id}_{author_name}_{timestamp}": "VideoID_Author_Timestamp"
    ]
    
    init() {
        if let loaded = AppSettings.loadFromDefaults() {
            self = loaded
            return
        }
        // Default to Downloads/TikSave
        let downloadsPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        self.defaultOutputFolder = downloadsPath.appendingPathComponent("TikSave")
        
        self.filenameTemplate = "{author_unique_id}_{id}_{title_sanitized}"
        self.autoFetchOnPaste = false
        self.autoDownloadAfterFetch = false
        self.autoHandsFree = false
        self.autoLaunchOnLogin = false
        self.hideDockIcon = false
        self.saveAudioAlso = false
        self.downloadConcurrency = 2
        self.watermarkDefault = false
        self.thumbnailCacheSize = 100 * 1024 * 1024 // 100MB
        self.clearHistoryOnExit = false
        self.retryAttempts = 2
        self.organizeByType = true
        self.createSubfolders = true
        self.customSubfolderPattern = "{type}/{author_unique_id}"
        self.embedMetadata = true
        self.embedThumbnailAsCover = true
        self.notificationSound = .system
        self.useCustomNotificationSound = false
        self.activeCustomSoundID = nil
        self.customNotificationSounds = []
    }

    private static let defaultsKey = "AppSettings"
    
    static func loadFromDefaults() -> AppSettings? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
    
    static func saveToDefaults(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Notification Sound Options
enum NotificationSound: String, Codable, CaseIterable, Identifiable {
    case system
    case tiksaveChime
    case fakhhhhhg
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "Default"
        case .tiksaveChime: return "TikSave Chime"
        case .fakhhhhhg: return "Fakhhhhhg"
        }
    }
    
    var fileName: String? {
        switch self {
        case .system: return nil
        case .tiksaveChime: return "TikSaveChime.wav"
        case .fakhhhhhg: return "fakhhhhhg.wav"
        }
    }
}

extension NotificationSound {
    func asUNNotificationSound() -> UNNotificationSound {
        guard let fileName else { return .default }
        guard let url = Self.locateResource(named: fileName) else { return .default }
        let soundName = UNNotificationSoundName(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            return UNNotificationSound(named: soundName) ?? .default
        }
        return .default
    }
    
    var nsUserNotificationSoundName: String {
        guard let fileName else { return NSUserNotificationDefaultSoundName }
        if let url = Self.locateResource(named: fileName), FileManager.default.fileExists(atPath: url.path) {
            return fileName
        }
        return NSUserNotificationDefaultSoundName
    }
    
    static func locateResource(named fileName: String) -> URL? {
        let components = fileName.split(separator: ".", maxSplits: 1).map(String.init)
        let resource = components.first ?? fileName
        let ext = components.count > 1 ? components.last : nil
        if let bundleURL = Bundle.main.url(forResource: resource, withExtension: ext) {
            return bundleURL
        }
        if let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let sandboxSounds = library.appendingPathComponent("Sounds", isDirectory: true).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: sandboxSounds.path) {
                return sandboxSounds
            }
        }
        let sharedDir = URL(fileURLWithPath: ("~/Library/Sounds" as NSString).expandingTildeInPath, isDirectory: true)
        let sharedURL = sharedDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: sharedURL.path) {
            return sharedURL
        }
        let managerURL = CustomSoundManager.shared.url(for: fileName)
        return FileManager.default.fileExists(atPath: managerURL.path) ? managerURL : nil
    }
}

// MARK: - Custom Notification Sound Support
struct CustomNotificationSound: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var fileName: String
    
    init(id: UUID = UUID(), displayName: String, fileName: String) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
    }
}

enum NotificationSoundSource: Equatable {
    case builtIn(NotificationSound)
    case custom(CustomNotificationSound)
    
    var displayName: String {
        switch self {
        case .builtIn(let sound): return sound.displayName
        case .custom(let custom): return custom.displayName
        }
    }
    
    func asUNNotificationSound() -> UNNotificationSound {
        switch self {
        case .builtIn(let sound): return sound.asUNNotificationSound()
        case .custom(let custom): return custom.asUNNotificationSound()
        }
    }
    
    func legacySoundName() -> String {
        switch self {
        case .builtIn(let sound): return sound.nsUserNotificationSoundName
        case .custom(let custom): return custom.nsUserNotificationSoundName
        }
    }
    
    func previewURL() -> URL? {
        switch self {
        case .builtIn(let sound):
            guard let fileName = sound.fileName else { return nil }
            return NotificationSound.locateResource(named: fileName)
        case .custom(let custom):
            return CustomSoundManager.shared.url(for: custom.fileName)
        }
    }
}

extension AppSettings {
    func resolvedNotificationSoundSource() -> NotificationSoundSource {
        if useCustomNotificationSound,
           let activeID = activeCustomSoundID,
           let custom = customNotificationSounds.first(where: { $0.id == activeID }),
           CustomSoundManager.shared.fileExists(named: custom.fileName) {
            return .custom(custom)
        }
        return .builtIn(notificationSound)
    }
}

extension CustomNotificationSound {
    func asUNNotificationSound() -> UNNotificationSound {
        let manager = CustomSoundManager.shared
        let fileURL = manager.url(for: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
    
    var nsUserNotificationSoundName: String {
        let manager = CustomSoundManager.shared
        let fileURL = manager.url(for: fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileName
        }
        return NSUserNotificationDefaultSoundName
    }
}

// MARK: - URL Validation
extension URL {
    var isTikTokURL: Bool {
        let host = self.host?.lowercased() ?? ""
        return host.contains("tiktok.com") || host.contains("vt.tiktok.com") || host.contains("vm.tiktok.com")
    }
    
    var extractTikTokID: String? {
        // Extract video ID from various TikTok URL formats
        let pathComponents = self.pathComponents
        
        // Handle /video/{id} format
        if let videoIndex = pathComponents.firstIndex(of: "video"),
           videoIndex + 1 < pathComponents.count {
            return pathComponents[videoIndex + 1]
        }
        
        // Handle short URLs (vt.tiktok.com)
        if self.host?.contains("vt.tiktok.com") == true {
            // The ID is usually in the path for short URLs
            return self.pathComponents.last
        }
        
        return nil
    }
}

// MARK: - String Extensions for Filename Sanitization
extension String {
    var sanitizedForFilename: String {
        return self
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var truncatedForFilename: String {
        let maxLength = 100 // Reasonable limit for filename
        if self.count <= maxLength {
            return self
        }
        return String(self.prefix(maxLength))
    }
    
    func truncatedForFilename(_ maxLength: Int) -> String {
        if self.count <= maxLength {
            return self
        }
        return String(self.prefix(maxLength))
    }
}

// MARK: - Formatted Number Extensions
extension Int {
    var formattedCount: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        } else {
            return String(self)
        }
    }
}

extension Int64 {
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB, .useBytes]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: self)
    }
}

extension Double {
    var formattedSpeed: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
        byteCountFormatter.countStyle = .file
        return "\(byteCountFormatter.string(fromByteCount: Int64(self)))/s"
    }
}

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

// MARK: - TikTok Profile Errors

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
