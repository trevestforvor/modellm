---
phase: 03
slug: download-model-library
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 03 — Validation Strategy

## Test Infrastructure

| Component | Location | Purpose |
|-----------|----------|---------|
| `ModelRunnerTests/DownloadServiceTests.swift` | Unit tests | DownloadService actor logic, state machine transitions |
| `ModelRunnerTests/ModelLibraryTests.swift` | Unit tests | SwiftData DownloadedModel CRUD, delete-and-purge logic |
| `ModelRunnerTests/StorageGuardTests.swift` | Unit tests | Pre-download storage check logic |
| `ModelRunnerTests/DownloadURLTests.swift` | Unit tests | HF URL construction, auth header injection |
| Physical device | Manual | Background session continuity (simulator cannot replicate) |

Swift Testing framework (`import Testing`) — already established in Phase 1.

## Sampling Rate

**Target:** No 3 consecutive tasks without an automated verify step.

**Latency budget:** Build+test cycle < 90s on-device, < 45s simulator.

## Per-Task Verification Map

| Plan | Task | Verify Type | Command / Method |
|------|------|-------------|-----------------|
| 03-01 | T1: DownloadedModel SwiftData schema | automated | `grep "@Model" ModelRunner/Models/DownloadedModel.swift` |
| 03-01 | T2: ModelContainer setup in App entry | automated | `grep "ModelContainer" ModelRunner/App/ModelRunnerApp.swift` |
| 03-01 | T3: DownloadService actor stub | automated | `grep "actor DownloadService" ModelRunner/Services/Download/DownloadService.swift` |
| 03-01 | T4: AppContainer wired | automated | `grep "downloadService\|modelLibrary" ModelRunner/App/AppContainer.swift` |
| 03-02 | T1: Background URLSession configuration | automated | `grep "URLSessionConfiguration.background" ModelRunner/Services/Download/DownloadService.swift` |
| 03-02 | T2: handleEventsForBackgroundURLSession | automated | `grep "handleEventsForBackgroundURLSession" ModelRunner/App/ModelRunnerApp.swift` |
| 03-02 | T3: DownloadTask creation + resume | automated | `grep "downloadTask\|cancelByProducingResumeData" ModelRunner/Services/Download/DownloadService.swift` |
| 03-02 | T4: Progress delegate + Foundation.Progress | automated | `grep "Foundation.Progress\|completedUnitCount\|throughput" ModelRunner/Services/Download/DownloadService.swift` |
| 03-02 | T5: File finalization + iCloud exclusion | automated | `grep "isExcludedFromBackup\|moveItem" ModelRunner/Services/Download/DownloadService.swift` |
| 03-02 | T6: Cancel + resume data persistence | automated | `grep "cancelByProducingResumeData\|resumeData" ModelRunner/Services/Download/DownloadService.swift` |
| 03-03 | T1: NWPathMonitor cellular detection | automated | `grep "NWPathMonitor\|usesInterfaceType(.cellular)" ModelRunner/Services/Download/DownloadService.swift` |
| 03-03 | T2: Pre-download storage check | automated | `grep "availableStorage\|fileSizeBytes" ModelRunner/Services/Download/DownloadService.swift` |
| 03-03 | T3: DownloadProgressBar overlay | automated | `grep "DownloadProgressBar\|isActive" ModelRunner/Views/Download/DownloadProgressBar.swift` |
| 03-03 | T4: Tab bar integration | automated | `grep "LibraryView\|BrowseView" ModelRunner/ContentView.swift` |
| 03-04 | T1: LibraryView list | automated | `grep "LibraryView\|DownloadedModel\|@Query" ModelRunner/Views/Library/LibraryView.swift` |
| 03-04 | T2: Library card subview | automated | `grep "LibraryModelCard\|lastUsedDate\|conversationCount" ModelRunner/Views/Library/LibraryModelCard.swift` |
| 03-04 | T3: Swipe-to-delete + bulk edit | automated | `grep "swipeActions\|EditButton\|onDelete" ModelRunner/Views/Library/LibraryView.swift` |
| 03-04 | T4: Active model selection | automated | `grep "isActive\|activeModel\|checkmark" ModelRunner/Views/Library/LibraryView.swift` |
| 03-04 | T5: Storage summary header | automated | `grep "storageUsed\|freeStorage" ModelRunner/Views/Library/LibraryView.swift` |

## Wave 0 Requirements

- [ ] `ModelRunnerTests/DownloadServiceTests.swift` — stub tests for DLST-01, DLST-02, DLST-03
- [ ] `ModelRunnerTests/ModelLibraryTests.swift` — stub tests for DLST-04, DLST-05
- [ ] `ModelRunnerTests/StorageGuardTests.swift` — stub tests for storage guard logic

*Existing test infrastructure (Swift Testing, xcodebuild) from Phase 1 covers the runner.*

## Manual-Only Verifications

| ID | Test | Requirement |
|----|------|-------------|
| V-01 | Start download, press Home, wait 30s, return — progress continued | DLST-02 |
| V-02 | Kill app during download, relaunch — download resumes from correct offset | DLST-02 |
| V-03 | Fill device storage, attempt download — blocked with specific error message | DLST-03 |
| V-04 | On cellular, tap Download — cellular warning alert appears before task starts | DLST-01 |
| V-05 | Force-quit app after download completes, relaunch — model appears in Library | DLST-04 |
| V-06 | Swipe-delete a model — file removed from disk, storage freed | DLST-05 |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
