import Foundation

/// A group of notifications for the same Issue/PR
public struct NotificationGroup: Identifiable, Sendable {
    public let id: String
    public let notifications: [GitHubNotification]
    /// The most recent notification (used for display)
    public let latestNotification: GitHubNotification

    public init(id: String, notifications: [GitHubNotification]) {
        self.id = id
        self.notifications = notifications
        // swiftlint:disable:next force_unwrapping
        self.latestNotification = notifications.max(by: { $0.updatedAt < $1.updatedAt })!
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
