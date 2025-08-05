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
    private let deviceCodePath = "/device/code"
    private let redirectScheme = "ramyam-m"
    
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
        return try await startDeviceCodeFlow()
#else
        return try await startPKCEFlow(email: email)
#endif
    }
    
    // MARK: - PKCE Flow (iOS + macOS)
    @MainActor
    private func startPKCEFlow(email: String) async throws -> String {
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
#if os(iOS) || os(macOS)
            session?.prefersEphemeralWebBrowserSession = true
            session?.presentationContextProvider = self
#endif
            session?.start()
            
            self.session?.start()
        }
        
        try await self.exchangeCodeForToken(authorizationCode: code)
        return code
    }
    
    // MARK: - Device Code Flow (tvOS)
    @MainActor
    private func startDeviceCodeFlow() async throws -> String {
        struct DeviceCodeResponse: Codable {
            let device_code: String
            let user_code: String
            let verification_uri: String
            let expires_in: Int
            let interval: Int
        }
        
        // Step 1: Request device code
        var request = URLRequest(url: baseURL.appendingPathComponent(deviceCodePath))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "client_id=\(clientId)&scope=read".data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let deviceCodeData = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        
        print("📺 Go to \(deviceCodeData.verification_uri) and enter code: \(deviceCodeData.user_code)")
        
        // Step 2: Poll token endpoint
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < Double(deviceCodeData.expires_in) {
            try await Task.sleep(nanoseconds: UInt64(deviceCodeData.interval) * 1_000_000_000)
            
            var pollRequest = URLRequest(url: baseURL.appendingPathComponent(tokenPath))
            pollRequest.httpMethod = "POST"
            pollRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            pollRequest.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=\(deviceCodeData.device_code)&client_id=\(clientId)".data(using: .utf8)
            
            let (pollData, _) = try await URLSession.shared.data(for: pollRequest)
            
            if let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: pollData) {
                try saveTokens(tokenResponse)
                return "device_code_authenticated"
            }
        }
        throw AuthError.tokenExchangeFailed("Device code expired")
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
    
    public func saveTokens(_ tokenResponse: TokenResponse) throws {
        guard let accessData = tokenResponse.access_token.data(using: .utf8),
              let refreshData = tokenResponse.refresh_token.data(using: .utf8) else {
            throw AuthError.missingTokenData
        }
        _ = KeychainHelper.shared.save(accessData, service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount)
        _ = KeychainHelper.shared.save(refreshData, service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount)
    }
}

#if !os(tvOS)
extension AuthManager: ASWebAuthenticationPresentationContextProviding {}
#endif

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
