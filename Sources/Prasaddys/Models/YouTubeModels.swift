import Foundation

// MARK: - YouTubeSearchResultsModel
public struct YouTubeSearchResultsModel: Codable, Sendable {
    public let kind: String
    public let etag: String
    public let nextPageToken: String?
    public let prevPageToken: String?
    public let pageInfo: PageInfo
    public let items: [YouTubeSearchResult]
}

// MARK: - PageInfo
public struct PageInfo: Codable, Sendable {
    public let totalResults: Int
    public let resultsPerPage: Int
}

// MARK: - YouTubeSearchResult
public struct YouTubeSearchResult: Codable, Identifiable, Sendable, Equatable {
    public let videoInfo: VideoID // Renamed from `id`
    public let snippet: Snippet
    
    public var id: String { videoInfo.videoId } // Now `id` conforms to Identifiable
    
    private enum CodingKeys: String, CodingKey {
        case videoInfo = "id"
        case snippet
    }
}

// MARK: - VideoID
public struct VideoID: Codable, Sendable, Equatable {
    public let kind: String
    public let videoId: String
}

// MARK: - Snippet
public struct Snippet: Codable, Sendable, Equatable {
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
public struct Thumbnails: Codable, Sendable, Equatable {
    public let `default`: ThumbnailDetail?
    public let medium: ThumbnailDetail?
    public let high: ThumbnailDetail?
}

// MARK: - ThumbnailDetail
public struct ThumbnailDetail: Codable, Sendable, Equatable {
    public let url: String
    public let width: Int?
    public let height: Int?
}
