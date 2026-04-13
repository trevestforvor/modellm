# Remote Inference & Unified Model Picker

**Date:** 2026-04-12
**Status:** Approved
**Scope:** Add remote server connectivity, unify local and remote inference behind one abstraction, build unified model picker with thinking support

---

## Problem

ModelRunner has a complete chat UI shell but no working inference backend. The llama.cpp XCFramework isn't linked, so on-device inference is non-functional. The user has multiple models running on remote servers (Ollama, vLLM, llama.cpp server) that all expose OpenAI-compatible APIs. We need to get chat working end-to-end against these servers while designing an abstraction that on-device inference can slot into later.

## Design

### 1. Inference Abstraction Layer

Two protocols decouple the chat UI from where inference happens:

**`InferenceBackend`** — what ChatViewModel talks to:

```swift
protocol InferenceBackend: Sendable {
    var id: String { get }
    var displayName: String { get }
    var source: ModelSource { get }

    func generate(
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> AsyncThrowingStream<StreamToken, Error>

    func stop() async
}

enum StreamToken: Sendable {
    case thinking(String)   // reasoning_content delta
    case content(String)    // regular content delta
    case done               // stream finished
}

enum ModelSource: Hashable, Codable {
    case local
    case remote(serverID: UUID)
}
```

Note: `ModelSource.remote` uses the `ServerConnection` UUID as a stable identifier, not the display name (which is editable and non-unique).

**`APIAdapter`** — how a remote server's API format is spoken:

```swift
protocol APIAdapter: Sendable {
    static var format: APIFormat { get }

    func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> URLRequest

    func parseTokenStream(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<StreamToken, Error>
}
```

**`RemoteInferenceBackend`** combines a server connection + model ID + the appropriate adapter to conform to `InferenceBackend`. ChatViewModel never knows which adapter is in use.

**Cancellation model:** `RemoteInferenceBackend` holds a reference to the active `URLSessionDataTask`. Calling `stop()` cancels the task (closing the socket), which terminates the `AsyncBytes` stream. The adapter's `parseTokenStream` sees the cancellation and yields any partial content accumulated so far before ending. This ensures partial responses are preserved in the chat history.

Later, `LocalInferenceBackend` wraps the existing `InferenceService`/`LlamaSession` behind the same `InferenceBackend` protocol. ChatViewModel won't change.

### 2. API Format Detection & Adapters

Three adapters ship in v1 (OpenAI Chat and Legacy are the priority; Anthropic is a skeleton for future use):

| Adapter | Endpoint | Request Format | Streaming Format | Priority |
|---------|----------|---------------|-----------------|----------|
| `OpenAIChatAdapter` | `/v1/chat/completions` | `messages` array, `stream: true` | SSE `data:` chunks with `choices[0].delta.content` | P0 — all user servers |
| `OpenAILegacyAdapter` | `/v1/completions` | `prompt` string, `stream: true` | SSE `data:` chunks with `choices[0].text` | P0 — backwards compat |
| `AnthropicMessagesAdapter` | `/v1/messages` | `messages` array, `stream: true` | SSE `event: content_block_delta` with `delta.text` | P2 — skeleton only |

**Detection — two-phase probe on server add:**

Phase 1: Discover models (required before format probing):
1. `GET /v1/models` — if successful, parse model list and pick the first model ID as the probe target

Phase 2: Probe each format using the discovered model ID:
1. `POST /v1/chat/completions` with `{model: "<probeModel>", messages: [{role: "user", content: "hi"}], max_tokens: 1, stream: false}` — success → OpenAI Chat
2. `POST /v1/completions` with `{model: "<probeModel>", prompt: "hi", max_tokens: 1}` — success → OpenAI Legacy
3. `POST /v1/messages` with `{model: "<probeModel>", messages: [{role: "user", content: "hi"}], max_tokens: 1}` — success → Anthropic

All three probes run in parallel. Every format that responds successfully is stored in `supportedFormats`. The app defaults to the best available (chat completions > legacy completions > anthropic) but the user can switch via server settings.

If `/v1/models` fails (some servers don't implement it), the user is prompted to enter a model ID manually, and probing proceeds with that.

If no probes succeed → show error with details, offer manual format selection as fallback.

### 3. Server Management

**Data model** — SwiftData `@Model`:

```swift
@Model
final class ServerConnection {
    @Attribute(.unique) var id: UUID
    var name: String                    // "MacBook Pro"
    var baseURL: String                 // "https://server.example.com"
    var supportedFormats: [APIFormat]   // all detected formats
    var activeFormat: APIFormat          // currently selected format
    var apiKeyRef: String?              // Keychain item identifier (NOT the key itself)
    var isActive: Bool                  // reachable at last check
    var addedAt: Date
    var lastCheckedAt: Date?
}

enum APIFormat: String, Codable, CaseIterable {
    case openAIChat         // /v1/chat/completions
    case openAILegacy       // /v1/completions
    case anthropicMessages  // /v1/messages
}
```

**API key storage:** `apiKeyRef` stores a Keychain item identifier. Actual secrets are stored in and retrieved from Keychain using a `KeychainService` helper. Secrets never touch SwiftData.

**UI — Settings > Servers:**
- List of saved servers with reachability indicator (green/red dot)
- "Add Server" flow: enter name + URL → app probes `/v1/models` → shows detected models and formats → saves
- Tap server to edit (name, URL, active format picker, API key)
- Swipe to delete
- Pull to refresh reachability status

### 4. Model Discovery & Persistence

When a server is reachable, the app queries its model list:

- **OpenAI-compatible:** `GET /v1/models` → parse `data[].id` (or top-level `models[].name` for Ollama-style responses, which return both shapes)
- **Anthropic:** No standard model list endpoint — user configures model IDs manually in server settings

Discovered models are stored transiently in memory (re-queried on app launch and when server list changes). Each becomes a `RemoteModel`:

```swift
struct RemoteModel: Identifiable, Sendable {
    let id: String              // model ID from server
    let serverID: UUID          // which ServerConnection owns this
    let serverName: String      // for display (denormalized)
}
```

**Usage stats persistence** — a separate SwiftData model tracks measured performance across both local and remote models:

```swift
@Model
final class ModelUsageStats {
    @Attribute(.unique) var modelIdentity: String  // composite key (see below)
    var lastMeasuredTokPerSec: Double?
    var totalGenerations: Int
    var lastUsedAt: Date
}
```

The `modelIdentity` key is a stable composite: `"local:<repoId>"` for on-device models, `"remote:<serverUUID>:<modelID>"` for remote models. This decouples usage tracking from the transient `RemoteModel` structs.

### 5. Unified Model Picker

One picker sheet, shown when starting a chat or switching models. Models are grouped by source:

```
── On Device ──────────────────────
  Llama 3.2 3B Q4_K_M         12.4 tok/s

── MacBook Pro ────────────────────
  llama3:70b                   42.3 tok/s
  codestral:latest             — tok/s

── Home Server ────────────────────
  nemotron-3-nano-4b           129 tok/s
```

- **On-device models:** only downloaded models appear (no undownloaded/browse models). Show estimated tok/s from CompatibilityEngine or measured tok/s from `ModelUsageStats` if available
- **Remote models:** show measured tok/s from `ModelUsageStats`, or "—" if never used
- **Connectivity:** remote models from unreachable servers are grayed out with "offline" label
- **Selection behavior:** selecting a model starts a new conversation with that model. To resume an existing conversation, use the conversation history view (already built)

### 6. Model Selection & ChatViewModel Integration

**App-level model selection** — the selected model identity lives in `AppContainer`, not just `ChatViewModel`:

```swift
// In AppContainer
struct SelectedModel: Codable {
    let backendID: String       // InferenceBackend.id
    let displayName: String
    let source: ModelSource
}

var selectedModel: SelectedModel?  // persisted to UserDefaults
```

This allows the selection to persist across app launches, be visible from any screen (e.g., a model name in the tab bar or nav title), and be restored on cold start.

**ChatViewModel changes:**

1. Replace direct `InferenceService` dependency with `InferenceBackend` (protocol)
2. Receive `InferenceBackend` from AppContainer based on `selectedModel`
3. `sendMessage()` calls `backend.generate(messages:params:enableThinking:)` → streams `StreamToken` values
4. After generation completes, persist final tok/s to `ModelUsageStats`
5. `stopGeneration()` calls `backend.stop()` → cancels URLSessionTask for remote, sets cancellation flag for local

**Chat UI changes** (correcting earlier claim of "no UI changes"):

- ChatView toolbar: shows selected model name + source label, tap opens model picker
- ChatInputBar: adds thinking toggle button (brain icon, tinted when active)
- ChatBubbleView: new rendering path for thinking blocks (see Section 7)
- ChatView: presents ModelPickerView as a sheet

### 7. Reasoning/Thinking Support

Some models (e.g., Nemotron) return `reasoning_content` separately from `content` in chat completion responses.

**Adapter behavior by format:**
- **OpenAI Chat:** parses `choices[0].delta.reasoning_content` → `.thinking`, `choices[0].delta.content` → `.content`. If `reasoning_content` is absent or `enableThinking` is false, only `.content` tokens are yielded.
- **Anthropic:** parses `thinking` content blocks → `.thinking`, `text` content blocks → `.content`
- **OpenAI Legacy:** no thinking support — all tokens are `.content`. `enableThinking` parameter is ignored.

**Thinking detection — probe-time:** During format probing (ServerProbe), the chat completions probe response is inspected for a `reasoning_content` field. If present (even if empty/null), the model is marked as thinking-capable. This flag is stored per-model in the `ProbeResult.thinkingModelIDs` set and propagated to the picker UI.

- Models with thinking capability show a brain icon in the model picker
- Selecting a thinking-capable model auto-enables the thinking toggle
- The thinking toggle is still available for all models (user can force-enable for models not detected during probe — detection only catches the probe model, not all models on a server)
- If `enableThinking` is true but the model doesn't produce thinking tokens at runtime, nothing happens — no error, no empty block

**Thinking toggle in chat UI:**

- Toggle in ChatInputBar: brain icon button, tinted when active
- Global default: **off** (stored in UserDefaults via `ChatSettings.enableThinking`)
- Per-conversation override: stored in `Conversation.enableThinking` (new Bool field)
- When toggled mid-conversation, takes effect on the next generation

**Chat bubble rendering:**

```
┌─ Thinking ─────────────────── ▼ ┐  ← collapsible, muted secondary color
│ We need to respond politely...   │
│ Thought for 2.3s                 │  ← shown when collapsed
└──────────────────────────────────┘
┌──────────────────────────────────┐
│ Hello! How can I help you today? │  ← normal assistant bubble
└──────────────────────────────────┘
```

Thinking block auto-collapses after generation completes. Collapsed state shows "Thought for Xs" (measured from first `.thinking` token to first `.content` token). Tap to expand/collapse.

### 8. Conversation Identity for Remote Models

The current `Conversation` model stores `modelRepoId`, `modelDisplayName`, and `modelQuantization` — all local-model-centric fields. To support remote models:

**Replace model identity fields with a unified shape:**

```swift
// In Conversation @Model
var modelIdentity: String       // "local:<repoId>" or "remote:<serverUUID>:<modelID>"
var modelDisplayName: String    // "Llama 3.2 3B Q4_K_M" or "nemotron-3-nano-4b"
var modelSourceLabel: String    // "On Device" or "MacBook Pro"
var enableThinking: Bool        // per-conversation thinking toggle
```

This replaces `modelRepoId` and `modelQuantization`. The `modelIdentity` string matches the key used in `ModelUsageStats` for consistent cross-referencing.

Migration: existing conversations with `modelRepoId` set get migrated to `modelIdentity = "local:<repoId>"`. Field is non-optional with a default of empty string for the migration.

### 9. Error Handling

| Scenario | Behavior |
|----------|----------|
| Server unreachable on add | Show error with detail (timeout vs DNS vs refused), don't save. Offer retry. |
| Server goes offline mid-chat | Cancel URLSessionTask, show "Server disconnected" inline error. Preserve partial response and prior messages. |
| Server rejects auth (401/403) | Show "Authentication required" with prompt to add/update API key in server settings. |
| Rate limited (429) | Show "Rate limited — try again in Xs" if `Retry-After` header present. |
| Model not found (404) | Show "Model no longer available on [server]" — refresh model list. |
| Stream parse error | Stop generation, show partial response with error indicator. |
| TLS/certificate error | Show "Connection not secure" with option to trust (for self-signed certs on local network). Uses `URLSessionDelegate` to handle `NSURLAuthenticationMethodServerTrust`. |
| Invalid URL format | Validate on input before probing — show inline validation error. |
| Request timeout | 30s timeout on probes, 0 (no timeout) on streaming generation. Probe timeout shows "Server not responding." |
| Non-SSE error response | Parse response body for error message (most servers return JSON errors). Display server's error text in the chat. |

### 10. File Structure

New files (all under `ModelRunner/`):

```
Services/
  Inference/
    Backends/
      InferenceBackend.swift          // protocol + ModelSource + StreamToken + SelectedModel
      RemoteInferenceBackend.swift    // remote server conformer with URLSessionTask lifecycle
    Adapters/
      APIAdapter.swift                // protocol + APIFormat enum
      OpenAIChatAdapter.swift         // /v1/chat/completions (P0)
      OpenAILegacyAdapter.swift       // /v1/completions (P0)
      AnthropicMessagesAdapter.swift  // /v1/messages (P2 — skeleton)
    ServerProbe.swift                 // two-phase detection (models → format probing)
  Keychain/
    KeychainService.swift             // Keychain CRUD for API keys

Models/
  ServerConnection.swift              // SwiftData @Model
  ModelUsageStats.swift               // SwiftData @Model for tok/s persistence

Features/
  Settings/
    ServerListView.swift              // server management list
    AddServerView.swift               // add server flow with probe UI
    ServerDetailView.swift            // edit server + format picker
  ModelPicker/
    ModelPickerView.swift             // unified picker sheet
    ModelPickerViewModel.swift        // aggregates local + remote models
```

Modified files:

```
Features/Chat/ChatViewModel.swift     // InferenceBackend protocol, StreamToken handling
Features/Chat/ChatView.swift          // model picker sheet, toolbar model display
Features/Chat/ChatInputBar.swift      // thinking toggle button
Features/Chat/ChatBubbleView.swift    // thinking block rendering (collapsible)
Features/Chat/ChatSettings.swift      // add enableThinking global default
Models/Conversation.swift             // unified modelIdentity + enableThinking fields
App/AppContainer.swift                // selectedModel state, backend factory
App/ModelRunnerApp.swift              // Settings navigation entry
```

### 11. Testing Strategy

- **Adapter unit tests:** Each adapter gets tests with recorded SSE responses (no live server needed). Test both normal and thinking-content streams.
- **ServerProbe tests:** Mock URLSession responses for two-phase format detection. Test partial detection (models endpoint fails, manual model ID entry).
- **RemoteInferenceBackend tests:** Mock adapter, verify token stream assembly and cancellation behavior.
- **ModelUsageStats tests:** Verify composite key generation and tok/s persistence.
- **Integration test (opt-in, manual):** Live test against the Nemotron server. Not part of automated CI — requires network access and server availability. Gated behind an environment variable or test plan flag.

### 12. What This Design Does NOT Cover

- Fixing HF Browse (separate effort — HF API wiring + token support)
- Fixing Download pipeline (separate effort)
- Linking llama.cpp XCFramework / `LocalInferenceBackend` (separate effort — slots into `InferenceBackend` protocol)
- Network auto-discovery (out of scope — manual server add only)
- Conversation sync across devices (out of scope for v1)
- Per-model settings on remote servers (use global `ChatSettings` for now; per-model is a future enhancement)

---

## Test Server

Validated endpoint for development:
- **URL:** `https://nemo34bone.trevestforvorolares.olares.com`
- **Model:** `nemotron-3-nano-4b` (3.97B params, GGUF, llama.cpp server)
- **Formats:** `/v1/chat/completions` ✓, `/v1/completions` ✓
- **Performance:** ~129 tok/s generation, ~38 tok/s prompt processing
- **Note:** Returns `reasoning_content` field in chat completions (thinking model)
