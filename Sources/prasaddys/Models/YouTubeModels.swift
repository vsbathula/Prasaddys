import Foundation

// MARK: - YouTubeSearchResultsModel
struct YouTubeSearchResultsModel: Codable {
    let items: [YouTubeSearchResult]
}

// MARK: - YouTubeSearchResult
struct YouTubeSearchResult: Codable, Identifiable {
    let videoInfo: VideoID // Renamed from `id`
    let snippet: Snippet

    var id: String { videoInfo.videoId } // Now `id` conforms to Identifiable

    private enum CodingKeys: String, CodingKey {
        case videoInfo = "id"
        case snippet
    }
}

// MARK: - VideoID
struct VideoID: Codable {
    let kind: String
    let videoId: String
}

// MARK: - Snippet
struct Snippet: Codable {
    let publishedAt: String?
    let channelId: String?
    let title: String
    let description: String
    let thumbnails: Thumbnails
    let channelTitle: String?
    let liveBroadcastContent: String?
    let publishTime: String?
}

// MARK: - Thumbnails
struct Thumbnails: Codable {
    let `default`: ThumbnailDetail?
    let medium: ThumbnailDetail?
    let high: ThumbnailDetail?
}

// MARK: - ThumbnailDetail
struct ThumbnailDetail: Codable {
    let url: String
    let width: Int?
    let height: Int?
}
