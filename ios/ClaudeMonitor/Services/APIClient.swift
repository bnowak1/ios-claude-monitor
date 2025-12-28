import Foundation

actor APIClient {
    static let shared = APIClient()

    private var baseURL: URL {
        guard let urlString = UserDefaults.standard.string(forKey: "apiURL"),
              let url = URL(string: urlString) else {
            return URL(string: "http://localhost:3000")!
        }
        return url
    }

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? "dev-key-change-me"
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private init() {}

    // MARK: - API Methods

    func fetchSessions() async throws -> SessionsResponse {
        let url = baseURL.appendingPathComponent("api/sessions")
        return try await request(url: url)
    }

    func fetchSession(id: String) async throws -> Session {
        let url = baseURL.appendingPathComponent("api/sessions/\(id)")
        let response: SingleSessionResponse = try await request(url: url)
        return response.session
    }

    func fetchEvents(for sessionId: String, since: String? = nil, limit: Int = 50) async throws -> EventsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/sessions/\(sessionId)/events"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: since))
        }

        components.queryItems = queryItems

        return try await request(url: components.url!)
    }

    func fetchAllEvents(since: String? = nil, limit: Int = 100) async throws -> EventsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/events"), resolvingAgainstBaseURL: false)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let since = since {
            queryItems.append(URLQueryItem(name: "since", value: since))
        }

        components.queryItems = queryItems

        return try await request(url: components.url!)
    }

    func fetchStats() async throws -> StatsResponse {
        let url = baseURL.appendingPathComponent("api/stats")
        return try await request(url: url)
    }

    func checkHealth() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        let _: HealthResponse = try await request(url: url)
        return true
    }

    // MARK: - Private

    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decode error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "nil")")
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
