import Testing
import Foundation
import SwiftData
@testable import ModelRunner

/// Tests for ChatViewModel SwiftData persistence — CHAT-04
@Suite("ChatViewModelPersistence")
@MainActor
struct ChatViewModelPersistenceTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Conversation.self, Message.self, DownloadedModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeViewModel(context: ModelContext) -> ChatViewModel {
        let vm = ChatViewModel(
            inferenceService: InferenceService(),
            inferenceParams: .default(contextWindowCap: 2048)
        )
        vm.configure(modelContext: context)
        return vm
    }

    private func makeModel(repoId: String = "test/llama") -> DownloadedModel {
        DownloadedModel(
            repoId: repoId,
            displayName: "Test Model",
            filename: "model-Q4_K_M.gguf",
            quantization: "Q4_K_M",
            fileSizeBytes: 1_000_000,
            localPath: "/tmp/model.gguf"
        )
    }

    // MARK: - Tests

    @Test("startNewConversation creates persisted Conversation record")
    func testStartNewConversationCreatesRecord() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = makeViewModel(context: context)

        let model = makeModel()
        context.insert(model)

        vm.startNewConversation(for: model)

        let descriptor = FetchDescriptor<Conversation>()
        let convs = try context.fetch(descriptor)
        #expect(convs.count == 1)
        #expect(convs[0].modelRepoId == "test/llama")
        #expect(convs[0].title == "New Conversation")
    }

    @Test("First user message triggers title generation on active conversation")
    func testFirstMessageGeneratesTitle() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = makeViewModel(context: context)

        let model = makeModel()
        context.insert(model)
        vm.startNewConversation(for: model)

        // Directly test title generation via activeConversation (avoids inference)
        vm.activeConversation?.generateTitle(from: "What is quantum computing?")
        try context.save()

        let descriptor = FetchDescriptor<Conversation>()
        let convs = try context.fetch(descriptor)
        #expect(convs.count == 1)
        #expect(convs[0].title == "What is quantum computing?")
    }

    @Test("deleteConversation clears activeConversation and messages")
    func testDeleteConversationClearsActive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = makeViewModel(context: context)

        let model = makeModel()
        context.insert(model)
        vm.startNewConversation(for: model)

        let conv = try #require(vm.activeConversation)
        vm.deleteConversation(conv)

        #expect(vm.activeConversation == nil)
        #expect(vm.messages.isEmpty)
    }

    @Test("loadMostRecentConversation restores conversation from SwiftData")
    func testLoadMostRecentConversationRestores() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = makeViewModel(context: context)

        let model = makeModel()
        context.insert(model)

        // Create a conversation with a custom title
        let conv = Conversation(modelRepoId: model.repoId, modelDisplayName: model.displayName, modelQuantization: model.quantization)
        conv.generateTitle(from: "Hello world")
        context.insert(conv)
        try context.save()

        // A fresh ViewModel should load the existing conversation
        let vm2 = ChatViewModel(
            inferenceService: InferenceService(),
            inferenceParams: .default(contextWindowCap: 2048)
        )
        vm2.loadMostRecentConversation(for: model, modelContext: context)

        #expect(vm2.activeConversation?.id == conv.id)
        #expect(vm2.activeConversation?.title == "Hello world")
    }
}
