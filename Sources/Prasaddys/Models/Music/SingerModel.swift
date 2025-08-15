import Foundation

// MARK: - SingerModel
public struct SingerModel: Decodable, Identifiable {
    public  let id: String
    public  let name: String
}

// MARK: - SingersResponse
public struct SingersResponse: Decodable {
    public  let singers: [String]
    public  let pagination: PaginationModel
}
