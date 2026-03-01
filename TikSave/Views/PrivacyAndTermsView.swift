import SwiftUI

struct PrivacyAndTermsView: View {
    @State private var selectedTab: LegalTab = .privacy
    
    enum LegalTab: String, CaseIterable {
        case privacy = "Privacy Policy"
        case terms = "Terms of Service"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
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
            
            // Content
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
    
    // MARK: - Privacy Policy Content
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Privacy Policy")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Last Updated: February 23, 2026")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            sectionCard(title: "Introduction") {
                Text("TikSave is committed to protecting your privacy. This Privacy Policy explains how TikSave handles your information when you use our macOS application.")
            }
            
            sectionCard(title: "Information We Collect") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Information You Provide:")
                        .font(.system(size: 13, weight: .semibold))
                    bulletPoint("Download URLs: TikTok video URLs you paste or provide")
                    bulletPoint("File Preferences: Output folder, filename templates, settings")
                    bulletPoint("Custom Sounds: Audio files you upload for notifications")
                    
                    Text("Automatically Collected:")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 8)
                    bulletPoint("Download History: Local records (stored only on your device)")
                    bulletPoint("Cache Data: Temporary thumbnails and metadata (local only)")
                    bulletPoint("App Settings: Your preferences (stored locally)")
                }
            }
            
            sectionCard(title: "How We Use Your Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TikSave processes all data locally on your device. We use your information to:")
                        .padding(.bottom, 4)
                    bulletPoint("Download TikTok videos based on URLs you provide")
                    bulletPoint("Save files to your chosen output location")
                    bulletPoint("Display download history and metadata")
                    bulletPoint("Apply your custom settings and preferences")
                    bulletPoint("Play custom notification sounds")
                }
            }
            
            sectionCard(title: "Data Storage") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local Storage Only")
                        .font(.system(size: 13, weight: .semibold))
                    Text("All data is stored exclusively on your Mac:")
                        .padding(.bottom, 4)
                    bulletPoint("Download history: ~/Library/Application Support/TikSave/")
                    bulletPoint("Custom sounds: ~/Library/Application Support/TikSave/CustomSounds/")
                    bulletPoint("Thumbnail cache: ~/Library/Caches/TikSave/")
                    bulletPoint("Settings: macOS UserDefaults")
                    
                    Text("No Cloud Storage")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 8)
                    Text("TikSave does NOT:")
                        .padding(.bottom, 4)
                    bulletPoint("Upload your data to any servers")
                    bulletPoint("Store your information in the cloud")
                    bulletPoint("Sync data across devices")
                    bulletPoint("Transmit your download history anywhere")
                }
            }
            
            sectionCard(title: "Third-Party Services") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TikSave uses the Tikwm API to fetch video metadata and download links. When you download a video, the TikTok URL is sent to Tikwm's servers.")
                        .padding(.bottom, 4)
                    Text("TikSave does NOT use:")
                        .padding(.bottom, 4)
                    bulletPoint("Analytics services")
                    bulletPoint("Crash reporting tools")
                    bulletPoint("Advertising networks")
                    bulletPoint("User tracking mechanisms")
                }
            }
            
            sectionCard(title: "Your Rights") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You have complete control over your data:")
                        .padding(.bottom, 4)
                    bulletPoint("View your download history in the app")
                    bulletPoint("Clear history at any time via Settings")
                    bulletPoint("Clear thumbnail cache via Settings")
                    bulletPoint("Delete the app to remove all data")
                    bulletPoint("Access all data in ~/Library/Application Support/TikSave/")
                }
            }
            
            sectionCard(title: "Contact") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For privacy-related questions:")
                        .padding(.bottom, 4)
                    bulletPoint("GitHub: github.com/miftahganzz/TikSave")
                    bulletPoint("Website: miftah.is-a.dev")
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
    
    // MARK: - Terms of Service Content
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Terms of Service")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Last Updated: February 23, 2026")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            sectionCard(title: "Acceptance of Terms") {
                Text("By downloading, installing, or using TikSave, you agree to be bound by these Terms of Service. If you do not agree, do not use the app.")
            }
            
            sectionCard(title: "License") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TikSave grants you a limited, non-exclusive, non-transferable license to use the app for personal, non-commercial purposes.")
                        .padding(.bottom, 4)
                    Text("You may NOT:")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.bottom, 4)
                    bulletPoint("Use the app for commercial purposes without permission")
                    bulletPoint("Redistribute, sell, or sublicense the app")
                    bulletPoint("Reverse engineer or decompile the app")
                    bulletPoint("Use the app to violate any laws or regulations")
                }
            }
            
            sectionCard(title: "User Responsibilities") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Legal Compliance")
                        .font(.system(size: 13, weight: .semibold))
                    bulletPoint("Comply with all applicable laws and regulations")
                    bulletPoint("Respect intellectual property rights")
                    bulletPoint("Only download content you have the right to download")
                    bulletPoint("Use downloaded content in accordance with TikTok's ToS")
                    
                    Text("Content Rights")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 8)
                    bulletPoint("Downloaded content belongs to its original creators")
                    bulletPoint("You are responsible for how you use downloaded content")
                    bulletPoint("Obtain permission from creators for commercial use")
                }
            }
            
            sectionCard(title: "Prohibited Uses") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You may NOT use TikSave to:")
                        .padding(.bottom, 4)
                    bulletPoint("Infringe on copyrights or intellectual property")
                    bulletPoint("Download content for commercial redistribution")
                    bulletPoint("Harass, stalk, or harm others")
                    bulletPoint("Violate TikTok's Terms of Service")
                    bulletPoint("Engage in any illegal activities")
                }
            }
            
            sectionCard(title: "Disclaimer of Warranties") {
                Text("TikSave is provided \"AS IS\" and \"AS AVAILABLE\" without warranties of any kind. We do not guarantee uninterrupted or error-free operation, accuracy of results, or fitness for a particular purpose.")
            }
            
            sectionCard(title: "Limitation of Liability") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The developer shall not be liable for:")
                        .padding(.bottom, 4)
                    bulletPoint("Indirect, incidental, or consequential damages")
                    bulletPoint("Loss of profits or data")
                    bulletPoint("Service interruptions")
                    bulletPoint("Third-party claims")
                }
            }
            
            sectionCard(title: "Third-Party Services") {
                Text("TikSave relies on third-party services (TikTok and Tikwm API). We are not responsible for their availability, reliability, or service interruptions.")
            }
            
            sectionCard(title: "Termination") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You may stop using TikSave at any time by deleting the app. We reserve the right to discontinue the app or modify features at any time.")
                }
            }
            
            sectionCard(title: "Contact") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For questions about these Terms:")
                        .padding(.bottom, 4)
                    bulletPoint("GitHub: github.com/miftahganzz/TikSave")
                    bulletPoint("Website: miftah.is-a.dev")
                    bulletPoint("Issues: github.com/miftahganzz/TikSave/issues")
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
    
    // MARK: - Helpers
    
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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
    
    private func bulletPoint(_ text: String) -> some View {
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
    NavigationStack {
        PrivacyAndTermsView()
    }
}
