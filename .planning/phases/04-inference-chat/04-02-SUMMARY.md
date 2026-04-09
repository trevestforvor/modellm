---
phase: 4
plan: 2
subsystem: inference-chat
tags: [chatviewmodel, streaming, observable, inference]
dependency_graph:
  requires: [04-01]
  provides: [ChatViewModel, ChatMessage, ChatSettings, InferenceService-stub, InferenceParams, PromptFormatter]
  affects: [ChatView, AppContainer]
tech_stack:
  added: []
  patterns: [AsyncThrowingStream token streaming, @Observable @MainActor ViewModel, actor-isolated InferenceService, ContinuousClock tok/s measurement]
key_files:
  created:
    - ModelRunner/Features/Chat/ChatMessage.swift
    - ModelRunner/Features/Chat/ChatSettings.swift
    - ModelRunner/Features/Chat/ChatViewModel.swift
    - ModelRunner/Services/Inference/InferenceService.swift
    - ModelRunner/Services/Inference/InferenceParams.swift
    - ModelRunner/Services/Inference/PromptFormatter.swift
    - ModelRunnerTests/ChatViewModelTests.swift
  modified:
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - ChatViewModel uses @MainActor isolation — isGenerating set synchronously before Task launch so UI updates atomically
  - Context overflow protection uses 4-chars-per-token heuristic, trims oldest messages keeping at least 2
  - InferenceService stub added as Rule 3 deviation (04-01 dependency not yet committed in parallel execution)
  - Test helpers preload stub model so send() enters generating state for concurrent-send tests
metrics:
  duration_minutes: 35
  completed_date: "2026-04-09"
  tasks: 3
  files: 8
---

# Phase 4 Plan 2: ChatViewModel — Conversation State and Streaming Coordination Summary

**One-liner:** @Observable ChatViewModel with AsyncThrowingStream token loop, ContinuousClock tok/s, and context window overflow protection, backed by actor-isolated InferenceService stub.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 04-02-01 | ChatMessage + ChatSettings models | db48a6f |
| 04-02-02 | ChatViewModel + InferenceService/Params/PromptFormatter stubs | 9f44ee8 |
| 04-02-03 | ChatViewModelTests — 11 tests passing | 7c658c5 |

## Verification

- Build: SUCCEEDED (iPhone 16 simulator)
- Tests: 11/11 passed on iPhone 16 simulator
- `@Observable` and `@MainActor` present on ChatViewModel
- `isGenerating`, `tokensPerSecond`, `loadingState` all observable
- `AsyncThrowingStream` iteration pattern in `runGeneration()`
- `stopGeneration()` called on actor in `stop()`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created InferenceService/InferenceParams/PromptFormatter stubs**
- **Found during:** Task 04-02-02
- **Issue:** Plan 04-01 (InferenceService) not yet committed in parallel execution — ChatViewModel cannot compile without these types
- **Fix:** Created stub implementations with correct actor API surface (loadModel, generate, stopGeneration, isLoaded). Stubs are forward-compatible with 04-01 real implementation.
- **Files modified:** ModelRunner/Services/Inference/InferenceService.swift, InferenceParams.swift, PromptFormatter.swift
- **Commit:** 9f44ee8

**2. [Rule 1 - Bug] Fixed testSendAppendsUserMessage and testSendWhileGeneratingIsIgnored**
- **Found during:** Task 04-02-03
- **Issue:** Original plan test code assumed model-not-loaded state would keep `isGenerating = true`, but `runGeneration()` immediately sets `isGenerating = false` when no model is loaded
- **Fix:** Tests now call `makeViewModelWithLoadedModel()` (creates a temp file so stub succeeds) ensuring `isGenerating` stays true during the async generation loop
- **Files modified:** ModelRunnerTests/ChatViewModelTests.swift
- **Commit:** 7c658c5

## Known Stubs

- `InferenceService.generate()` yields a placeholder string char-by-char — full llama.cpp decode loop is Plan 04-01
- `InferenceService.loadModel()` accepts any existing file path without real GGUF validation — 04-01 will add actual llama_load_model_from_file call

## Self-Check: PASSED

- ModelRunner/Features/Chat/ChatMessage.swift: FOUND
- ModelRunner/Features/Chat/ChatSettings.swift: FOUND
- ModelRunner/Features/Chat/ChatViewModel.swift: FOUND
- ModelRunner/Services/Inference/InferenceService.swift: FOUND
- ModelRunner/Services/Inference/InferenceParams.swift: FOUND
- ModelRunner/Services/Inference/PromptFormatter.swift: FOUND
- ModelRunnerTests/ChatViewModelTests.swift: FOUND
- Commits db48a6f, 9f44ee8, 7c658c5: FOUND
