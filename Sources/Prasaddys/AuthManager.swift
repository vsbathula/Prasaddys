#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

import Foundation
import AuthenticationServices
import CommonCrypto

// MARK: - AuthManager Public Interface

/// A class to manage the OAuth 2.0 authentication process using the Authorization Code Flow with PKCE and the Device Authorization Grant for tvOS.
@MainActor
public class AuthManager: NSObject {
    // MARK: - Properties
    private let baseURL: URL
    private let clientId: String
    private let redirectUri: String
    private let authPath = "/authorize"
    private let tokenPath = "/token"
    private let redirectScheme = "ramyam-m" // Must match the URL Scheme configured in Xcode
    
    private var verifier: String = ""
    private var state: String = ""
    private var session: ASWebAuthenticationSession?
    
    // MARK: - Initialization
    /// Initializes the authentication manager with the required configuration.
    /// - Parameters:
    ///   - baseURL: The base URL of the OAuth 2.0 authorization server.
    ///   - clientId: The client ID for your application.
    ///   - redirectUri: The redirect URI for the authorization code flow (iOS/macOS).
    public init(baseURL: URL, clientId: String, redirectUri: String) {
        self.baseURL = baseURL
        self.clientId = clientId
        self.redirectUri = redirectUri
    }
    
    // MARK: - Public API
    
    /// Starts the authorization process using the Authorization Code Flow with PKCE.
    /// This method is only available on iOS and macOS.
    /// - Parameter email: The user's email address to pre-fill the login form.
    /// - Returns: The authorization code received from the server.
    @MainActor
    public func startAuthorization(email: String) async throws {
#if os(tvOS)
        throw AuthError.unsupportedPlatform
#else
        self.verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: self.verifier)
        
        guard let generatedState = PKCEHelper.generateState() else {
            throw AuthError.stateGenerationFailed
        }
        
        self.state = generatedState
        
        var components = URLComponents(url: baseURL.appendingPathComponent(authPath), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "state", value: self.state),
            URLQueryItem(name: "email", value: email)
        ]
        
        guard let url = components.url else {
            throw AuthError.invalidURL
        }
        
        let code: String = try await withCheckedThrowingContinuation { continuation in
            self.session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: redirectScheme
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                if let error = error {
                    // Check for user cancellation
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
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
            
            self.session?.prefersEphemeralWebBrowserSession = true
            self.session?.presentationContextProvider = self
            
//            DispatchQueue.main.async {
//                print("Starting ASWebAuthenticationSession with URL: \(url)")
//                let started = self.session?.start()
//                print("Session started: \(started ?? false)")
//            }
            await MainActor.run {
                let started = self.session?.start()
                print("Session start called via MainActor: \(started ?? false)")
            }
        }
        
        // This line attempts to exchange the code for a token,
        // but the prompt asked to make the AuthManager work. This part is already correct.
         try await self.exchangeCodeForToken(authorizationCode: code)
//        return code
#endif
    }
    
    // MARK: - tvOS Device Flow
    
    /// Starts the Device Authorization Grant flow for tvOS.
    /// This method is only available on tvOS.
#if os(tvOS)
    public func startDeviceCodeFlow(email: String) async throws -> (deviceCode: String, userCode: String, verificationUri: String, interval: Int) {
        var request = URLRequest(url: baseURL.appendingPathComponent("/device_authorize"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "scope": "read",
            "email": email
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response: response, data: data, errorMessage: "Device code request failed")
        
        let deviceCodeResponse = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        
        return (
            deviceCode: deviceCodeResponse.device_code,
            userCode: deviceCodeResponse.user_code,
            verificationUri: deviceCodeResponse.verification_uri,
            interval: deviceCodeResponse.interval
        )
    }
    
    /// Polls the token endpoint until the user authorizes the device.
    /// This method is only available on tvOS.
    public func pollForDeviceCodeToken(deviceCode: String, interval: Int) async throws {
        let pollInterval = UInt64(interval) * 1_000_000_000 // seconds to nanoseconds
        
        while true {
            try await Task.sleep(nanoseconds: pollInterval)
            
            let request = createTokenRequest(with: [
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "device_code": deviceCode,
                "client_id": clientId
            ])
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                    try saveTokens(tokenResponse)
                    return
                } else {
                    let tokenErrorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data)
                    if tokenErrorResponse?.error == "authorization_pending" || tokenErrorResponse?.error == "slow_down" {
                        continue
                    } else if let tokenErrorResponse = tokenErrorResponse {
                        throw AuthError.tokenRequestFailed(tokenErrorResponse.error_description ?? "Unknown error during polling")
                    } else {
                        throw AuthError.tokenRequestFailed(String(data: data, encoding: .utf8) ?? "Unknown error during polling")
                    }
                }
            } catch let urlError as URLError where urlError.code == .timedOut {
                continue // Retry on timeout
            } catch {
                throw error
            }
        }
    }
#endif
    
    // MARK: - Internal Helper Methods
    @MainActor
    private func exchangeCodeForToken(authorizationCode: String) async throws {
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
    
    
//    // MARK: - Presentation Anchor (iOS & macOS)
//    
//#if !os(tvOS)
//    @MainActor
//    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
//#if os(iOS)
//        return UIApplication.shared.connectedScenes
//            .compactMap { $0 as? UIWindowScene }
//            .flatMap { $0.windows }
//            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
//#elseif os(macOS)
//        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
//#else
//        return ASPresentationAnchor()
//#endif
//    }
//#endif
    
    
    
    
    // MARK: - Token Management & Retrieval
    
    /// Retrieves the current access token from the keychain.
    /// - Returns: The access token string, or nil if not found.
    public func getCurrentAccessToken() -> String? {
        guard let data = KeychainHelper.shared.read(service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Retrieves the current user ID from the keychain.
    /// - Returns: The user ID string, or nil if not found.
    public func getUserId() -> String? {
        guard let data = KeychainHelper.shared.read(service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Clears all authentication tokens from the keychain.
    @MainActor
    public func logout() {
        clearAllAuthTokens()
    }
    
    @MainActor
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
    
    private func clearAllAuthTokens() {
        KeychainHelper.shared.delete(service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.accessTokenExpiryService, account: AppConstants.Keychain.accessTokenExpiryAccount)
        KeychainHelper.shared.delete(service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount)
    }
    
    private func saveTokens(_ tokenResponse: TokenResponse) throws {
        guard let accessData = tokenResponse.access_token.data(using: .utf8),
              let refreshData = tokenResponse.refresh_token.data(using: .utf8),
              let userIdData = tokenResponse.user_id.data(using: .utf8) else {
            throw AuthError.missingTokenData
        }
        print("[Access Token] \(String(describing: tokenResponse.access_token.data(using: .utf8)))")
        print("[Refersh Token] \(String(describing: tokenResponse.refresh_token.data(using: .utf8)))")
        
        var saveSuccess = true

        if !KeychainHelper.shared.save(accessData, service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount) {
            print("❌ Failed to save access token.")
            saveSuccess = false
        }

        if !KeychainHelper.shared.save(refreshData, service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount) {
            print("❌ Failed to save refresh token.")
            saveSuccess = false
        }

        if !KeychainHelper.shared.save(userIdData, service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount) {
            print("❌ Failed to save user ID.")
            saveSuccess = false
        }

        if saveSuccess {
            print("✅ [AuthManager] All tokens and user ID saved successfully.")
        } else {
            throw AuthError.tokenPersistenceFailed
        }
//        guard KeychainHelper.shared.save(accessData, service: AppConstants.Keychain.accessTokenService, account: AppConstants.Keychain.accessTokenAccount) &&
//                KeychainHelper.shared.save(refreshData, service: AppConstants.Keychain.refreshTokenService, account: AppConstants.Keychain.refreshTokenAccount) &&
//                KeychainHelper.shared.save(userIdData, service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount) else {
//            throw AuthError.tokenPersistenceFailed
//        }
        
        if let expiresIn = tokenResponse.expires_in {
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            TokenExpiryHelper.saveExpiryDate(expiryDate)
        }
    }
    
    private func createTokenRequest(with parameters: [String: String]) -> URLRequest {
        let url = baseURL.appendingPathComponent(tokenPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        print("[createTokenRequest] \(request)")
        return request
    }
    
    private func validateResponse(response: URLResponse, data: Data, errorMessage: String) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? errorMessage
            throw AuthError.tokenRequestFailed(message)
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
#if !os(tvOS)
extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    @MainActor
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #elseif os(macOS)
        print("Available windows: \(NSApplication.shared.windows)")
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif

// MARK: - Supporting Types

/// Represents the structure of an error response from the token endpoint.
public struct TokenErrorResponse: Codable {
    public let error: String
    public let error_description: String?
}

/// Represents the structure of a successful device code response.
#if os(tvOS)
public struct DeviceCodeResponse: Codable {
    public let device_code: String
    public let user_code: String
    public let verification_uri: String
    public let expires_in: Int
    public let interval: Int
}
#endif

/// Defines the custom errors for the authentication process.
public enum AuthError: Error, LocalizedError {
    case stateMismatch
    case invalidURL
    case missingTokenData
    case tokenRequestFailed(String)
    case tokenPersistenceFailed
    case stateGenerationFailed
    case unsupportedPlatform
    case userCancelled
    
    public var errorDescription: String? {
        switch self {
        case .stateMismatch: return "The returned state does not match the original state."
        case .invalidURL: return "The URL for the request is invalid."
        case .missingTokenData: return "Required token data is missing."
        case .tokenRequestFailed(let message): return "Token request failed: \(message)"
        case .tokenPersistenceFailed: return "Failed to save token data to the keychain."
        case .stateGenerationFailed: return "Failed to generate a state parameter."
        case .unsupportedPlatform: return "This authentication flow is not supported on the current platform."
        case .userCancelled: return "The user cancelled the authentication process."
        }
    }
}

