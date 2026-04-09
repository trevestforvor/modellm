import Foundation

// MARK: - Annotated Model (HF model + compatibility verdict)

/// An HF model result with per-variant compatibility results attached.
/// The unit of display in the Browse UI.
struct AnnotatedModel: Identifiable, Hashable {
    let id: String                    // HF repo id, e.g. "bartowski/Meta-Llama-3-8B-Instruct-GGUF"
    let repoId: String                // Same as id
    let displayName: String           // Part after '/', e.g. "Meta-Llama-3-8B-Instruct-GGUF"
    let downloadCount: Int
    let variants: [AnnotatedVariant]  // Per-GGUF-file compatibility; only .runsWell and .runsSlow included

    /// Best variant for this device: highest file size among .runsWell tier.
    /// More file size = higher quantization = better quality within the same tier.
    var bestVariant: AnnotatedVariant? {
        variants.filter { $0.result.tier == .runsWell }
                .max { ($0.metadata.fileSizeBytes ?? 0) < ($1.metadata.fileSizeBytes ?? 0) }
    }

    /// Primary compatibility result for card badge display.
    /// Shows best .runsWell variant, or falls back to first .runsSlow variant.
    var primaryResult: AnnotatedVariant? {
        bestVariant ?? variants.first { $0.result.tier == .runsSlow }
    }

    // MARK: Hashable

    static func == (lhs: AnnotatedModel, rhs: AnnotatedModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A single GGUF file variant with its compatibility verdict.
struct AnnotatedVariant: Identifiable, Hashable {
    let id: String               // rfilename, e.g. "Meta-Llama-3-8B-Instruct-Q4_K_M.gguf"
    let metadata: ModelMetadata
    let result: CompatibilityResult

    /// Filename portion only (no repo path prefix).
    var filename: String {
        metadata.name.components(separatedBy: "/").last ?? metadata.name
    }

    /// Quantization type for display in variant rows.
    var quantType: QuantizationType {
        metadata.quantizationType
    }

    /// Formatted file size string, e.g. "4.1 GB".
    var formattedFileSize: String {
        guard let bytes = metadata.fileSizeBytes else { return "— GB" }
        return bytes.formattedFileSize
    }

    // MARK: Hashable

    static func == (lhs: AnnotatedVariant, rhs: AnnotatedVariant) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Formatting Extensions

extension UInt64 {
    /// Formats bytes as human-readable file size: "4.1 GB" or "512 MB"
    var formattedFileSize: String {
        let gb = Double(self) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(self) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
}

extension Int {
    /// Formats download count as abbreviated string: "12.4K" or "1.2M"
    var formattedDownloadCount: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
