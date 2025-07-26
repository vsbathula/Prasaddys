import Foundation

// MARK: - MoviesResponseModel
struct MoviesResponseModel: Decodable {
    let movies: [Movie]
    let pagination: Pagination
}

// MARK: - Movie
struct Movie: Decodable, Identifiable, Hashable {
    var id: String { movieRatingKey }
    let movieRatingKey: String
    let movieTitle: String
    let movieYear: Int?
    let movieThumbnail: String?
}

// MARK: - MoviesPagination
//struct MoviesPagination: Codable {
//    let currentPage: Int
//    let totalPages: Int
//    let totalRecords: Int
//    let limit: Int
//}

// MARK: - MovieDetailResponse
struct MovieDetailResponse: Codable {
    let movieRatingKey: String
    let movieStudio: String?
    let movieTitle: String
    let movieOriginalTitle: String?
    let movieContentRating: String?
    let movieSummary: String?
    let movieAudienceRating: Double?
    let movieYear: Int?
    let movieThumbnail: String?
    let movieArt: String?
    let movieDuration: Int
    let movieOriginallyAvailableAt: String?
    let media: [Media]
    let genre: [Genre]?
    let country: [Country]?
    let director: [Director]?
    let writer: [Writer]?
    let producer: [Producer]?
    let rating: [Rating]?
    let actor: [Actor]?
    let tracks: [Track]?
}

// MARK: - Media
struct Media: Codable {
    let mediaId: Int
    let mediaDuration: Int
    let mediaBitRate: Int
    let mediaWidth: Int
    let mediaHeight: Int
    let mediaAspectRatio: Double
    let mediaAudioChannels: Int
    let mediaAudioCodec: String
    let mediaVideoCodec: String
    let mediaContainer: String
    let mediaVideoResolution: String
    let mediaVideoFrameRate: String
    let mediaVideoProfile: String
    let part: [Part]
}

// MARK: - Part
struct Part: Codable {
    let partId: Int
    let partFile: String
    let partKey: String
    let partSize: Int
    let partContainer: String
    let stream: [Stream]
}

// MARK: - Stream
struct Stream: Codable {
    let streamId: Int
    let streamType: Int?
    let streamCodec: String
    let streamDisplayTitle: String
    let streamExtendedDisplayTitle: String
    let streamAudioChannelLayout: String?
    let streamChannels: Int?
    let streamSamplingRate: Int?
}

// MARK: - Genre
struct Genre: Codable {
    let genreId: Int
    let genre: String
}

// MARK: - Country
struct Country: Codable {
    let countryId: Int
    let country: String
}

// MARK: - Director
struct Director: Codable {
    let directorId: Int
    let directorName: String
    let directorThumb: String?
}

// MARK: - Writer
struct Writer: Codable {
    let writerId: Int
    let writerName: String
    let writerThumb: String?
}

// MARK: - Producer
struct Producer: Codable {
    let producerId: Int
    let producerName: String
    let producerThumb: String?
}

// MARK: - Actor
struct Actor: Codable {
    let actorId: Int
    let actorName: String
    let actorRole: String
    let actorThumb: String?
}

// MARK: - Rating
struct Rating: Codable {
    let ratingImage: String
    let ratingValue: Int
    let ratingType: String
}

