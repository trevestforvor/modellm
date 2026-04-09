# Design System — ModelRunner

## Product Context
- **What this is:** iOS app for browsing Hugging Face models, verifying device compatibility, downloading, and running LLM inference on-device
- **Who it's for:** People who want to run AI models locally on their iPhone
- **Space/industry:** On-device AI tools (PocketPal AI, LLMFarm, Locally AI, Google AI Edge Gallery)
- **Project type:** Native iOS app (SwiftUI, iPhone-first)

## Aesthetic Direction
- **Direction:** Industrial-precision with atmosphere
- **Decoration level:** Intentional — MeshGradient background provides depth and personality, cards are clean data surfaces
- **Mood:** Confident dark instrument that knows your device. Not a terminal, not a toy. Approachable precision. The gradient gives it soul; the data density gives it credibility.
- **References:** Locally AI (dark, clean), Split app Midnight Prism theme (gradient-as-material)

## Background — MeshGradient

The background is a SwiftUI `MeshGradient` (iOS 18+), not a flat color. This is the signature visual element.

**3x3 mesh, dark spectrum with sapphire/violet/teal color flow:**

```
Top row:    #172440 (sapphire)  → #0F0E1A (base)   → #122A32 (teal)
Mid row:    #221942 (violet)    → #110F1C (base)    → #141E3A (deep blue)
Bottom row: #0F0E1A (base)     → #12242C (teal)    → #1C153E (violet)
```

**Rules:**
- The gradient IS the app background. Content sits directly on it.
- Cards use solid `#0D0C18` — dark enough to let the gradient show between cards, solid enough for consistent text contrast
- The gradient shows through the gaps between cards, not through the cards themselves
- The gradient should feel like colored light in a dark room, not a painted wall

**SwiftUI implementation:** See `MeshGradientPreview.playground` for the working reference.

## Typography

All system fonts. No custom fonts.

- **Display/Hero:** SF Pro Display — nav titles, screen headers (22pt, bold)
- **Heading:** SF Pro Text — section headers (17pt, semibold)
- **Body:** SF Pro Text — descriptions, author names (15pt/13pt, regular)
- **Data values:** SF Mono — tok/s badges, file sizes (12pt, semibold). Monospace signals precision.
- **Caption:** SF Pro Text — download counts, tertiary info (12pt, regular)

**Rule:** SF Mono is used ONLY for the tok/s badge and file size values. All other text uses SF Pro. This keeps the precision feel without going full terminal.

## Color

- **Approach:** Restrained dark with one accent + two semantic compatibility colors
- **Background base:** `#0F0E1A` — dark violet-black (MeshGradient center points)
- **Card surface:** `#0D0C18` solid — near-black, no opacity. Cards are defined by content and faint corner radius, not by contrast.
- **Primary text:** `#EDEDF4` — soft white
- **Secondary text:** `#9896B0` — lavender-gray
- **Tertiary text:** `#6B6980` — muted purple-gray
- **Accent:** `#8B7CF0` — warm violet (links, CTAs, author names)
- **Compatibility green:** `#34D399` — mint-green for "Runs Well" tok/s badges
- **Compatibility amber:** `#FBBF24` — warm gold for "Runs Slowly" tok/s badges
- **Badge backgrounds:** Compatibility color at 12% opacity
- **Borders:** `#302E42` — purple-tinted dark
- **Dark mode:** This IS dark mode. No light mode for v1.

## Spacing
- **Base unit:** 8pt (4pt for fine adjustments)
- **Density:** Comfortable-dense. Cards are packed with info but not cramped.
- **Card internal padding:** 16pt
- **Card gap:** 8-10pt between cards
- **Section header padding:** 20pt top, 10pt bottom
- **Scale:** xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48)

## Layout
- **Approach:** Grid-disciplined, single column on iPhone
- **Card style:** Full-width cards with 16px horizontal margins. Dense content, no thumbnails.
- **Corner radius:** 16pt on cards and search bar. Capsule on badges.
- **Recommendations:** Horizontal scroll section at top, cards show edge of next card for scroll affordance
- **All Models:** Vertical stack below recommendations
- **Detail view:** NavigationStack push (not sheet)

## Tok/s Badge (Signature Element)
The compatibility badge is the centerpiece of every card. It communicates both compatibility AND expected performance in one glance.

- **Format:** `~N tok/s` in SF Mono 12pt semibold
- **Green pill:** `#34D399` text on `#34D399` at 12% opacity background — "Runs Well"
- **Amber pill:** `#FBBF24` text on `#FBBF24` at 12% opacity background — "Runs Slowly"
- **Shape:** Capsule
- **Padding:** 10pt horizontal, 4pt vertical
- **Position:** Top-right of card, aligned with model name

## Motion
- **Approach:** Minimal-functional
- **Transitions:** Standard NavigationStack push/pop
- **No bouncy springs, no entrance animations.** The speed of the app IS the motion design.
- **Download bar:** Spring with dampingFraction 0.8 for slide in/out
- **Potential future:** Subtle MeshGradient animation (slow-moving color flow), but not for v1

## Iconography
- **System:** SF Symbols exclusively
- **Style:** Monochrome, matching text color context
- **No custom icons for v1**

## Navigation Structure
- **Tab bar:** 3 tabs — Browse | Library | Chat
- **Tab bar surface:** `#0D0C18` at 95% opacity with `#302E42` top border
- **Tab icons:** SF Symbols — `square.grid.2x2` (Browse), `tray.full` (Library), `bubble.left.fill` (Chat)
- **Selected state:** `#8B7CF0` (accent violet)
- **Unselected state:** `#6B6980` (tertiary text)

## Download Bar (Phase 3)
Persistent bottom bar visible across all screens during active download. Sits above the tab bar.

- **Surface:** `#0D0C18` at 95% opacity with `#302E42` top border. Same card material.
- **Height:** 52pt. Compact.
- **Progress indicator:** Circular ring (30pt diameter), `#302E42` track, `#8B7CF0` fill stroke with round line cap.
- **Info layout:** Model name in SF Pro Text 13pt medium, then speed/ETA in SF Mono 11pt secondary text.
- **Speed format:** "63%  ·  12.4 MB/s  ·  ~2 min left"
- **Cancel button:** SF Symbol `xmark.circle.fill` at 22pt in `#6B6980`
- **Completion state:** Briefly shows checkmark + "Downloaded" in `#34D399`, then slides away.
- **Animation:** Spring slide up/down with dampingFraction 0.8.

## Library Tab (Phase 3)
Dedicated tab for managing downloaded models.

### Storage Summary Header
- **Position:** Below nav title, centered
- **Format:** "3 Models  ·  8.4 GB  ·  12.1 GB free" in SF Mono 13pt medium, `#9896B0`
- **Dots:** `#6B6980` tertiary

### Library Model Card
Same visual language as browse cards with usage metadata.

```
┌───────────────────────────────────────────┐
│▌ Model Name (16pt semibold)   [ ~32 tok/s]│  ← violet left bar = active model
│▌ Q4_K_M (13pt secondary)                 │
│▌ 2.5 GB  ·  💬 14  ·  2 hours ago        │  ← SF Mono size, conversation count, relative time
└───────────────────────────────────────────┘
```

- **Background:** `#0D0C18` solid
- **Corner radius:** 16pt
- **Active model indicator:** 3pt wide `#8B7CF0` bar on left edge, full card height, 8pt vertical padding
- **Inactive cards:** No left bar, 16pt horizontal padding
- **Active cards:** 13pt horizontal padding (3pt bar + 13pt = 16pt total)
- **Card spacing:** 8pt between cards
- **Sort order:** Last-used date, most recent first
- **Deletion:** Swipe-to-delete (single) + Edit button (bulk). Destructive alert: "Delete [Name]? This will free [size]."

### Library Empty State
- **Symbol:** `arrow.down.circle` SF Symbol in `#6B6980`, `.largeTitle` scale
- **Heading:** "No models yet" in `#6B6980`
- **Body:** "Browse models to download your first one" with "Browse" in `#8B7CF0`

## Chat UI (Phase 4)
Bubble-style chat with MeshGradient showing between messages.

### Chat Nav Bar
- **Surface:** `#0D0C18` at 90% opacity with `#302E42` bottom border
- **Title:** "Chat" in SF Pro 18pt bold
- **Subtitle:** "[Model] · [Quant]" in SF Pro 12pt secondary
- **Settings icon:** SF Symbol `gearshape` in `#9896B0`, trailing

### User Bubbles
- **Background:** `#8B7CF0` (accent violet)
- **Text:** `#EDEDF4` in SF Pro 15pt
- **Alignment:** Right
- **Corner radius:** 16pt top-leading, 16pt top-trailing, 4pt bottom-trailing (tail), 16pt bottom-leading
- **Padding:** 14pt horizontal, 10pt vertical
- **Max width:** Screen width minus 60pt left margin

### Assistant Bubbles
- **Background:** `#1A1830` — slightly lighter than card surface, readable on gradient
- **Text:** `#EDEDF4` in SF Pro 15pt
- **Alignment:** Left
- **Corner radius:** 16pt top-leading, 16pt top-trailing, 16pt bottom-trailing, 4pt bottom-leading (tail)
- **Padding:** 14pt horizontal, 10pt vertical
- **Max width:** Screen width minus 60pt right margin
- **Markdown:** Rendered inside bubbles. Code blocks get `#0D0C18` background with SF Mono.
- **Key visual:** The MeshGradient shows between bubbles. Bubbles float on the gradient, not on a flat background.

### Streaming Indicator
- **Position:** Below the assistant bubble being generated
- **Format:** "~24 tok/s" in SF Mono 11pt semibold
- **Color during streaming:** `#34D399` (green)
- **Color after completion:** `#6B6980` (tertiary), fades out after 2s
- **Cursor:** 2×16pt rectangle in `#8B7CF0` at end of streaming text

### Input Bar
- **Surface:** `#0D0C18` at 95% opacity with `#302E42` top border
- **History toggle:** Glass button (34pt, `#1A1830` at 60% opacity, `#302E42` border, 8pt corner radius) with SF Symbol `clock`. Active state: `clock.fill` in `#8B7CF0`. Positioned left of text field.
- **Text field:** `#1A1830` fill, `#302E42` border at 0.5pt, 12pt corner radius
- **Placeholder:** "Message..." in `#6B6980` 15pt
- **Send button (ready):** 34pt circle, `#8B7CF0` fill, white `arrow.up` icon 14pt bold
- **Send button (disabled):** Same but at 40% opacity
- **Stop button (generating):** 34pt circle, `#FBBF24` (amber) fill, black `stop.fill` icon 12pt bold

### Model Loading State
- **Layout:** Centered on chat view with gradient fully visible behind
- **Progress ring:** 64pt diameter, `#302E42` track, `#8B7CF0` fill, 3pt stroke with round cap
- **Label:** "Loading [Model] [Quant]..." in SF Pro 15pt `#9896B0`
- **Sublabel:** "[size] into memory" in SF Mono 12pt `#6B6980`
- **Input bar:** Disabled state, placeholder "Waiting for model..." at 50% opacity
- **No overlay or dimming:** The gradient is the backdrop

## Glass Material (Phase 5)
A lighter, more translucent surface for navigational elements. Differentiates from solid `#0D0C18` data cards.

- **Background:** `#1A1830` at 60% opacity (gradient bleeds through slightly)
- **Border:** `#302E42` at 0.5pt
- **Corner radius:** 12pt
- **Usage:** Conversation history rows, history toggle button, settings section backgrounds, "Get Started" welcome button

## Conversation History (Phase 5)
Chat tab is always "chat first." History is a toggle overlay, not a landing page.

- **Default state:** Active conversation with input bar at bottom. History toggle (clock icon) beside text field.
- **History state:** Tapping clock replaces chat content with history list. History is bottom-anchored (`.defaultScrollAnchor(.bottom)`), growing upward from the input bar. Most recent conversations closest to text field.
- **Grouped by model:** Model name + quant + tok/s badge as section headers. Glass-material conversation rows underneath.
- **Row content:** Auto-title (truncated first message) in SF Pro 15pt, relative timestamp in 12pt trailing, chevron indicator. One line each.
- **Dismiss:** Tap X button in history header, or tap the clock icon again, or select a conversation.
- **Animation:** Spring with 0.3s duration for toggle transitions.
- **New chat:** Just type in the text field. No separate "New Chat" button needed.
- **Deletion:** Swipe-to-delete on history rows, consistent with Library pattern.

## Parameter Settings (Phase 5)
Accessible from gear icon in chat nav bar. Per-model settings.

- **Background:** MeshGradient (consistent with rest of app)
- **Sections:** Glass-material section backgrounds with uppercase 12pt semibold tracking labels
- **Presets:** Three horizontal capsule pills — "Precise" / "Balanced" / "Creative". Selected: `#8B7CF0` fill. Unselected: `#302E42` border. Tapping snaps sliders to preset values.
- **Advanced section:** Collapsed by default with chevron disclosure. Opens to show temperature (0.0-2.0) and top-p (0.0-1.0) sliders.
- **Sliders:** SwiftUI native with `#8B7CF0` tint. Label left, SF Mono value right. Min/max endpoint labels in `#6B6980`.
- **System prompt:** Multi-line text field with glass background. Preset chips above ("Helpful assistant", "Creative writer", "Code helper", "Tutor") that populate the field on tap.
- **Scope:** Per-model. Each model stores its own temperature, top-p, and system prompt.

## Welcome Screen (Phase 5)
First-launch only. Poster layout on full MeshGradient.

- **Background:** Full MeshGradient with no cards or overlays. The gradient breathes completely.
- **Content:** Centered vertically. App icon placeholder (80pt rounded rect, `#8B7CF0` at 15% opacity, `cpu` SF Symbol). "ModelRunner" in SF Pro 28pt bold. "Run AI on your iPhone" in 20pt semibold. Subtitle in 15pt secondary.
- **Two buttons:** Stacked vertically, full-width, 16pt horizontal margins.
  - "Show Me Around" — `#8B7CF0` filled, 14pt corner radius. Starts guided download (auto-picks best model).
  - "Get Started" — Glass material, 14pt corner radius. Skips to Browse tab.
- **No decoration.** No illustration, no emoji. The gradient is the visual. The copy is the hook.

## Design Playgrounds

Working SwiftUI playground files for visual reference and iteration:

| Playground | Covers | Key Surfaces |
|-----------|--------|-------------|
| `MeshGradientPreview.playground` | Phase 2 | MeshGradient background, browse cards, search bar, tok/s badges |
| `ChatLibraryPreview.playground` | Phase 3 + 4 | Chat bubbles, library tab, download bar, model loading, tab bar |
| `Phase5Preview.playground` | Phase 5 | Conversation history overlay, parameter settings, welcome screen |

Swap the `setLiveView()` call at the bottom of each playground's `Contents.swift` to preview different screens.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-09 | MeshGradient background | Gives personality without decoration. Sapphire/violet/teal at dark spectrum. |
| 2026-04-09 | Dark-only, no light mode | Category convention, easier on eyes for long inference sessions |
| 2026-04-09 | SF Mono for data values only | Precision feel without terminal aesthetic |
| 2026-04-09 | No model thumbnails | Tok/s badge is the visual anchor. Cleaner, faster loading. |
| 2026-04-09 | Solid dark cards (#0D0C18) | Consistent contrast, gradient shows between cards not through them |
| 2026-04-09 | Warm violet accent (#8B7CF0) | Distinguishes from every other dark-blue dev tool |
| 2026-04-09 | Playground-first design iteration | SwiftUI playground doubles as working view code |
| 2026-04-09 | 3-tab navigation (Browse/Library/Chat) | Clean separation: discover, manage, use |
| 2026-04-09 | Persistent download bar above tab bar | Visible across all screens, compact 52pt, circular progress ring |
| 2026-04-09 | Violet user bubbles (#8B7CF0) | Brand-colored, asymmetric corner radius for tail effect |
| 2026-04-09 | Gradient shows through chat | MeshGradient breathes between bubbles — no flat chat background |
| 2026-04-09 | Active model left-edge accent bar | 3pt violet bar instead of checkmark — visual pop without clutter |
| 2026-04-09 | Amber stop button during generation | Clear differentiation from send button, matches amber "runs slowly" semantic |
| 2026-04-09 | ChatLibraryPreview.playground | Phase 3+4 design playground with chat, library, loading, tab bar |
| 2026-04-09 | Glass material for navigational surfaces | 60% opacity differentiates from solid data cards |
| 2026-04-09 | Bottom-anchored history overlay | History grows upward from input bar, not top-down. Chat-first tab. |
| 2026-04-09 | Clock toggle for history | Glass button beside text field, no separate history page |
| 2026-04-09 | Preset pills for inference params | Precise/Balanced/Creative snap sliders to values |
| 2026-04-09 | Per-model parameter settings | Each model stores own temperature, top-p, system prompt |
| 2026-04-09 | Welcome screen as poster | Full gradient, two paths (guided vs skip), zero decoration |
| 2026-04-09 | Phase5Preview.playground | Phase 5 design playground with history, settings, welcome |
