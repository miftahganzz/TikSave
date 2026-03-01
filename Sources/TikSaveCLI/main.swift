import Foundation
import ArgumentParser

struct TikSave: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tiksave",
        abstract: "Download TikTok videos without watermarks from the command line",
        version: "1.0.0",
        subcommands: [Download.self, Profile.self],
        defaultSubcommand: Download.self
    )
}

extension TikSave {
    struct Download: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Download TikTok video"
        )
        
        @Argument(help: "TikTok video URL")
        var url: String
        
        @Option(name: .shortAndLong, help: "Output directory")
        var output: String = "."
        
        @Option(name: .shortAndLong, help: "Format: video, audio, images")
        var format: DownloadFormat = .video
        
        @Flag(name: .shortAndLong, help: "Download with watermark")
        var watermark: Bool = false
        
        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false
        
        func run() async throws {
            let downloader = TikTokDownloader(verbose: verbose)
            
            print("🎬 TikSave CLI v1.0.0")
            print("📥 Downloading from: \(url)")
            print("📁 Output: \(output)")
            print("🎯 Format: \(format)")
            print("")
            
            do {
                try await downloader.download(
                    url: url,
                    format: format,
                    watermark: watermark,
                    outputPath: output
                )
                print("\n✅ Download completed successfully!")
            } catch {
                print("\n❌ Error: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct Profile: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Download TikTok profile information"
        )
        
        @Argument(help: "TikTok username")
        var username: String
        
        @Option(name: .shortAndLong, help: "Output directory")
        var output: String = "."
        
        @Flag(name: .shortAndLong, help: "Download avatar")
        var avatar: Bool = false
        
        @Flag(name: .shortAndLong, help: "Verbose output")
        var verbose: Bool = false
        
        func run() async throws {
            let downloader = TikTokDownloader(verbose: verbose)
            
            print("🎬 TikSave CLI v1.0.0")
            print("👤 Fetching profile: @\(username)")
            print("")
            
            do {
                try await downloader.downloadProfile(
                    username: username,
                    downloadAvatar: avatar,
                    outputPath: output
                )
                print("\n✅ Profile fetched successfully!")
            } catch {
                print("\n❌ Error: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
}

enum DownloadFormat: String, ExpressibleByArgument {
    case video
    case audio
    case images
}

TikSave.main()
