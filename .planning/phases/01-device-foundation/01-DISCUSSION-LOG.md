# Phase 1: Device Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-08
**Phase:** 01-device-foundation
**Areas discussed:** Compatibility tiers, Device data source, Context window policy, Model metadata trust

---

## Compatibility Tiers

### How many tiers?

| Option | Description | Selected |
|--------|-------------|----------|
| 3 tiers (Recommended) | Runs Well / Runs Slowly / Won't Run — simple, clear, no ambiguity | ✓ |
| 4 tiers | Optimal / Runs Well / Runs Slowly / Won't Run — finer grain | |
| 2 tiers | Compatible / Incompatible — simplest but loses nuance | |

**User's choice:** 3 tiers
**Notes:** None

### How should tiers appear in the UI?

| Option | Description | Selected |
|--------|-------------|----------|
| Color + text badge | Green 'Runs Well', Yellow 'Runs Slowly', Red 'Won't Run' | |
| Score-based | Numeric score with color gradient | |
| You decide | Claude's discretion | |

**User's choice:** Custom — "Runs well and runs slowly should appear with green and yellow. The ones that won't run at all should just not appear."
**Notes:** Won't Run models are hidden entirely from browse results, not shown with a red badge.

### Cutoff basis between tiers?

| Option | Description | Selected |
|--------|-------------|----------|
| Token speed estimate | Based on expected tokens/sec | |
| RAM headroom | Based on free RAM after model load | |
| Both combined | Composite of speed + RAM headroom | ✓ |

**User's choice:** Both combined
**Notes:** None

### Unknown model metadata?

| Option | Description | Selected |
|--------|-------------|----------|
| Show 'Unknown' tier | Honest, let user decide | |
| Block download | Conservative — can't verify, don't risk it | ✓ |
| Warn and allow | Warning with confirmation step | |

**User's choice:** Block download
**Notes:** None

---

## Device Data Source

### Chip capability source?

| Option | Description | Selected |
|--------|-------------|----------|
| Static lookup table | Bundled table mapping chips to capabilities | ✓ |
| Remote config | Fetch from server | |
| Runtime-only | Detect everything at runtime | |

**User's choice:** Static lookup table
**Notes:** None

### Unknown future chips?

| Option | Description | Selected |
|--------|-------------|----------|
| Graceful fallback (Recommended) | Runtime RAM detection, assume at least as good as most recent known | ✓ |
| Block until update | Show device not supported | |
| User self-report | Ask user to pick device | |

**User's choice:** Graceful fallback
**Notes:** None

### RAM detection approach?

| Option | Description | Selected |
|--------|-------------|----------|
| Per-chip jetsam table | Hardcode known limits per chip | |
| Fixed 40% rule | Flat multiplier on physical RAM | |
| Runtime measurement | os_proc_available_memory() at launch | |

**User's choice:** You decide
**Notes:** Claude has discretion on which approach is most accurate

### Spec refresh timing?

| Option | Description | Selected |
|--------|-------------|----------|
| App launch only | Check once at startup | |
| Launch + before download | Re-check storage before each download | ✓ |
| You decide | Claude's discretion | |

**User's choice:** Launch + before download
**Notes:** None

---

## Context Window Policy

### Context window adjustability?

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed per tier (Recommended) | Engine picks safe size, not adjustable | ✓ |
| User-adjustable with limits | User can increase, capped at safe max | |
| User-adjustable with warnings | Full flexibility, OOM warnings | |

**User's choice:** Fixed per tier
**Notes:** None

### KV cache budgeting?

| Option | Description | Selected |
|--------|-------------|----------|
| Part of RAM budget | Model + KV cache = total, downgrade if exceeds limit | ✓ |
| Separate warning | Show limited context warning separately | |
| You decide | Claude's discretion | |

**User's choice:** Part of RAM budget
**Notes:** None

---

## Model Metadata Trust

### GGUF metadata trust level?

| Option | Description | Selected |
|--------|-------------|----------|
| Trust but verify size | Use metadata, cross-check file size | ✓ |
| Trust fully | Accept as-is | |
| Derive from file size | Ignore metadata, estimate from size | |

**User's choice:** Trust but verify size
**Notes:** None

### Missing metadata fields?

| Option | Description | Selected |
|--------|-------------|----------|
| Estimate from file size | Infer params from size + quant type | ✓ |
| Block (consistent) | Same as earlier — block if can't verify | |
| You decide | Claude's discretion | |

**User's choice:** Estimate from file size
**Notes:** Interesting nuance — user chose to block when size/params are completely undeterminable, but estimate when only some fields are missing.

---

## Claude's Discretion

- RAM detection strategy (per-chip jetsam table vs 40% rule vs runtime measurement)
- Exact token speed estimation formula
- Internal data structures for chip lookup and CompatibilityResult

## Deferred Ideas

None — discussion stayed within phase scope
