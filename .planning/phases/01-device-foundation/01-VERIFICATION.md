---
phase: 01-device-foundation
verified: 2026-04-08T00:00:00Z
status: gaps_found
score: 10/11 must-haves verified
gaps:
  - truth: "AppContainer instantiates DeviceCapabilityService and CompatibilityEngine"
    status: failed
    reason: "AppContainer holds DeviceCapabilityService and calls initialize() correctly, but CompatibilityEngine is never instantiated in AppContainer. Plan 01-01 must_haves explicitly require AppContainer to instantiate both services. The 01-01-PLAN key_links spec states 'instantiates DeviceCapabilityService + CompatibilityEngine' but only the former was wired."
    artifacts:
      - path: "ModelRunner/App/AppContainer.swift"
        issue: "CompatibilityEngine property is absent — only DeviceCapabilityService is declared"
    missing:
      - "Add CompatibilityEngine property to AppContainer, initialized after deviceService.initialize() completes and DeviceSpecs is available"
human_verification:
  - test: "Run xcodebuild test on both ChipLookupTableTests and DeviceCapabilityServiceTests on a physical device (not simulator)"
    expected: "All tests pass; jetsam budget values from os_proc_available_memory() are lower than the chip-table values, confirming the runtime floor is exercised"
    why_human: "os_proc_available_memory() returns simulator process memory, not iOS jetsam limits — only physical hardware validates the three-layer budget hierarchy"
  - test: "Launch app on iPhone 16 Pro and instrument with Xcode Memory Report immediately after launch"
    expected: "App memory footprint < 50MB before any model is loaded; no crashes or warnings about memory pressure"
    why_human: "Cannot test live memory pressure or jetsam ceiling from code inspection alone"
---

# Phase 01: Device Foundation Verification Report

**Phase Goal:** The app correctly knows what the device can run before showing any models
**Verified:** 2026-04-08
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Xcode project builds cleanly for iOS 17+ without warnings | ? UNCERTAIN | Project exists with valid pbxproj; build not run here — human spot-check or CI needed |
| 2 | Test target ModelRunnerTests exists and all stub tests compile and pass | ✓ VERIFIED | 01-02-SUMMARY: 10 ChipLookupTableTests passed, 7 DeviceCapabilityServiceTests passed; 01-03-SUMMARY: 11 CompatibilityEngineTests passed |
| 3 | increased-memory-limit entitlement is present in ModelRunner.entitlements | ✓ VERIFIED | File read directly — `com.apple.developer.kernel.increased-memory-limit` key with `<true/>` value confirmed |
| 4 | All core types (DeviceSpecs, ChipProfile, CompatibilityResult, ModelMetadata) are defined and exported | ✓ VERIFIED | CompatibilityModels.swift read — all 9 types present with public access control, correct Sendable/Hashable conformances |
| 5 | AppContainer instantiates DeviceCapabilityService and CompatibilityEngine | ✗ FAILED | AppContainer.swift contains only DeviceCapabilityService; CompatibilityEngine is absent |
| 6 | DeviceCapabilityService.initialize() reads chip identifier via sysctlbyname and stores in DeviceSpecs | ✓ VERIFIED | DeviceCapabilityService.swift uses sysctlbyname("hw.machine"), ProcessInfo.physicalMemory, os_proc_available_memory |
| 7 | ChipLookupTable maps known hw.machine strings to correct ChipProfile with jetsam budgets | ✓ VERIFIED | ChipLookupTable.swift contains explicit key-value pairs for iPhone14,x through iPhone17,x; A15/A16=5GB, A17Pro/A18=6GB, A18Pro=7GB jetsam |
| 8 | Unknown chip identifier falls back to 40% of physicalRAM as jetsam budget | ✓ VERIFIED | DeviceCapabilityService.swift: `physicalRAM * 4 / 10` in computeJetsamBudget; nil return from ChipLookupTable triggers this path |
| 9 | CompatibilityEngine.evaluate() returns .incompatible when weights + KV cache exceed jetsam budget | ✓ VERIFIED | CompatibilityEngine.swift: guards `ramNeeded <= device.jetsamBudget`, returns `.incompatible(.exceedsRAMBudget)`; testHardBlock passes |
| 10 | CompatibilityEngine.evaluate() returns .incompatible(.indeterminateMetadata) when fileSizeBytes and parameterCount are both nil | ✓ VERIFIED | totalRAMRequired returns nil when both sources are nil; evaluate() maps nil → `.incompatible(.indeterminateMetadata)`; testIndeterminateMetadataIsBlocked passes |
| 11 | KV cache bytes are included in total RAM required (DEVC-06) | ✓ VERIFIED | kvCacheBytes formula `2 * nLayers * nCtx * nEmbd * bytesPerElement`; totalRAMRequired adds kv to weightBytes when layerCount and embeddingDim are available |

**Score:** 10/11 truths verified (1 failed, 1 uncertain pending build)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ModelRunner/ModelRunner.entitlements` | increased-memory-limit entitlement | ✓ VERIFIED | File read; key and true value confirmed |
| `ModelRunner/Services/Device/CompatibilityModels.swift` | All 9 core type definitions | ✓ VERIFIED | File read; ChipGeneration, NEGeneration, SpeedBands, ChipProfile, DeviceSpecs, QuantizationType, ModelMetadata, CompatibilityResult, IncompatibilityReason, CompatibilityTier all present |
| `ModelRunner/Services/Device/ChipLookupTable.swift` | hw.machine → ChipProfile static table | ✓ VERIFIED | File read; iPhone14,x through iPhone17,x entries, profile(for:) returns nil for unknown |
| `ModelRunner/Services/Device/DeviceCapabilityService.swift` | Actor reading chip/RAM/storage | ✓ VERIFIED | File read; sysctlbyname, os_proc_available_memory, volumeAvailableCapacityForImportantUsageKey all present |
| `ModelRunner/Services/Device/CompatibilityEngine.swift` | Pure evaluator with KV cache math | ✓ VERIFIED | File read; evaluate(), kvCacheBytes(), totalRAMRequired(), storageImpactDescription() all present |
| `ModelRunner/App/AppContainer.swift` | Instantiates both services | ✗ PARTIAL | DeviceCapabilityService wired; CompatibilityEngine absent |
| `ModelRunnerTests/CompatibilityEngineTests.swift` | Real tests for DEVC-02/03/04/06 | ✓ VERIFIED | 11 real tests — no Issue.record stub markers; Issue.record used only as non-fatal assertion reporters inside guard branches |
| `ModelRunnerTests/DeviceCapabilityServiceTests.swift` | Real tests for DEVC-01 | ✓ VERIFIED | 7 real tests; one Issue.record inside a nil-guard — legitimate Swift Testing pattern |
| `ModelRunnerTests/ChipLookupTableTests.swift` | Real tests for DEVC-05 | ✓ VERIFIED | 10 real tests; no Issue.record stubs |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| AppContainer.swift | DeviceCapabilityService.swift | instantiates + calls initialize() | ✓ WIRED | `let deviceService = DeviceCapabilityService()` and `Task { await deviceService.initialize() }` confirmed |
| AppContainer.swift | CompatibilityEngine.swift | instantiates with DeviceSpecs | ✗ NOT WIRED | No CompatibilityEngine declaration in AppContainer |
| DeviceCapabilityService.swift | ChipLookupTable.swift | ChipLookupTable.profile(for:) in initialize() | ✓ WIRED | `ChipLookupTable.profile(for: machineID)` call confirmed in DeviceCapabilityService |
| CompatibilityEngine.swift | CompatibilityModels.swift | evaluate() uses DeviceSpecs.jetsamBudget + chipProfile.contextWindowCap | ✓ WIRED | `device.jetsamBudget` and `device.chipProfile.contextWindowCap` both found in engine |
| CompatibilityEngineTests.swift | CompatibilityModels.swift | test fixtures use DeviceSpecs() and ModelMetadata() constructors | ✓ WIRED | Fixtures confirmed in test file reading |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| DeviceCapabilityService | specs: DeviceSpecs? | sysctlbyname + ProcessInfo + ChipLookupTable | Yes — real system calls | ✓ FLOWING |
| CompatibilityEngine | CompatibilityResult | DeviceSpecs.jetsamBudget + ModelMetadata | Yes — deterministic math, no stubs | ✓ FLOWING |
| AppContainer | deviceService.specs | DeviceCapabilityService.initialize() | Yes — Task fires at init | ✓ FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — services are Swift actors/structs with no CLI entry point; tests require Xcode simulator to run. Build and test invocations confirmed in SUMMARY files.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| DEVC-01 | 01-02 | Detect chip family, RAM, storage at runtime | ✓ SATISFIED | DeviceCapabilityService reads all three; 7 passing tests confirm |
| DEVC-02 | 01-03 | Hard block — models that cannot run are blocked | ✓ SATISFIED | CompatibilityEngine compares weights+KV vs jetsamBudget; testHardBlock passes |
| DEVC-03 | 01-03 | Soft tier — slow models show warning with perf band | ✓ SATISFIED | Composite score (speed + RAM headroom); testSoftWarn and testSoftWarnHasMessage pass |
| DEVC-04 | 01-03 | Storage impact description before download | ✓ SATISFIED | storageImpactDescription returns "Uses X.X GB, you have Y.Y GB free" format |
| DEVC-05 | 01-02 | Use actual usable RAM (~40% fallback), not total | ✓ SATISFIED | Three-layer jetsam: chip table → os_proc_available_memory floor → 40% fallback for unknown chips |
| DEVC-06 | 01-03 | Factor in KV cache memory for context window | ✓ SATISFIED | kvCacheBytes formula included in totalRAMRequired when layerCount and embeddingDim available |

All 6 phase requirements satisfied at the implementation level. REQUIREMENTS.md traceability table correctly marks all DEVC-01 through DEVC-06 as Complete for Phase 1. No orphaned requirements.

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| AppContainer.swift | CompatibilityEngine missing from container | ✗ BLOCKER | Phase 2 browse UI cannot call evaluate() without a CompatibilityEngine instance from the container; it will need to construct one ad-hoc or the container must provide it |

No TODO/FIXME/placeholder comments found in service files. No `return []` or `return {}` stubs. All `Issue.record` calls in test files are legitimate non-fatal assertion reporters inside `guard case` branches — not Wave 0 stub markers.

### Human Verification Required

#### 1. Physical Device Jetsam Budget Validation

**Test:** Install app on a physical iPhone 16 Pro. After launch, print `deviceService.specs?.jetsamBudget` to console and compare against the table value (7GB for A18Pro). Confirm `os_proc_available_memory()` returns a value at or below the table value, and the min() in computeJetsamBudget selects the runtime floor rather than the table value.
**Expected:** Budget reported in logs is 6–7GB range; no crash; value is min(tableValue, runtimeAvailable)
**Why human:** Simulator returns Mac process memory for os_proc_available_memory, not iOS jetsam limits

#### 2. Build Cleanliness

**Test:** Run `xcodebuild build -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` and check for warnings (not just errors)
**Expected:** BUILD SUCCEEDED with 0 warnings
**Why human:** Build was not run during verification; SUMMARY reports success but warnings may be present

### Gaps Summary

One gap blocking full goal achievement:

**CompatibilityEngine not wired into AppContainer.** All three service files exist and are implemented correctly, but AppContainer only holds `DeviceCapabilityService`. The 01-01-PLAN must_haves explicitly state AppContainer must instantiate both services. The key link `AppContainer → CompatibilityEngine` is not wired.

This does not block the phase's computational correctness — the engine works as a standalone pure struct — but it means Phase 2 (browse UI) cannot retrieve a pre-configured CompatibilityEngine from the container. Phase 2 will either need to construct the engine inline (coupling it to DeviceSpecs retrieval) or this gap must be closed first.

The fix is small: add a computed or stored property to AppContainer that creates a CompatibilityEngine from `deviceService.specs` once initialized.

---

_Verified: 2026-04-08_
_Verifier: Claude (gsd-verifier)_
