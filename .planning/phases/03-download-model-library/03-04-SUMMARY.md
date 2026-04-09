---
phase: 03-download-model-library
plan: "04"
subsystem: Library UI
tags: [swiftui, swiftdata, library, active-model, delete]
dependency_graph:
  requires: [03-01, 03-03]
  provides: [library-tab-ui, library-service, library-model-card]
  affects: [phase-04-inference]
tech_stack:
  added: []
  patterns: [swiftdata-query, mainactor-service, swipe-actions, confirmation-dialog]
key_files:
  created:
    - ModelRunner/Services/Library/LibraryService.swift
    - ModelRunner/Views/Library/LibraryModelCard.swift
  modified:
    - ModelRunner/Views/Library/LibraryView.swift
    - ModelRunnerTests/ModelLibraryTests.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - "availableStorage on DeviceCapabilityService is async throws (actor property) — use try? await in .task modifier"
  - "Added Foundation import to ModelLibraryTests for UserDefaults/Data access in test scope"
metrics:
  duration: 456s
  completed: "2026-04-09"
  tasks: 4
  files: 5
requirements:
  - DLST-03
  - DLST-04
  - DLST-05
---

# Phase 03 Plan 04: Library Tab UI Summary

**One-liner:** Full Library tab with @Query-sorted model list, swipe-to-delete with confirmation, tap-to-activate (single active model enforcement on @MainActor), and storage summary header.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create LibraryService | 6d6d5ba | ModelRunner/Services/Library/LibraryService.swift |
| 2 | Create LibraryModelCard | a0c315a | ModelRunner/Views/Library/LibraryModelCard.swift |
| 3 | Implement LibraryView | f60189e | ModelRunner/Views/Library/LibraryView.swift, project.pbxproj |
| 4 | Replace ModelLibraryTests stubs | 8511a00 | ModelRunnerTests/ModelLibraryTests.swift |

## What Was Built

**LibraryService** (`@MainActor` class):
- `setActiveModel(_:in:context:)` — deactivates all models first, then sets target active (P-06 atomic guarantee)
- `toggleActive(_:in:context:)` — used by Library tap gesture; deactivates if already active
- `deleteModel(_:context:)` — removes GGUF file via FileManager, clears UserDefaults resume key, deletes SwiftData record
- Storage aggregation: `totalStorageUsed`, `formattedTotalStorage`, `formattedFreeStorage`

**LibraryModelCard** (SwiftUI row view):
- Shows: model name, `QuantizationBadge` pill, formattedSize, relativeLastUsed, conversationCount
- Active model shows `checkmark.circle.fill` (green), inactive shows empty circle (D-10)

**LibraryView** (full implementation replacing Plan 01 stub):
- `@Query(sort: \DownloadedModel.lastUsedDate, order: .reverse)` — live SwiftData list (D-08)
- Swipe-to-delete with `confirmationDialog` showing model name and size freed (D-09)
- `EditButton` for bulk delete mode via `onDelete`
- Tap row calls `LibraryService.toggleActive` (DLST-05)
- Storage summary header: model count, total GB used, free GB (D-13)
- Empty state with `internaldrive` icon

**ModelLibraryTests** (10 real tests, all passing):
- In-memory SwiftData container for isolation
- Persistence, formattedSize, relativeLastUsed, setActiveModel, deleteModel, storage totals

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing Foundation import in ModelLibraryTests**
- **Found during:** Task 4 test run
- **Issue:** `UserDefaults` and `Data` not in scope without Foundation import
- **Fix:** Added `import Foundation` to ModelLibraryTests.swift
- **Files modified:** ModelRunnerTests/ModelLibraryTests.swift
- **Commit:** 8511a00

**2. [Rule 3 - Blocking] New files not registered in Xcode project**
- **Found during:** Task 3 build verification
- **Issue:** LibraryModelCard.swift and LibraryService.swift compiled but not in pbxproj — "cannot find in scope" build errors
- **Fix:** Added PBXBuildFile, PBXFileReference, PBXGroup (Services/Library), and Sources build phase entries
- **Files modified:** ModelRunner.xcodeproj/project.pbxproj
- **Commit:** f60189e

**3. [Rule 1 - Bug] availableStorage is async throws, not just async**
- **Found during:** Task 3 implementation
- **Issue:** Plan's code used `await container.deviceService.availableStorage` but the actor property is `async throws`
- **Fix:** Changed to `Int64((try? await container.deviceService.availableStorage) ?? 0)` in both `.task` and `performDelete`
- **Files modified:** ModelRunner/Views/Library/LibraryView.swift
- **Commit:** f60189e

## Verification

- Build: `xcodebuild build -scheme ModelRunner` — SUCCEEDED
- Tests: `xcodebuild test -scheme ModelRunnerTests -only-testing:ModelRunnerTests/ModelLibraryTests` — 10/10 PASSED
- All acceptance criteria grep checks pass

## Self-Check: PASSED
