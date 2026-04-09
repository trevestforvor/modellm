import Foundation

/// Parameters for configuring a llama.cpp inference context and sampler chain.
/// contextWindowTokens comes from ChipProfile.contextWindowCap.
/// temperature and topP come from DownloadedModel per-model settings.
public struct InferenceParams: Sendable {
    public let contextWindowTokens: Int32
    public let batchSize: Int32
    public let gpuLayers: Int32
    // Phase 5: sampling parameters
    public let temperature: Float
    public let topP: Float
    public let systemPrompt: String

    public static func `default`(contextWindowCap: Int) -> InferenceParams {
        InferenceParams(
            contextWindowTokens: Int32(contextWindowCap),
            batchSize: 512,
            gpuLayers: 99,
            temperature: 0.7,
            topP: 0.9,
            systemPrompt: "You are a helpful assistant."
        )
    }

    /// Build InferenceParams from a DownloadedModel's stored settings.
    static func from(model: DownloadedModel, contextWindowCap: Int) -> InferenceParams {
        InferenceParams(
            contextWindowTokens: Int32(contextWindowCap),
            batchSize: 512,
            gpuLayers: 99,
            temperature: Float(model.temperature),
            topP: Float(model.topP),
            systemPrompt: model.systemPrompt
        )
    }

    public init(
        contextWindowTokens: Int32,
        batchSize: Int32,
        gpuLayers: Int32,
        temperature: Float = 0.7,
        topP: Float = 0.9,
        systemPrompt: String = "You are a helpful assistant."
    ) {
        self.contextWindowTokens = contextWindowTokens
        self.batchSize = batchSize
        self.gpuLayers = gpuLayers
        self.temperature = temperature
        self.topP = topP
        self.systemPrompt = systemPrompt
    }
}
