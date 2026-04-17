import Foundation
import SwiftData

@Model
final class DownloadedModel {
    /// Unique HF repo identifier e.g. "bartowski/Llama-3.2-3B-Instruct-GGUF"
    @Attribute(.unique) var repoId: String
    /// Human-readable name e.g. "Llama 3.2 3B Instruct"
    var displayName: String
    /// GGUF filename e.g. "Llama-3.2-3B-Instruct-Q4_K_M.gguf"
    var filename: String
    /// Quantization string e.g. "Q4_K_M" — stored as String (not QuantizationType) for SwiftData Codable compatibility
    var quantization: String
    /// File size in bytes from HF API LFS metadata
    var fileSizeBytes: Int64
    /// Absolute path to GGUF file in Application Support/huggingface/hub/
    var localPath: String
    /// Updated when model is activated (D-08: sort key for Library)
    var lastUsedDate: Date
    /// Phase 4 will increment this; Phase 3 initializes to 0 (D-07: shown on Library card)
    var conversationCount: Int
    /// Only one model is active at a time — enforced in DownloadService (D-10)
    var isActive: Bool
    /// Timestamp when download completed
    var downloadedAt: Date

    // MARK: - Inference Parameters (Phase 5)
    /// Temperature for sampling. Range 0.0–2.0. Default 0.7 (balanced).
    var temperature: Double = 0.7
    /// Top-p nucleus sampling. Range 0.0–1.0. Default 0.9 (balanced).
    var topP: Double = 0.9
    /// System prompt sent at the start of every conversation with this model.
    var systemPrompt: String = "You are a helpful assistant."

    // MARK: - Vision Capability
    /// True if this model accepts image inputs. Defaults to false (text-only).
    /// Set at download time via `VisionWhitelist.supportsVision(repoId:)`.
    /// When true, the chat UI reveals the attachment menu (file/photo/camera).
    var supportsVision: Bool = false

    init(
        repoId: String,
        displayName: String,
        filename: String,
        quantization: String,
        fileSizeBytes: Int64,
        localPath: String
    ) {
        self.repoId = repoId
        self.displayName = displayName
        self.filename = filename
        self.quantization = quantization
        self.fileSizeBytes = fileSizeBytes
        self.localPath = localPath
        self.lastUsedDate = Date()
        self.conversationCount = 0
        self.isActive = false
        self.downloadedAt = Date()
    }

    /// Formatted file size for display e.g. "3.4 GB"
    var formattedSize: String {
        let bytes = Double(fileSizeBytes)
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", bytes / 1_000_000_000)
        } else {
            return String(format: "%.0f MB", bytes / 1_000_000)
        }
    }

    /// Relative timestamp for Library card e.g. "2 hours ago" (D-08)
    var relativeLastUsed: String {
        lastUsedDate.formatted(.relative(presentation: .named))
    }

    /// Canonical on-disk URL, recomputed against the current sandbox.
    ///
    /// Every app install gets a fresh container UUID, so the `localPath` stored at download
    /// time goes stale after reinstall. This property ignores the stored string and rebuilds
    /// the path from `repoId + filename` — which are stable — against the current
    /// Application Support directory. Also falls back to `Bundle.main` so bundled models
    /// installed via BundledModelInstaller still resolve.
    var resolvedFileURL: URL {
        // 1. Cheapest: whatever we stored, if it still exists on disk.
        if !localPath.isEmpty, FileManager.default.fileExists(atPath: localPath) {
            return URL(filePath: localPath)
        }

        // 2. Bundled model? BundledModelInstaller stores `Bundle.main.url(forResource:)`.
        if let bundled = Bundle.main.url(forResource: filename, withExtension: nil) {
            return bundled
        }

        // 3. Downloaded model — mirror DownloadService's destination layout exactly.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let safeRepo = repoId.replacingOccurrences(of: "/", with: "--")
        return appSupport
            .appending(path: "huggingface/hub/\(safeRepo)/blobs/\(filename)", directoryHint: .notDirectory)
    }

    /// Whether the model file exists on disk at the resolved path.
    var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: resolvedFileURL.path)
    }
}
