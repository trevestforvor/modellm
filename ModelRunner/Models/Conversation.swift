import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modelRepoId: String
    var modelDisplayName: String
    var modelQuantization: String

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    init(modelRepoId: String, modelDisplayName: String, modelQuantization: String) {
        self.id = UUID()
        self.modelRepoId = modelRepoId
        self.modelDisplayName = modelDisplayName
        self.modelQuantization = modelQuantization
        self.title = "New Conversation"
        self.createdAt = Date()
        self.updatedAt = Date()
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
