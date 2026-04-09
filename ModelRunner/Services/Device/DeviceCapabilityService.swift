import Foundation
import Darwin  // provides os_proc_available_memory on iOS via Darwin umbrella

/// Detects and caches device hardware specs.
/// Chip + RAM read once at initialize(). Storage queried on demand (changes over time).
///
/// Usage: call `await service.initialize()` at app launch before any compatibility checks.
public actor DeviceCapabilityService {

    // MARK: - Public interface

    /// Cached device specs. Nil until initialize() completes.
    public private(set) var specs: DeviceSpecs?

    /// Re-queries available storage from the file system.
    /// Called before download decisions (D-06: storage re-checked before each download).
    public var availableStorage: UInt64 {
        get async throws {
            let url = URL(fileURLWithPath: NSHomeDirectory())
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            guard let capacity = values.volumeAvailableCapacityForImportantUsage else {
                throw DeviceCapabilityError.storageQueryFailed
            }
            return UInt64(capacity)
        }
    }

    public init() {}

    /// Reads chip, RAM, and OS version. Must be called at app launch before any model compatibility checks.
    /// Safe to call multiple times — subsequent calls refresh the cached specs.
    public func initialize() async {
        let machineID = machineIdentifier()
        let physicalRAM = ProcessInfo.processInfo.physicalMemory
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion

        let profile = ChipLookupTable.profile(for: machineID)
        let jetsamBudget = computeJetsamBudget(
            chipProfile: profile,
            physicalRAM: physicalRAM
        )

        specs = DeviceSpecs(
            chipIdentifier: machineID,
            chipProfile: profile ?? unknownChipProfile(physicalRAM: physicalRAM, jetsam: jetsamBudget),
            physicalRAM: physicalRAM,
            jetsamBudget: jetsamBudget,
            osVersion: osVersion
        )
    }

    // MARK: - Private helpers

    /// Reads hw.machine via sysctlbyname.
    /// Returns "unknown" if the call fails (should never happen on real hardware).
    private func machineIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    /// Three-layer hierarchy for jetsam budget (Claude's discretion per CONTEXT.md):
    /// 1. Chip table value (primary — encodes hardware knowledge)
    /// 2. os_proc_available_memory() as runtime floor — if runtime < table, use runtime
    /// 3. 40% of physicalRAM for unknown chips (D-05 fallback)
    private func computeJetsamBudget(chipProfile: ChipProfile?, physicalRAM: UInt64) -> UInt64 {
        // Baseline: runtime available memory (call at launch before any allocation)
        // ANTI-PATTERN WARNING: do NOT call after loading a model — will give misleadingly low value
        let runtimeAvailable = UInt64(os_proc_available_memory())

        if let profile = chipProfile {
            // Known chip: use table value, floored by runtime reading
            // min() ensures we use the most conservative of the two
            return min(profile.jetsamBudgetBytes, runtimeAvailable > 0 ? runtimeAvailable : profile.jetsamBudgetBytes)
        } else {
            // Unknown chip (D-05): flat 40% rule — conservative but never blocks new devices
            let conservativeFallback = physicalRAM * 4 / 10
            return runtimeAvailable > 0 ? min(runtimeAvailable, conservativeFallback) : conservativeFallback
        }
    }

    /// Constructs a synthetic ChipProfile for unknown chips using only runtime data.
    private func unknownChipProfile(physicalRAM: UInt64, jetsam: UInt64) -> ChipProfile {
        // Assume "at least as good as" the most recent known generation (A18 Pro baseline, D-05)
        // Use A18 speed bands as conservative estimate — unknown new device won't be slower
        let bands = SpeedBands(small3B: 25...55, medium7B: 12...28, large13B: 5...14)
        return ChipProfile(
            generation: .unknown,
            physicalRAMBytes: physicalRAM,
            jetsamBudgetBytes: jetsam,
            neuralEngine: .unknown,
            contextWindowCap: 2048,  // Safe default for unknown chips
            speedBands: bands
        )
    }
}

// MARK: - Errors

public enum DeviceCapabilityError: Error, LocalizedError {
    case storageQueryFailed
    case notInitialized

    public var errorDescription: String? {
        switch self {
        case .storageQueryFailed: return "Could not query available device storage"
        case .notInitialized: return "DeviceCapabilityService not initialized — call initialize() at launch"
        }
    }
}
