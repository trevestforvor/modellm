import Testing
@testable import ModelRunner

/// Tests for DownloadService — covers DLST-01 (progress indicator) and DLST-02 (background continuity).
/// Wave 0: All tests are RED stubs. Plans 02 and 03 replace Issue.record() with real assertions.
@Suite("DownloadService")
struct DownloadServiceTests {

    // DLST-01: User can download models with progress indicator (MB/s, ETA, cancel)
    @Test("Download state transitions from idle to downloading when download starts")
    func testDownloadStateTransitionsToDownloading() async throws {
        Issue.record("STUB — implement in Plan 02 Task 1")
    }

    @Test("Download progress reports bytesWritten and totalBytes")
    func testDownloadProgressReportsBytesWritten() async throws {
        Issue.record("STUB — implement in Plan 02 Task 4")
    }

    @Test("Cancel transitions download state back to idle")
    func testCancelTransitionsToIdle() async throws {
        Issue.record("STUB — implement in Plan 02 Task 6")
    }

    @Test("Resume data is stored after cancel")
    func testResumeDataStoredAfterCancel() async throws {
        Issue.record("STUB — implement in Plan 02 Task 6")
    }

    // DLST-02: Downloads continue when backgrounded
    @Test("Background completion handler is called after urlSessionDidFinishEvents")
    func testBackgroundCompletionHandlerCalled() async throws {
        Issue.record("STUB — implement in Plan 02 Task 2 (requires physical device for full validation)")
    }

    @Test("DownloadService is eagerly instantiated before UI loads")
    func testDownloadServiceEagerInstantiation() async throws {
        // This can be checked: AppContainer.shared.downloadService must not be nil
        Issue.record("STUB — implement in Plan 02 after AppContainer wiring is confirmed")
    }

    // DLST-03: Storage guardrail blocks download when free < model size + 1GB
    @Test("Pre-download storage check returns insufficient when free storage < required + 1GB buffer")
    func testStorageCheckBlocksWhenInsufficient() async throws {
        Issue.record("STUB — implement in Plan 03 Task 2")
    }

    @Test("Cellular warning fires when NWPathMonitor reports cellular interface")
    func testCellularWarningFiresOnCellular() async throws {
        Issue.record("STUB — implement in Plan 03 Task 1")
    }
}
