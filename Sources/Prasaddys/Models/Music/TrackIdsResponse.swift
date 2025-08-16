struct TrackIdItem: Codable, Identifiable {
    let id: Int
    let trackRatingKey: String
}

struct TrackIdsResponse: Codable {
    let trackIds: [TrackIdItem]
}
