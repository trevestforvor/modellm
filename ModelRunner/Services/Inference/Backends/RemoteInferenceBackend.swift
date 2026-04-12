import Foundation
import OSLog

private let logger = Logger(subsystem: "com.modelrunner", category: "RemoteInferenceBackend")

public final class RemoteInferenceBackend: InferenceBackend, @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let source: ModelSource

    private let baseURL: URL
    private let adapter: any APIAdapter
    private let apiKey: String?
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
            baseURL: baseURL, model: id, messages: messages,
            params: params, enableThinking: enableThinking, apiKey: apiKey
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200...299).contains(httpResponse.statusCode) {
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody.append(Character(UnicodeScalar(byte)))
                            if errorBody.count > 1000 { break }
                        }
                        continuation.finish(throwing: RemoteInferenceError.httpError(
                            statusCode: httpResponse.statusCode, body: errorBody
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
