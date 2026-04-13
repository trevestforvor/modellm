---
status: testing
phase: 02-hf-browse-compatibility-ui
source:
  - 02-01-SUMMARY.md
  - 02-02-SUMMARY.md
  - 02-03-SUMMARY.md
started: "2026-04-09T12:05:00.000Z"
updated: "2026-04-09T12:05:00.000Z"
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

number: 1
name: App Launches with Browse Tab
expected: |
  Build and run the app in the iOS Simulator (iPhone 17 Pro or similar).
  The app should launch directly to the Browse tab, showing a dark mesh-gradient
  background (deep dark purple/blue gradient). A tab bar at the bottom shows three
  tabs: Browse (grid icon), Library (tray icon), Chat (bubble icon).
  The Browse tab should be selected by default.
awaiting: user response

## Tests

### 1. App Launches with Browse Tab
expected: |
  Build and run the app in the iOS Simulator (iPhone 17 Pro or similar).
  The app should launch directly to the Browse tab, showing a dark mesh-gradient
  background (deep dark purple/blue gradient). A tab bar at the bottom shows three
  tabs: Browse (grid icon), Library (tray icon), Chat (bubble icon).
  The Browse tab should be selected by default.
result: [pending]

### 2. Recommendations Section Loads
expected: |
  Within a few seconds of launch, a "Recommended for Your Device" section
  appears at the top of the Browse screen with horizontally scrollable model
  cards. You should see up to 5 model cards you can swipe through.
  If no network available, the section should be hidden (no error shown in the
  recommendations area).
result: [pending]

### 3. Model Card Appearance
expected: |
  Each model card has a dark (#0D0C18) background with rounded corners.
  It shows:
  - Model name (bold, white/light text) — truncated to one line
  - A metadata row in secondary gray: e.g. "8B · Q4_K_M · 4.6 GB · 124.3K downloads"
  - A tok/s pill badge on the right: either green ("~25 tok/s") or amber ("~7 tok/s")
    in a capsule shape with colored text and lightly tinted background
result: [pending]

### 4. All Models List and Search
expected: |
  Below the recommendations, an "All Models" section shows a vertical list of
  model cards. Each card has the same styling as the recommendations cards.
  Tapping the search bar (or using the searchable interface at top) and typing
  a model name (e.g. "llama") should update the list to show matching results.
  The recommendations section disappears while searching — only search results show.
result: [pending]

### 5. Tap Card Pushes Detail View
expected: |
  Tapping any model card navigates (push animation, not a sheet) to the model
  detail view. The detail view shows:
  - Navigation title with the model name (inline style)
  - A "Variants" section listing all GGUF files for this model
  - Each variant row shows: quantization type (left), file size in monospaced
    font (center), tok/s badge (right)
  - A storage impact line: "Uses X.X GB · You have Y.Y GB free"
  Back button returns to browse list.
result: [pending]

### 6. Download Button Disabled
expected: |
  At the bottom of the model detail view, a "Download · Coming Soon" button
  is visible but disabled (grayed out / reduced opacity). Tapping it does nothing.
  There should also be a link icon in the toolbar that opens the model's Hugging
  Face page.
result: [pending]

### 7. Library and Chat Placeholder Tabs
expected: |
  Tapping the Library tab shows a dark background with a tray icon and text:
  "Library" and "Download models to see them here".
  Tapping the Chat tab shows a dark background with a bubble icon and text:
  "Chat" and "Download a model to start chatting".
  Both are clearly placeholder views, not functional.
result: [pending]

### 8. Compatibility Filtering (Incompatible Models Hidden)
expected: |
  Models in the browse list and recommendations should all have either a green
  or amber tok/s badge — no model without a badge should appear in the list
  (incompatible models are silently filtered). This is hard to directly verify
  unless you know of a model that exceeds device RAM limits, but the observable
  check is: every visible model card has a tok/s badge.
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0

## Gaps

[none yet]
