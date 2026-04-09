# Phase 4: Inference + Chat - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can have a streaming conversation with a downloaded model entirely on-device. Includes: model loading from Library's active selection, streaming token output in a chat UI, tok/s display during generation, stop-generation control, and system prompt configuration. Does NOT include chat history persistence or inference parameter tuning (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Chat UI Layout
- **D-01:** Bubble-style chat messages (iMessage pattern). User bubbles right-aligned in accent violet (`#8B7CF0`), assistant bubbles left-aligned in `#1A1830`. Asymmetric corner radius for tail effect (4pt on the "tail" corner, 16pt elsewhere).
- **D-02:** MeshGradient shows between bubbles. Bubbles float on the gradient, not a flat background. This is a deliberate differentiator from every competitor in the space.
- **D-03:** Character-by-character token streaming. Each token appears as it's generated. Blinking violet cursor at the end of streaming text.
- **D-04:** Full markdown rendering inside assistant bubbles. Bold, italic, lists, headers, and code blocks (code blocks get `#0D0C18` background with SF Mono).
- **D-05:** Tok/s indicator below the assistant bubble during generation. SF Mono 11pt in `#34D399` (green) while streaming, fades to `#6B6980` (tertiary) 2 seconds after completion.

### Model Loading Experience
- **D-06:** Chat view opens immediately. Model loads in the background. Centered 64pt circular progress ring in accent violet on the MeshGradient (no overlay, no dimming). Label: "Loading [Model] [Quant]..." with sublabel "[size] into memory".
- **D-07:** Input bar shows disabled state during loading: "Waiting for model..." at 50% opacity. Send button disabled.
- **D-08:** Load failure handling at Claude's discretion — pick the best UX for the error type (corrupt file vs OOM vs unknown).

### Conversation Behavior
- **D-09:** Stop button replaces send button during generation. 34pt amber (`#FBBF24`) circle with black stop icon. Tapping stops inference immediately, partial response is kept.
- **D-10:** No regenerate button, no message editing. If the response isn't what the user wanted, they follow up with clarification in the conversation. Simpler and more natural.
- **D-11:** System prompt: a small set of presets (e.g., "Helpful assistant", "Creative writer", "Code helper") that populate an editable text field. Lives in a chat settings view (gear icon in chat nav bar), not in the main chat UI.
- **D-12:** Chat tab is the 3rd tab in the bottom tab bar (Browse | Library | Chat). Always shows the active model's conversation.

### Navigation
- **D-13:** Chat nav bar shows "Chat" title + "[Model] · [Quant]" subtitle. Gear icon for settings (system prompt).
- **D-14:** Active model is set by tapping in Library (Phase 3 D-10). Chat tab loads whichever model is active.

### Claude's Discretion
- Model load error handling UX (error in chat view vs bounce to library, based on error type)
- System prompt preset list (which presets to include)
- Chat settings view layout
- How to handle switching active model while a conversation is in progress
- Memory management during inference (when to unload model)
- AsyncStream implementation details for token callbacks

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Foundation
- `.planning/phases/01-device-foundation/01-CONTEXT.md` — D-07 (fixed context window per device tier), D-08 (KV cache in RAM budget)
- `ModelRunner/Services/Device/CompatibilityModels.swift` — DeviceSpecs, ChipProfile with contextWindowCap

### Phase 3 Download + Library
- `.planning/phases/03-download-model-library/03-CONTEXT.md` — D-10 (tap to activate model), D-14 (swift-huggingface cache), D-15 (SwiftData for metadata)

### Design System
- `DESIGN.md` — Full chat UI spec: bubble colors, input bar, loading state, tab bar, download bar. **This is the visual source of truth.**
- `ChatLibraryPreview.playground` — Working SwiftUI playground with chat, library, loading, and tab bar previews

### Project & Requirements
- `.planning/PROJECT.md` — llama.cpp XCFramework for inference, AsyncStream for streaming
- `.planning/REQUIREMENTS.md` — CHAT-01 (streaming chat), CHAT-02 (tok/s display), CHAT-03 (offline), CHAT-06 (UI responsive during inference)

### Research
- `.planning/research/STACK.md` — llama.cpp Swift bindings, inference loop patterns
- `.planning/research/ARCHITECTURE.md` — InferenceService component definition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CompatibilityModels.swift` — ChipProfile has contextWindowCap for configuring inference context size
- `AppContainer` — @Observable, will hold InferenceService
- `DeviceCapabilityService` — Runtime memory checks useful for pre-load validation
- Phase 3's SwiftData model records — active model state, file path to GGUF on disk

### Established Patterns
- @Observable for state management (AppContainer)
- Actor pattern for async services (DeviceCapabilityService)
- iOS 17+ with SwiftUI and SwiftData
- MeshGradient background (shared across all screens)

### Integration Points
- Phase 3's active model selection → Chat tab loads the selected model
- Phase 3's SwiftData DownloadedModel record → provides GGUF file path and metadata for llama.cpp
- Tab bar navigation (Browse | Library | Chat) established in Phase 3
- InferenceService will be added to AppContainer

</code_context>

<specifics>
## Specific Ideas

- The gradient showing through chat is the visual differentiator — every competitor has flat dark backgrounds. ModelRunner's chat has atmosphere.
- Character-by-character streaming with the violet cursor feels alive and responsive
- No regen/edit is a deliberate simplicity choice — the user prefers inline clarification over backtracking
- System prompt presets make the feature accessible to non-technical users while the editable field satisfies power users
- User wants a design consultation (`/design-consultation` or `/design-html`) for the chat interface before or during implementation — captured in DESIGN.md and ChatLibraryPreview.playground

</specifics>

<deferred>
## Deferred Ideas

- Chat history persistence — Phase 5
- Inference parameter tuning (temperature, top-p, system prompt customization) — Phase 5
- Offline-first indicator in UI — could be Phase 5 polish

</deferred>

---

*Phase: 04-inference-chat*
*Context gathered: 2026-04-09*
