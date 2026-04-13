import Foundation

/// Adapter for OpenAI-compatible chat completions API (/v1/chat/completions).
/// Supports SSE streaming with reasoning_content (thinking) and content deltas.
public struct OpenAIChatAdapter: APIAdapter, Sendable {

    public static let format: APIFormat = .openAIChat

    public init() {}

    // MARK: - APIAdapter

    public func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool,
        apiKey: String?
    ) -> URLRequest {
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        var messageArray: [[String: String]] = []
        if !params.systemPrompt.isEmpty {
            messageArray.append(["role": "system", "content": params.systemPrompt])
        }
        for msg in messages {
            let role = msg.role == .user ? "user" : "assistant"
            messageArray.append(["role": role, "content": msg.content])
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messageArray,
            "stream": true,
            "temperature": params.temperature,
            "top_p": params.topP,
            "max_tokens": 4096
        ]

        // Signal thinking preference to servers that support it.
        // Servers that don't recognize these params will ignore them safely.
        if enableThinking {
            body["enable_thinking"] = true
            body["reasoning_effort"] = "high"
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    public func parseTokenStream(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        if let token = parseLine(line) {
                            continuation.yield(token)
                            if case .done = token { break }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Internal helpers (accessible for tests)

    /// Parse a single SSE line into a StreamToken, or nil if the line should be skipped.
    func parseLine(_ line: String) -> StreamToken? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))

        if payload == "[DONE]" { return .done }

        guard
            let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let delta = first["delta"] as? [String: Any]
        else { return nil }

        // reasoning_content takes priority (thinking tokens)
        if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
            return .thinking(reasoning)
        }
        // Regular content delta
        if let content = delta["content"] as? String, !content.isEmpty {
            return .content(content)
        }
        // Role-only or empty delta — skip
        return nil
    }

    /// Test helper: parse an array of SSE lines and collect all tokens.
    func parseSSELines(_ lines: [String]) async throws -> [StreamToken] {
        var tokens: [StreamToken] = []
        for line in lines {
            if let token = parseLine(line) {
                tokens.append(token)
                if case .done = token { break }
            }
        }
        return tokens
    }
}
