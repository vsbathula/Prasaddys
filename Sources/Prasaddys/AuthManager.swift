#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

import Foundation
import AuthenticationServices

public class AuthManager: NSObject {
    private let baseURL: URL
    private let clientId: String
    private let redirectUri: String
    
    private var verifier: String = ""
    private var state: String = ""
    private var session: ASWebAuthenticationSession?
    
    private let authPath = "/authorize"
    private let tokenPath = "/token"
    private let redirectScheme = "ramyam"
    
    public init(baseURL: URL, clientId: String, redirectUri: String) {
        self.baseURL = baseURL
        self.clientId = clientId
        self.redirectUri = redirectUri
    }
    
#if !os(tvOS)
    @MainActor
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
#elseif os(macOS)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
#else
        return ASPresentationAnchor()
#endif
    }
#endif
    
    @MainActor
    public func startAuthorization(email: String) async throws -> String {
#if os(tvOS)
        throw AuthError.unsupportedPlatform
#else
        verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)
        
        guard let generatedState = PKCEHelper.generateState() else {
            throw AuthError.stateGenerationFailed
        }
        
        state = generatedState
        
        var components = URLComponents(url: baseURL.appendingPathComponent(authPath), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "email", value: email)
        ]
        
        guard let url = components.url else {
            throw AuthError.invalidURL
        }
        
        let code: String = try await withCheckedThrowingContinuation { continuation in
            session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: redirectScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = queryItems.first(where: { $0.name == "code" })?.value,
                      let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
                      returnedState == self.state else {
                    continuation.resume(throwing: AuthError.stateMismatch)
                    return
                }
                
                continuation.resume(returning: code)
            }
            
            session?.prefersEphemeralWebBrowserSession = true
            
#if os(iOS)
            session?.presentationContextProvider = self
#endif
            
            self.session?.start()
        }
        
        try await self.exchangeCodeForToken(authorizationCode: code)
        return code
#endif
    }
    
    
    
    // MARK: - Token Exchange
    @MainActor
    public func exchangeCodeForToken(authorizationCode: String) async throws {
        let request = createTokenRequest(with: [
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "client_id": clientId,
            "code_verifier": verifier,
            "redirect_uri": redirectUri,
            "state": state
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try validateResponse(response: response, data: data, errorMessage: "Token exchange failed")
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try saveTokens(tokenResponse)
    }
    
    // MARK: - Token Refresh
    public func refreshAccessToken() async throws {
        guard let refreshTokenData = KeychainHelper.shared.read(service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount),
              let refreshToken = String(data: refreshTokenData, encoding: .utf8) else {
            throw AuthError.missingTokenData
        }
        
        let request = createTokenRequest(with: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try validateResponse(response: response, data: data, errorMessage: "Token refresh failed")
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        try saveTokens(tokenResponse)
    }
    
    // MARK: - Token Management
    public func clearAllAuthTokens() {
        KeychainHelper.shared.delete(service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.accessTokenExpiryService, account: AppConstants.Keychain.accessTokenExpiryAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount)
    }
    
    public func saveTokens(_ tokenResponse: TokenResponse) throws {
        guard let accessData = tokenResponse.accessToken.data(using: .utf8),
              let refreshData = tokenResponse.refreshToken.data(using: .utf8),
              let userIdData = tokenResponse.userId.data(using: .utf8) else {
            throw AuthError.missingTokenData
        }
        
        let savedAccess = KeychainHelper.shared.save(accessData, service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount)
        let savedRefresh = KeychainHelper.shared.save(refreshData, service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount)
        let savedUserId = KeychainHelper.shared.save(userIdData, service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount)
        
        if !savedAccess || !savedRefresh || !savedUserId {
            throw AuthError.missingTokenData
        }
        
        if let expiresIn = tokenResponse.expiresIn {
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            TokenExpiryHelper.saveExpiryDate(expiryDate)
        }
    }
    
    // MARK: - Helpers
    private func createTokenRequest(with parameters: [String: String]) -> URLRequest {
        let url = baseURL.appendingPathComponent(tokenPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        return request
    }
    
    private func validateResponse(response: URLResponse, data: Data, errorMessage: String) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? errorMessage
            throw AuthError.tokenExchangeFailed(message)
        }
    }
}

#if !os(tvOS)
extension AuthManager: ASWebAuthenticationPresentationContextProviding {}
#endif

// MARK: - AuthError Enum
public enum AuthError: Error {
    case stateMismatch
    case invalidURL
    case missingTokenData
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case stateGenerationFailed
    case unsupportedPlatform
    case userCancelled
}

