import Foundation

public struct TokenResponse: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let userId: String
    public let expiresIn: Int?
}
