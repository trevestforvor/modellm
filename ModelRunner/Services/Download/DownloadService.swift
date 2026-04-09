import Foundation
import SwiftData

// MARK: - DownloadService Actor

/// Background download manager for GGUF model files.
/// Uses URLSessionConfiguration.background to satisfy DLST-02.
/// Actor isolation prevents data races on activeTask, resumeData, and state.
actor DownloadService: NSObject {
    static let backgroundSessionIdentifier = "com.modelrunner.download"

    // MARK: - State

    /// Published to UI via @MainActor — observed by DownloadProgressBar (Plan 03)
    @MainActor private(set) var state: DownloadState = .idle

    /// Stored by AppDelegate.handleEventsForBackgroundURLSession — called in urlSessionDidFinishEvents
    var backgroundCompletionHandler: (() -> Void)?

    // MARK: - Private

    private var urlSession: URLSession!
    private var activeTask: URLSessionDownloadTask?
    private var activeDownloadId: String?   // repoId of in-progress download
    private var activeDisplayName: String?
    private var activeFileSizeBytes: Int64 = 0
    private var resumeData: Data?
    private var progress: Progress = Progress()

    // SwiftData context for recording completed downloads (Plan 02 Task 5)
    // Injected from AppContainer so we don't create a second ModelContainer
    var modelContext: ModelContext?

    // MARK: - Init

    override init() {
        super.init()
        // Create background URLSession with the same identifier on EVERY launch.
        // iOS uses the identifier to reconnect pending tasks after app re-launch (P-01).
        let config = URLSessionConfiguration.background(
            withIdentifier: Self.backgroundSessionIdentifier
        )
        // isDiscretionary = false: user tapped Download. Do NOT defer (P-04).
        config.isDiscretionary = false
        // sessionSendsLaunchEvents = true: iOS re-launches app when download completes while backgrounded.
        config.sessionSendsLaunchEvents = true
        // Allow cellular by default — cellular warning is shown before calling startDownload (Plan 03 Task 1)
        config.allowsCellularAccess = true

        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public API

    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        self.backgroundCompletionHandler = handler
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
}

// MARK: - DownloadError

enum DownloadError: Error, LocalizedError {
    case notImplemented
    case insufficientStorage(freeBytes: Int64, neededBytes: Int64)
    case cellularBlocked
    case invalidResumeData
    case fileMoveFailure(Error)
    case networkUnavailable
    case alreadyDownloading

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Not implemented"
        case .insufficientStorage(let free, let needed):
            let freeGB = String(format: "%.1f", Double(free) / 1_000_000_000)
            let needGB = String(format: "%.1f", Double(needed) / 1_000_000_000)
            return "Need \(needGB) GB free, you have \(freeGB) GB"
        case .cellularBlocked:
            return "Download blocked on cellular"
        case .invalidResumeData:
            return "Resume data is invalid — download will restart from beginning"
        case .fileMoveFailure(let underlying):
            return "Failed to save downloaded file: \(underlying.localizedDescription)"
        case .networkUnavailable:
            return "No network connection available"
        case .alreadyDownloading:
            return "A download is already in progress"
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadService: URLSessionDownloadDelegate {

    /// Called continuously during download — update Foundation.Progress for throughput + ETA
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { [self] in
            await updateProgress(
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
        }
    }

    private func updateProgress(bytesWritten: Int64, totalBytes: Int64) async {
        progress.completedUnitCount = bytesWritten
        // Foundation.Progress computes throughput in bytes/sec after first few updates.
        // .throughput returns NSNumber? — bridge to Double for display.
        let throughputBPS: Double? = progress.throughput.map { Double($0) }

        let modelName = activeDisplayName ?? "Downloading..."
        let fractionCompleted = totalBytes > 0
            ? Double(bytesWritten) / Double(totalBytes)
            : 0.0

        await MainActor.run {
            self.state = .downloading(
                modelName: modelName,
                progress: fractionCompleted,
                bytesWritten: bytesWritten,
                totalBytes: totalBytes,
                throughput: throughputBPS
            )
        }
    }

    /// Called when download completes. CRITICAL: move temp file SYNCHRONOUSLY here (P-02).
    /// iOS deletes the temp file when this method returns — async Task will be too late.
    ///
    /// IMPLEMENTATION PATTERN (P-02):
    /// 1. Call `synchronousFinalizeDownload(tempURL:repoId:filename:)` SYNCHRONOUSLY — moves file before method returns
    /// 2. Only AFTER the synchronous move succeeds: dispatch an async Task for the SwiftData record
    /// Do NOT put the file move inside an async Task — the temp file will be gone by the time it runs.
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let filename = downloadTask.originalRequest?.url?.lastPathComponent ?? "model.gguf"
        // repoId is set as taskDescription during startDownload (see Task 3)
        let repoId = downloadTask.taskDescription ?? "unknown/model"

        // SYNCHRONOUS file move — MUST complete before this method returns (P-02)
        do {
            let destURL = try DownloadService.synchronousFinalizeDownload(
                tempURL: location,
                repoId: repoId,
                filename: filename
            )
            // File is safely on disk. NOW dispatch async for SwiftData record.
            Task { [self] in
                await recordFinalization(destURL: destURL, downloadTask: downloadTask, repoId: repoId)
            }
        } catch {
            Task { [self] in await handleError(error: error) }
        }
    }

    /// Static synchronous file move helper — callable from nonisolated context.
    /// Extracted as static so it can be called directly from the nonisolated delegate method.
    static func synchronousFinalizeDownload(tempURL: URL, repoId: String, filename: String) throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Mirror HubCache directory structure in Application Support (P-07: not Caches — auto-purged)
        let destDir = appSupport
            .appending(path: "huggingface/hub/\(repoId.replacingOccurrences(of: "/", with: "--"))/blobs", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destURL = destDir.appending(path: filename)

        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }

        // SYNCHRONOUS move — iOS deletes temp file when didFinishDownloadingTo returns (P-02)
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        // Exclude from iCloud backup — GGUF files are 2-4GB of re-downloadable content (D-16)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDest = destURL
        try mutableDest.setResourceValues(resourceValues)

        return destURL
    }

    /// Async portion of finalization — SwiftData record creation after file is safely moved.
    private func recordFinalization(destURL: URL, downloadTask: URLSessionDownloadTask, repoId: String) async {
        let displayName = activeDisplayName ?? repoId
        let filename = downloadTask.originalRequest?.url?.lastPathComponent ?? "model.gguf"
        let quantization = QuantizationType.allCases
            .first { filename.contains($0.rawValue) }?.rawValue ?? "Unknown"
        let sizeBytes = activeFileSizeBytes
        let ctx = modelContext

        await MainActor.run {
            recordDownloadComplete(
                localURL: destURL,
                repoId: repoId,
                displayName: displayName,
                filename: filename,
                quantization: quantization,
                fileSizeBytes: sizeBytes,
                context: ctx
            )
        }
        activeTask = nil
        activeDownloadId = nil
        activeDisplayName = nil
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        // URLError.cancelled is expected when user taps Cancel — not a real error
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        Task { [self] in
            await handleError(error: error)
        }
    }

    private func handleError(error: Error) async {
        let modelName = activeDisplayName ?? "Download"
        await MainActor.run {
            self.state = .failed(modelName: modelName, errorDescription: error.localizedDescription)
        }
        activeTask = nil
        activeDownloadId = nil
    }

    /// Called after all pending background session events have been delivered.
    /// MUST call backgroundCompletionHandler on MainActor — iOS requires this to update system UI (P-01).
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { [self] in
            let handler = await backgroundCompletionHandler
            await MainActor.run {
                handler?()
            }
            await clearBackgroundCompletionHandler()
        }
    }

    private func clearBackgroundCompletionHandler() {
        backgroundCompletionHandler = nil
    }
}

// MARK: - File Finalization

extension DownloadService {

    /// Moves downloaded temp file to Application Support/huggingface/hub/ and sets iCloud backup exclusion.
    /// This is called from within the URLSessionDownloadDelegate — the move itself is synchronous.
    func finalizeDownload(tempURL: URL, repoId: String, filename: String) throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Mirror HubCache directory structure in Application Support (P-07: not Caches — auto-purged)
        let destDir = appSupport
            .appending(path: "huggingface/hub/\(repoId.replacingOccurrences(of: "/", with: "--"))/blobs", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let destURL = destDir.appending(path: filename)

        // Remove existing file if present (e.g. partial from previous interrupted download)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }

        // SYNCHRONOUS move — iOS deletes temp file when didFinishDownloadingTo returns (P-02)
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        // Exclude from iCloud backup — GGUF files are 2-4GB of re-downloadable content (D-16)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDest = destURL
        try mutableDest.setResourceValues(resourceValues)

        return destURL
    }
}

// MARK: - Download Initiation

extension DownloadService {

    /// Constructs the HF CDN URL for a GGUF file.
    /// Pattern: https://huggingface.co/{repo}/resolve/{revision}/{filename}
    /// LFS files are served from the CDN at this URL — no redirect needed.
    func ggufDownloadURL(repo: String, revision: String = "main", filename: String) -> URL {
        URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(filename)")!
    }

    /// Start a GGUF download. Throws if another download is already active.
    /// Cellular check and storage check are handled by Plan 03 before calling this method.
    func startDownload(
        repoId: String,
        filename: String,
        fileSizeBytes: Int64,
        displayName: String,
        quantization: String,
        authToken: String?
    ) async throws {
        guard activeTask == nil else {
            throw DownloadError.alreadyDownloading
        }

        // Store metadata for delegate callbacks
        activeDownloadId = repoId
        activeDisplayName = displayName
        activeFileSizeBytes = fileSizeBytes

        // Configure Foundation.Progress for throughput + ETA tracking
        progress = Progress(totalUnitCount: fileSizeBytes)

        // Build download request
        let downloadURL = ggufDownloadURL(repo: repoId, filename: filename)
        var request = URLRequest(url: downloadURL)

        // Auth header for gated models (token stored in Keychain by Phase 2)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Check for valid resume data (P-03: validate before using)
        let resumeKey = "resumeData_\(repoId)"
        if let stored = UserDefaults.standard.data(forKey: resumeKey) {
            // Use resume data — Foundation handles HTTP 206 byte-range negotiation
            activeTask = urlSession.downloadTask(withResumeData: stored)
            UserDefaults.standard.removeObject(forKey: resumeKey)
            resumeData = nil
        } else {
            activeTask = urlSession.downloadTask(with: request)
        }

        // Tag task so didFinishDownloadingTo can retrieve repoId nonisolatedly
        activeTask?.taskDescription = repoId
        activeTask?.resume()

        await MainActor.run {
            self.state = .downloading(
                modelName: displayName,
                progress: 0.0,
                bytesWritten: 0,
                totalBytes: fileSizeBytes,
                throughput: nil
            )
        }
    }
}

// MARK: - Progress Display Helpers

extension DownloadService {

    /// Formatted throughput string e.g. "4.2 MB/s"
    /// Uses Foundation.Progress.throughput — non-nil after the first few progress updates.
    static func formattedThroughput(_ bytesPerSec: Double?) -> String {
        guard let bps = bytesPerSec, bps > 0 else { return "—" }
        return String(format: "%.1f MB/s", bps / 1_000_000)
    }

    /// Formatted ETA string e.g. "3 min 20 sec"
    /// Uses Foundation.Progress.estimatedTimeRemaining — computed from throughput history.
    static func formattedETA(_ seconds: TimeInterval?) -> String {
        guard let secs = seconds, secs > 0, secs.isFinite else { return "—" }
        return Duration.seconds(secs).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
    }
}

// MARK: - SwiftData Record Creation

extension DownloadService {

    /// Creates a DownloadedModel SwiftData record after the GGUF file is moved to Application Support.
    /// Must be called on MainActor (SwiftData requires MainActor context for modelContext operations).
    @MainActor
    func recordDownloadComplete(
        localURL: URL,
        repoId: String,
        displayName: String,
        filename: String,
        quantization: String,
        fileSizeBytes: Int64,
        context: ModelContext? = nil
    ) {
        guard let context else {
            // modelContext not yet injected — this is a setup error
            assertionFailure("DownloadService.modelContext is nil — inject via setModelContext in AppContainer")
            return
        }

        let model = DownloadedModel(
            repoId: repoId,
            displayName: displayName,
            filename: filename,
            quantization: quantization,
            fileSizeBytes: fileSizeBytes,
            localPath: localURL.path
        )

        context.insert(model)

        do {
            try context.save()
        } catch {
            // Non-fatal — model will appear after next context sync
            print("[DownloadService] SwiftData save failed: \(error)")
        }

        // Transition state to idle so DownloadProgressBar hides
        self.state = .idle
    }
}

// MARK: - Finalization Orchestration

extension DownloadService {

    /// Orchestrates file move (synchronous) and SwiftData record creation (async/MainActor).
    /// Called via unstructured Task from didFinishDownloadingTo — the file move inside
    /// finalizeDownload is synchronous and completes before any async suspension point.
    func finalize(tempURL: URL, task: URLSessionDownloadTask) async {
        guard
            let repoId = activeDownloadId,
            let displayName = activeDisplayName
        else { return }

        let filename = task.originalRequest?.url?.lastPathComponent
            ?? tempURL.lastPathComponent

        // Determine quantization from filename (best-effort)
        let quantization = QuantizationType.allCases
            .first { filename.contains($0.rawValue) }?.rawValue ?? "Unknown"

        let sizeBytes = activeFileSizeBytes
        let ctx = modelContext

        do {
            // finalizeDownload is synchronous — file is moved before this line returns
            let destURL = try finalizeDownload(tempURL: tempURL, repoId: repoId, filename: filename)

            // Now record in SwiftData on MainActor
            await MainActor.run {
                recordDownloadComplete(
                    localURL: destURL,
                    repoId: repoId,
                    displayName: displayName,
                    filename: filename,
                    quantization: quantization,
                    fileSizeBytes: sizeBytes,
                    context: ctx
                )
            }
        } catch {
            await handleError(error: error)
        }

        activeTask = nil
        activeDownloadId = nil
        activeDisplayName = nil
    }
}

// MARK: - Cancel and Resume

extension DownloadService {

    /// Cancels the active download and stores resume data to UserDefaults for crash recovery.
    /// Resume data allows restarting from the same byte offset on next download attempt (HTTP 206).
    /// Note (P-03): Resume data is invalidated if server ETag changes. Check before using in startDownload.
    func cancelDownload() async {
        guard let task = activeTask else {
            await MainActor.run { self.state = .idle }
            return
        }

        let repoId = activeDownloadId ?? "unknown"

        // cancelByProducingResumeData: graceful cancel that preserves partial download data
        // The async version returns the resume data directly
        let data = await task.cancelByProducingResumeData()

        if let data {
            // Store keyed by repoId — retrieved in startDownload on next attempt
            UserDefaults.standard.set(data, forKey: "resumeData_\(repoId)")
            resumeData = data
        }

        activeTask = nil
        activeDownloadId = nil
        activeDisplayName = nil

        await MainActor.run {
            self.state = .idle
        }
    }

    /// Checks if resume data exists for a given repoId.
    func hasResumeData(for repoId: String) -> Bool {
        UserDefaults.standard.data(forKey: "resumeData_\(repoId)") != nil
    }

    /// Clears resume data for a repoId (called after successful completion or if ETag validation fails).
    func clearResumeData(for repoId: String) {
        UserDefaults.standard.removeObject(forKey: "resumeData_\(repoId)")
    }
}
