import XCTest
@testable import ModelRunner

final class OpenAIChatAdapterTests: XCTestCase {

    private let adapter = OpenAIChatAdapter()
    private let baseURL = URL(string: "https://api.example.com")!

    private func makeParams(systemPrompt: String = "") -> InferenceParams {
        InferenceParams(
            contextWindowTokens: 2048,
            batchSize: 512,
            gpuLayers: 99,
            temperature: 0.8,
            topP: 0.95,
            systemPrompt: systemPrompt
        )
    }

    private func makeMessages() -> [ChatMessage] {
        [ChatMessage(role: .user, content: "Hello")]
    }

    // MARK: - buildRequest tests

    func testBuildRequest_setsCorrectEndpoint() {
        let request = adapter.buildRequest(
            baseURL: baseURL,
            model: "gpt-4",
            messages: makeMessages(),
            params: makeParams(),
            enableThinking: false,
            apiKey: nil
        )
        XCTAssertEqual(request.url?.path, "/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testBuildRequest_includesApiKey() {
        let request = adapter.buildRequest(
            baseURL: baseURL,
            model: "gpt-4",
            messages: makeMessages(),
            params: makeParams(),
            enableThinking: false,
            apiKey: "sk-test-key"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key")
    }

    func testBuildRequest_includesTemperatureAndTopP() throws {
        let params = makeParams()
        let request = adapter.buildRequest(
            baseURL: baseURL,
            model: "gpt-4o",
            messages: makeMessages(),
            params: params,
            enableThinking: false,
            apiKey: nil
        )
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["temperature"] as? Float, 0.8)
        XCTAssertEqual(json["top_p"] as? Float, 0.95)
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["model"] as? String, "gpt-4o")
    }

    // MARK: - parseTokenStream tests

    private func collectTokens(_ sseString: String) async throws -> [StreamToken] {
        let lines = sseString.components(separatedBy: "\n")
        return try await adapter.parseSSELines(lines)
    }

    func testParseTokenStream_contentTokens() async throws {
        let sse = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}
        data: {"choices":[{"delta":{"content":" world"}}]}
        data: [DONE]
        """
        let tokens = try await collectTokens(sse)
        XCTAssertEqual(tokens, [.content("Hello"), .content(" world"), .done])
    }

    func testParseTokenStream_reasoningContent() async throws {
        let sse = """
        data: {"choices":[{"delta":{"reasoning_content":"Let me think"}}]}
        data: {"choices":[{"delta":{"content":"The answer"}}]}
        data: [DONE]
        """
        let tokens = try await collectTokens(sse)
        XCTAssertEqual(tokens, [.thinking("Let me think"), .content("The answer"), .done])
    }

    func testParseTokenStream_emptyDeltaSkipped() async throws {
        let sse = """
        data: {"choices":[{"delta":{"role":"assistant"}}]}
        data: {"choices":[{"delta":{"content":"Hi"}}]}
        data: [DONE]
        """
        let tokens = try await collectTokens(sse)
        XCTAssertEqual(tokens, [.content("Hi"), .done])
    }
}
