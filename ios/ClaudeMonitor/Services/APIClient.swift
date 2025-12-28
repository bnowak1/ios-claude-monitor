import Foundation

actor APIClient {
    static let shared = APIClient()

    private var baseURLString: String {
        var urlString = UserDefaults.standard.string(forKey: "apiURL") ?? "http://localhost:3000"
        // Remove trailing slash if present
        if urlString.hasSuffix("/") {
            urlString = String(urlString.dropLast())
        }
        return urlString
    }

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? "dev-key-change-me"
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private init() {}

    private func buildURL(path: String) -> URL {
        let fullURL = "\(baseURLString)\(path)"
        print("[APIClient] Building URL: \(fullURL)")
        return URL(string: fullURL)!
    }

    // MARK: - API Methods

    func fetchSessions() async throws -> SessionsResponse {
        let url = buildURL(path: "/api/sessions")
        return try await request(url: url)
    }

    func fetchSession(id: String) async throws -> Session {
        let url = buildURL(path: "/api/sessions/\(id)")
        let response: SingleSessionResponse = try await request(url: url)
        return response.session
    }

    func fetchEvents(for sessionId: String, since: String? = nil, limit: Int = 50) async throws -> EventsResponse {
        var path = "/api/sessions/\(sessionId)/events?limit=\(limit)"
        if let since = since {
            path += "&since=\(since)"
        }
        let url = buildURL(path: path)
        return try await request(url: url)
    }

    func fetchAllEvents(since: String? = nil, limit: Int = 100) async throws -> EventsResponse {
        var path = "/api/events?limit=\(limit)"
        if let since = since {
            path += "&since=\(since)"
        }
        let url = buildURL(path: path)
        return try await request(url: url)
    }

    func fetchStats() async throws -> StatsResponse {
        let url = buildURL(path: "/api/stats")
        return try await request(url: url)
    }

    func checkHealth() async throws -> Bool {
        let url = buildURL(path: "/health")
        let _: HealthResponse = try await request(url: url)
        return true
    }

    // MARK: - Private

    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        print("[APIClient] Request: \(url.absoluteString)")
        print("[APIClient] API Key: \(apiKey.prefix(10))...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[APIClient] Error: Invalid response type")
            throw APIError.invalidResponse
        }

        print("[APIClient] Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            print("[APIClient] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[APIClient] Decode error: \(error)")
            print("[APIClient] Response: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Supporting Types

struct SingleSessionResponse: Codable {
    let session: Session
}

struct HealthResponse: Codable {
    let status: String
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Invalid API key"
        case .httpError(let code):
            return "Server error (HTTP \(code))"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        }
    }
}
