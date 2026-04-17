import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: String      // "user" | "assistant"
    var content: String
    var createdAt: Date
    /// User feedback on an assistant message. Values: "up", "down", or nil (no feedback).
    var userFeedback: String? = nil

    var conversation: Conversation?

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}
