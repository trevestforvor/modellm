import Foundation

/// Parameters for configuring a llama.cpp inference context.
/// contextWindowTokens comes from ChipProfile.contextWindowCap.
public struct InferenceParams: Sendable {
    public let contextWindowTokens: Int32
    public let batchSize: Int32
    public let gpuLayers: Int32

    public static func `default`(contextWindowCap: Int) -> InferenceParams {
        InferenceParams(
            contextWindowTokens: Int32(contextWindowCap),
            batchSize: 512,
            gpuLayers: 99  // offload all layers to Metal GPU
        )
    }

    public init(contextWindowTokens: Int32, batchSize: Int32, gpuLayers: Int32) {
        self.contextWindowTokens = contextWindowTokens
        self.batchSize = batchSize
        self.gpuLayers = gpuLayers
    }
}
