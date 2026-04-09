# Phase 5: Polish + V1 Completeness — Research

**Phase:** 05-polish-v1-completeness
**Requirements:** CHAT-04, CHAT-05
**Researched:** 2026-04-09

---

## Standard Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| Conversation persistence | SwiftData `@Model` — `Conversation` + `Message` | Extend existing ModelContainer from Phase 3 |
| Parameters storage | SwiftData — `ModelSettings @Model` or embedded in `DownloadedModel` | Per-model grain (D-10) |
| History list | `List` with `ForEach` grouped by model, `.defaultScrollAnchor(.bottom)` | Bottom-anchored, iOS 17+ |
| History overlay | `ZStack` replace chat content area, spring animation 0.3s | Not a NavigationStack push |
| Parameter presets | Enum (`Precise`/`Balanced`/`Creative`) → temperature+top-p tuples | D-09 |
| Parameter sliders | SwiftUI `Slider(value:in:step:)` with `#8B7CF0` tint | D-11 |
| llama.cpp params | `llama_context_default_params()` → set `.temp` and `.top_p` | Pass through `InferenceParams` |
| First-launch detection | `@AppStorage("hasCompletedOnboarding") var hasOnboarded: Bool` | Standard pattern, persists across launches |
| Auto-title | `String.prefix(50)` from first user message | Truncate + ellipsis if needed |
| Relative timestamps | `RelativeDateTimeFormatter` | Already in iOS 15+ |
| Best-model picker | Filter `DownloadedModel` where compatibility == `.runsWell`, sort by fileSizeBytes ascending | Guided onboarding |

---

## Architecture Patterns

### 1. SwiftData Schema Extension

Phase 3 established `DownloadedModel @Model` in `ModelRunner/Models/DownloadedModel.swift`. Phase 5 adds two new models to the same schema. All three are registered in the `ModelContainer` at app launch.

```swift
// ModelRunner/Models/Conversation.swift
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String          // auto-generated from first message
    var createdAt: Date
    var updatedAt: Date
    var modelRepoId: String    // foreign key by value — avoids relationship complexity
    var modelDisplayName: String
    var modelQuantization: String
    
    @Relationship(deleteRule: .cascade)
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
}

// ModelRunner/Models/Message.swift
@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: String           // "user" | "assistant" — avoid enum for Codable simplicity
    var content: String
    var createdAt: Date
    var conversation: Conversation?

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}
```

**Important:** Use `@Relationship(deleteRule: .cascade)` on the `messages` array so deleting a `Conversation` cascades to its `Message` rows. Without this, orphan `Message` rows accumulate.

**Migration:** Adding new `@Model` types to a `ModelContainer` that already has `DownloadedModel` does NOT require a migration schema. SwiftData creates the new tables automatically. No `VersionedSchema` or `MigrationPlan` needed for adding tables — only for changing existing ones.

### 2. ModelContainer Registration

```swift
// ModelRunnerApp.swift — update the .modelContainer modifier
.modelContainer(for: [DownloadedModel.self, Conversation.self, Message.self])
```

All three models in one container means they share a SQLite store. Relationships (Conversation → Message) work correctly. Cross-model relationships (Conversation.modelRepoId matching DownloadedModel.repoId) are done by value (String) not by SwiftData relationship — keeps schema simple and avoids cascade complexity when a model is deleted.

### 3. ModelSettings — Per-Model Inference Parameters

The cleanest approach: add inference parameter fields directly to `DownloadedModel` rather than creating a separate `ModelSettings` model. This avoids an extra join and aligns with D-10 (params are per-model, not per-conversation).

```swift
// Add to DownloadedModel @Model
var temperature: Double = 0.7
var topP: Double = 0.9
var systemPrompt: String = "You are a helpful assistant."
```

**Alternative considered:** Separate `ModelSettings @Model` with a one-to-one relationship to `DownloadedModel`. Rejected because SwiftData one-to-one relationships require explicit inverses and the extra complexity isn't justified for 3 fields.

**Phase 4 context:** In Phase 4, `systemPrompt` was stored in `UserDefaults`. Phase 5 migrates it to `DownloadedModel` in SwiftData. The `ChatSettingsView` reads/writes `DownloadedModel` directly, not UserDefaults.

### 4. InferenceParams — Passing Temperature/Top-P to llama.cpp

Phase 4 established `InferenceParams.swift` with `contextWindowTokens`, `batchSize`, `gpuLayers`. Phase 5 extends it with sampling parameters:

```swift
struct InferenceParams: Sendable {
    let contextWindowTokens: Int32
    let batchSize: Int32
    let gpuLayers: Int32
    // Phase 5 additions:
    let temperature: Float
    let topP: Float
    let systemPrompt: String

    static func `default`(contextWindowCap: Int) -> InferenceParams {
        InferenceParams(
            contextWindowTokens: Int32(contextWindowCap),
            batchSize: 512,
            gpuLayers: 99,
            temperature: 0.7,
            topP: 0.9,
            systemPrompt: "You are a helpful assistant."
        )
    }
}
```

**llama.cpp API:** In `LlamaSession`, after `llama_new_context_with_model`, create a `llama_sampler_chain`:

```c
// C API (accessed via bridging header or directly)
struct llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
llama_sampler * smpl = llama_sampler_chain_init(sparams);
llama_sampler_chain_add(smpl, llama_sampler_init_top_p(params.topP, 1));
llama_sampler_chain_add(smpl, llama_sampler_init_temp(params.temperature));
llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
```

Then in the decode loop: `llama_sampler_sample(smpl, ctx, -1)` to get the next token. This replaces greedy decoding.

**Alternative (older API):** Some XCFramework builds expose `llama_context_params.temp` and `llama_context_params.top_p` directly. Check the XCFramework headers from Phase 4's Task 04-01-02 to determine which API is available. The sampler chain approach is preferred for b5046+.

### 5. History Overlay — ZStack Pattern

```swift
// ChatView body
ZStack(alignment: .bottom) {
    if showingHistory {
        ConversationHistoryView(
            conversations: conversations,
            onSelect: { conversation in
                activeConversation = conversation
                showingHistory = false
            },
            onDismiss: { showingHistory = false }
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    } else {
        // active chat bubble list + scroll view
        MessageListView(messages: activeConversation?.messages ?? [])
            .transition(.opacity)
    }
}
.animation(.spring(duration: 0.3, bounce: 0.15), value: showingHistory)
```

The history overlay replaces the chat content area, NOT the entire screen. The input bar stays pinned at bottom regardless of state. The toggle button in the input bar controls `showingHistory`.

**Bottom-anchored scroll:**
```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack { /* conversation rows */ }
    }
    .defaultScrollAnchor(.bottom)
}
```

`.defaultScrollAnchor(.bottom)` is iOS 17+. Rows grow upward from the bottom, most recent conversation nearest the input bar.

### 6. Conversation Grouping with @Query

SwiftData's `@Query` doesn't natively support groupBy. Group in-memory after fetching:

```swift
@Query(sort: \Conversation.updatedAt, order: .reverse)
private var conversations: [Conversation]

// Computed property for grouped display
var conversationsByModel: [(modelId: String, displayName: String, conversations: [Conversation])] {
    let grouped = Dictionary(grouping: conversations, by: \.modelRepoId)
    return grouped.map { (modelId: $0.key, displayName: $0.value.first?.modelDisplayName ?? $0.key, conversations: $0.value) }
        .sorted { $0.conversations[0].updatedAt > $1.conversations[0].updatedAt }
}
```

This is O(n) and fast enough for v1 (users won't have hundreds of conversations).

### 7. First-Launch Detection

```swift
// In ModelRunnerApp or a root coordinator view
@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

var body: some Scene {
    WindowGroup {
        if hasCompletedOnboarding {
            ContentView()
        } else {
            WelcomeView(onComplete: { hasCompletedOnboarding = true })
        }
    }
    .modelContainer(for: [...])
}
```

`@AppStorage` wraps `UserDefaults`. Survives app restarts. Set to `true` when the user taps either welcome button. Simple and reliable.

**Guided path — best model picker:**
```swift
func pickBestModel(from models: [DownloadedModel], engine: CompatibilityEngine) -> DownloadedModel? {
    models
        .filter { engine.compatibility(for: $0.repoId) == .runsWell }
        .min(by: { $0.fileSizeBytes < $1.fileSizeBytes })
}
```

If no "Runs Well" models are downloaded, the guided path should fall back to Browse (same as "Get Started").

### 8. Auto-Title Generation

```swift
extension Conversation {
    func generateTitle(from firstUserMessage: String) {
        let truncated = String(firstUserMessage.prefix(50))
        title = truncated.count < firstUserMessage.count ? "\(truncated)..." : truncated
    }
}
```

Called when the first user message is sent. Update the `Conversation.title` in SwiftData at the same time as persisting the message.

### 9. Relative Timestamps

```swift
let formatter = RelativeDateTimeFormatter()
formatter.unitsStyle = .abbreviated  // "2h ago", "3d ago"
let display = formatter.localizedString(for: conversation.updatedAt, relativeTo: Date())
```

Format once per row render. No caching needed for a history list with < 100 items.

### 10. ChatViewModel — Adding Persistence Layer

Phase 4's `ChatViewModel` holds `messages: [ChatMessage]` in-memory. Phase 5 adds a SwiftData-backed `Conversation` object:

```swift
@Observable
@MainActor
final class ChatViewModel {
    // Phase 4 (preserved)
    var messages: [ChatMessage] = []
    var isGenerating = false
    var tokensPerSecond: Double = 0
    var loadingState: ModelLoadState = .idle

    // Phase 5 additions
    var activeConversation: Conversation?
    var showingHistory = false

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startNewConversation(for model: DownloadedModel) {
        let conv = Conversation(
            modelRepoId: model.repoId,
            modelDisplayName: model.displayName,
            modelQuantization: model.quantization
        )
        modelContext?.insert(conv)
        try? modelContext?.save()
        activeConversation = conv
        messages = []
    }

    func send(text: String) {
        // Save user message to SwiftData
        let userMsg = Message(role: "user", content: text)
        activeConversation?.messages.append(userMsg)
        if activeConversation?.title == "New Conversation" {
            activeConversation?.generateTitle(from: text)
        }

        // Proceed with inference (existing Phase 4 flow)
        // On completion: save assistant message to SwiftData
    }
}
```

**Concurrency note:** SwiftData `ModelContext` operations must run on `@MainActor`. Since `ChatViewModel` is already `@MainActor`, this works naturally. Inference still runs on `Task.detached` inside `InferenceService`. The only SwiftData writes happen on `MainActor` (before inference starts for user message, after for assistant message).

### 11. Preset Pills → Slider Values

```swift
enum InferencePreset: String, CaseIterable {
    case precise = "Precise"
    case balanced = "Balanced"
    case creative = "Creative"

    var temperature: Double {
        switch self {
        case .precise:  return 0.3
        case .balanced: return 0.7
        case .creative: return 1.2
        }
    }
    var topP: Double {
        switch self {
        case .precise:  return 0.7
        case .balanced: return 0.9
        case .creative: return 0.95
        }
    }
}
```

Tapping a preset pill writes `temperature` and `topP` to the `DownloadedModel` in SwiftData and snaps the sliders. The "Advanced" disclosure group shows the actual slider values reflecting the current state.

---

## Common Pitfalls

### 1. SwiftData Cascade Delete (Critical)
Without `@Relationship(deleteRule: .cascade)` on `Conversation.messages`, deleting a `Conversation` orphans all its `Message` rows in the database. These accumulate silently. Always set delete rules explicitly.

### 2. ModelContext on Wrong Thread
SwiftData `ModelContext` is not thread-safe. Do NOT capture `modelContext` into a `Task.detached` closure. All `modelContext` calls must happen on `@MainActor`. Since `ChatViewModel` is `@MainActor`, this is naturally safe — but be careful if refactoring to async.

### 3. @Query in Non-View Types
`@Query` only works in SwiftUI `View` types. Do NOT put `@Query` in `ChatViewModel` (it's `@Observable`, not a `View`). Query in the View and pass results to the ViewModel, or use a `ModelContext` with `FetchDescriptor` manually.

### 4. InferenceParams Must Be Rebuilt on Each Conversation Start
When the user changes temperature/top-p in settings, the `InferenceService` actor holds a session with old params. The session must be reloaded for new params to take effect — `n_ctx` is the same but sampling params are rebuilt. The `LlamaSession` sampler chain is created at init time.

**Solution:** Reload the model (call `InferenceService.loadModel()`) when params change OR pass a fresh sampler chain per generation call. The latter is preferred since the model doesn't need to re-load from disk — only the sampler chain needs rebuilding.

### 5. Bottom-Anchored Scroll with Section Headers
`.defaultScrollAnchor(.bottom)` anchors the scroll position but doesn't change the visual order. You still need to render conversations in newest-first order. Combine with reverse-sorted `@Query` (`.reverse` order by `updatedAt`).

### 6. Onboarding and ModelContainer Init Order
`WelcomeView` is shown before `ContentView` but the `ModelContainer` must already be initialized (it's on the `WindowGroup` modifier). This is correct — `.modelContainer()` applies to the entire `WindowGroup`, so both `WelcomeView` and `ContentView` have access to SwiftData from the start.

---

## Validation Architecture

### Integration Test Strategy

Phase 5 adds three new surfaces (history overlay, parameter settings, welcome screen) and one data layer (SwiftData persistence). Testing splits:

**Unit-testable (simulator):**
- `Conversation.generateTitle()` — string truncation logic
- `InferencePreset` — temperature/topP value mapping
- `InferenceParams` — extended struct with temperature/topP
- `ChatViewModel.startNewConversation()` — creates Conversation in in-memory ModelContext
- `ChatViewModel.send()` — persists Message, updates title on first send
- `pickBestModel()` — filtering and sorting logic

**SwiftData integration (simulator):**
- Create Conversation, add Messages, verify cascade delete removes Messages
- Fetch Conversations sorted by updatedAt, verify order
- Modify DownloadedModel temperature/topP, verify persists across ModelContext reload

**Manual-only (physical device):**
- History overlay springs open and closes correctly
- Conversation persists across app restart
- Parameters take effect in next inference (temperature produces more varied output at 1.2 vs 0.3)
- Guided onboarding: app correctly picks smallest "Runs Well" model
- Welcome screen only shows once (AppStorage persists)

### Grep-Verifiable Acceptance Conditions

```bash
# Conversation model
grep -c "@Model" ModelRunner/Models/Conversation.swift          # >= 1
grep -c "deleteRule: .cascade" ModelRunner/Models/Conversation.swift  # >= 1
grep -c "modelRepoId" ModelRunner/Models/Conversation.swift    # >= 1

# Message model
grep -c "@Model" ModelRunner/Models/Message.swift              # >= 1
grep -c "conversation:" ModelRunner/Models/Message.swift       # >= 1

# DownloadedModel extensions
grep -c "temperature" ModelRunner/Models/DownloadedModel.swift  # >= 1
grep -c "topP" ModelRunner/Models/DownloadedModel.swift         # >= 1
grep -c "systemPrompt" ModelRunner/Models/DownloadedModel.swift # >= 1

# InferenceParams
grep -c "temperature" ModelRunner/Services/Inference/InferenceParams.swift  # >= 1
grep -c "topP" ModelRunner/Services/Inference/InferenceParams.swift         # >= 1

# ModelContainer
grep -c "Conversation.self" ModelRunner/App/ModelRunnerApp.swift  # >= 1
grep -c "Message.self" ModelRunner/App/ModelRunnerApp.swift       # >= 1

# Onboarding
grep -c "hasCompletedOnboarding" ModelRunner/App/ModelRunnerApp.swift  # >= 1
grep -c "WelcomeView" ModelRunner/App/ModelRunnerApp.swift             # >= 1

# History overlay
grep -c "defaultScrollAnchor" ModelRunner/Features/Chat/ConversationHistoryView.swift  # >= 1
grep -c "showingHistory" ModelRunner/Features/Chat/ChatView.swift  # >= 1
```

---

## Phase Boundary Confirmation

**In scope (Phase 5):**
- `Conversation` and `Message` SwiftData `@Model` types
- Add `temperature`, `topP`, `systemPrompt` fields to `DownloadedModel`
- Extend `InferenceParams` with `temperature`, `topP`, `systemPrompt`
- Update `InferenceService`/`LlamaSession` to use sampler chain with params
- `ChatViewModel` persistence layer (SwiftData read/write)
- `ConversationHistoryView` — bottom-anchored, grouped by model, glass rows
- History toggle (clock button) in input bar
- `ChatSettingsView` extension — preset pills + sliders + system prompt
- `WelcomeView` — first-launch screen with two paths
- `ModelRunnerApp` — first-launch gate via `@AppStorage`
- Guided onboarding: best-model picker + download flow handoff

**Out of scope (Phase 5):**
- Manual conversation renaming
- Conversation export/share
- Model-specific chat themes
- Multi-model switching

---

## Sources

- Apple SwiftData Documentation — `@Model`, `@Relationship`, `ModelContainer`, `ModelContext` (HIGH confidence)
- llama.cpp b5046+ XCFramework headers — sampler chain API (`llama_sampler_chain_init`, `llama_sampler_init_temp`, `llama_sampler_init_top_p`) — verify from Phase 4 Task 04-01-02 (HIGH confidence)
- Phase 4 RESEARCH.md — established InferenceService actor pattern, AsyncThrowingStream bridge (HIGH confidence)
- Phase 3 CONTEXT.md — DownloadedModel schema, SwiftData setup at app entry (HIGH confidence)
- Phase 4 CONTEXT.md — ChatViewModel structure, ChatSettingsView, system prompt presets (HIGH confidence)
- DESIGN.md Phase 5 sections — glass material specs, history overlay layout, parameter settings layout, welcome screen (HIGH confidence)

---

## RESEARCH COMPLETE

**Key findings:**
1. Adding `Conversation` + `Message` @Model to existing ModelContainer requires no migration — SwiftData handles new tables automatically.
2. Sampling parameters (temperature, top-p) go through a llama.cpp `llama_sampler_chain`, not `llama_context_params` — rebuild sampler chain per generation to support live param changes without model reload.
3. `@Query` works only in SwiftUI Views — history list grouping must be done via computed property on in-memory results.
4. The 3-field extension to `DownloadedModel` (temperature, topP, systemPrompt) is simpler than a separate `ModelSettings` @Model — no relationship needed.
5. First-launch gate is `@AppStorage("hasCompletedOnboarding")` on `ModelRunnerApp` — safe, simple, correct.
