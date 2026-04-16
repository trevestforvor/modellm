import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ChatViewModel")

enum ModelLoadState: Equatable {
    case idle
    case loading(progress: Double)
    case ready
    case failed(String)

    static func == (lhs: ModelLoadState, rhs: ModelLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready): return true
        case (.loading(let a), .loading(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

@Observable
@MainActor
final class ChatViewModel {
    // MARK: - State (observable)
    /// Completed messages — stable, not mutated during streaming
    var messages: [ChatMessage] = []
    /// The actively streaming message — rendered separately from the ForEach to avoid
    /// full array re-diffing on every token. Nil when not streaming.
    var streamingMessage: ChatMessage?
    /// Incremented on each buffer flush — drives auto-scroll in ChatView
    var streamingFlushCount: Int = 0
    private(set) var isGenerating: Bool = false
    private(set) var tokensPerSecond: Double = 0
    private(set) var loadingState: ModelLoadState = .idle
    var settings: ChatSettings = ChatSettings.load()
    /// Thinking toggle — controlled by the brain button in ChatInputBar
    var enableThinking: Bool = false

    // MARK: - Persistence
    var activeConversation: Conversation?
    var showingHistory: Bool = false
    private var modelContext: ModelContext?

    // MARK: - Backend (protocol-based — works for both local and remote)
    var backend: (any InferenceBackend)?

    // MARK: - Legacy (local model support — kept until LocalInferenceBackend ships)
    private var inferenceService: InferenceService?
    private var inferenceParams: InferenceParams?

    // MARK: - Private
    private var generationTask: Task<Void, Never>?
    private var generationStart: ContinuousClock.Instant?
    private var tokenCount: Int = 0
    private var thinkingStart: ContinuousClock.Instant?

    // Context window protection
    private var maxHistoryTokens: Int {
        Int(inferenceParams?.contextWindowTokens ?? 4096) - 512
    }

    // MARK: - Init

    /// New init for protocol-based backends (remote models)
    init(backend: any InferenceBackend) {
        self.backend = backend
        self.loadingState = .ready
    }

    /// Legacy init for local InferenceService (kept until LocalInferenceBackend ships)
    init(inferenceService: InferenceService, inferenceParams: InferenceParams) {
        self.inferenceService = inferenceService
        self.inferenceParams = inferenceParams
    }

    // MARK: - Persistence Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Conversation Management

    func startNewConversation(for selectedModel: SelectedModel) {
        guard let modelContext else { return }
        // Remove current conversation if it has no messages (user hit + without typing)
        cleanupEmptyConversation()
        let sourceLabel: String
        if case .remote(let serverID) = selectedModel.source {
            // SwiftData can't filter by UUID in predicates — fetch all and filter in memory
            let allServers = (try? modelContext.fetch(FetchDescriptor<ServerConnection>())) ?? []
            sourceLabel = allServers.first(where: { $0.id == serverID })?.name ?? "Remote"
        } else {
            sourceLabel = "On Device"
        }
        let conv = Conversation(
            modelIdentity: selectedModel.modelIdentity,
            modelDisplayName: selectedModel.displayName,
            modelSourceLabel: sourceLabel,
            enableThinking: settings.enableThinking
        )
        modelContext.insert(conv)
        try? modelContext.save()
        activeConversation = conv
        messages = []
    }

    /// Legacy: start conversation for a local DownloadedModel
    func startNewConversation(for model: DownloadedModel) {
        guard let modelContext else { return }
        cleanupEmptyConversation()
        let conv = Conversation(
            modelRepoId: model.repoId,
            modelDisplayName: model.displayName,
            modelQuantization: model.quantization
        )
        modelContext.insert(conv)
        try? modelContext.save()
        activeConversation = conv
        messages = []
    }

    func loadMostRecentConversation(forIdentity modelIdentity: String, modelContext: ModelContext) {
        self.modelContext = modelContext
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.modelIdentity == modelIdentity },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let recent = try? modelContext.fetch(descriptor).first {
            activeConversation = recent
            messages = recent.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
        }
    }

    /// Legacy: load conversation for a local DownloadedModel
    func loadMostRecentConversation(for model: DownloadedModel, modelContext: ModelContext) {
        self.modelContext = modelContext
        let repoId = model.repoId
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.modelRepoId == repoId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let recent = try? modelContext.fetch(descriptor).first {
            activeConversation = recent
            messages = recent.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
        } else {
            startNewConversation(for: model)
        }
    }

    /// Delete all conversations with no messages (avoids empty history entries)
    private func cleanupEmptyConversation() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<Conversation>()
        guard let allConversations = try? modelContext.fetch(descriptor) else { return }
        var didDelete = false
        for conv in allConversations where conv.messages.isEmpty {
            modelContext.delete(conv)
            if conv.id == activeConversation?.id {
                activeConversation = nil
            }
            didDelete = true
        }
        if didDelete { try? modelContext.save() }
    }

    func deleteConversation(_ conversation: Conversation) {
        modelContext?.delete(conversation)
        try? modelContext?.save()
        if activeConversation?.id == conversation.id {
            activeConversation = nil
            messages = []
        }
    }

    // MARK: - Public API

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Persist user message
        if let conv = activeConversation {
            let persistedUser = Message(role: "user", content: text)
            conv.messages.append(persistedUser)
            if conv.title == "New Conversation" {
                conv.generateTitle(from: text)
            }
            conv.updatedAt = Date()
            try? modelContext?.save()
        }

        isGenerating = true
        generationTask = Task { [weak self] in
            guard let self else { return }
            if self.backend != nil {
                await self.runRemoteGeneration()
            } else if self.inferenceService != nil {
                await self.runLocalGeneration()
            }
        }
    }

    func stop() {
        generationTask?.cancel()
        if let backend {
            Task { await backend.stop() }
        } else if let inferenceService {
            Task { await inferenceService.stopGeneration() }
        }
        // Finalize streaming message into messages array
        if var final = streamingMessage {
            final.isStreaming = false
            final.finalTokPerSec = tokensPerSecond
            messages.append(final)
            streamingMessage = nil
        }
        isGenerating = false
        // tok/s persists — no reset
    }

    /// Legacy: load a local GGUF model
    func loadModel(url: URL) async {
        guard let inferenceService, let inferenceParams else { return }
        loadingState = .loading(progress: 0)
        do {
            try await inferenceService.loadModel(at: url, params: inferenceParams)
            loadingState = .ready
        } catch {
            loadingState = .failed(error.localizedDescription)
            logger.error("Model load failed: \(error)")
        }
    }

    // MARK: - Remote Generation (InferenceBackend protocol)

    private func runRemoteGeneration() async {
        guard let backend else { return }

        let params = inferenceParams ?? InferenceParams.default(contextWindowCap: 4096)

        // Use streamingMessage instead of appending to messages array — avoids ForEach re-diffing
        streamingMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)

        generationStart = .now
        thinkingStart = nil
        tokenCount = 0
        tokensPerSecond = 0

        // Read from self.enableThinking — bound to the brain toggle in ChatInputBar
        let thinkingEnabled = self.enableThinking

        // All completed messages — no placeholder in the array
        let messagesToSend = messages

        let stream = backend.generate(
            messages: messagesToSend,
            params: params,
            enableThinking: thinkingEnabled
        )

        var isInThinkingPhase = false

        // Buffer tokens and flush to UI at ~20fps to avoid layout thrashing.
        // At 129 tok/s, unbuffered updates cause 129 full SwiftUI re-renders/sec
        // which freezes the main thread on ChatMessage array copies.
        var contentBuffer = ""
        var thinkingBuffer = ""
        var lastFlush = ContinuousClock.now
        let flushInterval = Duration.milliseconds(50)

        do {
            for try await token in stream {
                if Task.isCancelled { break }

                switch token {
                case .thinking(let text):
                    if thinkingEnabled {
                        if !isInThinkingPhase {
                            isInThinkingPhase = true
                            thinkingStart = .now
                        }
                        let cleaned = Self.stripStopTokens(text)
                        if !cleaned.isEmpty {
                            thinkingBuffer += cleaned
                        }
                    }
                    tokenCount += 1

                case .content(let text):
                    if isInThinkingPhase {
                        if let start = thinkingStart {
                            let elapsed = start.duration(to: .now)
                            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                            streamingMessage?.thinkingDuration = seconds
                        }
                        isInThinkingPhase = false
                        // Flush any remaining thinking buffer immediately on phase transition
                        if !thinkingBuffer.isEmpty {
                            streamingMessage?.thinkingContent += thinkingBuffer
                            thinkingBuffer = ""
                        }
                    }
                    let cleaned = Self.stripStopTokens(text)
                    if !cleaned.isEmpty {
                        contentBuffer += cleaned
                    }
                    tokenCount += 1

                case .done:
                    print("[STREAM] received .done after \(self.tokenCount) tokens")
                    break
                }

                // Flush buffers to UI at throttled rate
                let now = ContinuousClock.now
                if now - lastFlush >= flushInterval {
                    if !contentBuffer.isEmpty {
                        streamingMessage?.content += contentBuffer
                        contentBuffer = ""
                    }
                    if !thinkingBuffer.isEmpty {
                        streamingMessage?.thinkingContent += thinkingBuffer
                        thinkingBuffer = ""
                    }
                    updateToksPerSecond()
                    streamingFlushCount += 1
                    lastFlush = now
                }
            }
        } catch {
            print("[STREAM] ERROR after \(self.tokenCount) tokens: \(error)")
            if streamingMessage?.content.isEmpty == true {
                streamingMessage?.content = "Error: \(error.localizedDescription)"
            }
        }

        print("[STREAM] ended: \(self.tokenCount) tokens, cancelled=\(Task.isCancelled), contentLen=\(self.streamingMessage?.content.count ?? 0), buf=\(contentBuffer.count)")

        // Final flush — ensure all buffered tokens are rendered
        if !contentBuffer.isEmpty {
            streamingMessage?.content += contentBuffer
        }
        if !thinkingBuffer.isEmpty {
            streamingMessage?.thinkingContent += thinkingBuffer
        }
        updateToksPerSecond()
        streamingFlushCount += 1

        // Yield to let SwiftUI render the final streaming state before transitioning.
        // Without this, SwiftUI coalesces the final content update with the move to
        // messages[], and the completed bubble may render with stale layout dimensions.
        try? await Task.sleep(for: .milliseconds(50))

        // Move streaming message into completed messages array
        let assistantContent = streamingMessage?.content ?? ""
        if var final = streamingMessage {
            final.isStreaming = false
            final.finalTokPerSec = tokensPerSecond
            messages.append(final)
            streamingMessage = nil
        }
        isGenerating = false
        streamingFlushCount += 1  // trigger final scroll to completed message

        // Persist tok/s to ModelUsageStats
        if let modelContext, tokensPerSecond > 0,
           let remoteBackend = backend as? RemoteInferenceBackend {
            let identity = remoteBackend.modelIdentity
            var statsDescriptor = FetchDescriptor<ModelUsageStats>(
                predicate: #Predicate { $0.modelIdentity == identity }
            )
            statsDescriptor.fetchLimit = 1
            let stats: ModelUsageStats
            if let existing = try? modelContext.fetch(statsDescriptor).first {
                stats = existing
            } else {
                stats = ModelUsageStats(modelIdentity: identity)
                modelContext.insert(stats)
            }
            stats.recordGeneration(tokPerSec: tokensPerSecond)
            try? modelContext.save()
        }

        // tok/s persists — no reset

        // Persist assistant message
        if !assistantContent.isEmpty {
            let persistedAssistant = Message(role: "assistant", content: assistantContent)
            activeConversation?.messages.append(persistedAssistant)
            activeConversation?.updatedAt = Date()
            try? modelContext?.save()
        }
    }

    // MARK: - Local Generation (legacy — InferenceService path)

    private func runLocalGeneration() async {
        guard let inferenceService, let inferenceParams else { return }

        let isLoaded = await inferenceService.isLoaded
        guard isLoaded else {
            isGenerating = false
            return
        }

        let prompt = buildPrompt()

        // Use streamingMessage instead of appending to messages array — avoids ForEach re-diffing
        streamingMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)

        generationStart = .now
        tokenCount = 0
        tokensPerSecond = 0

        let stream = await inferenceService.generate(prompt: prompt, params: inferenceParams)

        do {
            for try await token in stream {
                if Task.isCancelled { break }
                streamingMessage?.content += token
                tokenCount += 1
                updateToksPerSecond()
            }
        } catch {
            logger.error("Generation error: \(error)")
            if var msg = streamingMessage {
                if msg.content.isEmpty {
                    msg.content = "Error: \(error.localizedDescription)"
                }
                streamingMessage = msg
            }
        }

        // Move streaming message into completed messages array
        let assistantContent = streamingMessage?.content ?? ""
        if var final = streamingMessage {
            final.isStreaming = false
            final.finalTokPerSec = tokensPerSecond
            messages.append(final)
            streamingMessage = nil
        }
        isGenerating = false
        // tok/s persists — no reset

        // Persist assistant message
        if !assistantContent.isEmpty {
            let persistedAssistant = Message(role: "assistant", content: assistantContent)
            activeConversation?.messages.append(persistedAssistant)
            activeConversation?.updatedAt = Date()
            try? modelContext?.save()
        }
    }

    // MARK: - Prompt Building (legacy local path)

    private func buildPrompt() -> String {
        guard let inferenceParams else { return "" }
        let maxChars = maxHistoryTokens * 4
        var historyMessages = messages.filter { $0.role == .user || ($0.role == .assistant && !$0.isStreaming) }

        var totalChars = historyMessages.reduce(0) { $0 + $1.content.count }
        while totalChars > maxChars && historyMessages.count > 2 {
            let removed = historyMessages.removeFirst()
            totalChars -= removed.content.count
        }

        return PromptFormatter.chatml(system: inferenceParams.systemPrompt, messages: historyMessages)
    }

    // MARK: - Token Cleanup

    /// Strip ChatML stop tokens that some models output as visible text
    private static let stopTokenPatterns = ["<|im_end|>", "<|im_start|>", "<|endoftext|>", "</s>"]

    private static func stripStopTokens(_ text: String) -> String {
        var result = text
        for pattern in stopTokenPatterns {
            result = result.replacingOccurrences(of: pattern, with: "")
        }
        return result
    }

    // MARK: - Tok/s

    private func updateToksPerSecond() {
        guard let start = generationStart else { return }
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        if seconds > 0 {
            tokensPerSecond = Double(tokenCount) / seconds
        }
    }

}
