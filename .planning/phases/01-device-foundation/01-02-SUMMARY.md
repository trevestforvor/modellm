---
phase: 01-device-foundation
plan: 02
subsystem: device-detection
tags: [chip-detection, jetsam, sysctlbyname, os_proc_available_memory, storage, actor, tdd]
dependency_graph:
  requires: [01-01]
  provides: [DeviceCapabilityService, ChipLookupTable, DeviceSpecs]
  affects: [01-03-CompatibilityEngine]
tech_stack:
  added: []
  patterns:
    - Swift actor for thread-safe device spec caching
    - TDD: stub → test → implementation → all green
    - Three-layer jetsam budget (table → runtime floor → 40% fallback)
    - Explicit hw.machine → ChipProfile key-value table (no computed offset rules)
key_files:
  created:
    - ModelRunner/Services/Device/ChipLookupTable.swift
    - ModelRunner/Services/Device/DeviceCapabilityService.swift
  modified:
    - ModelRunner/App/AppContainer.swift
    - ModelRunnerTests/ChipLookupTableTests.swift
    - ModelRunnerTests/DeviceCapabilityServiceTests.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - "iPhone 15 non-Pro (hw.machine iPhone15,4) maps to A16, not A17Pro — verified against adamawolf gist"
  - "os_proc_available_memory available via Darwin umbrella import — no bridging header needed"
  - "DeviceCapabilityServiceTests.testJetsamBudgetSmallerThanPhysicalRAM uses Issue.record for nil guard (not throw) — consistent with Swift Testing pattern for actors"
metrics:
  duration: ~15 minutes
  completed: 2026-04-08
  tasks_completed: 2
  files_changed: 6
requirements:
  - DEVC-01
  - DEVC-05
---

# Phase 01 Plan 02: ChipLookupTable + DeviceCapabilityService Summary

**One-liner:** Chip lookup table (A15–A18Pro hw.machine mapping) and DeviceCapabilityService actor with three-layer jetsam budget via sysctlbyname + os_proc_available_memory + 40% fallback.

## What Was Built

### ChipLookupTable (Task 1)

Static lookup table mapping `hw.machine` strings to `ChipProfile` values for all iPhones from iPhone 13 (A15) through iPhone 16 Pro Max (A18Pro). Key design decisions:

- Explicit key-value pairs per iPhone SKU — no computed offset rules (Pitfall 4 from RESEARCH.md)
- Returns `nil` for unknown identifiers — fallback logic lives in `DeviceCapabilityService`, not here
- A15/A16: `contextWindowCap=1024`, `jetsamBudgetBytes=5GB`
- A17Pro/A18: `contextWindowCap=2048`, `jetsamBudgetBytes=6GB`
- A18Pro: `contextWindowCap=4096`, `jetsamBudgetBytes=7GB`

### DeviceCapabilityService (Task 2)

Swift actor that reads device hardware at launch and caches as `DeviceSpecs`. Three-layer jetsam budget:

1. Chip table value (primary — encodes hardware knowledge)
2. `os_proc_available_memory()` as runtime floor via `Darwin` import (no bridging header needed)
3. `physicalRAM * 4 / 10` (40% rule) for unknown chips per D-05

Storage queried on-demand via `volumeAvailableCapacityForImportantUsageKey` to reflect real-time changes.

### AppContainer (updated)

Instantiates `DeviceCapabilityService` and calls `initialize()` via `Task {}` at app launch.

## Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| ChipLookupTableTests | 10 | All passed |
| DeviceCapabilityServiceTests | 7 | All passed |

No `Issue.record` stubs remain in either test file.

## Deviations from Plan

None — plan executed exactly as written. `os_proc_available_memory` was available via `import Darwin` as anticipated in the plan's "try pure Swift first" note, so no bridging header was needed.

## Known Stubs

None. All data flows are wired: `ChipLookupTable.profile(for:)` → `DeviceCapabilityService.initialize()` → `DeviceSpecs` → ready for `CompatibilityEngine` (Plan 03).
