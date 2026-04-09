import Testing
@testable import ModelRunner

@Suite("CompatibilityEngine")
struct CompatibilityEngineTests {
    @Test("model exceeding jetsam budget returns incompatible")
    func testHardBlock() throws {
        Issue.record("STUB — implement in Plan 03 Task 1")
    }

    @Test("model within budget but slow speed returns runsSlowly")
    func testSoftWarn() throws {
        Issue.record("STUB — implement in Plan 03 Task 1")
    }

    @Test("storage impact description formats correctly")
    func testStorageDescription() throws {
        Issue.record("STUB — implement in Plan 03 Task 2")
    }

    @Test("KV cache bytes are included in total RAM required")
    func testKVCacheIncluded() throws {
        Issue.record("STUB — implement in Plan 03 Task 1")
    }
}
