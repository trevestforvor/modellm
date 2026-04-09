---
phase: 1
slug: device-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-08
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (Xcode 16+) / XCTest |
| **Config file** | None — use default Xcode test target |
| **Quick run command** | `xcodebuild test -scheme ModelRunnerTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |
| **Full suite command** | Same — Phase 1 is pure logic, no network or disk tests |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme ModelRunnerTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- **After every plan wave:** Run full suite (same command)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | DEVC-01 | unit | `xcodebuild test -only-testing:ModelRunnerTests/DeviceCapabilityServiceTests` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | DEVC-02 | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testHardBlock` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | DEVC-03 | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testSoftWarn` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | DEVC-04 | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testStorageDescription` | ❌ W0 | ⬜ pending |
| 01-02-04 | 02 | 1 | DEVC-05 | unit | `xcodebuild test -only-testing:ModelRunnerTests/ChipLookupTableTests/testUnknownChipFallback` | ❌ W0 | ⬜ pending |
| 01-02-05 | 02 | 1 | DEVC-06 | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testKVCacheIncluded` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ModelRunnerTests/DeviceCapabilityServiceTests.swift` — stubs for DEVC-01
- [ ] `ModelRunnerTests/CompatibilityEngineTests.swift` — stubs for DEVC-02, DEVC-03, DEVC-04, DEVC-06
- [ ] `ModelRunnerTests/ChipLookupTableTests.swift` — stubs for DEVC-05
- [ ] Xcode test target `ModelRunnerTests` — greenfield, must be created

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Jetsam budget accuracy on physical hardware | DEVC-02 | Jetsam limits vary per device and entitlement; simulator doesn't enforce real limits | Load a model near the jetsam boundary on physical iPhone with `increased-memory-limit` entitlement and verify OOM vs success matches engine verdict |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
