import Foundation
import SwiftUI
import Combine

// MARK: - Download ViewModel for Touch Bar Integration
@MainActor
class DownloadViewModel: ObservableObject {
    @Published var inputURL: String = ""
    @Published var selectedFormat: DownloadFormat = .noWatermark
    @Published var fetchedData: TikwmData?
    @Published var isLoading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    @Published var autoClipboardDetect: Bool = false
    
    // Shared instance for Touch Bar access
    static let shared = DownloadViewModel()
    
    // Services
    private let apiClient = TikwmAPIClient.shared
    private let downloadManager = DownloadManager.shared
    private let clipboardMonitor = ClipboardMonitor.shared
    private let cacheManager = CacheManager.shared
    private var settings = AppSettings()
    
    // Combine subscribers
    private var cancellables = Set<AnyCancellable>()
    
    // Publishers for Touch Bar observation
    var canFetch: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($inputURL, $isLoading)
            .map { url, loading in
                !url.isEmpty && !loading && self.isValidTikTokURL(url)
            }
            .eraseToAnyPublisher()
    }
    
    var canDownload: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3($fetchedData, $isLoading, $isDownloading)
            .map { data, loading, downloading in
                data != nil && !loading && !downloading
            }
            .eraseToAnyPublisher()
    }
    
    var isProcessing: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($isLoading, $isDownloading)
            .map { loading, downloading in
                loading || downloading
            }
            .eraseToAnyPublisher()
    }
    
    init() {
        setupClipboardMonitoring()
        setupDownloadProgressTracking()
        clipboardMonitor.updateFromSettings()
    }
    
    // MARK: - Actions
    
    func pasteURL() {
        // Use clipboard monitor for better URL detection
        if let tiktokURL = clipboardMonitor.getFirstTikTokURL() {
            inputURL = tiktokURL.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    func toggleAutoClipboardDetect() {
        autoClipboardDetect.toggle()
        
        if autoClipboardDetect {
            clipboardMonitor.startAutoDetection()
        } else {
            clipboardMonitor.stopAutoDetection()
        }
    }
    
    func fetchVideo() async {
        guard !inputURL.isEmpty, isValidTikTokURL(inputURL) else { return }
        
        // Check cache first
        if let videoID = URL(string: inputURL)?.extractTikTokID,
           let cachedData = cacheManager.getCachedMetadata(for: videoID) {
            fetchedData = cachedData
            return
        }
        
        isLoading = true
        
        do {
            let data = try await apiClient.fetchVideoMetadata(from: inputURL)
            fetchedData = data
            
            // Cache the metadata
            cacheManager.cacheMetadata(data)
            
            // Pre-cache thumbnail
            if let thumbnailURL = data.cover {
                cacheManager.getThumbnail(for: data.id, imageURL: thumbnailURL)
            }
            
        } catch {
            // Error handling will be shown in UI
            print("Fetch error: \(error)")
        }
        
        isLoading = false
    }
    
    func downloadVideo() async {
        guard let data = fetchedData else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        
        // If photo mode assets exist and format is images, enqueue images download
        if selectedFormat == .images, let images = data.images, !images.isEmpty {
            downloadManager.addImagesToQueue(url: inputURL, images: images)
        } else {
            downloadManager.addToQueue(url: inputURL, format: selectedFormat)
        }
        
        // Clear input and preview after adding to queue
        inputURL = ""
        fetchedData = nil
        isDownloading = false
        downloadProgress = 0.0
    }
    
    func cycleFormat() {
        switch selectedFormat {
        case .noWatermark:
            selectedFormat = .watermark
        case .watermark:
            selectedFormat = .audio
        case .audio:
            selectedFormat = .images
        case .images:
            selectedFormat = .noWatermark
        }
    }

    // Entry point for hands-free clipboard detection
    func startHandsFreeDownload(with urls: [String]) {
        guard let firstURL = urls.first else { return }
        inputURL = firstURL.trimmingCharacters(in: .whitespacesAndNewlines)
        handleAutoDownloadIfNeeded()
    }
    
    // MARK: - Private Methods
    
    private func setupClipboardMonitoring() {
        // Listen for TikTok URL detection notifications
        NotificationCenter.default.publisher(for: Notification.Name("TikTokURLDetected"))
            .sink { [weak self] notification in
                if let urls = notification.userInfo?["urls"] as? [String],
                   let firstURL = urls.first {
                    DispatchQueue.main.async {
                        self?.inputURL = firstURL
                        self?.handleAutoDownloadIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Bind clipboard monitor state
        clipboardMonitor.$hasTikTokURL
            .sink { [weak self] hasURL in
                DispatchQueue.main.async {
                    if hasURL, let url = self?.clipboardMonitor.getFirstTikTokURL() {
                        self?.inputURL = url
                        self?.handleAutoDownloadIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handleAutoDownloadIfNeeded() {
        settings = AppSettings() // refresh latest persisted settings
        guard settings.autoFetchOnPaste || settings.autoHandsFree else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.fetchVideo()
            if (self.settings.autoDownloadAfterFetch || self.settings.autoHandsFree), self.fetchedData != nil {
                await self.downloadVideo()
            }
        }
    }
    
    private func setupDownloadProgressTracking() {
        // Track download progress from DownloadManager
        downloadManager.$downloadQueue
            .sink { [weak self] queue in
                DispatchQueue.main.async {
                    let activeDownloads = queue.filter { $0.status.isDownloading }
                    self?.isDownloading = !activeDownloads.isEmpty
                    
                    if let firstActive = activeDownloads.first {
                        self?.downloadProgress = firstActive.progress
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helpers
    
    private func isValidTikTokURL(_ url: String) -> Bool {
        return URL(string: url)?.isTikTokURL == true
    }
    
    // MARK: - Touch Bar Helpers
    
    var formatDisplayText: String {
        switch selectedFormat {
        case .noWatermark: return "No WM"
        case .watermark: return "WM"
        case .audio: return "Audio"
        case .images: return "Images"
        }
    }
    
    var formatIconName: String {
        switch selectedFormat {
        case .noWatermark: return "video"
        case .watermark: return "video.badge.plus"
        case .audio: return "music.note"
        case .images: return "photo.on.rectangle"
        }
    }
}
