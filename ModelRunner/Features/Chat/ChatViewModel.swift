import Foundation
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
    private(set) var messages: [ChatMessage] = []
    private(set) var isGenerating: Bool = false
    private(set) var tokensPerSecond: Double = 0
    private(set) var loadingState: ModelLoadState = .idle
    var settings: ChatSettings = ChatSettings.load()

    // MARK: - Private
    private let inferenceService: InferenceService
    private let inferenceParams: InferenceParams
    private var generationTask: Task<Void, Never>?
    private var generationStart: ContinuousClock.Instant?
    private var tokenCount: Int = 0

    // Context window protection: max tokens to keep in history
    // Conservative: reserve 512 tokens for the new response
    private var maxHistoryTokens: Int { Int(inferenceParams.contextWindowTokens) - 512 }

    init(inferenceService: InferenceService, inferenceParams: InferenceParams) {
        self.inferenceService = inferenceService
        self.inferenceParams = inferenceParams
    }

    // MARK: - Public API

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        isGenerating = true
        generationTask = Task {
            await self.runGeneration()
        }
    }

    func stop() {
        generationTask?.cancel()
        Task {
            await inferenceService.stopGeneration()
        }
        // Mark last assistant message as no longer streaming
        if let idx = messages.indices.last, messages[idx].role == .assistant {
            messages[idx].isStreaming = false
        }
        isGenerating = false
        resetTokSAfterDelay()
    }

    func loadModel(url: URL) async {
        loadingState = .loading(progress: 0)
        do {
            try await inferenceService.loadModel(at: url, params: inferenceParams)
            loadingState = .ready
        } catch {
            loadingState = .failed(error.localizedDescription)
            logger.error("Model load failed: \(error)")
        }
    }

    // MARK: - Private

    private func runGeneration() async {
        // Ensure model is loaded
        let isLoaded = await inferenceService.isLoaded
        guard isLoaded else {
            isGenerating = false
            return
        }

        // Build prompt with context window protection
        let prompt = buildPrompt()

        // Add streaming assistant message placeholder
        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.endIndex - 1

        // Reset tok/s tracking
        generationStart = .now
        tokenCount = 0
        tokensPerSecond = 0

        let stream = await inferenceService.generate(prompt: prompt)

        do {
            for try await token in stream {
                if Task.isCancelled { break }
                messages[assistantIndex].content += token
                tokenCount += 1
                updateToksPerSecond()
            }
        } catch {
            logger.error("Generation error: \(error)")
        }

        messages[assistantIndex].isStreaming = false
        isGenerating = false
        resetTokSAfterDelay()
    }

    private func buildPrompt() -> String {
        // Apply context window protection by rough character count
        // Heuristic: ~4 chars per token
        let maxChars = maxHistoryTokens * 4
        var historyMessages = messages.filter { $0.role == .user || ($0.role == .assistant && !$0.isStreaming) }

        // Trim oldest pairs until within budget
        var totalChars = historyMessages.reduce(0) { $0 + $1.content.count }
        while totalChars > maxChars && historyMessages.count > 2 {
            let removed = historyMessages.removeFirst()
            totalChars -= removed.content.count
        }

        return PromptFormatter.chatml(system: settings.systemPrompt, messages: historyMessages)
    }

    private func updateToksPerSecond() {
        guard let start = generationStart else { return }
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        if seconds > 0 {
            tokensPerSecond = Double(tokenCount) / seconds
        }
    }

    private func resetTokSAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            tokensPerSecond = 0
        }
    }
}
