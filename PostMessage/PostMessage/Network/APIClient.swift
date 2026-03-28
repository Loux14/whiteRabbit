import Foundation

enum APIError: Error {
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case pseudoTaken
}

actor APIClient {
    static let shared = APIClient()

    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:8000"
    #else
    private let baseURL = "http://192.168.x.x:8000" // TODO: set server IP
    #endif
    private let decoder: JSONDecoder = JSONDecoder()
    private let encoder: JSONEncoder = JSONEncoder()

    // MARK: - Connectivity

    func ping() async throws {
        let _: [String: String] = try await get("/health", token: nil)
    }

    // MARK: - Register

    func register(pseudo: String) async throws -> RegisterResponse {
        let body = RegisterRequest(pseudo: pseudo)
        return try await post("/register", body: body, token: nil)
    }

    // MARK: - Keys

    func uploadKeys(_ bundle: KeyBundleUpload, token: String) async throws {
        let _: [String: String] = try await post("/keys", body: bundle, token: token)
    }

    func fetchKeys(for pseudo: String) async throws -> KeyBundleResponse {
        return try await get("/keys/\(pseudo)", token: nil)
    }

    // MARK: - Device token

    func uploadDeviceToken(_ token: String, authToken: String) async throws {
        let _: [String: String] = try await post("/device-token",
                                                  body: ["token": token],
                                                  token: authToken)
    }

    // MARK: - Messages

    func sendMessage(_ request: SendMessageRequest, token: String) async throws -> SendMessageResponse {
        return try await post("/messages", body: request, token: token)
    }

    func fetchMessages(token: String) async throws -> [IncomingMessage] {
        let response: MessagesResponse = try await get("/messages", token: token)
        return response.messages
    }

    func deleteMessage(id: Int, token: String) async throws {
        let _: [String: String] = try await delete("/messages/\(id)", token: token)
    }

    // MARK: - Helpers

    private func get<T: Decodable>(_ path: String, token: String?) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "GET"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B, token: String?) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func delete<T: Decodable>(_ path: String, token: String?) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "DELETE"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode == 409 { throw APIError.pseudoTaken }
        guard (200...299).contains(http.statusCode) else { throw APIError.httpError(http.statusCode) }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
