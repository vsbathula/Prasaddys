public struct TrackIdItem: Codable, Identifiable {
    public let id: Int
    public let trackRatingKey: String
}

public struct TrackIdsResponse: Codable {
    public let trackIds: [TrackIdItem]
}
