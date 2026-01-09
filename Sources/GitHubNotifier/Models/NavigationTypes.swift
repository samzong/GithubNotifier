import Foundation

public enum MenuBarMainTab: String, CaseIterable, Sendable {
    case activity
    case notifications
}

public enum MenuBarSubTab: String, CaseIterable, Sendable {
    case all
    case issues
    case prs
}

public enum ActivityFilter: String, CaseIterable, Sendable {
    case all
    case assigned
    case created
    case mentioned
    case reviewRequested
}
