import Foundation
import Security

public class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()

    private init() {}

    // MARK: - Save Data
    @discardableResult
    public func save(_ data: Data, service: String, account: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        SecItemDelete(query)

        let attributes = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly // Recommended accessibility
        ] as CFDictionary

        let status = SecItemAdd(attributes, nil)
        if status != errSecSuccess {
            print("🔐 Keychain save failed for \(account) (Status: \(status))")
            return false
        }
        return true
    }

    // MARK: - Read Data
    public func read(service: String, account: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)

        if status == errSecSuccess {
            return result as? Data
        } else if status == errSecItemNotFound {
            return nil
        } else {
            print("🔐 Keychain read failed for \(account) (Status: \(status))")
            return nil
        }
    }

    // MARK: - Delete
    @discardableResult
    public func delete(service: String, account: String) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary

        let status = SecItemDelete(query)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("🔐 Keychain delete failed for \(account) (Status: \(status))")
            return false
        }
        return true
    }

    // MARK: - Date Helpers
    @discardableResult
    public func save(date: Date, service: String, account: String) -> Bool {
        // Use requiringSecureCoding: true for enhanced security
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: date, requiringSecureCoding: true) {
            return save(data, service: service, account: account)
        } else {
            print("❌ Failed to archive Date for keychain for account: \(account)")
            return false
        }
    }

    public func readDate(service: String, account: String) -> Date? {
        guard let data = read(service: service, account: account) else {
            return nil
        }

        do {
            // Specify the class NSDate.self, then cast to Swift's Date
            if let date = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSDate.self, from: data) as Date? {
                return date
            } else {
                print("❌ Keychain: Unarchived data was not a Date object for account: \(account)")
                return nil
            }
        } catch {
            print("❌ Keychain: Failed to unarchive Date from Keychain for account: \(account): \(error.localizedDescription)")
            return nil
        }
    }
}
