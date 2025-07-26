import Foundation
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public class AuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    
    private let baseURL: URL
    private let clientId: String
    private let email: String
    private let redirectUri: String
    private var verifier: String = ""
    private var state: String = ""
    private var session: ASWebAuthenticationSession?
    
    private let authPath = "/authorize"
    private let tokenPath = "/token"
    private let redirectScheme = "ramyam" // customize to your app's URL scheme
    
    init(baseURL: URL, clientId: String, email: String, redirectUri: String) {
        self.baseURL = baseURL
        self.clientId = clientId
        self.email = email
        self.redirectUri = redirectUri
    }

    // MARK: - Cross-platform presentation anchor
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }

    public func startAuthorization(email: String) async throws -> String {
        verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)

        guard let generatedState = PKCEHelper.generateState() else {
            throw AuthError.unknown
        }
        state = generatedState

        guard var components = URLComponents(string: "\(self.baseURL)\(authPath)") else {
            throw AuthError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: self.clientId),
            URLQueryItem(name: "redirect_uri", value: self.redirectUri),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "email", value: self.email)
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value,
                      let receivedState = queryItems.first(where: { $0.name == "state" })?.value,
                      receivedState == self?.state else {
                    continuation.resume(throwing: AuthError.stateMismatch)
                    return
                }

                continuation.resume(returning: code)
            }
            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = true
            session?.start()
        }
    }

    public func exchangeCodeForToken(authorizationCode: String) async throws -> TokenResponse {
        guard let tokenURL = URL(string: "\(self.baseURL)\(tokenPath)") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "client_id": self.clientId,
            "code_verifier": verifier,
            "redirect_uri": self.redirectUri,
            "state": state
        ]
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "No message"
            throw AuthError.tokenExchangeFailed(msg)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try saveTokens(tokenResponse)
        return tokenResponse
    }

    public func refreshAccessToken() async throws -> TokenResponse {
        guard let refreshTokenData = KeychainHelper.shared.read(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.refreshTokenAccount),
              let refreshToken = String(data: refreshTokenData, encoding: .utf8) else {
            throw AuthError.missingTokenData
        }

        guard let tokenURL = URL(string: "\(self.baseURL)\(tokenPath)") else {
            throw AuthError.invalidURL
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": self.clientId
        ]
        request.httpBody = bodyParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "No message"
            throw AuthError.tokenRefreshFailed(msg)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try saveTokens(tokenResponse)
        return tokenResponse
    }

    public func clearAllAuthTokens() {
        KeychainHelper.shared.delete(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.refreshTokenAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenExpiryAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount)
    }

    public func saveTokens(_ tokenResponse: TokenResponse) throws {
        guard let accessData = tokenResponse.accessToken.data(using: .utf8),
              let refreshData = tokenResponse.refreshToken.data(using: .utf8),
              let userIdData = tokenResponse.userId.data(using: .utf8) else {
            throw AuthError.missingTokenData
        }

        let savedAccess = KeychainHelper.shared.save(accessData, service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenAccount)
        let savedRefresh = KeychainHelper.shared.save(refreshData, service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.refreshTokenAccount)
        let savedUserId = KeychainHelper.shared.save(userIdData, service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount)

        if !savedAccess || !savedRefresh || !savedUserId {
            throw AuthError.missingTokenData
        }

        if let expiresIn = tokenResponse.expiresIn {
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            TokenExpiryHelper.saveExpiryDate(expiryDate)
        }
    }
}

public enum AuthError: Error {
    case stateMismatch
    case invalidURL
    case missingTokenData
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case unknown
}
