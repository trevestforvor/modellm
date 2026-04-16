import Foundation

/// Role of a participant in a chat conversation.
public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

/// A single message in a chat conversation.
/// Content is mutable to support streaming token append during generation.
public struct ChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    /// Reasoning/thinking content — separate from main content, rendered as collapsible block
    public var thinkingContent: String
    /// True while the assistant is streaming tokens into this message.
    public var isStreaming: Bool
    /// Duration of thinking phase in seconds (first thinking token → first content token)
    public var thinkingDuration: TimeInterval?
    /// Final measured tok/s — set when generation completes, persists on the message
    public var finalTokPerSec: Double?

    public init(role: MessageRole, content: String, isStreaming: Bool = false, thinkingContent: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.isStreaming = isStreaming
    }
}
