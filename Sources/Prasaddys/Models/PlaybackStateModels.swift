import Foundation

// MARK: - PlaybackStateResponse
struct PlaybackStateResponse: Codable {
    let playbackState: PlaybackState
}

// MARK: - PlaybackState
struct PlaybackState: Codable {
    let playbackPosition: Double
    let isShuffleEnabled: Bool
    let shuffledTrackContext: [String]?
    let originalTrackContext: [String]?
    let currentPlayingTrack: String?
}




