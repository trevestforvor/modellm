import XCTest
@testable import ModelRunner

final class OpenAILegacyAdapterTests: XCTestCase {

    private let adapter = OpenAILegacyAdapter()
    private let baseURL = URL(string: "https://api.example.com")!

    private func makeParams(systemPrompt: String = "You are helpful.") -> InferenceParams {
        InferenceParams(
            contextWindowTokens: 2048,
            batchSize: 512,
            gpuLayers: 99,
            temperature: 0.7,
            topP: 0.9,
            systemPrompt: systemPrompt
        )
    }

    // MARK: - buildRequest tests

    func testBuildRequest_usesCompletionsEndpoint() {
        let messages = [ChatMessage(role: .user, content: "Hello")]
        let request = adapter.buildRequest(
            baseURL: baseURL,
            model: "text-davinci-003",
            messages: messages,
            params: makeParams(),
            enableThinking: false,
            apiKey: nil
        )
        XCTAssertEqual(request.url?.path, "/v1/completions")
    }

    func testBuildRequest_flattenMessagesToPrompt() throws {
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there")
        ]
        let request = adapter.buildRequest(
            baseURL: baseURL,
            model: "text-davinci-003",
            messages: messages,
            params: makeParams(),
            enableThinking: false,
            apiKey: nil
        )
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        // Must have "prompt" key, not "messages"
        XCTAssertNotNil(json["prompt"] as? String)
        XCTAssertNil(json["messages"])

        let prompt = try XCTUnwrap(json["prompt"] as? String)
        // Should contain all message content
        XCTAssertTrue(prompt.contains("Hello"))
        XCTAssertTrue(prompt.contains("Hi there"))
    }

    // MARK: - parseLine tests

    func testParseLine_extractsText() {
        let line = #"data: {"choices":[{"text":"Hello"}]}"#
        let token = adapter.parseLine(line)
        XCTAssertEqual(token, .content("Hello"))
    }

    func testParseLine_done() {
        let token = adapter.parseLine("data: [DONE]")
        XCTAssertEqual(token, .done)
    }
}
