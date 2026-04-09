---
phase: 04-inference-chat
verified: 2026-04-09T00:00:00Z
status: gaps_found
score: 6/7 must-haves verified
gaps:
  - truth: "ChatViewModel unit tests exist and cover key behaviors"
    status: failed
    reason: "ChatViewModelTests.swift was planned in 04-02 but does not exist in ModelRunnerTests/"
    artifacts:
      - path: "ModelRunnerTests/ChatViewModelTests.swift"
        issue: "File missing — plan 04-02 required >= 7 test functions covering send, stop, load states"
    missing:
      - "Create ModelRunnerTests/ChatViewModelTests.swift with at minimum: testInitialState, testSendEmptyTextDoesNothing, testSendAppendsUserMessage, testSendWhileGeneratingIsIgnored, testStopClearsGeneratingState, testLoadModelFailedUpdatesState, testDefaultSystemPromptIsHelpful"
human_verification:
  - test: "Chat tab renders with MeshGradient and bubble layout"
    expected: "Launch app on simulator, navigate to Chat tab — dark violet gradient visible, 'No model selected' empty state with cpu icon shown"
    why_human: "Visual UI verification requires simulator rendering"
  - test: "Send/Stop button swaps correctly"
    expected: "After tapping Send (violet arrow.up), button turns amber stop.fill; after tapping Stop, reverts to arrow.up"
    why_human: "Requires interactive UI session"
---

# Phase 4: Inference & Chat Verification Report

**Phase Goal:** Users can have a streaming conversation with a downloaded model entirely on-device
**Verified:** 2026-04-09
**Status:** gaps_found — 1 gap (missing test file)
**Re-verification:** No — initial verification

## Important Context

LlamaSession is intentionally a stub that throws `modelLoadFailed` because the llama.cpp XCFramework has NOT been added to the project yet. The architecture (InferenceService actor, ChatViewModel streaming, ChatView UI) is verified as wired end-to-end such that swapping in the real XCFramework is a single-file change in `LlamaSession.swift`.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | InferenceService actor wraps LlamaSession with AsyncThrowingStream and Task.detached | VERIFIED | `actor InferenceService`, `Task.detached`, `AsyncThrowingStream` all present in InferenceService.swift:19,82,83,88 |
| 2 | ChatViewModel is @Observable @MainActor and coordinates streaming tokens | VERIFIED | Both attributes present; `for try await token in stream` at line 113; `isGenerating`, `tokensPerSecond` observable |
| 3 | ChatView UI is wired to ChatViewModel with bubble list, input bar, loading state | VERIFIED | ChatBubbleView, ChatInputBar, ChatLoadingView, MeshGradient, ScrollViewReader all referenced in ChatView.swift |
| 4 | Chat tab is wired into the tab bar | VERIFIED | `ChatView` at ContentView.swift:31, `bubble.left.fill` at line 38 |
| 5 | Design spec colors and stop button are correct | VERIFIED | #8B7CF0 user bubbles, #1A1830 assistant bubbles, #FBBF24 stop, #34D399 tok/s badge |
| 6 | PromptFormatter and InferenceService have unit tests | VERIFIED | PromptFormatterTests.swift (5 tests), InferenceServiceTests.swift (6 tests) |
| 7 | ChatViewModel has unit tests | FAILED | ChatViewModelTests.swift does not exist |

**Score:** 6/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ModelRunner/Services/Inference/InferenceService.swift` | Actor with AsyncThrowingStream + Task.detached | VERIFIED | All key patterns present |
| `ModelRunner/Services/Inference/LlamaSession.swift` | Stub throwing modelLoadFailed | VERIFIED | Throws at line 78; commented XCFramework calls ready |
| `ModelRunner/Services/Inference/InferenceParams.swift` | contextWindowTokens, batchSize, gpuLayers | VERIFIED | Exists |
| `ModelRunner/Services/Inference/PromptFormatter.swift` | chatml() with im_start tokens | VERIFIED | Exists |
| `ModelRunner/Models/ChatMessage.swift` | struct ChatMessage with isStreaming | VERIFIED | At Models/ not Features/Chat/ — diverges from plan path, but type is correct |
| `ModelRunner/Features/Chat/ChatViewModel.swift` | @Observable @MainActor with streaming loop | VERIFIED | All required patterns present |
| `ModelRunner/Features/Chat/ChatView.swift` | Bubble list + MeshGradient + input bar | VERIFIED | All subcomponents referenced |
| `ModelRunner/Features/Chat/ChatBubbleView.swift` | UnevenRoundedRectangle, violet user, dark assistant | VERIFIED | Colors and corner radii match spec |
| `ModelRunner/Features/Chat/ChatInputBar.swift` | Send/stop swap, FBBF24, arrow.up/stop.fill | VERIFIED | All patterns present |
| `ModelRunner/Features/Chat/ChatLoadingView.swift` | Rotating progress ring, #8B7CF0 | VERIFIED | Exists with rotation animation |
| `ModelRunner/Features/Chat/ChatSettingsView.swift` | SystemPromptPreset picker + editable field | VERIFIED | Exists |
| `ModelRunner/Features/Chat/ToksPerSecondBadge.swift` | SF Mono, #34D399, fades after generation | VERIFIED | Exists with monospaced font and color |
| `ModelRunner/App/AppContainer.swift` | inferenceService + inferenceParams() | VERIFIED | Lines 30, 57 |
| `ModelRunnerTests/PromptFormatterTests.swift` | >= 4 test functions | VERIFIED | 5 test functions |
| `ModelRunnerTests/InferenceServiceTests.swift` | >= 4 test functions | VERIFIED | 6 test functions |
| `ModelRunnerTests/ChatViewModelTests.swift` | >= 7 test functions | MISSING | File does not exist |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| ChatView | ChatViewModel | @State private var viewModel | WIRED | ChatView creates and holds ChatViewModel via setupViewModel() |
| ChatView | AppContainer | @Environment(AppContainer.self) | WIRED | Environment injection, container.inferenceService passed to VM |
| ChatViewModel | InferenceService | actor call `inferenceService.generate(prompt:)` | WIRED | Line 111 in ChatViewModel.swift |
| ChatViewModel | InferenceService | `inferenceService.stopGeneration()` | WIRED | Line 66 in ChatViewModel.swift |
| ChatViewModel | PromptFormatter | `PromptFormatter.chatml(system:messages:)` | WIRED | Called in buildPrompt() |
| InferenceService | LlamaSession | `session = try LlamaSession(modelURL:params:)` | WIRED | Line in InferenceService; throws until XCFramework added |
| ContentView | ChatView | Tab "Chat" with bubble.left.fill | WIRED | ContentView.swift:31,38 |
| AppContainer | InferenceService | `let inferenceService = InferenceService()` | WIRED | AppContainer.swift:30 |

### Data-Flow Trace (Level 4)

N/A — LlamaSession is an intentional stub. Data flow is architecturally complete but inference produces no tokens until XCFramework is integrated. This is expected per phase context.

### Behavioral Spot-Checks

Step 7b: SKIPPED — inference requires llama.cpp XCFramework (not yet linked) and physical device for meaningful output. Build compilation is the correct check here.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| CHAT-01 | 04-01, 04-02, 04-03 | User can load a downloaded model and chat with streaming output | SATISFIED (architecture) | InferenceService + ChatViewModel + ChatView fully wired; blocked on XCFramework for actual tokens |
| CHAT-02 | 04-02, 04-03 | App displays tokens/sec during inference | SATISFIED | ToksPerSecondBadge with tokensPerSecond from ChatViewModel |
| CHAT-03 | 04-01, 04-02, 04-03 | Chat works fully offline after model download | SATISFIED | No network calls in inference path; all on-device via llama.cpp |
| CHAT-06 | 04-01, 04-02, 04-03 | Inference runs on background thread — UI remains responsive | SATISFIED | Task.detached in InferenceService.swift:88; @MainActor on ChatViewModel for UI updates only |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| LlamaSession.swift | 91 | Commented-out `throw InferenceError.modelLoadFailed(...)` inside decode path | Info | Intentional — marks where XCFramework call goes; not a blocking stub |
| ChatView.swift | 503 | `activeModelURL: URL?` defaults to nil — no Phase 3 active model wired | Warning | Chat shows "No model selected" empty state until Phase 3 active model selection is complete; by design per 04-03 plan |

No blockers found. The LlamaSession stub is architecturally correct and documented. All rendering paths use real data from the ViewModel.

### Human Verification Required

1. **Chat tab visual rendering**
   - Test: Launch simulator, navigate to Chat tab
   - Expected: Dark MeshGradient background visible, "No model selected" empty state with cpu icon and instruction text
   - Why human: Requires visual inspection of SwiftUI rendering

2. **Send/Stop button swap animation**
   - Test: With a loaded model, tap Send — observe button; tap Stop — observe revert
   - Expected: Violet arrow.up → amber stop.fill on send; returns to arrow.up after stop
   - Why human: Requires interactive UI; can't automate without XCFramework delivering tokens

### Gaps Summary

One gap blocking full test coverage: `ChatViewModelTests.swift` was specified in plan 04-02 (>= 7 test functions covering initial state, send behaviors, stop, load state, and settings) but was not created. The PromptFormatter and InferenceService test files are complete and substantive.

The architecture is fully wired. Swapping in the real llama.cpp XCFramework requires only filling in the C API calls in `LlamaSession.swift` — the actor, streaming, and UI layers require no changes.

---

_Verified: 2026-04-09_
_Verifier: Claude (gsd-verifier)_
