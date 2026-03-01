import AppKit
import Combine

// MARK: - Touch Bar Controller
@MainActor
class TouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = TouchBarController()
    
    enum Mode {
        case download
        case activeDownload(progress: Double, speedText: String?, etaText: String?)
        case history(hasSelection: Bool)
        case settings
    }
    
    // Identifiers
    private enum Item: String {
        case pasteURL
        case fetch
        case download
        case format
        case openFolder
        case embedMeta
        case organize
        case watermarkToggle
        case progress
        case pause
        case cancel
        case historySearch
        case historyReveal
        case historyRedownload
        case historyDelete
        case settingsStepper
        case settingsAutoFetch
        case settingsClearCache
        case flexibleSpace
    }
    
    // State
    private var touchBar: NSTouchBar?
    private var mode: Mode = .download
    private var cancellables = Set<AnyCancellable>()
    private let downloadViewModel = DownloadViewModel.shared
    private let downloadManager = DownloadManager.shared
    private var settings = AppSettings()
    private var historyHasSelection = false
    
    // MARK: - Public API
    func makeTouchBar() -> NSTouchBar? {
        guard NSApp.responds(to: #selector(getter: NSApp.touchBar)) else { return nil }
        buildObservers()
        return buildTouchBar(for: mode)
    }
    
    func updateMode(tab: SidebarTab) {
        switch tab {
        case .download: mode = downloadViewModel.isDownloading ? .activeDownload(progress: downloadViewModel.downloadProgress, speedText: nil, etaText: nil) : .download
        case .stalker: mode = .download
        case .history: mode = .history(hasSelection: historyHasSelection)
        case .settings: mode = .settings
        case .credits: mode = .history(hasSelection: historyHasSelection)
        }
        refresh()
    }
    
    func updateHistorySelection(hasSelection: Bool) {
        historyHasSelection = hasSelection
        if case .history = mode {
            mode = .history(hasSelection: hasSelection)
            refresh()
        }
    }
    
    func updateActiveDownload(progress: Double, speedText: String?, etaText: String?) {
        mode = .activeDownload(progress: progress, speedText: speedText, etaText: etaText)
        refresh()
    }
    
    // MARK: - Build / Refresh
    private func refresh() {
        let bar = buildTouchBar(for: mode)
        touchBar = bar
        if NSApp.responds(to: #selector(getter: NSApplication.touchBar)) {
            NSApp.touchBar = bar
        }
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            window.touchBar = bar
        }
    }
    
    private func buildTouchBar(for mode: Mode) -> NSTouchBar {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.tiksave.touchbar")
        bar.defaultItemIdentifiers = identifiers(for: mode)
        touchBar = bar
        return bar
    }
    
    private func identifiers(for mode: Mode) -> [NSTouchBarItem.Identifier] {
        switch mode {
        case .download:
            return [.init(Item.pasteURL.rawValue), .init(Item.fetch.rawValue), .init(Item.format.rawValue), .init(Item.download.rawValue), .init(Item.openFolder.rawValue), .flexibleSpace, .init(Item.embedMeta.rawValue), .init(Item.organize.rawValue), .init(Item.watermarkToggle.rawValue)]
        case .activeDownload:
            return [.init(Item.openFolder.rawValue), .init(Item.progress.rawValue), .flexibleSpace, .init(Item.pause.rawValue), .init(Item.cancel.rawValue)]
        case .history(let hasSelection):
            var items: [NSTouchBarItem.Identifier] = [.init(Item.historySearch.rawValue)]
            if hasSelection {
                items += [.init(Item.historyReveal.rawValue), .init(Item.historyRedownload.rawValue), .init(Item.historyDelete.rawValue)]
            }
            return items
        case .settings:
            return [.init(Item.settingsStepper.rawValue), .flexibleSpace, .init(Item.settingsAutoFetch.rawValue), .init(Item.settingsClearCache.rawValue)]
        }
    }
    
    // MARK: - NSTouchBarDelegate
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier.rawValue {
        case Item.pasteURL.rawValue: return makeButton(id: .pasteURL, symbol: "doc.on.clipboard", color: .controlAccentColor, action: #selector(pasteURL))
        case Item.fetch.rawValue: return makeButton(id: .fetch, symbol: "magnifyingglass", color: .systemBlue, action: #selector(fetch))
        case Item.format.rawValue: return makeFormatControl()
        case Item.download.rawValue: return makeDownloadButton()
        case Item.openFolder.rawValue: return makeButton(id: .openFolder, symbol: "folder.fill", color: .systemGray, action: #selector(openFolder))
        case Item.embedMeta.rawValue: return makeToggle(id: .embedMeta, symbol: "tag.fill", state: settings.embedMetadata, handler: { [weak self] new in self?.settings.embedMetadata = new; self?.persist() })
        case Item.organize.rawValue: return makeToggle(id: .organize, symbol: "folder.badge.plus", state: settings.organizeByType, handler: { [weak self] new in self?.settings.organizeByType = new; self?.persist() })
        case Item.watermarkToggle.rawValue: return makeToggle(id: .watermarkToggle, symbol: "drop.fill", state: settings.watermarkDefault, handler: { [weak self] new in self?.settings.watermarkDefault = new; self?.persist() })
        case Item.progress.rawValue: return makeProgress()
        case Item.pause.rawValue: return makeButton(id: .pause, symbol: "pause.fill", color: .systemGray, action: #selector(pauseDownload))
        case Item.cancel.rawValue: return makeButton(id: .cancel, symbol: "xmark.circle.fill", color: .systemRed, action: #selector(cancelDownload))
        case Item.historySearch.rawValue: return makeButton(id: .historySearch, symbol: "magnifyingglass.circle.fill", color: .controlAccentColor, action: #selector(focusHistorySearch))
        case Item.historyReveal.rawValue: return makeButton(id: .historyReveal, symbol: "eye.fill", color: .systemGray, action: #selector(revealHistory))
        case Item.historyRedownload.rawValue: return makeButton(id: .historyRedownload, symbol: "arrow.clockwise.circle.fill", color: .systemBlue, action: #selector(redownloadHistory))
        case Item.historyDelete.rawValue: return makeButton(id: .historyDelete, symbol: "trash.fill", color: .systemRed, action: #selector(deleteHistory))
        case Item.settingsStepper.rawValue: return makeStepper()
        case Item.settingsAutoFetch.rawValue: return makeToggle(id: .settingsAutoFetch, symbol: "bolt.fill", state: settings.autoFetchOnPaste, handler: { [weak self] new in self?.settings.autoFetchOnPaste = new; self?.persist() })
        case Item.settingsClearCache.rawValue: return makeButton(id: .settingsClearCache, symbol: "arrow.triangle.2.circlepath", action: #selector(clearCache))
        case Item.flexibleSpace.rawValue: return NSTouchBarItem(identifier: .flexibleSpace)
        default: return nil
        }
    }
    
    // MARK: - Item Builders
    private func makeButton(id: Item, symbol: String, color: NSColor? = nil, action: Selector) -> NSButtonTouchBarItem {
        let item = NSButtonTouchBarItem(identifier: .init(id.rawValue), title: "", image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(), target: self, action: action)
        item.bezelColor = color?.withAlphaComponent(0.8)
        return item
    }
    
    private func makeToggle(id: Item, symbol: String, state: Bool, handler: @escaping (Bool) -> Void) -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .init(id.rawValue))
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(), target: self, action: #selector(toggleButtonTapped(_:)))
        button.bezelStyle = .texturedRounded
        button.setButtonType(.toggle)
        button.state = state ? .on : .off
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.tag = toggleHandlers.count
        toggleHandlers.append(handler)
        item.view = button
        return item
    }
    
    private func makeFormatControl() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .init(Item.format.rawValue))
        let control = NSSegmentedControl(images: [
            NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil) ?? NSImage(),
            NSImage(systemSymbolName: "film", accessibilityDescription: nil) ?? NSImage(),
            NSImage(systemSymbolName: "music.note", accessibilityDescription: nil) ?? NSImage(),
            NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: nil) ?? NSImage()
        ], trackingMode: .selectOne, target: self, action: #selector(formatChanged(_:)))
        control.segmentStyle = .separated
        control.selectedSegment = 0
        item.view = control
        downloadViewModel.$selectedFormat
            .sink { [weak control] format in
                control?.selectedSegment = {
                    switch format {
                    case .noWatermark: return 0
                    case .watermark: return 1
                    case .audio: return 2
                    case .images: return 3
                    }
                }()
            }
            .store(in: &cancellables)
        return item
    }
    
    private func makeDownloadButton() -> NSButtonTouchBarItem {
        let item = NSButtonTouchBarItem(identifier: .init(Item.download.rawValue), title: "", image: NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil) ?? NSImage(), target: self, action: #selector(download))
        item.bezelColor = NSColor.controlAccentColor
        item.isEnabled = false
        downloadViewModel.canDownload
            .sink { [weak item] can in item?.isEnabled = can }
            .store(in: &cancellables)
        downloadViewModel.$isDownloading
            .sink { [weak item] running in
                let symbol = running ? "pause.circle.fill" : "arrow.down.circle.fill"
                item?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                item?.bezelColor = running ? NSColor.systemOrange : NSColor.controlAccentColor
            }
            .store(in: &cancellables)
        return item
    }
    
    private func makeProgress() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .init(Item.progress.rawValue))
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        let bar = NSProgressIndicator()
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.controlSize = .regular
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 12)
        stack.addArrangedSubview(bar)
        stack.addArrangedSubview(label)
        item.view = stack
        downloadViewModel.$downloadProgress
            .sink { [weak bar, weak label] progress in
                bar?.doubleValue = progress
                let percent = Int(progress * 100)
                label?.stringValue = "\(percent)%"
            }
            .store(in: &cancellables)
        return item
    }
    
    private func makeStepper() -> NSCustomTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: .init(Item.settingsStepper.rawValue))
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        let minus = NSButton(image: NSImage(systemSymbolName: "minus.circle.fill", accessibilityDescription: nil) ?? NSImage(), target: self, action: #selector(decreaseConcurrency))
        let label = NSTextField(labelWithString: "\(settings.downloadConcurrency)")
        label.font = NSFont.systemFont(ofSize: 12)
        label.alignment = .center
        let plus = NSButton(image: NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: nil) ?? NSImage(), target: self, action: #selector(increaseConcurrency))
        stack.addArrangedSubview(minus)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(plus)
        stepperLabel = label
        item.view = stack
        return item
    }
    
    // MARK: - Actions
    @objc private func pasteURL() { downloadViewModel.pasteURL() }
    @objc private func fetch() { Task { await downloadViewModel.fetchVideo() } }
    @objc private func download() { Task { await downloadViewModel.downloadVideo() } }
    @objc private func openFolder() { NSWorkspace.shared.activateFileViewerSelecting([settings.defaultOutputFolder]) }
    @objc private func pauseDownload() { /* Implement pause in DownloadManager if available */ }
    @objc private func cancelDownload() { downloadManager.cancelAll() }
    @objc private func focusHistorySearch() { NotificationCenter.default.post(name: .init("HistoryFocusSearch"), object: nil) }
    @objc private func revealHistory() { NotificationCenter.default.post(name: .init("HistoryReveal"), object: nil) }
    @objc private func redownloadHistory() { NotificationCenter.default.post(name: .init("HistoryRedownload"), object: nil) }
    @objc private func deleteHistory() { NotificationCenter.default.post(name: .init("HistoryDelete"), object: nil) }
    @objc private func increaseConcurrency() { settings.downloadConcurrency = min(settings.downloadConcurrency + 1, 5); persist(); updateStepperLabel() }
    @objc private func decreaseConcurrency() { settings.downloadConcurrency = max(settings.downloadConcurrency - 1, 1); persist(); updateStepperLabel() }
    @objc private func clearCache() { NotificationCenter.default.post(name: .clearCacheRequested, object: nil) }
    @objc private func formatChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: downloadViewModel.selectedFormat = .noWatermark
        case 1: downloadViewModel.selectedFormat = .watermark
        case 2: downloadViewModel.selectedFormat = .audio
        case 3: downloadViewModel.selectedFormat = .images
        default: break
        }
    }
    @objc private func toggleButtonTapped(_ sender: NSButton) {
        let handler = toggleHandlers[safe: sender.tag]
        handler?(sender.state == .on)
    }
    
    // MARK: - Helpers
    private var toggleHandlers: [(Bool) -> Void] = []
    private weak var stepperLabel: NSTextField?
    
    private func persist() { AppSettings.saveToDefaults(settings) }
    private func updateStepperLabel() { stepperLabel?.stringValue = "\(settings.downloadConcurrency)" }
    
    private func buildObservers() {
        downloadViewModel.$isDownloading
            .sink { [weak self] running in
                guard let self else { return }
                switch self.mode {
                case .download, .activeDownload:
                    self.mode = running ? .activeDownload(progress: self.downloadViewModel.downloadProgress, speedText: nil, etaText: nil) : .download
                    self.refresh()
                default: break
                }
            }
            .store(in: &cancellables)
        downloadViewModel.$downloadProgress
            .sink { [weak self] progress in
                guard let self else { return }
                if case .activeDownload = self.mode {
                    self.mode = .activeDownload(progress: progress, speedText: nil, etaText: nil)
                    self.refresh()
                }
            }
            .store(in: &cancellables)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
