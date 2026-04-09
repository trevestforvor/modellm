# Roadmap: ModelRunner

## Overview

ModelRunner ships in five phases that follow the natural dependency chain of the app: device capability detection must exist before compatibility can be shown, browse must exist before downloads make sense, downloads must complete before inference can run, and inference must be stable before polish is layered on top. Each phase delivers a coherent, testable slice of the product.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Device Foundation** - Detect device specs and compute compatibility verdicts before any UI exists
- [x] **Phase 2: HF Browse + Compatibility UI** - Browse Hugging Face models with live compatibility badges
- [ ] **Phase 3: Download + Model Library** - Download models in the background and manage the local library
- [ ] **Phase 4: Inference + Chat** - Load a model and run a streaming chat conversation on-device
- [ ] **Phase 5: Polish + V1 Completeness** - Chat history, inference parameters, and UX completeness

## Phase Details

### Phase 1: Device Foundation
**Goal**: The app correctly knows what the device can run before showing any models
**Depends on**: Nothing (first phase)
**Requirements**: DEVC-01, DEVC-02, DEVC-03, DEVC-04, DEVC-05, DEVC-06
**Success Criteria** (what must be TRUE):
  1. App detects chip family, physical RAM, and free storage at launch without user input
  2. CompatibilityEngine returns a hard-blocked verdict for a model that exceeds the device's jetsam-limited RAM budget
  3. CompatibilityEngine returns a soft-warning verdict for a model that will run but is likely to generate tokens slowly
  4. Compatibility math accounts for ~40% jetsam headroom and KV cache overhead, not raw physical RAM
  5. Storage impact (e.g. "Uses 4.2 GB, you have 6.1 GB free") can be computed from model metadata
**Plans**: 3 plans
Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold, entitlements, type contracts, Wave 0 test stubs
- [x] 01-02-PLAN.md — ChipLookupTable + DeviceCapabilityService (DEVC-01, DEVC-05)
- [x] 01-03-PLAN.md — CompatibilityEngine with KV cache math (DEVC-02, DEVC-03, DEVC-04, DEVC-06)

### Phase 2: HF Browse + Compatibility UI
**Goal**: Users can browse and search Hugging Face models and immediately see whether each will run on their device
**Depends on**: Phase 1
**Requirements**: HFIN-01, HFIN-02, HFIN-03, HFIN-04
**Success Criteria** (what must be TRUE):
  1. User can open the app and see a list of GGUF/LLM models from Hugging Face
  2. User can search models by name or keyword and see results update
  3. User can tap a model and view file size, quantization level, parameter count, and a clear compatibility verdict (Runs well / Runs slowly / Won't run)
  4. Each model row in the list shows a compatibility badge derived from the device's actual specs
  5. A "Best for your device" recommendation section surfaces chip-appropriate models
**Plans**: 3 plans
Plans:
- [x] 02-01-PLAN.md — HF type system scaffold (HFModels, AnnotatedModel, HFAPIError, QuantizationParser, test stubs)
- [x] 02-02-PLAN.md — HFAPIService networking + HFBrowseViewModel business logic
- [x] 02-03-PLAN.md — SwiftUI view layer (BrowseView, ModelCardView, ToksBadgeView, ModelDetailView, VariantRowView, ContentView TabView)
**UI hint**: yes

### Phase 3: Download + Model Library
**Goal**: Users can download a model safely and manage their local collection
**Depends on**: Phase 2
**Requirements**: DLST-01, DLST-02, DLST-03, DLST-04, DLST-05
**Success Criteria** (what must be TRUE):
  1. User can start a download and see live progress (MB/s, ETA, and a cancel button)
  2. A download started in the app continues if the user backgrounds the app
  3. User can open the Library tab and see all downloaded models with size and last-used date
  4. User can delete a downloaded model from the Library to free storage
  5. User can switch which downloaded model is active
**Plans**: TBD
**UI hint**: yes

### Phase 4: Inference + Chat
**Goal**: Users can have a streaming conversation with a downloaded model entirely on-device
**Depends on**: Phase 3
**Requirements**: CHAT-01, CHAT-02, CHAT-03, CHAT-06
**Success Criteria** (what must be TRUE):
  1. User can load a downloaded model and send a message; tokens stream into the chat view in real time
  2. Tokens per second is displayed during active inference
  3. Chat works with no internet connection after the model is downloaded
  4. The UI remains scrollable and responsive while the model is generating tokens
**Plans**: TBD
**UI hint**: yes

### Phase 5: Polish + V1 Completeness
**Goal**: Chat history persists, inference parameters are adjustable, and the full pipeline has no rough edges
**Depends on**: Phase 4
**Requirements**: CHAT-04, CHAT-05
**Success Criteria** (what must be TRUE):
  1. User can close and reopen the app and find their previous conversations intact
  2. User can adjust temperature, system prompt, and top-p before or during a session
  3. User can return to any past conversation and continue it
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Device Foundation | 2/3 | In Progress|  |
| 2. HF Browse + Compatibility UI | 0/TBD | Not started | - |
| 3. Download + Model Library | 2/4 | In Progress|  |
| 4. Inference + Chat | 0/TBD | Not started | - |
| 5. Polish + V1 Completeness | 0/TBD | Not started | - |
