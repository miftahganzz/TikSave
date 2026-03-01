import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var settings = AppSettings()
    @State private var isSyncingFromMenu = false
    @State private var previewName: String = ""
    @State private var showPresets = false
    @State private var previewSound: NSSound?
    @State private var toastMessage: String?
    @State private var toastVisible = false
    @State private var toastWorkItem: DispatchWorkItem?
    @State private var pendingDeletion: CustomNotificationSound?
    
    private var activeCustomSound: CustomNotificationSound? {
        settings.customNotificationSounds.first { $0.id == settings.activeCustomSoundID }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                VStack(spacing: 16) {
                    outputSection
                    performanceSection
                    automationSection
                    notificationSection
                    
                    HStack(alignment: .top, spacing: 16) {
                        organizationSection
                        startupSection
                    }
                    
                    metadataSection
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Settings")
        .onAppear {
            refreshPreview()
            refreshCacheSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cacheCleared)) { _ in
            refreshCacheSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("SettingsChangedFromMenu"))) { _ in
            guard let loaded = AppSettings.loadFromDefaults() else { return }
            isSyncingFromMenu = true
            settings = loaded
            DispatchQueue.main.async { isSyncingFromMenu = false }
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .confirmationDialog("Remove sound?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { newValue in if !newValue { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { sound in
            Button("Remove \(sound.displayName)", role: .destructive) { removeCustomSound(sound) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { sound in
            Text("\(sound.displayName) will be deleted.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 26, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                    Text("Customize your experience")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.bottom, 16)
    }
    
    private var notificationSection: some View {
        sectionCard(title: "Notifications", icon: "bell.badge.fill", iconColor: .orange) {
            VStack(alignment: .leading, spacing: 16) {
                builtInSoundPicker
                Divider()
                customSoundControls
                previewRow
            }
        }
    }

    private var builtInSoundPicker: some View {
        labeledRow(label: "Built-in Sound") {
            Picker("Sound", selection: $settings.notificationSound) {
                ForEach(NotificationSound.allCases) { sound in
                    Text(sound.displayName).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.notificationSound) { _ in
                persist()
            }
        }
    }

    private var customSoundControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom Sounds")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button(action: importCustomSound) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if settings.customNotificationSounds.isEmpty {
                Text("Belum ada suara custom. Unggah terlebih dahulu.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Toggle("Use uploaded sounds", isOn: $settings.useCustomNotificationSound)
                    .onChange(of: settings.useCustomNotificationSound) { _ in persist() }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(settings.customNotificationSounds) { sound in
                        customSoundRow(sound)
                    }
                }
            }
            Text("Accepted: \(CustomSoundManager.acceptedExtensions.joined(separator: ", ").uppercased()).")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func customSoundRow(_ sound: CustomNotificationSound) -> some View {
        let isActive = sound.id == settings.activeCustomSoundID
        return HStack(spacing: 12) {
            Button {
                setActiveCustomSound(sound)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isActive ? .accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sound.displayName)
                            .font(.system(size: 13))
                        Text(sound.fileName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button { revealCustomSound(sound) } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12))
            }
            .help("Reveal in Finder")
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button { pendingDeletion = sound } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .help("Delete sound")
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isActive ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var previewRow: some View {
        HStack {
            Button {
                previewNotificationSound()
            } label: {
                Label("Preview", systemImage: "play.circle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
            Text("Applies to hands-free detect & completion alerts.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sections
    private var outputSection: some View {
        sectionCard(title: "Output & Naming", icon: "folder.fill", iconColor: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                labeledRow(label: "Output Folder") {
                    HStack {
                        Text(settings.defaultOutputFolder.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Spacer()
                        Button(action: chooseOutputFolder) {
                            Text("Choose")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                labeledRow(label: "Filename Template") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Template", text: $settings.filenameTemplate)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: settings.filenameTemplate) { _ in
                                refreshPreview()
                                persist()
                            }
                        DisclosureGroup(isExpanded: $showPresets) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(AppSettings.filenameTemplates.keys.sorted(), id: \.self) { key in
                                    Button(key) {
                                        settings.filenameTemplate = key
                                        refreshPreview()
                                        persist()
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                }
                            }
                            .padding(.leading, 4)
                        } label: {
                            Text("Presets")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                labeledRow(label: "Preview") {
                    Text(previewName.isEmpty ? "--" : previewName)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private var performanceSection: some View {
        sectionCard(title: "Performance", icon: "gauge.high", iconColor: .green) {
            VStack(alignment: .leading, spacing: 16) {
                labeledRow(label: "Max Concurrent Downloads") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            Stepper("\(settings.downloadConcurrency)", value: $settings.downloadConcurrency, in: 1...5)
                                .frame(width: 140, alignment: .trailing)
                                .onChange(of: settings.downloadConcurrency) { _ in persist() }
                        }
                        Text("Controls how many downloads run simultaneously.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                labeledRow(label: "Retry Attempts") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            Stepper("\(settings.retryAttempts)", value: $settings.retryAttempts, in: 0...5)
                                .frame(width: 140, alignment: .trailing)
                                .onChange(of: settings.retryAttempts) { _ in persist() }
                        }
                        Text("Number of automatic retries when a download fails.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var automationSection: some View {
        sectionCard(title: "Automation", icon: "bolt.fill", iconColor: .yellow) {
            VStack(alignment: .leading, spacing: 16) {
                automationToggle(title: "Auto-fetch on paste", binding: $settings.autoFetchOnPaste, description: "Fetch metadata immediately when a TikTok URL is detected.")
                Divider()
                automationToggle(title: "Auto-download clipboard links", binding: $settings.autoDownloadAfterFetch, description: "When a TikTok link is detected from clipboard, download immediately after fetch.")
                Divider()
                automationToggle(title: "Hands-free mode", binding: $settings.autoHandsFree, description: "Fully automatic: detect, fetch, and download without pasting. Shows detect + complete notifications.")
                Divider()
                automationToggle(title: "Save audio also", binding: $settings.saveAudioAlso, description: "Download audio track alongside the video.")
                Divider()
                automationToggle(title: "Watermark default", binding: $settings.watermarkDefault, description: "Use watermark version as default format.")
                Divider()
                automationToggle(title: "Clear history on exit", binding: $settings.clearHistoryOnExit, description: "Purge download history when closing the app.")
            }
        }
    }

    private var startupSection: some View {
        sectionCard(title: "Startup & Background", icon: "power.circle.fill", iconColor: .purple) {
            VStack(alignment: .leading, spacing: 16) {
                automationToggle(title: "Launch at login", binding: $settings.autoLaunchOnLogin, description: "Start TikSave automatically when you log in.")
                Divider()
                automationToggle(title: "Hide Dock icon", binding: $settings.hideDockIcon, description: "Run TikSave in the background (menu bar only).")
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var organizationSection: some View {
        sectionCard(title: "File Organization", icon: "square.grid.2x2.fill", iconColor: .indigo) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Organize by type", isOn: $settings.organizeByType)
                    .onChange(of: settings.organizeByType) { _ in persist() }
                Divider()
                Toggle("Create subfolders", isOn: $settings.createSubfolders)
                    .onChange(of: settings.createSubfolders) { _ in persist() }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subfolder pattern")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    TextField("{type}/{author_unique_id}", text: $settings.customSubfolderPattern)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!settings.createSubfolders)
                        .opacity(settings.createSubfolders ? 1 : 0.5)
                        .onChange(of: settings.customSubfolderPattern) { _ in persist() }
                    Text("Variables: {type}, {author_unique_id}, {username}, {id}")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var metadataSection: some View {
        sectionCard(title: "Metadata & Storage", icon: "internaldrive.fill", iconColor: .pink) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Embed metadata", isOn: $settings.embedMetadata)
                    .onChange(of: settings.embedMetadata) { _ in persist() }
                Toggle("Embed thumbnail as cover art", isOn: $settings.embedThumbnailAsCover)
                    .onChange(of: settings.embedThumbnailAsCover) { _ in persist() }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thumbnail Cache Size")
                            .font(.system(size: 13))
                        Text(ByteCountFormatter.string(fromByteCount: settings.thumbnailCacheSize, countStyle: .file))
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    Spacer()
                    Button(action: clearCache) {
                        Text("Clear")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.title = "Choose Output Folder"
        panel.message = "Select where to save downloaded TikTok videos"
        if panel.runModal() == .OK {
            settings.defaultOutputFolder = panel.url ?? settings.defaultOutputFolder
            persist()
        }
    }
    
    private func clearCache() {
        let cacheManager = CacheManager.shared
        let freed = cacheManager.clearCache()
        settings.thumbnailCacheSize = 0
        persist()
        let formatted = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
        let alert = NSAlert()
        alert.messageText = "Cache Cleared"
        alert.informativeText = "Freed up \(formatted)."
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func refreshPreview() {
        let mockTitle = "Amazing Video"
        let mockAuthor = "user123"
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: now)
        let timeString = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .medium)
        var result = settings.filenameTemplate
        let replacements: [String: String] = [
            "{username}": mockAuthor,
            "{author_unique_id}": mockAuthor,
            "{author_name}": mockAuthor,
            "{id}": "123456789",
            "{type}": "video",
            "{date}": dateString,
            "{time}": timeString,
            "{index}": "01",
            "{title_sanitized}": mockTitle
        ]
        for (k, v) in replacements { result = result.replacingOccurrences(of: k, with: v) }
        previewName = result
    }
    
    private func refreshCacheSize() {
        let currentSize = CacheManager.shared.currentCacheSize()
        if settings.thumbnailCacheSize != currentSize {
            settings.thumbnailCacheSize = currentSize
            persist()
        }
    }
    
    private func previewNotificationSound() {
        let source = settings.resolvedNotificationSoundSource()
        guard let url = source.previewURL() else {
            NSSound.beep()
            return
        }
        previewSound = NSSound(contentsOf: url, byReference: true)
        previewSound?.play()
    }
    
    private func importCustomSound() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = CustomSoundManager.acceptedExtensions
        panel.title = "Choose Audio File"
        panel.message = "Select a sound file to use for TikSave notifications"
        if panel.runModal() == .OK, let selectedURL = panel.url {
            do {
                let custom = try CustomSoundManager.shared.importSound(from: selectedURL)
                settings.customNotificationSounds.append(custom)
                settings.activeCustomSoundID = custom.id
                settings.useCustomNotificationSound = true
                persist()
                showToast("Imported \(custom.displayName)")
            } catch {
                presentAlert(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }
    
    private func removeCustomSound(_ sound: CustomNotificationSound) {
        CustomSoundManager.shared.removeSound(named: sound.fileName)
        settings.customNotificationSounds.removeAll { $0.id == sound.id }
        if settings.activeCustomSoundID == sound.id {
            settings.activeCustomSoundID = settings.customNotificationSounds.first?.id
        }
        if settings.activeCustomSoundID == nil {
            settings.useCustomNotificationSound = false
        }
        persist()
        showToast("Removed \(sound.displayName)")
        pendingDeletion = nil
    }
    
    private func revealCustomSound(_ sound: CustomNotificationSound) {
        let url = CustomSoundManager.shared.url(for: sound.fileName)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func setActiveCustomSound(_ sound: CustomNotificationSound) {
        settings.activeCustomSoundID = sound.id
        settings.useCustomNotificationSound = true
        persist()
        showToast("Using \(sound.displayName)")
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        toastWorkItem?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            toastVisible = true
        }
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut) { toastVisible = false }
        }
        toastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: workItem)
    }
    
    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private func persist() {
        guard !isSyncingFromMenu else { return }
        AppSettings.saveToDefaults(settings)
    }
    
    private var toastOverlay: some View {
        Group {
            if toastVisible, let toastMessage {
                Text(toastMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toastVisible)
    }
    
    // MARK: - Helpers
    private func sectionCard<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            
            content()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private func labeledRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            content()
        }
    }
    
    private func automationToggle(title: String, binding: Binding<Bool>, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: binding)
                .font(.system(size: 13))
                .onChange(of: binding.wrappedValue) { _ in
                    guard !isSyncingFromMenu else { return }
                    persist()
                    applySideEffects(for: title)
                }
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func applySideEffects(for title: String) {
        guard let appDelegate = AppDelegate.sharedInstance else { return }
        switch title {
        case "Launch at login":
            appDelegate.appDelegateApplyLoginItem(enabled: settings.autoLaunchOnLogin)
        case "Hide Dock icon":
            appDelegate.appDelegateApplyActivationPolicy(hideDock: settings.hideDockIcon)
        default:
            break
        }
        // Notify Control Center menu to refresh its state
        NotificationCenter.default.post(name: .init("SettingsChangedFromUI"), object: nil)
    }
}

#Preview {
    SettingsView()
        .frame(width: 900, height: 700)
}
