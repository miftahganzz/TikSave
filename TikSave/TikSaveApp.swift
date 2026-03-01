import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement

@main
struct TikSaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(DownloadViewModel.shared)
                .frame(width: 1000, height: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1000, height: 700)
    }
}

// MARK: - App Delegate for Touch Bar
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    private var touchBarController: TouchBarController?
    private var statusItem: NSStatusItem?
    private var settings = AppSettings()
    private let downloadViewModel = DownloadViewModel.shared
    private let clipboardMonitor = ClipboardMonitor.shared
    private var isQuitting = false
    private weak var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup Touch Bar for main window
        touchBarController = TouchBarController.shared
        
        if let window = NSApp.windows.first {
            configureWindow(window)
            window.touchBar = touchBarController?.makeTouchBar()
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            self?.configureWindow(window)
            window.touchBar = self?.touchBarController?.makeTouchBar()
        }
        // Listen for settings changes from UI to refresh menu
        NotificationCenter.default.addObserver(forName: .init("SettingsChangedFromUI"), object: nil, queue: .main) { [weak self] _ in
            self?.refreshMenu()
        }
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        setupStatusItem()
        applyActivationPolicy()
        setLoginItem(enabled: settings.autoLaunchOnLogin)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = roundedStatusIcon(named: "StatusIcon") ?? NSImage(systemSymbolName: "arrow.down.to.line", accessibilityDescription: "TikSave")
        statusItem?.button?.imagePosition = .imageOnly
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(statusItemClicked(_:))
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem?.menu = buildMenu()
    }

    private func roundedStatusIcon(named name: String) -> NSImage? {
        guard let img = NSImage(named: name) else { return nil }
        let size = NSSize(width: 24, height: 24)
        let target = NSImage(size: size)
        target.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.set()
        rect.fill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        path.addClip()
        img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        target.unlockFocus()
        target.isTemplate = false
        return target
    }

    private func buildMenu() -> NSMenu {
        // Reload latest settings to stay in sync with UI changes
        if let loaded = AppSettings.loadFromDefaults() {
            settings = loaded
        }
        let menu = NSMenu()
        let openAppItem = NSMenuItem(title: "Open TikSave", action: #selector(openApp), keyEquivalent: "o")
        openAppItem.target = self
        openAppItem.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
        menu.addItem(openAppItem)
        let openFolderItem = NSMenuItem(title: "Open Downloads Folder", action: #selector(openDownloadsFolder), keyEquivalent: "f")
        openFolderItem.target = self
        openFolderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(openFolderItem)
        menu.addItem(NSMenuItem.separator())
        let autoFetchItem = NSMenuItem(title: settings.autoFetchOnPaste ? "Auto-fetch clipboard ✓" : "Auto-fetch clipboard", action: #selector(toggleAutoFetch), keyEquivalent: "f")
        autoFetchItem.target = self
        menu.addItem(autoFetchItem)
        let autoDownloadItem = NSMenuItem(title: settings.autoDownloadAfterFetch ? "Auto-download clipboard ✓" : "Auto-download clipboard", action: #selector(toggleAutoDownload), keyEquivalent: "d")
        autoDownloadItem.target = self
        menu.addItem(autoDownloadItem)
        let handsFreeItem = NSMenuItem(title: settings.autoHandsFree ? "Hands-free mode ✓" : "Hands-free mode", action: #selector(toggleHandsFree), keyEquivalent: "h")
        handsFreeItem.target = self
        menu.addItem(handsFreeItem)
        let autoLaunchItem = NSMenuItem(title: settings.autoLaunchOnLogin ? "Launch at login ✓" : "Launch at login", action: #selector(toggleAutoLaunch), keyEquivalent: "l")
        autoLaunchItem.target = self
        menu.addItem(autoLaunchItem)
        let hideDockItem = NSMenuItem(title: settings.hideDockIcon ? "Hide Dock icon ✓" : "Hide Dock icon", action: #selector(toggleHideDockIcon), keyEquivalent: "k")
        hideDockItem.target = self
        menu.addItem(hideDockItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit TikSave", action: #selector(quitApp), keyEquivalent: "q")
        return menu
    }

    private func refreshMenu() {
        statusItem?.menu = buildMenu()
    }

    @objc private func openApp() {
        if settings.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        
        // Find the main window
        if let window = mainWindow ?? NSApp.windows.first {
            window.setIsVisible(true)
            window.makeKeyAndOrderFront(nil)
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            // Ensure window is ordered front and focused
            window.orderFrontRegardless()
            window.makeKey()
        } else {
            NSApp.sendAction(#selector(NSWindow.makeKeyAndOrderFront(_:)), to: nil, from: nil)
        }
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func openDownloadsFolder() {
        let folder = settings.defaultOutputFolder
        NSWorkspace.shared.open(folder)
    }
    
    @MainActor
    @objc private func toggleAutoFetch() {
        settings.autoFetchOnPaste.toggle()
        AppSettings.saveToDefaults(settings)
        clipboardMonitor.updateFromSettings()
        downloadViewModel.autoClipboardDetect = settings.autoFetchOnPaste
        NotificationCenter.default.post(name: .init("SettingsChangedFromMenu"), object: nil)
        refreshMenu()
    }
    
    @MainActor
    @objc private func toggleAutoDownload() {
        settings.autoDownloadAfterFetch.toggle()
        AppSettings.saveToDefaults(settings)
        NotificationCenter.default.post(name: .init("SettingsChangedFromMenu"), object: nil)
        refreshMenu()
    }
    
    @MainActor
    @objc private func toggleHandsFree() {
        settings.autoHandsFree.toggle()
        AppSettings.saveToDefaults(settings)
        clipboardMonitor.updateFromSettings()
        NotificationCenter.default.post(name: .init("SettingsChangedFromMenu"), object: nil)
        refreshMenu()
    }
    
    @MainActor
    @objc private func toggleAutoLaunch() {
        settings.autoLaunchOnLogin.toggle()
        AppSettings.saveToDefaults(settings)
        setLoginItem(enabled: settings.autoLaunchOnLogin)
        NotificationCenter.default.post(name: .init("SettingsChangedFromMenu"), object: nil)
        refreshMenu()
    }
    
    @MainActor
    @objc private func toggleHideDockIcon() {
        settings.hideDockIcon.toggle()
        AppSettings.saveToDefaults(settings)
        applyActivationPolicy()
        NotificationCenter.default.post(name: .init("SettingsChangedFromMenu"), object: nil)
        refreshMenu()
    }
    
    private func requestNotificationPermission() {
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if !granted {
                    print("Notification permission not granted")
                }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Refresh menu each time it's opened to ensure sync
            refreshMenu()
            statusItem?.menu = buildMenu()
            statusItem?.button?.performClick(nil)
        } else {
            openApp()
        }
    }
    
    private func applyActivationPolicy() {
        let anyVisibleWindow = NSApp.windows.contains(where: { $0.isVisible })
        let shouldHideDock = settings.hideDockIcon || !anyVisibleWindow
        let policy: NSApplication.ActivationPolicy = shouldHideDock ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }

    private func configureWindow(_ window: NSWindow) {
        window.isReleasedWhenClosed = false
        window.delegate = self
        mainWindow = window
        
        window.setContentSize(NSSize(width: 1000, height: 700))
        window.minSize = NSSize(width: 1000, height: 700)
        window.maxSize = NSSize(width: 1000, height: 700)
        window.styleMask.remove(.resizable)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isQuitting {
            return true
        }
        sender.orderOut(nil)
        applyActivationPolicy()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isQuitting = true
        return .terminateNow
    }
    
    private func setLoginItem(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item registration failed: \(error)")
            }
        }
    }
}

// MARK: - Helpers for Settings side-effects
extension AppDelegate {
    static var sharedInstance: AppDelegate? { NSApp.delegate as? AppDelegate }
    func appDelegateApplyActivationPolicy(hideDock: Bool) {
        settings.hideDockIcon = hideDock
        applyActivationPolicy()
    }
    func appDelegateApplyLoginItem(enabled: Bool) {
        settings.autoLaunchOnLogin = enabled
        setLoginItem(enabled: enabled)
    }
}
