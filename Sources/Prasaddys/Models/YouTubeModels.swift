import Foundation

// MARK: - YouTubeSearchResultsModel
public struct YouTubeSearchResultsModel: Codable {
    public let items: [YouTubeSearchResult]
}

// MARK: - YouTubeSearchResult
public struct YouTubeSearchResult: Codable, Identifiable {
    public let videoInfo: VideoID // Renamed from `id`
    public let snippet: Snippet

    public var id: String { videoInfo.videoId } // Now `id` conforms to Identifiable

    private enum CodingKeys: String, CodingKey {
        case videoInfo = "id"
        case snippet
    }
}

// MARK: - VideoID
public struct VideoID: Codable {
    public let kind: String
    public let videoId: String
}

// MARK: - Snippet
public struct Snippet: Codable {
    public let publishedAt: String?
    public let channelId: String?
    public let title: String
    public let description: String
    public let thumbnails: Thumbnails
    public let channelTitle: String?
    public let liveBroadcastContent: String?
    public let publishTime: String?
}

// MARK: - Thumbnails
public struct Thumbnails: Codable {
    public let `default`: ThumbnailDetail?
    public let medium: ThumbnailDetail?
    public let high: ThumbnailDetail?
}

// MARK: - ThumbnailDetail
public struct ThumbnailDetail: Codable {
    public let url: String
    public let width: Int?
    public let height: Int?
}
