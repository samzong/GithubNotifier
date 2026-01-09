import GitHubNotifierCore
import Observation
import SwiftUI

@MainActor
@Observable
final class MenuBarViewModel {
    private let notificationService: NotificationService
    private let activityService: MyItemsService

    var selectedMainTab: MenuBarMainTab = .activity
    var selectedSubTab: MenuBarSubTab = .issues
    var selectedActivityFilter: ActivityFilter = .all
    var isMarkingAsRead = false

    var isLoading: Bool {
        notificationService.isLoading || activityService.isLoading
    }

    var unreadCount: Int {
        notificationService.unreadCount
    }

    var currentUserLogin: String? {
        notificationService.currentUser?.login
    }

    var currentIssuesCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count { $0.notificationType == .issue }
        case .activity:
            activityService.issues(for: legacyFilter).count
        }
    }

    var currentPrsCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count { $0.notificationType == .pullRequest }
        case .activity:
            activityService.pullRequests(for: legacyFilter).count
        }
    }

    var filteredActivityItems: [SearchResultItem] {
        switch selectedSubTab {
        case .all:
            activityService.items(for: legacyFilter).prefix(20).map(\.self)
        case .issues:
            activityService.issues(for: legacyFilter).prefix(20).map(\.self)
        case .prs:
            activityService.pullRequests(for: legacyFilter).prefix(20).map(\.self)
        }
    }

    var filteredNotifications: [GitHubNotification] {
        switch selectedSubTab {
        case .all:
            notificationService.notifications
        case .issues:
            notificationService.notifications.filter { $0.notificationType == .issue }
        case .prs:
            notificationService.notifications.filter { $0.notificationType == .pullRequest }
        }
    }

    var filteredGroupedNotifications: [NotificationGroup] {
        switch selectedSubTab {
        case .all:
            notificationService.groupedNotifications
        case .issues:
            notificationService.groupedNotifications.filter { $0.latestNotification.notificationType == .issue }
        case .prs:
            notificationService.groupedNotifications.filter { $0.latestNotification.notificationType == .pullRequest }
        }
    }

    var filterCounts: [ActivityFilter: Int] {
        [
            .all: activityService.items(for: .all).count,
            .assigned: activityService.items(for: .assigned).count,
            .created: activityService.items(for: .created).count,
            .mentioned: activityService.items(for: .mentioned).count,
            .reviewRequested: activityService.items(for: .reviewRequested).count,
        ]
    }

    init(notificationService: NotificationService, activityService: MyItemsService) {
        self.notificationService = notificationService
        self.activityService = activityService
    }

    func initialLoad() async {
        await notificationService.fetchCurrentUser()
        if notificationService.notifications.isEmpty {
            await notificationService.fetchNotifications()
        }
        if activityService.items.isEmpty {
            await activityService.fetchMyItems()
        }
    }

    func refresh() async {
        switch selectedMainTab {
        case .notifications:
            await notificationService.fetchNotifications()
        case .activity:
            await activityService.fetchMyItems()
        }
    }

    func markFilteredAsRead() async {
        guard !isMarkingAsRead else { return }
        isMarkingAsRead = true
        defer { isMarkingAsRead = false }

        switch selectedSubTab {
        case .all:
            await notificationService.markAllAsRead()
        case .issues, .prs:
            for notification in filteredNotifications {
                await notificationService.markAsRead(notification: notification)
            }
        }
    }

    private var legacyFilter: MyItemsFilter {
        switch selectedActivityFilter {
        case .all: .all
        case .assigned: .assigned
        case .created: .created
        case .mentioned: .mentioned
        case .reviewRequested: .reviewRequested
        }
    }

    func getPRState(for notification: GitHubNotification) -> PRState? {
        notificationService.getPRState(for: notification)
    }

    func getIssueState(for notification: GitHubNotification) -> IssueState? {
        notificationService.getIssueState(for: notification)
    }
}
