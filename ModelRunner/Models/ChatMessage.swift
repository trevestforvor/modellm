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
    /// True while the assistant is streaming tokens into this message.
    public var isStreaming: Bool

    public init(role: MessageRole, content: String, isStreaming: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
    }
}
