import XCTest
import SwiftData
@testable import ModelRunner

final class ConversationTests: XCTestCase {

    // MARK: - generateTitle

    func testGenerateTitleShortMessage() {
        let conv = Conversation(modelRepoId: "test/model", modelDisplayName: "Test", modelQuantization: "Q4_K_M")
        conv.generateTitle(from: "Hello world")
        XCTAssertEqual(conv.title, "Hello world")
    }

    func testGenerateTitleLongMessageTruncates() {
        let longMessage = String(repeating: "a", count: 60)
        let conv = Conversation(modelRepoId: "test/model", modelDisplayName: "Test", modelQuantization: "Q4_K_M")
        conv.generateTitle(from: longMessage)
        XCTAssertTrue(conv.title.hasSuffix("..."))
        XCTAssertEqual(conv.title.count, 53) // 50 chars + "..."
    }

    func testGenerateTitleExactly50Chars() {
        let exact50 = String(repeating: "b", count: 50)
        let conv = Conversation(modelRepoId: "test/model", modelDisplayName: "Test", modelQuantization: "Q4_K_M")
        conv.generateTitle(from: exact50)
        XCTAssertFalse(conv.title.hasSuffix("..."))
        XCTAssertEqual(conv.title.count, 50)
    }

    func testInitialTitleIsNewConversation() {
        let conv = Conversation(modelRepoId: "test/model", modelDisplayName: "Test", modelQuantization: "Q4_K_M")
        XCTAssertEqual(conv.title, "New Conversation")
    }

    // MARK: - SwiftData in-memory

    func testConversationPersistsInMemory() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Conversation.self, Message.self, DownloadedModel.self,
            configurations: config
        )
        let context = ModelContext(container)

        let conv = Conversation(modelRepoId: "test/llama", modelDisplayName: "Llama", modelQuantization: "Q4_K_M")
        context.insert(conv)
        try context.save()

        let descriptor = FetchDescriptor<Conversation>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].modelRepoId, "test/llama")
    }

    func testDeleteConversationCascadesToMessages() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Conversation.self, Message.self, DownloadedModel.self,
            configurations: config
        )
        let context = ModelContext(container)

        let conv = Conversation(modelRepoId: "test/llama", modelDisplayName: "Llama", modelQuantization: "Q4_K_M")
        context.insert(conv)
        let msg = Message(role: "user", content: "Hello")
        conv.messages.append(msg)
        try context.save()

        context.delete(conv)
        try context.save()

        let msgDescriptor = FetchDescriptor<Message>()
        let remainingMessages = try context.fetch(msgDescriptor)
        XCTAssertEqual(remainingMessages.count, 0, "Messages should be cascade-deleted with conversation")
    }
}
