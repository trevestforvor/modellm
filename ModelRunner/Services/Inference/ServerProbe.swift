import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ServerProbe")

public enum ServerProbe {

    public struct ProbeResult: Sendable {
        public let models: [String]
        public let supportedFormats: [APIFormat]
        public let thinkingModelIDs: Set<String>
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

        let (formats, thinkingModels) = await probeFormats(
            baseURL: baseURL, model: probeModel, apiKey: apiKey, timeout: timeoutSeconds
        )

        guard !formats.isEmpty else {
            throw ProbeError.noFormatsDetected
        }

        return ProbeResult(
            models: models,
            supportedFormats: formats.sorted { $0.priority < $1.priority },
            thinkingModelIDs: thinkingModels
        )
    }

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

    private static func probeFormats(
        baseURL: URL, model: String, apiKey: String?, timeout: TimeInterval
    ) async -> ([APIFormat], Set<String>) {
        let thinkingDetected = ThinkingDetector()

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

                            if format == .openAIChat {
                                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let choices = json["choices"] as? [[String: Any]],
                                   let message = choices.first?["message"] as? [String: Any],
                                   message["reasoning_content"] != nil {
                                    await thinkingDetected.markThinking(model: model)
                                }
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

        let thinkingModels = await thinkingDetected.models
        return (formats, thinkingModels)
    }

    private actor ThinkingDetector {
        var models: Set<String> = []
        func markThinking(model: String) { models.insert(model) }
    }

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
