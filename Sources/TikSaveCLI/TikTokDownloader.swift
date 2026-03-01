import Foundation

class TikTokDownloader {
    private let verbose: Bool
    private let apiBase = "https://api.tikwm.com/api"
    
    init(verbose: Bool = false) {
        self.verbose = verbose
    }
    
    func download(url: String, format: DownloadFormat, watermark: Bool, outputPath: String) async throws {
        let videoId = try extractVideoId(from: url)
        
        if verbose {
            print("🔍 Extracted video ID: \(videoId)")
        }
        
        print("⏳ Fetching video information...")
        let videoInfo = try await fetchVideoInfo(videoId: videoId)
        
        print("📊 Title: \(videoInfo.title)")
        print("👤 Author: @\(videoInfo.author)")
        print("❤️  Likes: \(formatNumber(videoInfo.likes))")
        print("💬 Comments: \(formatNumber(videoInfo.comments))")
        print("🔄 Shares: \(formatNumber(videoInfo.shares))")
        print("")
        
        switch format {
        case .video:
            let downloadURL = watermark ? videoInfo.playURL : videoInfo.downloadURL
            try await downloadFile(
                from: downloadURL,
                to: outputPath,
                filename: "\(videoInfo.id)_\(watermark ? "wm" : "nowm").mp4",
                type: "video"
            )
            
        case .audio:
            try await downloadFile(
                from: videoInfo.musicURL,
                to: outputPath,
                filename: "\(videoInfo.id)_audio.mp3",
                type: "audio"
            )
            
        case .images:
            if videoInfo.images.isEmpty {
                throw DownloadError.noImages
            }
            print("📸 Downloading \(videoInfo.images.count) images...")
            for (index, imageURL) in videoInfo.images.enumerated() {
                try await downloadFile(
                    from: imageURL,
                    to: outputPath,
                    filename: "\(videoInfo.id)_image_\(index + 1).jpg",
                    type: "image \(index + 1)/\(videoInfo.images.count)"
                )
            }
        }
    }
    
    func downloadProfile(username: String, downloadAvatar: Bool, outputPath: String) async throws {
        print("⏳ Fetching profile information...")
        
        let cleanUsername = username.replacingOccurrences(of: "@", with: "")
        let profileInfo = try await fetchProfileInfo(username: cleanUsername)
        
        print("👤 Username: @\(profileInfo.username)")
        print("📝 Nickname: \(profileInfo.nickname)")
        print("📊 Followers: \(formatNumber(profileInfo.followers))")
        print("👥 Following: \(formatNumber(profileInfo.following))")
        print("❤️  Total Likes: \(formatNumber(profileInfo.totalLikes))")
        print("🎬 Videos: \(formatNumber(profileInfo.videoCount))")
        print("📄 Bio: \(profileInfo.bio)")
        print("")
        
        if downloadAvatar {
            try await downloadFile(
                from: profileInfo.avatarURL,
                to: outputPath,
                filename: "\(cleanUsername)_avatar.jpg",
                type: "avatar"
            )
        }
        
        let profileData = """
        TikTok Profile: @\(profileInfo.username)
        Nickname: \(profileInfo.nickname)
        Followers: \(formatNumber(profileInfo.followers))
        Following: \(formatNumber(profileInfo.following))
        Total Likes: \(formatNumber(profileInfo.totalLikes))
        Videos: \(formatNumber(profileInfo.videoCount))
        Bio: \(profileInfo.bio)
        Verified: \(profileInfo.verified ? "Yes" : "No")
        """
        
        let profilePath = URL(fileURLWithPath: outputPath).appendingPathComponent("\(cleanUsername)_profile.txt")
        try profileData.write(to: profilePath, atomically: true, encoding: .utf8)
        print("💾 Profile saved to: \(profilePath.path)")
    }
    
    private func extractVideoId(from url: String) throws -> String {
        let patterns = [
            #"(?:vm\.tiktok\.com|vt\.tiktok\.com)/([A-Za-z0-9]+)"#,
            #"tiktok\.com/@[^/]+/video/(\d+)"#,
            #"tiktok\.com/.*[?&]v=(\d+)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        throw DownloadError.invalidURL
    }
    
    private func fetchVideoInfo(videoId: String) async throws -> VideoInfo {
        let urlString = "\(apiBase)/?url=https://www.tiktok.com/@x/video/\(videoId)"
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DownloadError.networkError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataDict = json?["data"] as? [String: Any] else {
            throw DownloadError.parseError
        }
        
        return VideoInfo(
            id: videoId,
            title: dataDict["title"] as? String ?? "",
            author: dataDict["author"] as? String ?? "",
            downloadURL: dataDict["hdplay"] as? String ?? dataDict["play"] as? String ?? "",
            playURL: dataDict["play"] as? String ?? "",
            musicURL: dataDict["music"] as? String ?? "",
            images: (dataDict["images"] as? [String]) ?? [],
            likes: dataDict["digg_count"] as? Int ?? 0,
            comments: dataDict["comment_count"] as? Int ?? 0,
            shares: dataDict["share_count"] as? Int ?? 0
        )
    }
    
    private func fetchProfileInfo(username: String) async throws -> ProfileInfo {
        let urlString = "\(apiBase)/user/info?unique_id=\(username)"
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DownloadError.networkError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataDict = json?["data"] as? [String: Any],
              let userInfo = dataDict["user"] as? [String: Any],
              let stats = dataDict["stats"] as? [String: Any] else {
            throw DownloadError.parseError
        }
        
        return ProfileInfo(
            username: userInfo["unique_id"] as? String ?? username,
            nickname: userInfo["nickname"] as? String ?? "",
            bio: userInfo["signature"] as? String ?? "",
            avatarURL: userInfo["avatar_larger"] as? String ?? "",
            followers: stats["followerCount"] as? Int ?? 0,
            following: stats["followingCount"] as? Int ?? 0,
            totalLikes: stats["heartCount"] as? Int ?? 0,
            videoCount: stats["videoCount"] as? Int ?? 0,
            verified: userInfo["verified"] as? Bool ?? false
        )
    }
    
    private func downloadFile(from urlString: String, to outputPath: String, filename: String, type: String) async throws {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }
        
        print("⬇️  Downloading \(type)...")
        
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DownloadError.downloadFailed
        }
        
        let destinationURL = URL(fileURLWithPath: outputPath).appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        let fileSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 ?? 0
        print("💾 Saved: \(filename) (\(formatBytes(fileSize)))")
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct VideoInfo {
    let id: String
    let title: String
    let author: String
    let downloadURL: String
    let playURL: String
    let musicURL: String
    let images: [String]
    let likes: Int
    let comments: Int
    let shares: Int
}

struct ProfileInfo {
    let username: String
    let nickname: String
    let bio: String
    let avatarURL: String
    let followers: Int
    let following: Int
    let totalLikes: Int
    let videoCount: Int
    let verified: Bool
}

enum DownloadError: LocalizedError {
    case invalidURL
    case networkError
    case parseError
    case downloadFailed
    case noImages
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid TikTok URL"
        case .networkError: return "Network request failed"
        case .parseError: return "Failed to parse response"
        case .downloadFailed: return "Download failed"
        case .noImages: return "This video has no images"
        }
    }
}
