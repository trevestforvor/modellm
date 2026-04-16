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
        let json = """
        {"models":[{"name":"nemotron-3-nano-4b","model":"nemotron-3-nano-4b"}],"data":[{"id":"nemotron-3-nano-4b"}]}
        """.data(using: .utf8)!

        let models = try ServerProbe.parseModelsResponse(json)
        XCTAssertTrue(models.contains("nemotron-3-nano-4b"))
        // Should not have duplicates
        XCTAssertEqual(models.count, 1)
    }

    func testParseModelsResponse_emptyData() throws {
        let json = """
        {"data":[]}
        """.data(using: .utf8)!

        let models = try ServerProbe.parseModelsResponse(json)
        XCTAssertTrue(models.isEmpty)
    }
}
