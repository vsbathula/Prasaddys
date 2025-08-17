public struct TrackId: Codable, Identifiable, Sendable {
    public let id: Int
    public let trackRatingKey: String
}

public struct TrackIdsResponse: Codable, Sendable {
    public let trackIds: [TrackId]
}
