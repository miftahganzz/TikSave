import Foundation
import Combine
import AppKit
import UserNotifications

// MARK: - Download Errors
enum DownloadError: Error, LocalizedError {
    case invalidURL
    case fileSystemError(Error)
    case networkError(Error)
    case downloadCancelled
    case downloadFailed(String)
    case insufficientSpace
    case securityError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .downloadCancelled:
            return "Download was cancelled"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .insufficientSpace:
            return "Insufficient disk space"
        case .securityError:
            return "Security error: Cannot access file system"
        }
    }
}

// MARK: - Speed Tracker
private class SpeedTracker {
    private var samples: [(bytes: Int64, timestamp: Date)] = []
    private let maxSamples = 10
    
    func addSample(bytes: Int64) {
        samples.append((bytes: bytes, timestamp: Date()))
        
        // Keep only recent samples
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }
    
    func calculateSpeed() -> Double {
        guard samples.count >= 2 else { return 0 }
        
        let timeDiff = samples.last!.timestamp.timeIntervalSince(samples.first!.timestamp)
        let bytesDiff = samples.last!.bytes - samples.first!.bytes
        
        guard timeDiff > 0 else { return 0 }
        
        return Double(bytesDiff) / timeDiff
    }
    
    func estimateTimeRemaining(currentBytes: Int64, totalBytes: Int64) -> TimeInterval? {
        let speed = calculateSpeed()
        guard speed > 0, currentBytes < totalBytes else { return nil }
        
        let remainingBytes = totalBytes - currentBytes
        return Double(remainingBytes) / speed
    }
}

// MARK: - Download Progress
struct DownloadProgress {
    let bytesReceived: Int64
    let totalBytes: Int64
    let speed: Double // bytes per second
    let percentComplete: Double
    let timeRemaining: TimeInterval?
    
    var formattedProgress: String {
        let percent = String(format: "%.1f", percentComplete * 100)
        let received = ByteCountFormatter.string(fromByteCount: bytesReceived, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let speed = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file)
        
        var progress = "\(percent)% - \(received)/\(total)"
        
        if speed != "0 bytes" {
            progress += " - \(speed)/s"
        }
        
        if let timeRemaining = timeRemaining, timeRemaining > 0 {
            let timeFormatter = DateComponentsFormatter()
            timeFormatter.allowedUnits = [.hour, .minute, .second]
            timeFormatter.unitsStyle = .abbreviated
            if let timeString = timeFormatter.string(from: timeRemaining) {
                progress += " - \(timeString) left"
            }
        }
        
        return progress
    }
}

// MARK: - Download Manager
@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    // MARK: - Published Properties
    @Published var downloadQueue: [DownloadItem] = []
    @Published var activeDownloads: [UUID: URLSessionDownloadTask] = [:]
    @Published var concurrencyLimit: Int = 2
    @Published var retryAttempts: Int = 2
    
    // MARK: - Private Properties
    private let session: URLSession
    private let fileManager: FileManager
    private var progressObservers: [UUID: AnyCancellable] = [:]
    private var downloadTimers: [UUID: Timer] = [:]
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var settings = AppSettings()
    private var speedTrackers: [UUID: SpeedTracker] = [:]
    
    // MARK: - Initialization
    private init() {
        self.fileManager = FileManager.default
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300 // 5 minutes
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Add download to queue
    func addToQueue(url: String, format: DownloadFormat = .noWatermark) {
        let downloadItem = DownloadItem(sourceURL: url, downloadFormat: format)
        downloadQueue.append(downloadItem)
        processQueue()
    }
    
    /// Add photo-mode images batch to queue
    func addImagesToQueue(url: String, images: [String]) {
        let downloadItem = DownloadItem(sourceURL: url, downloadFormat: .images)
        var item = downloadItem
        item.tikwmData = TikwmData(
            id: UUID().uuidString,
            region: nil,
            title: nil,
            duration: 0,
            play: nil,
            wmplay: nil,
            size: nil,
            wmSize: nil,
            cover: images.first,
            originCover: images.first,
            images: images,
            music: nil,
            musicInfo: nil,
            playCount: nil,
            diggCount: nil,
            commentCount: nil,
            shareCount: nil,
            downloadCount: nil,
            collectCount: nil,
            createTime: nil,
            isAd: nil,
            author: nil
        )
        downloadQueue.append(item)
        processQueue()
    }
    
    /// Add multiple downloads to queue
    func addToQueue(urls: [String], format: DownloadFormat = .noWatermark) {
        for url in urls {
            let downloadItem = DownloadItem(sourceURL: url, downloadFormat: format)
            downloadQueue.append(downloadItem)
        }
        processQueue()
    }
    
    /// Start download for a specific item
    func startDownload(for item: DownloadItem) {
        guard let index = downloadQueue.firstIndex(where: { $0.id == item.id }) else { return }
        
        downloadQueue[index].status = .downloading
        
        Task {
            do {
                // First fetch metadata
                let metadata = try await TikwmAPIClient.shared.fetchVideoMetadata(from: item.sourceURL)
                
                // Update item with metadata
                downloadQueue[index].tikwmData = metadata
                downloadQueue[index].status = .ready
                
                // Start actual download
                try await downloadFile(item: downloadQueue[index], metadata: metadata)
                
            } catch {
                downloadQueue[index].status = .failed
                downloadQueue[index].errorMessage = error.localizedDescription
                
                // Retry logic
                if shouldRetry(item: downloadQueue[index]) {
                    retryDownload(for: item)
                } else {
                    processQueue() // Move to next item
                }
            }
        }
    }
    
    /// Pause download
    func pauseDownload(for item: DownloadItem) {
        guard let task = activeDownloads[item.id] else { return }
        task.suspend()
        
        if let index = downloadQueue.firstIndex(where: { $0.id == item.id }) {
            downloadQueue[index].status = .paused
        }
    }
    
    /// Resume download
    func resumeDownload(for item: DownloadItem) {
        guard let task = activeDownloads[item.id] else { return }
        task.resume()
        
        if let index = downloadQueue.firstIndex(where: { $0.id == item.id }) {
            downloadQueue[index].status = .downloading
        }
    }
    
    /// Cancel download
    func cancelDownload(for item: DownloadItem) {
        guard let task = activeDownloads[item.id] else { return }
        task.cancel()
        
        activeDownloads.removeValue(forKey: item.id)
        
        if let index = downloadQueue.firstIndex(where: { $0.id == item.id }) {
            downloadQueue[index].status = .cancelled
        }
        
        // Clean up progress observers and timers
        cleanupProgressObservers(for: item.id)
        processQueue()
    }
    
    /// Cancel all active downloads
    func cancelAll() {
        let active = activeDownloads.keys
        for id in active {
            if let task = activeDownloads[id] {
                task.cancel()
            }
            if let index = downloadQueue.firstIndex(where: { $0.id == id }) {
                downloadQueue[index].status = .cancelled
            }
            cleanupProgressObservers(for: id)
        }
        activeDownloads.removeAll()
    }
    
    /// Retry failed download
    func retryDownload(for item: DownloadItem) {
        guard let index = downloadQueue.firstIndex(where: { $0.id == item.id }),
              downloadQueue[index].status == .failed else { return }
        
        // Reset item state
        downloadQueue[index].status = .waiting
        downloadQueue[index].progress = 0.0
        downloadQueue[index].downloadedBytes = 0
        downloadQueue[index].totalBytes = nil
        downloadQueue[index].speed = 0.0
        downloadQueue[index].errorMessage = nil
        
        processQueue()
    }
    
    /// Clear completed downloads
    func clearCompleted() {
        downloadQueue.removeAll { $0.status == .completed }
    }
    
    /// Clear failed downloads
    func clearFailed() {
        downloadQueue.removeAll { $0.status == .failed }
    }
    
    /// Get download statistics
    var downloadStats: (active: Int, completed: Int, failed: Int, total: Int) {
        let active = downloadQueue.filter { $0.status.isDownloading }.count
        let completed = downloadQueue.filter { $0.status.isCompleted }.count
        let failed = downloadQueue.filter { $0.status.isFailed }.count
        let total = downloadQueue.count
        
        return (active, completed, failed, total)
    }
    
    // MARK: - Private Methods
    
    private func processQueue() {
        let activeCount = downloadQueue.filter { $0.status.isDownloading }.count
        
        guard activeCount < concurrencyLimit else { return }
        
        // Find next waiting item
        if let nextIndex = downloadQueue.firstIndex(where: { $0.status == .waiting }) {
            let nextItem = downloadQueue[nextIndex]
            startDownload(for: nextItem)
        }
    }
    
    private func downloadFile(item: DownloadItem, metadata: TikwmData) async throws {
        // Determine download URL based on format
        let downloadURL: String
        let fileExtension: String
        
        switch item.downloadFormat {
        case .noWatermark:
            downloadURL = metadata.play ?? metadata.wmplay ?? ""
            fileExtension = "mp4"
        case .watermark:
            downloadURL = metadata.wmplay ?? metadata.play ?? ""
            fileExtension = "mp4"
        case .audio:
            downloadURL = metadata.music ?? ""
            fileExtension = "mp3"
        case .images:
            // handled separately
            downloadURL = ""
            fileExtension = "images"
        }
        
        // Photo mode: download all images as a batch and mark complete
        if item.downloadFormat == .images {
            try await downloadImages(item: item, metadata: metadata)
            return
        }
        
        // Validate download URL
        guard !downloadURL.isEmpty, let url = URL(string: downloadURL) else {
            throw DownloadError.invalidURL
        }
        
        // Generate filename
        let filename = generateFilename(for: metadata, extension: fileExtension)
        let outputURL = try getOutputURL(for: filename, metadata: metadata, format: item.downloadFormat)
        
        // Create download task
        let task = session.downloadTask(with: url) { [weak self] tempURL, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    await self.handleDownloadError(error, for: item.id)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await self.handleDownloadError(DownloadError.downloadFailed("Invalid response"), for: item.id)
                    return
                }
                
                guard let tempURL = tempURL else {
                    await self.handleDownloadError(DownloadError.downloadFailed("No temporary file"), for: item.id)
                    return
                }
                
                do {
                    // Move file to final location
                    try self.fileManager.moveItem(at: tempURL, to: outputURL)
                    
                    // Update item
                    if let index = self.downloadQueue.firstIndex(where: { $0.id == item.id }) {
                        self.downloadQueue[index].status = .completed
                        self.downloadQueue[index].progress = 1.0
                        self.downloadQueue[index].localFileURL = outputURL
                        self.downloadQueue[index].completedAt = Date()
                        
                        // Add to download history
                        let completedItem = self.downloadQueue[index]
                        self.cacheManager.addToDownloadHistory(item: completedItem, metadata: metadata)
                        
                        // Cache thumbnail
                        if let thumbnailURL = metadata.cover {
                            self.cacheManager.getThumbnail(for: metadata.id, imageURL: thumbnailURL)
                        }
                        
                        // Cache metadata
                        self.cacheManager.cacheMetadata(metadata)
                        
                        // Send completion notification
                        self.sendCompletionNotification(for: completedItem)
                    }
                    
                } catch {
                    await self.handleDownloadError(DownloadError.fileSystemError(error), for: item.id)
                }
                
                // Clean up
                self.activeDownloads.removeValue(forKey: item.id)
                self.cleanupProgressObservers(for: item.id)
                
                // Process next item in queue
                self.processQueue()
            }
        }
        
        // Store task and start
        activeDownloads[item.id] = task
        task.resume()
        
        // Setup progress monitoring
        setupProgressMonitoring(for: item.id, task: task)
    }

    private func downloadImages(item: DownloadItem, metadata: TikwmData) async throws {
        guard let images = metadata.images, !images.isEmpty else {
            throw DownloadError.invalidURL
        }
        let baseFolder = try getOutputURL(for: generateFilename(for: metadata, extension: "images"), metadata: metadata, format: .images)
            .deletingPathExtension()
        try fileManager.createDirectory(at: baseFolder, withIntermediateDirectories: true)
        var index = 1
        for urlString in images {
            guard let url = URL(string: urlString) else { continue }
            let data = try await URLSession.shared.data(from: url).0
            let fileURL = baseFolder.appendingPathComponent(String(format: "%02d.jpg", index))
            try data.write(to: fileURL)
            index += 1
        }
        if let i = downloadQueue.firstIndex(where: { $0.id == item.id }) {
            downloadQueue[i].status = .completed
            downloadQueue[i].progress = 1.0
            downloadQueue[i].localFileURL = baseFolder
            downloadQueue[i].completedAt = Date()
            sendCompletionNotification(for: downloadQueue[i])
        }
        activeDownloads.removeValue(forKey: item.id)
        processQueue()
    }
    
    private func setupProgressMonitoring(for itemID: UUID, task: URLSessionDownloadTask) {
        // Timer for progress updates
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let task = self.activeDownloads[itemID],
                      let index = self.downloadQueue.firstIndex(where: { $0.id == itemID }) else {
                    return
                }
                
                // Update progress
                if task.countOfBytesExpectedToReceive > 0 {
                    let progress = Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive)
                    self.downloadQueue[index].progress = progress
                    self.downloadQueue[index].downloadedBytes = task.countOfBytesReceived
                    self.downloadQueue[index].totalBytes = task.countOfBytesExpectedToReceive
                    
                    // Use SpeedTracker for accurate speed calculation
                    let speedTracker = self.speedTrackers[itemID] ?? SpeedTracker()
                    speedTracker.addSample(bytes: task.countOfBytesReceived)
                    self.speedTrackers[itemID] = speedTracker
                    
                    let speed = speedTracker.calculateSpeed()
                    let timeRemaining = speedTracker.estimateTimeRemaining(
                        currentBytes: task.countOfBytesReceived,
                        totalBytes: task.countOfBytesExpectedToReceive
                    )
                    
                    self.downloadQueue[index].speed = speed
                    self.downloadQueue[index].timeRemaining = timeRemaining
                }
            }
        }
        
        downloadTimers[itemID] = timer
    }
    
    private func cleanupProgressObservers(for itemID: UUID) {
        progressObservers[itemID]?.cancel()
        progressObservers.removeValue(forKey: itemID)
        downloadTimers[itemID]?.invalidate()
        downloadTimers.removeValue(forKey: itemID)
        speedTrackers.removeValue(forKey: itemID)
    }
    
    private func handleDownloadError(_ error: Error, for itemID: UUID) async {
        if let index = downloadQueue.firstIndex(where: { $0.id == itemID }) {
            downloadQueue[index].status = .failed
            downloadQueue[index].errorMessage = error.localizedDescription
        }
        
        activeDownloads.removeValue(forKey: itemID)
        cleanupProgressObservers(for: itemID)
    }

    // MARK: - Notifications
    private func sendCompletionNotification(for item: DownloadItem) {
        settings = AppSettings() // refresh persisted settings
        // Only surface notifications when automation is active to avoid noise
        guard settings.autoFetchOnPaste || settings.autoDownloadAfterFetch || settings.autoHandsFree else { return }
        let soundSource = settings.resolvedNotificationSoundSource()
        let content = UNMutableNotificationContent()
        content.title = "Download Completed"
        let title = item.tikwmData?.title ?? "Saved item"
        content.body = "\(title) ready"
        content.sound = soundSource.asUNNotificationSound()
        if let fileURL = item.localFileURL {
            content.userInfo = ["path": fileURL.path]
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Download notification failed: %@", error.localizedDescription)
                self.deliverLegacyNotification(title: content.title, message: content.body, sound: soundSource)
            }
        }
    }

    private func deliverLegacyNotification(title: String, message: String, sound: NotificationSoundSource) {
        DispatchQueue.main.async {
            let legacyNotification = NSUserNotification()
            legacyNotification.title = title
            legacyNotification.informativeText = message
            legacyNotification.soundName = sound.legacySoundName()
            NSUserNotificationCenter.default.deliver(legacyNotification)
        }
    }
    
    private func shouldRetry(item: DownloadItem) -> Bool {
        // Implement retry logic based on error type and attempt count
        // This is a simplified version
        return item.status == .failed && retryAttempts > 0
    }
    
    private func generateFilename(for metadata: TikwmData, extension: String) -> String {
        let template = AppSettings().filenameTemplate
        
        // Get current date for timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        // Extract duration in seconds
        let durationSeconds = metadata.duration ?? 0
        let durationMinutes = durationSeconds / 60
        let durationSecondsRemainder = durationSeconds % 60
        let durationFormatted = String(format: "%02d:%02d", durationMinutes, durationSecondsRemainder)
        
        // Extract play count
        let playCount = metadata.playCount ?? 0
        let formattedPlayCount = NumberFormatter.localizedString(from: NSNumber(value: playCount), number: .decimal)
        
        // Extract digg count
        let diggCount = metadata.diggCount ?? 0
        let formattedDiggCount = NumberFormatter.localizedString(from: NSNumber(value: diggCount), number: .decimal)
        
        // Extract comment count
        let commentCount = metadata.commentCount ?? 0
        let formattedCommentCount = NumberFormatter.localizedString(from: NSNumber(value: commentCount), number: .decimal)
        
        // Extract share count
        let shareCount = metadata.shareCount ?? 0
        let formattedShareCount = NumberFormatter.localizedString(from: NSNumber(value: shareCount), number: .decimal)
        
        // Extract music info
        let musicTitle = metadata.musicInfo?.title?.sanitizedForFilename.truncatedForFilename ?? "no_music"
        let musicAuthor = metadata.musicInfo?.author?.sanitizedForFilename.truncatedForFilename ?? "unknown"
        
        // Extract author info
        let authorName = metadata.author?.nickname?.sanitizedForFilename.truncatedForFilename ?? "unknown_author"
        let authorUniqueId = metadata.author?.uniqueId ?? "unknown_id"
        
        // Extract video description (first 50 chars)
        let description = (metadata.title ?? "").sanitizedForFilename.truncatedForFilename(50)
        
        var filename = template
            .replacingOccurrences(of: "{author_unique_id}", with: authorUniqueId)
            .replacingOccurrences(of: "{author_name}", with: authorName)
            .replacingOccurrences(of: "{id}", with: metadata.id)
            .replacingOccurrences(of: "{title_sanitized}", with: (metadata.title ?? "video").sanitizedForFilename.truncatedForFilename)
            .replacingOccurrences(of: "{title}", with: (metadata.title ?? "video"))
            .replacingOccurrences(of: "{timestamp}", with: timestamp)
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: Date()))
            .replacingOccurrences(of: "{duration}", with: durationFormatted)
            .replacingOccurrences(of: "{duration_seconds}", with: String(durationSeconds))
            .replacingOccurrences(of: "{play_count}", with: formattedPlayCount)
            .replacingOccurrences(of: "{digg_count}", with: formattedDiggCount)
            .replacingOccurrences(of: "{comment_count}", with: formattedCommentCount)
            .replacingOccurrences(of: "{share_count}", with: formattedShareCount)
            .replacingOccurrences(of: "{music_title}", with: musicTitle)
            .replacingOccurrences(of: "{music_author}", with: musicAuthor)
            .replacingOccurrences(of: "{description}", with: description)
            .replacingOccurrences(of: "{format}", with: `extension`)
        
        // Add format extension
        filename = "\(filename).\(`extension`)"
        
        // Handle filename conflicts with better numbering
        var finalFilename = filename
        var counter = 1
        
        while fileManager.fileExists(atPath: getOutputPath(for: finalFilename)) {
            let nameWithoutExt = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            finalFilename = "\(nameWithoutExt) (\(counter)).\(ext)"
            counter += 1
        }
        
        return finalFilename
    }
    
    private func getOutputURL(for filename: String, metadata: TikwmData, format: DownloadFormat) throws -> URL {
        let settings = AppSettings()
        var outputFolder = settings.defaultOutputFolder
        
        if settings.createSubfolders {
            let typeValue: String = {
                switch format {
                case .noWatermark, .watermark: return "video"
                case .audio: return "audio"
                case .images: return "images"
                }
            }()
            let author = metadata.author?.uniqueId ?? metadata.author?.nickname ?? "unknown"
            let replacements: [String: String] = [
                "{type}": typeValue,
                "{author_unique_id}": author,
                "{username}": author,
                "{id}": metadata.id
            ]
            var subfolder = settings.customSubfolderPattern
            for (key, value) in replacements {
                subfolder = subfolder.replacingOccurrences(of: key, with: value)
            }
            outputFolder = outputFolder.appendingPathComponent(subfolder)
        }
        
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        
        return outputFolder.appendingPathComponent(filename)
    }
    
    private func getOutputPath(for filename: String) -> String {
        let settings = AppSettings()
        return settings.defaultOutputFolder.appendingPathComponent(filename).path
    }
    
}

// MARK: - FileManager Extension
extension FileManager {
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        var isDirectory: ObjCBool = false
        if !fileExists(atPath: url.path, isDirectory: &isDirectory) {
            try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: nil)
        }
    }
}
