---
phase: 01-device-foundation
plan: 03
subsystem: Device
tags: [compatibility-engine, kv-cache, ram-budget, tdd]
dependency_graph:
  requires: [01-01, 01-02]
  provides: [CompatibilityEngine]
  affects: [Phase 02 browse UI compatibility badge rendering]
tech_stack:
  added: []
  patterns: [Pure struct O(1) evaluate(), composite scoring (speed + RAM headroom), TDD red/green]
key_files:
  created:
    - ModelRunner/Services/Device/CompatibilityEngine.swift
  modified:
    - ModelRunnerTests/CompatibilityEngineTests.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - "RAM headroom < 15% triggers runsSlowly (not incompatible) — conservative but lets model run"
  - "isSlow threshold: upper bound of speed range < 5 tok/sec"
  - "KV cache omitted from budget when layerCount or embeddingDim is nil — best-effort with weight bytes alone"
metrics:
  duration: ~18 minutes
  completed: 2026-04-09
  tasks_completed: 1
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 01 Plan 03: CompatibilityEngine Summary

**One-liner:** Pure function compatibility evaluator with KV cache math, composite score soft-tier, and indeterminate metadata guard.

## What Was Built

`CompatibilityEngine.swift` — pure struct with no I/O, no async, O(1) evaluate():

- `evaluate(_ model: ModelMetadata) -> CompatibilityResult` — three-tier verdict (runsWell / runsSlowly / incompatible)
- `kvCacheBytes(nLayers:nCtx:nEmbd:bytesPerElement:)` — formula: `2 × nLayers × nCtx × nEmbd × bytesPerElement`
- `totalRAMRequired(_ model:)` — weights + KV cache at device's fixed `contextWindowCap`
- `storageImpactDescription(modelBytes:availableBytes:)` — "Uses X.X GB, you have Y.Y GB free"

Key correctness decisions:
- Compares against `device.jetsamBudget`, never `device.physicalRAM` (DEVC-02 anti-pattern guard)
- Uses `device.chipProfile.contextWindowCap` as fixed n_ctx (D-07)
- D-03: nil fileSizeBytes + nil parameterCount → `.incompatible(.indeterminateMetadata)`
- D-10: nil fileSizeBytes + known paramCount → `paramCount × quantType.bytesPerWeight` estimate

All 11 `CompatibilityEngineTests` pass green on iOS Simulator (iPhone 16 Pro).

## Test Coverage

| Test | Requirement | Result |
|------|-------------|--------|
| testHardBlock | DEVC-02 | PASS |
| testRunsWellOnHighEndDevice | DEVC-02 | PASS |
| testSoftWarn | DEVC-03 | PASS |
| testSoftWarnHasMessage | DEVC-03 | PASS |
| testStorageDescription | DEVC-04 | PASS |
| testStorageDescriptionSmallModel | DEVC-04 | PASS |
| testKVCacheIncluded | DEVC-06 | PASS |
| testKVCacheScalesWithContext | DEVC-06 | PASS |
| testKVCacheInRAMBudget | DEVC-06 | PASS |
| testIndeterminateMetadataIsBlocked | D-03 | PASS |
| testBestEffortEstimation | D-10 | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing Foundation import in CompatibilityEngineTests.swift**
- **Found during:** Task 1 GREEN phase — build error
- **Issue:** `OperatingSystemVersion` not in scope in test file (DeviceSpecs uses it in fixture construction)
- **Fix:** Added `import Foundation` to test file
- **Files modified:** ModelRunnerTests/CompatibilityEngineTests.swift
- **Commit:** 5586058

## Pending Checkpoint

**Task 2** (checkpoint:human-verify) was not executed — requires physical device with real hardware.

See checkpoint details below. Plan is blocked at Task 2 pending physical device validation.

## Known Stubs

None — all test stubs from the Wave 0 phase replaced with real test implementations.

## Self-Check: PASSED

- [x] `ModelRunner/Services/Device/CompatibilityEngine.swift` exists
- [x] `grep "kvCacheBytes" ModelRunner/Services/Device/CompatibilityEngine.swift` — found
- [x] `grep "totalRAMRequired" ModelRunner/Services/Device/CompatibilityEngine.swift` — found
- [x] `grep "device.jetsamBudget" ModelRunner/Services/Device/CompatibilityEngine.swift` — found
- [x] `grep "physicalRAM" ModelRunner/Services/Device/CompatibilityEngine.swift` — not in evaluate() decision path (only in comment)
- [x] `grep "device.chipProfile.contextWindowCap" ModelRunner/Services/Device/CompatibilityEngine.swift` — found
- [x] `grep "storageImpactDescription" ModelRunner/Services/Device/CompatibilityEngine.swift` — found
- [x] Commit 5586058 exists
- [x] All 11 CompatibilityEngineTests pass green (** TEST SUCCEEDED **)
