# Requirements: ModelRunner

**Defined:** 2026-04-08
**Core Value:** Device-aware model compatibility verification — users see at a glance what will run well, what will run slowly, and what won't run at all on their specific device, before downloading anything.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Device & Compatibility

- [x] **DEVC-01**: App dynamically detects device chip family, RAM, and available storage at runtime
- [x] **DEVC-02**: App computes hard compatibility limits — models that cannot run are blocked from download
- [x] **DEVC-03**: App computes soft compatibility tiers — models that will run slowly display a warning with expected performance band
- [x] **DEVC-04**: App shows storage impact before download (e.g. "Uses 4.2 GB, you have 6.1 GB free")
- [x] **DEVC-05**: Compatibility engine accounts for actual usable RAM (~40% of physical) not total RAM
- [x] **DEVC-06**: Compatibility engine factors in KV cache memory for context window sizing

### HF Integration

- [ ] **HFIN-01**: User can browse Hugging Face models filtered to GGUF/LLM models
- [ ] **HFIN-02**: User can search models by name or keyword
- [ ] **HFIN-03**: User can view model detail with file size, quantization level, parameter count, and compatibility verdict
- [ ] **HFIN-04**: App surfaces chip-specific model recommendations ("Best for your [device]")

### Download & Storage

- [ ] **DLST-01**: User can download models via background URLSession with progress indicator (MB/s, ETA, cancel)
- [ ] **DLST-02**: Downloads continue when app is backgrounded
- [ ] **DLST-03**: User can view all downloaded models with size and last-used date
- [ ] **DLST-04**: User can delete downloaded models to free storage
- [ ] **DLST-05**: User can switch between downloaded models

### Inference & Chat

- [ ] **CHAT-01**: User can load a downloaded model and chat with it via streaming token output
- [ ] **CHAT-02**: App displays tokens/sec during inference
- [ ] **CHAT-03**: Chat works fully offline after model is downloaded
- [ ] **CHAT-04**: User can view and return to previous chat conversations (history persistence)
- [ ] **CHAT-05**: User can adjust inference parameters (temperature, system prompt, top-p)
- [ ] **CHAT-06**: Inference runs on background thread — UI remains responsive during generation

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Model Types

- **MODL-01**: Support speech-to-text models
- **MODL-02**: Support image generation models
- **MODL-03**: Support other model types (classification, embedding)

### Advanced Features

- **ADVF-01**: RAG / document upload for chat context
- **ADVF-02**: Plain-language quantization labels (Q4_K_M → "Balanced")
- **ADVF-03**: iPad layout support
- **ADVF-04**: LoRA adapter management

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud/remote inference | Contradicts privacy and offline value proposition |
| Model fine-tuning | Impractical on-device; creates runaway complexity |
| OpenAI-compatible API server | iOS sandboxing makes background socket servers non-viable |
| Multi-model simultaneous inference | 2x RAM pressure will get the app killed by iOS |
| Social/sharing features | Contradicts local-first privacy positioning |
| Push notifications | Background URLSession handles download completion natively |
| Mac/iPad support | iPhone first; expand platform after validation |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEVC-01 | Phase 1 | Complete |
| DEVC-02 | Phase 1 | Complete |
| DEVC-03 | Phase 1 | Complete |
| DEVC-04 | Phase 1 | Complete |
| DEVC-05 | Phase 1 | Complete |
| DEVC-06 | Phase 1 | Complete |
| HFIN-01 | Phase 2 | Pending |
| HFIN-02 | Phase 2 | Pending |
| HFIN-03 | Phase 2 | Pending |
| HFIN-04 | Phase 2 | Pending |
| DLST-01 | Phase 3 | Pending |
| DLST-02 | Phase 3 | Pending |
| DLST-03 | Phase 3 | Pending |
| DLST-04 | Phase 3 | Pending |
| DLST-05 | Phase 3 | Pending |
| CHAT-01 | Phase 4 | Pending |
| CHAT-02 | Phase 4 | Pending |
| CHAT-03 | Phase 4 | Pending |
| CHAT-06 | Phase 4 | Pending |
| CHAT-04 | Phase 5 | Pending |
| CHAT-05 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 21 total
- Mapped to phases: 21
- Unmapped: 0

---
*Requirements defined: 2026-04-08*
*Last updated: 2026-04-08 after roadmap creation*
