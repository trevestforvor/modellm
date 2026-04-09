# Phase 1: Device Foundation - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Detect device specs (chip, RAM, storage) and compute compatibility verdicts for any given model metadata. Pure logic layer — no UI in this phase. The CompatibilityEngine must return correct hard/soft verdicts before any browse or download UI exists.

</domain>

<decisions>
## Implementation Decisions

### Compatibility Tiers
- **D-01:** 3 tiers: "Runs Well" (green), "Runs Slowly" (yellow), "Won't Run" (hidden). Won't Run models are filtered out entirely — users never see them in browse results.
- **D-02:** Cutoffs determined by composite score: expected token speed AND RAM headroom combined. Not just one metric.
- **D-03:** Models with undeterminable size/params are blocked from download entirely — conservative safety.

### Device Data Source
- **D-04:** Static chip lookup table bundled in the app, mapping chip identifiers to RAM tiers, Neural Engine capability, and expected performance bands. Updated via app releases.
- **D-05:** Unknown chip fallback: use runtime RAM detection and assume "at least as good as" the most recent known chip generation. Never block a new device.
- **D-06:** Device specs checked at app launch (chip, RAM) and re-checked before each download (available storage specifically).

### Context Window Policy
- **D-07:** Context window size is fixed per device tier — engine picks a safe context size based on chip + model combo. Not user-adjustable.
- **D-08:** KV cache memory is part of the total RAM budget: model size + KV cache at the fixed context length = total RAM needed. If total exceeds jetsam limit, tier is downgraded.

### Model Metadata Trust
- **D-09:** Trust GGUF metadata for param count and quant type, but cross-check file size against expected range for that configuration. Flag mismatches.
- **D-10:** If key metadata fields are missing (e.g., no param count), estimate from file size + quantization type as best effort rather than blocking.

### Claude's Discretion
- RAM detection strategy: whether to use per-chip jetsam table, flat 40% rule, or runtime `os_proc_available_memory()` — Claude picks the most accurate approach based on research
- Exact token speed estimation formula per chip/model combo
- Internal data structures for chip lookup table and CompatibilityResult

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs — requirements fully captured in decisions above and in:

### Project & Requirements
- `.planning/PROJECT.md` — Core value (compatibility verification), constraints, key decisions
- `.planning/REQUIREMENTS.md` — DEVC-01 through DEVC-06 acceptance criteria

### Research
- `.planning/research/STACK.md` — llama.cpp XCFramework integration path, swift-huggingface, device detection APIs
- `.planning/research/PITFALLS.md` — RAM detection trap (~40% usable), KV cache OOM, Metal background thread crash
- `.planning/research/ARCHITECTURE.md` — DeviceCapabilityService and CompatibilityEngine component definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None — this phase establishes the foundational patterns

### Integration Points
- CompatibilityEngine will be consumed by Phase 2 (HF Browse UI) to annotate model listings
- DeviceCapabilityService will be consumed by Phase 3 (Download) for storage-aware warnings

</code_context>

<specifics>
## Specific Ideas

- "Won't Run" models should be invisible, not shown with a red badge — cleaner UX where users only see what they can actually use
- The compatibility engine is the app's moat — no competitor does pre-download compatibility checking
- Research flagged that iPhone 16 Pro loses 44% throughput after sustained inference due to thermal throttling — may affect "Runs Well" vs "Runs Slowly" in practice

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-device-foundation*
*Context gathered: 2026-04-08*
