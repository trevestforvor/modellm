# Phase 2: HF Browse + Compatibility UI - Context

**Gathered:** 2026-04-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can browse and search Hugging Face GGUF/LLM models and immediately see whether each will run on their device. Recommendations surface the best models upfront. Model detail shows per-variant compatibility. Download functionality is Phase 3 — this phase shows a download button but it's non-functional (or disabled with "Coming soon").

</domain>

<decisions>
## Implementation Decisions

### Browse Layout
- **D-01:** Card-based layout — larger cards with rich detail per model, not compact list rows.
- **D-02:** Compatibility badge is a colored pill with estimated tok/s (e.g. green pill "~25 tok/s" or yellow pill "~8 tok/s"). Not a text label like "Runs Well" — the speed estimate IS the badge.
- **D-03:** Default sort: compatibility-first. "Runs Well" models appear before "Runs Slowly" models.
- **D-04:** Each card shows: model name, file size, parameter count, quantization type, download count, and the tok/s pill badge.
- **D-05:** "Won't Run" models are hidden entirely (carried forward from Phase 1 D-01). Models with indeterminate metadata are also hidden (Phase 1 D-03).

### Search Behavior
- **D-06:** Live search with debounce — results update as user types.
- **D-07:** GGUF filtering is server-side via HF API (filter by library_name or tags).
- **D-08:** Loading states, error states, and no-results states needed.

### Model Detail View
- **D-09:** Navigation pattern: Claude's discretion (sheet vs push).
- **D-10:** Compatibility verdict is inline with other specs, not a hero section.
- **D-11:** Detail shows: model description (from HF card), list of GGUF file variants with per-variant compatibility verdict and tok/s estimate, storage impact ("Uses X GB, you have Y GB free"), and a download button (disabled/placeholder for Phase 3).
- **D-12:** Per-variant compatibility is key — a single HF repo may have Q4_K_M (runs well), Q5_K_S (runs slowly), and Q8_0 (won't run) for the same model. Each variant gets its own badge.

### Recommendations UX
- **D-13:** Recommendations ARE the default landing/home screen. Search takes users to the full catalog.
- **D-14:** Selected by: filter to "Runs Well" tier, sort by HF download count — algorithmic, always fresh.
- **D-15:** Show 4-6 recommended models.

### Claude's Discretion
- Navigation pattern for detail view (sheet vs NavigationStack push)
- Default landing screen layout (how recommendations + search coexist)
- Empty state design for no-results
- Loading skeleton/shimmer patterns
- Error state handling (network failures, API errors)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Foundation
- `.planning/phases/01-device-foundation/01-CONTEXT.md` — D-01 (3 tiers, hidden "Won't Run"), D-03 (indeterminate blocked), D-09 (trust-but-verify metadata)
- `ModelRunner/Services/Device/CompatibilityModels.swift` — Type contracts: CompatibilityTier, CompatibilityResult, ModelMetadata, DeviceSpecs
- `ModelRunner/Services/Device/CompatibilityEngine.swift` — evaluate(model:) returns CompatibilityResult with tier + estimated tok/s
- `ModelRunner/App/AppContainer.swift` — Holds deviceService and compatibilityEngine

### Project & Requirements
- `.planning/PROJECT.md` — Core value, constraints
- `.planning/REQUIREMENTS.md` — HFIN-01 through HFIN-04 acceptance criteria

### Research
- `.planning/research/STACK.md` — swift-huggingface 0.8.0+ for HF API
- `.planning/research/FEATURES.md` — Feature landscape, competitor analysis
- `.planning/research/ARCHITECTURE.md` — HFAPIService component definition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CompatibilityEngine.evaluate(model:)` — takes ModelMetadata, returns CompatibilityResult with tier and estimated tok/s range. Ready to use.
- `AppContainer` — @Observable, holds deviceService and compatibilityEngine. SwiftUI views can access via @Environment or @State.
- `CompatibilityModels.swift` — All types needed: ModelMetadata, CompatibilityTier (.runsWell, .runsSlow, .incompatible), CompatibilityResult.

### Established Patterns
- @Observable for state management (AppContainer)
- Actor pattern for async services (DeviceCapabilityService)
- iOS 17+ target with SwiftUI

### Integration Points
- New HFAPIService will be added to AppContainer
- Browse views consume CompatibilityEngine from container
- ModelMetadata struct needs to be populated from HF API response data

</code_context>

<specifics>
## Specific Ideas

- The tok/s estimate pill badge is the centerpiece of every model card — it communicates both compatibility AND expected performance in one glance
- Recommendations as landing screen means users see curated, compatible models before they even search
- Per-variant compatibility in detail view is a strong differentiator — no competitor shows "Q4_K_M works, Q8_0 doesn't" for the same model
- The browse experience should feel like a curated store, not a raw API dump

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-hf-browse-compatibility-ui*
*Context gathered: 2026-04-08*
