import Foundation

public class KeyChainUtil {
    
    public static func getAccessToken() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenAccount),
           let token = String(data: data, encoding: .utf8) {
            return "Bearer \(token)"
        }
        return nil
    }
    
    public static func getRefreshToken() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.refreshTokenAccount) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    public static func getUserEmail() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount),
           let email = String(data: data, encoding: .utf8) {
            return email
        }
        return nil
    }
    
    public static func getDeviceUuid() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.deviceService, account: AppConstants.Keychain.deviceAccount),
           let deviceUuid = String(data: data, encoding: .utf8) {
            return deviceUuid
        }
        return nil
    }
    
    public static func getUserId() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.userIdService, account: AppConstants.Keychain.userIdAccount),
           let userId = String(data: data, encoding: .utf8) {
            return userId
        }
        return nil
    }
    
    public static func getOsModel() -> String? {
        if let savedModelData = KeychainHelper.shared.read(service: AppConstants.Keychain.userModelService, account: AppConstants.Keychain.userModelAccount),
           let savedModel = String(data: savedModelData, encoding: .utf8) {
            return savedModel
        }
        return nil
    }
    
    public static func getOsVersion() -> String? {
        if let savedVersionData = KeychainHelper.shared.read(service: AppConstants.Keychain.userSystemVersionService, account: AppConstants.Keychain.userSystemVersionAccount),
           let savedVersion = String(data: savedVersionData, encoding: .utf8) {
            return savedVersion
        }
        return nil
    }
    
}
