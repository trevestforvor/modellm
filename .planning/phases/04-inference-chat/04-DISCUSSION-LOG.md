# Phase 4: Inference + Chat - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-09
**Phase:** 04-Inference + Chat
**Areas discussed:** Chat UI layout, Model loading experience, Conversation behavior

---

## Chat UI Layout

### Streaming Token Display

| Option | Description | Selected |
|--------|-------------|----------|
| Character-by-character | Each token appears one at a time, typing animation | ✓ |
| Chunk buffered | Buffer a few tokens before rendering | |
| You decide | Claude picks based on llama.cpp callback behavior | |

**User's choice:** Character-by-character

### Tok/s Indicator Position

| Option | Description | Selected |
|--------|-------------|----------|
| Below the generating message | Small text under assistant bubble | ✓ |
| In the input bar area | Replace input field with generation status bar | |
| Both | Status bar + badge near streaming text | |

**User's choice:** Below the generating message

### Message Style

| Option | Description | Selected |
|--------|-------------|----------|
| Bubble style | Colored bubbles like iMessage | ✓ |
| Full-width blocks | Messages span full width like ChatGPT | |
| Minimal / flat | No backgrounds, just text with role labels | |

**User's choice:** Bubble style (recommended)

### Markdown Rendering

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — full markdown | Bold, italic, code blocks, lists, headers | ✓ |
| Code blocks only | Fenced code with syntax highlighting only | |
| Plain text only | No markdown rendering | |

**User's choice:** Full markdown

---

## Model Loading Experience

### Loading UX

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen loading | Dedicated loading screen with progress | |
| Inline in chat view | Chat view opens with loading indicator | |
| Background with notification | Model loads in background, notification when ready | |

**User's choice:** Chat view opens immediately, model loads in background with circular progress animation
**Notes:** User specified they want a "nice looking loading animation, perhaps a download completion circle" visible in the chat UI while the model loads.

### Load Failure

| Option | Description | Selected |
|--------|-------------|----------|
| Error in chat view | Error message in chat area with retry button | |
| Bounce to Library | Navigate back with error alert | |
| You decide | Claude picks based on error type | ✓ |

**User's choice:** You decide

---

## Conversation Behavior

### Stop Generation

| Option | Description | Selected |
|--------|-------------|----------|
| Stop button | Button in input area, stops immediately, keeps partial | ✓ |
| Tap message to stop | Tap generating message to stop | |
| No stop | Wait for completion | |

**User's choice:** Stop button (recommended)

### Regenerate / Edit

| Option | Description | Selected |
|--------|-------------|----------|
| Regenerate only | Regenerate button on last assistant message | |
| Regenerate + edit | Regenerate + edit last user message | |
| Neither for v1 | No regen or editing | ✓ |

**User's choice:** Neither — user prefers to clarify inline rather than regenerate or edit
**Notes:** User said "I don't think people really do either of those" and "I'd rather just clarify inline"

### System Prompt

| Option | Description | Selected |
|--------|-------------|----------|
| Hidden default | Sensible default, user never sees it | |
| Visible but not editable | Show at top of chat as info element | |
| Editable from start | User can set/edit before or during chat | ✓ |

**User's choice:** Preset system prompts that populate an editable text field in a settings view
**Notes:** User wants "a few suggested minimal ones that they can propagate into a text view that they could then edit" — lives in settings, separate from main chat UI

### Chat Navigation

| Option | Description | Selected |
|--------|-------------|----------|
| Chat tab (3-tab bar) | Browse \| Library \| Chat — dedicated tab | ✓ |
| Chat opens from Library | Tapping active model pushes into chat | |
| You decide | Claude picks based on navigation hierarchy | |

**User's choice:** Chat tab (3-tab bar)

---

## Claude's Discretion

- Model load error handling UX
- System prompt preset list
- Chat settings view layout
- Switching active model during conversation
- Memory management during inference
- AsyncStream implementation

## Deferred Ideas

- Chat history persistence — Phase 5
- Inference parameter tuning — Phase 5
