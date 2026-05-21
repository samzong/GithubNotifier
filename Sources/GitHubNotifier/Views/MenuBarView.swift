import AppKit
import GitHubNotifierCore
import SwiftUI

struct MenuBarView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(ActivityService.self) private var activityService
    @Environment(SearchService.self) private var searchService
    @Environment(MonitorStore.self) private var monitorStore
    @Environment(MonitorEngine.self) private var monitorEngine
    @Environment(SettingsNavigationState.self) private var settingsNavigationState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @AppStorage("menubar.selectedMainTab") private var selectedMainTabRawValue = MenuBarMainTab.activity.rawValue
    @AppStorage("menubar.selectedSubTab") private var selectedSubTabRawValue = MenuBarSubTab.issues.rawValue
    @AppStorage("menubar.selectedActivityFilter") private var selectedActivityFilterRawValue = ActivityFilter.all.rawValue
    @AppStorage("searchList.selectedFilterId") private var selectedSearchFilterIdString: String?

    @State private var isMarkingAsRead = false
    @State private var visibleMainTabs = MenuBarMainTab.visibleTabs()

    private var hasToken: Bool {
        notificationService.isAuthenticated
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

    private var selectedSearchFilterId: UUID? {
        get { selectedSearchFilterIdString.flatMap { UUID(uuidString: $0) } }
        nonmutating set { selectedSearchFilterIdString = newValue?.uuidString }
    }

    private var effectiveMainTab: MenuBarMainTab {
        if visibleMainTabs.contains(selectedMainTab) {
            return selectedMainTab
        }
        return visibleMainTabs.first ?? .notifications
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasToken {
                HeaderView(
                    selectedTab: Binding(
                        get: { selectedMainTab },
                        set: { selectedMainTab = $0 }
                    ),
                    visibleTabs: visibleMainTabs,
                    unreadCount: notificationService.unreadCount,
                    currentUserLogin: notificationService.currentUser?.login,
                    onOpenSettings: { openSettingsAndBringToFront() },
                    onQuit: { NSApplication.shared.terminate(nil) }
                )

                Divider()

                SubTabPickerView(
                    selectedSubTab: Binding(
                        get: { selectedSubTab },
                        set: { selectedSubTab = $0 }
                    ),
                    mainTab: effectiveMainTab,
                    allCount: currentAllCount,
                    issuesCount: currentIssuesCount,
                    prsCount: currentPrsCount,
                    isMarkingAsRead: isMarkingAsRead,
                    isLoading: notificationService.isLoading || activityService.isLoading || searchService.isLoading || monitorEngine
                        .isSyncing,
                    pinnedSearches: searchService.savedSearches.filter { $0.isEnabled && $0.isPinned },
                    selectedSearchId: Binding(
                        get: { selectedSearchFilterId },
                        set: { selectedSearchFilterId = $0 }
                    ),
                    onMarkAsRead: markFilteredAsRead,
                    onRefresh: refreshCurrentTab,
                    onManage: (effectiveMainTab == .search || effectiveMainTab == .watching) ? {
                        if effectiveMainTab == .search {
                            openAuxiliaryWindowAndBringToFront(window: .searchManagement)
                        } else {
                            openAuxiliaryWindowAndBringToFront(window: .monitorManagement)
                        }
                    } : nil
                )

                if effectiveMainTab == .activity {
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
        .frame(width: 380, height: 520)
        .liquidReadableWindowBackground()
        .liquidAutomaticScrollEdgeEffect(for: .top)
        .task {
            normalizeSelectedMainTabIfNeeded()
            clearInitialFocus()
            await initialLoad()
        }
        .onChange(of: selectedMainTab) { _, newTab in
            guard visibleMainTabs.contains(newTab) else {
                normalizeSelectedMainTabIfNeeded()
                return
            }
            if newTab == .activity, selectedSubTab == .all {
                selectedSubTab = .issues
            }
            Task { await refreshCurrentTab() }
        }
    }

    @ViewBuilder private var contentView: some View {
        switch effectiveMainTab {
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

        case .search:
            SearchListView(
                selectedSearchId: Binding(
                    get: { selectedSearchFilterId },
                    set: { selectedSearchFilterId = $0 }
                )
            ) { item in
                closeMenuBarWindow()
                openActivityItem(item)
            }
            .environment(searchService)

        case .watching:
            if monitorStore.monitors.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("menubar.watching.empty.title".localized)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("menubar.watching.empty.description".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button("monitor.management.title".localized) {
                        openAuxiliaryWindowAndBringToFront(window: .monitorManagement)
                    }
                    .liquidGlassButtonStyle(prominent: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if monitorStore.events.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("monitor.management.events.empty".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(monitorStore.events) { event in
                            MenuBarEventRow(event: event) {
                                monitorStore.markEventRead(id: event.id)
                                if let url = URL(string: event.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var currentAllCount: Int {
        switch effectiveMainTab {
        case .notifications:
            notificationService.unreadCount
        case .activity:
            activityService.items(for: .all).count
        case .search:
            searchService.items.count
        case .watching:
            monitorStore.events.count
        }
    }

    private var currentIssuesCount: Int {
        switch effectiveMainTab {
        case .notifications:
            notificationService.notifications.count { $0.notificationType == .issue }
        case .activity:
            activityService.issues(for: .all).count
        case .search:
            searchService.items.count(where: { $0.itemType == .issue })
        case .watching:
            0
        }
    }

    private var currentPrsCount: Int {
        switch effectiveMainTab {
        case .notifications:
            notificationService.notifications.count { $0.notificationType == .pullRequest }
        case .activity:
            activityService.pullRequests(for: .all).count
        case .search:
            searchService.items.count(where: { $0.itemType == .pullRequest })
        case .watching:
            0
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

    @MainActor
    private func initialLoad() async {
        await notificationService.fetchCurrentUser()
        if notificationService.notifications.isEmpty {
            await notificationService.fetchNotifications()
        }
        if activityService.items.isEmpty {
            await activityService.fetchMyItems()
        }
        if searchService.items.isEmpty {
            await searchService.fetchAll()
        }
        if monitorStore.events.isEmpty {
            await monitorEngine.syncAll()
        }
    }

    @MainActor
    private func refreshCurrentTab() async {
        switch effectiveMainTab {
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
        case .search:
            await searchService.fetchAll()
        case .watching:
            await monitorEngine.syncAll()
        }
    }

    private func normalizeSelectedMainTabIfNeeded() {
        if !visibleMainTabs.contains(selectedMainTab) {
            selectedMainTab = visibleMainTabs.first ?? .notifications
        }
    }

    @MainActor
    private func markFilteredAsRead() async {
        guard !isMarkingAsRead else { return }
        isMarkingAsRead = true
        defer { isMarkingAsRead = false }

        if effectiveMainTab == .watching {
            monitorStore.markAllEventsRead()
            return
        }

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

    private func openSettingsAndBringToFront(tab: SettingsTab? = nil) {
        settingsNavigationState.open(tab: tab)
        closeMenuBarWindow()
        openSettings()

        // Activate the app to bring Settings window to front
        // The Settings scene handles its own window management
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func openAuxiliaryWindowAndBringToFront(window: WindowIdentifier) {
        WindowManager.shared.activeWindow = window
        closeMenuBarWindow()
        openWindow(id: "auxiliary")

        // Activate the app to bring auxiliary window to front
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

struct MenuBarEventRow: View {
    let event: MonitorEvent
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForEventKind(event.kind))
                .font(.system(size: 13))
                .foregroundStyle(colorForEventKind(event.kind))
                .frame(width: 24, height: 24)
                .background(colorForEventKind(event.kind).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if !event.actor.isEmpty {
                        Text("@\(event.actor)")
                            .fontWeight(.semibold)
                    }
                    Text(event.repo)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(event.occurredAt.timeAgo())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(event.isRead ? .secondary : .primary)
                    .fontWeight(event.isRead ? .regular : .semibold)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func iconForEventKind(_ kind: String) -> String {
        switch kind {
        case "commit": "arrow.triangle.pull"
        case "issue": "exclamationmark.bubble"
        case "pr": "arrow.triangle.merge"
        case "release": "shippingbox"
        case "comment": "text.bubble"
        case "code_match": "doc.text.magnifyingglass"
        default: "bell"
        }
    }

    private func colorForEventKind(_ kind: String) -> Color {
        switch kind {
        case "commit": .blue
        case "issue": .green
        case "pr": .purple
        case "release": .orange
        case "comment": .teal
        case "code_match": .cyan
        default: .secondary
        }
    }
}
