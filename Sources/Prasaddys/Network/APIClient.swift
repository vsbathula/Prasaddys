import Foundation
import Alamofire

public class APIClient: @unchecked Sendable {
    
    private let baseURL: URL
    private let authorizationToken: String?
    private let session: Session
    
    public init(baseURL: URL, authorizationToken: String? = nil, session: Session = .default) {
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
    
    public func searchYouTube(query: String, pageToken: String? = nil) async throws -> YouTubeSearchResultsModel {
        guard let youTubeAPIKey = AppConfigUtil.getYtApiKey(),
              let youTubeBaseUrl = AppConfigUtil.getYtApiUrl() else {
            throw APIError.custom("YouTube API key or URL is missing.")
        }
        
        // Build the full URL with query parameters
        guard var urlComponents = URLComponents(string: youTubeBaseUrl) else {
            throw APIError.invalidURL
        }
        
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "key", value: youTubeAPIKey)
        ]
        
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        // Perform the request using the complete URL
        return try await withCheckedThrowingContinuation { continuation in
            session.request(url, method: .get)
                .validate()
                .responseDecodable(of: YouTubeSearchResultsModel.self) { response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure(let error):
                        continuation.resume(throwing: self.mapAlamofireError(error, data: response.data))
                    }
                }
        }
    }
    
    public func search<T: Decodable & Sendable>(
        endpoint: String,
        query: String,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        
        let parameters: Parameters = [
            "q": query,
            "page": page,
            "limit": pageSize
        ]
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, parameters: parameters, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(T.self, decoder: decoder) // ⬅️ The key change: using T.self
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let searchResponse = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in search response"])
        }
        
        return searchResponse
    }
    
    public func fetchData<T: Decodable & Sendable>(
        endpoint: String,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let parameters: Parameters = [
            "page": page,
            "limit": pageSize
        ]
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, parameters: parameters, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(T.self, decoder: decoder)
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let dataResponse = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in response"])
        }
        return dataResponse
    }
    
    public func fetchAlbumById(_ albumRatingKey: String) async throws -> AlbumDetailResponse {
        let url = baseURL.appendingPathComponent("/albums/album/\(albumRatingKey)")
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
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
    
    public func fetchMovieById(_ movieRatingKey: String) async throws -> MovieDetailResponse {
        let url = baseURL.appendingPathComponent("/movies/movie/\(movieRatingKey)")
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(MovieDetailResponse.self, decoder: decoder)
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let albumDetail = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in movie detail response"])
        }
        
        return albumDetail
    }
    
    public func fetchTrackById(_ trackRatingKey: String) async throws -> Track {
        let url = baseURL.appendingPathComponent("/tracks/track/\(trackRatingKey)")
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(Track.self, decoder: decoder)
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let trackDetail = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data in album detail response"])
        }
        
        return trackDetail
    }
    
    public func savePlaybackState(currentlyPlayingTrack: String, isShuffleEnabled: Bool, shuffledTracksList: [String], originalTracksList: [String]) async throws {
        let url = baseURL.appendingPathComponent("/user/playback/state/save")
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
        }
        
        guard let userId = KeyChainUtil.getUserId(), !userId.isEmpty else {
            throw NSError(domain: "APIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not found."])
        }
        
        let parameters = PlaybackStatePayload(
            userId: userId,
            currentPlayingTrack: currentlyPlayingTrack,
            playbackPosition: 0.0,
            isShuffleEnabled: isShuffleEnabled,
            shuffledTrackContext: shuffledTracksList,
            originalTrackContext: originalTracksList
        )
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let playbackState = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Playback state not saved."])
        }
        
        PrintUtil.printDebug(data: "✅ Playback state saved successfully!")
    }
    
    public func fetchPlaybackState() async  throws -> PlaybackStateResponse {
        guard let userId = KeyChainUtil.getUserId(), !userId.isEmpty else {
            throw NSError(domain: "APIClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User ID not found."])
        }
        
        let url = baseURL.appendingPathComponent("/user/playback/state/get/\(userId)")
        
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let token = authorizationToken {
            headers.add(name: "Authorization", value: token)
        }
        
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = await session
            .request(url, method: .get, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(PlaybackStateResponse.self, decoder: decoder)
            .response
        
        if let error = response.error {
            throw error
        }
        
        guard let playBackDetail = response.value else {
            throw NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to get playback state"])
        }
        
        return playBackDetail
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
