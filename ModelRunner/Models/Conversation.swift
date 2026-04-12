import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    // Unified model identity — works for both local and remote
    // Format: "local:<repoId>" or "remote:<serverUUID>:<modelID>"
    var modelIdentity: String
    var modelDisplayName: String
    /// Source label for display: "On Device" or server name
    var modelSourceLabel: String
    /// Per-conversation thinking toggle
    var enableThinking: Bool

    // Legacy fields — kept for migration from pre-remote-inference conversations
    var modelRepoId: String
    var modelQuantization: String

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    /// Create a conversation with unified identity (new path — remote or local)
    init(modelIdentity: String, modelDisplayName: String, modelSourceLabel: String, enableThinking: Bool = false) {
        self.id = UUID()
        self.modelIdentity = modelIdentity
        self.modelDisplayName = modelDisplayName
        self.modelSourceLabel = modelSourceLabel
        self.enableThinking = enableThinking
        self.title = "New Conversation"
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelRepoId = ""
        self.modelQuantization = ""
    }

    /// Legacy init — for backward compatibility with existing local model conversations
    init(modelRepoId: String, modelDisplayName: String, modelQuantization: String) {
        self.id = UUID()
        self.modelIdentity = "local:\(modelRepoId)"
        self.modelDisplayName = modelDisplayName
        self.modelSourceLabel = "On Device"
        self.enableThinking = false
        self.title = "New Conversation"
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelRepoId = modelRepoId
        self.modelQuantization = modelQuantization
    }

    /// Auto-generate title from first user message. Truncated to 50 chars with ellipsis.
    func generateTitle(from firstUserMessage: String) {
        let trimmed = firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 {
            title = trimmed
        } else {
            title = String(trimmed.prefix(50)) + "..."
        }
        updatedAt = Date()
    }
}
