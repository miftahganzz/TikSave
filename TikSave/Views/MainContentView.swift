import SwiftUI

struct MainContentView: View {
    @State private var selectedTab: SidebarTab = .download
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var apiClient = TikwmAPIClient.shared
    @StateObject private var cacheManager = CacheManager.shared

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .navigationTitle("TikSave")
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                Group {
                    switch selectedTab {
                    case .download:
                        DownloadView()
                            .environmentObject(apiClient)
                    case .stalker:
                        TikTokStalkerView()
                    case .history:
                        DownloadHistoryView()
                    case .credits:
                        CreditsView()
                    case .settings:
                        SettingsView()
                    }
                }
                .navigationTitle(selectedTab.title)
            }
            .id(selectedTab)
        }
        .environmentObject(downloadManager)
        .environmentObject(apiClient)
        .environmentObject(cacheManager)
        .onChange(of: selectedTab) { newValue in
            TouchBarController.shared.updateMode(tab: newValue)
        }
        .onAppear {
            TouchBarController.shared.updateMode(tab: selectedTab)
            if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
                window.touchBar = TouchBarController.shared.makeTouchBar()
            }
        }
    }
}

struct CreditsView: View {
    private let githubProfileURL = URL(string: "https://github.com/miftahganzz")!
    private let websiteURL = URL(string: "https://miftah.is-a.dev")!
    private let reportIssueURL = URL(string: "https://github.com/miftahganzz/TikSave/issues/new")!
    private let githubAvatarURL = URL(string: "https://github.com/miftahganzz.png")!

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Credits")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Built with passion for Mac users")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                // Developer Card
                DeveloperCardView(
                    name: "miftahganzz",
                    bio: "Full-stack developer passionate about creating tools that simplify everyday tasks. TikSave started as a side project and evolved into a focused macOS application.",
                    githubURL: githubProfileURL,
                    websiteURL: websiteURL,
                    avatarURL: githubAvatarURL
                )
                
                // About TikSave
                InfoCardView(
                    title: "About TikSave",
                    content: "A focused, distraction-free TikTok downloader built exclusively for macOS. Designed for users who value speed, clarity, and control over their downloads."
                )
                
                // Features
                InfoCardView(
                    title: "Key Features",
                    content: "• Download videos without watermark\n• Extract audio to MP3 format\n• Batch download with queue system\n• Custom filename templates\n• Download history tracking\n• Local processing for privacy"
                )
                
                // Tech Stack
                InfoCardView(
                    title: "Technology",
                    content: "Built with Swift and SwiftUI as a native macOS application optimized for Apple Silicon. Uses Tikwm API for video data fetching."
                )
                
                // Support
                InfoCardView(
                    title: "Support & Feedback",
                    content: "Found a bug or have a suggestion? Feel free to open an issue on GitHub or reach out through the website."
                )
                
                // Legal
                InfoCardView(
                    title: "Legal",
                    content: "By using TikSave, you agree to our Terms of Service and Privacy Policy. All data is processed locally on your device. Always respect content creators' rights and download content responsibly."
                )
                
                // Footer Buttons
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Link(destination: githubProfileURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left.slash.chevron.right")
                                    .font(.system(size: 12))
                                Text("GitHub")
                                    .font(.system(size: 13))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Link(destination: websiteURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                Text("Website")
                                    .font(.system(size: 13))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Link(destination: reportIssueURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.bubble")
                                    .font(.system(size: 12))
                                Text("Report")
                                    .font(.system(size: 13))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    NavigationLink(destination: PrivacyAndTermsView()) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12))
                            Text("Privacy & Terms")
                                .font(.system(size: 13))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Text("v1.0.0 • macOS 13.0+")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Credits")
    }
}

private struct InfoCardView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(content)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct DeveloperCardView: View {
    let name: String
    let bio: String
    let githubURL: URL
    let websiteURL: URL
    let avatarURL: URL
    
    @State private var avatarImage: NSImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Avatar from GitHub
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 56, height: 56)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                    case .failure(_):
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 56, height: 56)
                            .foregroundColor(.secondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(name)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Creator & Developer")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(bio)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
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

// MARK: - TikTok Stalker View

struct TikTokStalkerView: View {
    @StateObject private var apiClient = TikTokProfileAPIClient.shared
    @State private var username: String = ""
    @State private var profile: TikTokProfile?
    @State private var toastMessage: String?
    @State private var toastVisible = false
    @State private var toastWorkItem: DispatchWorkItem?
    @FocusState private var isUsernameFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                inputSection
                
                if let profile = profile {
                    profileSection(profile: profile)
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("TikTok Stalker")
        .overlay(alignment: .bottom) {
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
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TikTok Stalker")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("View detailed TikTok profile information")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Username")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "at")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.leading, 10)
                        
                        TextField("username", text: $username)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .focused($isUsernameFieldFocused)
                            .onSubmit(fetchProfile)
                            .padding(.vertical, 10)
                        
                        if !username.isEmpty {
                            Button(action: { username = "" }) {
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
                    
                    Button(action: fetchProfile) {
                        if apiClient.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(username.isEmpty || apiClient.isLoading)
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
    
    private func profileSection(profile: TikTokProfile) -> some View {
        VStack(spacing: 16) {
            profileHeader(profile: profile)
            statsGrid(profile: profile)
            if !profile.bio.isEmpty {
                bioSection(profile: profile)
            }
            additionalInfo(profile: profile)
        }
    }
    
    private func profileHeader(profile: TikTokProfile) -> some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: profile.avatar)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 80, height: 80)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                case .failure(_):
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if profile.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
                
                Text("@\(profile.username)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    if profile.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }
                    
                    Label("Joined \(profile.joined)", systemImage: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
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
    
    private func statsGrid(profile: TikTokProfile) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            statCard(title: "Followers", value: profile.formattedFollowers, icon: "person.2.fill")
            statCard(title: "Following", value: profile.formattedFollowing, icon: "person.fill.checkmark")
            statCard(title: "Likes", value: profile.formattedLikes, icon: "heart.fill")
            statCard(title: "Videos", value: profile.formattedVideos, icon: "play.rectangle.fill")
        }
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
    
    private func bioSection(profile: TikTokProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bio")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(profile.bio)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func additionalInfo(profile: TikTokProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Additional Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            VStack(alignment: .leading, spacing: 8) {
                infoRow(label: "Friends", value: "\(profile.friends)")
                infoRow(label: "Last Name Change", value: profile.lastModifiedName)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    private func fetchProfile() {
        Task {
            await MainActor.run {
                apiClient.isLoading = true
            }
            
            do {
                let fetchedProfile = try await apiClient.fetchProfile(username: username)
                await MainActor.run {
                    profile = fetchedProfile
                    apiClient.isLoading = false
                }
            } catch {
                await MainActor.run {
                    showToast(error.localizedDescription)
                    apiClient.isLoading = false
                }
            }
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }
}

// MARK: - Privacy and Terms View

struct PrivacyAndTermsView: View {
    @State private var selectedTab: LegalTab = .privacy
    
    enum LegalTab: String, CaseIterable {
        case privacy = "Privacy Policy"
        case terms = "Terms of Service"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    ForEach(LegalTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 8) {
                                Text(tab.rawValue)
                                    .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                Divider()
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == .privacy {
                        privacyPolicyContent
                    } else {
                        termsOfServiceContent
                    }
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 28)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Legal")
    }
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Privacy Policy")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Last Updated: February 23, 2026")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            legalSectionCard(title: "Introduction") {
                Text("TikSave is committed to protecting your privacy. This Privacy Policy explains how TikSave handles your information when you use our macOS application.")
            }
            
            legalSectionCard(title: "Information We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Information You Provide:")
                        .font(.system(size: 13, weight: .semibold))
                    legalBulletPoint("Download URLs: TikTok video URLs you paste or provide")
                    legalBulletPoint("File Preferences: Output folder, filename templates, settings")
                    legalBulletPoint("Custom Sounds: Audio files you upload for notifications")
                    
                    Text("Automatically Collected:")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 8)
                    legalBulletPoint("Download History: Local records (stored only on your device)")
                    legalBulletPoint("Cache Data: Temporary thumbnails and metadata (local only)")
                    legalBulletPoint("App Settings: Your preferences (stored locally)")
                }
            }
            
            legalSectionCard(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TikSave processes all data locally on your device. We use your information to:")
                        .padding(.bottom, 4)
                    legalBulletPoint("Download TikTok videos based on URLs you provide")
                    legalBulletPoint("Save files to your chosen output location")
                    legalBulletPoint("Display download history and metadata")
                    legalBulletPoint("Apply your custom settings and preferences")
                    legalBulletPoint("Play custom notification sounds")
                }
            }
            
            legalSectionCard(title: "Data Storage") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local Storage Only")
                        .font(.system(size: 13, weight: .semibold))
                    Text("All data is stored exclusively on your Mac:")
                        .padding(.bottom, 4)
                    legalBulletPoint("Download history: ~/Library/Application Support/TikSave/")
                    legalBulletPoint("Custom sounds: ~/Library/Application Support/TikSave/CustomSounds/")
                    legalBulletPoint("Thumbnail cache: ~/Library/Caches/TikSave/")
                    legalBulletPoint("Settings: macOS UserDefaults")
                    
                    Text("No Cloud Storage")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 8)
                    Text("TikSave does NOT:")
                        .padding(.bottom, 4)
                    legalBulletPoint("Upload your data to any servers")
                    legalBulletPoint("Store your information in the cloud")
                    legalBulletPoint("Sync data across devices")
                    legalBulletPoint("Transmit your download history anywhere")
                }
            }
            
            legalSectionCard(title: "Third-Party Services") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TikSave uses the Tikwm API to fetch video metadata and download links. When you download a video, the TikTok URL is sent to Tikwm's servers.")
                        .padding(.bottom, 4)
                    Text("TikSave does NOT use:")
                        .padding(.bottom, 4)
                    legalBulletPoint("Analytics services")
                    legalBulletPoint("Crash reporting tools")
                    legalBulletPoint("Advertising networks")
                    legalBulletPoint("User tracking mechanisms")
                }
            }
            
            legalSectionCard(title: "Your Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You have complete control over your data:")
                        .padding(.bottom, 4)
                    legalBulletPoint("View your download history in the app")
                    legalBulletPoint("Clear history at any time via Settings")
                    legalBulletPoint("Clear thumbnail cache via Settings")
                    legalBulletPoint("Delete the app to remove all data")
                    legalBulletPoint("Access all data in ~/Library/Application Support/TikSave/")
                }
            }
            
            legalSectionCard(title: "Contact") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For privacy-related questions:")
                        .padding(.bottom, 4)
                    legalBulletPoint("GitHub: github.com/miftahganzz/TikSave")
                    legalBulletPoint("Website: miftah.is-a.dev")
                }
            }
            
            Text("Summary: TikSave is a privacy-focused application that processes everything locally on your Mac. We don't collect, store, or transmit your personal information.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.1))
                )
        }
    }
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Terms of Service")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Last Updated: February 23, 2026")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            legalSectionCard(title: "Acceptance of Terms") {
                Text("By downloading, installing, or using TikSave, you agree to be bound by these Terms of Service. If you do not agree, do not use the app.")
            }
            
            legalSectionCard(title: "License") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TikSave grants you a limited, non-exclusive, non-transferable license to use the app for personal, non-commercial purposes.")
                        .padding(.bottom, 4)
                    Text("You may NOT:")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.bottom, 4)
                    legalBulletPoint("Use the app for commercial purposes without permission")
                    legalBulletPoint("Redistribute, sell, or sublicense the app")
                    legalBulletPoint("Reverse engineer or decompile the app")
                    legalBulletPoint("Use the app to violate any laws or regulations")
                }
            }
            
            legalSectionCard(title: "User Responsibilities") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Legal Compliance")
                        .font(.system(size: 13, weight: .semibold))
                    legalBulletPoint("Comply with all applicable laws and regulations")
                    legalBulletPoint("Respect intellectual property rights")
                    legalBulletPoint("Only download content you have the right to download")
                    legalBulletPoint("Use downloaded content in accordance with TikTok's ToS")
                    
                    Text("Content Rights")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 8)
                    legalBulletPoint("Downloaded content belongs to its original creators")
                    legalBulletPoint("You are responsible for how you use downloaded content")
                    legalBulletPoint("Obtain permission from creators for commercial use")
                }
            }
            
            legalSectionCard(title: "Prohibited Uses") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You may NOT use TikSave to:")
                        .padding(.bottom, 4)
                    legalBulletPoint("Infringe on copyrights or intellectual property")
                    legalBulletPoint("Download content for commercial redistribution")
                    legalBulletPoint("Harass, stalk, or harm others")
                    legalBulletPoint("Violate TikTok's Terms of Service")
                    legalBulletPoint("Engage in any illegal activities")
                }
            }
            
            legalSectionCard(title: "Disclaimer of Warranties") {
                Text("TikSave is provided \"AS IS\" and \"AS AVAILABLE\" without warranties of any kind. We do not guarantee uninterrupted or error-free operation, accuracy of results, or fitness for a particular purpose.")
            }
            
            legalSectionCard(title: "Limitation of Liability") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The developer shall not be liable for:")
                        .padding(.bottom, 4)
                    legalBulletPoint("Indirect, incidental, or consequential damages")
                    legalBulletPoint("Loss of profits or data")
                    legalBulletPoint("Service interruptions")
                    legalBulletPoint("Third-party claims")
                }
            }
            
            legalSectionCard(title: "Third-Party Services") {
                Text("TikSave relies on third-party services (TikTok and Tikwm API). We are not responsible for their availability, reliability, or service interruptions.")
            }
            
            legalSectionCard(title: "Termination") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You may stop using TikSave at any time by deleting the app. We reserve the right to discontinue the app or modify features at any time.")
                }
            }
            
            legalSectionCard(title: "Contact") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For questions about these Terms:")
                        .padding(.bottom, 4)
                    legalBulletPoint("GitHub: github.com/miftahganzz/TikSave")
                    legalBulletPoint("Website: miftah.is-a.dev")
                    legalBulletPoint("Issues: github.com/miftahganzz/TikSave/issues")
                }
            }
            
            Text("Important: TikSave is a tool for personal use. Always respect content creators' rights and TikTok's Terms of Service. Download content only if you have the right to do so.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.1))
                )
        }
    }
    
    private func legalSectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            
            content()
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func legalBulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    MainContentView()
}