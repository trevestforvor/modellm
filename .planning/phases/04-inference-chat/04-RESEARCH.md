# Phase 4: Inference + Chat — Research

**Researched:** 2026-04-09
**Phase Goal:** Users can have a streaming conversation with a downloaded model entirely on-device
**Requirements covered:** CHAT-01, CHAT-02, CHAT-03, CHAT-06

---

## Standard Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| Inference engine | llama.cpp XCFramework binary target (b5046+) | Already established in STACK.md. Binary target avoids `unsafeFlags`. |
| Streaming output | `AsyncThrowingStream<String, Error>` | Bridge llama.cpp C callback → Swift continuation |
| Inference isolation | Swift `actor` or `Task.detached` | Never run on MainActor — CHAT-06 |
| Chat state | `@Observable ChatViewModel` | iOS 17+ pattern, already established in AppContainer |
| Markdown rendering | `AttributedString` + custom render pass | No third-party markdown lib required for v1 scope |
| Conversation persistence | In-memory `[ChatMessage]` array (v1) | History persistence is v2 (CHAT-04). No SwiftData for messages in Phase 4. |
| System prompt storage | `UserDefaults` | Simple key-value, no schema needed for a string |
| Tok/s measurement | `ContinuousClock` + token counter in InferenceService | No library needed |

---

## Architecture Patterns

### 1. InferenceService as Actor

```swift
actor InferenceService {
    private var loadedModel: LlamaModel?  // wraps llama_model*
    private var activeSession: LlamaSession?  // wraps llama_context*

    // CRITICAL: One session per loaded model. Do NOT recreate per message.
    func loadModel(at url: URL, params: InferenceParams) async throws
    func generate(prompt: String) -> AsyncThrowingStream<String, Error>
    func stopGeneration()
    func unloadModel() async
}
```

**Why actor:** Prevents data races on `llama_model` and `llama_context` pointers across concurrent Swift tasks. Inference is inherently serial per context.

### 2. AsyncThrowingStream Token Bridge

```swift
// InferenceService.swift
func generate(prompt: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { continuation.finish(); return }
            // Format prompt using model's chat template
            // Run llama_decode() in loop, call continuation.yield(tokenString)
            // On stop: continuation.finish()
            // On error: continuation.finish(throwing: error)
        }
    }
}
```

**Key pattern:** `Task.detached` ensures inference never runs on MainActor even if `generate()` is called from a MainActor context (CHAT-06).

### 3. ChatViewModel iterates stream

```swift
@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isGenerating = false
    var tokensPerSecond: Double = 0
    var loadingState: ModelLoadState = .idle

    private var generationTask: Task<Void, Never>?

    func send(text: String) {
        generationTask = Task {
            // Load model if needed
            // Append user message
            // Append empty assistant message
            var tokenCount = 0
            let start = ContinuousClock.now
            for try await token in inferenceService.generate(prompt: buildPrompt()) {
                messages[messages.endIndex - 1].content += token
                tokenCount += 1
                tokensPerSecond = Double(tokenCount) / ContinuousClock.now.duration(to: start).seconds
            }
        }
    }

    func stop() {
        generationTask?.cancel()
        inferenceService.stopGeneration()  // signals C loop to exit
    }
}
```

### 4. Prompt Formatting

```swift
// Format as chatml or llama-3-instruct depending on model metadata
// For v1: use chatml as default, let user override system prompt
struct PromptFormatter {
    static func chatml(system: String, messages: [ChatMessage]) -> String {
        var result = "<|im_start|>system\n\(system)<|im_end|>\n"
        for message in messages {
            let role = message.role == .user ? "user" : "assistant"
            result += "<|im_start|>\(role)\n\(message.content)<|im_end|>\n"
        }
        result += "<|im_start|>assistant\n"
        return result
    }
}
```

**For v1:** Use ChatML as the default template. Most GGUF models on HF support it. Model-specific template detection is v2.

### 5. llama.cpp XCFramework Integration

The XCFramework exposes a C API. Key initialization sequence:

```swift
// Pseudocode — actual API requires reading XCFramework headers
// Step 1: Load model
var modelParams = llama_model_default_params()
modelParams.n_gpu_layers = 99  // offload all layers to Metal GPU
let model = llama_load_model_from_file(url.path, modelParams)

// Step 2: Create context (KV cache allocated here — expensive)
var ctxParams = llama_context_default_params()
ctxParams.n_ctx = UInt32(contextWindowCap)  // from ChipProfile.contextWindowCap
ctxParams.n_batch = 512
let ctx = llama_new_context_with_model(model, ctxParams)

// Step 3: Tokenize + decode loop (in Task.detached)
// Step 4: Unload on model switch
llama_free(ctx)
llama_free_model(model)
```

**Important:** `n_ctx` should use `ChipProfile.contextWindowCap` already defined in `CompatibilityModels.swift`. This is the integration point from Phase 1.

**BLOCKER from STATE.md:** llama.cpp XCFramework Swift API surface (b5046+) should be confirmed from XCFramework headers before writing InferenceService. Plan should include a task to read actual headers.

---

## Don't Hand-Roll

| Problem | Use Instead |
|---------|-------------|
| Markdown parsing | `AttributedString(markdown:)` — handles bold, italic, code spans natively |
| Code block rendering | SwiftUI `.monospaced()` + background color — no library needed |
| Tok/s calculation | `ContinuousClock` — already in Swift stdlib |
| Token streaming coordination | `AsyncThrowingStream` — already in Swift stdlib |
| System prompt storage | `UserDefaults` — not worth a SwiftData model |
| Thread safety on llama context | Swift `actor` — not a manual lock/mutex |

---

## Common Pitfalls

### 1. Context-Per-Message (Critical)
Creating a new `llama_context` per message takes 3-10 seconds and allocates the full KV cache each time. **Keep one session resident per loaded model. Tear it down only when the user switches models.**

### 2. MainActor Inference (CHAT-06 Killer)
Calling `llama_decode()` on the main thread freezes the UI between every token. **Always `Task.detached(priority: .userInitiated)`.**

### 3. Continuation Leak
If `generate()` throws before starting the decode loop, the `AsyncThrowingStream` continuation must be finished. Missing `continuation.finish(throwing:)` in error paths causes the caller to hang indefinitely.

### 4. Token-to-String Conversion
`llama_token_to_piece()` returns a C string that may be empty for special tokens (BOS, EOS). Filter empty strings before yielding to the stream. Also, EOS token signals completion — do not yield it, do call `continuation.finish()`.

### 5. Stop Signal Race
Calling `stopGeneration()` must atomically set a flag that the decode loop checks after each token. Using `Task.cancel()` alone is insufficient because llama.cpp's C loop doesn't check Swift cooperative cancellation. Use a dedicated `@Sendable` atomic or actor-isolated boolean.

### 6. Context Window Overflow
If conversation history exceeds `n_ctx` tokens, llama.cpp will error. For v1: truncate from the oldest messages when approaching the limit. The `ChipProfile.contextWindowCap` value (from Phase 1) is the ceiling.

### 7. Memory Pressure on Load
Model loading on A14/A15 (4GB RAM) with a Q4_K_M 3B model consumes ~2.5GB. iOS may Jetsam the app if background processes are heavy. Show loading progress with a timeout (30s) and surface a friendly error if load fails.

---

## Validation Architecture

### Integration Test Strategy
llama.cpp inference cannot be unit tested without a real GGUF file. Tests that require inference must be integration tests run on physical device.

```
Wave 0: Unit tests (no model file needed)
  - PromptFormatter: chatml output format
  - ChatViewModel: state transitions (idle → loading → generating → idle)
  - InferenceParams: context window cap derived from ChipProfile
  - ToksPerSecond: calculation math

Wave 1: Integration (requires GGUF file — skip in CI)
  - InferenceService.loadModel: loads without crash
  - InferenceService.generate: stream yields tokens
  - InferenceService.stopGeneration: cancels cleanly
```

### Grep-Verifiable Acceptance Conditions
- `grep -r "Task.detached" ModelRunner/Services/Inference/` — inference runs off MainActor
- `grep -r "AsyncThrowingStream" ModelRunner/Services/Inference/` — streaming pattern used
- `grep -r "ChatViewModel" ModelRunner/Features/Chat/` — ViewModel exists
- `grep -r "n_gpu_layers" ModelRunner/` — Metal GPU offload configured
- `grep -r "isGenerating" ModelRunner/Features/Chat/` — UI can observe generation state

---

## Code Examples

### ChatMessage model

```swift
enum MessageRole: String, Codable { case user, assistant }

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    var content: String
    var isStreaming: Bool = false
}
```

### Tok/s display timing

```swift
// In ChatViewModel, on MainActor
private var generationStart: ContinuousClock.Instant?
private var tokenCount: Int = 0

// On first token:
generationStart = .now
tokenCount = 0

// Per token:
tokenCount += 1
if let start = generationStart {
    let elapsed = start.duration(to: .now).components.seconds
    if elapsed > 0 {
        tokensPerSecond = Double(tokenCount) / Double(elapsed)
    }
}

// 2 seconds after stream ends: fade tokensPerSecond display
```

### Markdown rendering (v1 approach)

```swift
// For simple cases, AttributedString handles bold/italic/code spans
// Code blocks need a custom view since AttributedString doesn't style backgrounds
struct AssistantBubbleContent: View {
    let text: String

    var body: some View {
        // Split on code fences, render each segment
        // Text segments: AttributedString(markdown:)
        // Code blocks: monospaced Text with #0D0C18 background
    }
}
```

---

## Phase Boundary Confirmation

**In scope (Phase 4):**
- InferenceService actor with llama.cpp XCFramework
- ChatViewModel with streaming state
- ChatView: bubble UI, streaming cursor, tok/s badge
- Model loading state UI (progress ring)
- System prompt settings (presets + editable field)
- Stop/send button swap during generation
- Offline-only operation (CHAT-03 — no network calls during inference)

**Out of scope (future):**
- Chat history persistence across sessions (CHAT-04, Phase 5)
- Inference parameter UI — temperature/top-p (CHAT-05, Phase 5)
- Multi-model switching mid-conversation
- Chat export

---

## Sources

- `.planning/research/ARCHITECTURE.md` — InferenceService component definition, anti-patterns (HIGH confidence — project-established)
- `.planning/research/STACK.md` — llama.cpp XCFramework integration, binary target, token streaming pattern (HIGH confidence — project-established)
- `DESIGN.md` — Chat UI spec: bubble colors, input bar, loading state (HIGH confidence — project-established)
- `.planning/phases/04-inference-chat/04-CONTEXT.md` — Implementation decisions D-01 through D-14 (HIGH confidence — user decisions)
- `ModelRunner/App/AppContainer.swift` — Existing service pattern, @Observable (HIGH confidence — codebase)
- `ModelRunner/Services/Device/CompatibilityModels.swift` — ChipProfile.contextWindowCap integration point (HIGH confidence — codebase)
- llama.cpp anti-pattern: context per message — HIGH confidence (documented in ARCHITECTURE.md, confirmed in community discussions)
- Swift `AsyncThrowingStream` continuation bridging — HIGH confidence (Swift stdlib, standard pattern)

## RESEARCH COMPLETE

Phase 4 is well-understood from prior research artifacts. Key findings:
1. InferenceService must be an `actor` — prevents KV cache race conditions
2. `Task.detached` is mandatory for CHAT-06 (UI responsiveness)
3. llama.cpp XCFramework C API headers must be read before writing InferenceService (confirmed blocker from STATE.md)
4. ConversationStore is in-memory only for v1 — no SwiftData schema changes needed
5. Markdown rendering via `AttributedString` + custom code block view — no third-party dependency
6. Stop signal needs an actor-isolated boolean, not just Task cancellation
