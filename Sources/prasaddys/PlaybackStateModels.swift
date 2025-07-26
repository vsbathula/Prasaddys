import Foundation

// MARK: - PlaybackStateResponse
struct PlaybackStateResponse: Codable {
    let playbackState: PlaybackState
    let pagination: Pagination
}

// MARK: - PlaybackState
struct PlaybackState: Codable {
    let playbackPosition: TimeInterval
    let isShuffleEnabled: Bool
    let shuffleContext: [String]?
    let currentPlayingTrack: String?
    let tracks: [Track]
}
