public struct TrackIdItem: Codable, Identifiable, Sendable {
    public let id: Int
    public let trackRatingKey: String
}

public struct TrackIdsResponse: Codable, Sendable {
    public let trackIds: [TrackIdItem]
}
