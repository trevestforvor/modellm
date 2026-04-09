---
phase: 5
slug: polish-v1-completeness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing) |
| **Config file** | `ModelRunner.xcodeproj` — existing test target `ModelRunnerTests` |
| **Quick run command** | `xcodebuild test -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing ModelRunnerTests/ConversationTests -only-testing ModelRunnerTests/InferencePresetTests -only-testing ModelRunnerTests/ChatViewModelPersistenceTests 2>&1 \| grep -E "(passed\|failed\|error)"` |
| **Full suite command** | `xcodebuild test -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 \| grep -E "(passed\|failed\|error)"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (ConversationTests + InferencePresetTests)
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | CHAT-04 | unit | `grep -c "@Model" ModelRunner/Models/Conversation.swift` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | CHAT-04 | unit | `grep -c "@Model" ModelRunner/Models/Message.swift` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 1 | CHAT-04 | unit | `grep -c "Conversation.self" ModelRunner/App/ModelRunnerApp.swift` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 1 | CHAT-04 | unit | `xcodebuild test ... -only-testing ModelRunnerTests/ConversationTests` | ❌ W0 | ⬜ pending |
| 05-01-05 | 01 | 2 | CHAT-04 | unit | `xcodebuild test ... -only-testing ModelRunnerTests/ChatViewModelPersistenceTests` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | CHAT-05 | unit | `grep -c "temperature" ModelRunner/Models/DownloadedModel.swift` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | CHAT-05 | unit | `grep -c "temperature" ModelRunner/Services/Inference/InferenceParams.swift` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 1 | CHAT-05 | unit | `xcodebuild test ... -only-testing ModelRunnerTests/InferencePresetTests` | ❌ W0 | ⬜ pending |
| 05-02-04 | 02 | 2 | CHAT-05 | build | `xcodebuild build ... 2>&1 \| grep -c "error:"` returns 0 | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 1 | CHAT-04 | build | `grep -c "showingHistory" ModelRunner/Features/Chat/ChatView.swift` | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 1 | CHAT-04 | build | `grep -c "defaultScrollAnchor" ModelRunner/Features/Chat/ConversationHistoryView.swift` | ❌ W0 | ⬜ pending |
| 05-03-03 | 03 | 2 | CHAT-04 | manual | App restart: conversation visible in history overlay | — | ⬜ pending |
| 05-04-01 | 04 | 1 | — | build | `grep -c "hasCompletedOnboarding" ModelRunner/App/ModelRunnerApp.swift` | ❌ W0 | ⬜ pending |
| 05-04-02 | 04 | 1 | — | manual | Fresh install: welcome screen appears. Subsequent launch: no welcome screen. | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ModelRunnerTests/ConversationTests.swift` — stubs for CHAT-04 (Conversation + Message persistence, cascade delete)
- [ ] `ModelRunnerTests/ChatViewModelPersistenceTests.swift` — stubs for CHAT-04 (startNewConversation, send persists messages)
- [ ] `ModelRunnerTests/InferencePresetTests.swift` — stubs for CHAT-05 (preset pill values, temperature/topP ranges)

*Existing infrastructure (XCTest + ModelRunnerTests target) covers the framework. Only new stub files are required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Conversation persists across app restart | CHAT-04 | Requires real SQLite persistence, not in-memory | Send a message. Force-quit app. Reopen. Tap clock icon. Verify conversation appears. |
| Return to past conversation and continue | CHAT-04 | Requires full UI flow | From history overlay, tap a past conversation. Verify messages reload. Send a new message. Verify it appends. |
| Temperature affects inference output | CHAT-05 | Requires physical device + loaded model | Set Precise preset. Ask "Tell me a story." Set Creative preset. Ask same question. Verify responses differ in variability. |
| History overlay spring animation | CHAT-04 | Visual/motion, not grep-checkable | Tap clock button. Verify overlay springs up with 0.3s bounce. Tap again. Verify spring dismiss. |
| Guided onboarding picks smallest Runs Well model | — | Requires device + downloaded models | On fresh install with 2+ models downloaded, tap "Show Me Around." Verify smallest compatible model is selected. |
| Welcome screen shows once only | — | Requires UserDefaults persistence across launches | Fresh install: welcome appears. Tap either button. Force-quit. Reopen. Verify no welcome screen. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
