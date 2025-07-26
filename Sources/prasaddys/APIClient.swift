import Foundation
import Alamofire

public class APIClient: @unchecked Sendable {
    
    private let baseURL: URL
    private let authorizationToken: String?
    private let session: Session
    
    init(baseURL: URL, authorizationToken: String? = nil, session: Session = .default) {
        self.baseURL = baseURL
        self.authorizationToken = authorizationToken
        self.session = session
    }
    
    public func performRequest<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        baseURL: URL,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        data: Data? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        decoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }()
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        
        var request: DataRequest
        
        if let data = data {
            request = session.upload(data, to: url, method: method, headers: headers)
        } else {
            request = session.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            request
                .validate()
                .responseDecodable(of: T.self, decoder: decoder) { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: self.mapAlamofireError(error, data: response.data))
                    }
                }
        }
    }
    
    private func mapAlamofireError(_ error: AFError, data: Data?) -> APIError {
        if let urlError = error.underlyingError as? URLError {
            if urlError.code == .notConnectedToInternet {
                return .noInternetConnection
            }
            return .networkError(urlError)
        }
        
        switch error {
        case .sessionTaskFailed(let urlError as URLError) where urlError.code == .notConnectedToInternet:
            return .noInternetConnection
        case .responseSerializationFailed(let reason):
            return .decodingFailed(reason as! Error)
        case .parameterEncodingFailed(let reason):
            return .encodingFailed(reason as! Error)
        case .createUploadableFailed(let error),
                .createURLRequestFailed(let error),
                .requestAdaptationFailed(let error),
                .requestRetryFailed(_, let error):
            return .networkError(error)
        case .responseValidationFailed(let reason):
            if case let .unacceptableStatusCode(code) = reason {
                return .httpError(statusCode: code, data: data)
            }
            return .invalidRequest
        default:
            return .networkError(error)
        }
    }
    
    public func fetchAlbums(page: Int = 1, pageSize: Int = 20) async throws -> AlbumsResponseModel {
        let url = baseURL.appendingPathComponent("albums")
        let parameters: Parameters = [
            "page": page,
            "limit": pageSize
        ]
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, parameters: parameters, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(AlbumsResponseModel.self, decoder: decoder)
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let albumsResponse = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in albums response"])
        }
        
        return albumsResponse
    }
    
    func fetchAlbumById(_ albumRatingKey: String) async throws -> AlbumDetailResponse {
        let url = baseURL.appendingPathComponent("/albums/album/\(albumRatingKey)")
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(AlbumDetailResponse.self, decoder: decoder)
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let albumDetail = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in album detail response"])
        }
        
        return albumDetail
    }
    
    func searchAlbums(query: String, page: Int = 1, pageSize: Int = 20) async throws -> AlbumsResponseModel {
            let url = baseURL.appendingPathComponent("/albums/search")
            
            let parameters: Parameters = [
                "q": query,
                "page": page,
                "limit": pageSize
            ]
            
            var headers: HTTPHeaders = ["Accept": "application/json"]
            if let token = authorizationToken {
                headers.add(name: "Authorization", value: "Bearer \(token)")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let response = await session
                .request(url, method: .get, parameters: parameters, headers: headers)
                .validate(statusCode: 200..<300)
                .serializingDecodable(AlbumsResponseModel.self, decoder: decoder)
                .response
            
            if let error = response.error {
                throw error
            }
            
            guard let albumsResponse = response.value else {
                throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in search albums response"])
            }
            
            return albumsResponse
        }
    
}

public enum APIError: Error, Sendable {
    case noInternetConnection
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int, data: Data?)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case invalidRequest
    case invalidData
    case custom(String)
}
