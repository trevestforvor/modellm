import Testing
@testable import ModelRunner

@Suite("ChipLookupTable")
struct ChipLookupTableTests {
    @Test("unknown chip fallback is ~40% of physicalRAM, never 100%")
    func testUnknownChipFallback() throws {
        Issue.record("STUB — implement in Plan 02 Task 2")
    }

    @Test("known chip identifiers map to correct jetsam budget")
    func testKnownChipMapping() throws {
        Issue.record("STUB — implement in Plan 02 Task 2")
    }
}
