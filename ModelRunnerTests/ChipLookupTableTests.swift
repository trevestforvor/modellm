import Testing
@testable import ModelRunner

@Suite("ChipLookupTable")
struct ChipLookupTableTests {

    @Test("unknown chip identifier returns nil")
    func testUnknownChipFallback() {
        let result = ChipLookupTable.profile(for: "iPhone99,9")
        #expect(result == nil, "Unknown chip must return nil so DeviceCapabilityService applies 40% fallback")
    }

    @Test("iPhone14,2 maps to A15 generation")
    func testIPhone13ProIsA15() {
        let profile = ChipLookupTable.profile(for: "iPhone14,2")
        #expect(profile != nil)
        #expect(profile?.generation == .a15)
    }

    @Test("iPhone15,4 maps to A16 generation (iPhone 15 non-Pro)")
    func testIPhone15IsA16() {
        let profile = ChipLookupTable.profile(for: "iPhone15,4")
        #expect(profile != nil)
        #expect(profile?.generation == .a16)
    }

    @Test("iPhone16,1 maps to A17Pro generation")
    func testIPhone15ProIsA17Pro() {
        let profile = ChipLookupTable.profile(for: "iPhone16,1")
        #expect(profile != nil)
        #expect(profile?.generation == .a17Pro)
    }

    @Test("iPhone17,1 maps to A18 generation")
    func testIPhone16IsA18() {
        let profile = ChipLookupTable.profile(for: "iPhone17,1")
        #expect(profile != nil)
        #expect(profile?.generation == .a18)
    }

    @Test("iPhone17,3 maps to A18Pro generation")
    func testIPhone16ProIsA18Pro() {
        let profile = ChipLookupTable.profile(for: "iPhone17,3")
        #expect(profile != nil)
        #expect(profile?.generation == .a18Pro)
    }

    @Test("A15 contextWindowCap is 1024")
    func testA15ContextCap() {
        let profile = ChipLookupTable.profile(for: "iPhone14,5")
        #expect(profile?.contextWindowCap == 1024)
    }

    @Test("A18Pro contextWindowCap is 4096")
    func testA18ProContextCap() {
        let profile = ChipLookupTable.profile(for: "iPhone17,3")
        #expect(profile?.contextWindowCap == 4096)
    }

    @Test("A18Pro jetsam budget is greater than A15 jetsam budget")
    func testJetsamBudgetScalesWithGeneration() {
        let a15 = ChipLookupTable.profile(for: "iPhone14,5")
        let a18Pro = ChipLookupTable.profile(for: "iPhone17,3")
        #expect(a15 != nil && a18Pro != nil)
        #expect(a18Pro!.jetsamBudgetBytes > a15!.jetsamBudgetBytes)
    }

    @Test("Known chip identifiers have non-zero jetsam budget")
    func testKnownChipMapping() {
        let knownIdentifiers = ["iPhone14,2", "iPhone15,2", "iPhone16,1", "iPhone17,1", "iPhone17,3"]
        for id in knownIdentifiers {
            let profile = ChipLookupTable.profile(for: id)
            #expect(profile != nil, "Expected profile for \(id)")
            #expect(profile!.jetsamBudgetBytes > 0, "Jetsam budget must be non-zero for \(id)")
        }
    }
}
