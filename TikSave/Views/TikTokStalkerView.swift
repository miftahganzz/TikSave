import SwiftUI

struct TikTokStalkerView: View {
    @StateObject private var apiClient = TikTokProfileAPIClient.shared
    @State private var username: String = ""
    @State private var profile: TikTokProfile?
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isUsernameFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Input Section
                inputSection
                
                // Profile Section
                if let profile = profile {
                    profileSection(profile: profile)
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 28)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("TikTok Stalker")
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Input Section
    
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
                            Text("Search")
                                .font(.system(size: 13, weight: .medium))
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
    
    // MARK: - Profile Section
    
    private func profileSection(profile: TikTokProfile) -> some View {
        VStack(spacing: 16) {
            // Profile Header
            profileHeader(profile: profile)
            
            // Stats Grid
            statsGrid(profile: profile)
            
            // Bio Section
            if !profile.bio.isEmpty {
                bioSection(profile: profile)
            }
            
            // Additional Info
            additionalInfo(profile: profile)
        }
    }
    
    private func profileHeader(profile: TikTokProfile) -> some View {
        HStack(spacing: 16) {
            // Avatar
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
            
            // Profile Info
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
    
    // MARK: - Actions
    
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
                    errorMessage = error.localizedDescription
                    showingError = true
                    apiClient.isLoading = false
                }
            }
        }
    }
}

#Preview {
    TikTokStalkerView()
}
