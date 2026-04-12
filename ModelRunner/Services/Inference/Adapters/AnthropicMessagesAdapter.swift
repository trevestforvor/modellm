import Foundation

/// Skeleton adapter for Anthropic /v1/messages endpoints.
/// P2 priority — compiles and is detectable by ServerProbe, but not production-tested.
public struct AnthropicMessagesAdapter: APIAdapter, Sendable {
    public static let format: APIFormat = .anthropicMessages

    public init() {}

    public func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool,
        apiKey: String?
    ) -> URLRequest {
        let endpoint = baseURL.appendingPathComponent("v1/messages")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let chatMessages = messages.map { msg -> [String: String] in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        var body: [String: Any] = [
            "model": model,
            "messages": chatMessages,
            "max_tokens": 4096,
            "stream": true
        ]

        if !params.systemPrompt.isEmpty {
            body["system"] = params.systemPrompt
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    public func parseTokenStream(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var buffer = ""
                do {
                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        if char == "\n" {
                            let line = buffer
                            buffer = ""
                            if let token = parseLine(line) {
                                if case .done = token {
                                    continuation.yield(.done)
                                    continuation.finish()
                                    return
                                }
                                continuation.yield(token)
                            }
                        } else {
                            buffer.append(char)
                        }
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func parseLine(_ line: String) -> StreamToken? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))

        if payload == "[DONE]" { return .done }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        if type == "message_stop" { return .done }

        if type == "content_block_delta",
           let delta = json["delta"] as? [String: Any] {
            if let text = delta["text"] as? String, !text.isEmpty {
                return .content(text)
            }
        }

        return nil
    }
}
