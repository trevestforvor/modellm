---
phase: 4
plan: 1
subsystem: inference
tags: [llama.cpp, actor, AsyncThrowingStream, inference, chat]
dependency_graph:
  requires: [03-04]
  provides: [InferenceService, InferenceParams, PromptFormatter, LlamaSession, ChatMessage]
  affects: [AppContainer, Phase4Plans]
tech_stack:
  added: []
  patterns: [Swift actor for KV cache isolation, AsyncThrowingStream token bridge, Task.detached for CHAT-06]
key_files:
  created:
    - ModelRunner/Services/Inference/InferenceService.swift
    - ModelRunner/Services/Inference/LlamaSession.swift
    - ModelRunner/Services/Inference/InferenceParams.swift
    - ModelRunner/Services/Inference/PromptFormatter.swift
    - ModelRunner/Models/ChatMessage.swift
    - ModelRunnerTests/PromptFormatterTests.swift
    - ModelRunnerTests/InferenceServiceTests.swift
  modified:
    - ModelRunner/App/AppContainer.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - "LlamaSession stub with XCFramework integration comments — XCFramework binary target requires Xcode UI, cannot be added via pbxproj editing alone"
  - "ChatMessage defined in Models/ as canonical type for Phase 4 to avoid re-definition in 04-02"
  - "Swift Testing used instead of XCTest — matches all existing test files in codebase"
  - "LlamaSession.runDecodeLoop() finishes immediately when XCFramework not linked — correct behavior for state-only unit tests"
metrics:
  duration_seconds: 630
  completed_date: "2026-04-09T12:30:03Z"
  tasks_completed: 6
  files_created: 7
  files_modified: 2
---

# Phase 4 Plan 1: InferenceService — llama.cpp XCFramework Integration Summary

**One-liner:** Swift actor InferenceService with AsyncThrowingStream token bridge, protocol-based LlamaSession stub with full XCFramework integration comments, and PromptFormatter.chatml() for ChatML prompt formatting.

## What Was Built

### InferenceService (actor)
- Actor isolation prevents concurrent access to `llama_context*` KV cache
- `generate(prompt:)` returns `AsyncThrowingStream<String, Error>` — inference on `Task.detached`
- `stopGeneration()` uses actor-isolated boolean (`session.isCancelled`) — not just `Task.cancel()`
- `loadModel/unloadModel` lifecycle, `isLoaded` state property
- CHAT-06 compliance: inference never runs on MainActor

### LlamaSession
- Wraps model URL + InferenceParams; guards file existence at init (throws `modelLoadFailed` if missing)
- Full XCFramework integration comments in `init()` and `runDecodeLoop()` showing exact C API calls
- `isCancelled: Bool` checked by decode loop stub
- Currently finishes stream immediately (no XCFramework linked) — correct for unit tests

### InferenceParams
- `contextWindowTokens` from `ChipProfile.contextWindowCap` (Phase 1 integration point)
- `batchSize: 512`, `gpuLayers: 99` (full Metal offload)

### PromptFormatter
- `chatml(system:messages:)` static func — ChatML template for GGUF models

### ChatMessage
- `MessageRole` enum (user/assistant), `ChatMessage` struct with Identifiable + Sendable
- Defined canonically in `Models/` to avoid duplication with 04-02

### AppContainer
- `inferenceService: InferenceService()` added (Phase 4 section)
- `inferenceParams()` convenience builds from `device.chipProfile.contextWindowCap`

### Tests (Swift Testing)
- `PromptFormatterTests`: 5 tests — chatml format, role order, multi-turn, token count
- `InferenceServiceTests`: 6 tests — state transitions (no GGUF file required)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Convention] Used Swift Testing instead of XCTest**
- **Found during:** Task 04-01-05
- **Issue:** Plan specified XCTest but all 9 existing test files use Swift Testing framework
- **Fix:** Used `import Testing`, `@Suite`, `@Test`, `#expect`, `Issue.record()` to match codebase
- **Files modified:** PromptFormatterTests.swift, InferenceServiceTests.swift

**2. [Rule 3 - Blocking] XCFramework binary target not addable via pbxproj**
- **Found during:** Task 04-01-01
- **Issue:** llama.cpp XCFramework must be added through Xcode's SPM package resolution UI — pbxproj doesn't support SPM binary targets as plain file references
- **Fix:** Created protocol-ready stub (`LlamaSession`) with comprehensive XCFramework integration comments. InferenceService actor architecture is complete and correct — only the C API calls need to be wired in when XCFramework is linked.
- **Action required:** Open project in Xcode → File → Add Package Dependencies → add binary target at `https://github.com/ggml-org/llama.cpp/releases/download/b5046/llama-b5046-xcframework.zip` → link LlamaFramework to ModelRunner target → uncomment `import LlamaFramework` and implement `LlamaSession.init()` and `runDecodeLoop()` bodies.

**3. [Out of scope] Cross-agent build failures from 04-02 incomplete types**
- **Found during:** Build verification
- **Issue:** `ChatView.swift` (04-02 agent) references `ChatViewModel` and `ChatSettings` types that don't exist yet. This breaks the full project build.
- **Not fixed:** Out of scope (04-02's files, not caused by 04-01 changes)
- **Deferred to:** 04-02 plan completion

## Known Stubs

| File | Line | Description | Resolution |
|------|------|-------------|------------|
| `LlamaSession.swift` | init() | No actual llama.cpp C API calls — file existence guarded only | Uncomment XCFramework calls after binary target linked |
| `LlamaSession.swift` | runDecodeLoop() | Immediately finishes stream with no tokens | Replace with actual decode loop using llama_decode() |

These stubs are intentional — the InferenceService architecture is complete. The stubs prevent the XCFramework requirement from blocking parallel Phase 4 plans.

## Self-Check: PASSED

Files created:
- /Users/trevest/Developer/models/ModelRunner/Services/Inference/InferenceService.swift ✓
- /Users/trevest/Developer/models/ModelRunner/Services/Inference/LlamaSession.swift ✓
- /Users/trevest/Developer/models/ModelRunner/Services/Inference/InferenceParams.swift ✓
- /Users/trevest/Developer/models/ModelRunner/Services/Inference/PromptFormatter.swift ✓
- /Users/trevest/Developer/models/ModelRunner/Models/ChatMessage.swift ✓
- /Users/trevest/Developer/models/ModelRunnerTests/PromptFormatterTests.swift ✓
- /Users/trevest/Developer/models/ModelRunnerTests/InferenceServiceTests.swift ✓

Commits:
- bb02036: chore(04-01): pbxproj — Inference group ✓
- 5fc3b81: feat(04-01): InferenceParams, PromptFormatter, LlamaSession, ChatMessage ✓
- ca292e4: feat(04-01): InferenceService actor ✓
- b21b722: test(04-01): PromptFormatter tests ✓
- a21841f: test(04-01): InferenceService tests ✓
