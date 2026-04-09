import Foundation

// MARK: - HF API Response DTOs

/// Root model object from HF API /api/models endpoint.
/// Both list (search) and single-model responses decode to this type.
struct HFModelListResponse: Decodable {
    let id: String              // "username/model-name"
    let modelId: String?
    let downloads: Int
    let likes: Int
    let lastModified: String?
    let siblings: [HFSibling]?  // Present when full=true in request

    enum CodingKeys: String, CodingKey {
        case id
        case modelId
        case downloads
        case likes
        case lastModified
        case siblings
    }

    /// Best-effort parameter count from model id string.
    /// Matches patterns like "8b", "7b", "70b", "1.5b", "0.5b" (case-insensitive).
    /// Returns nil if no match — CompatibilityEngine handles nil gracefully.
    var estimatedParameterCount: Int? {
        let text = id.lowercased()
        // Regex: digit(s) optionally followed by decimal, then literal 'b'
        guard let range = text.range(of: #"(\d+(?:\.\d+)?)b"#, options: .regularExpression) else {
            return nil
        }
        let matched = String(text[range])
        let numStr = matched.dropLast() // remove trailing 'b'
        guard let billions = Double(numStr) else { return nil }
        // Guard against false positives from context window sizes (128k → 128 billion params is wrong)
        // Reasonable param range: 0.1B to 200B
        guard billions >= 0.1 && billions <= 200 else { return nil }
        return Int(billions * 1_000_000_000)
    }

    /// Display name extracted from repo id (part after the '/').
    var displayName: String {
        id.components(separatedBy: "/").last ?? id
    }
}

/// A single file in an HF model repository.
struct HFSibling: Decodable {
    let rfilename: String   // e.g. "model-Q4_K_M.gguf", "tokenizer.json"
    let size: Int64?        // May be LFS pointer size (136 bytes) — prefer lfs.size
    let blobId: String?
    let lfs: HFLFSMeta?

    /// LFS metadata — contains the true file size for large files.
    struct HFLFSMeta: Decodable {
        let size: Int64     // Actual file size in bytes
        let sha256: String?
    }

    /// True file size in bytes. Prefers lfs.size over size (see Research pitfall #1).
    var trueSize: Int64? {
        lfs?.size ?? size
    }

    /// Returns true if this sibling is a GGUF model file.
    var isGGUF: Bool {
        rfilename.lowercased().hasSuffix(".gguf")
    }

    /// Maps this GGUF sibling to a ModelMetadata for CompatibilityEngine.
    /// Returns nil if not a GGUF file.
    func toModelMetadata(repoId: String, paramCount: Int?) -> ModelMetadata? {
        guard isGGUF else { return nil }
        let bytes = trueSize.map { UInt64(max(0, $0)) }
        return ModelMetadata(
            name: "\(repoId)/\(rfilename)",
            fileSizeBytes: bytes,
            parameterCount: paramCount,
            quantizationType: QuantizationType.fromFilename(rfilename)
        )
    }
}
