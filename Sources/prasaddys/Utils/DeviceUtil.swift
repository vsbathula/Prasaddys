import SwiftUI

public class DeviceUtil {

    public static func getOrCreateUUID() -> String {
        if let existingUUID = KeyChainUtil.getDeviceUuid(), !existingUUID.isEmpty {
            return existingUUID
        }

        let newUUID = UUID().uuidString
        if let uuidData = newUUID.data(using: .utf8) {
            let success = KeychainHelper.shared.save(
                uuidData,
                service: AppConstants.Keychain.deviceService,
                account: AppConstants.Keychain.deviceAccount
            )
            if success {
                return newUUID
            } else {
                print("❌ Failed to save new UUID to Keychain")
            }
        }
        return newUUID
    }

    @MainActor public static func getDeviceModel() -> String {
        if let existingModel = KeyChainUtil.getOsModel(), !existingModel.isEmpty {
            return existingModel
        }

        let currentModel: String

        #if os(iOS) || os(tvOS)
        currentModel = UIDevice.current.model
        #elseif os(macOS)
        currentModel = Host.current().localizedName ?? "Mac"
        #else
        currentModel = "Unknown"
        #endif

        if let modelData = currentModel.data(using: .utf8) {
            let success = KeychainHelper.shared.save(
                modelData,
                service: AppConstants.Keychain.userModelService,
                account: AppConstants.Keychain.userModelAccount
            )
            if !success {
                print("❌ Failed to save device model '\(currentModel)' to Keychain.")
            }
        } else {
            print("⚠️ Could not convert device model '\(currentModel)' to Data.")
        }

        return currentModel
    }

    @MainActor public static func getSystemVersion() -> String {
        if let existingVersion = KeyChainUtil.getOsVersion(), !existingVersion.isEmpty {
            return existingVersion
        }

        let currentVersion: String

        #if os(iOS) || os(tvOS)
        currentVersion = UIDevice.current.systemVersion
        #elseif os(macOS)
        currentVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #else
        currentVersion = "Unknown"
        #endif

        if let versionData = currentVersion.data(using: .utf8) {
            let success = KeychainHelper.shared.save(
                versionData,
                service: AppConstants.Keychain.userSystemVersionService,
                account: AppConstants.Keychain.userSystemVersionAccount
            )
            if !success {
                print("❌ Failed to save system version '\(currentVersion)' to Keychain.")
            }
        } else {
            print("⚠️ Could not convert system version '\(currentVersion)' to Data.")
        }

        return currentVersion
    }
}
