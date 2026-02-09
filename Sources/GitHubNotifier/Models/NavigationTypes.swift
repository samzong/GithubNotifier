import Foundation
import GitHubNotifierCore

public enum MenuBarMainTab: String, CaseIterable, Sendable {
    case activity
    case notifications
    case search

    public static let displayOrder: [MenuBarMainTab] = [.notifications, .activity, .search]

    public var titleKey: String {
        switch self {
        case .notifications:
            "menubar.tab.notifications"
        case .activity:
            "menubar.tab.activity"
        case .search:
            "menubar.tab.search"
        }
    }

    public var iconName: String {
        switch self {
        case .notifications:
            "bell"
        case .activity:
            "list.bullet.rectangle"
        case .search:
            "magnifyingglass"
        }
    }

    private var visibilityPreferenceKey: String {
        switch self {
        case .notifications:
            UserPreferences.menubarShowNotificationsTabKey
        case .activity:
            UserPreferences.menubarShowActivityTabKey
        case .search:
            UserPreferences.menubarShowSearchTabKey
        }
    }

    public func isVisible(in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: visibilityPreferenceKey) != nil else {
            return true
        }
        return defaults.bool(forKey: visibilityPreferenceKey)
    }

    public static func visibleTabs(from defaults: UserDefaults = .standard) -> [MenuBarMainTab] {
        let tabs = displayOrder.filter { $0.isVisible(in: defaults) }
        return tabs.isEmpty ? [fallbackTab(from: defaults)] : tabs
    }

    public static func fallbackTab(from defaults: UserDefaults = .standard) -> MenuBarMainTab {
        displayOrder.first(where: { $0.isVisible(in: defaults) }) ?? .notifications
    }
}

public enum MenuBarSubTab: String, CaseIterable, Sendable {
    case all
    case issues
    case prs
}
