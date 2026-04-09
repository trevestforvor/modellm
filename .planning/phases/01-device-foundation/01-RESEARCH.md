# Phase 1: Device Foundation - Research

**Researched:** 2026-04-08
**Domain:** iOS device capability detection + compatibility verdict engine (pure Swift, no UI)
**Confidence:** HIGH (core APIs verified via Apple docs; jetsam budget figures MEDIUM — hardware-dependent, needs physical device validation)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 3 tiers: "Runs Well" (green), "Runs Slowly" (yellow), "Won't Run" (hidden). Won't Run models are filtered out entirely — users never see them in browse results.
- **D-02:** Cutoffs determined by composite score: expected token speed AND RAM headroom combined. Not just one metric.
- **D-03:** Models with undeterminable size/params are blocked from download entirely — conservative safety.
- **D-04:** Static chip lookup table bundled in the app, mapping chip identifiers to RAM tiers, Neural Engine capability, and expected performance bands. Updated via app releases.
- **D-05:** Unknown chip fallback: use runtime RAM detection and assume "at least as good as" the most recent known chip generation. Never block a new device.
- **D-06:** Device specs checked at app launch (chip, RAM) and re-checked before each download (available storage specifically).
- **D-07:** Context window size is fixed per device tier — engine picks a safe context size based on chip + model combo. Not user-adjustable.
- **D-08:** KV cache memory is part of the total RAM budget: model size + KV cache at the fixed context length = total RAM needed. If total exceeds jetsam limit, tier is downgraded.
- **D-09:** Trust GGUF metadata for param count and quant type, but cross-check file size against expected range for that configuration. Flag mismatches.
- **D-10:** If key metadata fields are missing (e.g., no param count), estimate from file size + quantization type as best effort rather than blocking.

### Claude's Discretion

- RAM detection strategy: whether to use per-chip jetsam table, flat 40% rule, or runtime `os_proc_available_memory()` — Claude picks the most accurate approach based on research
- Exact token speed estimation formula per chip/model combo
- Internal data structures for chip lookup table and CompatibilityResult

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEVC-01 | App dynamically detects device chip family, RAM, and available storage at runtime | `sysctlbyname("hw.machine")` for chip ID; `ProcessInfo.physicalMemory` for RAM; `URL.volumeAvailableCapacityForImportantUsage` for storage |
| DEVC-02 | App computes hard compatibility limits — models that cannot run are blocked from download | CompatibilityEngine returns `.incompatible` when model RAM + KV cache > jetsam budget |
| DEVC-03 | App computes soft compatibility tiers — models that will run slowly display expected performance band | CompatibilityEngine returns `.marginal` when within budget but token speed estimate falls in "Runs Slowly" band |
| DEVC-04 | App shows storage impact before download (e.g. "Uses 4.2 GB, you have 6.1 GB free") | DeviceCapabilityService.availableStorage + model file size from HF siblings array |
| DEVC-05 | Compatibility engine accounts for actual usable RAM (~40% of physical) not total RAM | Hybrid approach: per-chip jetsam table as primary, `os_proc_available_memory()` as runtime floor check |
| DEVC-06 | Compatibility engine factors in KV cache memory for context window sizing | KV cache formula: `2 * n_layers * n_ctx * n_embd * bytes_per_element` — capped per chip tier |
</phase_requirements>

---

## Summary

Phase 1 is a pure-logic layer with no UI. It must produce two services: `DeviceCapabilityService` (detects chip, RAM, storage) and `CompatibilityEngine` (given model metadata + device specs, returns a three-tier verdict). Both are greenfield — no existing code to reuse.

The central research finding is that a **hybrid RAM detection strategy** is most accurate: a static per-chip jetsam table gives consistent pre-download estimates, while `os_proc_available_memory()` provides a real-time floor for actual budgeting. Using only `ProcessInfo.physicalMemory` (total RAM) would over-estimate available budget by roughly 60%, causing models to pass compatibility that then OOM on load. The `increased-memory-limit` entitlement must be added to the `.entitlements` file — without it, jetsam limits are lower than the hardware suggests.

KV cache math is the second critical finding. The compatibility budget is not just model weights — it is weights plus KV cache at the fixed context length for that device tier. A 7B Q4_K_M model is ~4GB of weights, but with n_ctx=2048 on an A15 device the total rises to 5-6GB, exceeding the ~3GB jetsam budget for that chip. The engine must compute total, not just weight size.

**Primary recommendation:** Build `DeviceCapabilityService` first (pure Apple system APIs, no external deps), then `CompatibilityEngine` as a pure function consuming its output. Both are fully testable in isolation with no hardware required.

---

## Standard Stack

### Core (Phase 1 only — no third-party libraries needed)

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| `sysctlbyname("hw.machine")` | system | Chip identifier (e.g. `"iPhone17,2"`) | Only authoritative source for the exact hardware model identifier on iOS |
| `ProcessInfo.processInfo.physicalMemory` | system | Physical RAM in bytes | Foundation API, always available, no entitlement |
| `os_proc_available_memory()` | system (requires `#include <os/proc.h>`) | Runtime available memory floor | Apple-documented API; more accurate than physicalMemory for jetsam budgeting |
| `URL.volumeAvailableCapacityForImportantUsage` | Foundation, iOS 11+ | Available storage the OS will permit for important user data | More accurate than `volumeAvailableCapacity`; accounts for iOS purging caches |
| `ProcessInfo.processInfo.operatingSystemVersion` | system | iOS version gating | Needed for feature-set differences |
| `ProcessInfo.processInfo.thermalState` | system | Thermal state observation | Surface to CompatibilityEngine for soft-warning context |

No third-party libraries are needed for Phase 1. All APIs are system-native.

### Entitlement Required

```xml
<!-- ModelRunner.entitlements -->
<key>com.apple.developer.kernel.increased-memory-limit</key>
<true/>
```

Without this entitlement, jetsam limits on high-RAM devices (iPhone 15 Pro 8GB, iPhone 16 Pro 8GB) are lower than the hardware can provide. This entitlement must be present before compatibility math is validated on physical hardware.

**Note:** The entitlement is self-provisioned for development builds. For App Store submission, Apple requires justification — "on-device LLM inference" is an accepted use case. Do not assume it will be rejected.

---

## Architecture Patterns

### Recommended Project Structure (Phase 1 scope)

```
ModelRunner/
├── App/
│   ├── ModelRunnerApp.swift        # App entry point
│   └── AppContainer.swift          # Instantiates DeviceCapabilityService + CompatibilityEngine
└── Services/
    └── Device/
        ├── DeviceCapabilityService.swift   # Detects chip/RAM/storage; caches snapshot
        ├── ChipLookupTable.swift           # Static table: hw.machine → ChipProfile
        ├── CompatibilityEngine.swift       # Pure function: (ModelMetadata, DeviceSpecs) → CompatibilityResult
        └── CompatibilityModels.swift       # Enums + value types for verdicts
```

### Pattern 1: DeviceCapabilityService as a Cached Snapshot

**What:** Service reads chip, RAM, and OS version once at launch and caches as an immutable `DeviceSpecs` struct. Storage is re-queried on demand (before each download check) because it changes.

**When to use:** Chip and RAM don't change during a session — cache at startup. Storage is dynamic — query on-demand via async property.

```swift
// Source: Apple Developer Docs — ProcessInfo, sysctlbyname, volumeAvailableCapacityForImportantUsage
struct DeviceSpecs {
    let chipIdentifier: String          // e.g. "iPhone17,2"
    let chipProfile: ChipProfile        // looked up from ChipLookupTable
    let physicalRAM: UInt64             // bytes, from ProcessInfo.physicalMemory
    let jetsam Budget: UInt64           // bytes, from chip table (primary) or runtime floor
    let osVersion: OperatingSystemVersion
}

actor DeviceCapabilityService {
    private(set) var specs: DeviceSpecs?

    func initialize() async {
        let machine = machineIdentifier()          // sysctlbyname("hw.machine")
        let physicalRAM = ProcessInfo.processInfo.physicalMemory
        let profile = ChipLookupTable.profile(for: machine)
        let jetsamBudget = profile?.jetsamBudget ?? runtimeJetsamBudget(physicalRAM: physicalRAM)
        specs = DeviceSpecs(chipIdentifier: machine, chipProfile: profile ?? .unknown, ...)
    }

    var availableStorage: UInt64 {
        get async throws {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        }
    }
}
```

### Pattern 2: ChipLookupTable — Static, Bundled, Append-Only

**What:** A Swift enum or dictionary mapping `hw.machine` strings to `ChipProfile` values. Contains RAM tier, Neural Engine generation, expected token speed bands per model class (3B, 7B, 13B), and per-chip jetsam budget.

**When to use:** All compatibility math. Never compute from physicalMemory alone.

**Key data to encode (MEDIUM confidence — needs physical device validation per BLOCKER-01):**

| hw.machine prefix | Device generation | Physical RAM | Jetsam budget (approx, without entitlement) | Jetsam budget (approx, with entitlement) |
|---|---|---|---|---|
| iPhone14,x | iPhone 14 (A15) | 6GB | ~2.5–3GB | ~4–5GB |
| iPhone15,x | iPhone 15 / A16 | 6GB | ~2.5–3GB | ~4–5GB |
| iPhone15,4+ | iPhone 15 Pro (A17 Pro) | 8GB | ~3–4GB | ~6GB |
| iPhone17,x | iPhone 16 / A18 | 8GB | ~3–4GB | ~6–7GB |
| iPhone17,3+ | iPhone 16 Pro (A18 Pro) | 8GB | ~3–4GB | ~6–7GB |

**Note:** Exact jetsam budget values vary per iOS version and are not officially documented. The table above is derived from community testing (MEDIUM confidence). The `os_proc_available_memory()` runtime call serves as the authoritative floor — if it returns less than the table value, use the runtime value.

```swift
// ChipLookupTable.swift
struct ChipProfile {
    let generation: ChipGeneration         // .a15, .a16, .a17Pro, .a18, .a18Pro, .unknown
    let physicalRAMBytes: UInt64
    let jetsamBudgetBytes: UInt64          // with increased-memory-limit entitlement
    let neuralEngine: NEGeneration         // .gen4, .gen5, etc.
    let contextWindowCap: Int              // max safe n_ctx for this tier
    let speedBands: SpeedBands            // token/sec ranges per model class
}
```

### Pattern 3: CompatibilityEngine as a Pure Function

**What:** Takes `(ModelMetadata, DeviceSpecs)` and returns `CompatibilityResult`. No I/O, no async, fully testable.

**When to use:** Called for every model in browse results. Must be O(1) per call.

```swift
// Source: Architecture pattern from .planning/research/ARCHITECTURE.md
enum CompatibilityResult {
    case runsWell(estimatedTokensPerSec: ClosedRange<Float>)
    case runsSlowly(estimatedTokensPerSec: ClosedRange<Float>, warning: String)
    case incompatible(reason: IncompatibilityReason)
}

enum IncompatibilityReason {
    case exceedsRAMBudget(required: UInt64, available: UInt64)
    case indeterminateMetadata
    case exceedsStorage  // checked separately at download time
}

// Pure function — no actor needed
struct CompatibilityEngine {
    let device: DeviceSpecs

    func evaluate(_ model: ModelMetadata) -> CompatibilityResult {
        guard let ramNeeded = totalRAMRequired(model) else {
            return .incompatible(reason: .indeterminateMetadata)  // D-03
        }
        guard ramNeeded <= device.jetsamBudget else {
            return .incompatible(reason: .exceedsRAMBudget(required: ramNeeded, available: device.jetsamBudget))
        }
        let speed = estimatedSpeed(model, device: device)
        return speed.isAcceptable ? .runsWell(estimatedTokensPerSec: speed.range)
                                  : .runsSlowly(estimatedTokensPerSec: speed.range, warning: speed.warningMessage)
    }
}
```

### Pattern 4: RAM Budget Formula (Hybrid Strategy)

**What:** Total RAM required = model weights + KV cache at fixed context length for this chip tier.

```swift
// KV cache formula — verified from llama.cpp internals documentation
// Source: .planning/research/PITFALLS.md (confirmed via llama.cpp discussion #4423)
func kvCacheBytes(nLayers: Int, nCtx: Int, nEmbd: Int, bytesPerElement: Int = 2) -> UInt64 {
    // Each layer needs 2 (K+V) tensors × context length × embedding dim × bytes
    return UInt64(2 * nLayers * nCtx * nEmbd * bytesPerElement)
}

func totalRAMRequired(_ model: ModelMetadata) -> UInt64? {
    guard let weightBytes = model.estimatedWeightBytes,
          let nLayers = model.layerCount,
          let nEmbd = model.embeddingDim else { return nil }
    let nCtx = device.chipProfile.contextWindowCap  // D-07: fixed per device tier
    let kv = kvCacheBytes(nLayers: nLayers, nCtx: nCtx, nEmbd: nEmbd)
    return weightBytes + kv
}
```

**Jetsam budget determination (Claude's discretion — D-05 fallback):**
Use a **three-layer hierarchy**:
1. Per-chip jetsam table (primary) — stable, predictable, encodes hardware knowledge
2. `os_proc_available_memory()` runtime floor — if runtime returns < table value, use runtime (accounts for OS updates changing limits)
3. Flat 40% of physicalMemory — only for unknown chips (D-05 fallback); conservatively safe

```swift
func runtimeJetsamBudget(physicalRAM: UInt64) -> UInt64 {
    // os_proc_available_memory() requires calling at launch before any model allocation
    // Returns current available bytes; treated as floor, not ceiling
    let runtimeAvailable = UInt64(os_proc_available_memory())
    let conservativeFallback = physicalRAM * 4 / 10  // 40% rule for unknown chips
    return min(runtimeAvailable, conservativeFallback)  // most conservative wins
}
```

### Anti-Patterns to Avoid

- **Using `ProcessInfo.physicalMemory` directly for compatibility math:** This is total RAM, not jetsam budget. Will greenlight models that OOM on load. Always use the chip table / runtime floor instead.
- **Computing KV cache once at compile time:** KV cache depends on `n_ctx`, which varies per device tier. Recompute per (model, device) pair.
- **Calling `os_proc_available_memory()` after allocating model weights:** The value reflects what's available at call time. Call it at app launch before any model is loaded to get the baseline.
- **Blocking new/unknown devices (violates D-05):** If `hw.machine` is not in the table, fall back — never return `.incompatible` for unknown chip.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Available storage query | Custom FileManager disk space API | `URL.volumeAvailableCapacityForImportantUsage` | Apple's value accounts for purgeable cache; raw disk space APIs give wrong numbers on low-storage devices |
| Chip identifier | UIDevice.model string parsing | `sysctlbyname("hw.machine")` | UIDevice.model returns "iPhone" — useless. `hw.machine` returns "iPhone17,2" — the actual hardware ID |
| KV cache size estimation | Custom formula from scratch | The formula in Code Examples below | Two sources of truth: llama.cpp internals and Apple memory research; don't deviate |

**Key insight:** All device capability data comes from Apple system APIs. No third-party library is needed, and third-party device detection libraries (e.g., DeviceKit) have consistently stale lookup tables — build and own the chip table directly.

---

## Common Pitfalls

### Pitfall 1: Total RAM vs. Jetsam Budget

**What goes wrong:** `ProcessInfo.physicalMemory` returns 8GB on an iPhone 16 Pro. The compatibility check passes for a 7B Q5 model (~5GB weights). The model loads and immediately triggers jetsam termination because the actual app budget is ~3-4GB without loading additional overhead.

**Why it happens:** Physical RAM feels authoritative. Jetsam limits are undocumented and chip-version specific.

**How to avoid:** Use the chip lookup table for pre-download estimates. Cross-check with `os_proc_available_memory()` at runtime. Add the `increased-memory-limit` entitlement — without it, budgets are lower than the hardware suggests.

**Warning signs:** Compatibility checks pass on newer test devices but user-reported crashes appear on same-spec devices in production.

### Pitfall 2: Ignoring KV Cache in the RAM Budget

**What goes wrong:** A 7B Q4_K_M model is ~4GB of weights. With `n_ctx=2048`, KV cache adds another 1-2GB. On an A15 device with a ~3GB jetsam budget, the model passes the weight-only check but OOMs at the start of inference.

**Why it happens:** Weight size is visible (file size ≈ weight size for GGUF). KV cache is invisible until inference begins.

**How to avoid:** `totalRAMRequired = weights + kv_cache(n_ctx=device.contextWindowCap)`. Include both in every compatibility verdict. D-08 mandates this.

**Warning signs:** App crashes not at model load but at the first inference call, specifically on mid-range devices that passed the compatibility check.

### Pitfall 3: Missing `increased-memory-limit` Entitlement

**What goes wrong:** Models that should pass (e.g., 3B Q4 on iPhone 15 Pro 8GB) fail because the app's jetsam limit is set below the hardware capacity. The entitlement is not automatically granted.

**Why it happens:** Entitlement must be explicitly added to `.entitlements` file. Many developers discover it's missing after shipping.

**How to avoid:** Add `com.apple.developer.kernel.increased-memory-limit = true` in Wave 0 before any hardware testing. Validate jetsam numbers against a device with the entitlement before finalizing the chip table.

**Warning signs:** Physical hardware limits are significantly lower than expected based on device specs. The blocker in STATE.md flags this explicitly.

### Pitfall 4: Misread hw.machine → Chip Mapping

**What goes wrong:** The identifier offset pattern (`iPhone16,x` → A17, `iPhone17,x` → A18) has exceptions. Not all sub-identifiers within an iPhone generation use the same chip or RAM config. Pro and non-Pro variants within the same generation may have different RAM.

**Why it happens:** The pattern is close enough to be dangerous. iPhone 14 (A15) uses iPhone14,x identifiers; iPhone 14 Pro (A15 Pro) uses iPhone15,x — the number offset makes it easy to mis-map.

**How to avoid:** Maintain explicit key-value pairs in the chip table, not a computed offset rule. Use the GitHub gist (adamawolf/3048717) as the authoritative reference for current device codes and cross-check against Apple silicon Wikipedia entries.

**Warning signs:** A device reports itself as a different tier than expected. Always log `hw.machine` in development builds.

---

## Code Examples

### Reading hw.machine via sysctlbyname

```swift
// Source: Apple Developer Docs — https://developer.apple.com/documentation/kernel/1387446-sysctlbyname
import Darwin

func machineIdentifier() -> String {
    var size = 0
    sysctlbyname("hw.machine", nil, &size, nil, 0)
    var machine = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.machine", &machine, &size, nil, 0)
    return String(cString: machine)
}
// Returns: "iPhone17,2" for iPhone 16 Pro
```

### Querying Available Storage

```swift
// Source: Apple Developer Docs — URLResourceValues.volumeAvailableCapacityForImportantUsage
func availableStorageBytes() async throws -> UInt64 {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
        throw DeviceError.storageQueryFailed
    }
    return UInt64(capacity)
}
```

### KV Cache Memory Estimate

```swift
// Source: llama.cpp internals, cross-referenced with .planning/research/PITFALLS.md
// Formula: 2 tensors (K+V) × layers × context_length × embedding_dim × bytes_per_element
func kvCacheBytes(nLayers: Int, nCtx: Int, nEmbd: Int, quantBytesPerElement: Int = 2) -> UInt64 {
    UInt64(2 * nLayers * nCtx * nEmbd * quantBytesPerElement)
}

// Example: Llama 3 8B, Q4_K_M, n_ctx=2048 on A15 device tier
// nLayers=32, nEmbd=4096, n_ctx=2048, 2 bytes/element (fp16 KV)
// = 2 × 32 × 2048 × 4096 × 2 = 1,073,741,824 bytes ≈ 1GB
// Total RAM needed: ~4.3GB weights + ~1GB KV = ~5.3GB → exceeds A15 budget → .incompatible
```

### Compatibility Verdict (Simplified)

```swift
// Source: Architecture pattern established in .planning/research/ARCHITECTURE.md
func storageImpactDescription(modelBytes: UInt64, available: UInt64) -> String {
    let modelGB = Double(modelBytes) / 1_073_741_824
    let availableGB = Double(available) / 1_073_741_824
    return String(format: "Uses %.1f GB, you have %.1f GB free", modelGB, availableGB)
    // → "Uses 4.2 GB, you have 6.1 GB free" (DEVC-04)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `sysctlbyname("hw.memsize")` for RAM | Per-chip jetsam table + `os_proc_available_memory()` | iOS 15 (2021) — entitlement added | Without this: compatibility math overestimates budget by ~60% |
| Flat memory check (weights only) | Weights + KV cache at fixed n_ctx | llama.cpp community learnings 2024 | KV cache OOM is the #1 cause of "compatible model crashes at inference" |
| User-adjustable context window | Fixed context per device tier | Decision D-07 | Eliminates a whole class of OOM bugs from user misconfiguration |

---

## Environment Availability

Phase 1 is pure Swift logic — no external services, CLIs, or databases required.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Xcode 16+ | Build | ✓ (assumed) | Standard iOS development environment |
| Physical iOS device | Jetsam validation | Flag | Simulator does not enforce jetsam limits — all compatibility math must be validated on physical hardware before finalizing the chip table |

**Blocker note (from STATE.md):** Jetsam limit per chip generation needs validation on physical hardware before the compatibility ruleset is finalized. The chip table values are MEDIUM confidence until validated. The plan must include a physical device test task.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 16 built-in) or XCTest |
| Config file | None — use default Xcode test target |
| Quick run command | `xcodebuild test -scheme ModelRunnerTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |
| Full suite command | Same — Phase 1 has no network or disk tests, all logic is pure |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEVC-01 | DeviceCapabilityService reads chip, RAM, storage correctly | unit (mocked sysctlbyname) | `xcodebuild test -only-testing:ModelRunnerTests/DeviceCapabilityServiceTests` | ❌ Wave 0 |
| DEVC-02 | CompatibilityEngine returns .incompatible when model RAM > jetsam budget | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testHardBlock` | ❌ Wave 0 |
| DEVC-03 | CompatibilityEngine returns .runsSlow for in-budget but slow models | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testSoftWarn` | ❌ Wave 0 |
| DEVC-04 | storageImpactDescription formats "Uses X GB, you have Y GB free" correctly | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testStorageDescription` | ❌ Wave 0 |
| DEVC-05 | Jetsam budget is ~40% of physicalMemory for unknown chips, never 100% | unit | `xcodebuild test -only-testing:ModelRunnerTests/ChipLookupTableTests/testUnknownChipFallback` | ❌ Wave 0 |
| DEVC-06 | KV cache bytes included in total RAM required calculation | unit | `xcodebuild test -only-testing:ModelRunnerTests/CompatibilityEngineTests/testKVCacheIncluded` | ❌ Wave 0 |

**Physical device test (manual, not automated):**
- DEVC-02 verdict accuracy requires loading actual models on physical hardware to validate that `.incompatible` verdicts correlate with actual OOM behavior. This is a manual gate — plan must include it.

### Wave 0 Gaps

- [ ] `ModelRunnerTests/DeviceCapabilityServiceTests.swift` — covers DEVC-01
- [ ] `ModelRunnerTests/CompatibilityEngineTests.swift` — covers DEVC-02, DEVC-03, DEVC-04, DEVC-06
- [ ] `ModelRunnerTests/ChipLookupTableTests.swift` — covers DEVC-05
- [ ] Test target must be added to Xcode project (greenfield — no test target exists yet)
- [ ] `DeviceSpecs` must be constructable with test fixtures (not just from live system APIs)

---

## Open Questions

1. **Exact jetsam limits per chip generation with `increased-memory-limit` entitlement**
   - What we know: Without entitlement, ~40-50% of physical RAM. With entitlement, higher — but exact values undocumented.
   - What's unclear: Does iOS 18 change limits vs iOS 17? Do limits differ between iPhone 16 and 16 Pro on same chip?
   - Recommendation: Initialize the table with conservative values, then validate on physical hardware in the final task of this phase. Do not finalize the table until hardware testing is complete.

2. **`os_proc_available_memory()` Swift bridging**
   - What we know: This is a C function requiring `#include <os/proc.h>`. Apple documents it at https://developer.apple.com/documentation/os/3191911-os_proc_available_memory
   - What's unclear: Whether a bridging header is needed in a pure Swift package or if it's auto-imported.
   - Recommendation: Add a minimal Objective-C bridging header if needed; test in Wave 0.

3. **Context window cap per chip tier**
   - What we know: Q4 on A15, 2048 is the safe ceiling from community testing. 512-1024 is safer for older phones.
   - What's unclear: Whether `n_ctx=2048` vs `n_ctx=1024` materially affects model usefulness for the target user.
   - Recommendation: Start with 1024 for A15/A16, 2048 for A17+, 4096 for A18 Pro. Document as "configurable in ChipLookupTable" so it can be tuned without engine changes.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Docs — `sysctlbyname` — https://developer.apple.com/documentation/kernel/1387446-sysctlbyname
- Apple Developer Docs — `os_proc_available_memory` — https://developer.apple.com/documentation/os/3191911-os_proc_available_memory
- Apple Developer Docs — `volumeAvailableCapacityForImportantUsage` — URLResourceValues
- Apple Developer Docs — `increased-memory-limit` entitlement — https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit
- Apple Developer Docs — Jetsam event reports — https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports
- llama.cpp iOS discussion — https://github.com/ggml-org/llama.cpp/discussions/4423
- Project pre-research: `.planning/research/STACK.md`, `.planning/research/PITFALLS.md`, `.planning/research/ARCHITECTURE.md`

### Secondary (MEDIUM confidence)
- adamawolf/3048717 GitHub Gist — hw.machine → device name mapping (community-maintained, widely referenced)
- Apple Developer Forums — increased-memory-limit thread — https://developer.apple.com/forums/thread/777370
- PojavLauncher iOS memory limits issue — https://github.com/PojavLauncherTeam/PojavLauncher_iOS/issues/97 — community jetsam limit documentation

### Tertiary (LOW confidence — needs physical device validation)
- Community jetsam budget estimates per chip tier (40% rule, exact numbers unverified by Apple)
- Token speed estimates per chip/model combination

---

## Metadata

**Confidence breakdown:**
- Standard stack (APIs): HIGH — all Apple system APIs, well-documented
- Chip table data: MEDIUM — community-sourced, pending physical device validation
- KV cache formula: HIGH — derived from llama.cpp internals, cross-referenced with multiple sources
- Token speed bands: LOW — highly hardware-dependent, requires physical device benchmarking

**Research date:** 2026-04-08
**Valid until:** 2026-10-08 (6 months — chip table needs updating on each new iPhone release)
