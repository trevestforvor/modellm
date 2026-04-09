---
phase: 5
plan: 1
subsystem: data-layer
tags: [swiftdata, schema, conversation, inference-params]
dependency_graph:
  requires: [phase-04-inference-chat]
  provides: [conversation-schema, message-schema, inference-preset, per-model-settings]
  affects: [05-02-chat-settings, 05-03-conversation-persistence, 05-04-onboarding]
tech_stack:
  added: [SwiftData @Model, InferencePreset enum]
  patterns: [cascade-delete relationship, per-model inference parameters, wave-0 test stubs]
key_files:
  created:
    - ModelRunner/Models/Conversation.swift
    - ModelRunner/Models/Message.swift
    - ModelRunner/Models/InferencePreset.swift
    - ModelRunnerTests/ConversationTests.swift
    - ModelRunnerTests/InferencePresetTests.swift
  modified:
    - ModelRunner/Models/DownloadedModel.swift
    - ModelRunner/App/ModelRunnerApp.swift
    - ModelRunner/Services/Inference/InferenceParams.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - "InferenceParams.from(model:) is internal (not public) — DownloadedModel is internal, public method cannot reference internal type"
  - "role stored as String in Message (not enum) — simplifies SwiftData persistence, no Codable conformance needed"
  - "InferencePreset values: precise(0.3,0.7), balanced(0.7,0.9), creative(1.2,0.95)"
metrics:
  duration_seconds: 539
  completed_date: "2026-04-09"
  tasks_completed: 6
  files_changed: 9
---

# Phase 5 Plan 1: SwiftData Schema — Conversation, Message, and Per-Model Settings Summary

**One-liner:** Conversation and Message @Model types with cascade-delete, InferencePreset enum (precise/balanced/creative), and per-model temperature/topP/systemPrompt fields on DownloadedModel.

## What Was Built

Extended the SwiftData schema from Phase 3's single `DownloadedModel` to a 3-model schema:

- `Conversation @Model` — stores chat sessions with `modelRepoId`, `modelDisplayName`, `modelQuantization`, timestamps, and cascade-delete relationship to `[Message]`
- `Message @Model` — stores individual chat turns with `role` (String "user"/"assistant"), `content`, `createdAt`, and inverse relationship to `Conversation`
- `InferencePreset` enum — maps `.precise` → (0.3, 0.7), `.balanced` → (0.7, 0.9), `.creative` → (1.2, 0.95) with `apply(to: DownloadedModel)` helper
- `DownloadedModel` extended with `temperature: Double = 0.7`, `topP: Double = 0.9`, `systemPrompt: String` — no migration needed, defaults applied on first access
- `ModelContainer` updated to register all 3 model types
- `InferenceParams` extended with `temperature`, `topP`, `systemPrompt` fields and `from(model:contextWindowCap:)` factory method
- Wave-0 test stubs: 6 `ConversationTests` (including cascade-delete in-memory test) and 6 `InferencePresetTests`

## Decisions Made

1. `InferenceParams.from(model:)` is `internal` — `DownloadedModel` is internal, Swift forbids `public` methods that reference internal types
2. `role` stored as `String` in `Message`, not an enum — avoids Codable conformance requirement for SwiftData persistence; valid values are `"user"` and `"assistant"`
3. `InferencePreset` in its own file `InferencePreset.swift` — clean separation, used across ChatSettingsView and ChatViewModel

## Deviations from Plan

### Parallel Execution Note

05-04 (WelcomeView/Onboarding) agent ran in parallel and committed the 05-01 schema files as a dependency it needed first (`feat(05-04)` commit `4d0e6d2`). All 05-01 files are present in the repository with correct content matching the plan spec. The files I created locally were the same content and were absorbed into the 05-04 commit.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed InferenceParams.from(model:) visibility**
- **Found during:** Task 05-01-05 / build verification
- **Issue:** `public static func from(model: DownloadedModel, ...)` — `DownloadedModel` is `internal`, Swift forbids `public` methods with internal parameters
- **Fix:** Changed to `static func from(model:)` (internal visibility)
- **Files modified:** `ModelRunner/Services/Inference/InferenceParams.swift`

## Known Stubs

None — all schema types are fully implemented. Test stubs (wave-0) exist in `ConversationTests` and `InferencePresetTests` and run as passing XCTest cases.

## Self-Check: PASSED

- ModelRunner/Models/Conversation.swift — FOUND
- ModelRunner/Models/Message.swift — FOUND
- ModelRunner/Models/InferencePreset.swift — FOUND
- ModelRunnerTests/ConversationTests.swift — FOUND
- ModelRunnerTests/InferencePresetTests.swift — FOUND
- @Model in Conversation.swift — 1 (PASS)
- deleteRule: .cascade in Conversation.swift — 1 (PASS)
- generateTitle in Conversation.swift — 1 (PASS)
- temperature in DownloadedModel.swift — 1 (PASS)
- Conversation.self in ModelRunnerApp.swift — 1 (PASS)
- Message.self in ModelRunnerApp.swift — 1 (PASS)
- from(model: in InferenceParams.swift — 1 (PASS)
- func test in ConversationTests.swift — 6 (PASS)
- func test in InferencePresetTests.swift — 6 (PASS)
- BUILD SUCCEEDED — PASS
