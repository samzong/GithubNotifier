import SwiftUI

public enum NotificationType: String, CaseIterable, Sendable {
    case pullRequest = "PullRequest"
    case issue = "Issue"
    case commit = "Commit"
    case release = "Release"
    case discussion = "Discussion"
    case checkSuite = "CheckSuite"
    case repositoryInvitation = "RepositoryInvitation"
    case repositoryVulnerabilityAlert = "RepositoryVulnerabilityAlert"
    case unknown = "Unknown"

    public static func from(_ typeString: String) -> NotificationType {
        NotificationType(rawValue: typeString) ?? .unknown
    }

    public var displayName: String {
        switch self {
        case .pullRequest:
            "Pull Request"
        case .issue:
            "Issue"
        case .commit:
            "Commit"
        case .release:
            "Release"
        case .discussion:
            "Discussion"
        case .checkSuite:
            "Check Suite"
        case .repositoryInvitation:
            "Repository Invitation"
        case .repositoryVulnerabilityAlert:
            "Vulnerability Alert"
        case .unknown:
            "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .pullRequest:
            "arrow.triangle.pull"
        case .issue:
            "exclamationmark.circle"
        case .commit:
            "arrow.triangle.branch"
        case .release:
            "tag"
        case .discussion:
            "bubble.left.and.bubble.right"
        case .checkSuite:
            "checkmark.circle"
        case .repositoryInvitation:
            "envelope"
        case .repositoryVulnerabilityAlert:
            "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .unknown:
            "questionmark.circle"
        }
    }

    public var iconAssetName: String? {
        switch self {
        case .pullRequest:
            "PullRequestOpen"
        case .issue:
            "IssueOpen"
        default:
            nil
        }
    }
}

public enum PRState: Sendable {
    case open
    case closed
    case merged
    case draft

    public var color: Color {
        switch self {
        case .open:
            .green
        case .closed:
            .red
        case .merged:
            .purple
        case .draft:
            .gray
        }
    }

    public var icon: String {
        switch self {
        case .open:
            "arrow.triangle.pull"
        case .closed:
            "xmark.circle"
        case .merged:
            "arrow.triangle.merge"
        case .draft:
            "doc.text"
        }
    }

    public var iconAssetName: String {
        switch self {
        case .open:
            "PullRequestOpen"
        case .closed:
            "PullRequestClosed"
        case .merged:
            "PullRequestMerged"
        case .draft:
            "PullRequestDraft"
        }
    }
}

public enum IssueState: Sendable {
    case open
    case closedCompleted
    case closedNotPlanned

    public var color: Color {
        switch self {
        case .open:
            .green
        case .closedCompleted:
            .purple
        case .closedNotPlanned:
            .gray
        }
    }

    public var icon: String {
        switch self {
        case .open:
            "exclamationmark.circle"
        case .closedCompleted:
            "checkmark.circle"
        case .closedNotPlanned:
            "xmark.circle"
        }
    }

    public var iconAssetName: String {
        switch self {
        case .open:
            "IssueOpen"
        case .closedCompleted:
            "IssueClosed"
        case .closedNotPlanned:
            "IssueNotPlanned"
        }
    }
}
