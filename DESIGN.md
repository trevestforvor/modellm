# Design System — ModelRunner

> Source of truth for the visual language, motion, typography, and accessibility rules of the ModelRunner iOS app. If it's in code and not in this doc, either this doc is stale or the code is drifting.

## Product Context

- **What this is:** iOS app for browsing Hugging Face models, verifying device compatibility, downloading, and running LLM inference on-device. Also connects to remote OpenAI/Anthropic-compatible endpoints.
- **Who it's for:** People who want to run or test AI models locally on their iPhone — developers, hobbyists, privacy-minded users.
- **Space/category:** On-device AI tools (PocketPal AI, LLMFarm, Locally AI, Google AI Edge Gallery).
- **Positioning:** Hybrid of "chat app" and "developer tool." Lean **70% dev-tool, 30% chat**: technical metadata visible, minimal decoration, accent used sparingly — not consumer-messaging-app cheerful.
- **Platform:** Native iOS 17+ (SwiftUI, iPhone-first).

## Aesthetic Direction

- **Direction:** Industrial-precision with atmosphere.
- **Decoration level:** Intentional only. The MeshGradient and a single radial glow carry all the personality; everything else is restrained.
- **Mood:** Confident dark instrument that knows your device. Not a terminal, not a toy. **Approachable precision.**
- **References:** Claude iOS, ChatGPT iOS, Linear iOS, Craft — serious tools that use dark indigo/violet sparingly. Avoid consumer chat (Telegram, Messages) or AI-art (Midjourney, Runway) aesthetics.

## Background — MeshGradient

A 3x3 SwiftUI `MeshGradient` (iOS 18+) is the app's signature surface. Content sits directly on it. Cards and the chat input bar blend into near-black at the bottom so the gradient "breathes" only where it should.

```
Top row     #1E2A78 (deep indigo) → #2B2180 (toned violet) → #1C3F7A (blue push)
Mid (0.58)  #1A1F4D (blue-violet) → #221B5C (mid violet)   → #162A52 (deep cobalt)
Bottom row  #0B0C1A (near-black)  → #080913 (near-black)   → #0A0E1F (near-black)
```

**Rules:**
- Middle row points shifted down to `y = 0.58` so the top has more visual weight.
- Soft RadialGradient overlay (color `#6C5CFF` at 0.10 opacity, top-leading, 500pt radius, `.plusLighter` blend) adds a single subtle glow.
- Bottom row must remain dark enough that the input bar blends in — never brighten below `y = 0.70`.
- No pure `#000000` ever. Deepest black is `#0D0C18` (cards, input bar) and `#080913` (gradient bottom-center).
- **Accessibility:** If `@Environment(\.accessibilityReduceMotion) == true`, the radial glow overlay is dropped and any future gradient animation is disabled.

## Typography

Three Apple-shipped families used by role. **No custom bundled fonts.**

| Role | Font | Apple Design | Usage |
|------|------|--------------|-------|
| Primary UI | SF Pro (default) | `.default` | Everything not covered below — body text, buttons, labels, toolbar icons |
| Brand / editorial | New York | `.serif` | Toolbar model-name title, `ChatEmptyState` hero, section dividers you want to feel "stated not shouted" |
| Data / metadata | SF Mono | `.monospaced` | tok/s badge, model quantization tag, file sizes, timestamps, anything numeric/technical |

**Never use `.rounded` design.** It reads as friendly/consumer; opposite of the brand. Removed site-wide.

**Sizing:** Prefer semantic styles (`.body`, `.headline`, `.callout`, `.footnote`, `.caption`, `.caption2`) over fixed points for Dynamic Type support. Explicit points are OK for toolbar chrome, badges, and layout-sensitive data labels — but they should still pass largest-text rendering without truncation.

| Style | Default pt | Used for |
|-------|-----------|----------|
| `.largeTitle` (New York) | 34 | Empty-state hero only |
| `.title2` (New York) | 22 | Toolbar model name |
| `.headline` (SF Pro) | 17 semibold | Section labels inside sheets |
| `.body` (SF Pro) | 17 regular | Message text, descriptions |
| `.callout` (SF Pro) | 16 | Chat input text |
| `.footnote` (SF Pro) | 13 | Card subtitles, secondary text |
| `.caption` (SF Mono) | 12 semibold | tok/s badge, file size, quant label |
| `.caption2` (SF Mono) | 11 | Timestamps, tertiary metadata |

## Color

Dark-only. No light mode for v1. All colors are in the `Color(hex:)` helper until a named `Palette` module ships.

| Token | Hex / Expression | Use |
|-------|------------------|-----|
| `bg-deep` | `#0D0C18` | Solid card surface, input bar, sheet background |
| `bg-card-elevated` | `#1A1830` | Glass surface base (used at 0.6 opacity for translucency) |
| `fg-primary` | `#EDEDF4` (or `.white`) | Primary readable text |
| `fg-secondary` | `#9896B0` | Secondary/subtitle text, toolbar icon default |
| `fg-muted` | `#6B6980` | Placeholder, tertiary labels |
| `accent` | `#8B7CF0` → shifting to `#7C7BF5` | User bubbles, send button, active states, selection |
| `accent-glow` | `#6C5CFF` at 0.10 | MeshGradient radial overlay only |
| `success` | `#34D399` | "Runs Well" tok/s badges, success toasts |
| `warn` | `#FBBF24` | "Runs Slowly" tok/s badges, stop button background (amber reads as interruption, not error) |
| `error` | `#ef4444` | Destructive actions, error states |
| `border-hairline` | `Color.white.opacity(0.08)` | Card borders, glass outlines, input field strokes |
| `border-divider` | `#302E42` | Standalone horizontal section rules only |

**Rules:**
- Never use `.black` as a foreground on dark surfaces. The only exception is `.black` on the amber stop-button circle (`#FBBF24`) — deliberate high-contrast pairing, verified.
- Never use `.gray` — it ignores the theme. Use `fg-secondary` or `fg-muted` instead.
- Borders: `border-hairline` for cards/glass (premium), `border-divider` for standalone dividers (utility). Don't mix.

## Spacing

Base unit: **8pt** (4pt for fine adjustments). Scale: `xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48)`.

- Card internal padding: 16pt
- Card gap: 8–10pt between cards
- Section header padding: 20pt top, 10pt bottom
- Horizontal screen margins: 16pt
- Safe-area insets respected everywhere; input bar extends background below safe area via `ignoresSafeArea(edges: .bottom)` so the home indicator zone blends in

## Motion

Adopted from "Modern Dark (Cinema Mobile)" recommendations.

| Token | Value | Usage |
|-------|-------|-------|
| `easing-expo-out` | `cubic-bezier(0.16, 1, 0.3, 1)` | Default for entrances and state changes |
| `spring-default` | `response: 0.35, dampingFraction: 0.8` (≈ iOS `.smooth`) | Layout/content springs |
| `spring-haptic` | damping 20, stiffness 90 | Button press + haptic-linked animations |
| `press-scale` | `0.97` on press → `1.0` on release | All tappable cards and icon buttons |
| `duration-micro` | 150–200ms | Icon state flip, color change |
| `duration-transition` | 250–350ms | Sheet present/dismiss, history toggle |
| `stagger` | 30–50ms between items | List/grid entrance |

**Rules:**
- Prefer `transform`/`opacity` only — never animate `width`/`height`/`top`/`left`.
- Exit faster than enter (~60–70% of enter duration).
- All animations must be interruptible — a user tap cancels in-flight animation.
- **Reduce Motion**: When `accessibilityReduceMotion == true`, drop press-scale, use `.linear` transitions, skip radial glow, no continuous loops.

## Haptics

iOS `UIImpactFeedbackGenerator`. Purpose-driven, never decorative.

| Action | Impact |
|--------|--------|
| Send message | `.light` |
| Stop generation | `.medium` |
| Delete / destructive | `.heavy` + `notificationOccurred(.warning)` |
| Copy / success | `notificationOccurred(.success)` |
| Model selection change | `.soft` |

Never haptic on scroll, tab, or focus transitions.

## Iconography

- **System:** SF Symbols exclusively — no custom icon sets, no emojis as UI elements.
- **Weight:** `.medium` for toolbar icons, `.semibold` for emphasis, never `.bold`.
- **Decorative icons:** `.accessibilityHidden(true)`. Only interactive or informative icons get labels.

## Navigation Structure

Single-screen root — NOT a TabView. Decision: 2026-04-16.

- **Root:** `ChatRootView` wrapped in `NavigationStack`.
- **Toolbar (top):**
  - Leading: `gear` (Settings sheet) → `bubble.left` (conversation history overlay)
  - Principal: Model name button → opens `ModelsTabView` as a full-screen sheet
  - Trailing: `square.and.pencil` (new chat)
- **Model picker** is the full Models view presented as a sheet, not a separate tab.
- **History** is an inline ZStack overlay (not a sheet), bottom-anchored, springs up from the input bar.

## Accessibility

Required for every contributed view. Enforced in code review.

- **VoiceOver labels** on every icon-only button. If the purpose isn't self-evident from the label, add `.accessibilityHint(...)`.
- **Decorative icons, status dots, dividers:** `.accessibilityHidden(true)`.
- **Dynamic Type:** Prefer semantic Font styles. Pointed styles must be tested at `.accessibility3` / largest before shipping.
- **Reduce Motion:** See Motion section.
- **Live regions:** Streaming assistant text uses `.accessibilityAddTraits(.updatesFrequently)` and posts `UIAccessibility.Notification.announcement` at message complete.
- **Contrast:** All foreground/background pairs meet **WCAG AA 4.5:1** for body text and **3:1** for large/bold text. Never encode meaning in color alone — pair with icon or label.
- **Touch targets:** ≥44×44pt. Icon buttons use `.frame(width: 36, height: 36)` for visual but the tap target is extended via the padded parent hit region.

## Dark Mode Enforcement

- `INFOPLIST_KEY_UIUserInterfaceStyle = Dark` in both Debug and Release configs.
- `.preferredColorScheme(.dark)` on the root scene as belt-and-suspenders.
- No `@Environment(\.colorScheme)` branching in views — there is only dark.

## Chat UI

### Toolbar (covered in Navigation)

### Message List
- Assistant messages: **bubble-less**, left-aligned, plain text on the MeshGradient with 16pt horizontal padding. A small mono timestamp under each on hover/long-press optional.
- User messages: accent-filled bubble, right-aligned, **16pt corner radius** (not pill).
- Streaming message: live-region text + pulsing 2×16pt cursor in `accent`. tok/s badge pinned above input bar (not inside bubble).
- Generous vertical rhythm: 16pt between consecutive messages from same speaker; 24pt between speaker turns.

### Assistant Message Feedback
Below each **completed** assistant message, a subtle horizontal row of icon-only buttons:
- Thumbs up (`hand.thumbsup`) — "Good response"
- Thumbs down (`hand.thumbsdown`) — "Bad response"
- Copy (`doc.on.doc`) — copies the message text
- Regenerate (`arrow.counterclockwise`) — re-runs from previous user message

Icons `fg-muted` at rest, `accent` when selected/active. Feedback persists per-message in SwiftData.

### Input Bar
- Surface: solid `#0D0C18` with top hairline border. Extends below safe area via `ignoresSafeArea`.
- Controls, left to right: `+` attach menu, brain button, text field, send/stop.
- Send button: 34pt circle, `accent` filled; becomes amber `#FBBF24` stop-fill during generation.
- Text field: `#1A1830` fill, hairline white-0.08 border, 12pt corner radius.
- Attach menu (`Menu`) shows file/camera/photo options; photo actions disabled when active model's `supportsVision == false`.

### Empty State
- No models: `ChatEmptyState` — New York title, muted subtitle, accent "Browse models" button opening the Models sheet.
- Model loading: `ChatLoadingView` — progress ring in accent, mono sub-label showing the size loading into memory.

## Tok/s Badge (Signature Element)

Preserved from v1. Communicates compatibility and expected performance in one glance.

- Format: `~N tok/s` in SF Mono `.caption` semibold.
- Green `#34D399` on 12% green fill — "Runs Well"
- Amber `#FBBF24` on 12% amber fill — "Runs Slowly"
- Shape: Capsule. Padding: 10pt H / 4pt V.
- Position: card top-right OR pinned above input bar during streaming.

## Library Card (Models Sheet)

Kept from v1 layout.

```
┌───────────────────────────────────────────┐
│▌ Model Name (17pt semibold)   [ ~32 tok/s]│  ← accent left bar = active model
│▌ Q4_K_M (13pt secondary)                 │
│▌ 2.5 GB  ·  💬 14  ·  2 hours ago        │  ← SF Mono metadata
└───────────────────────────────────────────┘
```

- Background: `#0D0C18` solid
- Corner radius: 16pt
- Active indicator: 3pt `accent` bar on leading edge, full card height
- Inactive padding: 16pt H; active padding: 13pt H (bar + 13 = 16 visual total)
- Border: hairline white-0.08
- Swipe-to-delete (single), Edit → bulk

## Glass Material

Translucent surface for navigational/secondary elements. Differentiates from solid data cards.

- Fill: `#1A1830` at 0.6 opacity
- Border: hairline white-0.08
- Corner radius: 12pt
- Usage: conversation history rows, icon-button backgrounds (brain, attach), settings section backgrounds

## Per-Model Inference Settings

Preserved. Lives inside the Settings sheet (gear) as a NavigationLink when an active model exists.

- Preset pills: "Precise" / "Balanced" / "Creative" — snap temperature + top-p to values
- Advanced (collapsed): temperature 0.0–2.0, top-p 0.0–1.0 sliders
- System prompt: multi-line text field with glass surface; preset chips above ("Helpful assistant", "Creative writer", "Code helper", "Tutor")
- Scope: per-model (each `DownloadedModel` stores its own `temperature`, `topP`, `systemPrompt`)

## Model Name Formatting

Raw model strings like `"SmolLM2-360M-Instruct (Bundled) Q4_K_M"` get rendered human-friendly in the toolbar.

Algorithm (`ChatRootView.friendlyModelName`):
1. Drop anything inside parentheses.
2. Strip trailing `-Instruct`, `Instruct`, `-Chat`, `Chat`, `-it` (case-insensitive).
3. Replace remaining `-` with space.
4. Collapse whitespace.

Result: `"SmolLM2 360M"`.

## Vision Capability Detection

`DownloadedModel.supportsVision: Bool` populated via `VisionWhitelist.supportsVision(repoId:)` — case-insensitive substring match against known vision model families (`llava`, `llama-3.2-*-vision`, `qwen2-vl`, `phi-3-vision`, `moondream`, `internvl`, `minicpm-v`, etc.). Bundled models short-circuit to `false`. UI reveals/enables vision-specific attach actions based on this flag.

## Design Playgrounds (reference)

| Playground | Covers | Status |
|-----------|--------|--------|
| `MeshGradientPreview.playground` | Gradient iteration | Active — update when mesh colors change |
| `ChatLibraryPreview.playground` | Chat bubbles, library, download bar | Stale since single-screen refactor — update or drop |
| `Phase5Preview.playground` | History, settings | Stale since v1 — update or drop |

## Decisions Log

Append-only. Each entry includes date, decision, and rationale.

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-09 | MeshGradient background | Gives personality without decoration. Sapphire/violet/teal. |
| 2026-04-09 | Dark-only, no light mode | Category convention, easier on eyes for long inference sessions |
| 2026-04-09 | SF Mono for data values only | Precision feel without terminal aesthetic |
| 2026-04-09 | 3-tab navigation (Browse/Library/Chat) | Clean separation: discover, manage, use |
| 2026-04-09 | Violet user bubbles (#8B7CF0) | Brand-colored, asymmetric corner radius for tail effect |
| 2026-04-09 | Glass material for navigational surfaces | 60% opacity differentiates from solid data cards |
| 2026-04-09 | Per-model parameter settings | Each model stores own temperature, top-p, system prompt |
| 2026-04-09 | Welcome screen as poster | Full gradient, two paths (guided vs skip), zero decoration |
| 2026-04-16 | **Collapse tabs → single ChatRootView** | Reduces navigation overhead; model picker becomes a sheet. Chat is the root. |
| 2026-04-16 | **Drop WelcomeView entirely** | Bundled SmolLM2 auto-activates on first launch; onboarding was broken stubs anyway. |
| 2026-04-16 | **Attachment `+` menu always visible** | Text-file attachments always supported; vision actions disabled when model lacks support. Better discoverability than hiding. |
| 2026-04-16 | **Vision whitelist field on DownloadedModel** | Static substring match against known vision families. Simple, zero-cost at runtime. |
| 2026-04-16 | **Bundled SmolLM2-360M-Q8_0 (sim default)** | Lets the app work immediately post-install without forcing a download on simulator resets. Q8_0 because Q4_K_M produces gibberish at 360M. |
| 2026-04-16 | **MeshGradient re-colored toward indigo/blue** | Shifted cool, teal removed, bottom compressed to near-black so input bar blends in. |
| 2026-04-16 | **Radial glow overlay (top-leading, 0.10 opacity)** | Subtle ambient-light feel without competing with chat content. |
| 2026-04-17 | **Typography: SF Pro default + New York brand + SF Mono data** | `.rounded` was too friendly. New York reads editorial/smart for brand moments. |
| 2026-04-17 | **Hairline white-0.08 borders** | More premium than solid `#302E42` for card/glass outlines; solid reserved for standalone dividers. |
| 2026-04-17 | **Bubble radius 16 + bubble-less assistant** | Matches Claude/ChatGPT. Differentiates speakers without consumer-y pill shapes. |
| 2026-04-17 | **Assistant message feedback row** | Thumbs up/down + copy + regenerate. Table-stakes for serious AI tools. |
| 2026-04-17 | **`INFOPLIST_KEY_UIUserInterfaceStyle = Dark`** | Locks dark mode app-wide so any default `.primary`-styled text never renders black. |
| 2026-04-17 | **Motion tokens from Cinema Mobile pattern** | Expo.out easing + spring (20/90) + press-scale 0.97 + haptics — cohesive motion language. |

## Non-Goals (for v1)

- Light mode
- Custom bundled fonts (Inter, etc.) — defer unless SF Pro proves insufficient
- Full vision inference — UI stubs only; real LLaVA/mmproj integration is future work
- Suggested prompts on empty state
- Sharing, export, search across conversations
