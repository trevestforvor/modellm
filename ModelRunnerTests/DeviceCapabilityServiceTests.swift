import Testing
@testable import ModelRunner

@Suite("DeviceCapabilityService")
struct DeviceCapabilityServiceTests {
    @Test("reads chip identifier, RAM, and storage without crashing")
    func testDeviceSpecsInitialization() async throws {
        // WAVE 0 STUB — implementation added in Plan 02
        // This test must exist so xcodebuild test discovers it
        // Remove this comment and implement in Plan 02
        Issue.record("STUB — implement in Plan 02 Task 1")
    }

    @Test("unknown chip uses 40% physicalRAM as jetsam budget")
    func testUnknownChipJetsamFallback() async throws {
        Issue.record("STUB — implement in Plan 02 Task 1")
    }
}
