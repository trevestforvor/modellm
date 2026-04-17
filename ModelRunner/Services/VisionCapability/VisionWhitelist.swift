import Foundation

enum VisionWhitelist {
    /// Returns true if a given HF repo ID is known to be a multimodal vision model.
    /// Case-insensitive substring match. Used at download time to populate
    /// `DownloadedModel.supportsVision` so the chat UI can reveal attachment controls.
    static func supportsVision(repoId: String) -> Bool {
        // Bundled models are explicitly known-text. Short-circuit before pattern match.
        if repoId.hasPrefix("bundled/") { return false }

        let lower = repoId.lowercased()
        let markers = [
            "llava",
            "llama-3.2-11b-vision", "llama-3.2-90b-vision",
            "minicpm-v",
            "qwen2-vl", "qwen2.5-vl",
            "phi-3-vision", "phi-3.5-vision",
            "moondream",
            "internvl",
            "cogvlm",
            "idefics",
        ]
        return markers.contains { lower.contains($0) }
    }
}
