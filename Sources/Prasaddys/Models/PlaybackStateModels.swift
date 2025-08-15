import Foundation

// MARK: - PlaybackStateResponse
public struct PlaybackStateResponse: Codable {
    public let playbackState: PlaybackState
    public let pagination: PaginationModel
}

// MARK: - PlaybackState
public struct PlaybackState: Codable {
    public let playbackPosition: TimeInterval
    public let isShuffleEnabled: Bool
    public let shuffleContext: [String]?
    public let currentPlayingTrack: String?
    public let tracks: [Track]
}
