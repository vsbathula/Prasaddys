import Foundation
import CryptoKit

struct PKCEHelper {
    static func generateCodeVerifier() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<64).map { _ in characters.randomElement()! })
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64URLEncodedString()
    }
    
    static func generateState(length: Int = 32) -> String? {
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else {
                return errSecParam // Indicate an error with the buffer
            }
            return SecRandomCopyBytes(kSecRandomDefault, length, pointer)
        }
        guard status == errSecSuccess else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
