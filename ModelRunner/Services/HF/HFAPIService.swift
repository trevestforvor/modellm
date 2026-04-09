import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

actor HFAPIService {
    let pageSize = 20
    private let session: any URLSessionProtocol
    private let baseURL = URL(string: "https://huggingface.co/api")!
    var token: String?

    init(session: any URLSessionProtocol = URLSession.shared, token: String? = nil) {
        self.session = session
        self.token = token
    }

    // Implementation added in Plan 02
}
