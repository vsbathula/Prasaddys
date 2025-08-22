import Foundation

// MARK: - SingerModel
public struct SingerModel: Encodable, Decodable, Identifiable, Sendable {
    public  let id: String
    public  let name: String
}

// MARK: - SingersResponse
public struct SingersResponse: Decodable, Encodable, Sendable {
    public  let singers: [SingerModel]
    public  let pagination: PaginationModel
}
