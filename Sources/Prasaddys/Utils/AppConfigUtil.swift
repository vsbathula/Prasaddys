import Foundation

public class AppConfigUtil {
    
    // MARK: - Critical Configurations (Uses fatalError if missing)
    
    public static func getApiUrl() -> String {
        return getCriticalInfoPlistValue(forKey: "API_URL")
    }
    
    public static func getAuthUrl() -> String {
        return getCriticalInfoPlistValue(forKey: "AUTH_URL")
    }
    
    public static func getClientId() -> String {
        return getCriticalInfoPlistValue(forKey: "CLIENT_ID")
    }
#if os(iOS) || os(macOS)
    public static func getRedirectUri() -> String {
        return getCriticalInfoPlistValue(forKey: "REDIRECT_URI")
    }
#endif
    
    // MARK: - Non-Critical Configurations (Returns Optional String)
    public static func getYtApiUrl() -> String? {
        return getOptionalInfoPlistValue(forKey: "YT_API_URL")
    }
    
    public static func getYtApiKey() -> String? {
        return getOptionalInfoPlistValue(forKey: "YT_API_KEY")
    }
    
    public static func getPlexBaseUrl() -> String? {
        return getOptionalInfoPlistValue(forKey: "PLEX_URL")
    }

    public static func getPlexToken() -> String? {
        return getOptionalInfoPlistValue(forKey: "PLEX_TOKEN")
    }
    
    // MARK: - Private Helper Functions
    
    /// Fetches a critical Info.plist value. Will cause a fatalError if the key is missing or not a String.
    private static func getCriticalInfoPlistValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            fatalError("🚨 FATAL ERROR: Missing or invalid critical Info.plist value for key: \(key). App cannot function without this configuration.")
        }
        return value
    }
    
    /// Fetches an optional Info.plist value. Returns nil if the key is missing or not a String.
    private static func getOptionalInfoPlistValue(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            print("⚠️ [AppConfigUtil] Warning: Optional Info.plist value for key '\(key)' is missing or not a String. Feature relying on this may be disabled.")
            return nil
        }
        return value
    }
    
    public static func printinfoPlistvalues() {
        if let dict = Bundle.main.infoDictionary {
            for (key, value) in dict {
                print("\(key): \(value)")
            }
        }
    }
    
    public static func getThumbnailImageURL(from thumbnailPath: String) -> URL? {
        guard let plexBaseUrl = getPlexBaseUrl(),
              let plexToken = getPlexToken(),
              var components = URLComponents(string: plexBaseUrl + thumbnailPath) else {
            print("❌ [AppConfigUtil] Cannot construct thumbnail URL: Missing Plex base URL, token, or invalid path.")
            return nil
        }

        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "X-Plex-Token", value: plexToken)
        ]
        return components.url
    }
    
}
