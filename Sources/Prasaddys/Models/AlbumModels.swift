import Foundation

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

// MARK: - TrackResponseModel
public  struct TrackResponseModel: Codable, Sendable {
    public  let tracks: [Track]
    public  let pagination: Pagination
}

// MARK: - Track
public struct Track: Codable, Identifiable, Equatable, Sendable {
    public var id: String {trackId}
    public  let trackId: String
    public  let trackTitle: String
    public  let trackDuration: Int
    public  let trackSingers: String
    public  let trackFile: String
    public  let trackSize: Int
    public  let trackAudioCodec: String
    public  let trackAudioChannels: Int
    public  let trackThumbnail: String
    public  let trackFilepath: String
    public  let trackBitrate: Int
    public  let parentTitle: String
    public var trackOrder: Int
}

// MARK: - AlbumsResponseModel
public struct AlbumsResponseModel: Decodable, Sendable {
    public  let albums: [Album]
    public  let pagination: PaginationMeta
}

// MARK: - Album
public struct Album: Decodable, Identifiable, Hashable, Equatable, Sendable {
    public var id: String { albumRatingKey }
    public  let albumArtist: String
    public  let albumTitle: String
    public  let albumYear: Int
    public  let albumRatingKey: String
    public  let albumThumbnail: String
    public  let albumComposer: String
}

// MARK: - AlbumsPagination
//public  struct AlbumsPagination: Codable {
//    public  let currentPage: Int
//    public  let totalPages: Int
//    public  let totalRecords: Int
//    public  let limit: Int
//}

// MARK: - ArtistModel
public struct ArtistModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - ArtistsResponse
public struct ArtistsResponse: Decodable {
    public  let artists: [String]
    public  let pagination: Pagination
}

// MARK: - SingerModel
public struct SingerModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - SingersResponse
public struct SingersResponse: Decodable {
    public  let singers: [String]
    public  let pagination: Pagination
}

// MARK: - SingerModel
public struct MusicianModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - SingersResponse
public struct MusiciansResponse: Decodable {
    public  let composers: [String]
    public  let pagination: Pagination
}

// MARK: - Pagination
public struct Pagination: Codable, Sendable {
    public  let currentPage: Int
    public  let totalPages: Int
    public  let totalRecords: Int
    public  let limit: Int
}
