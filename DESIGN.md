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
- **Potential future:** Subtle MeshGradient animation (slow-moving color flow), but not for v1

## Iconography
- **System:** SF Symbols exclusively
- **Style:** Monochrome, matching text color context
- **No custom icons for v1**

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
