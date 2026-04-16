# Remote Inference & Unified Model Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add remote server connectivity so users can chat with models running on Ollama/vLLM/llama.cpp servers, behind a unified inference abstraction that on-device inference will slot into later.

**Architecture:** Protocol-based `InferenceBackend` decouples ChatViewModel from inference source. `APIAdapter` protocol handles request building and SSE stream parsing per API format (OpenAI Chat, OpenAI Legacy, Anthropic skeleton). Server connections are SwiftData-persisted; discovered models are transient with usage stats persisted separately.

**Tech Stack:** SwiftUI, SwiftData, URLSession (SSE streaming), async/await, Keychain Services

**Spec:** `docs/superpowers/specs/2026-04-12-remote-inference-and-unified-model-picker-design.md`

**Test Server:** `https://nemo34bone.trevestforvorolares.olares.com` — Nemotron 3 Nano 4B, supports `/v1/chat/completions` and `/v1/completions`, returns `reasoning_content`

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `ModelRunner/Services/Inference/Backends/InferenceBackend.swift` | `InferenceBackend` protocol, `StreamToken` enum, `ModelSource` enum, `SelectedModel` struct |
| `ModelRunner/Services/Inference/Backends/RemoteInferenceBackend.swift` | Remote server conformer — owns URLSessionDataTask, streams via APIAdapter |
| `ModelRunner/Services/Inference/Adapters/APIAdapter.swift` | `APIAdapter` protocol, `APIFormat` enum |
| `ModelRunner/Services/Inference/Adapters/OpenAIChatAdapter.swift` | `/v1/chat/completions` SSE parsing with reasoning_content support |
| `ModelRunner/Services/Inference/Adapters/OpenAILegacyAdapter.swift` | `/v1/completions` SSE parsing |
| `ModelRunner/Services/Inference/Adapters/AnthropicMessagesAdapter.swift` | `/v1/messages` SSE skeleton (P2) |
| `ModelRunner/Services/Inference/ServerProbe.swift` | Two-phase probe: model discovery then format detection |
| `ModelRunner/Services/Keychain/KeychainService.swift` | Keychain CRUD for API keys |
| `ModelRunner/Models/ServerConnection.swift` | SwiftData `@Model` for saved servers |
| `ModelRunner/Models/ModelUsageStats.swift` | SwiftData `@Model` for persisted tok/s across local and remote |
| `ModelRunner/Features/Settings/ServerListView.swift` | Server management list with reachability indicators |
| `ModelRunner/Features/Settings/AddServerView.swift` | Add server flow: name + URL → probe → save |
| `ModelRunner/Features/Settings/ServerDetailView.swift` | Edit server: name, URL, format picker, API key |
| `ModelRunner/Features/ModelPicker/ModelPickerView.swift` | Unified picker: on-device + remote grouped by source |
| `ModelRunner/Features/ModelPicker/ModelPickerViewModel.swift` | Aggregates local DownloadedModels + remote models from servers |
| `ModelRunnerTests/Adapters/OpenAIChatAdapterTests.swift` | SSE parsing tests with recorded responses |
| `ModelRunnerTests/Adapters/OpenAILegacyAdapterTests.swift` | SSE parsing tests |
| `ModelRunnerTests/ServerProbeTests.swift` | Format detection with mock URLSession |
| `ModelRunnerTests/RemoteInferenceBackendTests.swift` | Token stream assembly and cancellation |

### Modified Files

| File | Changes |
|------|---------|
| `ModelRunner/Models/Conversation.swift` | Replace `modelRepoId`/`modelQuantization` with `modelIdentity`/`modelSourceLabel`/`enableThinking` |
| `ModelRunner/Models/ChatMessage.swift` | Add `thinkingContent` property for thinking block display |
| `ModelRunner/Features/Chat/ChatViewModel.swift` | Replace `InferenceService` with `InferenceBackend`, handle `StreamToken`, thinking toggle |
| `ModelRunner/Features/Chat/ChatView.swift` | Model picker sheet, toolbar model display, thinking-aware setup |
| `ModelRunner/Features/Chat/ChatInputBar.swift` | Add thinking toggle button |
| `ModelRunner/Features/Chat/ChatBubbleView.swift` | Collapsible thinking block rendering |
| `ModelRunner/Features/Chat/ChatSettings.swift` | Add `enableThinking` global default |
| `ModelRunner/App/AppContainer.swift` | `selectedModel` state, backend factory, server model discovery |
| `ModelRunner/App/ModelRunnerApp.swift` | Add `ServerConnection` + `ModelUsageStats` to ModelContainer schema, Settings tab |
| `ModelRunner/ContentView.swift` | Add Settings tab, update Chat tab to use selectedModel from AppContainer |

---

## Task 1: Core Types — InferenceBackend Protocol & StreamToken

**Files:**
- Create: `ModelRunner/Services/Inference/Backends/InferenceBackend.swift`

- [ ] **Step 1: Create the InferenceBackend protocol and supporting types**

```swift
// ModelRunner/Services/Inference/Backends/InferenceBackend.swift
import Foundation

// MARK: - Stream Token

/// Structured token from an inference backend.
/// Adapters yield these instead of raw strings so thinking/reasoning content
/// is distinguishable from regular content.
public enum StreamToken: Sendable {
    /// Reasoning/thinking content (e.g., reasoning_content from OpenAI-compatible servers)
    case thinking(String)
    /// Regular assistant content
    case content(String)
    /// Stream finished
    case done
}

// MARK: - Model Source

/// Where a model is running — local on-device or on a remote server.
public enum ModelSource: Hashable, Codable, Sendable {
    case local
    case remote(serverID: UUID)

    var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }
}

// MARK: - Selected Model

/// Persisted model selection — survives app relaunch.
/// Stored in UserDefaults via AppContainer.
public struct SelectedModel: Codable, Sendable, Equatable {
    public let backendID: String
    public let displayName: String
    public let source: ModelSource

    public init(backendID: String, displayName: String, source: ModelSource) {
        self.backendID = backendID
        self.displayName = displayName
        self.source = source
    }

    /// Composite identity key matching ModelUsageStats.modelIdentity
    public var modelIdentity: String {
        switch source {
        case .local:
            return "local:\(backendID)"
        case .remote(let serverID):
            return "remote:\(serverID.uuidString):\(backendID)"
        }
    }
}

// MARK: - Inference Backend Protocol

/// Abstraction over local (llama.cpp) and remote (OpenAI-compatible) inference.
/// ChatViewModel depends on this protocol, never on a concrete backend.
public protocol InferenceBackend: Sendable {
    /// Unique identifier for this backend instance (model ID for remote, repoId for local)
    var id: String { get }

    /// Human-readable name shown in the model picker
    var displayName: String { get }

    /// Where this model is running
    var source: ModelSource { get }

    /// Stream tokens from the model.
    /// - Parameters:
    ///   - messages: Conversation history
    ///   - params: Inference parameters (temperature, topP, systemPrompt)
    ///   - enableThinking: Whether to request/display reasoning content
    /// - Returns: Async stream of StreamToken values
    func generate(
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> AsyncThrowingStream<StreamToken, Error>

    /// Cancel the current generation. Preserves partial output.
    func stop() async
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (or pre-existing errors unrelated to this file)

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Services/Inference/Backends/InferenceBackend.swift
git commit -m "feat: add InferenceBackend protocol, StreamToken, ModelSource, SelectedModel types"
```

---

## Task 2: APIAdapter Protocol & APIFormat Enum

**Files:**
- Create: `ModelRunner/Services/Inference/Adapters/APIAdapter.swift`

- [ ] **Step 1: Create the APIAdapter protocol**

```swift
// ModelRunner/Services/Inference/Adapters/APIAdapter.swift
import Foundation

// MARK: - API Format

/// Supported remote inference API formats.
/// Stored in ServerConnection to record which formats a server supports.
public enum APIFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case openAIChat = "openai_chat"              // /v1/chat/completions
    case openAILegacy = "openai_legacy"          // /v1/completions
    case anthropicMessages = "anthropic_messages" // /v1/messages

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAIChat: return "OpenAI Chat"
        case .openAILegacy: return "OpenAI Legacy"
        case .anthropicMessages: return "Anthropic Messages"
        }
    }

    /// Endpoint path for this format
    public var endpointPath: String {
        switch self {
        case .openAIChat: return "/v1/chat/completions"
        case .openAILegacy: return "/v1/completions"
        case .anthropicMessages: return "/v1/messages"
        }
    }

    /// Priority order for auto-selection (lower is better)
    public var priority: Int {
        switch self {
        case .openAIChat: return 0
        case .openAILegacy: return 1
        case .anthropicMessages: return 2
        }
    }
}

// MARK: - API Adapter Protocol

/// Builds HTTP requests and parses streaming responses for a specific API format.
/// Each adapter is a stateless value type — one instance per format.
public protocol APIAdapter: Sendable {
    /// Which API format this adapter speaks
    static var format: APIFormat { get }

    /// Build an HTTP request for the given parameters.
    func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool,
        apiKey: String?
    ) -> URLRequest

    /// Parse an SSE byte stream into structured StreamTokens.
    func parseTokenStream(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<StreamToken, Error>
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Services/Inference/Adapters/APIAdapter.swift
git commit -m "feat: add APIAdapter protocol and APIFormat enum"
```

---

## Task 3: OpenAI Chat Adapter — Request Building & SSE Parsing

**Files:**
- Create: `ModelRunner/Services/Inference/Adapters/OpenAIChatAdapter.swift`
- Create: `ModelRunnerTests/Adapters/OpenAIChatAdapterTests.swift`

- [ ] **Step 1: Write failing tests for SSE parsing**

```swift
// ModelRunnerTests/Adapters/OpenAIChatAdapterTests.swift
import XCTest
@testable import ModelRunner

final class OpenAIChatAdapterTests: XCTestCase {

    let adapter = OpenAIChatAdapter()

    // MARK: - Request Building

    func testBuildRequest_setsCorrectEndpoint() {
        let url = URL(string: "https://example.com")!
        let messages = [ChatMessage(role: .user, content: "hi")]
        let params = InferenceParams.default(contextWindowCap: 2048)

        let request = adapter.buildRequest(
            baseURL: url, model: "test-model", messages: messages,
            params: params, enableThinking: false, apiKey: nil
        )

        XCTAssertEqual(request.url?.path, "/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testBuildRequest_includesApiKey() {
        let url = URL(string: "https://example.com")!
        let messages = [ChatMessage(role: .user, content: "hi")]
        let params = InferenceParams.default(contextWindowCap: 2048)

        let request = adapter.buildRequest(
            baseURL: url, model: "test-model", messages: messages,
            params: params, enableThinking: false, apiKey: "sk-test-key"
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test-key")
    }

    func testBuildRequest_includesTemperatureAndTopP() throws {
        let url = URL(string: "https://example.com")!
        let messages = [ChatMessage(role: .user, content: "hi")]
        let params = InferenceParams(
            contextWindowTokens: 2048, batchSize: 512, gpuLayers: 99,
            temperature: 0.3, topP: 0.8
        )

        let request = adapter.buildRequest(
            baseURL: url, model: "test-model", messages: messages,
            params: params, enableThinking: false, apiKey: nil
        )

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(json["temperature"] as? Double, 0.3, accuracy: 0.01)
        XCTAssertEqual(json["top_p"] as? Double, 0.8, accuracy: 0.01)
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["model"] as? String, "test-model")
    }

    // MARK: - SSE Parsing

    func testParseTokenStream_contentTokens() async throws {
        let sseData = """
        data: {"choices":[{"delta":{"content":"Hello"}}]}

        data: {"choices":[{"delta":{"content":" world"}}]}

        data: [DONE]

        """

        let tokens = try await collectTokens(from: sseData)
        XCTAssertEqual(tokens, [.content("Hello"), .content(" world"), .done])
    }

    func testParseTokenStream_reasoningContent() async throws {
        let sseData = """
        data: {"choices":[{"delta":{"reasoning_content":"Let me think"}}]}

        data: {"choices":[{"delta":{"content":"The answer"}}]}

        data: [DONE]

        """

        let tokens = try await collectTokens(from: sseData)
        XCTAssertEqual(tokens, [.thinking("Let me think"), .content("The answer"), .done])
    }

    func testParseTokenStream_emptyDeltaSkipped() async throws {
        let sseData = """
        data: {"choices":[{"delta":{"role":"assistant"}}]}

        data: {"choices":[{"delta":{"content":"Hi"}}]}

        data: [DONE]

        """

        let tokens = try await collectTokens(from: sseData)
        XCTAssertEqual(tokens, [.content("Hi"), .done])
    }

    // MARK: - Helpers

    private func collectTokens(from sseString: String) async throws -> [StreamToken] {
        let data = Data(sseString.utf8)
        let (bytes, _) = try await URLSession.shared.bytes(for: mockURLRequest(data: data))
        // Can't easily mock URLSession.AsyncBytes, so test the SSE line parser directly
        let tokens = try await adapter.parseSSELines(sseString.components(separatedBy: "\n"))
        return tokens
    }
}

// Make StreamToken Equatable for test assertions
extension StreamToken: Equatable {
    public static func == (lhs: StreamToken, rhs: StreamToken) -> Bool {
        switch (lhs, rhs) {
        case (.thinking(let a), .thinking(let b)): return a == b
        case (.content(let a), .content(let b)): return a == b
        case (.done, .done): return true
        default: return false
        }
    }
}
```

- [ ] **Step 2: Implement OpenAIChatAdapter**

```swift
// ModelRunner/Services/Inference/Adapters/OpenAIChatAdapter.swift
import Foundation

/// Adapter for OpenAI-compatible /v1/chat/completions endpoints.
/// Handles streaming SSE with content and reasoning_content (thinking) deltas.
public struct OpenAIChatAdapter: APIAdapter, Sendable {
    public static let format: APIFormat = .openAIChat

    public init() {}

    // MARK: - Request Building

    public func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool,
        apiKey: String?
    ) -> URLRequest {
        let endpoint = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "temperature": Double(params.temperature),
            "top_p": Double(params.topP),
            "messages": messages.map { msg -> [String: String] in
                ["role": msg.role.rawValue, "content": msg.content]
            }
        ]

        // Add system prompt as first message if non-empty
        if !params.systemPrompt.isEmpty {
            var msgArray = body["messages"] as! [[String: String]]
            msgArray.insert(["role": "system", "content": params.systemPrompt], at: 0)
            body["messages"] = msgArray
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - SSE Stream Parsing

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
                    // Stream ended without [DONE]
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Line Parsing (also used by tests)

    /// Parse a single SSE line into a StreamToken, or nil if the line is not a data line.
    func parseLine(_ line: String) -> StreamToken? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))

        if payload == "[DONE]" {
            return .done
        }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any] else {
            return nil
        }

        // Check reasoning_content first (thinking tokens)
        if let reasoning = delta["reasoning_content"] as? String, !reasoning.isEmpty {
            return .thinking(reasoning)
        }

        // Then regular content
        if let content = delta["content"] as? String, !content.isEmpty {
            return .content(content)
        }

        // Empty delta (e.g., role-only) — skip
        return nil
    }

    /// Test helper: parse an array of SSE lines into tokens.
    func parseSSELines(_ lines: [String]) async throws -> [StreamToken] {
        var tokens: [StreamToken] = []
        for line in lines {
            if let token = parseLine(line) {
                tokens.append(token)
            }
        }
        return tokens
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ModelRunnerTests/OpenAIChatAdapterTests -quiet 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/Services/Inference/Adapters/OpenAIChatAdapter.swift ModelRunnerTests/Adapters/OpenAIChatAdapterTests.swift
git commit -m "feat: OpenAI Chat adapter with SSE parsing and reasoning_content support"
```

---

## Task 4: OpenAI Legacy Adapter

**Files:**
- Create: `ModelRunner/Services/Inference/Adapters/OpenAILegacyAdapter.swift`
- Create: `ModelRunnerTests/Adapters/OpenAILegacyAdapterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ModelRunnerTests/Adapters/OpenAILegacyAdapterTests.swift
import XCTest
@testable import ModelRunner

final class OpenAILegacyAdapterTests: XCTestCase {

    let adapter = OpenAILegacyAdapter()

    func testBuildRequest_usesCompletionsEndpoint() {
        let url = URL(string: "https://example.com")!
        let messages = [ChatMessage(role: .user, content: "hi")]
        let params = InferenceParams.default(contextWindowCap: 2048)

        let request = adapter.buildRequest(
            baseURL: url, model: "test-model", messages: messages,
            params: params, enableThinking: false, apiKey: nil
        )

        XCTAssertEqual(request.url?.path, "/v1/completions")
    }

    func testBuildRequest_flattenMessagesToPrompt() throws {
        let url = URL(string: "https://example.com")!
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there"),
            ChatMessage(role: .user, content: "How are you?")
        ]
        let params = InferenceParams.default(contextWindowCap: 2048)

        let request = adapter.buildRequest(
            baseURL: url, model: "test-model", messages: messages,
            params: params, enableThinking: false, apiKey: nil
        )

        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        let prompt = try XCTUnwrap(json["prompt"] as? String)
        XCTAssertTrue(prompt.contains("Hello"))
        XCTAssertTrue(prompt.contains("Hi there"))
        XCTAssertTrue(prompt.contains("How are you?"))
        XCTAssertNil(json["messages"]) // Legacy uses "prompt", not "messages"
    }

    func testParseLine_extractsText() {
        let line = "data: {\"choices\":[{\"text\":\"Hello\"}]}"
        let token = adapter.parseLine(line)
        XCTAssertEqual(token, .content("Hello"))
    }

    func testParseLine_done() {
        let line = "data: [DONE]"
        let token = adapter.parseLine(line)
        XCTAssertEqual(token, .done)
    }
}
```

- [ ] **Step 2: Implement OpenAILegacyAdapter**

```swift
// ModelRunner/Services/Inference/Adapters/OpenAILegacyAdapter.swift
import Foundation

/// Adapter for older OpenAI-compatible /v1/completions endpoints.
/// Flattens messages into a single prompt string using ChatML format.
/// No thinking/reasoning support — all tokens are .content.
public struct OpenAILegacyAdapter: APIAdapter, Sendable {
    public static let format: APIFormat = .openAILegacy

    public init() {}

    public func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool,
        apiKey: String?
    ) -> URLRequest {
        let endpoint = baseURL.appendingPathComponent("v1/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Flatten messages into a single prompt using ChatML format
        let prompt = PromptFormatter.chatml(system: params.systemPrompt, messages: messages)

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true,
            "temperature": Double(params.temperature),
            "top_p": Double(params.topP)
        ]

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

    func parseLine(_ line: String) -> StreamToken? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))

        if payload == "[DONE]" { return .done }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let text = choices.first?["text"] as? String, !text.isEmpty else {
            return nil
        }

        return .content(text)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ModelRunnerTests/OpenAILegacyAdapterTests -quiet 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/Services/Inference/Adapters/OpenAILegacyAdapter.swift ModelRunnerTests/Adapters/OpenAILegacyAdapterTests.swift
git commit -m "feat: OpenAI Legacy adapter for /v1/completions endpoints"
```

---

## Task 5: Anthropic Messages Adapter (Skeleton)

**Files:**
- Create: `ModelRunner/Services/Inference/Adapters/AnthropicMessagesAdapter.swift`

- [ ] **Step 1: Create skeleton adapter**

```swift
// ModelRunner/Services/Inference/Adapters/AnthropicMessagesAdapter.swift
import Foundation

/// Skeleton adapter for Anthropic /v1/messages endpoints.
/// P2 priority — implemented enough to compile and be detected by ServerProbe,
/// but not production-tested. Full implementation deferred.
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

        // Filter out system messages — Anthropic uses a top-level "system" field
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
            // Future: handle thinking blocks
            // if delta["type"] == "thinking_delta", let thinking = delta["thinking"] as? String { return .thinking(thinking) }
        }

        return nil
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Services/Inference/Adapters/AnthropicMessagesAdapter.swift
git commit -m "feat: Anthropic Messages adapter skeleton (P2)"
```

---

## Task 6: SwiftData Models — ServerConnection & ModelUsageStats

**Files:**
- Create: `ModelRunner/Models/ServerConnection.swift`
- Create: `ModelRunner/Models/ModelUsageStats.swift`
- Modify: `ModelRunner/App/ModelRunnerApp.swift` (add to ModelContainer schema)

- [ ] **Step 1: Create ServerConnection model**

```swift
// ModelRunner/Models/ServerConnection.swift
import Foundation
import SwiftData

@Model
final class ServerConnection {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var supportedFormats: [String]  // APIFormat rawValues — SwiftData can't store custom enums in arrays
    var activeFormatRaw: String     // APIFormat rawValue
    var apiKeyRef: String?          // Keychain item identifier, NOT the actual key
    var isActive: Bool
    var addedAt: Date
    var lastCheckedAt: Date?

    init(
        name: String,
        baseURL: String,
        supportedFormats: [APIFormat],
        activeFormat: APIFormat,
        apiKeyRef: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.baseURL = baseURL
        self.supportedFormats = supportedFormats.map(\.rawValue)
        self.activeFormatRaw = activeFormat.rawValue
        self.apiKeyRef = apiKeyRef
        self.isActive = true
        self.addedAt = Date()
    }

    // MARK: - Computed

    var activeFormat: APIFormat {
        get { APIFormat(rawValue: activeFormatRaw) ?? .openAIChat }
        set { activeFormatRaw = newValue.rawValue }
    }

    var parsedSupportedFormats: [APIFormat] {
        supportedFormats.compactMap { APIFormat(rawValue: $0) }
    }

    var parsedBaseURL: URL? {
        URL(string: baseURL)
    }
}
```

- [ ] **Step 2: Create ModelUsageStats model**

```swift
// ModelRunner/Models/ModelUsageStats.swift
import Foundation
import SwiftData

/// Persists measured performance and usage across both local and remote models.
/// Key format: "local:<repoId>" or "remote:<serverUUID>:<modelID>"
@Model
final class ModelUsageStats {
    @Attribute(.unique) var modelIdentity: String
    var lastMeasuredTokPerSec: Double?
    var totalGenerations: Int
    var lastUsedAt: Date

    init(modelIdentity: String) {
        self.modelIdentity = modelIdentity
        self.totalGenerations = 0
        self.lastUsedAt = Date()
    }

    /// Record a completed generation.
    func recordGeneration(tokPerSec: Double) {
        lastMeasuredTokPerSec = tokPerSec
        totalGenerations += 1
        lastUsedAt = Date()
    }
}
```

- [ ] **Step 3: Add new models to ModelContainer schema in ModelRunnerApp.swift**

In `ModelRunnerApp.swift`, update the `modelContainer` static property:

Replace:
```swift
let schema = Schema([DownloadedModel.self, Conversation.self, Message.self])
```

With:
```swift
let schema = Schema([DownloadedModel.self, Conversation.self, Message.self, ServerConnection.self, ModelUsageStats.self])
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ModelRunner/Models/ServerConnection.swift ModelRunner/Models/ModelUsageStats.swift ModelRunner/App/ModelRunnerApp.swift
git commit -m "feat: SwiftData models for ServerConnection and ModelUsageStats"
```

---

## Task 7: KeychainService

**Files:**
- Create: `ModelRunner/Services/Keychain/KeychainService.swift`

- [ ] **Step 1: Implement KeychainService**

```swift
// ModelRunner/Services/Keychain/KeychainService.swift
import Foundation
import Security

/// Simple Keychain CRUD for storing API keys.
/// Keys are stored with kSecClassGenericPassword, keyed by a service+account pair.
enum KeychainService {
    private static let service = "com.modelrunner.apikeys"

    /// Save or update a secret for the given account identifier.
    @discardableResult
    static func save(key: String, account: String) -> Bool {
        let data = Data(key.utf8)

        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        // If not found, add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }

    /// Retrieve a secret for the given account identifier.
    static func retrieve(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Delete a secret for the given account identifier.
    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Services/Keychain/KeychainService.swift
git commit -m "feat: KeychainService for secure API key storage"
```

---

## Task 8: ServerProbe — Two-Phase Format Detection

**Files:**
- Create: `ModelRunner/Services/Inference/ServerProbe.swift`
- Create: `ModelRunnerTests/ServerProbeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ModelRunnerTests/ServerProbeTests.swift
import XCTest
@testable import ModelRunner

final class ServerProbeTests: XCTestCase {

    func testParseModelsResponse_openAIFormat() throws {
        let json = """
        {"data":[{"id":"llama3:70b"},{"id":"codestral:latest"}]}
        """.data(using: .utf8)!

        let models = try ServerProbe.parseModelsResponse(json)
        XCTAssertEqual(models, ["llama3:70b", "codestral:latest"])
    }

    func testParseModelsResponse_ollamaFormat() throws {
        // Ollama returns both "models" array and "data" array
        let json = """
        {"models":[{"name":"nemotron-3-nano-4b","model":"nemotron-3-nano-4b"}],"data":[{"id":"nemotron-3-nano-4b"}]}
        """.data(using: .utf8)!

        let models = try ServerProbe.parseModelsResponse(json)
        XCTAssertTrue(models.contains("nemotron-3-nano-4b"))
    }

    func testParseModelsResponse_emptyData() throws {
        let json = """
        {"data":[]}
        """.data(using: .utf8)!

        let models = try ServerProbe.parseModelsResponse(json)
        XCTAssertTrue(models.isEmpty)
    }
}
```

- [ ] **Step 2: Implement ServerProbe**

```swift
// ModelRunner/Services/Inference/ServerProbe.swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ServerProbe")

/// Two-phase server format detection.
/// Phase 1: Discover models via GET /v1/models
/// Phase 2: Probe each API format in parallel using a discovered model ID
public enum ServerProbe {

    /// Result of probing a server
    public struct ProbeResult: Sendable {
        public let models: [String]
        public let supportedFormats: [APIFormat]
        /// Model IDs that returned reasoning_content during probe (thinking-capable)
        public let thinkingModelIDs: Set<String>
    }

    /// Probe a server to discover models and supported API formats.
    /// - Parameters:
    ///   - baseURL: Server base URL
    ///   - apiKey: Optional API key
    ///   - manualModelID: If model discovery fails, use this model ID for format probing
    /// - Returns: ProbeResult with discovered models and supported formats
    public static func probe(
        baseURL: URL,
        apiKey: String? = nil,
        manualModelID: String? = nil,
        timeoutSeconds: TimeInterval = 30
    ) async throws -> ProbeResult {
        // Phase 1: Discover models
        var models: [String] = []
        do {
            models = try await discoverModels(baseURL: baseURL, apiKey: apiKey, timeout: timeoutSeconds)
            logger.info("Discovered \(models.count) models on \(baseURL.absoluteString)")
        } catch {
            logger.warning("Model discovery failed: \(error.localizedDescription)")
        }

        // Use first discovered model, or manual ID, or fail
        guard let probeModel = models.first ?? manualModelID else {
            throw ProbeError.noModelsFound
        }

        // Phase 2: Probe formats in parallel (also detects thinking capability)
        let (formats, thinkingModels) = await probeFormats(
            baseURL: baseURL,
            model: probeModel,
            apiKey: apiKey,
            timeout: timeoutSeconds
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

    /// Parse model list from either OpenAI format (data[].id) or Ollama format (models[].name)
    static func parseModelsResponse(_ data: Data) throws -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProbeError.invalidResponse
        }

        var modelIDs: [String] = []

        // OpenAI format: {"data": [{"id": "model-name"}]}
        if let dataArray = json["data"] as? [[String: Any]] {
            modelIDs.append(contentsOf: dataArray.compactMap { $0["id"] as? String })
        }

        // Ollama format: {"models": [{"name": "model-name"}]}
        if let modelsArray = json["models"] as? [[String: Any]] {
            let ollamaNames = modelsArray.compactMap { $0["name"] as? String }
            // Avoid duplicates if server returns both formats
            for name in ollamaNames where !modelIDs.contains(name) {
                modelIDs.append(name)
            }
        }

        return modelIDs
    }

    // MARK: - Phase 2: Format Probing

    /// Returns (supportedFormats, thinkingModelIDs)
    private static func probeFormats(
        baseURL: URL,
        model: String,
        apiKey: String?,
        timeout: TimeInterval
    ) async -> ([APIFormat], Set<String>) {
        // Track whether the probe model supports thinking
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

                        // Override to non-streaming for probe (faster, less data)
                        if var body = request.httpBody,
                           var json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                            json["stream"] = false
                            json["max_tokens"] = 1
                            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
                        }

                        let (data, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                            logger.info("Format \(format.rawValue) supported on \(baseURL.absoluteString)")

                            // Check for thinking capability in chat completions response
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
                if let format = result {
                    supported.append(format)
                }
            }
            return supported
        }

        let thinkingModels = await thinkingDetected.models
        return (formats, thinkingModels)
    }

    /// Actor to safely collect thinking-capable model IDs from concurrent probe tasks
    private actor ThinkingDetector {
        var models: Set<String> = []
        func markThinking(model: String) { models.insert(model) }
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
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ModelRunnerTests/ServerProbeTests -quiet 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/Services/Inference/ServerProbe.swift ModelRunnerTests/ServerProbeTests.swift
git commit -m "feat: ServerProbe — two-phase model discovery and format detection"
```

---

## Task 9: RemoteInferenceBackend

**Files:**
- Create: `ModelRunner/Services/Inference/Backends/RemoteInferenceBackend.swift`
- Create: `ModelRunnerTests/RemoteInferenceBackendTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ModelRunnerTests/RemoteInferenceBackendTests.swift
import XCTest
@testable import ModelRunner

final class RemoteInferenceBackendTests: XCTestCase {

    func testProperties() {
        let backend = RemoteInferenceBackend(
            modelID: "llama3:70b",
            serverID: UUID(),
            serverName: "MacBook Pro",
            baseURL: URL(string: "https://example.com")!,
            adapter: OpenAIChatAdapter(),
            apiKey: nil
        )

        XCTAssertEqual(backend.id, "llama3:70b")
        XCTAssertEqual(backend.displayName, "llama3:70b")
        XCTAssertTrue(backend.source.isRemote)
    }

    func testModelIdentity() {
        let serverID = UUID()
        let backend = RemoteInferenceBackend(
            modelID: "nemotron-3-nano-4b",
            serverID: serverID,
            serverName: "Home Server",
            baseURL: URL(string: "https://example.com")!,
            adapter: OpenAIChatAdapter(),
            apiKey: nil
        )

        XCTAssertEqual(backend.modelIdentity, "remote:\(serverID.uuidString):nemotron-3-nano-4b")
    }
}
```

- [ ] **Step 2: Implement RemoteInferenceBackend**

```swift
// ModelRunner/Services/Inference/Backends/RemoteInferenceBackend.swift
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "RemoteInferenceBackend")

/// Remote server conformer for InferenceBackend.
/// Owns the URLSession data task lifecycle for streaming.
public final class RemoteInferenceBackend: InferenceBackend, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let source: ModelSource

    private let baseURL: URL
    private let adapter: any APIAdapter
    private let apiKey: String?

    /// Active streaming task — held for cancellation
    private var activeTask: URLSessionDataTask?
    private let lock = NSLock()

    public init(
        modelID: String,
        serverID: UUID,
        serverName: String,
        baseURL: URL,
        adapter: any APIAdapter,
        apiKey: String?
    ) {
        self.id = modelID
        self.displayName = modelID
        self.source = .remote(serverID: serverID)
        self.baseURL = baseURL
        self.adapter = adapter
        self.apiKey = apiKey
    }

    /// Composite identity key matching ModelUsageStats.modelIdentity
    public var modelIdentity: String {
        guard case .remote(let serverID) = source else { return "remote:unknown:\(id)" }
        return "remote:\(serverID.uuidString):\(id)"
    }

    public func generate(
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> AsyncThrowingStream<StreamToken, Error> {
        let request = adapter.buildRequest(
            baseURL: baseURL,
            model: id,
            messages: messages,
            params: params,
            enableThinking: enableThinking,
            apiKey: apiKey
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    // Check HTTP status
                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        // Try to read error body
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody.append(Character(UnicodeScalar(byte)))
                            if errorBody.count > 1000 { break }
                        }
                        continuation.finish(throwing: RemoteInferenceError.httpError(
                            statusCode: httpResponse.statusCode,
                            body: errorBody
                        ))
                        return
                    }

                    let tokenStream = adapter.parseTokenStream(from: bytes)
                    for try await token in tokenStream {
                        continuation.yield(token)
                        if case .done = token {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.yield(.done)
                    continuation.finish()
                } catch let urlError as URLError where urlError.code == .cancelled {
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    logger.error("Remote generation error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func stop() async {
        lock.lock()
        activeTask?.cancel()
        activeTask = nil
        lock.unlock()
        logger.info("Remote generation stopped for \(self.id)")
    }
}

// MARK: - Errors

public enum RemoteInferenceError: LocalizedError {
    case httpError(statusCode: Int, body: String)
    case serverDisconnected
    case authenticationRequired

    public var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            switch code {
            case 401, 403: return "Authentication required. Add or update the API key in server settings."
            case 404: return "Model no longer available on this server."
            case 429: return "Rate limited. Try again in a moment."
            default: return "Server error (\(code)): \(body.prefix(200))"
            }
        case .serverDisconnected: return "Server disconnected during generation."
        case .authenticationRequired: return "Authentication required."
        }
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:ModelRunnerTests/RemoteInferenceBackendTests -quiet 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/Services/Inference/Backends/RemoteInferenceBackend.swift ModelRunnerTests/RemoteInferenceBackendTests.swift
git commit -m "feat: RemoteInferenceBackend with streaming and cancellation"
```

---

## Task 10: Update Conversation Model for Unified Identity

**Files:**
- Modify: `ModelRunner/Models/Conversation.swift`

- [ ] **Step 1: Update Conversation with unified model identity fields**

Replace the existing `Conversation.swift` content:

```swift
// ModelRunner/Models/Conversation.swift
import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    // Unified model identity — works for both local and remote
    // Format: "local:<repoId>" or "remote:<serverUUID>:<modelID>"
    var modelIdentity: String
    var modelDisplayName: String
    /// Source label for display: "On Device" or server name
    var modelSourceLabel: String
    /// Per-conversation thinking toggle
    var enableThinking: Bool

    // Legacy field — kept for migration from pre-remote-inference conversations
    // New conversations use modelIdentity instead
    var modelRepoId: String
    var modelQuantization: String

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []

    /// Create a conversation with unified identity (new path — remote or local)
    init(modelIdentity: String, modelDisplayName: String, modelSourceLabel: String, enableThinking: Bool = false) {
        self.id = UUID()
        self.modelIdentity = modelIdentity
        self.modelDisplayName = modelDisplayName
        self.modelSourceLabel = modelSourceLabel
        self.enableThinking = enableThinking
        self.title = "New Conversation"
        self.createdAt = Date()
        self.updatedAt = Date()
        // Legacy fields — empty for new conversations
        self.modelRepoId = ""
        self.modelQuantization = ""
    }

    /// Legacy init — for backward compatibility with existing local model conversations
    init(modelRepoId: String, modelDisplayName: String, modelQuantization: String) {
        self.id = UUID()
        self.modelIdentity = "local:\(modelRepoId)"
        self.modelDisplayName = modelDisplayName
        self.modelSourceLabel = "On Device"
        self.enableThinking = false
        self.title = "New Conversation"
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelRepoId = modelRepoId
        self.modelQuantization = modelQuantization
    }

    /// Auto-generate title from first user message. Truncated to 50 chars with ellipsis.
    func generateTitle(from firstUserMessage: String) {
        let trimmed = firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 {
            title = trimmed
        } else {
            title = String(trimmed.prefix(50)) + "..."
        }
        updatedAt = Date()
    }
}
```

- [ ] **Step 2: Verify it compiles and existing tests still pass**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (some ChatViewModel references may need updating — fix in Task 13)

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Models/Conversation.swift
git commit -m "feat: unified model identity on Conversation for local and remote models"
```

---

## Task 11: Update ChatMessage with Thinking Content

**Files:**
- Modify: `ModelRunner/Models/ChatMessage.swift`

- [ ] **Step 1: Add thinkingContent to ChatMessage**

```swift
// ModelRunner/Models/ChatMessage.swift
import Foundation

/// Role of a participant in a chat conversation.
public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
}

/// A single message in a chat conversation.
/// Content is mutable to support streaming token append during generation.
public struct ChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    /// Reasoning/thinking content — separate from main content, rendered as collapsible block
    public var thinkingContent: String
    /// True while the assistant is streaming tokens into this message.
    public var isStreaming: Bool
    /// Duration of thinking phase in seconds (first thinking token → first content token)
    public var thinkingDuration: TimeInterval?

    public init(role: MessageRole, content: String, isStreaming: Bool = false, thinkingContent: String = "") {
        self.id = UUID()
        self.role = role
        self.content = content
        self.thinkingContent = thinkingContent
        self.isStreaming = isStreaming
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Models/ChatMessage.swift
git commit -m "feat: add thinkingContent and thinkingDuration to ChatMessage"
```

---

## Task 12: Update ChatSettings with Thinking Toggle

**Files:**
- Modify: `ModelRunner/Features/Chat/ChatSettings.swift`

- [ ] **Step 1: Add enableThinking to ChatSettings**

Add the `enableThinking` property to the `ChatSettings` struct. In `ChatSettings.swift`, add after `selectedPreset`:

```swift
var enableThinking: Bool = false
```

Update `defaultSettings`:

```swift
static let defaultSettings = ChatSettings(
    systemPrompt: SystemPromptPreset.helpful.prompt,
    selectedPreset: .helpful,
    enableThinking: false
)
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Chat/ChatSettings.swift
git commit -m "feat: add enableThinking to ChatSettings"
```

---

## Task 13: Refactor ChatViewModel for InferenceBackend Protocol

**Files:**
- Modify: `ModelRunner/Features/Chat/ChatViewModel.swift`

This is the largest change — ChatViewModel switches from directly using `InferenceService` to using the `InferenceBackend` protocol, handling `StreamToken` instead of raw strings, and supporting thinking content.

- [ ] **Step 1: Rewrite ChatViewModel**

Replace the full contents of `ChatViewModel.swift`:

```swift
// ModelRunner/Features/Chat/ChatViewModel.swift
import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ChatViewModel")

enum ModelLoadState: Equatable {
    case idle
    case loading(progress: Double)
    case ready
    case failed(String)

    static func == (lhs: ModelLoadState, rhs: ModelLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready): return true
        case (.loading(let a), .loading(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

@Observable
@MainActor
final class ChatViewModel {
    // MARK: - State (observable)
    var messages: [ChatMessage] = []
    private(set) var isGenerating: Bool = false
    private(set) var tokensPerSecond: Double = 0
    private(set) var loadingState: ModelLoadState = .idle
    var settings: ChatSettings = ChatSettings.load()

    // MARK: - Persistence
    var activeConversation: Conversation?
    var showingHistory: Bool = false
    private var modelContext: ModelContext?

    // MARK: - Backend
    /// The active inference backend — may be local (llama.cpp) or remote (OpenAI-compatible server).
    /// Set by the model picker or ChatView setup.
    var backend: (any InferenceBackend)?

    // MARK: - Legacy (local model support — kept for backward compat until LocalInferenceBackend ships)
    private var inferenceService: InferenceService?
    private var inferenceParams: InferenceParams?

    // MARK: - Private
    private var generationTask: Task<Void, Never>?
    private var generationStart: ContinuousClock.Instant?
    private var tokenCount: Int = 0
    private var thinkingStart: ContinuousClock.Instant?

    // MARK: - Init

    /// New init for protocol-based backends (remote models)
    init(backend: any InferenceBackend) {
        self.backend = backend
        self.loadingState = .ready  // Remote backends are always "ready"
    }

    /// Legacy init for local InferenceService (kept until LocalInferenceBackend ships)
    init(inferenceService: InferenceService, inferenceParams: InferenceParams) {
        self.inferenceService = inferenceService
        self.inferenceParams = inferenceParams
    }

    // MARK: - Persistence Configuration

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Conversation Management

    func startNewConversation(for selectedModel: SelectedModel) {
        guard let modelContext else { return }
        let conv = Conversation(
            modelIdentity: selectedModel.modelIdentity,
            modelDisplayName: selectedModel.displayName,
            modelSourceLabel: selectedModel.source.isRemote ? "Remote" : "On Device",
            enableThinking: settings.enableThinking
        )
        modelContext.insert(conv)
        try? modelContext.save()
        activeConversation = conv
        messages = []
    }

    /// Legacy: start conversation for a local DownloadedModel
    func startNewConversation(for model: DownloadedModel) {
        guard let modelContext else { return }
        let conv = Conversation(
            modelRepoId: model.repoId,
            modelDisplayName: model.displayName,
            modelQuantization: model.quantization
        )
        modelContext.insert(conv)
        try? modelContext.save()
        activeConversation = conv
        messages = []
    }

    func loadMostRecentConversation(forIdentity modelIdentity: String, modelContext: ModelContext) {
        self.modelContext = modelContext
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.modelIdentity == modelIdentity },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let recent = try? modelContext.fetch(descriptor).first {
            activeConversation = recent
            messages = recent.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
        }
        // If no recent conversation found, leave empty — user starts fresh on first send
    }

    /// Legacy: load conversation for a local DownloadedModel
    func loadMostRecentConversation(for model: DownloadedModel, modelContext: ModelContext) {
        self.modelContext = modelContext
        let repoId = model.repoId
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.modelRepoId == repoId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let recent = try? modelContext.fetch(descriptor).first {
            activeConversation = recent
            messages = recent.messages
                .sorted { $0.createdAt < $1.createdAt }
                .map { ChatMessage(role: $0.role == "user" ? .user : .assistant, content: $0.content) }
        } else {
            startNewConversation(for: model)
        }
    }

    func deleteConversation(_ conversation: Conversation) {
        modelContext?.delete(conversation)
        try? modelContext?.save()
        if activeConversation?.id == conversation.id {
            activeConversation = nil
            messages = []
        }
    }

    // MARK: - Public API

    func send(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isGenerating else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Persist user message
        if let conv = activeConversation {
            let persistedUser = Message(role: "user", content: text)
            conv.messages.append(persistedUser)
            if conv.title == "New Conversation" {
                conv.generateTitle(from: text)
            }
            conv.updatedAt = Date()
            try? modelContext?.save()
        }

        isGenerating = true
        generationTask = Task {
            if backend != nil {
                await runRemoteGeneration()
            } else if inferenceService != nil {
                await runLocalGeneration()
            }
        }
    }

    func stop() {
        generationTask?.cancel()
        if let backend {
            Task { await backend.stop() }
        } else if let inferenceService {
            Task { await inferenceService.stopGeneration() }
        }
        if let idx = messages.indices.last, messages[idx].role == .assistant {
            messages[idx].isStreaming = false
        }
        isGenerating = false
        resetTokSAfterDelay()
    }

    /// Legacy: load a local GGUF model
    func loadModel(url: URL) async {
        guard let inferenceService, let inferenceParams else { return }
        loadingState = .loading(progress: 0)
        do {
            try await inferenceService.loadModel(at: url, params: inferenceParams)
            loadingState = .ready
        } catch {
            loadingState = .failed(error.localizedDescription)
            logger.error("Model load failed: \(error)")
        }
    }

    // MARK: - Remote Generation (InferenceBackend protocol)

    private func runRemoteGeneration() async {
        guard let backend else { return }

        let params = inferenceParams ?? InferenceParams.default(contextWindowCap: 4096)

        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.endIndex - 1

        generationStart = .now
        thinkingStart = nil
        tokenCount = 0
        tokensPerSecond = 0

        let enableThinking = activeConversation?.enableThinking ?? settings.enableThinking
        let stream = backend.generate(
            messages: messages.dropLast().map { $0 },  // Exclude the empty assistant placeholder
            params: params,
            enableThinking: enableThinking
        )

        var isInThinkingPhase = false

        do {
            for try await token in stream {
                if Task.isCancelled { break }

                switch token {
                case .thinking(let text):
                    if !isInThinkingPhase {
                        isInThinkingPhase = true
                        thinkingStart = .now
                    }
                    messages[assistantIndex].thinkingContent += text
                    tokenCount += 1
                    updateToksPerSecond()

                case .content(let text):
                    if isInThinkingPhase {
                        // Transition from thinking to content — record thinking duration
                        if let start = thinkingStart {
                            let elapsed = start.duration(to: .now)
                            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                            messages[assistantIndex].thinkingDuration = seconds
                        }
                        isInThinkingPhase = false
                    }
                    messages[assistantIndex].content += text
                    tokenCount += 1
                    updateToksPerSecond()

                case .done:
                    break
                }
            }
        } catch {
            logger.error("Remote generation error: \(error)")
            if messages[assistantIndex].content.isEmpty {
                messages[assistantIndex].content = "Error: \(error.localizedDescription)"
            }
        }

        messages[assistantIndex].isStreaming = false
        isGenerating = false

        // Persist tok/s to ModelUsageStats
        if let modelContext, tokensPerSecond > 0,
           let remoteBackend = backend as? RemoteInferenceBackend {
            let identity = remoteBackend.modelIdentity
            let descriptor = FetchDescriptor<ModelUsageStats>(
                predicate: #Predicate { $0.modelIdentity == identity }
            )
            let stats = (try? modelContext.fetch(descriptor).first) ?? ModelUsageStats(modelIdentity: identity)
            if stats.modelContext == nil { modelContext.insert(stats) }
            stats.recordGeneration(tokPerSec: tokensPerSecond)
            try? modelContext.save()
        }

        resetTokSAfterDelay()

        // Persist assistant message
        let assistantContent = messages[assistantIndex].content
        let persistedAssistant = Message(role: "assistant", content: assistantContent)
        activeConversation?.messages.append(persistedAssistant)
        activeConversation?.updatedAt = Date()
        try? modelContext?.save()
    }

    // MARK: - Local Generation (legacy — InferenceService path)

    private func runLocalGeneration() async {
        guard let inferenceService, let inferenceParams else { return }

        let isLoaded = await inferenceService.isLoaded
        guard isLoaded else {
            isGenerating = false
            return
        }

        let prompt = buildPrompt()

        var assistantMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.endIndex - 1

        generationStart = .now
        tokenCount = 0
        tokensPerSecond = 0

        let stream = await inferenceService.generate(prompt: prompt, params: inferenceParams)

        do {
            for try await token in stream {
                if Task.isCancelled { break }
                messages[assistantIndex].content += token
                tokenCount += 1
                updateToksPerSecond()
            }
        } catch {
            logger.error("Generation error: \(error)")
        }

        messages[assistantIndex].isStreaming = false
        isGenerating = false
        resetTokSAfterDelay()

        // Persist assistant message
        let assistantContent = messages[assistantIndex].content
        let persistedAssistant = Message(role: "assistant", content: assistantContent)
        activeConversation?.messages.append(persistedAssistant)
        activeConversation?.updatedAt = Date()
        try? modelContext?.save()
    }

    // MARK: - Prompt Building (legacy local path)

    private func buildPrompt() -> String {
        guard let inferenceParams else { return "" }
        let maxHistoryTokens = Int(inferenceParams.contextWindowTokens) - 512
        let maxChars = maxHistoryTokens * 4
        var historyMessages = messages.filter { $0.role == .user || ($0.role == .assistant && !$0.isStreaming) }

        var totalChars = historyMessages.reduce(0) { $0 + $1.content.count }
        while totalChars > maxChars && historyMessages.count > 2 {
            let removed = historyMessages.removeFirst()
            totalChars -= removed.content.count
        }

        return PromptFormatter.chatml(system: inferenceParams.systemPrompt, messages: historyMessages)
    }

    // MARK: - Tok/s

    private func updateToksPerSecond() {
        guard let start = generationStart else { return }
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        if seconds > 0 {
            tokensPerSecond = Double(tokenCount) / seconds
        }
    }

    private func resetTokSAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            tokensPerSecond = 0
        }
    }
}
```

- [ ] **Step 2: Verify it compiles (expect some downstream breakage in ChatView — fixed in Task 16)**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -15`
Expected: May have some errors in ChatView.swift due to init signature changes — these get fixed in Task 16.

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Chat/ChatViewModel.swift
git commit -m "refactor: ChatViewModel uses InferenceBackend protocol with StreamToken and thinking support"
```

---

## Task 14: Update ChatBubbleView for Thinking Blocks

**Files:**
- Modify: `ModelRunner/Features/Chat/ChatBubbleView.swift`

- [ ] **Step 1: Add collapsible thinking block to ChatBubbleView**

Replace the full contents of `ChatBubbleView.swift`:

```swift
// ModelRunner/Features/Chat/ChatBubbleView.swift
import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    let tokensPerSecond: Double
    let isGenerating: Bool

    @State private var isThinkingExpanded: Bool = false

    private var userCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 16)
    }

    private var assistantCornerRadii: RectangleCornerRadii {
        RectangleCornerRadii(topLeading: 16, bottomLeading: 4, bottomTrailing: 16, topTrailing: 16)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
                userBubble
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    // Thinking block — shown if there's thinking content
                    if !message.thinkingContent.isEmpty {
                        thinkingBlock
                    }

                    assistantBubble

                    if message.role == .assistant && (isGenerating || tokensPerSecond > 0) {
                        ToksPerSecondBadge(tokensPerSecond: tokensPerSecond, isGenerating: isGenerating)
                            .padding(.leading, 12)
                    }
                }
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Thinking Block

    private var thinkingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isThinkingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.system(size: 12))
                    if isThinkingExpanded || message.isStreaming {
                        Text("Thinking")
                            .font(.system(size: 13, weight: .medium))
                    } else if let duration = message.thinkingDuration {
                        Text("Thought for \(String(format: "%.1f", duration))s")
                            .font(.system(size: 13, weight: .medium))
                    } else {
                        Text("Thinking")
                            .font(.system(size: 13, weight: .medium))
                    }
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: "#6B6980"))
            }

            // Expandable content
            if isThinkingExpanded || message.isStreaming {
                Text(message.thinkingContent)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#6B6980"))
                    .italic()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(cornerRadii: assistantCornerRadii)
                .fill(Color(hex: "#13111F"))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: assistantCornerRadii)
                        .strokeBorder(Color(hex: "#1E1C30"), lineWidth: 0.5)
                )
        )
        // Auto-collapse when generation finishes
        .onChange(of: message.isStreaming) { wasStreaming, isNowStreaming in
            if wasStreaming && !isNowStreaming {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isThinkingExpanded = false
                }
            }
        }
    }

    // MARK: - Bubbles

    private var userBubble: some View {
        Text(message.content)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: userCornerRadii)
                    .fill(Color(hex: "#8B7CF0"))
            )
            .foregroundStyle(.white)
            .font(.body)
    }

    private var assistantBubble: some View {
        assistantContent
    }

    private var assistantContent: some View {
        Group {
            if message.isStreaming {
                (Text(message.content) + Text("\u{258B}").foregroundStyle(Color(hex: "#8B7CF0")))
                    .font(.body)
            } else {
                markdownContent(message.content)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            UnevenRoundedRectangle(cornerRadii: assistantCornerRadii)
                .fill(Color(hex: "#1A1830"))
        )
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func markdownContent(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text) {
            Text(attributed)
                .font(.body)
        } else {
            Text(text)
                .font(.body)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Chat/ChatBubbleView.swift
git commit -m "feat: collapsible thinking block in ChatBubbleView"
```

---

## Task 15: Update ChatInputBar with Thinking Toggle

**Files:**
- Modify: `ModelRunner/Features/Chat/ChatInputBar.swift`

- [ ] **Step 1: Add thinking toggle button**

Add a `@Binding var enableThinking: Bool` parameter and a brain icon button. Add after `onToggleHistory` parameter:

```swift
@Binding var enableThinking: Bool
```

Add the thinking toggle button in the HStack, before the TextField. After the clock button block:

```swift
// Brain button — toggles thinking/reasoning mode
Button {
    enableThinking.toggle()
} label: {
    Image(systemName: "brain")
        .font(.system(size: 16))
        .foregroundStyle(enableThinking ? Color(hex: "#8B7CF0") : Color(hex: "#6B6980"))
        .frame(width: 36, height: 36)
        .background(
            Circle()
                .fill(enableThinking ? Color(hex: "#8B7CF0").opacity(0.15) : Color(hex: "#1A1830").opacity(0.6))
                .overlay(Circle().strokeBorder(
                    enableThinking ? Color(hex: "#8B7CF0").opacity(0.3) : Color(hex: "#302E42"),
                    lineWidth: 0.5
                ))
        )
}
```

- [ ] **Step 2: Verify it compiles (ChatView call site needs updating — Task 16)**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: May fail on call sites — fixed in Task 16

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Chat/ChatInputBar.swift
git commit -m "feat: thinking toggle button in ChatInputBar"
```

---

## Task 16: Server Management UI — ServerListView, AddServerView, ServerDetailView

**Files:**
- Create: `ModelRunner/Features/Settings/ServerListView.swift`
- Create: `ModelRunner/Features/Settings/AddServerView.swift`
- Create: `ModelRunner/Features/Settings/ServerDetailView.swift`

- [ ] **Step 1: Create ServerListView**

```swift
// ModelRunner/Features/Settings/ServerListView.swift
import SwiftUI
import SwiftData

struct ServerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ServerConnection.addedAt) private var servers: [ServerConnection]
    @State private var showAddServer = false

    var body: some View {
        List {
            if servers.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add a remote server to chat with models running on your network.")
                )
            }

            ForEach(servers) { server in
                NavigationLink(destination: ServerDetailView(server: server)) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(server.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                            Text(server.baseURL)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: "#6B6980"))
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(server.activeFormat.displayName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(hex: "#1A1830"))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let server = servers[index]
                    if let ref = server.apiKeyRef {
                        KeychainService.delete(account: ref)
                    }
                    modelContext.delete(server)
                }
                try? modelContext.save()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0D0C18"))
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddServer = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color(hex: "#8B7CF0"))
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            NavigationStack {
                AddServerView()
            }
        }
    }
}
```

- [ ] **Step 2: Create AddServerView**

```swift
// ModelRunner/Features/Settings/AddServerView.swift
import SwiftUI
import SwiftData

struct AddServerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = ""
    @State private var apiKey = ""
    @State private var isProbing = false
    @State private var probeError: String?
    @State private var probeResult: ServerProbe.ProbeResult?

    var body: some View {
        Form {
            Section("Server Details") {
                TextField("Name", text: $name, prompt: Text("MacBook Pro"))
                    .foregroundStyle(.white)
                TextField("URL", text: $urlString, prompt: Text("http://192.168.1.100:11434"))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                SecureField("API Key (optional)", text: $apiKey)
                    .foregroundStyle(.white)
            }
            .listRowBackground(Color(hex: "#1A1830"))

            if isProbing {
                Section {
                    HStack {
                        ProgressView()
                            .tint(Color(hex: "#8B7CF0"))
                        Text("Detecting server capabilities...")
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                }
                .listRowBackground(Color(hex: "#1A1830"))
            }

            if let error = probeError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.system(size: 14))
                }
                .listRowBackground(Color(hex: "#1A1830"))
            }

            if let result = probeResult {
                Section("Detected") {
                    LabeledContent("Models") {
                        Text("\(result.models.count) found")
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                    LabeledContent("Formats") {
                        Text(result.supportedFormats.map(\.displayName).joined(separator: ", "))
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                }
                .listRowBackground(Color(hex: "#1A1830"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0D0C18"))
        .navigationTitle("Add Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color(hex: "#9896B0"))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { saveServer() }
                    .foregroundStyle(Color(hex: "#8B7CF0"))
                    .disabled(probeResult == nil || name.isEmpty)
            }
        }
        .onChange(of: urlString) { _, _ in
            probeResult = nil
            probeError = nil
        }
        .onSubmit { probeServer() }
        .task {
            // Auto-probe if URL is pre-filled
            if !urlString.isEmpty { probeServer() }
        }
    }

    private func probeServer() {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), url.scheme != nil else {
            probeError = "Enter a valid URL (e.g., http://192.168.1.100:11434)"
            return
        }

        isProbing = true
        probeError = nil
        probeResult = nil

        Task {
            do {
                let result = try await ServerProbe.probe(
                    baseURL: url,
                    apiKey: apiKey.isEmpty ? nil : apiKey
                )
                probeResult = result
                if name.isEmpty {
                    name = url.host ?? "Server"
                }
            } catch {
                probeError = error.localizedDescription
            }
            isProbing = false
        }
    }

    private func saveServer() {
        guard let result = probeResult,
              let bestFormat = result.supportedFormats.first,
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }

        let server = ServerConnection(
            name: name,
            baseURL: url.absoluteString,
            supportedFormats: result.supportedFormats,
            activeFormat: bestFormat
        )

        // Save API key to Keychain if provided
        if !apiKey.isEmpty {
            let account = server.id.uuidString
            KeychainService.save(key: apiKey, account: account)
            server.apiKeyRef = account
        }

        modelContext.insert(server)
        try? modelContext.save()
        dismiss()
    }
}
```

- [ ] **Step 3: Create ServerDetailView**

```swift
// ModelRunner/Features/Settings/ServerDetailView.swift
import SwiftUI
import SwiftData

struct ServerDetailView: View {
    @Bindable var server: ServerConnection
    @Environment(\.modelContext) private var modelContext
    @State private var apiKeyInput = ""
    @State private var isReprobing = false

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $server.name)
                    .foregroundStyle(.white)
                TextField("URL", text: $server.baseURL)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
            }
            .listRowBackground(Color(hex: "#1A1830"))

            Section("API Format") {
                Picker("Active Format", selection: $server.activeFormatRaw) {
                    ForEach(server.parsedSupportedFormats) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }
                .foregroundStyle(.white)

                HStack {
                    Text("Supported")
                        .foregroundStyle(Color(hex: "#9896B0"))
                    Spacer()
                    Text(server.parsedSupportedFormats.map(\.displayName).joined(separator: ", "))
                        .foregroundStyle(Color(hex: "#6B6980"))
                        .font(.system(size: 13))
                }

                Button("Re-detect Formats") {
                    reprobeServer()
                }
                .foregroundStyle(Color(hex: "#8B7CF0"))
                .disabled(isReprobing)
            }
            .listRowBackground(Color(hex: "#1A1830"))

            Section("Authentication") {
                SecureField("API Key", text: $apiKeyInput, prompt: Text(server.apiKeyRef != nil ? "Key saved" : "None"))
                    .foregroundStyle(.white)

                if !apiKeyInput.isEmpty {
                    Button("Save Key") {
                        let account = server.apiKeyRef ?? server.id.uuidString
                        KeychainService.save(key: apiKeyInput, account: account)
                        server.apiKeyRef = account
                        try? modelContext.save()
                        apiKeyInput = ""
                    }
                    .foregroundStyle(Color(hex: "#8B7CF0"))
                }

                if server.apiKeyRef != nil {
                    Button("Remove Key", role: .destructive) {
                        if let ref = server.apiKeyRef {
                            KeychainService.delete(account: ref)
                        }
                        server.apiKeyRef = nil
                        try? modelContext.save()
                    }
                }
            }
            .listRowBackground(Color(hex: "#1A1830"))

            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(server.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(server.isActive ? "Connected" : "Offline")
                            .foregroundStyle(Color(hex: "#9896B0"))
                    }
                }
                if let lastChecked = server.lastCheckedAt {
                    LabeledContent("Last Checked") {
                        Text(lastChecked.formatted(.relative(presentation: .named)))
                            .foregroundStyle(Color(hex: "#6B6980"))
                    }
                }
            }
            .listRowBackground(Color(hex: "#1A1830"))
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0D0C18"))
        .navigationTitle(server.name)
    }

    private func reprobeServer() {
        guard let url = server.parsedBaseURL else { return }
        isReprobing = true

        let apiKey: String? = {
            guard let ref = server.apiKeyRef else { return nil }
            return KeychainService.retrieve(account: ref)
        }()

        Task {
            do {
                let result = try await ServerProbe.probe(baseURL: url, apiKey: apiKey)
                server.supportedFormats = result.supportedFormats.map(\.rawValue)
                server.isActive = true
                server.lastCheckedAt = Date()
                if !result.supportedFormats.contains(server.activeFormat),
                   let best = result.supportedFormats.first {
                    server.activeFormat = best
                }
                try? modelContext.save()
            } catch {
                server.isActive = false
                server.lastCheckedAt = Date()
                try? modelContext.save()
            }
            isReprobing = false
        }
    }
}
```

- [ ] **Step 4: Verify all three views compile**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ModelRunner/Features/Settings/ServerListView.swift ModelRunner/Features/Settings/AddServerView.swift ModelRunner/Features/Settings/ServerDetailView.swift
git commit -m "feat: server management UI — list, add with probe, edit with format picker"
```

---

## Task 17: Model Picker — ModelPickerView & ModelPickerViewModel

**Files:**
- Create: `ModelRunner/Features/ModelPicker/ModelPickerViewModel.swift`
- Create: `ModelRunner/Features/ModelPicker/ModelPickerView.swift`

- [ ] **Step 1: Create ModelPickerViewModel**

```swift
// ModelRunner/Features/ModelPicker/ModelPickerViewModel.swift
import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "ModelPicker")

/// Transient remote model representation for the picker
struct RemoteModel: Identifiable, Sendable {
    let id: String              // model ID from server
    let serverID: UUID
    let serverName: String
    var lastMeasuredTokPerSec: Double?
    /// Whether this model returned reasoning_content during server probe
    var supportsThinking: Bool

    var modelIdentity: String {
        "remote:\(serverID.uuidString):\(id)"
    }
}

/// A section in the model picker — grouped by source
struct ModelPickerSection: Identifiable {
    let id: String
    let title: String
    let models: [PickerModel]
}

/// Unified model for the picker — wraps both local and remote
struct PickerModel: Identifiable {
    let id: String
    let displayName: String
    let source: ModelSource
    let serverID: UUID?
    let serverName: String?
    let tokPerSec: Double?
    let isOnline: Bool
    /// Whether this model supports thinking/reasoning (detected during probe)
    let supportsThinking: Bool

    /// Build a SelectedModel from this picker entry
    func toSelectedModel() -> SelectedModel {
        SelectedModel(backendID: id, displayName: displayName, source: source)
    }
}

@Observable
@MainActor
final class ModelPickerViewModel {
    var sections: [ModelPickerSection] = []
    var isLoading: Bool = false

    private var modelContext: ModelContext?

    func load(modelContext: ModelContext) async {
        self.modelContext = modelContext
        isLoading = true
        var newSections: [ModelPickerSection] = []

        // Section 1: On-Device models
        let localModels = fetchLocalModels(modelContext: modelContext)
        if !localModels.isEmpty {
            newSections.append(ModelPickerSection(id: "local", title: "On Device", models: localModels))
        }

        // Section 2+: Remote servers
        let servers = fetchServers(modelContext: modelContext)
        for server in servers {
            let remoteModels = await discoverRemoteModels(server: server, modelContext: modelContext)
            if !remoteModels.isEmpty {
                newSections.append(ModelPickerSection(
                    id: server.id.uuidString,
                    title: server.name,
                    models: remoteModels
                ))
            }
        }

        sections = newSections
        isLoading = false
    }

    private func fetchLocalModels(modelContext: ModelContext) -> [PickerModel] {
        let descriptor = FetchDescriptor<DownloadedModel>(
            sortBy: [SortDescriptor(\.lastUsedDate, order: .reverse)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }

        return models.map { model in
            let identity = "local:\(model.repoId)"
            let stats = fetchStats(identity: identity, modelContext: modelContext)
            return PickerModel(
                id: model.repoId,
                displayName: "\(model.displayName) \(model.quantization)",
                source: .local,
                serverID: nil,
                serverName: nil,
                tokPerSec: stats?.lastMeasuredTokPerSec,
                isOnline: true,
                supportsThinking: false  // Local models: detected later when llama.cpp ships
            )
        }
    }

    private func fetchServers(modelContext: ModelContext) -> [ServerConnection] {
        let descriptor = FetchDescriptor<ServerConnection>(
            sortBy: [SortDescriptor(\.addedAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func discoverRemoteModels(server: ServerConnection, modelContext: ModelContext) async -> [PickerModel] {
        guard let url = server.parsedBaseURL else { return [] }

        let apiKey: String? = {
            guard let ref = server.apiKeyRef else { return nil }
            return KeychainService.retrieve(account: ref)
        }()

        do {
            // Full probe — discovers models, formats, AND thinking capability
            let result = try await ServerProbe.probe(baseURL: url, apiKey: apiKey)

            // Update server reachability
            server.isActive = true
            server.lastCheckedAt = Date()
            try? modelContext.save()

            return result.models.map { modelID in
                let identity = "remote:\(server.id.uuidString):\(modelID)"
                let stats = fetchStats(identity: identity, modelContext: modelContext)
                return PickerModel(
                    id: modelID,
                    displayName: modelID,
                    source: .remote(serverID: server.id),
                    serverID: server.id,
                    serverName: server.name,
                    tokPerSec: stats?.lastMeasuredTokPerSec,
                    isOnline: true,
                    supportsThinking: result.thinkingModelIDs.contains(modelID)
                )
            }
        } catch {
            logger.warning("Failed to discover models on \(server.name): \(error)")
            server.isActive = false
            server.lastCheckedAt = Date()
            try? modelContext.save()
            return []
        }
    }

    private func fetchStats(identity: String, modelContext: ModelContext) -> ModelUsageStats? {
        let descriptor = FetchDescriptor<ModelUsageStats>(
            predicate: #Predicate { $0.modelIdentity == identity }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
```

- [ ] **Step 2: Create ModelPickerView**

```swift
// ModelRunner/Features/ModelPicker/ModelPickerView.swift
import SwiftUI
import SwiftData

struct ModelPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var pickerVM = ModelPickerViewModel()

    let onSelect: (PickerModel) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0C18").ignoresSafeArea()

                if pickerVM.isLoading {
                    ProgressView("Loading models...")
                        .foregroundStyle(Color(hex: "#9896B0"))
                        .tint(Color(hex: "#8B7CF0"))
                } else if pickerVM.sections.isEmpty {
                    ContentUnavailableView(
                        "No Models Available",
                        systemImage: "cpu",
                        description: Text("Download a model or add a remote server in Settings.")
                    )
                } else {
                    modelList
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(hex: "#9896B0"))
                }
            }
            .task {
                await pickerVM.load(modelContext: modelContext)
            }
        }
    }

    private var modelList: some View {
        List {
            ForEach(pickerVM.sections) { section in
                Section(section.title) {
                    ForEach(section.models) { model in
                        Button {
                            onSelect(model)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(model.isOnline ? .white : Color(hex: "#6B6980"))

                                    if !model.isOnline {
                                        Text("offline")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                }

                                Spacer()

                                if model.supportsThinking {
                                    Image(systemName: "brain")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#8B7CF0").opacity(0.7))
                                }

                                if let tokPerSec = model.tokPerSec {
                                    Text(String(format: "%.1f tok/s", tokPerSec))
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#9896B0"))
                                } else {
                                    Text("— tok/s")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(Color(hex: "#6B6980"))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(!model.isOnline)
                        .listRowBackground(Color(hex: "#1A1830"))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
```

- [ ] **Step 3: Verify both views compile**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ModelRunner/Features/ModelPicker/ModelPickerViewModel.swift ModelRunner/Features/ModelPicker/ModelPickerView.swift
git commit -m "feat: unified model picker with local and remote model sections"
```

---

## Task 18: Wire AppContainer — selectedModel, Backend Factory, Settings Tab

**Files:**
- Modify: `ModelRunner/App/AppContainer.swift`
- Modify: `ModelRunner/ContentView.swift`

- [ ] **Step 1: Update AppContainer with selectedModel and backend factory**

Add to `AppContainer.swift` after the `activeModelQuant` property:

```swift
// MARK: - Unified Model Selection

/// Currently selected model — persisted to UserDefaults, works for both local and remote.
var selectedModel: SelectedModel? {
    didSet {
        if let model = selectedModel,
           let data = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(data, forKey: "selectedModel")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedModel")
        }
    }
}

/// Build an InferenceBackend for the given picker model selection.
/// Returns nil if the server connection can't be found.
func buildBackend(for pickerModel: PickerModel, modelContext: ModelContext) -> (any InferenceBackend)? {
    guard case .remote(let serverID) = pickerModel.source else {
        // Local backend — not yet implemented (Phase: llama.cpp XCFramework)
        return nil
    }

    let descriptor = FetchDescriptor<ServerConnection>(
        predicate: #Predicate { $0.id == serverID }
    )
    guard let server = try? modelContext.fetch(descriptor).first,
          let baseURL = server.parsedBaseURL else { return nil }

    let apiKey: String? = {
        guard let ref = server.apiKeyRef else { return nil }
        return KeychainService.retrieve(account: ref)
    }()

    let adapter: any APIAdapter = switch server.activeFormat {
    case .openAIChat: OpenAIChatAdapter()
    case .openAILegacy: OpenAILegacyAdapter()
    case .anthropicMessages: AnthropicMessagesAdapter()
    }

    return RemoteInferenceBackend(
        modelID: pickerModel.id,
        serverID: server.id,
        serverName: server.name,
        baseURL: baseURL,
        adapter: adapter,
        apiKey: apiKey
    )
}
```

In the `init()`, restore selectedModel from UserDefaults:

```swift
// Restore selected model from UserDefaults
if let data = UserDefaults.standard.data(forKey: "selectedModel"),
   let model = try? JSONDecoder().decode(SelectedModel.self, from: data) {
    self.selectedModel = model
}
```

- [ ] **Step 2: Add Settings tab to ContentView**

In `ContentView.swift`, add a Settings tab after the Chat tab. Add the enum case:

```swift
enum Tab { case browse, library, chat, settings }
```

Add the tab inside the TabView, after the Chat tab:

```swift
NavigationStack {
    ServerListView()
}
.tabItem {
    Label("Settings", systemImage: "gear")
}
.tag(Tab.settings)
```

- [ ] **Step 3: Update ChatView setup in ContentView to use model picker**

Replace the Chat tab's NavigationStack content to pass the selected backend:

```swift
NavigationStack {
    ChatView(
        activeModelURL: container.activeModelURL,
        activeModelName: container.selectedModel?.displayName ?? container.activeModelName ?? "",
        activeModelQuant: container.activeModelQuant ?? ""
    )
}
.tabItem {
    Label("Chat", systemImage: "bubble.left.fill")
}
.tag(Tab.chat)
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ModelRunner/App/AppContainer.swift ModelRunner/ContentView.swift
git commit -m "feat: AppContainer selectedModel + backend factory, Settings tab in ContentView"
```

---

## Task 19: Wire ChatView — Model Picker Sheet & Remote Backend Setup

**Files:**
- Modify: `ModelRunner/Features/Chat/ChatView.swift`

- [ ] **Step 1: Update ChatView to support model picker and remote backends**

Key changes to `ChatView.swift`:

1. Add `@State private var showModelPicker = false`
2. Add `@State private var enableThinking = false`
3. Make toolbar title tappable to open model picker
4. Update `ChatInputBar` call to pass `enableThinking` binding
5. Update `setupViewModel()` to create ChatViewModel with remote backend when selected
6. Add model picker sheet

Replace the toolbar section:
```swift
.toolbar {
    ToolbarItem(placement: .principal) {
        Button {
            showModelPicker = true
        } label: {
            VStack(spacing: 2) {
                Text("Chat")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                if let selected = container.selectedModel {
                    Text(selected.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#6B6980"))
                } else if !activeModelName.isEmpty && activeModelName != "No Model" {
                    Text("\(activeModelName) · \(activeModelQuant)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#6B6980"))
                }
            }
        }
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gear")
                .foregroundStyle(Color(hex: "#9896B0"))
        }
        .disabled(viewModel == nil)
    }
}
```

Add model picker sheet after the settings sheet:
```swift
.sheet(isPresented: $showModelPicker) {
    ModelPickerView { pickerModel in
        selectModel(pickerModel)
    }
}
```

Update `ChatInputBar` call to pass `enableThinking`:
```swift
ChatInputBar(
    text: $inputText,
    isGenerating: vm.isGenerating,
    isModelLoaded: vm.loadingState == .ready,
    onSend: {
        vm.send(text: inputText)
        inputText = ""
    },
    onStop: { vm.stop() },
    onToggleHistory: { vm.showingHistory.toggle() },
    enableThinking: $enableThinking
)
```

Add the `selectModel` method:
```swift
private func selectModel(_ pickerModel: PickerModel) {
    container.selectedModel = pickerModel.toSelectedModel()
    // Auto-enable thinking toggle if model supports it
    enableThinking = pickerModel.supportsThinking

    if let backend = container.buildBackend(for: pickerModel, modelContext: modelContext) {
        let vm = ChatViewModel(backend: backend)
        vm.configure(modelContext: modelContext)
        let identity = pickerModel.toSelectedModel().modelIdentity
        vm.loadMostRecentConversation(forIdentity: identity, modelContext: modelContext)
        if vm.activeConversation == nil {
            vm.startNewConversation(for: pickerModel.toSelectedModel())
        }
        viewModel = vm
    }
}
```

Update `setupViewModel()` to check for selected remote model first:
```swift
private func setupViewModel() async {
    // Check for remote model selection first
    if let selected = container.selectedModel, selected.source.isRemote {
        // Build a PickerModel from the selection to use buildBackend
        let pickerModel = PickerModel(
            id: selected.backendID,
            displayName: selected.displayName,
            source: selected.source,
            serverID: nil,
            serverName: nil,
            tokPerSec: nil,
            isOnline: true
        )
        if let backend = container.buildBackend(for: pickerModel, modelContext: modelContext) {
            let vm = ChatViewModel(backend: backend)
            vm.configure(modelContext: modelContext)
            vm.loadMostRecentConversation(forIdentity: selected.modelIdentity, modelContext: modelContext)
            viewModel = vm
            return
        }
    }

    // Fall back to local model setup
    guard let url = activeModelURL else {
        viewModel = nil
        return
    }
    let model = activeModel(from: container)
    let vm = ChatViewModel(
        inferenceService: container.inferenceService,
        inferenceParams: container.inferenceParams(activeModel: model)
    )
    viewModel = vm
    await vm.loadModel(url: url)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -15`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ModelRunner/Features/Chat/ChatView.swift
git commit -m "feat: wire model picker sheet and remote backend into ChatView"
```

---

## Task 20: End-to-End Integration Test

**Files:** None created — this is a manual verification step

- [ ] **Step 1: Build and run on simulator**

Run: `xcodebuild build -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5`
Expected: BUILD SUCCEEDED with no errors

- [ ] **Step 2: Verify all existing tests pass**

Run: `xcodebuild test -project ModelRunner.xcodeproj -scheme ModelRunner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -15`
Expected: All tests pass (existing + new adapter tests + probe tests + backend tests)

- [ ] **Step 3: Manual smoke test (if simulator available)**

1. Launch app → verify existing Browse/Library/Chat tabs work
2. Navigate to Settings tab → verify empty server list appears
3. Add server: name "Nemotron", URL `https://nemo34bone.trevestforvorolares.olares.com`
4. Verify probe detects models and formats (OpenAI Chat + Legacy)
5. Return to Chat → tap toolbar title → verify model picker shows "Nemotron" section
6. Select `nemotron-3-nano-4b` → send "Hello" → verify streaming response appears
7. Verify tok/s badge shows during generation
8. Toggle thinking on → send another message → verify thinking block appears if model produces reasoning_content

- [ ] **Step 4: Commit any fixes from smoke testing**

```bash
git add -A
git commit -m "fix: integration fixes from end-to-end smoke test"
```
