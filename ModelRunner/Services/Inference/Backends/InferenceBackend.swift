import Foundation

// MARK: - Stream Token

public enum StreamToken: Sendable {
    case thinking(String)   // reasoning_content delta
    case content(String)    // regular content delta
    case done               // stream finished
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

// MARK: - Model Source

public enum ModelSource: Hashable, Codable, Sendable {
    case local
    case remote(serverID: UUID)

    var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }
}

// MARK: - Selected Model

public struct SelectedModel: Codable, Sendable, Equatable {
    public let backendID: String
    public let displayName: String
    public let source: ModelSource

    public init(backendID: String, displayName: String, source: ModelSource) {
        self.backendID = backendID
        self.displayName = displayName
        self.source = source
    }

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

public protocol InferenceBackend: Sendable {
    var id: String { get }
    var displayName: String { get }
    var source: ModelSource { get }

    func generate(
        messages: [ChatMessage],
        params: InferenceParams,
        enableThinking: Bool
    ) -> AsyncThrowingStream<StreamToken, Error>

    func stop() async
}
