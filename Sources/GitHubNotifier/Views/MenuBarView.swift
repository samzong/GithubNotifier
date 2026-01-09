import AppKit
import GitHubNotifierCore
import SwiftUI

struct MenuBarView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(ActivityService.self) private var activityService
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    @AppStorage("menubar.selectedMainTab") private var selectedMainTabRawValue = MenuBarMainTab.activity.rawValue
    @AppStorage("menubar.selectedSubTab") private var selectedSubTabRawValue = MenuBarSubTab.issues.rawValue
    @AppStorage("menubar.selectedActivityFilter") private var selectedActivityFilterRawValue = ActivityFilter.all.rawValue

    @State private var isMarkingAsRead = false

    private var selectedMainTab: MenuBarMainTab {
        get { MenuBarMainTab(rawValue: selectedMainTabRawValue) ?? .activity }
        nonmutating set { selectedMainTabRawValue = newValue.rawValue }
    }

    private var selectedSubTab: MenuBarSubTab {
        get { MenuBarSubTab(rawValue: selectedSubTabRawValue) ?? .issues }
        nonmutating set { selectedSubTabRawValue = newValue.rawValue }
    }

    private var selectedActivityFilter: ActivityFilter {
        get { ActivityFilter(rawValue: selectedActivityFilterRawValue) ?? .all }
        nonmutating set { selectedActivityFilterRawValue = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                selectedTab: Binding(
                    get: { selectedMainTab },
                    set: { selectedMainTab = $0 }
                ),
                unreadCount: notificationService.unreadCount,
                isLoading: notificationService.isLoading || activityService.isLoading,
                currentUserLogin: notificationService.currentUser?.login,
                onRefresh: refreshCurrentTab,
                onOpenSettings: openSettingsAndBringToFront,
                onQuit: { NSApplication.shared.terminate(nil) }
            )

            Divider()

            SubTabPickerView(
                selectedSubTab: Binding(
                    get: { selectedSubTab },
                    set: { selectedSubTab = $0 }
                ),
                mainTab: selectedMainTab,
                allCount: currentAllCount,
                issuesCount: currentIssuesCount,
                prsCount: currentPrsCount,
                isMarkingAsRead: isMarkingAsRead,
                onMarkAsRead: markFilteredAsRead
            )

            if selectedMainTab == .activity {
                FilterBarView(
                    selectedFilter: Binding(
                        get: { selectedActivityFilter },
                        set: { selectedActivityFilter = $0 }
                    ),
                    filterCounts: filterCounts
                )
                Divider()
            }

            Divider()

            contentView
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 320, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            clearInitialFocus()
            await initialLoad()
        }
        .onChange(of: selectedMainTab) { _, newTab in
            if newTab == .activity && selectedSubTab == .all {
                selectedSubTab = .issues
            }
            Task { await refreshCurrentTab() }
        }
    }

    @ViewBuilder private var contentView: some View {
        switch selectedMainTab {
        case .activity:
            ActivityListView(
                subTab: selectedSubTab,
                filter: selectedActivityFilter
            ) { item in
                closeMenuBarWindow()
                openActivityItem(item)
            }
            .environment(activityService)

        case .notifications:
            NotificationListView(subTab: selectedSubTab) { group in
                closeMenuBarWindow()
                openNotificationGroup(group)
            }
            .environment(notificationService)
        }
    }

    private var currentAllCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.unreadCount
        case .activity:
            activityService.items(for: .all).count
        }
    }

    private var currentIssuesCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count { $0.notificationType == .issue }
        case .activity:
            activityService.issues(for: .all).count
        }
    }

    private var currentPrsCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count { $0.notificationType == .pullRequest }
        case .activity:
            activityService.pullRequests(for: .all).count
        }
    }

    private var filterCounts: [ActivityFilter: Int] {
        switch selectedSubTab {
        case .all:
            [
                .all: activityService.items(for: .all).count,
                .assigned: activityService.items(for: .assigned).count,
                .created: activityService.items(for: .created).count,
                .mentioned: activityService.items(for: .mentioned).count,
                .reviewRequested: activityService.items(for: .reviewRequested).count,
            ]
        case .issues:
            [
                .created: activityService.issues(for: .created).count,
                .assigned: activityService.issues(for: .assigned).count,
                .mentioned: activityService.issues(for: .mentioned).count,
            ]
        case .prs:
            [
                .created: activityService.pullRequests(for: .created).count,
                .reviewRequested: activityService.pullRequests(for: .reviewRequested).count,
                .assigned: activityService.pullRequests(for: .assigned).count,
                .mentioned: activityService.pullRequests(for: .mentioned).count,
            ]
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

    @MainActor
    private func initialLoad() async {
        await notificationService.fetchCurrentUser()
        if notificationService.notifications.isEmpty {
            await notificationService.fetchNotifications()
        }
        if activityService.items.isEmpty {
            await activityService.fetchMyItems()
        }
    }

    @MainActor
    private func refreshCurrentTab() async {
        switch selectedMainTab {
        case .notifications:
            await notificationService.fetchNotifications()
        case .activity:
            switch selectedSubTab {
            case .all:
                await activityService.fetchMyItems()
            case .issues:
                await activityService.fetchMyItems(type: .issue)
            case .prs:
                await activityService.fetchMyItems(type: .pullRequest)
            }
        }
    }

    @MainActor
    private func markFilteredAsRead() async {
        guard !isMarkingAsRead else { return }
        isMarkingAsRead = true
        defer { isMarkingAsRead = false }

        let notificationsToMark: [GitHubNotification] = switch selectedSubTab {
        case .all:
            notificationService.notifications
        case .issues:
            notificationService.notifications.filter { $0.notificationType == .issue }
        case .prs:
            notificationService.notifications.filter { $0.notificationType == .pullRequest }
        }

        for notification in notificationsToMark {
            await notificationService.markAsRead(notification: notification)
        }
    }

    private func openActivityItem(_ item: SearchResultItem) {
        if let url = item.webURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func openNotificationGroup(_ group: NotificationGroup) {
        let notification = group.latestNotification
        if let url = webURL(for: notification) {
            NSWorkspace.shared.open(url)
            Task {
                for notification in group.notifications {
                    await notificationService.markAsRead(notification: notification)
                }
            }
        }
    }

    private func webURL(for notification: GitHubNotification) -> URL? {
        guard let apiURLString = notification.subject.url,
              let apiURL = URL(string: apiURLString),
              apiURL.host == "api.github.com" else {
            return nil
        }

        let segments = apiURL.pathComponents
        // pathComponents: ["/", "repos", "owner", "repo", "pulls", "1"]
        guard segments.count >= 5, segments[1] == "repos" else {
            return URL(string: apiURLString.replacingOccurrences(of: "api.github.com/repos", with: "github.com")
                .replacingOccurrences(of: "api.github.com", with: "github.com"))
        }

        let owner = segments[2]
        let repo = segments[3]
        let rest = Array(segments.dropFirst(4))

        if rest.count >= 2 {
            let resource = rest[0]
            let identifier = rest[1]

            switch notification.notificationType {
            case .pullRequest:
                if resource == "pulls" || resource == "issues" {
                    return URL(string: "https://github.com/\(owner)/\(repo)/pull/\(identifier)")
                }
            case .issue:
                if resource == "issues" {
                    return URL(string: "https://github.com/\(owner)/\(repo)/issues/\(identifier)")
                }
            default:
                break
            }

            let mappedResource = resource == "pulls" ? "pull" : resource
            let path = ([owner, repo, mappedResource] + Array(rest.dropFirst(1))).joined(separator: "/")
            return URL(string: "https://github.com/\(path)")
        }

        return URL(string: "https://github.com/\(owner)/\(repo)")
    }

    private func clearInitialFocus() {
        Task { @MainActor in
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
        }
    }

    private func openSettingsAndBringToFront() {
        closeMenuBarWindow()
        openSettings()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            if let settingsWindow = NSApplication.shared.windows.first(where: {
                $0.title.contains("Settings") || $0.title.contains("设置")
            }) {
                settingsWindow.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }

    @MainActor
    private func closeMenuBarWindow() {
        dismiss()
        if let keyWindow = NSApplication.shared.keyWindow {
            keyWindow.performClose(nil)
        }
    }
}
