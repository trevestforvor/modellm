import Foundation

/// Formats chat messages into model-specific prompt strings.
/// v1 default: ChatML template, compatible with most GGUF models on Hugging Face.
public enum PromptFormatter {

    /// Format messages using the ChatML template.
    /// Compatible with most GGUF models on Hugging Face (Mistral, Llama-3, Phi, Qwen families).
    ///
    /// - Parameters:
    ///   - system: The system prompt defining assistant behavior.
    ///   - messages: Conversation history. All roles must be non-empty.
    /// - Returns: A fully formatted prompt string ready for tokenization.
    public static func chatml(system: String, messages: [ChatMessage]) -> String {
        var result = "<|im_start|>system\n\(system)<|im_end|>\n"
        for message in messages {
            let role = message.role == .user ? "user" : "assistant"
            result += "<|im_start|>\(role)\n\(message.content)<|im_end|>\n"
        }
        result += "<|im_start|>assistant\n"
        return result
    }
}
