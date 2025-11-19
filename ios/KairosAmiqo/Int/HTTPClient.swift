import Foundation

struct HTTPClient {
    let base: URL
    let session: URLSession = .shared

    func get(path: String, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "GET"
        headers.forEach { key, value in req.setValue(value, forHTTPHeaderField: key) }
        return try await session.data(for: req)
    }

    func post(path: String, body: Data, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { key, value in req.setValue(value, forHTTPHeaderField: key) }
        req.httpBody = body
        return try await session.data(for: req)
    }

    func postJSON<T: Encodable>(path: String, body: T, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { key, value in req.setValue(value, forHTTPHeaderField: key) }
        req.httpBody = try JSONEncoder().encode(body)
        return try await session.data(for: req)
    }

    func patch(path: String, body: Data, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { key, value in req.setValue(value, forHTTPHeaderField: key) }
        req.httpBody = body
        return try await session.data(for: req)
    }

    func delete(path: String, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        headers.forEach { key, value in req.setValue(value, forHTTPHeaderField: key) }
        return try await session.data(for: req)
    }
}
