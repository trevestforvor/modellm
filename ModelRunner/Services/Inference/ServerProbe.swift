import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ServerProbe")

/// Thinking capability of a model, detected during server probe.
public enum ThinkingCapability: String, Codable, Sendable {
    /// Model does not produce reasoning_content
    case none
    /// Model always produces reasoning_content — toggle only controls display
    case alwaysOn
    /// Model respects enable_thinking param — toggle controls server behavior
    case toggleable
}

public enum ServerProbe {

    public struct ProbeResult: Sendable {
        public let models: [String]
        public let supportedFormats: [APIFormat]
        /// Thinking capability per model ID (only tested for the probe model)
        public let thinkingCapabilities: [String: ThinkingCapability]
    }

    public static func probe(
        baseURL: URL,
        apiKey: String? = nil,
        manualModelID: String? = nil,
        timeoutSeconds: TimeInterval = 30
    ) async throws -> ProbeResult {
        var models: [String] = []
        do {
            models = try await discoverModels(baseURL: baseURL, apiKey: apiKey, timeout: timeoutSeconds)
            logger.info("Discovered \(models.count) models on \(baseURL.absoluteString)")
        } catch {
            logger.warning("Model discovery failed: \(error.localizedDescription)")
        }

        guard let probeModel = models.first ?? manualModelID else {
            throw ProbeError.noModelsFound
        }

        let (formats, thinkingCaps) = await probeFormats(
            baseURL: baseURL, model: probeModel, apiKey: apiKey, timeout: timeoutSeconds
        )

        guard !formats.isEmpty else {
            throw ProbeError.noFormatsDetected
        }

        return ProbeResult(
            models: models,
            supportedFormats: formats.sorted { $0.priority < $1.priority },
            thinkingCapabilities: thinkingCaps
        )
    }

    // MARK: - Phase 1: Model Discovery

    static func discoverModels(baseURL: URL, apiKey: String?, timeout: TimeInterval) async throws -> [String] {
        let url = baseURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ProbeError.modelDiscoveryFailed
        }

        return try parseModelsResponse(data)
    }

    static func parseModelsResponse(_ data: Data) throws -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProbeError.invalidResponse
        }

        var modelIDs: [String] = []

        if let dataArray = json["data"] as? [[String: Any]] {
            modelIDs.append(contentsOf: dataArray.compactMap { $0["id"] as? String })
        }

        if let modelsArray = json["models"] as? [[String: Any]] {
            let ollamaNames = modelsArray.compactMap { $0["name"] as? String }
            for name in ollamaNames where !modelIDs.contains(name) {
                modelIDs.append(name)
            }
        }

        return modelIDs
    }

    // MARK: - Phase 2: Format Probing + Thinking Detection

    private static func probeFormats(
        baseURL: URL, model: String, apiKey: String?, timeout: TimeInterval
    ) async -> ([APIFormat], [String: ThinkingCapability]) {
        let thinkingDetector = ThinkingDetector()

        let formats = await withTaskGroup(of: APIFormat?.self) { group in
            let adapters: [(APIFormat, any APIAdapter)] = [
                (.openAIChat, OpenAIChatAdapter()),
                (.openAILegacy, OpenAILegacyAdapter()),
                (.anthropicMessages, AnthropicMessagesAdapter())
            ]

            for (format, adapter) in adapters {
                group.addTask {
                    do {
                        let dummyMessage = ChatMessage(role: .user, content: "hi")
                        let params = InferenceParams.default(contextWindowCap: 2048)
                        var request = adapter.buildRequest(
                            baseURL: baseURL, model: model, messages: [dummyMessage],
                            params: params, enableThinking: false, apiKey: apiKey
                        )
                        request.timeoutInterval = timeout

                        if var body = request.httpBody,
                           var json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                            json["stream"] = false
                            json["max_tokens"] = 1
                            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
                        }

                        let (data, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                            logger.info("Format \(format.rawValue) supported on \(baseURL.absoluteString)")

                            // Phase 3: Detect thinking capability (only for OpenAI Chat format)
                            if format == .openAIChat {
                                let thinksWithoutFlag = responseHasThinking(data)

                                if thinksWithoutFlag {
                                    // Model thinks by default — check if we can disable it
                                    let canToggle = await probeThinkingToggle(
                                        baseURL: baseURL, model: model, apiKey: apiKey, timeout: timeout
                                    )
                                    await thinkingDetector.set(
                                        model: model,
                                        capability: canToggle ? .toggleable : .alwaysOn
                                    )
                                    logger.info("Thinking: \(canToggle ? "toggleable" : "always on") for \(model)")
                                }
                                // If no thinking in default response → .none (not stored)
                            }

                            return format
                        }
                    } catch {
                        logger.debug("Format \(format.rawValue) probe failed: \(error.localizedDescription)")
                    }
                    return nil
                }
            }

            var supported: [APIFormat] = []
            for await result in group {
                if let format = result { supported.append(format) }
            }
            return supported
        }

        let caps = await thinkingDetector.capabilities
        return (formats, caps)
    }

    // MARK: - Thinking Toggle Detection

    /// Send a second request with enable_thinking=false to see if the model respects it.
    private static func probeThinkingToggle(
        baseURL: URL, model: String, apiKey: String?, timeout: TimeInterval
    ) async -> Bool {
        let adapter = OpenAIChatAdapter()
        let dummyMessage = ChatMessage(role: .user, content: "hi")
        let params = InferenceParams.default(contextWindowCap: 2048)

        // Build request with enable_thinking explicitly false
        var request = adapter.buildRequest(
            baseURL: baseURL, model: model, messages: [dummyMessage],
            params: params, enableThinking: false, apiKey: apiKey
        )
        request.timeoutInterval = timeout

        // Override: non-streaming, max_tokens=1, and explicitly add enable_thinking=false
        if var body = request.httpBody,
           var json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            json["stream"] = false
            json["max_tokens"] = 1
            json["enable_thinking"] = false
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            // If this request does NOT have reasoning_content, the toggle works
            return !responseHasThinking(data)
        } catch {
            return false
        }
    }

    /// Check if a chat completion response contains non-empty reasoning_content
    private static func responseHasThinking(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            return false
        }
        // Check for reasoning_content — present and non-empty
        if let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Thinking Detector Actor

    private actor ThinkingDetector {
        var capabilities: [String: ThinkingCapability] = [:]
        func set(model: String, capability: ThinkingCapability) {
            capabilities[model] = capability
        }
    }

    // MARK: - Errors

    public enum ProbeError: LocalizedError {
        case noModelsFound
        case noFormatsDetected
        case modelDiscoveryFailed
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .noModelsFound: return "No models found on server. Try entering a model ID manually."
            case .noFormatsDetected: return "Server did not respond to any known API format."
            case .modelDiscoveryFailed: return "Could not query server's model list."
            case .invalidResponse: return "Server returned an unexpected response."
            }
        }
    }
}
