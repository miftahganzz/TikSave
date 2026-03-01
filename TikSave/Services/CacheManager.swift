import Foundation
import SwiftUI
import Combine

// MARK: - Cache Manager
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    @Published var thumbnailCache: [String: NSImage] = [:]
    @Published var metadataCache: [String: TikwmData] = [:]
    @Published var downloadHistory: [DownloadHistoryItem] = []
    
    private let cacheDirectory: URL
    private let thumbnailDirectory: URL
    private let metadataDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let maxHistoryItems = 1000
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Setup cache directories
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("TikSave")
        
        self.cacheDirectory = appDir.appendingPathComponent("Cache")
        self.thumbnailDirectory = cacheDirectory.appendingPathComponent("Thumbnails")
        self.metadataDirectory = cacheDirectory.appendingPathComponent("Metadata")
        
        createDirectoriesIfNeeded()
        loadCacheFromDisk()
        loadDownloadHistory()
        
        // Setup periodic cache cleanup
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupCache()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .clearCacheRequested)
            .sink { [weak self] _ in
                self?.clearCache()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Directory Management
    private func createDirectoriesIfNeeded() {
        [cacheDirectory, thumbnailDirectory, metadataDirectory].forEach { url in
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Thumbnail Cache
    func getThumbnail(for videoID: String, imageURL: String? = nil) -> NSImage? {
        // Check memory cache first
        if let cachedImage = thumbnailCache[videoID] {
            return cachedImage
        }
        
        // Check disk cache
        let thumbnailURL = thumbnailDirectory.appendingPathComponent("\(videoID).jpg")
        if FileManager.default.fileExists(atPath: thumbnailURL.path),
           let image = NSImage(contentsOf: thumbnailURL) {
            thumbnailCache[videoID] = image
            return image
        }
        
        // If image URL provided, download and cache
        if let imageURL = imageURL, let url = URL(string: imageURL) {
            downloadAndCacheThumbnail(for: videoID, from: url)
        }
        
        return nil
    }

    /// Store a thumbnail image in memory and on disk
    func cacheThumbnail(_ image: NSImage, for videoID: String) {
        thumbnailCache[videoID] = image
        saveThumbnailToDisk(for: videoID, image: image)
    }
    
    private func downloadAndCacheThumbnail(for videoID: String, from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = NSImage(data: data),
                  error == nil else {
                return
            }
            
            DispatchQueue.main.async {
                self.thumbnailCache[videoID] = image
                self.saveThumbnailToDisk(for: videoID, image: image)
            }
        }.resume()
    }
    
    private func saveThumbnailToDisk(for videoID: String, image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }
        
        let thumbnailURL = thumbnailDirectory.appendingPathComponent("\(videoID).jpg")
        try? jpegData.write(to: thumbnailURL)
    }
    
    // MARK: - Metadata Cache
    func getCachedMetadata(for videoID: String) -> TikwmData? {
        // Check memory cache first
        if let metadata = metadataCache[videoID] {
            return metadata
        }
        
        // Check disk cache
        let metadataURL = metadataDirectory.appendingPathComponent("\(videoID).json")
        if FileManager.default.fileExists(atPath: metadataURL.path),
           let data = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(TikwmData.self, from: data) {
            metadataCache[videoID] = metadata
            return metadata
        }
        
        return nil
    }
    
    func cacheMetadata(_ metadata: TikwmData) {
        metadataCache[metadata.id] = metadata
        
        let metadataURL = metadataDirectory.appendingPathComponent("\(metadata.id).json")
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }
    
    // MARK: - Download History
    func addToDownloadHistory(item: DownloadItem, metadata: TikwmData) {
        let historyItem = DownloadHistoryItem(
            id: UUID(),
            videoID: metadata.id,
            title: metadata.title ?? "Unknown",
            author: metadata.author?.nickname ?? "Unknown",
            downloadFormat: item.downloadFormat,
            downloadDate: Date(),
            fileSize: item.totalBytes ?? 0,
            filePath: item.localFileURL?.path,
            thumbnailURL: metadata.cover
        )
        
        downloadHistory.insert(historyItem, at: 0)
        
        // Keep only recent items
        if downloadHistory.count > maxHistoryItems {
            downloadHistory = Array(downloadHistory.prefix(maxHistoryItems))
        }
        
        saveDownloadHistory()
    }
    
    func clearDownloadHistory() {
        downloadHistory.removeAll()
        saveDownloadHistory()
    }
    
    private func saveDownloadHistory() {
        let historyURL = cacheDirectory.appendingPathComponent("download_history.json")
        if let data = try? JSONEncoder().encode(downloadHistory) {
            try? data.write(to: historyURL)
        }
    }
    
    private func loadDownloadHistory() {
        let historyURL = cacheDirectory.appendingPathComponent("download_history.json")
        if FileManager.default.fileExists(atPath: historyURL.path),
           let data = try? Data(contentsOf: historyURL),
           let history = try? JSONDecoder().decode([DownloadHistoryItem].self, from: data) {
            downloadHistory = history
        }
    }
    
    // MARK: - Cache Management
    private func loadCacheFromDisk() {
        // Load thumbnails from disk
        if let enumerator = FileManager.default.enumerator(at: thumbnailDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let videoID = fileURL.deletingPathExtension().lastPathComponent
                if let image = NSImage(contentsOf: fileURL) {
                    thumbnailCache[videoID] = image
                }
            }
        }
        
        // Load metadata from disk
        if let enumerator = FileManager.default.enumerator(at: metadataDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                let videoID = fileURL.deletingPathExtension().lastPathComponent
                if let data = try? Data(contentsOf: fileURL),
                   let metadata = try? JSONDecoder().decode(TikwmData.self, from: data) {
                    metadataCache[videoID] = metadata
                }
            }
        }
    }
    
    @discardableResult
    func clearCache() -> Int64 {
        let freedBytes = calculateCacheSize()
        thumbnailCache.removeAll()
        metadataCache.removeAll()
        downloadHistory.removeAll()
        
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        createDirectoriesIfNeeded()
        updateCachedSize()
        
        NotificationCenter.default.post(name: .cacheCleared, object: nil, userInfo: ["freedBytes": freedBytes])
        return freedBytes
    }
    
    func currentCacheSize() -> Int64 {
        return calculateCacheSize()
    }
    
    private func cleanupCache() {
        // Implement LRU cache cleanup based on size
        let currentSize = calculateCacheSize()
        
        if currentSize > maxCacheSize {
            // Remove oldest thumbnails first
            let thumbnailFiles = try? FileManager.default.contentsOfDirectory(at: thumbnailDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            let sortedFiles = thumbnailFiles?.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 < date2
            }
            
            var sizeToRemove = currentSize - maxCacheSize + (maxCacheSize / 10) // Remove extra 10%
            
            for file in sortedFiles ?? [] {
                if sizeToRemove <= 0 { break }
                
                if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let fileSize = attributes[.size] as? Int64 {
                    try? FileManager.default.removeItem(at: file)
                    sizeToRemove -= fileSize
                    
                    // Remove from memory cache too
                    let videoID = file.deletingPathExtension().lastPathComponent
                    thumbnailCache.removeValue(forKey: videoID)
                }
            }
        }
    }
    
    private func calculateCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = values.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        return totalSize
    }

    private func updateCachedSize() {
        var settings = AppSettings()
        settings.thumbnailCacheSize = calculateCacheSize()
        AppSettings.saveToDefaults(settings)
    }
    
    // MARK: - Cache Statistics
    var cacheStats: CacheStats {
        CacheStats(
            thumbnailCount: thumbnailCache.count,
            metadataCount: metadataCache.count,
            historyCount: downloadHistory.count,
            totalSize: calculateCacheSize()
        )
    }
}

// MARK: - Download History Model
struct DownloadHistoryItem: Codable, Identifiable {
    let id: UUID
    let videoID: String
    let title: String
    let author: String
    let downloadFormat: DownloadFormat
    let downloadDate: Date
    let fileSize: Int64
    let filePath: String?
    let thumbnailURL: String?
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: downloadDate)
    }
    
    var fileExists: Bool {
        guard let filePath = filePath else { return false }
        return FileManager.default.fileExists(atPath: filePath)
    }
}

// MARK: - Cache Stats
struct CacheStats {
    let thumbnailCount: Int
    let metadataCount: Int
    let historyCount: Int
    let totalSize: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

extension Notification.Name {
    static let clearCacheRequested = Notification.Name("ClearCacheRequested")
    static let cacheCleared = Notification.Name("CacheCleared")
}
