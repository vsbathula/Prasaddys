import Foundation

class KeyChainUtil {
    
    static func getAccessToken() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.accessTokenAccount),
           let token = String(data: data, encoding: .utf8) {
            return "Bearer \(token)"
        }
        return nil
    }
    
    static func getRefreshToken() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.plexService, account: AppConstants.Keychain.refreshTokenAccount) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func getUserEmail() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.userEmailService, account: AppConstants.Keychain.userEmailAccount),
           let email = String(data: data, encoding: .utf8) {
            return email
        }
        return nil
    }
    
    static func getDeviceUuid() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.deviceService, account: AppConstants.Keychain.deviceAccount),
           let deviceUuid = String(data: data, encoding: .utf8) {
            return deviceUuid
        }
        return nil
    }
    
    static func getUserId() -> String? {
        if let data = KeychainHelper.shared.read(service: AppConstants.Keychain.userIdService, account: AppConstants.Keychain.userIdAccount),
           let userId = String(data: data, encoding: .utf8) {
            return userId
        }
        return nil
    }
    
    static func getOsModel() -> String? {
        if let savedModelData = KeychainHelper.shared.read(service: AppConstants.Keychain.userModelService, account: AppConstants.Keychain.userModelAccount),
           let savedModel = String(data: savedModelData, encoding: .utf8) {
            return savedModel
        }
        return nil
    }
    
    static func getOsVersion() -> String? {
        if let savedVersionData = KeychainHelper.shared.read(service: AppConstants.Keychain.userSystemVersionService, account: AppConstants.Keychain.userSystemVersionAccount),
           let savedVersion = String(data: savedVersionData, encoding: .utf8) {
            return savedVersion
        }
        return nil
    }
    
}
