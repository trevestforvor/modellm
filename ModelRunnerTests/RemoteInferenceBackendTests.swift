import XCTest
@testable import ModelRunner

final class RemoteInferenceBackendTests: XCTestCase {

    func testProperties() {
        let serverID = UUID()
        let backend = RemoteInferenceBackend(
            modelID: "llama3:70b",
            serverID: serverID,
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
