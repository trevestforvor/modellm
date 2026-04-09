import Foundation

/// Background download manager for GGUF model files.
/// Uses URLSessionConfiguration.background to satisfy DLST-02 (downloads continue when backgrounded).
/// Full implementation in Plan 02.
actor DownloadService: NSObject {
    static let backgroundSessionIdentifier = "com.modelrunner.download"

    /// Published download progress state — observed by DownloadProgressBar (Plan 03)
    @MainActor private(set) var state: DownloadState = .idle

    /// Stored by AppDelegate.handleEventsForBackgroundURLSession — called after delegate events complete
    var backgroundCompletionHandler: (() -> Void)?

    // URLSession is created in Plan 02 with URLSessionConfiguration.background(withIdentifier:)
    // Kept nil here so the stub compiles without URLSessionDelegate conformance
    private var urlSession: URLSession?

    override init() {
        super.init()
        // Plan 02: instantiate background URLSession here
    }

    /// Called by AppDelegate when iOS re-launches app for background download completion
    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        self.backgroundCompletionHandler = handler
    }

    /// Initiates download of a GGUF file. Full implementation in Plan 02.
    func startDownload(repoId: String, filename: String, fileSizeBytes: Int64, displayName: String, quantization: String, authToken: String?) async throws {
        // Plan 02 implements this
        throw DownloadError.notImplemented
    }

    /// Pauses active download, storing resume data. Full implementation in Plan 02.
    func cancelDownload() async {
        // Plan 02 implements this
    }
}

enum DownloadError: Error {
    case notImplemented
    case insufficientStorage(freeBytes: Int64, neededBytes: Int64)
    case cellularBlocked
    case invalidResumeData
    case fileMoveFailure(Error)
    case networkUnavailable
}
