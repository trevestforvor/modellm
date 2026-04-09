import Testing
@testable import ModelRunner

@Suite("HFBrowseViewModel")
struct HFBrowseViewModelTests {

    @Test("loadInitialData populates recommendations with runsWell models only")
    func testRecommendationsFilteredToRunsWell() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }

    @Test("search results exclude incompatible models")
    func testIncompatibleModelsFiltered() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }

    @Test("search results sorted runsWell before runsSlow")
    func testCompatibilitySortOrder() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }

    @Test("debounced search fires once for rapid input")
    func testDebouncedSearchFiresOnce() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }

    @Test("loadNextPage appends to existing results and increments offset")
    func testPaginationAppendsResults() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }

    @Test("search error sets searchError and does not clear existing results")
    func testSearchErrorPreservesResults() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }

    @Test("detail load returns full model with all GGUF variants")
    func testModelDetailLoad() async throws {
        // WAVE 0 STUB — implement in Plan 03, Task 2
        Issue.record("STUB — implement in Plan 03")
    }
}
