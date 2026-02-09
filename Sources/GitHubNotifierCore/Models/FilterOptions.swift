import Foundation

public struct UserPreferences {
    public var githubToken: String?
    public var refreshInterval: TimeInterval = 60 // 60 seconds
    public var showNotificationCount: Bool = true
    public var alwaysShowIcon: Bool = true

    public static let tokenKeychainKey = "github_personal_access_token"

    public static let refreshIntervalKey = "refreshInterval"
    public static let showNotificationCountKey = "showNotificationCount"
    public static let launchAtLoginKey = "launchAtLogin"
    public static let menubarShowNotificationsTabKey = "menubar.showNotificationsTab"
    public static let menubarShowActivityTabKey = "menubar.showActivityTab"
    public static let menubarShowSearchTabKey = "menubar.showSearchTab"

    public init() {}
}
