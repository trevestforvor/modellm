---
phase: 2
slug: hf-browse-compatibility-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) |
| **Config file** | ModelRunner.xcodeproj |
| **Quick run command** | `xcodebuild test -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ModelRunnerTests/HFAPIServiceTests -only-testing:ModelRunnerTests/QuantizationTypeTests -only-testing:ModelRunnerTests/HFBrowseViewModelTests 2>&1 | tail -20` |
| **Full suite command** | `xcodebuild test -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -40` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (unit tests for affected target)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | HFIN-01 | unit | `xcodebuild test ... -only-testing:ModelRunnerTests/HFAPIServiceTests` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | HFIN-01 | unit | `xcodebuild test ... -only-testing:ModelRunnerTests/QuantizationTypeTests` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | HFIN-02 | unit | `xcodebuild test ... -only-testing:ModelRunnerTests/HFBrowseViewModelTests` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | HFIN-03 | integration | `xcodebuild test ... -only-testing:ModelRunnerTests/HFBrowseViewModelTests/testModelDetailLoad` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 3 | HFIN-04 | unit | `xcodebuild test ... -only-testing:ModelRunnerTests/HFBrowseViewModelTests/testRecommendations` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 3 | HFIN-01,02 | integration | Simulator: search renders cards with badges | manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ModelRunnerTests/HFAPIServiceTests.swift` — stubs for HFIN-01, HFIN-03 (mock URLSession)
- [ ] `ModelRunnerTests/QuantizationTypeTests.swift` — stubs for `QuantizationType.fromFilename` edge cases
- [ ] `ModelRunnerTests/HFBrowseViewModelTests.swift` — stubs for HFIN-02, HFIN-04 (search debounce, recommendations, compatibility sort)
- [ ] Simulator target booted for integration checks

*XCTest is already present via Xcode — no install step needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Compatibility badge colors render correctly (green/yellow) | HFIN-02 | UI color assertion not automatable without snapshot tests | Launch in simulator, search "llama", verify green pill on compatible model |
| Search debounce feels responsive (300ms) | HFIN-01 | Timing perception is subjective | Type rapidly, confirm no per-keystroke flicker |
| "Won't Run" models absent from browse list | HFIN-02 | Requires real device profile + real HF data | Filter by compatibility, verify no red-badge models appear |
| Pagination loads next page on scroll | HFIN-01 | Scroll behavior requires simulator | Scroll to bottom of results, verify more models load |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
