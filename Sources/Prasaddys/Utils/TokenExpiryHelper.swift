import Foundation

public struct TokenExpiryHelper {

    /// Saves a Date (token expiry) to Keychain
    public static func saveExpiryDate(_ date: Date) {
        if !KeychainHelper.shared.save(date: date,
                                        service: AppConstants.Keychain.accessTokenExpiryService,
                                        account: AppConstants.Keychain.accessTokenExpiryAccount) {
            print("❌ [TokenExpiryHelper] Failed to save expiry date to Keychain.")
        } else {
            print("✅ [TokenExpiryHelper] Token expiry date saved.")
        }
    }

    /// Reads expiry date from Keychain and checks if it's expired
    public static func isExpired() -> Bool {
        guard let expiryDate = KeychainHelper.shared.readDate(
            service: AppConstants.Keychain.accessTokenExpiryService,
            account: AppConstants.Keychain.accessTokenExpiryAccount
        ) else {
            print("⚠️ [TokenExpiryHelper] No expiry date found in Keychain. Assuming expired.")
            return true
        }

        let expired = Date() >= expiryDate
        if expired {
            print("⏱️ [TokenExpiryHelper] Access token is expired.")
        } else {
            print("✅ [TokenExpiryHelper] Access token is not expired.")
        }
        return expired
    }
}
