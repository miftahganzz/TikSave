import SwiftUI

struct DownloadHistoryView: View {
    @StateObject private var cacheManager = CacheManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showingClearAlert = false
    
    var filteredHistory: [DownloadHistoryItem] {
        var items = cacheManager.downloadHistory
        
        // Filter by search text
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by type
        switch selectedFilter {
        case .all:
            break
        case .video:
            items = items.filter { item in
                item.downloadFormat == .noWatermark || item.downloadFormat == .watermark
            }
        case .audio:
            items = items.filter { $0.downloadFormat == .audio }
        case .recent:
            let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            items = items.filter { $0.downloadDate >= threeDaysAgo }
        }
        
        return items.sorted { $0.downloadDate > $1.downloadDate }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with search and filter
                headerSection
                
                // Content
                if filteredHistory.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: searchText.isEmpty ? "No Download History" : "No Results",
                        description: searchText.isEmpty ? 
                            "Your downloaded videos will appear here" : 
                            "Try adjusting your search or filters"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredHistory) { item in
                            HistoryItemRow(item: item)
                        }
                    }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("History")
        .alert("Clear History", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                cacheManager.clearDownloadHistory()
            }
        } message: {
            Text("Are you sure you want to clear all download history? This action cannot be undone.")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("\(filteredHistory.count) of \(cacheManager.downloadHistory.count) downloads")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Search and Filter
            VStack(alignment: .leading, spacing: 12) {
                Text("Search & Filter")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 10) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        TextField("Search downloads...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                    
                    // Filter picker
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 13))
                    .frame(width: 100)
                    
                    // Clear button
                    Button(action: { showingClearAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(cacheManager.downloadHistory.isEmpty)
                    .help("Clear History")
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
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: DownloadHistoryItem
    @StateObject private var cacheManager = CacheManager.shared
    @State private var thumbnailImage: Image?
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
            
            // Info
            VStack(alignment: .leading, spacing: 5) {
                // Title
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                
                // Author and format
                HStack(spacing: 6) {
                    Text("@\(item.author)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Text(item.downloadFormat.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Date and size
                HStack(spacing: 6) {
                    Text(item.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if item.fileSize > 0 {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(item.formattedFileSize)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status and actions
            HStack(spacing: 8) {
                // File status
                Image(systemName: item.fileExists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(item.fileExists ? .secondary : .secondary.opacity(0.5))
                    .help(item.fileExists ? "File exists" : "File not found")
                
                // Reveal button
                if item.fileExists, let filePath = item.filePath {
                    Button(action: {
                        NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Show in Finder")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
        .onAppear {
            loadThumbnail()
        }
    }
    
    // MARK: - Thumbnail View
    
    private var thumbnailView: some View {
        Group {
            if let thumbnailImage = thumbnailImage {
                thumbnailImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        Image(systemName: item.downloadFormat == .audio ? "music.note" : "video.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadThumbnail() {
        if let cachedImage = cacheManager.getThumbnail(for: item.videoID) {
            thumbnailImage = Image(nsImage: cachedImage)
        } else if let thumbnailURL = item.thumbnailURL {
            cacheManager.getThumbnail(for: item.videoID, imageURL: thumbnailURL)
            
            // Try again after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let cachedImage = cacheManager.getThumbnail(for: item.videoID) {
                    thumbnailImage = Image(nsImage: cachedImage)
                }
            }
        }
    }
}

// MARK: - History Filter

enum HistoryFilter: CaseIterable {
    case all
    case video
    case audio
    case recent
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .video: return "Video"
        case .audio: return "Audio"
        case .recent: return "Recent"
        }
    }
}

#Preview {
    DownloadHistoryView()
        .frame(width: 800, height: 600)
}
