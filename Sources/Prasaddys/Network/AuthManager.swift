#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import Foundation
import AuthenticationServices
import CommonCrypto
import Alamofire

// MARK: - AuthManager Public Interface

/// A class to manage the OAuth 2.0 authentication process using the Authorization Code Flow with PKCE and the Device Authorization Grant for tvOS.
@MainActor
public class AuthManager: NSObject {
    // MARK: - Properties
    private let baseURL: URL
    private let clientId: String
#if !os(tvOS)
    private let redirectUri: String
#endif
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
#if os(tvOS)
    // Initializer for tvOS, which does not require a redirectUri
    public init(baseURL: URL, clientId: String) {
        self.baseURL = baseURL
        self.clientId = clientId
    }
#else
    public init(baseURL: URL, clientId: String, redirectUri: String) {
        self.baseURL = baseURL
        self.clientId = clientId
        self.redirectUri = redirectUri
    }
#endif
    
    // MARK: - Public API
    
    /// Starts the authorization process using the Authorization Code Flow with PKCE.
    /// This method is only available on iOS and macOS.
    /// - Parameter email: The user's email address to pre-fill the login form.
    /// - Returns: The authorization code received from the server.
    @MainActor
    public func startAuthorization(email: String, deviceId: String) async throws {
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
            URLQueryItem(name: "email", value: email),
            URLQueryItem(name: "device_id", value: deviceId)
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
            Task {
                await MainActor.run {
                    let started = self.session?.start()
                    print("Session start called via MainActor: \(started ?? false)")
                }
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
    public func startDeviceCodeFlow() async throws -> (deviceCode: String, userCode: String, verificationUri: String, interval: Int) {
        var request = URLRequest(url: baseURL.appendingPathComponent("/device_authorize"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "scope": "read"
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
    public func pollForDeviceCodeToken(deviceCode: String, interval: Int, deviceId: String) async throws {
        let pollInterval = UInt64(interval) * 1_000_000_000 // seconds to nanoseconds
        
        while true {
            try await Task.sleep(nanoseconds: pollInterval)
            
            let request = createTokenRequest(with: [
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                "device_code": deviceCode,   // <-- fixed here
                "client_id": clientId,
                "deviceid": deviceId
            ])
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                    try saveTokens(tokenResponse)
                    let success = await postDeviceDetails()
                    if success {
                        print("📱 Device details successfully posted")
                    } else {
                        print("🚫 Failed to post device details")
                    }
                    return
                } else {
                    let tokenErrorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data)
                    if let errorResp = tokenErrorResponse {
                        print("Polling error: \(errorResp.error) - \(errorResp.error_description ?? "")")
                        if errorResp.error == "authorization_pending" || errorResp.error == "slow_down" {
                            continue
                        } else {
                            throw AuthError.tokenRequestFailed(errorResp.error_description ?? "Unknown error during polling")
                        }
                    } else {
                        let raw = String(data: data, encoding: .utf8) ?? "Unknown error data"
                        print("Polling unexpected error data: \(raw)")
                        throw AuthError.tokenRequestFailed(raw)
                    }
                }
            } catch let urlError as URLError where urlError.code == .timedOut {
                print("Polling timeout, retrying...")
                continue // Retry on timeout
            } catch {
                throw error
            }
        }
    }
#endif
    
    public func postDeviceDetails() async -> Bool {
        guard
            let userId = KeyChainUtil.getUserId(), !userId.isEmpty,
            let deviceUuid = KeyChainUtil.getDeviceUuid(), !deviceUuid.isEmpty,
            let deviceModelStr = KeyChainUtil.getOsModel(), !deviceModelStr.isEmpty,
            let deviceVersionStr = KeyChainUtil.getOsVersion(), !deviceVersionStr.isEmpty
        else {
            print("❌ Missing required device or user data.")
            return false
        }
        
        let userDevicePostUrl = "/user/\(userId)/devices/device"
        let apiBaseURL = AppConfigUtil.getApiUrl()
        let usersBaseURL = apiBaseURL.replacingOccurrences(of: "/api/media", with: "/api/users")
        
        guard let url = URL(string: "\(usersBaseURL)\(userDevicePostUrl)") else {
            print("❌ Invalid device POST URL: \(usersBaseURL)\(userDevicePostUrl)")
            return false
        }
        
        let payload: [String: String] = [
            "deviceId": deviceUuid,
            "deviceType": deviceModelStr,
            "deviceOsVersion": deviceVersionStr
        ]
        
        var headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        if let accessToken = KeyChainUtil.getAccessToken(), !accessToken.isEmpty {
            headers.add(name: "Authorization", value: accessToken)
        } else {
            print("⚠️ Access token not found — request might fail.")
        }
        
        do {
            let response = try await AF.request(
                url,
                method: .post,
                parameters: payload,
                encoding: JSONEncoding.default,
                headers: headers
            )
                .validate(statusCode: 200..<300)
                .serializingString() // or .serializingDecodable(SomeModel.self) if expecting a model
                .value
            
            print("✅ Device POST response: \(response)")
            return true
            
        } catch {
            if let afError = error as? AFError {
                print("❌ Alamofire error: \(afError.localizedDescription)")
            } else {
                print("❌ Unexpected error: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Internal Helper Methods
#if !os(tvOS)
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
#endif
    
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
        
        guard let email = KeyChainUtil.getUserEmail(), !email.isEmpty else { return }
        
        guard let userid = KeyChainUtil.getUserId(), !userid.isEmpty else { return }
                
        guard let deviceUuid = KeyChainUtil.getDeviceUuid(), !deviceUuid.isEmpty else { return }
//        if let email = KeyChainUtil.getUserEmail(), !email.isEmpty {
//            bodyParams["email"] = email
//        } else {
//            print("⚠️ [AuthManager] Warning: User email not found in Keychain for refresh request. Proceeding without it.")
//        }
        
//        if let userid = KeyChainUtil.getUserId(), !userid.isEmpty {
//            bodyParams["userid"] = userid
//        } else {
//            print("⚠️ [AuthManager] Warning: User id not found in Keychain for refresh request. Proceeding without it.")
//        }
//        
//        if let deviceUuid = KeyChainUtil.getDeviceUuid(), !deviceUuid.isEmpty {
//            bodyParams["deviceid"] = deviceUuid
//        } else {
//            print("⚠️ [AuthManager] Warning: User device uuid not found in Keychain for refresh request. Proceeding without it.")
//        }
        
        let request = createTokenRequest(with: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "email": email,
            "userid": userid,
            "deviceid": deviceUuid
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
              let userIdData = tokenResponse.user_id.data(using: .utf8),
        let userEmailData = tokenResponse.user_email.data(using: .utf8) else {
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
        
        if !KeychainHelper.shared.save(userIdData, service: AppConstants.Keychain.userIdService, account: AppConstants.Keychain.userIdAccount) {
            print("❌ Failed to save user ID.")
            saveSuccess = false
        }
        
        if !KeychainHelper.shared.save(userEmailData, service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount) {
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
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // ✅ Ensure this method runs on the main thread
        precondition(Thread.isMainThread, "presentationAnchor(for:) must be called on the main thread")
        
#if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
#elseif os(macOS)
        return NSApplication.shared.windows.first ?? NSApp.mainWindow ?? ASPresentationAnchor()
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

