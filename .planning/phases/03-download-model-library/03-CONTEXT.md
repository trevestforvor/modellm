# Phase 3: Download + Model Library - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can download a model safely and manage their local collection. Includes: download initiation from Phase 2's detail view, background download with progress, model library management (view, delete, switch active), and storage guardrails. Does NOT include inference/chat (Phase 4) or chat history (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Download Experience
- **D-01:** Persistent bottom bar for download progress — visible across all screens (like Apple Music downloads). Shows active download with MB/s, ETA, and cancel button.
- **D-02:** One download at a time. Additional downloads are queued.
- **D-03:** Auto-resume on app relaunch if a download was interrupted (network loss, crash). Show a notification so user can cancel if they changed their mind. swift-huggingface supports resume.
- **D-04:** Allow downloads on any network type. If on cellular, show a warning dialog with the file size before proceeding ("This will use ~3.2 GB of cellular data. Continue?").
- **D-05:** Downloads continue when the app is backgrounded (DLST-02). Use background URLSession.

### Library Management
- **D-06:** Dedicated Library tab in bottom tab bar (Browse | Library). Not a section within Browse.
- **D-07:** Library card shows: model name, file size on disk, quantization type, compatibility badge (tok/s pill from Phase 2), and conversation count.
- **D-08:** Library sorted by last-used date (most recently used first). Show relative timestamp ("2 hours ago") alongside conversation count to reinforce sort order.
- **D-09:** Swipe-to-delete for single models, Edit button for bulk deletion. Destructive confirmation alert shows size freed ("Delete Llama 3.2? This will free 3.4 GB.").
- **D-10:** Tap a model in Library to make it the active model (checkmark appears). Active model is what loads when user opens Chat in Phase 4.

### Storage Guardrails
- **D-11:** Pre-download storage check: if free storage < model size + 1 GB buffer, disable download button with message ("Need X GB free, you have Y GB"). Hard block — no override.
- **D-12:** If storage fills mid-download (another app uses space), pause the download and show a notification ("Download paused — low storage"). Auto-resume when space is available. Partial file is kept.
- **D-13:** Library header summary: "Models: 3 · 12.4 GB used · 8.2 GB free". Quick glance at total storage impact.

### File Management
- **D-14:** Use swift-huggingface's built-in cache for file storage. Proven cache structure, handles dedup, resume-friendly.
- **D-15:** SwiftData @Model for downloaded model metadata (name, file path, size, quantization, last used date, conversation count, active status). Consistent with iOS 17+ target.
- **D-16:** GGUF files excluded from iCloud backup (isExcludedFromBackup = true). Models are 2-4 GB — re-downloadable content should not consume iCloud storage.

### Claude's Discretion
- Bottom bar design (height, animation, how it appears/dismisses)
- Download queue management implementation details
- SwiftData model schema (exact fields, relationships)
- Library empty state design
- Cellular warning dialog copy and styling
- How active model state persists across launches

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Foundation
- `.planning/phases/01-device-foundation/01-CONTEXT.md` — D-03 (indeterminate blocked from download), D-06 (storage re-checked before download)
- `ModelRunner/Services/Device/CompatibilityModels.swift` — ModelMetadata, CompatibilityResult, CompatibilityTier types
- `ModelRunner/Services/Device/DeviceCapabilityService.swift` — Runtime storage detection

### Phase 2 Browse UI
- `.planning/phases/02-hf-browse-compatibility-ui/02-CONTEXT.md` — D-11 (detail view download button), D-12 (per-variant compatibility)
- `ModelRunner/App/AppContainer.swift` — @Observable container, holds services

### Project & Requirements
- `.planning/PROJECT.md` — Core value, constraints, swift-huggingface as download library
- `.planning/REQUIREMENTS.md` — DLST-01 through DLST-05 acceptance criteria

### Research
- `.planning/research/STACK.md` — swift-huggingface 0.8.0+ download capabilities, background URLSession patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DeviceCapabilityService` — provides free storage via runtime detection, ready for pre-download checks
- `CompatibilityModels.swift` — ModelMetadata struct has fileSizeBytes for storage impact calculation
- `AppContainer` — @Observable, will hold the new DownloadManager and ModelLibrary services

### Established Patterns
- @Observable for state management (AppContainer)
- Actor pattern for async services (DeviceCapabilityService)
- iOS 17+ target with SwiftUI and SwiftData

### Integration Points
- Phase 2's model detail view triggers download — download button connects to DownloadManager
- Library tab added to main tab bar navigation
- SwiftData ModelContainer needs to be configured in App entry point
- Active model selection feeds into Phase 4's inference loading

</code_context>

<specifics>
## Specific Ideas

- The persistent bottom bar should feel like Apple Music's download indicator — unobtrusive but always visible when a download is active
- Library sorted by recency means the model you just used is always at the top — no hunting
- Conversation count on library cards ties the model to its usage, helping users decide what to keep
- 1 GB storage buffer is generous but prevents the frustrating "download failed at 98%" scenario

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-download-model-library*
*Context gathered: 2026-04-09*
