import Testing
@testable import ModelRunner

@Suite("HFAPIService")
struct HFAPIServiceTests {

    @Test("searchGGUFModels decodes valid search response")
    func testSearchDecoding() async throws {
        // WAVE 0 STUB — implement in Plan 02, Task 2
        Issue.record("STUB — implement in Plan 02")
    }

    @Test("LFS size is preferred over sibling size when both present")
    func testLFSSizePreferred() async throws {
        // WAVE 0 STUB — implement in Plan 02, Task 2
        Issue.record("STUB — implement in Plan 02")
    }

    @Test("HTTP 429 throws HFAPIError.rateLimited")
    func testRateLimitHandling() async throws {
        // WAVE 0 STUB — implement in Plan 02, Task 2
        Issue.record("STUB — implement in Plan 02")
    }

    @Test("empty results array decodes without error")
    func testEmptyResultsDecoding() async throws {
        // WAVE 0 STUB — implement in Plan 02, Task 2
        Issue.record("STUB — implement in Plan 02")
    }

    @Test("fetchModelDetail returns single model with full siblings list")
    func testFetchModelDetail() async throws {
        // WAVE 0 STUB — implement in Plan 02, Task 2
        Issue.record("STUB — implement in Plan 02")
    }

    @Test("non-GGUF siblings are filtered from metadata mapping")
    func testNonGGUFFilesFiltered() async throws {
        // WAVE 0 STUB — implement in Plan 02, Task 2
        Issue.record("STUB — implement in Plan 02")
    }
}
