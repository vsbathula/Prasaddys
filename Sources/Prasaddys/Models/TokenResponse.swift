import Foundation

public struct TokenResponse: Codable, Sendable {
    public let access_token: String
    public let refresh_token: String
    public let token_type: String
    public let user_id: String
    public let expires_in: Int?
}
