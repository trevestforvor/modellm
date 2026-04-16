import Foundation

// MARK: - API Format

public enum APIFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case openAIChat = "openai_chat"
    case openAILegacy = "openai_legacy"
    case anthropicMessages = "anthropic_messages"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAIChat: return "OpenAI Chat"
        case .openAILegacy: return "OpenAI Legacy"
        case .anthropicMessages: return "Anthropic Messages"
        }
    }

    public var endpointPath: String {
        switch self {
        case .openAIChat: return "/v1/chat/completions"
        case .openAILegacy: return "/v1/completions"
        case .anthropicMessages: return "/v1/messages"
        }
    }

    public var priority: Int {
        switch self {
        case .openAIChat: return 0
        case .openAILegacy: return 1
        case .anthropicMessages: return 2
        }
    }
}

// MARK: - API Adapter Protocol

public protocol APIAdapter: Sendable {
    static var format: APIFormat { get }

    func buildRequest(
        baseURL: URL,
        model: String,
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool,
        apiKey: String?
    ) -> URLRequest

    func parseTokenStream(
        from bytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<StreamToken, Error>
}
