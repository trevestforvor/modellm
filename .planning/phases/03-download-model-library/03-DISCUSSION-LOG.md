# Phase 3: Download + Model Library - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 03-Download + Model Library
**Areas discussed:** Download experience, Library management, Storage guardrails, File management

---

## Download Experience

### Progress UI

| Option | Description | Selected |
|--------|-------------|----------|
| Inline on model card | Progress bar replaces download button on detail view | |
| Persistent bottom bar | Floating bar at bottom, visible across all screens | ✓ |
| Dedicated downloads tab | Separate tab for active/queued downloads | |
| You decide | Claude picks best pattern | |

**User's choice:** Persistent bottom bar
**Notes:** Like Apple Music downloads — always visible.

### Download Concurrency

| Option | Description | Selected |
|--------|-------------|----------|
| One at a time | Queue additional downloads | ✓ |
| Up to 2 concurrent | Two parallel with queue | |
| Unlimited concurrent | Download as many as desired | |

**User's choice:** One at a time (recommended)

### Failure Recovery

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-resume on next launch | Detects incomplete, resumes automatically | |
| Manual retry button | Show failed download with Retry button | |
| Auto-resume + manual cancel | Resume automatically, show notification to cancel | ✓ |

**User's choice:** Auto-resume + manual cancel

### Network Policy

| Option | Description | Selected |
|--------|-------------|----------|
| Wi-Fi only by default | Block cellular, no override | |
| Wi-Fi default + cellular toggle | Default Wi-Fi, setting to allow cellular | |
| Always allow, warn on cellular | Allow cellular with per-download warning dialog | ✓ |

**User's choice:** Always allow, warn on cellular

---

## Library Management

### Navigation

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated tab | Bottom tab bar: Browse \| Library | ✓ |
| Section within Browse | 'My Models' section above recommendations | |
| Profile/settings area | Library under profile/settings screen | |

**User's choice:** Dedicated tab (recommended)

### Card Info

| Option | Description | Selected |
|--------|-------------|----------|
| Essentials only | Name, size, quant type, compatibility badge | |
| Essentials + usage stats | Above plus last-used date, conversation count | ✓ |
| Rich detail | All above plus HF download count, description, params | |

**User's choice:** Essentials + conversation count, sorted by last-used
**Notes:** User wanted essentials plus conversation count specifically. Sort by last-used so most recently active model is at top. Claude suggested showing relative timestamp alongside conversation count.

### Deletion

| Option | Description | Selected |
|--------|-------------|----------|
| Swipe-to-delete | Standard iOS swipe with confirm alert | |
| Edit mode with multi-select | Edit button for bulk deletion | |
| Both | Swipe for single, Edit for bulk | ✓ |

**User's choice:** Both (recommended)

### Active Model Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Tap to activate | Tap model, checkmark appears, used for Chat | ✓ |
| No explicit activation | Pick model when starting new chat (Phase 4) | |
| You decide | Claude picks based on Phase 4 needs | |

**User's choice:** Tap to activate

---

## Storage Guardrails

### Pre-download Check

| Option | Description | Selected |
|--------|-------------|----------|
| Block if insufficient | Disable download if free < model + buffer | ✓ |
| Warn but allow | Warning dialog, let users proceed | |
| Block + suggest cleanup | Block and suggest models to delete | |

**User's choice:** Block if insufficient, but with 1 GB buffer (increased from 500 MB)
**Notes:** User explicitly requested increasing the buffer from 500 MB to 1 GB.

### Mid-download Storage Fill

| Option | Description | Selected |
|--------|-------------|----------|
| Pause + notify | Pause download, notification, auto-resume when space available | ✓ |
| Fail + clean up | Cancel and delete partial file | |
| Pause + offer cleanup | Pause and offer to delete other models | |

**User's choice:** Pause + notify

### Storage Summary

| Option | Description | Selected |
|--------|-------------|----------|
| Header summary | "Models: 3 · 12.4 GB used · 8.2 GB free" at top of Library | ✓ |
| No summary | Individual sizes are enough | |
| Storage bar visualization | Visual bar like iPhone Storage settings | |

**User's choice:** Header summary (recommended)

---

## File Management

### Cache Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| swift-huggingface cache | Use library's built-in cache structure | ✓ |
| Custom app storage | Own file management in Documents/App Support | |
| You decide | Claude picks based on capabilities | |

**User's choice:** swift-huggingface cache (recommended)

### Metadata Storage

| Option | Description | Selected |
|--------|-------------|----------|
| SwiftData | @Model for downloaded model records | ✓ |
| UserDefaults / plist | Simple key-value storage | |
| JSON file | Local JSON in Application Support | |

**User's choice:** SwiftData (recommended)

### iCloud Backup

| Option | Description | Selected |
|--------|-------------|----------|
| Exclude from backup | isExcludedFromBackup for GGUF files | ✓ |
| Include in backup | Let iCloud back up model files | |
| You decide | Claude picks based on Apple guidelines | |

**User's choice:** Exclude from backup (recommended)

---

## Claude's Discretion

- Bottom bar design (height, animation, appearance/dismissal)
- Download queue management implementation
- SwiftData model schema details
- Library empty state design
- Cellular warning dialog copy and styling
- Active model state persistence

## Deferred Ideas

None — discussion stayed within phase scope
