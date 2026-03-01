import Foundation

enum CustomSoundManagerError: LocalizedError {
    case unsupportedFormat
    case fileConflict
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Format tidak didukung. Gunakan file WAV, AIFF, atau CAF."
        case .fileConflict:
            return "Sudah ada file dengan nama tersebut. Coba ganti nama file."
        case .fileOperationFailed(let reason):
            return reason
        }
    }
}

final class CustomSoundManager {
    static let shared = CustomSoundManager()
    static let supportedExtensions: Set<String> = ["wav", "aif", "aiff", "caf"]
    static let convertibleExtensions: Set<String> = ["mp3", "m4a", "aac"]
    static var acceptedExtensions: [String] {
        Array(supportedExtensions.union(convertibleExtensions)).sorted()
    }

    private let fileManager = FileManager.default
    private init() {}

    private lazy var baseDirectory: URL = {
        let expanded = ("~/Library/Sounds" as NSString).expandingTildeInPath
        let soundsDir = URL(fileURLWithPath: expanded, isDirectory: true)
        if !fileManager.fileExists(atPath: soundsDir.path) {
            try? fileManager.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        }
        return soundsDir
    }()

    func url(for fileName: String) -> URL {
        baseDirectory.appendingPathComponent(fileName)
    }

    func fileExists(named fileName: String) -> Bool {
        fileManager.fileExists(atPath: url(for: fileName).path)
    }

    func removeSound(named fileName: String) {
        let target = url(for: fileName)
        try? fileManager.removeItem(at: target)
    }

    func importSound(from sourceURL: URL) throws -> CustomNotificationSound {
        try ensureDirectory()
        let ext = sourceURL.pathExtension.lowercased()
        let displayName = sourceURL.deletingPathExtension().lastPathComponent
        let safeBase = sanitize(displayName)
        var workingURL = sourceURL
        var cleanupURL: URL?
        var targetExtension = ext
        defer {
            if let cleanupURL {
                try? fileManager.removeItem(at: cleanupURL)
            }
        }
        if !Self.supportedExtensions.contains(ext) {
            if Self.convertibleExtensions.contains(ext) {
                let converted = try convertToWave(from: sourceURL)
                workingURL = converted
                cleanupURL = converted
                targetExtension = "wav"
            } else {
                throw CustomSoundManagerError.unsupportedFormat
            }
        }
        let sanitizedBase = safeBase.isEmpty ? "TikSave" : safeBase
        let fileName = uniqueFileName(basename: sanitizedBase, ext: targetExtension)
        let destination = url(for: fileName)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CustomSoundManagerError.fileConflict
        }
        do {
            try fileManager.copyItem(at: workingURL, to: destination)
        } catch {
            throw CustomSoundManagerError.fileOperationFailed(error.localizedDescription)
        }
        return CustomNotificationSound(displayName: displayName, fileName: fileName)
    }

    private func ensureDirectory() throws {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }

    private func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(filtered).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "TikSave" : trimmed
    }

    private func uniqueFileName(basename: String, ext: String) -> String {
        let token = UUID().uuidString.prefix(6)
        return "TikSave-\(basename)-\(token).\(ext)"
    }

    private func convertToWave(from sourceURL: URL) throws -> URL {
        let temporary = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = ["-f", "WAVE", "-d", "LEI16", sourceURL.path, temporary.path]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        do {
            try process.run()
        } catch {
            throw CustomSoundManagerError.fileOperationFailed("Gagal menjalankan afconvert: \(error.localizedDescription)")
        }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            try? fileManager.removeItem(at: temporary)
            throw CustomSoundManagerError.fileOperationFailed("Konversi gagal: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return temporary
    }
}
