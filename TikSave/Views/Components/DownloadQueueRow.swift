// DownloadQueueRow.swift
import SwiftUI

struct DownloadQueueRow: View {
    let item: DownloadItem
    let onAction: (DownloadQueueAction) -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    @State private var animatedProgress: Double = 0.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Premium Status Icon with Animation
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 36, height: 36)
                    .shadow(color: statusColor.opacity(0.2), radius: 4, x: 0, y: 2)
                
                statusIcon
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(statusColor)
                    .symbolRenderingMode(.hierarchical)
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 8) {
                // Title and Metadata Row
                HStack(alignment: .center, spacing: 12) {
                    if let data = item.tikwmData {
                        Text(data.title ?? "Untitled Video")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text(item.sourceURL)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let author = item.tikwmData?.author?.nickname {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("@\(author)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                // Progress Section
                if item.status == .downloading {
                    VStack(alignment: .leading, spacing: 6) {
                        // Custom Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(animatedProgress), height: 6)
                                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .frame(height: 6)
                        
                        // Progress Details
                        HStack(spacing: 16) {
                            Label(
                                "\(Int(animatedProgress * 100))%",
                                systemImage: "percent"
                            )
                            .font(.caption2)
                            .foregroundColor(.blue)
                            
                            if item.speed > 0 {
                                Label(
                                    ByteCountFormatter.string(fromByteCount: Int64(item.speed), countStyle: .file) + "/s",
                                    systemImage: "speedometer"
                                )
                                .font(.caption2)
                                .foregroundColor(.purple)
                            }
                            
                            if let timeRemaining = item.timeRemaining, timeRemaining > 0 {
                                Label(
                                    formatTimeRemaining(timeRemaining),
                                    systemImage: "timer"
                                )
                                .font(.caption2)
                                .foregroundColor(.orange)
                            }
                            
                            if let totalBytes = item.totalBytes {
                                Label(
                                    ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file),
                                    systemImage: "externaldrive"
                                )
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    // Status Message
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(item.status.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if item.status == .failed, let errorMessage = item.errorMessage {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                        
                        if let completedAt = item.completedAt {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(completedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 10) {
                if item.status.canPause {
                    actionButton(icon: "pause.circle.fill", color: .orange, action: .pause, help: "Pause")
                }
                
                if item.status.canResume {
                    actionButton(icon: "play.circle.fill", color: .green, action: .resume, help: "Resume")
                }
                
                if item.status.canCancel {
                    actionButton(icon: "xmark.circle.fill", color: .red, action: .cancel, help: "Cancel")
                }
                
                if item.status.canRetry {
                    actionButton(icon: "arrow.clockwise.circle.fill", color: .blue, action: .retry, help: "Retry")
                }
                
                if item.status.isCompleted, item.localFileURL != nil {
                    actionButton(icon: "folder.circle.fill", color: .purple, action: .reveal, help: "Show in Finder")
                }
            }
            .padding(.leading, 8)
            .opacity(isHovering ? 1 : 0.7)
            .scaleEffect(isHovering ? 1 : 0.98)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(
                    color: .black.opacity(isHovering ? 0.12 : 0.06),
                    radius: isHovering ? 12 : 8,
                    x: 0,
                    y: isHovering ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.99 : 1)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onLongPressGesture(minimumDuration: 0.1) { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        } perform: {}
        .onChange(of: item.progress) { newValue in
            let clamped = min(max(newValue, 0), 1)
            withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
                animatedProgress = clamped
            }
        }
        .onAppear {
            animatedProgress = min(max(item.progress, 0), 1)
        }
    }
    
    private func actionButton(icon: String, color: Color, action: DownloadQueueAction, help: String) -> some View {
        Button(action: { onAction(action) }) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(color)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
    
    private var statusIcon: some View {
        Group {
            switch item.status {
            case .waiting:
                Image(systemName: "clock")
            case .fetching:
                ProgressView()
                    .scaleEffect(0.7)
            case .ready:
                Image(systemName: "checkmark")
            case .downloading:
                Image(systemName: "arrow.down")
            case .paused:
                Image(systemName: "pause")
            case .completed:
                Image(systemName: "checkmark")
            case .failed:
                Image(systemName: "exclamationmark")
            case .cancelled:
                Image(systemName: "xmark")
            }
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .waiting: return .orange
        case .fetching: return .blue
        case .ready: return .blue
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }
    
    private var statusBackgroundColor: Color {
        statusColor.opacity(0.15)
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: timeInterval) ?? ""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 12) {
        DownloadQueueRow(
            item: {
                var item = DownloadItem(sourceURL: "https://tiktok.com/@user/video/123456789")
                item.status = .downloading
                item.progress = 0.65
                item.downloadedBytes = 6500000
                item.totalBytes = 10000000
                item.speed = 1500000
                item.tikwmData = TikwmData.mock
                return item
            }()
        ) { action in }
        
        DownloadQueueRow(
            item: {
                var item = DownloadItem(sourceURL: "https://tiktok.com/@user/video/987654321")
                item.status = .completed
                item.progress = 1.0
                item.completedAt = Date()
                item.tikwmData = TikwmData.mock
                return item
            }()
        ) { action in }
        
        DownloadQueueRow(
            item: {
                var item = DownloadItem(sourceURL: "https://tiktok.com/@user/video/456789123")
                item.status = .failed
                item.errorMessage = "Network timeout"
                item.tikwmData = TikwmData.mock
                return item
            }()
        ) { action in }
    }
    .padding()
}