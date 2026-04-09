---
phase: 05-polish-v1-completeness
verified: 2026-04-09T00:00:00Z
status: gaps_found
score: 4/6 must-haves verified
re_verification: false
gaps:
  - truth: "User can adjust temperature, system prompt, and top-p before or during a session (CHAT-05) — values reach inference"
    status: failed
    reason: "AppContainer.inferenceParams() calls InferenceParams.default(...) unconditionally. InferenceParams.from(model:) factory is dead code — never called. Temperature and topP written via ChatSettingsView to SwiftData are ignored at inference time."
    artifacts:
      - path: "ModelRunner/App/AppContainer.swift"
        issue: "inferenceParams() returns InferenceParams.default(contextWindowCap:) instead of InferenceParams.from(model:contextWindowCap:)"
      - path: "ModelRunner/Services/Inference/InferenceParams.swift"
        issue: "from(model:contextWindowCap:) factory exists but is never called"
    missing:
      - "AppContainer.inferenceParams() must fetch the active DownloadedModel from SwiftData and delegate to InferenceParams.from(model:contextWindowCap:)"
      - "Or ChatView must build InferenceParams.from(model:...) and pass it to ChatViewModel on init/reload"
  - truth: "User can adjust temperature, system prompt, and top-p — system prompt reaches inference"
    status: failed
    reason: "ChatViewModel.settings is ChatSettings loaded from UserDefaults (not SwiftData DownloadedModel.systemPrompt). ChatSettingsView writes systemPrompt to DownloadedModel in SwiftData, but ChatViewModel reads from the old UserDefaults path. The two are disconnected."
    artifacts:
      - path: "ModelRunner/Features/Chat/ChatViewModel.swift"
        issue: "Line 31: var settings: ChatSettings = ChatSettings.load() — reads systemPrompt from UserDefaults, not from DownloadedModel.systemPrompt"
      - path: "ModelRunner/Features/Chat/ChatSettings.swift"
        issue: "Still serves as the runtime source for systemPrompt despite Phase 5 migrating it to SwiftData"
    missing:
      - "ChatViewModel must use activeModel.systemPrompt in buildPrompt() instead of settings.systemPrompt"
      - "Either remove ChatSettings UserDefaults path or keep it in sync with SwiftData (former preferred)"
human_verification:
  - test: "Verify conversation history overlay visual appearance"
    expected: "Bottom-anchored glass rows, blur/vibrancy background, rows scroll from bottom"
    why_human: "Glass/vibrancy rendering requires device/simulator run"
  - test: "Verify WelcomeView two-path onboarding flow"
    expected: "Two buttons — guided tour and browse directly — both navigate correctly"
    why_human: "Navigation flow requires runtime testing"
---

# Phase 5: Polish + v1 Completeness Verification Report

**Phase Goal:** Chat history persists, inference parameters are adjustable, and the full pipeline has no rough edges
**Verified:** 2026-04-09
**Status:** gaps_found — 2 gaps blocking CHAT-05 goal achievement
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can close/reopen and find previous conversations intact (CHAT-04) | VERIFIED | ChatViewModel.loadMostRecentConversation() fetches via FetchDescriptor, inserts to activeConversation; user messages and assistant messages persisted to SwiftData on every send |
| 2 | User can return to any past conversation and continue it (CHAT-04) | VERIFIED | ConversationHistoryView wired in ChatView; onSelect sets vm.activeConversation and rebuilds messages array with correct role mapping |
| 3 | User can adjust temperature and top-p — values reach inference | FAILED | ChatSettingsView writes to DownloadedModel.temperature/.topP in SwiftData correctly, but AppContainer.inferenceParams() calls InferenceParams.default() ignoring those values |
| 4 | User can adjust system prompt — value reaches inference | FAILED | ChatSettingsView writes to DownloadedModel.systemPrompt in SwiftData, but ChatViewModel.buildPrompt() reads from ChatSettings (UserDefaults). Two separate system prompt stores, wrong one wins |
| 5 | Welcome screen with two-path onboarding exists | VERIFIED | WelcomeView.swift exists with two Button actions: handleShowMeAround (guided) and .browse (direct) |
| 6 | Per-model parameter settings with preset pills | VERIFIED | ChatSettingsView has ForEach(InferencePreset.allCases), temperature Slider, topP Slider, systemPrompt TextEditor all wired to DownloadedModel |

**Score:** 4/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ModelRunner/Models/Conversation.swift` | @Model with cascade delete + generateTitle | VERIFIED | @Model, @Attribute(.unique), deleteRule: .cascade, generateTitle all present |
| `ModelRunner/Models/Message.swift` | @Model with inverse relationship | VERIFIED | @Model, @Attribute(.unique), conversation: Conversation? present |
| `ModelRunner/Models/InferencePreset.swift` | Enum with precise/balanced/creative presets | VERIFIED | All 3 cases, correct values (0.3/0.7, 0.7/0.9, 1.2/0.95) |
| `ModelRunner/Models/DownloadedModel.swift` | temperature, topP, systemPrompt fields | VERIFIED | All 3 fields present |
| `ModelRunner/App/ModelRunnerApp.swift` | ModelContainer with Conversation.self, Message.self | VERIFIED | Both types registered |
| `ModelRunner/Services/Inference/InferenceParams.swift` | temperature, topP, systemPrompt + from(model:) | VERIFIED (definition only) | Factory method exists but is never called |
| `ModelRunner/App/AppContainer.swift` | inferenceParams() uses DownloadedModel settings | FAILED | Calls InferenceParams.default() — ignores per-model SwiftData fields |
| `ModelRunner/Features/Chat/ChatViewModel.swift` | systemPrompt from SwiftData DownloadedModel | FAILED | Reads from ChatSettings (UserDefaults) at line 31 |
| `ModelRunner/Features/Chat/ConversationHistoryView.swift` | Bottom-anchored history overlay | VERIFIED | .defaultScrollAnchor(.bottom) present |
| `ModelRunner/Features/Onboarding/WelcomeView.swift` | Two-path onboarding | VERIFIED | Two button paths present |
| `ModelRunnerTests/ConversationTests.swift` | >= 5 tests including cascade | VERIFIED | 6 tests including testDeleteConversationCascadesToMessages |
| `ModelRunnerTests/InferencePresetTests.swift` | >= 5 tests | VERIFIED | 6 tests covering all preset values and ranges |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| ChatSettingsView sliders | DownloadedModel.temperature/.topP | $model.temperature binding | WIRED | Direct SwiftData @Model binding |
| ChatSettingsView | DownloadedModel.systemPrompt | $model.systemPrompt binding | WIRED | TextEditor bound to model.systemPrompt |
| DownloadedModel.temperature/.topP | InferenceParams | InferenceParams.from(model:) | NOT_WIRED | Factory exists, never called; AppContainer.inferenceParams() uses .default() |
| DownloadedModel.systemPrompt | ChatViewModel.buildPrompt() | activeModel.systemPrompt | NOT_WIRED | buildPrompt() reads ChatSettings.systemPrompt from UserDefaults instead |
| ChatView onSelect | ChatViewModel | vm.activeConversation + vm.messages | WIRED | Line 91-94 in ChatView.swift |
| ChatViewModel | SwiftData Conversation/Message | modelContext.insert / save | WIRED | User messages line 117-124, assistant messages line 201-204 |
| AppContainer | InferenceService | inferenceParams() | PARTIAL | Called at ChatView line 226, but returns hardcoded defaults |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| ChatSettingsView | model.temperature | DownloadedModel @Model (SwiftData) | Yes — writes to persistent store | FLOWING |
| InferenceService.generate | params.temperature | AppContainer.inferenceParams() | No — always 0.7 default | STATIC |
| ChatViewModel.buildPrompt | settings.systemPrompt | ChatSettings.load() (UserDefaults) | No — ignores SwiftData model.systemPrompt | STATIC |
| ConversationHistoryView | conversations (FetchRequest) | SwiftData @Query | Yes — fetches real persisted conversations | FLOWING |
| ChatView messages restore | vm.messages | conversation.messages mapped to ChatMessage | Yes — reads persisted Message records | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — requires running simulator (iOS app, not a CLI/API).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| CHAT-04 | 05-01, 05-02 | User can view and return to previous chat conversations | SATISFIED | Conversation/Message @Models with SwiftData persistence; ConversationHistoryView; loadMostRecentConversation() |
| CHAT-05 | 05-01, 05-03 | User can adjust inference parameters (temperature, system prompt, top-p) | PARTIAL | UI writes to SwiftData correctly; values do not reach inference engine (blocked by AppContainer + ChatViewModel gaps) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `ModelRunner/App/AppContainer.swift` | 59 | `InferenceParams.default(contextWindowCap:)` — ignores DownloadedModel settings | Blocker | CHAT-05 temperature/topP never applied to inference |
| `ModelRunner/Features/Chat/ChatViewModel.swift` | 31 | `ChatSettings.load()` — reads systemPrompt from UserDefaults instead of SwiftData | Blocker | System prompt set in UI never reaches inference |

### Human Verification Required

#### 1. Conversation History Overlay Visual

**Test:** Launch app with a model active, tap the clock button, verify ConversationHistoryView appears as a bottom-anchored overlay with glass/vibrancy rows
**Expected:** Semi-transparent overlay, rows visible from bottom of chat area, scrollable
**Why human:** Glass material and vibrancy rendering requires running simulator

#### 2. WelcomeView Two-Path Navigation

**Test:** Fresh install (or delete app data), launch app, verify WelcomeView appears with two distinct action paths
**Expected:** "Show me around" guides through onboarding; second button navigates directly to Browse tab
**Why human:** Navigation flow and conditional display of WelcomeView requires runtime

### Gaps Summary

Two related gaps both trace to the same root cause: the Phase 5 plan correctly migrated per-model inference parameters to SwiftData (DownloadedModel fields) and the write path is properly wired (ChatSettingsView -> SwiftData), but the READ path was not updated.

1. **temperature/topP gap:** `AppContainer.inferenceParams()` calls `InferenceParams.default(...)` unconditionally. The `InferenceParams.from(model:contextWindowCap:)` factory built in 05-01 is dead code. Fix: fetch the active DownloadedModel in AppContainer and call the factory, OR refactor ChatView to build InferenceParams from the model and pass it to ChatViewModel.

2. **systemPrompt gap:** `ChatViewModel.buildPrompt()` reads `settings.systemPrompt` where `settings` is `ChatSettings.load()` from UserDefaults. This is the Phase 4 UserDefaults path that Phase 5 was meant to replace. Fix: replace `settings.systemPrompt` in `buildPrompt()` with `activeModel?.systemPrompt ?? "You are a helpful assistant."` where activeModel is the current DownloadedModel from SwiftData.

These are the only two blockers. CHAT-04 (conversation persistence and history) is fully achieved.

---

_Verified: 2026-04-09_
_Verifier: Claude (gsd-verifier)_
