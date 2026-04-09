import Testing
@testable import ModelRunner

/// Tests for pre-download storage guardrail logic — supports DLST-01 (safe download).
/// Wave 0: stubs for Plan 03 Task 2 implementation.
@Suite("StorageGuard")
struct StorageGuardTests {

    @Test("Storage check allows download when free > model size + 1GB buffer")
    func testStorageAllowsDownloadWithBuffer() async throws {
        Issue.record("STUB — implement in Plan 03 Task 2")
    }

    @Test("Storage check blocks download when free == model size (no buffer)")
    func testStorageBlocksWithoutBuffer() async throws {
        Issue.record("STUB — implement in Plan 03 Task 2")
    }

    @Test("DownloadError.insufficientStorage carries freeBytes and neededBytes")
    func testInsufficientStorageErrorCarriesValues() throws {
        let error = DownloadError.insufficientStorage(freeBytes: 2_000_000_000, neededBytes: 4_000_000_000)
        if case .insufficientStorage(let free, let needed) = error {
            #expect(free == 2_000_000_000)
            #expect(needed == 4_000_000_000)
        } else {
            Issue.record("Expected .insufficientStorage case")
        }
    }
}
