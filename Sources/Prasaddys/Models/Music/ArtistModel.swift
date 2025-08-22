import Foundation

// MARK: - ArtistModel
public struct ArtistModel: Encodable, Decodable, Identifiable, Sendable {
    public  let id: String
    public  let name: String
}

// MARK: - ArtistsResponse
public struct ArtistsResponse: Decodable, Encodable, Sendable {
    public  let artists: [ArtistModel]
    public  let pagination: PaginationModel
}
