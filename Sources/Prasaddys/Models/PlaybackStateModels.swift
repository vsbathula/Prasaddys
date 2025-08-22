import Foundation

// MARK: - PlaybackStateResponse
public struct PlaybackStateResponse: Codable, Sendable {
    public let playbackState: PlaybackState
}

// MARK: - PlaybackState
public struct PlaybackState: Codable, Sendable {
    public let playbackPosition: Double
    public let isShuffleEnabled: Bool
    public let shuffledTrackContext: [String]?
    public let originalTrackContext: [String]?
    public let currentPlayingTrack: String?
}


public struct PlaybackStatePayload: Encodable, Sendable {
    public let userId: String
    public let currentPlayingTrack: String
    public let playbackPosition: Double
    public let isShuffleEnabled: Bool?
    public let shuffledTrackContext: [String]?
    public let originalTrackContext: [String]?
}
