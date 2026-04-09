# Phase 3: Download + Model Library - Research

**Phase:** 03-download-model-library
**Researched:** 2026-04-09
**Confidence:** HIGH — swift-huggingface 0.8.0 API verified from source + official blog; background URLSession patterns from Apple docs; SwiftData from official docs

---

## Summary

Phase 3 has three distinct technical domains:

1. **Download layer** — `HubClient.downloadFile()` drives the download with a `Progress` object. For a single GGUF file, use `downloadFile(at:from:to:progress:)`, not `downloadSnapshot`. Background URLSession requires a separate `URLSession` with `URLSessionConfiguration.background(withIdentifier:)`. The swift-huggingface client uses URLSession internally but does NOT use a background session — background download requires wrapping the download in a custom `URLSessionDownloadTask` that uses `background(withIdentifier:)` configuration.

2. **Storage metadata layer** — SwiftData `@Model` class tracks downloaded model state (path, size, last used, quantization, active status). Configured in AppContainer. `ModelContainer` setup at app entry point.

3. **Library UI** — `LibraryView` in a tab bar alongside `BrowseView`. Sorted by `lastUsedDate`. Swipe-to-delete with `FileManager.default.removeItem` plus SwiftData `modelContext.delete`. Header shows aggregated storage summary.

**Critical finding:** swift-huggingface's `downloadFile` / `downloadSnapshot` use an in-process URLSession, not a background session. To satisfy DLST-02 (downloads continue when backgrounded), you must implement a `DownloadService` actor that creates a `background(withIdentifier:)` URLSession, manages its own delegate, and coordinates with `handleEventsForBackgroundURLSession` in AppDelegate/SwiftUI `@UIApplicationDelegateAdaptor`. The swift-huggingface `HubCache` structure can still be used for file path resolution — download to the correct blob location manually.

---

## Standard Stack

### Core (Phase 3 scope)

| Component | Technology | Version | Notes |
|-----------|-----------|---------|-------|
| Download management | Custom `DownloadService` actor + `URLSessionConfiguration.background` | iOS 17+ | swift-huggingface download methods don't support background sessions — must wrap manually |
| File download API | `HubClient.downloadFile(at:from:to:progress:)` | swift-huggingface 0.8.0+ | For foreground-only path; background path uses raw URLSessionDownloadTask |
| Resume data | `URLSessionDownloadTask.cancelByProducingResumeData` + `URLSession.downloadTask(withResumeData:)` | Foundation | HF CDN supports byte-range resume via HTTP 206 |
| Cache structure | `HubCache.default` (`Library/Caches/huggingface/hub/` on iOS sandboxed apps) | swift-huggingface 0.8.0+ | Auto-detected for sandboxed iOS apps; use `HubCache.default.repoDirectory(repo:kind:)` for path construction |
| Model metadata persistence | `SwiftData @Model` | iOS 17+ | `DownloadedModel` @Model class with `@Attribute(.unique)` on repoId |
| Network type detection | `NWPathMonitor` (Network framework) | iOS 12+ | Check `path.usesInterfaceType(.cellular)` before download starts |
| iCloud backup exclusion | `URL.setResourceValues` with `URLResourceValues.isExcludedFromBackup = true` | Foundation | Apply after file is finalized in cache |
| Progress reporting | `Foundation.Progress` | Foundation | `fractionCompleted`, `completedUnitCount`, `totalUnitCount` — throughput via `throughput` property |
| Background re-connection | `handleEventsForBackgroundURLSession` | UIKit / SwiftUI `@UIApplicationDelegateAdaptor` | Required for iOS background download lifecycle |

### No Third-Party Libraries Needed

- Do NOT add Alamofire or any download manager library
- Do NOT add a separate progress tracking library — `Foundation.Progress` has `.throughput` (bytes/sec) built in
- Do NOT add a file watcher — SwiftData query updates are sufficient for UI reactivity

---

## Architecture Patterns

### 1. DownloadService Actor

```swift
actor DownloadService: NSObject {
    static let backgroundSessionIdentifier = "com.modelrunner.download"
    
    private var urlSession: URLSession!
    private var activeTask: URLSessionDownloadTask?
    private var resumeData: Data?
    
    // Published via @Observable wrapper (DownloadState)
    private(set) var state: DownloadState = .idle
    
    // Background session completion handler — stored from AppDelegate
    var backgroundCompletionHandler: (() -> Void)?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.background(
            withIdentifier: Self.backgroundSessionIdentifier
        )
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false  // NOT discretionary — user-initiated, not background fetch
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
}
```

Key design choices:
- `isDiscretionary = false` — user tapped Download; system must not defer it
- `sessionSendsLaunchEvents = true` — iOS re-launches app when download completes while backgrounded
- Actor isolation prevents data races on `activeTask` and `state`
- `backgroundCompletionHandler` handed off from `handleEventsForBackgroundURLSession`

### 2. Background Session Lifecycle

In `ModelRunnerApp.swift` (using `@UIApplicationDelegateAdaptor`):

```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // Must reconnect to DownloadService before calling completion
        // DownloadService is a singleton actor — reconnect triggers delegate events
        Task {
            await AppContainer.shared.downloadService.setBackgroundCompletionHandler(completionHandler)
        }
    }
}
```

In `DownloadService` delegate:

```swift
func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    Task { @MainActor in
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}
```

**Why this matters:** If you don't call the completion handler, iOS will not give your app more background time and system-level download UI won't update correctly. Missing this is the #1 background download bug.

### 3. HF Download URL Construction (not using swift-huggingface download methods)

Since we need a raw `URLSessionDownloadTask`, construct the download URL manually:

```swift
// HF CDN URL pattern for GGUF files (LFS)
// https://huggingface.co/<repo>/resolve/<revision>/<filename>
func ggufDownloadURL(repo: String, revision: String = "main", filename: String) -> URL {
    URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(filename)")!
}

// Add auth token if available (from Keychain — Phase 2 decision)
var request = URLRequest(url: ggufDownloadURL(repo: repoId, filename: ggufFilename))
if let token = keychainToken {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}

let task = urlSession.downloadTask(with: request)
task.resume()
```

**Why not swift-huggingface `downloadFile`?** The swift-huggingface client creates an ephemeral or default URLSession internally. Its download tasks cannot be a background session task. For GGUF files (2-4 GB), this means the download pauses the moment the app goes to background. Using a raw `URLSessionDownloadTask` on a background session is the correct pattern.

### 4. Progress Reporting (MB/s + ETA)

`Foundation.Progress` provides `throughput` (bytes/sec) and `estimatedTimeRemaining` when properly tracked:

```swift
// In URLSessionDownloadDelegate
func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
) {
    Task { @MainActor in
        downloadState.bytesWritten = totalBytesWritten
        downloadState.totalBytes = totalBytesExpectedToWrite
        // Foundation.Progress computes throughput automatically when 
        // completedUnitCount updates — use it
        progress.completedUnitCount = totalBytesWritten
        // throughput in bytes/sec: progress.throughput (non-nil after first few updates)
        // ETA in seconds: progress.estimatedTimeRemaining
    }
}
```

Display format:
- MB/s: `String(format: "%.1f MB/s", Double(throughput ?? 0) / 1_000_000)`
- ETA: `Duration.seconds(estimatedTimeRemaining ?? 0).formatted(.units(allowed: [.minutes, .seconds]))`

### 5. Cancel + Resume Flow

```swift
func cancelDownload() async {
    guard let task = activeTask else { return }
    let data = await task.cancelByProducingResumeData()
    resumeData = data  // persist to UserDefaults for crash recovery
    UserDefaults.standard.set(data, forKey: "resumeData_\(activeDownloadId ?? "")")
    state = .idle
}

func resumeOrStart(request: URLRequest) async {
    if let data = resumeData {
        activeTask = urlSession.downloadTask(withResumeData: data)
        resumeData = nil
    } else {
        activeTask = urlSession.downloadTask(with: request)
    }
    activeTask?.resume()
    state = .downloading(progress: progress)
}
```

**Pitfall:** Resume data becomes invalid if the server changes (different ETag/revision). Always validate the ETag from the HF API before attempting resume. If invalid, delete stored resume data and restart.

### 6. File Finalization After Download

```swift
func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
) {
    // Construct HubCache-compatible destination
    let destination = HubCache.default
        .repoDirectory(repo: repoId, kind: .model)
        .appending(components: "blobs", etag)
    
    do {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: location, to: destination)
        
        // Mark as excluded from iCloud backup
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try destination.setResourceValues(resourceValues)
        
        // Write SwiftData record on main actor
        Task { @MainActor in
            await recordDownloadComplete(at: destination)
        }
    } catch {
        // Handle move failure
    }
}
```

**Critical:** The `location` URL is temporary — iOS deletes it when this delegate method returns. You MUST move the file synchronously within this delegate method (not in an async Task).

### 7. SwiftData Schema

```swift
import SwiftData

@Model
final class DownloadedModel {
    @Attribute(.unique) var repoId: String          // "username/model-name"
    var displayName: String                          // "Llama 3.2 3B"
    var filename: String                             // "model-Q4_K_M.gguf"
    var quantization: String                         // "Q4_K_M"
    var fileSizeBytes: Int64                         // from HF API sibling.lfs.size
    var localPath: String                            // absolute path in HubCache
    var lastUsedDate: Date                           // updated when model is activated
    var conversationCount: Int                       // for Library card display (Phase 4 increments)
    var isActive: Bool                               // only one model active at a time
    var downloadedAt: Date                           // for display / audit
    
    init(repoId: String, displayName: String, filename: String,
         quantization: String, fileSizeBytes: Int64, localPath: String) {
        self.repoId = repoId
        self.displayName = displayName
        self.filename = filename
        self.quantization = quantization
        self.fileSizeBytes = fileSizeBytes
        self.localPath = localPath
        self.lastUsedDate = Date()
        self.conversationCount = 0
        self.isActive = false
        self.downloadedAt = Date()
    }
}
```

**Active model constraint:** SwiftData has no cross-row unique constraint. Enforce "only one active" in code: when setting `model.isActive = true`, first query all models and set `isActive = false`, then set the target model to `true`, in a single modelContext operation.

### 8. Storage Check Pattern

```swift
func preDownloadStorageCheck(requiredBytes: Int64) async -> StorageCheckResult {
    let freeBytes = await DeviceCapabilityService.shared.availableStorage
    let bufferBytes: Int64 = 1_073_741_824  // 1 GB
    let needed = requiredBytes + bufferBytes
    if freeBytes < needed {
        return .insufficient(freeBytes: freeBytes, neededBytes: needed)
    }
    return .sufficient
}
```

Reuse `DeviceCapabilityService.availableStorage` — it already queries `volumeAvailableCapacityForImportantUsage`.

### 9. Cellular Warning

```swift
import Network

func checkNetworkAndProceed(fileSize: Int64, onProceed: @escaping () -> Void) {
    let monitor = NWPathMonitor()
    monitor.pathUpdateHandler = { path in
        monitor.cancel()
        if path.usesInterfaceType(.cellular) {
            // Show alert on main thread
            Task { @MainActor in
                showCellularAlert(fileSize: fileSize, onProceed: onProceed)
            }
        } else {
            onProceed()
        }
    }
    monitor.start(queue: .global())
}
```

Check once at download initiation — not continuously. Don't block or re-check during download.

### 10. Library Tab Navigation

Phase 2 established `BrowseView` as the first tab. Add `LibraryView` as the second tab:

```swift
// ContentView.swift (or wherever tab navigation lives)
TabView {
    BrowseView()
        .tabItem { Label("Browse", systemImage: "magnifyingglass") }
    LibraryView()
        .tabItem { Label("Library", systemImage: "internaldrive") }
}
```

`LibraryView` uses `@Query(sort: \DownloadedModel.lastUsedDate, order: .reverse)` for automatic SwiftData-backed sort.

### Persistent Bottom Bar

The download progress bar sits above the tab bar. Implement as an overlay in the root `TabView` container:

```swift
TabView { ... }
.overlay(alignment: .bottom) {
    if downloadService.state.isActive {
        DownloadProgressBar(state: downloadService.state)
            .padding(.bottom, 49)  // tab bar height
    }
}
```

Height: 64pt. Shows model name, progress bar, MB/s, ETA, cancel button.

---

## Don't Hand-Roll

| Problem | Use Instead |
|---------|-------------|
| Download resume logic | `URLSession.downloadTask(withResumeData:)` — Foundation handles HTTP 206 byte ranges |
| Progress throughput calculation | `Foundation.Progress.throughput` — built-in, updates automatically |
| ETA calculation | `Foundation.Progress.estimatedTimeRemaining` — computed from throughput history |
| File cache structure | `HubCache.default.repoDirectory(repo:kind:)` for path resolution — don't invent your own |
| Network type detection | `NWPathMonitor` — don't ping servers or check `Reachability` |
| Relative timestamp formatting | `Date.formatted(.relative(presentation: .named))` — "2 hours ago" built-in iOS 15+ |
| Storage query | `DeviceCapabilityService.availableStorage` — already implemented in Phase 1 |
| SwiftData fetching | `@Query` macro — don't implement custom fetch logic |

---

## Common Pitfalls

### P-01: Background session not reconnected on relaunch

**Problem:** If the app is killed while a download runs, iOS re-launches it and delivers `handleEventsForBackgroundURLSession`. If you don't immediately recreate the URLSession with the SAME identifier string, iOS cannot deliver the events and the download appears stalled.

**Fix:** Instantiate `DownloadService` eagerly in `AppContainer.init()` — before any UI loads. The background URLSession is recreated with the same identifier, which lets iOS reconnect pending tasks.

### P-02: Moving temp file asynchronously

**Problem:** Moving the downloaded temp file in an async Task within `didFinishDownloadingTo` — iOS deletes the temp file before the async closure runs.

**Fix:** Use synchronous `FileManager.default.moveItem` directly inside the delegate method. No Task, no dispatch.

### P-03: Resume data invalidated by ETag change

**Problem:** Storing resume data and using it after the model file has been updated on HF Hub (e.g., model maintainer re-uploads). The server's ETag no longer matches, and the byte-range request fails with 416 or returns corrupt data.

**Fix:** Before using stored resume data, fetch the current ETag from the HF API and compare. If changed, discard resume data and restart from 0.

### P-04: `isDiscretionary = true` deferring user-initiated downloads

**Problem:** Setting `isDiscretionary = true` tells iOS the download can wait for optimal conditions (plugged in, on WiFi). For user-tapped downloads, this means the download might not start for minutes.

**Fix:** `isDiscretionary = false` for DownloadService. Reserve `isDiscretionary = true` for background prefetch scenarios (not applicable to v1).

### P-05: SwiftData model not excluded from iCloud backup

**Problem:** SwiftData's ModelContainer stores its database file in `Application Support` by default, which is iCloud-backed. The GGUF files are stored outside SwiftData (in HubCache), but if paths or metadata are stored in iCloud, Apple App Review can flag excessive iCloud usage.

**Fix:** GGUF files: set `isExcludedFromBackup = true` as shown above. SwiftData container: Use a custom URL in Application Support — iCloud only backs up Application Support if you don't explicitly configure otherwise. The GGUF files in `Library/Caches` are automatically NOT backed up (Caches directory is excluded by iOS). This is an important reason to use `HubCache.default` which targets `Library/Caches` on iOS.

### P-06: Active model race condition

**Problem:** User taps two models quickly — both execute `setActive()` and both might persist `isActive = true`.

**Fix:** Run the "deactivate all, activate one" logic in a single `@MainActor` function, not concurrently. Since SwiftData operations must run on the main actor when using `@Query`, this is naturally serialized.

### P-07: Library/Caches auto-purged by iOS

**Problem:** iOS may purge `Library/Caches` when the device is low on storage. This would delete GGUF files without the user's knowledge.

**Fix:** Store GGUF files in `Library/Application Support` (not `Library/Caches`). This requires overriding HubCache's default location for the iOS app:

```swift
// In AppContainer.init() or DownloadService.init()
let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let ggufCacheURL = appSupportURL.appending(path: "huggingface/hub", directoryHint: .isDirectory)
let hubCache = HubCache(location: .fixed(directory: ggufCacheURL))
```

Then set `isExcludedFromBackup = true` on each GGUF blob file individually (Application Support IS backed up unless excluded per-file).

**Confidence: HIGH** — Apple's docs are explicit that `Library/Caches` can be purged. This is a v1 correctness issue.

### P-08: Progress bar covers content at small screen sizes

**Problem:** The 64pt overlay bottom bar + 49pt tab bar = 113pt taken from bottom. On iPhone SE (4.7"), this is ~15% of screen height.

**Fix:** Use `safeAreaInset(edge: .bottom)` instead of `.overlay` — SwiftUI will automatically adjust scroll content insets for views inside the affected container.

---

## Validation Architecture

The following areas require physical-device validation that cannot be covered by unit tests:

### V-01: Background download continuity (DLST-02)
**Test:** Start a 1+ GB download, press Home button, wait 30 seconds, return to app — progress should have continued.
**Why device-only:** Simulator does not simulate iOS background session behavior accurately.

### V-02: Resume after app kill
**Test:** Start a download, kill the app from app switcher (not sleep), relaunch — app should detect in-progress download and offer to resume.

### V-03: Storage auto-purge protection
**Test:** Verify GGUF files are in `Library/Application Support`, not `Library/Caches`, by checking file path at runtime.
**Automated check:** `XCTAssertTrue(localPath.contains("Application Support"))` in unit test against `DownloadedModel.localPath`.

### V-04: Cellular warning trigger
**Test:** Enable cellular-only network on device, attempt download — verify alert appears with correct file size.

### V-05: SwiftData persistence across launches
**Test:** Download a model, force-quit, relaunch — Library tab shows the model with correct last-used date and file size.

---

## Sources

| Source | Confidence | URL |
|--------|-----------|-----|
| swift-huggingface 0.8.0 blog announcement | HIGH | https://huggingface.co/blog/swift-huggingface |
| HubClient+Files.swift source (actual API signatures) | HIGH | https://github.com/huggingface/swift-huggingface/blob/main/Sources/HuggingFace/Hub/HubClient%2BFiles.swift |
| HubCache.swift source (iOS cache location) | HIGH | https://github.com/huggingface/swift-huggingface/blob/main/Sources/HuggingFace/Hub/HubCache.swift |
| Apple: Downloading files in the background | HIGH | https://docs.developer.apple.com/tutorials/data/documentation/foundation/downloading-files-in-the-background.md |
| Apple: SwiftData overview | HIGH | https://docs.developer.apple.com/tutorials/data/documentation/swiftdata.md |
| Apple: NWPathMonitor | HIGH | https://docs.developer.apple.com/tutorials/data/documentation/network/nwpathmonitor.md |

## RESEARCH COMPLETE

Phase 3 research complete. Key findings:

1. **swift-huggingface download methods don't support background sessions** — must use raw `URLSessionDownloadTask` with `background(withIdentifier:)` config
2. **HubCache targets `Library/Caches` on iOS** — must override to `Application Support` to prevent auto-purge of 2-4GB GGUF files
3. **`isDiscretionary = false`** — user-initiated downloads must not be deferred
4. **`didFinishDownloadingTo` must move file synchronously** — no async Task within this delegate method
5. **`Foundation.Progress` has built-in throughput + ETA** — no custom calculation needed
6. **SwiftData `@Query` with `sort: \DownloadedModel.lastUsedDate`** — provides automatic Library sort with live updates

Ready for `/gsd:plan-phase 3`.
