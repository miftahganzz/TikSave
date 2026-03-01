// VideoPreviewCard.swift
import SwiftUI

struct VideoPreviewCard: View {
    let data: TikwmData
    let format: DownloadFormat
    let onDownload: (DownloadFormat) -> Void
    
    @State private var thumbnailImage: Image?
    @State private var isLoadingThumbnail = true
    @State private var isHovering = false
    @State private var isDownloadHovering = false
    @StateObject private var cacheManager = CacheManager.shared
    
    var body: some View {
        HStack(spacing: 24) {
            // Premium Thumbnail Container
            ZStack {
                // Background Glow
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 20)
                    .opacity(isHovering ? 0.8 : 0.4)
                
                thumbnailView
                    .frame(width: 160, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: .black.opacity(0.2),
                        radius: 20,
                        x: 0,
                        y: 8
                    )
            }
            .frame(width: 160)
            
            // Content Section
            VStack(alignment: .leading, spacing: 16) {
                // Title and Author
                VStack(alignment: .leading, spacing: 12) {
                    Text(data.title ?? "Untitled Video")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        // Author Avatar
                        Group {
                            if let avatarURL = data.author?.avatar, let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.2))
                                }
                            } else {
                                Circle().fill(Color.gray.opacity(0.2))
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.5), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.author?.nickname ?? "Unknown Creator")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            
                            Text("@\(data.author?.uniqueId ?? "unknown")")
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Stats Row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        StatPill(icon: "play.circle.fill", count: data.playCount ?? 0, color: .blue)
                        StatPill(icon: "heart.circle.fill", count: data.diggCount ?? 0, color: .red)
                        StatPill(icon: "bubble.right.circle.fill", count: data.commentCount ?? 0, color: .green)
                        StatPill(icon: "arrowshape.turn.up.right.circle.fill", count: data.shareCount ?? 0, color: .orange)
                    }
                }
                
                // Metadata Row
                HStack(spacing: 20) {
                    Label(
                        formatDuration(data.duration ?? 0),
                        systemImage: "clock.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if let size = data.size {
                        Label(
                            ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file),
                            systemImage: "externaldrive.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if let playCount = data.playCount {
                        Label(
                            playCount.formattedCount,
                            systemImage: "eye.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                // Music Info
                if let musicInfo = data.musicInfo, let title = musicInfo.title {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.caption)
                            .foregroundColor(.purple)
                        
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if let author = musicInfo.author {
                            Text("• \(author)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Download Button
                HStack {
                    Button(action: { onDownload(format) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text("Download")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            
                            Text(format.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Group {
                                if isDownloadHovering {
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    LinearGradient(
                                        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                }
                            }
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                            color: .blue.opacity(isDownloadHovering ? 0.5 : 0.3),
                            radius: isDownloadHovering ? 15 : 10,
                            x: 0,
                            y: isDownloadHovering ? 8 : 5
                        )
                        .scaleEffect(isDownloadHovering ? 1.02 : 1)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isDownloadHovering = hovering
                        }
                    }
                    
                    if let images = data.images, !images.isEmpty {
                        Button(action: { onDownload(.images) }) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        .help("Download Images")
                    }
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(NSColor.controlBackgroundColor))
                
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
            
            if isLoadingThumbnail {
                ProgressView()
                    .controlSize(.large)
                    .scaleEffect(0.8)
            } else if let thumbnailImage = thumbnailImage {
                thumbnailImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "video.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            // Duration Badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Label(
                        formatDuration(data.duration ?? 0),
                        systemImage: "clock.fill"
                    )
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        .ultraThinMaterial,
                        in: Capsule()
                    )
                    .foregroundColor(.white)
                }
                .padding(10)
            }
            
            // Play Button Overlay on Hover
            if isHovering {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(radius: 10)
                    )
            }
        }
        .onAppear { loadThumbnail() }
    }
    
    private func loadThumbnail() {
        if let cachedImage = cacheManager.getThumbnail(for: data.id) {
            thumbnailImage = Image(nsImage: cachedImage)
            isLoadingThumbnail = false
            return
        }
        
        guard let coverURL = URL(string: data.cover ?? data.originCover ?? "") else {
            isLoadingThumbnail = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: coverURL)
                if let nsImage = NSImage(data: data) {
                    await MainActor.run {
                        thumbnailImage = Image(nsImage: nsImage)
                        isLoadingThumbnail = false
                    }
                    cacheManager.cacheThumbnail(nsImage, for: self.data.id)
                }
            } catch {
                await MainActor.run {
                    isLoadingThumbnail = false
                }
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

}

#Preview {
    VideoPreviewCard(
        data: TikwmData.mock,
        format: .noWatermark
    ) { format in
        print("Download: \(format)")
    }
    .padding()
}