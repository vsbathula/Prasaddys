import Foundation

// MARK: - TrackResponseModel

public  struct TrackResponseModel: Codable, Sendable {
    public let tracks: [Track]
    public let tracksRatingKeyList: [String]
    public let pagination: PaginationModel
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
