import Foundation
import OSLog

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
/// When the llama.cpp XCFramework is linked, replace the stub implementations
/// with actual C API calls:
///   - llama_load_model_from_file(url.path, modelParams) → self.model
///   - llama_new_context_with_model(model, ctxParams) → self.ctx
///   - deinit: llama_free(ctx); llama_free_model(model)
///
/// - Note: LlamaFramework import is staged — uncomment `import LlamaFramework`
///   after the XCFramework binary target is linked to the ModelRunner target.
final class LlamaSession {

    // MARK: - Stored Properties

    let modelURL: URL
    let params: InferenceParams
    /// Checked by the decode loop to exit after the current token.
    var isCancelled: Bool = false

    // MARK: - llama.cpp C Pointers (staged — populated after XCFramework linked)
    //
    // private var model: OpaquePointer?  // llama_model*
    // private var ctx: OpaquePointer?    // llama_context*

    // MARK: - Init

    /// Load a GGUF model from disk and allocate the KV cache context.
    ///
    /// - Throws: `InferenceError.modelLoadFailed` if file is missing or unreadable.
    ///           `InferenceError.contextCreationFailed` if context allocation fails (OOM).
    init(modelURL: URL, params: InferenceParams) throws {
        self.modelURL = modelURL
        self.params = params

        // Guard: file must exist on disk before we attempt to load.
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw InferenceError.modelLoadFailed("File not found: \(modelURL.lastPathComponent)")
        }

        sessionLogger.info("LlamaSession: model file found at \(modelURL.lastPathComponent)")

        // --- XCFramework integration point ---
        // When LlamaFramework is linked, replace this block with:
        //
        //   llama_backend_init()
        //
        //   var modelParams = llama_model_default_params()
        //   modelParams.n_gpu_layers = params.gpuLayers
        //   guard let model = llama_load_model_from_file(modelURL.path, modelParams) else {
        //       throw InferenceError.modelLoadFailed("llama_load_model_from_file returned nil")
        //   }
        //   self.model = model
        //
        //   var ctxParams = llama_context_default_params()
        //   ctxParams.n_ctx = UInt32(params.contextWindowTokens)
        //   ctxParams.n_batch = UInt32(params.batchSize)
        //   guard let ctx = llama_new_context_with_model(model, ctxParams) else {
        //       llama_free_model(model)
        //       throw InferenceError.contextCreationFailed
        //   }
        //   self.ctx = ctx
        //
        // Until then: session is a valid stub (file exists, no C pointers allocated).
    }

    // MARK: - Decode Loop Stub

    /// Generate tokens by running the llama.cpp decode loop.
    ///
    /// When LlamaFramework is linked, replace this stub with:
    ///   1. llama_tokenize(ctx, prompt, tokens, maxTokens, addBos: true)
    ///   2. llama_batch_init(batchSize, 0, 1)
    ///   3. for each batch: llama_decode(ctx, batch)
    ///   4. llama_sampler_sample → token
    ///   5. if token == llama_token_eos(model) → break
    ///   6. llama_token_to_piece(ctx, token) → String → yield via continuation
    ///   7. if isCancelled → break
    ///
    /// - Parameter prompt: Fully formatted prompt string (e.g., from PromptFormatter.chatml).
    /// - Parameter continuation: AsyncThrowingStream continuation to yield tokens into.
    func runDecodeLoop(
        prompt: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        // Stub: no XCFramework linked yet. Finish immediately with no tokens.
        // This is correct for unit tests that verify state (no model = no tokens).
        sessionLogger.info("LlamaSession.runDecodeLoop: XCFramework not yet linked — finishing stream immediately")
        continuation.finish()
    }

    // MARK: - Deinit

    deinit {
        // When LlamaFramework is linked:
        //   if let ctx { llama_free(ctx) }
        //   if let model { llama_free_model(model) }
        sessionLogger.debug("LlamaSession deallocated: \(self.modelURL.lastPathComponent)")
    }
}
