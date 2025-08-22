import Foundation

// MARK: - MusicianModel
public struct MusicianModel: Encodable, Decodable, Identifiable, Sendable {
    public  let id: String
    public  let name: String
}

// MARK: - MusiciansResponse
public struct MusiciansResponse: Decodable, Encodable, Sendable {
    public  let musicians: [MusicianModel]
    public  let pagination: PaginationModel
}
