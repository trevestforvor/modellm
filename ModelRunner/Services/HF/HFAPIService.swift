import Foundation

// URLSessionProtocol is defined here to enable mock injection in tests.
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

actor HFAPIService {
    let pageSize = 20
    private let session: any URLSessionProtocol
    private let baseURL = URL(string: "https://huggingface.co/api")!
    var token: String?

    // Simple in-memory cache. Key: "query:offset". TTL: 5 minutes.
    private var cache: [String: (result: [HFModelListResponse], expiry: Date)] = [:]
    private let cacheTTL: TimeInterval = 300

    init(session: any URLSessionProtocol = URLSession.shared, token: String? = nil) {
        self.session = session
        self.token = token
    }

    // MARK: - Search

    func searchGGUFModels(query: String, offset: Int) async throws -> [HFModelListResponse] {
        let cacheKey = "\(query):\(offset)"
        if let cached = cache[cacheKey], cached.expiry > Date() {
            return cached.result
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("models"),
                                       resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            .init(name: "library",   value: "gguf"),
            .init(name: "sort",      value: "downloads"),
            .init(name: "direction", value: "-1"),
            .init(name: "limit",     value: "\(pageSize)"),
            .init(name: "full",      value: "true"),
            .init(name: "offset",    value: "\(offset)"),
        ]
        if !query.isEmpty {
            queryItems.append(.init(name: "search", value: query))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw HFAPIError.invalidURL }

        let result = try await fetch([HFModelListResponse].self, url: url)
        cache[cacheKey] = (result: result, expiry: Date().addingTimeInterval(cacheTTL))
        return result
    }

    // MARK: - Detail

    func fetchModelDetail(repoId: String) async throws -> HFModelListResponse {
        let url = baseURL.appendingPathComponent("models/\(repoId)")
        return try await fetch(HFModelListResponse.self, url: url)
    }

    // MARK: - Private

    private func fetch<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw HFAPIError.rateLimited }
            guard (200..<300).contains(http.statusCode) else {
                throw HFAPIError.httpError(http.statusCode)
            }
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw HFAPIError.decodingError(error)
        }
    }
}
