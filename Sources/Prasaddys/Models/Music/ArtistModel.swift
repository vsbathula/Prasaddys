import Foundation

// MARK: - ArtistModel
public struct ArtistModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - ArtistsResponse
public struct ArtistsResponse: Decodable {
    public  let artists: [String]
    public  let pagination: PaginationModel
}
