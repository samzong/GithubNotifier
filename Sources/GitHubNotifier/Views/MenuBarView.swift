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

    private var hasToken: Bool {
        KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey) != nil
    }

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
            if hasToken {
                HeaderView(
                    selectedTab: Binding(
                        get: { selectedMainTab },
                        set: { selectedMainTab = $0 }
                    ),
                    unreadCount: notificationService.unreadCount,
                    isLoading: notificationService.isLoading || activityService.isLoading,
                    currentUserLogin: notificationService.currentUser?.login,
                    onRefresh: refreshCurrentTab,
                    onOpenSettings: { openSettingsAndBringToFront() },
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
                    onMarkAsRead: markFilteredAsRead,
                    onOpenRules: { openSettingsAndBringToFront(tab: .rules) }
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
            } else {
                WelcomeView(onOpenSettings: { openSettingsAndBringToFront(tab: .account) })
            }
        }
        .frame(width: 360, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            clearInitialFocus()
            await initialLoad()
        }
        .onChange(of: selectedMainTab) { _, newTab in
            if newTab == .activity, selectedSubTab == .all {
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
        // Prefer constructing URL from known components
        if let number = notification.issueOrPRNumber {
            let baseURL = notification.repository.htmlUrl
            switch notification.notificationType {
            case .pullRequest:
                return URL(string: "\(baseURL)/pull/\(number)")
            case .issue:
                return URL(string: "\(baseURL)/issues/\(number)")
            case .commit:
                // For commits finding the SHA from subject url is safer than fragile parsing
                // But given we don't have SHA easily available in top level model without parsing subject.url,
                // we'll fallback to a safer subject.url replacement or just repository root if complex.
                break
            default:
                break
            }
        }

        // Fallback: If we have subject.url (API URL), try to convert to HTML URL generally
        if let apiURLString = notification.subject.url {
            return URL(string: apiURLString
                .replacingOccurrences(of: "api.github.com/repos", with: "github.com")
                .replacingOccurrences(of: "/pulls/", with: "/pull/") // API uses pulls, HTML uses pull
            )
        }

        return URL(string: notification.repository.htmlUrl)
    }

    private func clearInitialFocus() {
        Task { @MainActor in
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
        }
    }

    @AppStorage("settings.selectedTab") private var settingsSelectedTab: SettingsTab = .general

    private func openSettingsAndBringToFront(tab: SettingsTab? = nil) {
        if let tab {
            settingsSelectedTab = tab
        }
        closeMenuBarWindow()
        openSettings()

        // Activate the app to bring Settings window to front
        // The Settings scene handles its own window management
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
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
