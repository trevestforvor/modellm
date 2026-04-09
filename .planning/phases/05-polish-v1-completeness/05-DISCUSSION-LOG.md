# Phase 5: Polish + V1 Completeness - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 05-Polish + V1 Completeness
**Areas discussed:** Chat history persistence, Inference parameters, V1 rough edges

---

## Chat History Persistence

### Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Simple chronological list | Flat list, newest first | |
| Grouped by model | Conversations under model headers | ✓ |
| You decide | Claude picks | |

**User's choice:** Grouped by model

### Location

| Option | Description | Selected |
|--------|-------------|----------|
| Inside Chat tab | List by default, tap to resume, New Chat button | ✓ |
| Separate History tab | 4th tab | |
| Inside Library per model | History within model cards | |

**User's choice:** Inside Chat tab

### Deletion

| Option | Description | Selected |
|--------|-------------|----------|
| Swipe-to-delete | Standard iOS swipe with confirmation | ✓ |
| No deletion in v1 | Conversations persist forever | |
| Clear all per model | Bulk-only per model group | |

**User's choice:** Swipe-to-delete (recommended)

### Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-title from first message | Truncated first user message | ✓ |
| Timestamp only | Date/time with message preview | |
| Auto-title + editable | Auto-generate but renameable | |

**User's choice:** Auto-title from first message

---

## Inference Parameters

### Control Style

| Option | Description | Selected |
|--------|-------------|----------|
| Friendly sliders with presets | Named presets + expandable Advanced sliders | ✓ |
| Raw sliders only | Temperature/top-p sliders, no presets | |
| Presets only | Named presets, no raw access | |

**User's choice:** Friendly sliders with presets (recommended)

### Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Global default + per-conversation | Global with per-chat override | |
| Global only | One set for all | |
| Per-model | Each model has own parameters | ✓ |

**User's choice:** Per-model
**Notes:** User said "per model is probably preferable" — each model behaves differently so parameters should be tied to the model.

---

## V1 Rough Edges

### Onboarding

| Option | Description | Selected |
|--------|-------------|----------|
| No onboarding | Straight to Browse | |
| Minimal walkthrough | 1-2 screen overlay | |
| Guided first download | Walk user through first model | |

**User's choice:** User's choice to get started or get onboarding
**Notes:** User proposed a welcome screen with two paths: "Get Started" (skip) or "Show Me Around" (guided download). Guided path auto-picks the best model for the device.

### Guided Model Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-pick best model | App selects smallest/fastest Runs Well model | ✓ |
| Choose from 2-3 options | Curated shortlist | |
| You decide | Claude picks | |

**User's choice:** Auto-pick best model

---

## Design Consultation Needed

User requested `/design-consultation` for Phase 5 surfaces before planning:
- Conversation list — glass-style navigation buttons per model group
- Parameter settings view — form layout question (iOS grouped list vs dark card aesthetic)
- Welcome/onboarding screen — MeshGradient or visually distinct

## Claude's Discretion

- Edge case handling (deleted model, storage full)
- SwiftData conversation schema
- List-to-chat transitions
- Parameter ranges and step values
- Guided onboarding copy

## Deferred Ideas

- Manual conversation renaming — post-v1
- Export/share conversations — future
- Model-specific chat themes — future
