# UI Consolidation: Two-Tab Layout with Model Cards

**Date:** 2026-04-12
**Status:** Approved
**Scope:** Consolidate 4 tabs into 2 (Chat + Models), redesign Models tab with card grid + HF browse list

---

## Problem

ModelRunner has 4 tabs (Browse, Library, Chat, Settings) but only Chat and Settings do anything useful. Browse and Library are separate concepts that should be unified. Settings contains only server management, which belongs in the Models tab. The result is a scattered navigation that makes a mostly-empty app feel emptier.

## Design

### Tab Bar

Two tabs, left to right:

1. **Chat** (bubble icon) — primary tab, leftmost position
2. **Models** (grid icon) — model management, server connections, HF browsing

No Settings tab. Settings accessible via gear icon in Models tab header.

### Models Tab Layout

Single scrollable view with two sections, separated by a divider:

#### Section 1: "My Models" (Card Grid)

A 2-column grid of rounded rectangle cards showing all available models — both downloaded on-device models and remote server models, unified.

**Each card contains:**
- **Source indicator** — colored dot + label (e.g., green dot "MacBook Pro", purple dot "On Device", red dot "Home Server")
- **Model name** — primary text, bold (e.g., "nemotron-3-nano-4b")
- **Size info** — secondary text (e.g., "3.97B params" for remote, "Q4_K_M · 2.1 GB" for local)
- **Tok/s** — monospace, purple accent (e.g., "129 tok/s"), or "— tok/s" if never used
- **Capability badge** — bottom-right:
  - Thinking models: purple badge "🧠 think"
  - Local models: green "Runs Well" / yellow "Runs Slow" badge from CompatibilityEngine
  - Code models: purple "code" tag (future)
  - Offline: red "offline" text

**Card states:**
- **Online/available** — full opacity, tappable
- **Offline** — 45% opacity, red dot, "offline" badge, not tappable

**Card interaction:**
- **Tap** → select model and switch to Chat tab with it loaded
- **Swipe left** → delete (with confirmation for downloaded models, instant for remote)
- **Long press** → context menu (delete, server details for remote models)

**"+ Add Server" button** — inline in the section header row, right-aligned. Opens the AddServerView sheet. Same design as current implementation.

**Empty state:** When no models exist, show a centered prompt: "Add a remote server or download a model to get started" with two buttons: "Add Server" and "Browse Models" (scrolls to HF section).

#### Divider

A subtle 1px line (`#302E42`) with 20px vertical margins separating the two sections.

#### Section 2: "Browse Hugging Face" (List)

A search bar + scrollable list of HF GGUF models. Uses list format (not cards) because browse results are denser and benefit from horizontal info layout.

**Search bar** — dark input field with magnifying glass icon, placeholder "Search GGUF models..."

**Each browse row contains:**
- **Model name** — primary text, bold (e.g., "Phi-4-mini GGUF")
- **Publisher + size + quant** — secondary line (e.g., "bartowski · 3.8B · Q4_K_M available")
- **Download count** — tertiary line (e.g., "⬇ 124K downloads")
- **Compatibility badge** — right-aligned:
  - Green "Runs Well" — fits in RAM, good performance expected
  - Yellow "Runs Slow" — fits but will be slow
  - Red "Too Large" — won't fit, dimmed at 45% opacity

**Row interaction:**
- **Tap** → navigate to model detail view (existing ModelDetailView) with download options and full compatibility breakdown

**Recommendations:** Top 5 models by download count filtered to "Runs Well" tier, shown before the search bar as a "Recommended" subsection.

### Navigation Header

- **Left:** Large title "Models" (standard iOS large title style)
- **Right:** Gear icon button → settings sheet (inference defaults, about screen, future preferences)

### Settings Sheet (via gear icon)

Not a tab — a presented sheet accessible from the gear icon. Contains:
- Inference defaults (temperature, top-p, system prompt) — currently in ChatSettingsView
- About / app version
- Future: theme, notifications, export data

Server management does NOT live here — it's in the Models tab via "+ Add Server".

### Chat Tab

No changes to the Chat tab layout itself. The model picker sheet is still accessible from the toolbar title, but the primary model selection path is now tapping a card on the Models tab.

The Chat tab remains the leftmost tab (primary destination). When the app launches with no model selected, Chat shows the "Select Model" prompt as it does now.

## Files Affected

### Delete (tab consolidation)
- `ModelRunner/Features/Settings/ServerListView.swift` — server list moves into Models tab

### Create
- `ModelRunner/Features/Models/ModelsTabView.swift` — new unified Models tab
- `ModelRunner/Features/Models/ModelCardView.swift` — card component for My Models grid
- `ModelRunner/Features/Models/MyModelsSection.swift` — card grid section with "+ Add Server"
- `ModelRunner/Features/Models/BrowseSection.swift` — HF search + list section

### Modify
- `ModelRunner/ContentView.swift` — 2 tabs (Chat + Models), remove Browse/Library/Settings tabs
- `ModelRunner/Features/ModelPicker/ModelPickerViewModel.swift` — reuse for Models tab data (already aggregates local + remote)
- Possibly `ModelRunner/Features/Browse/BrowseView.swift` — extract HF search logic if reusable, or replace with BrowseSection

### Keep (reuse as-is)
- `ModelRunner/Features/Settings/AddServerView.swift` — presented as sheet from "+ Add Server"
- `ModelRunner/Features/Settings/ServerDetailView.swift` — presented from long-press context menu on remote model cards
- `ModelRunner/Features/Chat/ChatView.swift` — unchanged
- `ModelRunner/Features/ModelPicker/ModelPickerView.swift` — still used from Chat tab toolbar

## Card Design Tokens

```
Card background:     #1A1830
Card border:         #302E42, 1px solid
Card corner radius:  14pt
Card padding:        14pt
Grid gap:            10pt
Grid columns:        2 (equal width)

Source dot:          8x8pt circle
  - Remote online:   #22c55e (green)
  - On device:       #8B7CF0 (purple accent)
  - Remote offline:  #ef4444 (red)

Model name:          14pt, weight 600, white
Size/quant:          11pt, #6B6980
Tok/s:               11pt, monospace, #8B7CF0

Badge background:    15% opacity of badge color
Badge text:          9pt, badge color
Badge corner radius: 6pt
```

## What This Design Does NOT Cover

- Fixing HF API wiring (separate effort — Browse section uses existing BrowseViewModel)
- Download pipeline (separate effort)
- On-device inference (separate effort — llama.cpp XCFramework)
- Onboarding flow updates (may need adjustment for 2-tab layout)
- Model detail view redesign (existing ModelDetailView is kept)
