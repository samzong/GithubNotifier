import Foundation

/// A group of notifications for the same Issue/PR
public struct NotificationGroup: Identifiable, Sendable {
    public let id: String
    public let notifications: [GitHubNotification]

    public init(id: String, notifications: [GitHubNotification]) {
        self.id = id
        self.notifications = notifications
    }

    /// The most recent notification (used for display)
    public var latestNotification: GitHubNotification {
        // swiftlint:disable:next force_unwrapping
        notifications.max(by: { $0.updatedAt < $1.updatedAt })!
    }

    /// Convenience accessors from latest notification
    public var notificationType: NotificationType {
        latestNotification.notificationType
    }

    public var repository: GitHubNotification.Repository {
        latestNotification.repository
    }

    public var issueOrPRNumber: Int? {
        latestNotification.issueOrPRNumber
    }

    public var updatedAt: Date {
        latestNotification.updatedAt
    }

    public var displayTitle: String {
        latestNotification.displayTitle
    }
}
