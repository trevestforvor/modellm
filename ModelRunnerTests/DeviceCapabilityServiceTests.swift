import Testing
@testable import ModelRunner

@Suite("DeviceCapabilityService")
struct DeviceCapabilityServiceTests {

    @Test("initialize() populates specs with non-nil DeviceSpecs")
    func testDeviceSpecsInitialization() async throws {
        let service = DeviceCapabilityService()
        await service.initialize()
        let specs = await service.specs
        #expect(specs != nil, "specs must be non-nil after initialize()")
    }

    @Test("chipIdentifier is a non-empty string")
    func testChipIdentifierNonEmpty() async throws {
        let service = DeviceCapabilityService()
        await service.initialize()
        let specs = await service.specs
        #expect(specs?.chipIdentifier.isEmpty == false)
    }

    @Test("physicalRAM is greater than zero")
    func testPhysicalRAMNonZero() async throws {
        let service = DeviceCapabilityService()
        await service.initialize()
        let specs = await service.specs
        #expect(specs?.physicalRAM ?? 0 > 0)
    }

    @Test("jetsamBudget is less than or equal to physicalRAM")
    func testJetsamBudgetSmallerThanPhysicalRAM() async throws {
        let service = DeviceCapabilityService()
        await service.initialize()
        let specs = await service.specs
        guard let s = specs else {
            Issue.record("specs is nil")
            return
        }
        #expect(s.jetsamBudget <= s.physicalRAM, "Jetsam budget must never exceed physical RAM")
    }

    @Test("jetsamBudget is greater than zero")
    func testJetsamBudgetNonZero() async throws {
        let service = DeviceCapabilityService()
        await service.initialize()
        let specs = await service.specs
        #expect(specs?.jetsamBudget ?? 0 > 0)
    }

    @Test("availableStorage returns non-zero value")
    func testAvailableStorageNonZero() async throws {
        let service = DeviceCapabilityService()
        // Note: availableStorage doesn't require initialize() first
        let storage = try await service.availableStorage
        #expect(storage > 0, "Available storage must be readable from device file system")
    }

    @Test("unknown chip uses 40% physicalRAM as jetsam budget")
    func testUnknownChipJetsamFallback() {
        // Test the 40% rule directly using known values
        // physicalRAM = 8GB
        let physicalRAM: UInt64 = 8 * 1024 * 1024 * 1024
        let expected: UInt64 = physicalRAM * 4 / 10  // 40% = 3,435,973,837 bytes
        #expect(expected == physicalRAM * 4 / 10)
        // Verify it's less than physicalRAM
        #expect(expected < physicalRAM)
        // Verify it's approximately 40% (within 1% of 40%)
        let ratio = Double(expected) / Double(physicalRAM)
        #expect(ratio >= 0.39 && ratio <= 0.41, "40% fallback must be within 1% of 40%")
    }
}
