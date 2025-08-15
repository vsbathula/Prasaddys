import Foundation

// MARK: - AlbumsResponseModel
public struct AlbumsResponseModel: Decodable, Sendable {
    public  let albums: [Album]
    public  let pagination: PaginationModel
}

// MARK: - Album
public struct Album: Encodable, Decodable, Identifiable, Hashable, Equatable, Sendable {
    public var id: String { albumRatingKey }
    public  let albumArtist: String
    public  let albumTitle: String
    public  let albumYear: Int
    public  let albumRatingKey: String
    public  let albumThumbnail: String
    public  let albumComposer: String
}

// MARK: - AlbumDetailResponse
public struct AlbumDetailResponse: Codable, Sendable {
    public  let albumRatingKey: String
    public  let albumArtist: String
    public  let albumTitle: String
    public  let albumThumbnail: String
    public  let albumYear: Int
    public  let albumComposer: String
    public  let albumTracks: [Track]
}
