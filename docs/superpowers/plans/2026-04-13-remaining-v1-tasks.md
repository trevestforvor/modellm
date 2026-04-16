# Remaining V1 Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up llama.cpp for on-device inference, integrate LibraryView into the Models tab, create LocalInferenceBackend, and fix remaining audit items — getting the app to a functional v1 (excluding onboarding and HF API testing)

**Architecture:** Download llama.cpp XCFramework binary, replace LlamaSession stubs with real C API calls, wrap InferenceService behind InferenceBackend protocol as LocalInferenceBackend, integrate LibraryView as a section in ModelsTabView, fix remaining audit ship-blockers

**Tech Stack:** llama.cpp b8772 XCFramework, Swift/C interop via Clang module map, SwiftUI, SwiftData

**Exclusions:** Onboarding flow update (later), HF API wiring/testing (needs token), HF Browse functionality (separate effort)

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `Frameworks/llama.xcframework/` | Prebuilt llama.cpp binary (downloaded from GitHub releases) |
| `ModelRunner/Services/Inference/Backends/LocalInferenceBackend.swift` | Wraps InferenceService behind InferenceBackend protocol |

### Modified Files

| File | Changes |
|------|---------|
| `ModelRunner/Services/Inference/LlamaSession.swift` | Replace stubs with real llama.cpp C API calls |
| `ModelRunner/Features/Models/ModelsTabView.swift` | Add LibraryView content as a section below My Models |
| `ModelRunner/App/AppContainer.swift` | Add `buildLocalBackend` method |
| `ModelRunner/ContentView.swift` | Use `buildLocalBackend` when local model tapped |
| `ModelRunner/Features/Chat/ChatView.swift` | Fix `showSettings` dead trigger (UX audit) |
| `ModelRunner/Features/Chat/ChatViewModel.swift` | Surface local generation errors in message content |

---

## Task 1: Download and Link llama.cpp XCFramework

**Files:**
- Create: `Frameworks/llama.xcframework/` (downloaded binary)
- Modify: Xcode project settings

- [ ] **Step 1: Download the XCFramework**

```bash
mkdir -p Frameworks
cd Frameworks
curl -L -o llama-xcframework.zip "https://github.com/ggml-org/llama.cpp/releases/download/b8772/llama-b8772-xcframework.zip"
unzip llama-xcframework.zip
rm llama-xcframework.zip
cd ..
```

Expected: `Frameworks/llama.xcframework/` directory with `ios-arm64/`, `ios-arm64_x86_64-simulator/`, etc.

- [ ] **Step 2: Add XCFramework to Xcode project**

Open the Xcode project and:
1. Drag `Frameworks/llama.xcframework` into the project navigator under a "Frameworks" group
2. In target → General → Frameworks, Libraries, and Embedded Content: set `llama.xcframework` to **Embed & Sign**
3. Ensure `Accelerate.framework` and `Metal.framework` are linked (they should already be for an iOS project)

Alternatively, use `xcodebuild` settings or edit `project.pbxproj` programmatically.

- [ ] **Step 3: Verify the framework imports**

Create a test file or add to an existing file:
```swift
import llama
// If this compiles, the XCFramework is properly linked
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Frameworks/llama.xcframework ModelRunner.xcodeproj
git commit -m "feat: add llama.cpp b8772 XCFramework for on-device inference"
```

Note: The XCFramework is ~179MB. Consider adding it to `.gitignore` and documenting the download in README if repo size is a concern. For now, commit it directly.

---

## Task 2: Implement LlamaSession with Real C API Calls

**Files:**
- Modify: `ModelRunner/Services/Inference/LlamaSession.swift`

The current file has detailed comments showing exactly which C API calls to make. Replace the stubs.

- [ ] **Step 1: Replace the entire LlamaSession implementation**

Replace `ModelRunner/Services/Inference/LlamaSession.swift` with the real implementation. Key changes:

```swift
import Foundation
import OSLog
import llama

// Keep the existing InferenceError enum unchanged.

final class LlamaSession {
    let modelURL: URL
    let params: InferenceParams
    var isCancelled: Bool = false

    private var model: OpaquePointer?   // llama_model*
    private var ctx: OpaquePointer?     // llama_context*

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
            throw InferenceError.modelLoadFailed("llama_model_load_from_file returned nil")
        }
        self.model = loadedModel

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(params.contextWindowTokens)
        ctxParams.n_batch = UInt32(params.batchSize)
        guard let newCtx = llama_new_context_with_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            throw InferenceError.contextCreationFailed
        }
        self.ctx = newCtx
    }

    func buildSamplerChain(params: InferenceParams) -> OpaquePointer? {
        let sparams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(sparams) else { return nil }
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(params.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(params.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.max))
        return chain
    }

    func runDecodeLoop(
        prompt: String,
        params: InferenceParams,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        guard let model, let ctx else {
            continuation.finish(throwing: InferenceError.noActiveSession)
            return
        }

        let chain = buildSamplerChain(params: params)
        defer { if let chain { llama_sampler_free(chain) } }

        // Tokenize
        let promptCStr = prompt.utf8CString
        let maxTokens = Int32(promptCStr.count) + 128
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let nTokens = llama_tokenize(model, prompt, Int32(prompt.utf8.count), &tokens, maxTokens, true, true)
        guard nTokens > 0 else {
            continuation.finish(throwing: InferenceError.tokenizationFailed)
            return
        }
        tokens = Array(tokens.prefix(Int(nTokens)))

        // Create batch and process prompt
        var batch = llama_batch_init(Int32(params.batchSize), 0, 1)
        defer { llama_batch_free(batch) }

        // Fill batch with prompt tokens
        for (i, token) in tokens.enumerated() {
            llama_batch_add(&batch, token, Int32(i), [0], i == tokens.count - 1)
        }

        if llama_decode(ctx, batch) != 0 {
            continuation.finish(throwing: InferenceError.tokenizationFailed)
            return
        }

        // Generate tokens
        var nGenerated: Int32 = 0
        let nCtx = Int32(params.contextWindowTokens)

        while !isCancelled {
            guard let chain else { break }

            let newToken = llama_sampler_sample(chain, ctx, -1)

            // Check for EOS
            if llama_vocab_is_eog(model, newToken) { break }

            // Convert token to string
            var buf = [CChar](repeating: 0, count: 256)
            let nChars = llama_token_to_piece(model, newToken, &buf, Int32(buf.count), 0, true)
            if nChars > 0 {
                let piece = String(cString: buf)
                continuation.yield(piece)
            }

            // Prepare next batch
            llama_batch_clear(&batch)
            llama_batch_add(&batch, newToken, Int32(tokens.count) + nGenerated, [0], true)
            nGenerated += 1

            if llama_decode(ctx, batch) != 0 { break }

            // Context window check
            if Int32(tokens.count) + nGenerated >= nCtx { break }
        }

        continuation.finish()
    }

    deinit {
        if let ctx { llama_free(ctx) }
        if let model { llama_model_free(model) }
        llama_backend_free()
    }
}
```

**IMPORTANT:** The exact API names may differ slightly depending on the llama.cpp version. Read the actual headers in the XCFramework (`llama.xcframework/ios-arm64/Headers/llama.h`) to verify function signatures before implementing. Key functions to verify:
- `llama_model_load_from_file` vs `llama_load_model_from_file`
- `llama_model_free` vs `llama_free_model`
- `llama_vocab_is_eog` vs `llama_token_is_eog`
- `llama_batch_add` signature (may be a macro or function)

- [ ] **Step 2: Build and fix any API mismatches**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -30`

If there are errors about function names, read the actual headers:
```bash
find Frameworks/llama.xcframework -name "llama.h" | head -1 | xargs grep -E 'llama_(model_load|load_model|free_model|model_free|vocab_is_eog|token_is_eog|batch_add)' | head -20
```

Fix any API name mismatches and rebuild.

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Services/Inference/LlamaSession.swift
git commit -m "feat: implement LlamaSession with real llama.cpp C API calls"
```

---

## Task 3: Create LocalInferenceBackend

**Files:**
- Create: `ModelRunner/Services/Inference/Backends/LocalInferenceBackend.swift`

- [ ] **Step 1: Create the backend wrapper**

```swift
// ModelRunner/Services/Inference/Backends/LocalInferenceBackend.swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "LocalInferenceBackend")

/// Wraps InferenceService (llama.cpp actor) behind the InferenceBackend protocol.
/// This allows local on-device models to be used through the same interface as remote models.
public final class LocalInferenceBackend: InferenceBackend, @unchecked Sendable {
    public let id: String           // repoId of the DownloadedModel
    public let displayName: String
    public let source: ModelSource = .local

    private let inferenceService: InferenceService
    private let inferenceParams: InferenceParams
    private let modelURL: URL

    /// Whether the model has been loaded into memory
    private(set) var isLoaded: Bool = false

    public init(
        repoId: String,
        displayName: String,
        modelURL: URL,
        inferenceService: InferenceService,
        inferenceParams: InferenceParams
    ) {
        self.id = repoId
        self.displayName = displayName
        self.modelURL = modelURL
        self.inferenceService = inferenceService
        self.inferenceParams = inferenceParams
    }

    /// Composite identity key matching ModelUsageStats
    public var modelIdentity: String {
        "local:\(id)"
    }

    /// Load the model into memory. Call before generate().
    public func loadModel() async throws {
        try await inferenceService.loadModel(at: modelURL, params: inferenceParams)
        isLoaded = true
    }

    public func generate(
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> AsyncThrowingStream<StreamToken, Error> {
        // Build prompt from messages using ChatML format
        let prompt = PromptFormatter.chatml(system: params.systemPrompt, messages: messages)

        return AsyncThrowingStream { continuation in
            Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                let stream = await self.inferenceService.generate(prompt: prompt, params: params)
                do {
                    for try await token in stream {
                        // Local inference returns raw strings, wrap as .content
                        let cleaned = Self.stripStopTokens(token)
                        if !cleaned.isEmpty {
                            continuation.yield(.content(cleaned))
                        }
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func stop() async {
        await inferenceService.stopGeneration()
    }

    // MARK: - Token Cleanup (same as ChatViewModel)

    private static let stopTokenPatterns = ["<|im_end|>", "<|im_start|>", "<|endoftext|>", "</s>"]

    private static func stripStopTokens(_ text: String) -> String {
        var result = text
        for pattern in stopTokenPatterns {
            result = result.replacingOccurrences(of: pattern, with: "")
        }
        return result
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Services/Inference/Backends/LocalInferenceBackend.swift
git commit -m "feat: LocalInferenceBackend — wraps InferenceService behind InferenceBackend protocol"
```

---

## Task 4: Wire LocalInferenceBackend into AppContainer + ChatView

**Files:**
- Modify: `ModelRunner/App/AppContainer.swift`
- Modify: `ModelRunner/Features/Chat/ChatView.swift`

- [ ] **Step 1: Add buildLocalBackend to AppContainer**

Add this method to `AppContainer.swift` after `buildBackend(for:modelContext:)`:

```swift
/// Build a LocalInferenceBackend for a downloaded model.
func buildLocalBackend(for model: DownloadedModel) -> LocalInferenceBackend {
    let params = inferenceParams(activeModel: model)
    return LocalInferenceBackend(
        repoId: model.repoId,
        displayName: model.displayName,
        modelURL: URL(filePath: model.localPath),
        inferenceService: inferenceService,
        inferenceParams: params
    )
}
```

- [ ] **Step 2: Update ChatView.setupViewModel to use LocalInferenceBackend**

In `ChatView.swift`, update the local model path in `setupViewModel()` to create a `ChatViewModel(backend:)` instead of the legacy `ChatViewModel(inferenceService:inferenceParams:)`:

Find the local model fallback section and replace:
```swift
// Fall back to local model setup
guard let url = activeModelURL else {
    viewModel = nil
    return
}
let model = activeModel(from: container)
let vm = ChatViewModel(
    inferenceService: container.inferenceService,
    inferenceParams: container.inferenceParams(activeModel: model)
)
viewModel = vm
await vm.loadModel(url: url)
```

With:
```swift
// Fall back to local model setup
guard let url = activeModelURL else {
    viewModel = nil
    return
}
guard let model = activeModel(from: container) else {
    viewModel = nil
    return
}
let localBackend = container.buildLocalBackend(for: model)
let vm = ChatViewModel(backend: localBackend)
vm.configure(modelContext: modelContext)

let identity = "local:\(model.repoId)"
vm.loadMostRecentConversation(forIdentity: identity, modelContext: modelContext)
if vm.activeConversation == nil {
    let selected = SelectedModel(backendID: model.repoId, displayName: model.displayName, source: .local)
    vm.startNewConversation(for: selected)
}
viewModel = vm

// Load model into memory (shows loading state)
do {
    try await localBackend.loadModel()
} catch {
    vm.loadingState = .failed(error.localizedDescription)
}
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/App/AppContainer.swift ModelRunner/Features/Chat/ChatView.swift
git commit -m "feat: wire LocalInferenceBackend — local models now use the unified InferenceBackend protocol"
```

---

## Task 5: Integrate LibraryView into Models Tab

**Files:**
- Modify: `ModelRunner/Features/Models/ModelsTabView.swift`

Currently `LibraryView` is a fully built view (delete models, manage storage) but it's inaccessible because the Settings tab was removed. Add it as a section in ModelsTabView.

- [ ] **Step 1: Add Library section to ModelsTabView**

In `ModelsTabView.swift`, add a section between MyModelsSection and the Browse section for downloaded model management. Read the file first, then add after the divider and before the "BROWSE HUGGING FACE" header:

```swift
// Storage section — only show if there are downloaded models
if hasDownloadedModels {
    Text("STORAGE")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(hex: "#9896B0"))
        .tracking(0.5)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)

    StorageSummaryView()
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

    Rectangle()
        .fill(Color(hex: "#302E42"))
        .frame(height: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
}
```

Add a computed property:
```swift
private var hasDownloadedModels: Bool {
    pickerVM.sections.contains { $0.id == "local" && !$0.models.isEmpty }
}
```

Create a minimal `StorageSummaryView` that shows model count + storage used + "Manage" button that presents the full LibraryView as a sheet.

- [ ] **Step 2: Build and verify**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -10`

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Models/ModelsTabView.swift
git commit -m "feat: integrate storage management into Models tab — LibraryView accessible via Manage button"
```

---

## Task 6: Fix Remaining Audit Ship-Blockers

**Files:**
- Modify: `ModelRunner/Features/Chat/ChatView.swift` — fix dead `showSettings` trigger
- Modify: `ModelRunner/Features/Chat/ChatViewModel.swift` — surface local generation errors
- Modify: `ModelRunner/Features/Models/ModelsTabView.swift` — remove polling loop

- [ ] **Step 1: Fix showSettings dead trigger in ChatView**

The `showSettings` state exists but no button sets it to true (removed when we replaced gear with +). Add a settings option to a context menu or long-press, OR add it to the chat input bar area. Simplest: add a slider icon to the toolbar alongside the + button:

In ChatView toolbar, add before the existing + button ToolbarItem:
```swift
ToolbarItem(placement: .topBarTrailing) {
    HStack(spacing: 12) {
        if activeModel(from: container) != nil {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(Color(hex: "#9896B0"))
            }
        }
        Button {
            startNewChat()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "#9896B0"))
        }
        .disabled(viewModel == nil)
    }
}
```

Note: This replaces the existing single ToolbarItem with one that contains both buttons.

- [ ] **Step 2: Surface local generation errors**

In `ChatViewModel.swift`, find `runLocalGeneration()`'s catch block and update:

Find:
```swift
} catch {
    logger.error("Generation error: \(error)")
}
```

Change to:
```swift
} catch {
    logger.error("Generation error: \(error)")
    if var msg = streamingMessage, msg.content.isEmpty {
        msg.content = "Error: \(error.localizedDescription)"
        streamingMessage = msg
    }
}
```

- [ ] **Step 3: Remove polling loop in BrowseEmbeddedView**

In `ModelsTabView.swift`, find the `BrowseEmbeddedView` and remove the `.task` polling loop. Keep only `.onAppear` and `.onChange`:

Remove:
```swift
.task {
    while container.compatibilityEngine == nil {
        try? await Task.sleep(for: .milliseconds(200))
    }
    engineReady = true
}
```

Also remove the `@State private var engineReady = false` and the `.onChange(of: engineReady)`. Replace with:
```swift
.onChange(of: container.compatibilityEngine != nil) { _, ready in
    if ready { initViewModelIfNeeded() }
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -10`

- [ ] **Step 5: Commit**

```bash
git add ModelRunner/Features/Chat/ChatView.swift ModelRunner/Features/Chat/ChatViewModel.swift ModelRunner/Features/Models/ModelsTabView.swift
git commit -m "fix: restore settings trigger, surface local errors, remove polling loop"
```

---

## Task 7: Integration Test

- [ ] **Step 1: Full build**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' 2>&1 | grep -E '(error:|BUILD)' | head -10`

- [ ] **Step 2: Run tests**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,id=0B9BD01E-AFFB-466E-856D-D7877FCA161A' -only-testing:ModelRunnerTests 2>&1 | grep -i -E '(passed|failed|Executed)' | head -30`

- [ ] **Step 3: Manual smoke test**

1. Launch app → Models tab → verify My Models cards show
2. Tap a remote model card → verify Chat opens and streaming works
3. If a local model is downloaded: tap its card → verify model loads (or shows loading/error)
4. Tap + in toolbar → new chat starts
5. Tap slider icon → ChatSettingsView opens
6. Scroll down on Models tab → Storage section visible (if models downloaded)
7. "Manage" → LibraryView opens
8. Browse HF section visible with search bar
