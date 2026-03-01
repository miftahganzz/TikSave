// DownloadView.swift
import SwiftUI

struct DownloadView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var apiClient = TikwmAPIClient.shared
    @StateObject private var viewModel = DownloadViewModel.shared
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedImageIndices: Set<Int> = []
    
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                inputSection
                
                if let data = viewModel.fetchedData {
                    previewSection(data: data)
                }
                
                if !downloadManager.downloadQueue.isEmpty {
                    queueSection
                }
                
                Spacer(minLength: 20)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
        }
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Paste a TikTok URL to get started")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { viewModel.toggleAutoClipboardDetect() }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.autoClipboardDetect ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                        Text("Auto-detect")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(viewModel.autoClipboardDetect ? Color.primary.opacity(0.08) : Color.clear)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(viewModel.autoClipboardDetect ? 0.15 : 0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("URL")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "link")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.leading, 10)
                        
                        TextField("https://www.tiktok.com/@user/video/...", text: $viewModel.inputURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .focused($isURLFieldFocused)
                            .onSubmit(fetchVideo)
                            .padding(.vertical, 10)
                        
                        if !viewModel.inputURL.isEmpty {
                            Button(action: { viewModel.inputURL = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                    
                    Button(action: viewModel.pasteURL) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button(action: fetchVideo) {
                        if apiClient.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.inputURL.isEmpty || apiClient.isLoading)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Format")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    ForEach(DownloadFormat.allCases, id: \.self) { format in
                        Button(action: { viewModel.selectedFormat = format }) {
                            VStack(spacing: 6) {
                                Image(systemName: formatIcon(for: format))
                                    .font(.system(size: 18))
                                    .foregroundColor(viewModel.selectedFormat == format ? .primary : .secondary)
                                
                                Text(format.shortName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(viewModel.selectedFormat == format ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(viewModel.selectedFormat == format ? Color.primary.opacity(0.08) : Color(NSColor.controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(viewModel.selectedFormat == format ? 0.15 : 0.06), lineWidth: viewModel.selectedFormat == format ? 1 : 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private func previewSection(data: TikwmData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Preview")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.selectedFormat == .images, let images = data.images, !images.isEmpty {
                    Button(action: downloadSelectedImages) {
                        Text("Download \(selectedImageIndices.count)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(selectedImageIndices.isEmpty)
                }
            }
            
            if viewModel.selectedFormat == .images, let images = data.images, !images.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 160))], spacing: 16) {
                    ForEach(Array(images.enumerated()), id: \.element) { index, imageURL in
                        ImageSelectionCard(
                            imageURL: imageURL,
                            index: index,
                            isSelected: selectedImageIndices.contains(index),
                            onTap: { toggleImageSelection(index) }
                        )
                    }
                }
            } else {
                VideoPreviewCard(data: data, format: viewModel.selectedFormat) { format in
                    downloadVideo(data: data, format: format)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Queue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                let stats = downloadManager.downloadStats
                HStack(spacing: 10) {
                    Label("\(stats.active)", systemImage: "arrow.down.circle")
                    Label("\(stats.completed)", systemImage: "checkmark.circle")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            
            if downloadManager.downloadQueue.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("No downloads in queue")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(downloadManager.downloadQueue) { item in
                        DownloadQueueRow(item: item) { action in
                            handleQueueAction(action, for: item)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private func formatIcon(for format: DownloadFormat) -> String {
        switch format {
        case .noWatermark: return "video.fill"
        case .watermark: return "video.badge.plus"
        case .audio: return "music.note"
        case .images: return "photo.on.rectangle.angled"
        }
    }
    
    private func toggleImageSelection(_ index: Int) {
        if selectedImageIndices.contains(index) {
            selectedImageIndices.remove(index)
        } else {
            selectedImageIndices.insert(index)
        }
    }
    
    private func downloadSelectedImages() {
        guard let data = viewModel.fetchedData, let images = data.images else { return }
        
        let selectedImages = selectedImageIndices.sorted().map { images[$0] }
        downloadManager.addImagesToQueue(url: viewModel.inputURL, images: selectedImages)
        
        viewModel.inputURL = ""
        viewModel.fetchedData = nil
        selectedImageIndices.removeAll()
        isURLFieldFocused = false
    }
    
    private func fetchVideo() {
        guard !viewModel.inputURL.isEmpty else { return }
        
        guard apiClient.validateTikTokURLFormat(viewModel.inputURL) else {
            errorMessage = "Please enter a valid TikTok URL"
            showingError = true
            return
        }
        
        Task {
            do {
                let data = try await apiClient.fetchVideoMetadata(from: viewModel.inputURL)
                await MainActor.run {
                    viewModel.fetchedData = data
                    selectedImageIndices.removeAll()
                    errorMessage = ""
                    showingError = false
                }
            } catch {
                await MainActor.run {
                    if let apiError = error as? TikwmAPIError {
                        errorMessage = apiError.localizedDescription
                    } else {
                        errorMessage = "An unexpected error occurred"
                    }
                    showingError = true
                    viewModel.fetchedData = nil
                }
            }
        }
    }
    
    private func downloadVideo(data: TikwmData, format: DownloadFormat) {
        downloadManager.addToQueue(url: viewModel.inputURL, format: format)
        viewModel.inputURL = ""
        viewModel.fetchedData = nil
        isURLFieldFocused = false
    }
    
    private func handleQueueAction(_ action: DownloadQueueAction, for item: DownloadItem) {
        switch action {
        case .pause: downloadManager.pauseDownload(for: item)
        case .resume: downloadManager.resumeDownload(for: item)
        case .cancel: downloadManager.cancelDownload(for: item)
        case .retry: downloadManager.retryDownload(for: item)
        case .reveal:
            if let fileURL = item.localFileURL {
                NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: "")
            }
        }
    }
}

struct ImageSelectionCard: View {
    let imageURL: String
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: NSImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = thumbnailImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 140, maxHeight: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 140)
                        .overlay {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                }
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? .blue : .white.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .blur(radius: 2)
                            )
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.primary.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .task {
            isLoading = true
            if let url = URL(string: imageURL) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    thumbnailImage = NSImage(data: data)
                } catch {
                    print("Failed to load thumbnail: \(error)")
                }
            }
            isLoading = false
        }
    }
}

enum DownloadQueueAction {
    case pause
    case resume
    case cancel
    case retry
    case reveal
}

extension DownloadFormat {
    var shortName: String {
        switch self {
        case .noWatermark: return "No WM"
        case .watermark: return "WM"
        case .audio: return "Audio"
        case .images: return "Images"
        }
    }
}