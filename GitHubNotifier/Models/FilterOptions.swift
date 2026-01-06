import Foundation

struct FilterOptions {
    var onlyMergedPRs: Bool = false
    var onlyClosedIssues: Bool = false
    var includeTypes: Set<NotificationType> = Set(NotificationType.allCases)

    func shouldMarkAsRead(notification: GitHubNotification, prState: PRState? = nil, issueState: IssueState? = nil) -> Bool {
        switch notification.notificationType {
        case .pullRequest:
            if onlyMergedPRs, let state = prState {
                return state == .merged
            }
            return false
        case .issue:
            if onlyClosedIssues, let state = issueState {
                return state == .closedCompleted || state == .closedNotPlanned
            }
            return false
        default:
            return false
        }
    }
}

struct UserPreferences {
    var githubToken: String?
    var refreshInterval: TimeInterval = 60 // 60 seconds
    var showNotificationCount: Bool = true
    var alwaysShowIcon: Bool = true
    var autoMarkAsReadOnOpen: Bool = false

    static let tokenKeychainKey = "github_personal_access_token"
    
    static let refreshIntervalKey = "refreshInterval"
    static let showNotificationCountKey = "showNotificationCount"
}

