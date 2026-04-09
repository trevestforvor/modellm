import Foundation

/// Evaluates model compatibility against device specs. Pure function — no I/O, no async, O(1).
/// Instantiate with DeviceSpecs (from DeviceCapabilityService) and call evaluate() for each model.
public struct CompatibilityEngine {

    /// The device this engine evaluates against. Set once at init.
    public let device: DeviceSpecs

    public init(device: DeviceSpecs) {
        self.device = device
    }

    // MARK: - Primary evaluation

    /// Returns a three-tier compatibility verdict for the given model.
    /// D-01: .incompatible models should be hidden from browse UI — not shown with a badge.
    public func evaluate(_ model: ModelMetadata) -> CompatibilityResult {
        // Step 1: Resolve RAM required (weights + KV cache)
        // D-10: if fileSizeBytes is nil, try estimating from paramCount + quantType
        guard let ramNeeded = totalRAMRequired(model) else {
            // D-03: if we can't determine size at all, block conservatively
            return .incompatible(reason: .indeterminateMetadata)
        }

        // Step 2: Hard RAM check — DEVC-02
        // ANTI-PATTERN GUARD: Compare against jetsamBudget, NEVER physicalRAM
        guard ramNeeded <= device.jetsamBudget else {
            return .incompatible(reason: .exceedsRAMBudget(required: ramNeeded, available: device.jetsamBudget))
        }

        // Step 3: Soft tier check — D-02: composite score uses speed AND RAM headroom
        let speedEstimate = estimatedSpeed(model)
        let ramHeadroom = Double(device.jetsamBudget - ramNeeded) / Double(device.jetsamBudget)

        // Composite slow: either speed is in slow band OR RAM headroom < 15%
        let isSpeedSlow = isSlow(tokenRange: speedEstimate)
        let isRAMTight = ramHeadroom < 0.15

        if isSpeedSlow || isRAMTight {
            let warning = isRAMTight
                ? "Model uses \(Int(ramHeadroom * 100))% of available memory — may run slowly or be terminated under load"
                : "Expected token speed on this device is below comfortable chat speed"
            return .runsSlowly(estimatedTokensPerSec: speedEstimate, warning: warning)
        }

        return .runsWell(estimatedTokensPerSec: speedEstimate)
    }

    // MARK: - Storage impact (DEVC-04)

    /// Returns a human-readable storage impact string.
    /// Example: "Uses 4.2 GB, you have 6.1 GB free"
    public func storageImpactDescription(modelBytes: UInt64, availableBytes: UInt64) -> String {
        let modelGB = Double(modelBytes) / 1_073_741_824
        let availableGB = Double(availableBytes) / 1_073_741_824
        return String(format: "Uses %.1f GB, you have %.1f GB free", modelGB, availableGB)
    }

    // MARK: - KV cache math (DEVC-06)

    /// KV cache memory formula.
    /// Source: llama.cpp internals, confirmed in RESEARCH.md.
    /// Formula: 2 tensors (K + V) × layers × context_length × embedding_dim × bytes_per_element
    ///
    /// Example: Llama 3 8B, nLayers=32, nEmbd=4096, n_ctx=2048, 2 bytes/element (fp16 KV)
    /// = 2 × 32 × 2048 × 4096 × 2 = 1,073,741,824 bytes ≈ 1 GB
    public func kvCacheBytes(nLayers: Int, nCtx: Int, nEmbd: Int, bytesPerElement: Int = 2) -> UInt64 {
        UInt64(2 * nLayers * nCtx * nEmbd * bytesPerElement)
    }

    // MARK: - Private helpers

    /// Total RAM = weights + KV cache at device's fixed n_ctx (D-07, D-08).
    /// Returns nil if neither file size nor param count can be resolved (triggers D-03).
    private func totalRAMRequired(_ model: ModelMetadata) -> UInt64? {
        // Resolve weight bytes: prefer estimatedWeightBytes (from fileSizeBytes),
        // fall back to param count × bytes/weight (D-10 best-effort estimation)
        let weightBytes: UInt64
        if let fromFileSize = model.estimatedWeightBytes {
            weightBytes = fromFileSize
        } else if let paramCount = model.parameterCount {
            // D-10: estimate from param count × quant type bytes/weight
            weightBytes = UInt64(Double(paramCount) * model.quantizationType.bytesPerWeight)
        } else {
            // D-03: truly indeterminate — no file size and no param count
            return nil
        }

        // If we have layer count and embedding dim, include KV cache (D-08)
        if let nLayers = model.layerCount, let nEmbd = model.embeddingDim {
            let nCtx = device.chipProfile.contextWindowCap  // D-07: fixed per device tier
            let kv = kvCacheBytes(nLayers: nLayers, nCtx: nCtx, nEmbd: nEmbd)
            return weightBytes + kv
        }

        // If GGUF metadata is incomplete (no layer/embedding data), use weight bytes alone.
        // This is a conservative approximation — may under-count RAM by ~15-20%.
        // Still better than blocking the model entirely (D-10 best effort).
        return weightBytes
    }

    /// Estimates token speed range based on model parameter count and device chip speed bands.
    private func estimatedSpeed(_ model: ModelMetadata) -> ClosedRange<Float> {
        let bands = device.chipProfile.speedBands
        guard let params = model.parameterCount else {
            // Unknown param count — use 7B band as safe middle estimate
            return bands.medium7B
        }
        switch params {
        case ..<4_000_000_000:
            return bands.small3B
        case 4_000_000_000..<10_000_000_000:
            return bands.medium7B
        default:
            return bands.large13B
        }
    }

    /// Returns true if the token speed range falls below the "comfortable chat" threshold.
    /// Threshold: upper bound of speed range < 5 tokens/sec.
    /// D-02: composite score — this is one of the two signals (alongside RAM headroom).
    private func isSlow(tokenRange: ClosedRange<Float>) -> Bool {
        return tokenRange.upperBound < 5.0
    }
}
