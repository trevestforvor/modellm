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
}
