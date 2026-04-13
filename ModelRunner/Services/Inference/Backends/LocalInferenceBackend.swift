import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "LocalInferenceBackend")

public final class LocalInferenceBackend: InferenceBackend, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let source: ModelSource = .local

    private let inferenceService: InferenceService
    private let inferenceParams: InferenceParams
    private let modelURL: URL
    private(set) var isLoaded: Bool = false

    public init(
        repoId: String,
        displayName: String,
        modelURL: URL,
        inferenceService: InferenceService,
        inferenceParams: InferenceParams
    ) {
        self.id = repoId
        self.displayName = displayName
        self.modelURL = modelURL
        self.inferenceService = inferenceService
        self.inferenceParams = inferenceParams
    }

    public var modelIdentity: String { "local:\(id)" }

    public func loadModel() async throws {
        try await inferenceService.loadModel(at: modelURL, params: inferenceParams)
        isLoaded = true
    }

    public func generate(
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> AsyncThrowingStream<StreamToken, Error> {
        let prompt = PromptFormatter.chatml(system: params.systemPrompt, messages: messages)

        return AsyncThrowingStream { continuation in
            Task.detached { [weak self] in
                guard let self else { continuation.finish(); return }
                let stream = await self.inferenceService.generate(prompt: prompt, params: params)
                do {
                    for try await token in stream {
                        continuation.yield(.content(token))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func stop() async {
        await inferenceService.stopGeneration()
    }
}
