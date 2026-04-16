import Foundation

/// Adapter for OpenAI-compatible legacy completions API (/v1/completions).
/// Uses a single `prompt` string (ChatML formatted) instead of a messages array.
public struct OpenAILegacyAdapter: APIAdapter, Sendable {

    public static let format: APIFormat = .openAILegacy

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
        let url = baseURL.appendingPathComponent("v1/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let prompt = PromptFormatter.chatml(system: params.systemPrompt, messages: messages)

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true,
            "temperature": params.temperature,
            "top_p": params.topP,
            "max_tokens": 4096
        ]
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
            let text = first["text"] as? String,
            !text.isEmpty
        else { return nil }

        return .content(text)
    }
}
