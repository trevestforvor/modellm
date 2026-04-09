---
phase: 03-download-model-library
plan: 03
subsystem: download
tags: [download, cellular, storage, ui, progress-bar, guardrails]
dependency_graph:
  requires: [03-02]
  provides: [DownloadProgressBar, beginDownload, preDownloadStorageCheck, isOnCellular]
  affects: [ContentView, DownloadService]
tech_stack:
  added: [Network framework (NWPathMonitor)]
  patterns: [safeAreaInset persistent overlay, one-shot NWPathMonitor, actor async-throws property access]
key_files:
  created:
    - ModelRunner/Views/Download/DownloadProgressBar.swift
  modified:
    - ModelRunner/Services/Download/DownloadService.swift
    - ModelRunner/ContentView.swift
    - ModelRunnerTests/StorageGuardTests.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - availableStorage is async throws on actor — preDownloadStorageCheck must use try await
  - Color.accentColor is the correct ShapeStyle on iOS; .accent is not a valid ShapeStyle member
  - Preserved Chat tab and tab appearance customization in ContentView when wiring DownloadProgressBar
metrics:
  duration_seconds: 433
  completed_date: "2026-04-09"
  tasks_completed: 4
  files_changed: 5
requirements_satisfied: [DLST-01]
---

# Phase 03 Plan 03: Download Safety Guardrails + Progress Bar Summary

**One-liner:** NWPathMonitor cellular warning, 1GB storage buffer hard-block, and persistent 64pt DownloadProgressBar overlay wired via safeAreaInset across all tabs.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | NWPathMonitor cellular check in DownloadService | 530c8f7 | DownloadService.swift |
| 2 | Create DownloadProgressBar view | 3cd2c74 | DownloadProgressBar.swift, project.pbxproj |
| 3 | Wire DownloadProgressBar into ContentView | 775f193 | ContentView.swift |
| 4 | Replace StorageGuard test stubs with real tests | eb33231 | StorageGuardTests.swift, DownloadService.swift, DownloadProgressBar.swift |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] DeviceCapabilityService.availableStorage is async throws — must use try await**
- **Found during:** Task 4 (build verification)
- **Issue:** `preDownloadStorageCheck` used `await deviceService.availableStorage` but `availableStorage` is a computed property declared `get async throws` on the actor — missing `try`
- **Fix:** Changed to `try await deviceService.availableStorage`
- **Files modified:** ModelRunner/Services/Download/DownloadService.swift
- **Commit:** eb33231

**2. [Rule 1 - Bug] `.accent` is not a valid SwiftUI ShapeStyle**
- **Found during:** Task 4 (build verification)
- **Issue:** DownloadProgressBar used `.accent` in `foregroundStyle()` and `tint()` — not a valid member of ShapeStyle on iOS 17+
- **Fix:** Replaced with `Color.accentColor` which correctly resolves to the app's accent color
- **Files modified:** ModelRunner/Views/Download/DownloadProgressBar.swift
- **Commit:** eb33231

**3. [Non-deviation] ContentView Chat tab preserved**
- The plan's replacement template omitted the Chat tab, but the existing ContentView had a Chat placeholder tab with appearance customization. Preserved the existing tab structure and only replaced the safeAreaInset EmptyView stub with DownloadProgressBar. This is correct behavior — the plan's template was illustrative, not prescriptive.

## Success Criteria Verification

1. Build succeeds: xcodebuild exits 0 — PASSED
2. StorageGuard tests: all 4 pass — PASSED
3. NWPathMonitor present in DownloadService: grep exits 0 — PASSED
4. 1_073_741_824 buffer constant present: grep exits 0 — PASSED
5. struct DownloadProgressBar exists: grep exits 0 — PASSED
6. downloadService.state.isActive wired: grep exits 0 — PASSED
7. Manual V-04 (cellular alert): requires physical device — deferred to manual QA

## Known Stubs

None — all implementation is wired and functional.

## Self-Check: PASSED
