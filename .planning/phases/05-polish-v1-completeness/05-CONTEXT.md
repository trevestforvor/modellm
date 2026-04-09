# Phase 5: Polish + V1 Completeness - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning (design consultation needed before planning)

<domain>
## Phase Boundary

Chat history persists, inference parameters are adjustable, and the full pipeline has no rough edges. Includes: conversation persistence with SwiftData, conversation list UI, inference parameter controls (temperature, top-p, system prompt), first-launch onboarding choice, and overall v1 polish. Does NOT include new features beyond the existing Browse → Download → Chat pipeline.

</domain>

<decisions>
## Implementation Decisions

### Chat History Persistence
- **D-01:** Conversations stored in SwiftData. Each conversation has messages, associated model, creation date, and auto-generated title.
- **D-02:** Conversation list grouped by model. Model name as section header, conversations listed underneath.
- **D-03:** Conversation list lives inside the Chat tab. Chat tab shows the list by default; tapping a conversation resumes it, "New Chat" starts fresh.
- **D-04:** Auto-title from first user message (truncated). No manual renaming.
- **D-05:** Swipe-to-delete on conversation rows. Confirmation alert. Consistent with Library deletion pattern.
- **D-06:** Conversation list visual treatment: glass-style navigation buttons per model group (not cards, not plain rows). Exact design TBD via design consultation.

### Inference Parameters
- **D-07:** Friendly presets ("Precise", "Balanced", "Creative") that map to temperature/top-p combos, plus an expandable "Advanced" section with actual sliders for power users.
- **D-08:** Parameters are per-model. Each model has its own temperature, top-p, and system prompt stored in SwiftData. All conversations with that model use its settings.
- **D-09:** System prompt presets established in Phase 4 (D-11) — Phase 5 extends the settings view with temperature/top-p controls alongside the existing system prompt field.

### First-Launch Onboarding
- **D-10:** Welcome screen with two paths: "Get Started" (skip to Browse) or "Show Me Around" (guided download). Users choose their experience.
- **D-11:** Guided path: app auto-picks the best "Runs Well" model for the user's device (smallest + fastest). Walks them through download → first message. Zero decision fatigue.
- **D-12:** Welcome screen design TBD via design consultation — may use MeshGradient or be visually distinct.

### Claude's Discretion
- Edge case handling: deleted model with existing conversations, storage full during inference
- Conversation message schema (exact SwiftData fields)
- How conversation list transitions to/from active chat
- Parameter slider ranges and step values
- Guided onboarding copy and flow pacing

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phases
- `.planning/phases/03-download-model-library/03-CONTEXT.md` — D-15 (SwiftData for model metadata), D-10 (tap to activate model)
- `.planning/phases/04-inference-chat/04-CONTEXT.md` — D-11 (system prompt presets in settings view), D-12 (Chat as 3rd tab)

### Design System
- `DESIGN.md` — Full visual system. **Must be updated** with Phase 5 surfaces before planning.
- `ChatLibraryPreview.playground` — Phase 3+4 design reference
- A new design consultation is needed for: conversation list, parameter settings view, welcome/onboarding screen

### Project & Requirements
- `.planning/PROJECT.md` — Core value, constraints
- `.planning/REQUIREMENTS.md` — CHAT-04 (history persistence), CHAT-05 (inference parameters)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 3's SwiftData setup — ModelContainer already configured, DownloadedModel @Model exists. Extend with Conversation and Message models.
- Phase 4's ChatSettingsView — already has system prompt presets. Extend with temperature/top-p controls.
- Phase 4's ChatViewModel — in-memory conversation. Phase 5 adds persistence layer underneath.
- AppContainer — @Observable, holds all services

### Established Patterns
- @Observable for state management
- SwiftData @Model for persistence (Phase 3)
- MeshGradient background across all screens
- Swipe-to-delete with confirmation (Phase 3 Library)

### Integration Points
- ChatViewModel gains SwiftData read/write for conversation persistence
- Chat tab root view becomes a conversation list (new) instead of directly showing chat
- Settings view extends with parameter sliders
- Welcome screen inserts before main TabView on first launch

</code_context>

<specifics>
## Specific Ideas

- Glass-style navigation buttons for the conversation list — user specifically wants this visual treatment, not cards or plain rows
- Parameters per-model is the right grain — a creative writing model at temp 1.2 shouldn't affect a code helper at temp 0.3
- The guided onboarding auto-picks a model — this means the app needs a "best model for this device" algorithm (filter to Runs Well, sort by smallest size, pick first)
- Design consultation needed for three new surfaces before planning: conversation list, parameter settings, welcome/onboarding

</specifics>

<deferred>
## Deferred Ideas

- Manual conversation renaming — could be added post-v1
- Export/share conversations — future feature
- Model-specific chat themes — future personalization

</deferred>

---

*Phase: 05-polish-v1-completeness*
*Context gathered: 2026-04-09*
