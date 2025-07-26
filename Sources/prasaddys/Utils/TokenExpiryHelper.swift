import Foundation

public struct TokenExpiryHelper {

    /// Saves a Date (token expiry) to Keychain
    static func saveExpiryDate(_ date: Date) {
        if let expiryData = try? NSKeyedArchiver.archivedData(withRootObject: date, requiringSecureCoding: false) {
            // Check the return value of KeychainHelper.shared.save
            if !KeychainHelper.shared.save(expiryData, service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenExpiryAccount) {
                print("❌ [TokenExpiryHelper] Failed to save expiry date to Keychain.")
            } else {
                print("✅ [TokenExpiryHelper] Token expiry date saved.")
            }
        } else {
            print("❌ [TokenExpiryHelper] Failed to archive expiry date.")
        }
    }

    /// Reads expiry date from Keychain and checks if it's expired
    public static func isExpired() -> Bool {
        guard let expiryData = KeychainHelper.shared.read(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenExpiryAccount),
              let expiryNSDate = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: expiryData) else {
            print("⚠️ [TokenExpiryHelper] No expiry date found in Keychain or failed to unarchive. Assuming expired.")
            return true // Safely assume expired if data isn't available or readable
        }
        let expiryDate = expiryNSDate as Date
        let expired = Date() >= expiryDate
        if expired {
            print("⏱️ [TokenExpiryHelper] Access token is expired.")
        } else {
            print("✅ [TokenExpiryHelper] Access token is not expired.")
        }
        return expired
    }
}
