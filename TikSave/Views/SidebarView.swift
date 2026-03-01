import SwiftUI

enum SidebarTab: String, CaseIterable {
    case download = "download"
    case stalker = "stalker"
    case history = "history"
    case settings = "settings"
    case credits = "credits"
    
    var title: String {
        switch self {
        case .download: return "Download"
        case .stalker: return "TikTok Stalker"
        case .history: return "History"
        case .settings: return "Settings"
        case .credits: return "Credits"
        }
    }
    
    var iconName: String {
        switch self {
        case .download: return "arrow.down.circle"
        case .stalker: return "person.text.rectangle"
        case .history: return "clock.circle"
        case .settings: return "gear.circle"
        case .credits: return "person.crop.square"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @EnvironmentObject var downloadManager: DownloadManager
    private let sidebarWidth: CGFloat = 270
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
            Divider()
                .padding(.horizontal, 12)
                .opacity(0.35)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("MAIN")
                    sidebarRow(tab: .download)
                    sidebarRow(tab: .stalker)
                    sidebarRow(tab: .history)
                    sectionLabel("PREFERENCES")
                    sidebarRow(tab: .settings)
                    sectionLabel("ABOUT")
                    sidebarRow(tab: .credits)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            Divider()
                .padding(.horizontal, 12)
                .opacity(0.35)
            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(minWidth: sidebarWidth, idealWidth: sidebarWidth, maxWidth: sidebarWidth)
    }
}

#Preview {
    SidebarView(selectedTab: .constant(.download))
        .environmentObject(DownloadManager.shared)
        .frame(width: 270, height: 500)
}

// MARK: - Subviews
private extension SidebarView {
    var header: some View {
        Button(action: { selectedTab = .credits }) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("TikSave")
                        .font(.system(size: 16, weight: .semibold))
                    Text("TikTok Downloader")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }
    
    func sidebarRow(tab: SidebarTab) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 20, alignment: .leading)
                Text(tab.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                Spacer()
                if tab == .download {
                    let queueCount = downloadManager.downloadQueue.filter { $0.status == .waiting || $0.status == .downloading || $0.status == .fetching }.count
                    if queueCount > 0 {
                        Text("\(queueCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/miftahganzz/TikSave")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.slash.chevron.right")
                            .font(.system(size: 10))
                        Text("GitHub")
                            .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Link(destination: URL(string: "https://miftah.is-a.dev")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.system(size: 10))
                        Text("Website")
                            .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            VStack(spacing: 4) {
                Text("TikSave v1.0.0")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("macOS 13.0+")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
    }
}
