import Foundation

// MARK: - Chip Identification

public enum ChipGeneration: String, Hashable, Sendable {
    case a15    = "A15"
    case a16    = "A16"
    case a17Pro = "A17 Pro"
    case a18    = "A18"
    case a18Pro = "A18 Pro"
    case unknown = "Unknown"
}

public enum NEGeneration: String, Hashable, Sendable {
    case gen4    = "4th gen"
    case gen5    = "5th gen"
    case unknown = "Unknown"
}

// Token speed estimates per model class (tokens/sec ranges)
public struct SpeedBands: Hashable, Sendable {
    public let small3B: ClosedRange<Float>   // 3B param class
    public let medium7B: ClosedRange<Float>  // 7B param class
    public let large13B: ClosedRange<Float>  // 13B+ param class

    public init(small3B: ClosedRange<Float>, medium7B: ClosedRange<Float>, large13B: ClosedRange<Float>) {
        self.small3B = small3B
        self.medium7B = medium7B
        self.large13B = large13B
    }
}

// MARK: - Device Representation

public struct ChipProfile: Hashable, Sendable {
    public let generation: ChipGeneration
    public let physicalRAMBytes: UInt64
    /// Jetsam budget WITH increased-memory-limit entitlement
    public let jetsamBudgetBytes: UInt64
    public let neuralEngine: NEGeneration
    /// Max safe n_ctx for this chip tier (D-07: fixed per device tier, not user-adjustable)
    public let contextWindowCap: Int
    public let speedBands: SpeedBands

    public init(
        generation: ChipGeneration,
        physicalRAMBytes: UInt64,
        jetsamBudgetBytes: UInt64,
        neuralEngine: NEGeneration,
        contextWindowCap: Int,
        speedBands: SpeedBands
    ) {
        self.generation = generation
        self.physicalRAMBytes = physicalRAMBytes
        self.jetsamBudgetBytes = jetsamBudgetBytes
        self.neuralEngine = neuralEngine
        self.contextWindowCap = contextWindowCap
        self.speedBands = speedBands
    }
}

public struct DeviceSpecs: Sendable {
    /// Raw hw.machine string, e.g. "iPhone17,2"
    public let chipIdentifier: String
    /// Looked up from ChipLookupTable; .unknown profile if not in table
    public let chipProfile: ChipProfile
    public let physicalRAM: UInt64
    /// Effective memory budget for model loading (weights + KV cache must fit within this)
    /// Primary: chip table value. Floor: os_proc_available_memory(). Fallback: 40% of physicalRAM.
    public let jetsamBudget: UInt64
    public let osVersion: OperatingSystemVersion

    public init(
        chipIdentifier: String,
        chipProfile: ChipProfile,
        physicalRAM: UInt64,
        jetsamBudget: UInt64,
        osVersion: OperatingSystemVersion
    ) {
        self.chipIdentifier = chipIdentifier
        self.chipProfile = chipProfile
        self.physicalRAM = physicalRAM
        self.jetsamBudget = jetsamBudget
        self.osVersion = osVersion
    }
}

// MARK: - Model Metadata

public enum QuantizationType: String, Hashable, Sendable, CaseIterable {
    case q2K   = "Q2_K"
    case q3KS  = "Q3_K_S"
    case q3KM  = "Q3_K_M"
    case q4_0  = "Q4_0"
    case q4KS  = "Q4_K_S"
    case q4KM  = "Q4_K_M"
    case q5KM  = "Q5_K_M"
    case q6K   = "Q6_K"
    case q8_0  = "Q8_0"
    case f16   = "F16"
    case unknown = "Unknown"

    /// Approximate bytes per weight parameter — used for cross-checking file size vs param count (D-09)
    public var bytesPerWeight: Double {
        switch self {
        case .q2K:   return 0.313  // ~2.5 bits/weight
        case .q3KS:  return 0.375
        case .q3KM:  return 0.375
        case .q4_0:  return 0.5
        case .q4KS:  return 0.5
        case .q4KM:  return 0.5
        case .q5KM:  return 0.625
        case .q6K:   return 0.75
        case .q8_0:  return 1.0
        case .f16:   return 2.0
        case .unknown: return 0.5  // assume Q4 as best-effort
        }
    }
}

/// Model metadata consumed by CompatibilityEngine. Sourced from GGUF file headers via HF API (Phase 2).
public struct ModelMetadata: Sendable {
    public let name: String
    public let fileSizeBytes: UInt64?       // nil if HF API doesn't provide size
    public let parameterCount: Int?          // nil if not in GGUF metadata
    public let quantizationType: QuantizationType
    public let layerCount: Int?              // n_layers from GGUF header
    public let embeddingDim: Int?            // n_embd from GGUF header

    public init(
        name: String,
        fileSizeBytes: UInt64? = nil,
        parameterCount: Int? = nil,
        quantizationType: QuantizationType = .unknown,
        layerCount: Int? = nil,
        embeddingDim: Int? = nil
    ) {
        self.name = name
        self.fileSizeBytes = fileSizeBytes
        self.parameterCount = parameterCount
        self.quantizationType = quantizationType
        self.layerCount = layerCount
        self.embeddingDim = embeddingDim
    }

    /// Estimated weight bytes: file size minus ~5% GGUF container overhead.
    /// Returns nil if fileSizeBytes is nil (triggers D-03 indeterminate path in engine).
    public var estimatedWeightBytes: UInt64? {
        guard let size = fileSizeBytes else { return nil }
        return UInt64(Double(size) * 0.95)
    }
}

// MARK: - Compatibility Verdict

/// Reason a model cannot run on this device. D-02 hard-block cases.
public enum IncompatibilityReason: Sendable {
    /// Model RAM requirement (weights + KV cache) exceeds device jetsam budget (DEVC-05, DEVC-06)
    case exceedsRAMBudget(required: UInt64, available: UInt64)
    /// Size or params cannot be determined — conservative block per D-03
    case indeterminateMetadata
}

/// Three-tier compatibility result. D-01: won't run = hidden from browse UI.
public enum CompatibilityResult: Sendable {
    /// Model will run with good token throughput
    case runsWell(estimatedTokensPerSec: ClosedRange<Float>)
    /// Model will run but slowly — D-02 composite score triggered soft tier
    case runsSlowly(estimatedTokensPerSec: ClosedRange<Float>, warning: String)
    /// Model cannot run on this device — hidden from browse (D-01)
    case incompatible(reason: IncompatibilityReason)
}

extension CompatibilityResult {
    /// Simplified tier for UI badge rendering (Phase 2)
    public var tier: CompatibilityTier {
        switch self {
        case .runsWell: return .runsWell
        case .runsSlowly: return .runsSlow
        case .incompatible: return .incompatible
        }
    }
}

/// Simplified enum for UI layer — Phase 2 uses this for badge color
public enum CompatibilityTier: Sendable {
    case runsWell     // green
    case runsSlow     // yellow
    case incompatible // hidden — D-01: users never see won't-run models
}
