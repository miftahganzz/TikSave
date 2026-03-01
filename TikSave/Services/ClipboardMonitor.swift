import Foundation
import AppKit
import Combine
import UserNotifications

// MARK: - Clipboard Monitor
@MainActor
class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()
    
    @Published var lastClipboardContent: String = ""
    @Published var hasTikTokURL: Bool = false
    @Published var detectedURLs: [String] = []
    @Published var autoDetectionEnabled: Bool = false
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private var cancellables = Set<AnyCancellable>()
    
    // Notification for detected TikTok URLs
    private let tikTokURLDetected = Notification.Name("TikTokURLDetected")
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startAutoDetection() {
        autoDetectionEnabled = true
        startTimer()
    }
    
    func stopAutoDetection() {
        autoDetectionEnabled = false
        stopTimer()
    }
    
    func checkClipboardNow() {
        checkForChanges()
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Initial check
        lastChangeCount = pasteboard.changeCount
        checkForChanges()
        
        // Listen for app activation to check clipboard
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkForChanges()
            }
            .store(in: &cancellables)
    }
    
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        
        lastChangeCount = pasteboard.changeCount
        
        guard let clipboardString = pasteboard.string(forType: .string) else {
            updateClipboardState(content: "")
            return
        }
        
        updateClipboardState(content: clipboardString)
        
        if autoDetectionEnabled {
            detectAndNotifyTikTokURLs(in: clipboardString)
        }
    }
    
    private func updateClipboardState(content: String) {
        lastClipboardContent = content
        
        let urls = extractTikTokURLs(from: content)
        detectedURLs = urls
        hasTikTokURL = !urls.isEmpty
    }
    
    private func extractTikTokURLs(from text: String) -> [String] {
        let patterns = [
            "https://www\\.tiktok\\.com/@[^/]+/video/\\d+",
            "https://vm\\.tiktok\\.com/[A-Za-z0-9]+",
            "https://vt\\.tiktok\\.com/[A-Za-z0-9]+",
            "https://tiktok\\.com/@[^/]+/video/\\d+"
        ]
        
        var urls: [String] = []
        
        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            for match in matches ?? [] {
                if let range = Range(match.range, in: text) {
                    let url = String(text[range])
                    if !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        
        return urls
    }
    
    private func detectAndNotifyTikTokURLs(in text: String) {
        let urls = extractTikTokURLs(from: text)
        
        guard !urls.isEmpty else { return }
        
        // Post notification for detected URLs
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: self.tikTokURLDetected,
                object: self,
                userInfo: ["urls": urls]
            )
            // If hands-free is enabled, kick off download directly
            if AppSettings().autoHandsFree {
                DownloadViewModel.shared.startHandsFreeDownload(with: urls)
            }
        }
        
        let settings = AppSettings()
        let soundSource = settings.resolvedNotificationSoundSource()
        if settings.autoHandsFree {
            let message = urls.count == 1 ? "Link detected — downloading..." : "\(urls.count) links detected — downloading..."
            showNotification(title: "Hands-free: TikTok detected", message: message, sound: soundSource)
        } else {
            let message = urls.count == 1 ? "Tap to paste and download" : "Tap to paste and download"
            showNotification(title: urls.count == 1 ? "TikTok URL Detected" : "\(urls.count) TikTok URLs Detected", message: message, sound: soundSource)
        }
    }
    
    private func showNotification(title: String, message: String, sound: NotificationSoundSource) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = sound.asUNNotificationSound()
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard let self else { return }
            if let error {
                NSLog("UN notification failed: %@", error.localizedDescription)
                self.deliverLegacyNotification(title: title, message: message, sound: sound)
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
    
    // MARK: - Helper Methods
    
    func getFirstTikTokURL() -> String? {
        return detectedURLs.first
    }
    
    func getAllTikTokURLs() -> [String] {
        return detectedURLs
    }
    
    func clearDetectedURLs() {
        detectedURLs.removeAll()
        hasTikTokURL = false
    }
    
    // MARK: - Settings Integration
    
    func updateFromSettings() {
        let settings = AppSettings()
        if settings.autoFetchOnPaste || settings.autoHandsFree {
            startAutoDetection()
        } else {
            stopAutoDetection()
        }
    }
    
    deinit {
        Task { @MainActor in
            stopTimer()
        }
        cancellables.removeAll()
    }
}

// MARK: - Notification Handler
extension NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if notification.actionButtonTitle == "Paste URL" {
            // Trigger paste action in DownloadViewModel
            DispatchQueue.main.async {
                DownloadViewModel.shared.pasteURL()
            }
        }
    }
}
