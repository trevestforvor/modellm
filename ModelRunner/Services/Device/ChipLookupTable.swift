import Foundation

/// Static table mapping hw.machine identifiers to ChipProfile.
/// IMPORTANT: Use explicit key-value pairs — no computed offset rules (Pitfall 4).
/// Source: adamawolf/3048717 GitHub Gist cross-referenced with Apple silicon specs.
/// Update this table on each new iPhone release.
public struct ChipLookupTable {

    /// Returns the ChipProfile for a given hw.machine identifier, or nil for unknown chips.
    /// Nil return signals DeviceCapabilityService to use the conservative 40% fallback (D-05).
    public static func profile(for machineIdentifier: String) -> ChipProfile? {
        return table[machineIdentifier]
    }

    // MARK: - Private table

    private static let table: [String: ChipProfile] = buildTable()

    private static func buildTable() -> [String: ChipProfile] {
        var t: [String: ChipProfile] = [:]

        // --- A15 Bionic (iPhone 13 + iPhone 14 non-Pro) ---
        // Neural Engine: 4th gen, 6GB physical RAM, ~5GB jetsam (with entitlement)
        // Context cap: 1024 (conservative for 6GB class)
        let a15Bands = SpeedBands(
            small3B: 15...30,
            medium7B: 6...14,
            large13B: 2...6
        )
        let a15Profile = ChipProfile(
            generation: .a15,
            physicalRAMBytes: 6 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 5 * 1024 * 1024 * 1024,   // ~5GB with entitlement (MEDIUM confidence)
            neuralEngine: .gen4,
            contextWindowCap: 1024,
            speedBands: a15Bands
        )
        // iPhone 13 series
        t["iPhone14,4"] = a15Profile  // iPhone 13 mini
        t["iPhone14,5"] = a15Profile  // iPhone 13
        t["iPhone14,2"] = a15Profile  // iPhone 13 Pro
        t["iPhone14,3"] = a15Profile  // iPhone 13 Pro Max

        // iPhone 14 non-Pro (also A15, different hw.machine range)
        t["iPhone14,7"] = a15Profile  // iPhone 14
        t["iPhone14,8"] = a15Profile  // iPhone 14 Plus

        // --- A16 Bionic (iPhone 14 Pro, iPhone 15 non-Pro) ---
        // Neural Engine: 4th gen, 6GB physical, ~5GB jetsam
        let a16Bands = SpeedBands(
            small3B: 18...35,
            medium7B: 8...17,
            large13B: 3...8
        )
        let a16Profile = ChipProfile(
            generation: .a16,
            physicalRAMBytes: 6 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 5 * 1024 * 1024 * 1024,   // ~5GB with entitlement (MEDIUM confidence)
            neuralEngine: .gen4,
            contextWindowCap: 1024,
            speedBands: a16Bands
        )
        // iPhone 14 Pro (A16 with 6GB RAM)
        t["iPhone15,2"] = a16Profile  // iPhone 14 Pro
        t["iPhone15,3"] = a16Profile  // iPhone 14 Pro Max

        // iPhone 15 non-Pro (A16)
        t["iPhone15,4"] = a16Profile  // iPhone 15
        t["iPhone15,5"] = a16Profile  // iPhone 15 Plus

        // --- A17 Pro (iPhone 15 Pro) ---
        // Neural Engine: 5th gen, 8GB physical, ~6-7GB jetsam
        let a17ProBands = SpeedBands(
            small3B: 25...50,
            medium7B: 12...25,
            large13B: 5...12
        )
        let a17ProProfile = ChipProfile(
            generation: .a17Pro,
            physicalRAMBytes: 8 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 6 * 1024 * 1024 * 1024,   // ~6GB with entitlement (MEDIUM confidence)
            neuralEngine: .gen5,
            contextWindowCap: 2048,
            speedBands: a17ProBands
        )
        // iPhone 15 Pro (A17 Pro with 8GB RAM)
        t["iPhone16,1"] = a17ProProfile  // iPhone 15 Pro
        t["iPhone16,2"] = a17ProProfile  // iPhone 15 Pro Max

        // --- A18 (iPhone 16 non-Pro) ---
        // Neural Engine: 5th gen, 8GB physical, ~6GB jetsam
        let a18Bands = SpeedBands(
            small3B: 28...55,
            medium7B: 14...28,
            large13B: 6...14
        )
        let a18Profile = ChipProfile(
            generation: .a18,
            physicalRAMBytes: 8 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 6 * 1024 * 1024 * 1024,   // ~6GB with entitlement (MEDIUM confidence)
            neuralEngine: .gen5,
            contextWindowCap: 2048,
            speedBands: a18Bands
        )
        t["iPhone17,1"] = a18Profile   // iPhone 16
        t["iPhone17,2"] = a18Profile   // iPhone 16 Plus

        // --- A18 Pro (iPhone 16 Pro) ---
        // Neural Engine: 5th gen, 8GB physical, ~7GB jetsam (higher due to Pro entitlement headroom)
        // Note: 44% throughput loss after sustained thermal throttle (logged in CONTEXT.md specifics)
        let a18ProBands = SpeedBands(
            small3B: 30...60,
            medium7B: 15...30,
            large13B: 7...15
        )
        let a18ProProfile = ChipProfile(
            generation: .a18Pro,
            physicalRAMBytes: 8 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 7 * 1024 * 1024 * 1024,   // ~7GB with entitlement (MEDIUM confidence)
            neuralEngine: .gen5,
            contextWindowCap: 4096,
            speedBands: a18ProBands
        )
        t["iPhone17,3"] = a18ProProfile  // iPhone 16 Pro
        t["iPhone17,4"] = a18ProProfile  // iPhone 16 Pro Max

        return t
    }
}
