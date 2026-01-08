import Foundation

struct UserPreferences {
    var githubToken: String?
    var refreshInterval: TimeInterval = 60 // 60 seconds
    var showNotificationCount: Bool = true
    var alwaysShowIcon: Bool = true

    static let tokenKeychainKey = "github_personal_access_token"

    static let refreshIntervalKey = "refreshInterval"
    static let showNotificationCountKey = "showNotificationCount"
    static let launchAtLoginKey = "launchAtLogin"
}
