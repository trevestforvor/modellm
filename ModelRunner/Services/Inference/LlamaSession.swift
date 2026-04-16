import Foundation
import OSLog
import llama

// MARK: - Inference Errors

/// Errors surfaced by the inference pipeline.
public enum InferenceError: LocalizedError, Equatable {
    /// Model file could not be loaded (missing, corrupt, or unsupported format).
    case modelLoadFailed(String)
    /// llama_context creation failed (likely OOM — model too large for device RAM).
    case contextCreationFailed
    /// Input prompt could not be tokenized.
    case tokenizationFailed
    /// generate() was called before loadModel().
    case noActiveSession

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let msg): return "Failed to load model: \(msg)"
        case .contextCreationFailed: return "Failed to create inference context (out of memory?)"
        case .tokenizationFailed: return "Failed to tokenize input"
        case .noActiveSession: return "No model loaded — call loadModel() first"
        }
    }

    public static func == (lhs: InferenceError, rhs: InferenceError) -> Bool {
        switch (lhs, rhs) {
        case (.modelLoadFailed(let a), .modelLoadFailed(let b)): return a == b
        case (.contextCreationFailed, .contextCreationFailed): return true
        case (.tokenizationFailed, .tokenizationFailed): return true
        case (.noActiveSession, .noActiveSession): return true
        default: return false
        }
    }
}

// MARK: - LlamaSession

private let sessionLogger = Logger(subsystem: "com.modelrunner", category: "LlamaSession")

/// Wraps llama_model* and llama_context* lifetime.
///
/// NOT Sendable — accessed exclusively through the InferenceService actor.
final class LlamaSession {

    // MARK: - Stored Properties

    let modelURL: URL
    let params: InferenceParams
    /// Checked by the decode loop to exit after the current token.
    var isCancelled: Bool = false

    // MARK: - llama.cpp C Pointers

    private var model: OpaquePointer?  // llama_model* (incomplete type → OpaquePointer)
    private var ctx: OpaquePointer?    // llama_context* (incomplete type → OpaquePointer)

    // MARK: - Init

    /// Load a GGUF model from disk and allocate the KV cache context.
    ///
    /// - Throws: `InferenceError.modelLoadFailed` if file is missing or unreadable.
    ///           `InferenceError.contextCreationFailed` if context allocation fails (OOM).
    init(modelURL: URL, params: InferenceParams) throws {
        self.modelURL = modelURL
        self.params = params

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw InferenceError.modelLoadFailed("File not found: \(modelURL.lastPathComponent)")
        }

        llama_backend_init()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = params.gpuLayers
        guard let loadedModel = llama_model_load_from_file(modelURL.path, modelParams) else {
            throw InferenceError.modelLoadFailed(
                "llama_model_load_from_file returned nil for \(modelURL.lastPathComponent)"
            )
        }
        self.model = loadedModel
        sessionLogger.info("Model loaded: \(modelURL.lastPathComponent)")

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(params.contextWindowTokens)
        ctxParams.n_batch = UInt32(params.batchSize)
        guard let newCtx = llama_new_context_with_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            self.model = nil
            throw InferenceError.contextCreationFailed
        }
        self.ctx = newCtx
        sessionLogger.info("Context created: n_ctx=\(params.contextWindowTokens), n_batch=\(params.batchSize)")
    }

    // MARK: - Sampler Chain

    /// Build a sampler chain from InferenceParams.
    ///
    /// Called at the start of each generate() call — NOT at init time.
    /// This allows temperature/top-p changes to take effect without reloading
    /// the model from disk.
    ///
    /// Ordering: top-p filters the distribution first, then temperature scales it.
    func buildSamplerChain(params: InferenceParams) -> UnsafeMutablePointer<llama_sampler>? {
        let sparams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(sparams) else { return nil }
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(params.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(params.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
        return chain
    }

    // MARK: - Decode Loop

    /// Generate tokens by running the llama.cpp decode loop.
    ///
    /// - Parameter prompt: Fully formatted prompt string (e.g., from PromptFormatter.chatml).
    /// - Parameter params: Inference parameters — used to build sampler chain per invocation.
    /// - Parameter continuation: AsyncThrowingStream continuation to yield tokens into.
    func runDecodeLoop(
        prompt: String,
        params: InferenceParams,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        guard let model, let ctx else {
            continuation.finish(throwing: InferenceError.noActiveSession)
            return
        }

        // Build sampler chain per generate() call — not at init.
        // This ensures temperature/topP changes from ChatSettingsView take effect immediately.
        let chain = buildSamplerChain(params: params)
        defer { if let chain { llama_sampler_free(chain) } }

        guard let chain else {
            continuation.finish(throwing: InferenceError.noActiveSession)
            return
        }

        // Get vocab for tokenization and EOS checks
        guard let vocab = llama_model_get_vocab(model) else {
            continuation.finish(throwing: InferenceError.tokenizationFailed)
            return
        }

        // Tokenize the prompt
        let promptBytes = Array(prompt.utf8)
        let maxTokens = Int32(promptBytes.count) + 256
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let nTokens = llama_tokenize(
            vocab, prompt, Int32(promptBytes.count),
            &tokens, maxTokens, true, true
        )
        guard nTokens > 0 else {
            continuation.finish(throwing: InferenceError.tokenizationFailed)
            return
        }
        tokens = Array(tokens.prefix(Int(nTokens)))

        sessionLogger.info("Tokenized prompt: \(nTokens) tokens")

        // Process prompt using batch_get_one (simpler API for single-sequence)
        var tokenArray = tokens  // mutable copy for pointer
        let promptBatch = llama_batch_get_one(&tokenArray, nTokens)
        if llama_decode(ctx, promptBatch) != 0 {
            sessionLogger.error("Failed to decode prompt batch")
            continuation.finish(throwing: InferenceError.tokenizationFailed)
            return
        }

        // Generate tokens one at a time
        var nGenerated: Int32 = 0
        let nCtx = Int32(params.contextWindowTokens)

        while !isCancelled {
            let newToken = llama_sampler_sample(chain, ctx, -1)

            // Check for end of generation
            if llama_vocab_is_eog(vocab, newToken) {
                sessionLogger.info("EOS reached after \(nGenerated) tokens")
                break
            }

            // Convert token to string piece
            var buf = [CChar](repeating: 0, count: 256)
            let nChars = llama_token_to_piece(vocab, newToken, &buf, Int32(buf.count), 0, true)
            if nChars > 0 {
                buf[Int(nChars)] = 0  // null terminate
                let piece = String(cString: buf)
                continuation.yield(piece)
            }

            // Decode the single new token
            var singleToken = [newToken]
            let nextBatch = llama_batch_get_one(&singleToken, 1)
            if llama_decode(ctx, nextBatch) != 0 {
                sessionLogger.error("Decode failed at token \(nGenerated)")
                break
            }

            nGenerated += 1

            // Context window check
            if nTokens + nGenerated >= nCtx {
                sessionLogger.warning("Context window full at \(nTokens + nGenerated) tokens")
                break
            }
        }

        continuation.finish()
        sessionLogger.info("Generation complete: \(nGenerated) tokens generated")
    }

    // MARK: - Deinit

    deinit {
        if let ctx { llama_free(ctx) }
        if let model { llama_model_free(model) }
        llama_backend_free()
        sessionLogger.debug("LlamaSession deallocated: \(self.modelURL.lastPathComponent)")
    }
}
