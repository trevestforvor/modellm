---
phase: 4
slug: inference-chat
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift Testing for new tests) |
| **Config file** | `ModelRunnerTests/` — existing test target |
| **Quick run command** | `xcodebuild test -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16' -testPlan UnitOnly 2>/dev/null | xcpretty` |
| **Full suite command** | `xcodebuild test -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16' 2>/dev/null | xcpretty` |
| **Estimated runtime** | ~30 seconds (unit only), integration tests require physical device |

---

## Sampling Rate

- **After every task commit:** Run quick unit command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green (unit tests); integration tests documented separately
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 04-01-01 | 01 | 1 | CHAT-01 | unit | `grep -r "AsyncThrowingStream" ModelRunner/Services/Inference/` | ⬜ pending |
| 04-01-02 | 01 | 1 | CHAT-06 | unit | `grep -r "Task.detached" ModelRunner/Services/Inference/` | ⬜ pending |
| 04-01-03 | 01 | 1 | CHAT-01 | unit | `xcodebuild test ... -only-testing InferenceServiceTests` | ⬜ pending |
| 04-02-01 | 02 | 2 | CHAT-01 | unit | `grep -r "ChatViewModel" ModelRunner/Features/Chat/` | ⬜ pending |
| 04-02-02 | 02 | 2 | CHAT-02 | unit | `grep -r "tokensPerSecond" ModelRunner/Features/Chat/` | ⬜ pending |
| 04-02-03 | 02 | 2 | CHAT-06 | unit | `grep -r "isGenerating" ModelRunner/Features/Chat/` | ⬜ pending |
| 04-03-01 | 03 | 3 | CHAT-01 | manual | Visual: tokens stream in chat view on simulator | ⬜ pending |
| 04-03-02 | 03 | 3 | CHAT-02 | manual | Visual: tok/s badge appears below assistant bubble | ⬜ pending |
| 04-03-03 | 03 | 3 | CHAT-03 | manual | Enable airplane mode, confirm chat still works | ⬜ pending |
| 04-03-04 | 03 | 3 | CHAT-06 | manual | Scroll during generation — UI must not freeze | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ModelRunnerTests/InferenceServiceTests.swift` — unit test stubs for CHAT-01, CHAT-06
- [ ] `ModelRunnerTests/ChatViewModelTests.swift` — unit test stubs for CHAT-01, CHAT-02, CHAT-06
- [ ] `ModelRunnerTests/PromptFormatterTests.swift` — unit tests for ChatML formatting

*Existing infrastructure (XCTest target) covers the test runner. No new framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tokens stream character-by-character in real time | CHAT-01 | Requires physical device + real GGUF model; simulator lacks Metal | Load Q4_K_M model, send message, observe streaming |
| Tok/s badge shows correct value during generation | CHAT-02 | Requires real inference timing | Check SF Mono badge below assistant bubble |
| Chat works with no network | CHAT-03 | Requires airplane mode toggle | Enable airplane mode after model loaded, send message |
| UI scrollable during generation | CHAT-06 | Requires visual confirmation of 60fps | Drag scroll view during active generation |
| Stop button cancels inference immediately | CHAT-01 | Requires observing partial response behavior | Tap amber stop button mid-stream |
| Model loading progress ring appears | CHAT-01 | Visual feedback for 5-30s load time | Fresh app launch, tap Chat tab, observe loading state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
