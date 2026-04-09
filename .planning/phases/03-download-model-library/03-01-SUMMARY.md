---
phase: 03-download-model-library
plan: "01"
subsystem: download-foundation
tags: [swiftdata, download, scaffolding, wave-0]
dependency_graph:
  requires: []
  provides:
    - DownloadedModel @Model schema (Plans 02/03/04 build against this)
    - DownloadService actor stub (Plans 02/03 implement the body)
    - AppContainer.shared singleton (AppDelegate background session reconnect)
    - ModelContainer wiring at app entry point
    - LibraryView stub (Plan 04 implements)
    - Wave 0 RED test stubs for DLST-01 through DLST-05
  affects:
    - ModelRunnerApp.swift (AppDelegate + ModelContainer added)
    - AppContainer.swift (shared singleton + downloadService)
    - ContentView.swift (LibraryView tab, safeAreaInset placeholder)
tech_stack:
  added:
    - SwiftData (ModelContainer, @Model, @Attribute(.unique))
    - UIApplicationDelegate (AppDelegate for background URLSession lifecycle)
  patterns:
    - Singleton AppContainer.shared for cross-boundary actor access
    - Wave 0 stubs with Issue.record() for RED test state
key_files:
  created:
    - ModelRunner/Models/DownloadedModel.swift
    - ModelRunner/Models/DownloadState.swift
    - ModelRunner/Services/Download/DownloadService.swift
    - ModelRunner/Views/Library/LibraryView.swift
    - ModelRunnerTests/DownloadServiceTests.swift
    - ModelRunnerTests/ModelLibraryTests.swift
    - ModelRunnerTests/StorageGuardTests.swift
  modified:
    - ModelRunner/App/ModelRunnerApp.swift
    - ModelRunner/App/AppContainer.swift
    - ModelRunner/ContentView.swift
    - ModelRunner/Features/Browse/BrowseView.swift
    - ModelRunner.xcodeproj/project.pbxproj
decisions:
  - "AppContainer uses private init() + static shared to prevent accidental dual instantiation"
  - "DownloadState stored as enum (not in SwiftData) — progress state is transient, not persisted"
  - "quantization stored as String in DownloadedModel (not QuantizationType enum) for SwiftData Codable compatibility"
  - "LibraryView replaces inline libraryPlaceholder in ContentView to enable Plan 04 expansion"
metrics:
  duration_seconds: 425
  completed_date: "2026-04-09"
  tasks_completed: 6
  files_changed: 11
---

# Phase 03 Plan 01: Wave 0 Foundation — SwiftData Schema, ModelContainer, Tab Scaffold Summary

**One-liner:** SwiftData DownloadedModel schema + DownloadService actor stub + ModelContainer wiring + LibraryView tab scaffold + Wave 0 RED test stubs covering DLST-01 through DLST-05.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create DownloadedModel SwiftData schema | 24918db | DownloadedModel.swift, DownloadState.swift |
| 2 | Create DownloadService actor stub | 51d2e2f | DownloadService.swift |
| 3 | Wire ModelContainer and AppDelegate into ModelRunnerApp | 7e37768 | ModelRunnerApp.swift |
| 4 | Extend AppContainer with DownloadService and shared singleton | 34c7512 | AppContainer.swift |
| 5 | Update ContentView with tab navigation (Browse/Library) | 80ec5a7 | ContentView.swift, LibraryView.swift |
| 6 | Create Wave 0 test stubs for DLST-01 through DLST-05 | 95db10f | DownloadServiceTests.swift, ModelLibraryTests.swift, StorageGuardTests.swift |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Xcode project registration missing for all new files**
- **Found during:** Post-task verification (build attempt)
- **Issue:** Swift files added to disk are not automatically included in the Xcode target — project.pbxproj must list them in PBXBuildFile, PBXFileReference, PBXGroup, and PBXSourcesBuildPhase
- **Fix:** Added all 7 new files to project.pbxproj with proper UUIDs and group hierarchy (Models, Views/Library, Services/Download)
- **Files modified:** ModelRunner.xcodeproj/project.pbxproj
- **Commit:** 1b987ee

**2. [Rule 1 - Bug] BrowseView #Preview uses AppContainer() — now inaccessible after private init**
- **Found during:** First build attempt after Task 4
- **Issue:** `AppContainer.init()` was made private (singleton pattern), breaking BrowseView's `#Preview { BrowseView().environment(AppContainer()) }`
- **Fix:** Changed to `AppContainer.shared`
- **Files modified:** ModelRunner/Features/Browse/BrowseView.swift
- **Commit:** 1b987ee

## Known Stubs

| File | Stub | Reason |
|------|------|--------|
| ModelRunner/Views/Library/LibraryView.swift | Text("Library coming in Plan 04") style placeholder | Plan 04 implements full library UI |
| ModelRunner/Services/Download/DownloadService.swift | All methods throw .notImplemented | Plan 02 implements background URLSession download |
| ContentView.swift | `EmptyView()` in safeAreaInset | Plan 03 adds DownloadProgressBar |
| ModelRunnerTests/DownloadServiceTests.swift | 6 of 8 tests use Issue.record() | Plans 02/03 implement real assertions |
| ModelRunnerTests/ModelLibraryTests.swift | 6 of 7 tests use Issue.record() | Plan 04 implements real assertions |
| ModelRunnerTests/StorageGuardTests.swift | 2 of 3 tests use Issue.record() | Plan 03 implements real assertions |

Note: All stubs are intentional Wave 0 RED state — the plan goal (foundation for Plans 02-04) is achieved. Two real assertions exist: `testFormattedSizeGigabytes` and `testInsufficientStorageErrorCarriesValues`.

## Self-Check: PASSED

- [x] ModelRunner/Models/DownloadedModel.swift exists
- [x] ModelRunner/Models/DownloadState.swift exists
- [x] ModelRunner/Services/Download/DownloadService.swift exists
- [x] ModelRunner/Views/Library/LibraryView.swift exists
- [x] ModelRunnerTests/DownloadServiceTests.swift exists
- [x] ModelRunnerTests/ModelLibraryTests.swift exists
- [x] ModelRunnerTests/StorageGuardTests.swift exists
- [x] BUILD SUCCEEDED (xcodebuild exits 0)
- [x] All 7 commits verified in git log
