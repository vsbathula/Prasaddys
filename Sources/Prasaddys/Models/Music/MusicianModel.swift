import Foundation

// MARK: - MusicianModel
public struct MusicianModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - MusiciansResponse
public struct MusiciansResponse: Decodable, Encodable, Identifiable {
    public var id = UUID()
    public  let musicians: [String]
    public  let pagination: PaginationModel
}
