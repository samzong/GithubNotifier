import Foundation

public enum MenuBarMainTab: String, CaseIterable, Sendable {
    case activity
    case notifications
    case search
}

public enum MenuBarSubTab: String, CaseIterable, Sendable {
    case all
    case issues
    case prs
}

