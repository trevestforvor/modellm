import Testing
import Foundation
@testable import ModelRunner

// MARK: - Mock URLSession

/// Synchronous mock — returns preset data/response or throws preset error.
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    enum MockResult {
        case success(data: Data, statusCode: Int)
        case failure(Error)
    }
    var result: MockResult

    init(result: MockResult) { self.result = result }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        switch result {
        case .success(let data, let code):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: code,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Fixture Bundle Anchor

/// Class-based anchor so Bundle(for:) can locate the test bundle.
private final class FixtureBundleAnchor {}

// MARK: - Fixture Loader

private func fixture(_ name: String) -> Data {
    let bundle = Bundle(for: FixtureBundleAnchor.self)
    if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
       let data = try? Data(contentsOf: url) {
        return data
    }
    // Fallback: try without subdirectory (in case resources are flat in bundle)
    if let url = bundle.url(forResource: name, withExtension: "json"),
       let data = try? Data(contentsOf: url) {
        return data
    }
    fatalError("Fixture not found: \(name).json — verify Fixtures/ is in ModelRunnerTests Copy Bundle Resources")
}

// MARK: - Tests

@Suite("HFAPIService")
struct HFAPIServiceTests {

    @Test("searchGGUFModels decodes valid search response")
    func testSearchDecoding() async throws {
        let data = fixture("hf_search_gguf")
        let mock = MockURLSession(result: .success(data: data, statusCode: 200))
        let service = HFAPIService(session: mock)
        let results = try await service.searchGGUFModels(query: "llama", offset: 0)
        #expect(results.count == 3)
        #expect(results[0].id == "bartowski/Meta-Llama-3-8B-Instruct-GGUF")
        #expect(results[0].downloads == 124300)
        #expect(results[0].siblings?.count == 4)
    }

    @Test("LFS size is preferred over sibling size when both present")
    func testLFSSizePreferred() async throws {
        let data = fixture("hf_search_gguf")
        let mock = MockURLSession(result: .success(data: data, statusCode: 200))
        let service = HFAPIService(session: mock)
        let results = try await service.searchGGUFModels(query: "", offset: 0)
        let firstGGUF = results[0].siblings?.first(where: { $0.isGGUF })
        // sibling.size is 136 (pointer), lfs.size is 4920000000
        #expect(firstGGUF?.trueSize == 4_920_000_000)
    }

    @Test("HTTP 429 throws HFAPIError.rateLimited")
    func testRateLimitHandling() async throws {
        let mock = MockURLSession(result: .success(data: Data("[]".utf8), statusCode: 429))
        let service = HFAPIService(session: mock)
        do {
            _ = try await service.searchGGUFModels(query: "", offset: 0)
            Issue.record("Expected rateLimited error to be thrown")
        } catch HFAPIError.rateLimited {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("empty results array decodes without error")
    func testEmptyResultsDecoding() async throws {
        let data = fixture("hf_search_empty")
        let mock = MockURLSession(result: .success(data: data, statusCode: 200))
        let service = HFAPIService(session: mock)
        let results = try await service.searchGGUFModels(query: "nonsense", offset: 0)
        #expect(results.isEmpty)
    }

    @Test("fetchModelDetail returns single model with full siblings list")
    func testFetchModelDetail() async throws {
        let data = fixture("hf_model_detail")
        let mock = MockURLSession(result: .success(data: data, statusCode: 200))
        let service = HFAPIService(session: mock)
        let detail = try await service.fetchModelDetail(repoId: "bartowski/Meta-Llama-3-8B-Instruct-GGUF")
        #expect(detail.id == "bartowski/Meta-Llama-3-8B-Instruct-GGUF")
        // 3 GGUF variants + config.json = 4 siblings
        #expect(detail.siblings?.count == 4)
        let ggufFiles = detail.siblings?.filter { $0.isGGUF } ?? []
        #expect(ggufFiles.count == 3)
    }

    @Test("non-GGUF siblings are filtered by isGGUF property")
    func testNonGGUFFilesFiltered() async throws {
        let data = fixture("hf_search_gguf")
        let mock = MockURLSession(result: .success(data: data, statusCode: 200))
        let service = HFAPIService(session: mock)
        let results = try await service.searchGGUFModels(query: "", offset: 0)
        // First model has 4 siblings but only 2 GGUF files
        let firstModel = results[0]
        let ggufSiblings = firstModel.siblings?.filter { $0.isGGUF } ?? []
        let nonGGUF = firstModel.siblings?.filter { !$0.isGGUF } ?? []
        #expect(ggufSiblings.count == 2)  // Q4_K_M and Q8_0
        #expect(nonGGUF.count == 2)        // config.json and README.md
    }
}
