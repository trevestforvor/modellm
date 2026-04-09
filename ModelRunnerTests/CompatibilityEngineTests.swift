import Testing
import Foundation
@testable import ModelRunner

// MARK: - Test fixtures

/// A15-class device (6GB physical, 5GB jetsam, n_ctx=1024)
private func makeA15DeviceSpecs() -> DeviceSpecs {
    let bands = SpeedBands(small3B: 15...30, medium7B: 6...14, large13B: 2...6)
    let profile = ChipProfile(
        generation: .a15,
        physicalRAMBytes: 6 * 1024 * 1024 * 1024,
        jetsamBudgetBytes: 5 * 1024 * 1024 * 1024,  // 5GB
        neuralEngine: .gen4,
        contextWindowCap: 1024,
        speedBands: bands
    )
    return DeviceSpecs(
        chipIdentifier: "iPhone14,5",
        chipProfile: profile,
        physicalRAM: 6 * 1024 * 1024 * 1024,
        jetsamBudget: 5 * 1024 * 1024 * 1024,
        osVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
    )
}

/// A18Pro-class device (8GB physical, 7GB jetsam, n_ctx=4096)
private func makeA18ProDeviceSpecs() -> DeviceSpecs {
    let bands = SpeedBands(small3B: 30...60, medium7B: 15...30, large13B: 7...15)
    let profile = ChipProfile(
        generation: .a18Pro,
        physicalRAMBytes: 8 * 1024 * 1024 * 1024,
        jetsamBudgetBytes: 7 * 1024 * 1024 * 1024,
        neuralEngine: .gen5,
        contextWindowCap: 4096,
        speedBands: bands
    )
    return DeviceSpecs(
        chipIdentifier: "iPhone17,3",
        chipProfile: profile,
        physicalRAM: 8 * 1024 * 1024 * 1024,
        jetsamBudget: 7 * 1024 * 1024 * 1024,
        osVersion: OperatingSystemVersion(majorVersion: 18, minorVersion: 0, patchVersion: 0)
    )
}

// MARK: - Tests

@Suite("CompatibilityEngine")
struct CompatibilityEngineTests {

    // MARK: DEVC-02: Hard block

    @Test("model exceeding jetsam budget returns incompatible with exceedsRAMBudget reason")
    func testHardBlock() {
        // Large 13B Q5_K_M: ~8.5GB weights → definitely exceeds 5GB A15 jetsam
        let model = ModelMetadata(
            name: "Llama-13B-Q5_K_M",
            fileSizeBytes: 9_126_805_504,   // ~8.5GB file → ~8.1GB weights
            parameterCount: 13_000_000_000,
            quantizationType: .q5KM,
            layerCount: 40,
            embeddingDim: 5120
        )
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        let result = engine.evaluate(model)

        guard case .incompatible(let reason) = result else {
            Issue.record("Expected .incompatible, got \(result)")
            return
        }
        guard case .exceedsRAMBudget(let required, let available) = reason else {
            Issue.record("Expected .exceedsRAMBudget reason, got \(reason)")
            return
        }
        #expect(required > available, "Required RAM must exceed available jetsam budget")
        #expect(available == 5 * 1024 * 1024 * 1024, "Available should be A15 jetsam = 5GB")
    }

    @Test("model within budget on high-end device returns runsWell or runsSlowly (not incompatible)")
    func testRunsWellOnHighEndDevice() {
        // 3B Q4_K_M on A18Pro — small model, high-end device
        let model = ModelMetadata(
            name: "Qwen2.5-3B-Q4_K_M",
            fileSizeBytes: 1_879_048_192,   // ~1.75GB
            parameterCount: 3_000_000_000,
            quantizationType: .q4KM,
            layerCount: 36,
            embeddingDim: 2048
        )
        let engine = CompatibilityEngine(device: makeA18ProDeviceSpecs())
        let result = engine.evaluate(model)

        if case .incompatible(let reason) = result {
            Issue.record("Expected runsWell or runsSlowly, got .incompatible(\(reason))")
        }
    }

    // MARK: DEVC-03: Soft warn

    @Test("model within budget but slow speed returns runsSlowly")
    func testSoftWarn() {
        // Construct device with very slow speed bands to guarantee slow result
        let slowBands = SpeedBands(small3B: 0...4, medium7B: 0...4, large13B: 0...4)
        let slowProfile = ChipProfile(
            generation: .a15,
            physicalRAMBytes: 6 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 5 * 1024 * 1024 * 1024,
            neuralEngine: .gen4,
            contextWindowCap: 1024,
            speedBands: slowBands  // upper bound 4 < 5 threshold → isSlow = true
        )
        let slowDevice = DeviceSpecs(
            chipIdentifier: "iPhone14,5",
            chipProfile: slowProfile,
            physicalRAM: 6 * 1024 * 1024 * 1024,
            jetsamBudget: 5 * 1024 * 1024 * 1024,
            osVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
        )
        // Small 1B model — fits in budget easily, but speed band is slow
        let model = ModelMetadata(
            name: "TinyModel-Q4_K_M",
            fileSizeBytes: 536_870_912,   // 512MB — fits in 5GB jetsam easily
            parameterCount: 1_000_000_000,
            quantizationType: .q4KM,
            layerCount: 16,
            embeddingDim: 2048
        )
        let engine = CompatibilityEngine(device: slowDevice)
        let result = engine.evaluate(model)

        guard case .runsSlowly = result else {
            Issue.record("Expected .runsSlowly for model with slow speed bands, got \(result)")
            return
        }
    }

    @Test("runsSlowly warning message is non-empty")
    func testSoftWarnHasMessage() {
        let slowBands = SpeedBands(small3B: 0...4, medium7B: 0...4, large13B: 0...4)
        let slowProfile = ChipProfile(
            generation: .a15,
            physicalRAMBytes: 6 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 5 * 1024 * 1024 * 1024,
            neuralEngine: .gen4,
            contextWindowCap: 1024,
            speedBands: slowBands
        )
        let slowDevice = DeviceSpecs(
            chipIdentifier: "iPhone14,5",
            chipProfile: slowProfile,
            physicalRAM: 6 * 1024 * 1024 * 1024,
            jetsamBudget: 5 * 1024 * 1024 * 1024,
            osVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
        )
        let model = ModelMetadata(
            name: "TinyModel", fileSizeBytes: 536_870_912,
            parameterCount: 1_000_000_000, quantizationType: .q4KM,
            layerCount: 16, embeddingDim: 2048
        )
        let engine = CompatibilityEngine(device: slowDevice)
        if case .runsSlowly(_, let warning) = engine.evaluate(model) {
            #expect(!warning.isEmpty, "runsSlowly must include a non-empty warning message")
        }
    }

    // MARK: DEVC-04: Storage description

    @Test("storage impact description formats as 'Uses X.X GB, you have Y.Y GB free'")
    func testStorageDescription() {
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        // 4.2GB model, 6.1GB free
        let modelBytes: UInt64 = UInt64(4.2 * 1_073_741_824)
        let freeBytes: UInt64 = UInt64(6.1 * 1_073_741_824)
        let description = engine.storageImpactDescription(modelBytes: modelBytes, availableBytes: freeBytes)
        #expect(description == "Uses 4.2 GB, you have 6.1 GB free", "Expected exact format match, got: \(description)")
    }

    @Test("storage description handles 1GB boundary correctly")
    func testStorageDescriptionSmallModel() {
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        let modelBytes: UInt64 = 1_073_741_824     // exactly 1.0 GB
        let freeBytes: UInt64 = 10 * 1_073_741_824  // 10.0 GB
        let desc = engine.storageImpactDescription(modelBytes: modelBytes, availableBytes: freeBytes)
        #expect(desc == "Uses 1.0 GB, you have 10.0 GB free")
    }

    // MARK: DEVC-06: KV cache inclusion

    @Test("KV cache bytes computed correctly for Llama 8B at n_ctx=2048")
    func testKVCacheIncluded() {
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        // From RESEARCH.md verified example: 2 × 32 × 2048 × 4096 × 2 = 1,073,741,824
        let kv = engine.kvCacheBytes(nLayers: 32, nCtx: 2048, nEmbd: 4096, bytesPerElement: 2)
        #expect(kv == 1_073_741_824, "KV cache for 32 layers, n_ctx=2048, embd=4096, fp16 must be exactly 1GB")
    }

    @Test("KV cache bytes scale linearly with context window")
    func testKVCacheScalesWithContext() {
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        let kv1024 = engine.kvCacheBytes(nLayers: 32, nCtx: 1024, nEmbd: 4096, bytesPerElement: 2)
        let kv2048 = engine.kvCacheBytes(nLayers: 32, nCtx: 2048, nEmbd: 4096, bytesPerElement: 2)
        #expect(kv2048 == kv1024 * 2, "KV cache must scale linearly with context window size")
    }

    @Test("evaluate() includes KV cache in RAM total — model that fits weights-only but fails with KV is incompatible")
    func testKVCacheInRAMBudget() {
        // Device with tight jetsam budget: 4.5GB — fits 4GB weights but not 4GB + 1GB KV
        let tightBands = SpeedBands(small3B: 20...40, medium7B: 10...20, large13B: 5...10)
        let tightProfile = ChipProfile(
            generation: .a15,
            physicalRAMBytes: 6 * 1024 * 1024 * 1024,
            jetsamBudgetBytes: 4_831_838_208,   // 4.5GB
            neuralEngine: .gen4,
            contextWindowCap: 2048,             // n_ctx = 2048 → KV cache ~1GB for 7B
            speedBands: tightBands
        )
        let tightDevice = DeviceSpecs(
            chipIdentifier: "iPhone14,5",
            chipProfile: tightProfile,
            physicalRAM: 6 * 1024 * 1024 * 1024,
            jetsamBudget: 4_831_838_208,
            osVersion: OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)
        )
        // 7B Q4_K_M: ~4.3GB weights — passes weights-only check against 4.5GB budget
        // But KV cache at n_ctx=2048 adds ~1GB → total ~5.3GB → exceeds 4.5GB → incompatible
        let model = ModelMetadata(
            name: "Llama-7B-Q4_K_M",
            fileSizeBytes: 4_508_876_800,   // ~4.2GB file → ~4.0GB weights after GGUF header strip
            parameterCount: 7_000_000_000,
            quantizationType: .q4KM,
            layerCount: 32,
            embeddingDim: 4096
        )
        let engine = CompatibilityEngine(device: tightDevice)
        let result = engine.evaluate(model)

        guard case .incompatible = result else {
            Issue.record("Expected .incompatible because KV cache pushes total RAM over budget, got \(result)")
            return
        }
    }

    // MARK: D-03: Indeterminate metadata

    @Test("model with nil fileSizeBytes and nil parameterCount returns incompatible(.indeterminateMetadata)")
    func testIndeterminateMetadataIsBlocked() {
        // D-03: Conservative safety — block models we can't evaluate
        let model = ModelMetadata(
            name: "Unknown-Model",
            fileSizeBytes: nil,
            parameterCount: nil,
            quantizationType: .unknown
        )
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        let result = engine.evaluate(model)

        guard case .incompatible(let reason) = result else {
            Issue.record("Expected .incompatible for indeterminate metadata, got \(result)")
            return
        }
        guard case .indeterminateMetadata = reason else {
            Issue.record("Expected .indeterminateMetadata reason, got \(reason)")
            return
        }
    }

    @Test("model with nil fileSizeBytes but known paramCount uses D-10 best-effort estimation")
    func testBestEffortEstimation() {
        // D-10: estimate from param count × quant type bytes/weight (don't block)
        // 3B Q4_K_M: 3B × 0.5 bytes/weight = 1.5GB — fits in 5GB A15 jetsam easily
        let model = ModelMetadata(
            name: "Model-without-filesize",
            fileSizeBytes: nil,     // No file size from API
            parameterCount: 3_000_000_000,
            quantizationType: .q4KM,  // 0.5 bytes/weight
            layerCount: 32,
            embeddingDim: 2560
        )
        let engine = CompatibilityEngine(device: makeA15DeviceSpecs())
        let result = engine.evaluate(model)

        // Should not be .incompatible(.indeterminateMetadata) — we have param count
        if case .incompatible(let reason) = result, case .indeterminateMetadata = reason {
            Issue.record("D-10: Model with known paramCount must not return .indeterminateMetadata")
        }
        // Result should be runsWell or runsSlowly — not a hard block from unknown size
    }
}
