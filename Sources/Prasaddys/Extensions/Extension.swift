import Foundation
import Alamofire

public extension APIClient {
    func get<T: Decodable & Sendable>(
        _ path: String,
        baseURL: URL,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        try await performRequest(.get, path: path, baseURL: baseURL, parameters: parameters, headers: headers)
    }

    func post<T: Decodable & Sendable>(
        _ path: String,
        baseURL: URL,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        try await performRequest(.post, path: path, baseURL: baseURL, parameters: parameters, headers: headers, encoding: JSONEncoding.default)
    }

    func delete<T: Decodable & Sendable>(
        _ path: String,
        baseURL: URL,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        try await performRequest(.delete, path: path, baseURL: baseURL, parameters: parameters, headers: headers, encoding: URLEncoding.default)
    }

    // Envelope support
    func getWrapped<T: Decodable & Sendable>(
        _ path: String,
        baseURL: URL,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> Envelope<T> {
        try await get(path, baseURL: baseURL, parameters: parameters, headers: headers)
    }

    // Paginated support
    func getPaginated<T: Decodable & Sendable>(
        _ path: String,
        baseURL: URL,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> PaginatedEnvelope<T> {
        try await get(path, baseURL: baseURL, parameters: parameters, headers: headers)
    }
}

// Generic wrapper for standard `{ data: T }` API responses
public struct Envelope<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: T
}
