import SwiftUI

enum NotificationType: String, CaseIterable {
    case pullRequest = "PullRequest"
    case issue = "Issue"
    case commit = "Commit"
    case release = "Release"
    case discussion = "Discussion"
    case checkSuite = "CheckSuite"
    case repositoryInvitation = "RepositoryInvitation"
    case repositoryVulnerabilityAlert = "RepositoryVulnerabilityAlert"
    case unknown = "Unknown"

    static func from(_ typeString: String) -> NotificationType {
        NotificationType(rawValue: typeString) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .pullRequest:
            return "Pull Request"
        case .issue:
            return "Issue"
        case .commit:
            return "Commit"
        case .release:
            return "Release"
        case .discussion:
            return "Discussion"
        case .checkSuite:
            return "Check Suite"
        case .repositoryInvitation:
            return "Repository Invitation"
        case .repositoryVulnerabilityAlert:
            return "Vulnerability Alert"
        case .unknown:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .pullRequest:
            return "arrow.triangle.pull"
        case .issue:
            return "exclamationmark.circle"
        case .commit:
            return "arrow.triangle.branch"
        case .release:
            return "tag"
        case .discussion:
            return "bubble.left.and.bubble.right"
        case .checkSuite:
            return "checkmark.circle"
        case .repositoryInvitation:
            return "envelope"
        case .repositoryVulnerabilityAlert:
            return "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var iconAssetName: String? {
        switch self {
        case .pullRequest:
            return "PullRequestOpen"
        case .issue:
            return "IssueOpen"
        default:
            return nil
        }
    }
}

enum PRState {
    case open
    case closed
    case merged
    case draft

    var color: Color {
        switch self {
        case .open:
            return .green
        case .closed:
            return .red
        case .merged:
            return .purple
        case .draft:
            return .gray
        }
    }

    var icon: String {
        switch self {
        case .open:
            return "arrow.triangle.pull"
        case .closed:
            return "xmark.circle"
        case .merged:
            return "arrow.triangle.merge"
        case .draft:
            return "doc.text"
        }
    }

    var iconAssetName: String {
        switch self {
        case .open:
            return "PullRequestOpen"
        case .closed:
            return "PullRequestClosed"
        case .merged:
            return "PullRequestMerged"
        case .draft:
            return "PullRequestDraft"
        }
    }
}

enum IssueState {
    case open
    case closedCompleted
    case closedNotPlanned

    var color: Color {
        switch self {
        case .open:
            return .green
        case .closedCompleted:
            return .purple
        case .closedNotPlanned:
            return .gray
        }
    }

    var icon: String {
        switch self {
        case .open:
            return "exclamationmark.circle"
        case .closedCompleted:
            return "checkmark.circle"
        case .closedNotPlanned:
            return "xmark.circle"
        }
    }

    var iconAssetName: String {
        switch self {
        case .open:
            return "IssueOpen"
        case .closedCompleted:
            return "IssueClosed"
        case .closedNotPlanned:
            return "IssueNotPlanned"
        }
    }
}
