import Foundation

// MARK: - MoviesResponseModel
public struct MoviesResponseModel: Decodable {
    public let movies: [Movie]
    public let pagination: Pagination
}

// MARK: - Movie
public struct Movie: Decodable, Identifiable, Hashable {
    public var id: String { movieRatingKey }
    public let movieRatingKey: String
    public let movieTitle: String
    public let movieYear: Int?
    public let movieThumbnail: String?
}

// MARK: - MoviesPagination
//struct MoviesPagination: Codable {
//    public let currentPage: Int
//    public let totalPages: Int
//    public let totalRecords: Int
//    public let limit: Int
//}

// MARK: - MovieDetailResponse
public struct MovieDetailResponse: Codable {
    public let movieRatingKey: String
    public let movieStudio: String?
    public let movieTitle: String
    public let movieOriginalTitle: String?
    public let movieContentRating: String?
    public let movieSummary: String?
    public let movieAudienceRating: Double?
    public let movieYear: Int?
    public let movieThumbnail: String?
    public let movieArt: String?
    public let movieDuration: Int
    public let movieOriginallyAvailableAt: String?
    public let media: [Media]
    public let genre: [Genre]?
    public let country: [Country]?
    public let director: [Director]?
    public let writer: [Writer]?
    public let producer: [Producer]?
    public let rating: [Rating]?
    public let actor: [Actor]?
    public let tracks: [Track]?
}

// MARK: - Media
public struct Media: Codable {
    public let mediaId: Int
    public let mediaDuration: Int
    public let mediaBitRate: Int
    public let mediaWidth: Int
    public let mediaHeight: Int
    public let mediaAspectRatio: Double
    public let mediaAudioChannels: Int
    public let mediaAudioCodec: String
    public let mediaVideoCodec: String
    public let mediaContainer: String
    public let mediaVideoResolution: String
    public let mediaVideoFrameRate: String
    public let mediaVideoProfile: String
    public let part: [Part]
}

// MARK: - Part
public struct Part: Codable {
    public let partId: Int
    public let partFile: String
    public let partKey: String
    public let partSize: Int
    public let partContainer: String
    public let stream: [Stream]
}

// MARK: - Stream
public struct Stream: Codable {
    public let streamId: Int
    public let streamType: Int?
    public let streamCodec: String
    public let streamDisplayTitle: String
    public let streamExtendedDisplayTitle: String
    public let streamAudioChannelLayout: String?
    public let streamChannels: Int?
    public let streamSamplingRate: Int?
}

// MARK: - Genre
public struct Genre: Codable {
    public let genreId: Int
    public let genre: String
}

// MARK: - Country
public struct Country: Codable {
    public let countryId: Int
    public let country: String
}

// MARK: - Director
public struct Director: Codable {
    public let directorId: Int
    public let directorName: String
    public let directorThumb: String?
}

// MARK: - Writer
public struct Writer: Codable {
    public let writerId: Int
    public let writerName: String
    public let writerThumb: String?
}

// MARK: - Producer
public struct Producer: Codable {
    public let producerId: Int
    public let producerName: String
    public let producerThumb: String?
}

// MARK: - Actor
public struct Actor: Codable {
    public let actorId: Int
    public let actorName: String
    public let actorRole: String
    public let actorThumb: String?
}

// MARK: - Rating
public struct Rating: Codable {
    public let ratingImage: String
    public let ratingValue: Int
    public let ratingType: String
}

