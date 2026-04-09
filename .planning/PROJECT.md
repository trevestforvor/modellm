# ModelRunner

## What This Is

An iOS app that lets users browse Hugging Face models, verify compatibility with their specific device, download compatible models, and run inference locally on-device. Think LM Studio for iPhone — the key differentiator is intelligent device-aware filtering so users never download a model that won't work (or will barely work) on their hardware.

## Core Value

Device-aware model compatibility verification — users see at a glance what will run well, what will run slowly, and what won't run at all on their specific device, before downloading anything.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ Dynamic device spec detection (chip, RAM, available storage, OS version) — Phase 1
- ✓ Hard compatibility limits — filter out models that cannot run on the device (insufficient RAM, storage, unsupported format) — Phase 1
- ✓ Soft compatibility signals — warn about models that will run but perform poorly (slow token generation, high memory pressure) — Phase 1

### Active

<!-- Current scope. Building toward these. -->

- [ ] Browse and search Hugging Face model repository
- [ ] Download models with progress tracking and storage management
- [ ] LLM inference via llama.cpp Swift bindings
- [ ] Chat UI for interacting with loaded LLM models
- [ ] Model library — manage downloaded models (view, delete, switch)

### Out of Scope

- Speech-to-text models — future v2+ once core LLM pipeline is solid
- Image generation models — future v2+ once core LLM pipeline is solid
- Other model types (classification, embedding, etc.) — future expansion
- Cloud/remote inference — this is an on-device app
- Model fine-tuning — running inference only
- iPad/Mac support — iPhone first

## Context

- Hugging Face has a public API for model discovery, metadata, and file downloads
- llama.cpp has Swift/iOS bindings and is the most mature option for on-device LLM inference on Apple hardware
- Apple Neural Engine and GPU can accelerate inference but compatibility varies by chip generation (A-series, M-series)
- iOS exposes device info via ProcessInfo, sysctlbyname, and related APIs for RAM, chip, storage
- GGUF is the primary model format for llama.cpp — model metadata includes quantization level and parameter count which inform compatibility
- Models range from ~1GB (small quantized 1-3B) to 10GB+ (7B+ models) — storage management is critical on mobile

## Constraints

- **Platform**: iOS (SwiftUI) — iPhone only for v1
- **Inference engine**: llama.cpp Swift bindings — proven iOS support, GGUF format
- **Model source**: Hugging Face Hub API — primary model registry
- **On-device only**: No server-side inference, all processing happens locally
- **Storage**: Must respect device storage limits and allow users to manage downloaded models

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| llama.cpp for inference | Most mature iOS-compatible LLM inference engine, strong community, GGUF format support | — Pending |
| LLMs only for v1 | Narrower scope lets us nail the core UX (browse → verify → download → chat) before expanding model types | — Pending |
| Dynamic device detection over hardcoded specs | User might change phones; app should work on any supported device without updates | — Pending |
| Hard + soft compatibility tiers | Hard limits prevent broken downloads; soft limits help users make informed tradeoffs (speed vs capability) | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-08 after Phase 1 completion*
