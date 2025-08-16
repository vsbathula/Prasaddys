import Foundation

// MARK: - MusicianModel
public struct MusicianModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - MusiciansResponse
public struct MusiciansResponse: Decodable {
    public  let musicians: [String]
    public  let pagination: PaginationModel
}
