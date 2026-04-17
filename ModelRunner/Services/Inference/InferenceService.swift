import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "InferenceService")

/// Manages llama.cpp model loading and token-streaming inference.
///
/// Actor isolation prevents concurrent access to the llama_context* (KV cache races).
/// All generation runs on Task.detached — never on MainActor (CHAT-06).
///
/// Usage pattern:
/// ```swift
/// let service = InferenceService()
/// try await service.loadModel(at: ggufURL, params: .default(contextWindowCap: 2048))
/// for try await token in await service.generate(prompt: formattedPrompt) {
///     // append token to UI message on MainActor
/// }
/// ```
public actor InferenceService {

    // MARK: - State

    private var session: LlamaSession?
    /// Stop signal for the decode loop. Checked after each token.
    /// Using actor-isolated boolean, not Task.cancel() alone — the C decode loop
    /// does not check Swift cooperative cancellation.
    private var isCancelled: Bool = false

    // MARK: - Init

    public init() {}

    // MARK: - Model Management

    /// Load a GGUF model from disk. Allocates the KV cache — may take 2–30 seconds.
    ///
    /// Call from ChatViewModel before the first generate() invocation.
    /// If a model is already loaded, it is unloaded first.
    ///
    /// - Parameters:
    ///   - url: Path to a .gguf file in the app's documents directory.
    ///   - params: Inference parameters (contextWindowTokens from ChipProfile.contextWindowCap).
    /// - Throws: `InferenceError.modelLoadFailed` or `InferenceError.contextCreationFailed`.
    public func loadModel(at url: URL, params: InferenceParams) async throws {
        if session != nil {
            await unloadModel()
        }
        isCancelled = false
        logger.info("Loading model: \(url.lastPathComponent)")
        session = try LlamaSession(modelURL: url, params: params)
        logger.info("Model loaded successfully: \(url.lastPathComponent)")
    }

    /// Unload the current model and free its memory.
    /// Safe to call when no model is loaded.
    public func unloadModel() async {
        session = nil  // triggers LlamaSession.deinit → llama_free / llama_free_model
        logger.info("Model unloaded")
    }

    /// Whether a model is currently loaded and ready for inference.
    public var isLoaded: Bool { session != nil }

    // MARK: - Inference

    /// Stream token strings from the loaded model.
    ///
    /// Inference runs on `Task.detached(priority: .userInitiated)` so the MainActor
    /// is never blocked between tokens (CHAT-06).
    ///
    /// Pass current model params so temperature/top-p changes take effect on the next
    /// generate() call without reloading the 2–4 GB model from disk.
    ///
    /// The caller should iterate on a non-MainActor task:
    /// ```swift
    /// Task {
    ///     for try await token in await inferenceService.generate(prompt: prompt, params: params) {
    ///         await MainActor.run { message.content += token }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter prompt: Fully formatted prompt (e.g., PromptFormatter.chatml output).
    /// - Parameter params: Current inference parameters — sampler chain built fresh per call.
    /// - Returns: Async stream of token strings. Finishes normally at EOS, or throws on error.
    public func generate(prompt: String, params: InferenceParams) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { [weak self] continuation in
            guard let self else {
                continuation.finish(throwing: InferenceError.noActiveSession)
                return
            }
            Task.detached(priority: .userInitiated) {
                // Capture session reference inside actor isolation
                guard let session = await self.session else {
                    continuation.finish(throwing: InferenceError.noActiveSession)
                    return
                }
                await self.setNotCancelled()
                // Pass params to decode loop — sampler chain built fresh each invocation
                // so temperature/topP changes from ChatSettingsView take effect immediately.
                session.runDecodeLoop(prompt: prompt, params: params, continuation: continuation)
            }
        }
    }

    /// Format messages using the currently loaded model's embedded chat template.
    /// Falls back to ChatML when no model is loaded or the file has no template.
    public func formatPrompt(system: String, messages: [ChatMessage]) -> String {
        guard let session else {
            return PromptFormatter.chatml(system: system, messages: messages)
        }
        return session.formatPrompt(system: system, messages: messages)
    }

    /// Signal the decode loop to stop after the current token.
    ///
    /// Also cancel the outer Task to stop the continuation from being held open.
    /// This is an actor-isolated flag — the C decode loop reads `session.isCancelled`
    /// after each token, which is set here via the actor isolation boundary.
    public func stopGeneration() {
        isCancelled = true
        session?.isCancelled = true
        logger.info("Stop signal sent to decode loop")
    }

    // MARK: - Private

    private func setNotCancelled() {
        isCancelled = false
        session?.isCancelled = false
    }
}
