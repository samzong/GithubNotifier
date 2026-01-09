import AppKit
import GitHubNotifierCore
import Kingfisher
import SwiftUI

struct MenuBarView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(MyItemsService.self) private var myItemsService

    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    @AppStorage("menubar.selectedMainTab") private var selectedMainTabRawValue = MainTab.notifications.rawValue
    @AppStorage("menubar.selectedSubTab") private var selectedSubTabRawValue = SubTab.all.rawValue
    @AppStorage("menubar.selectedMyItemsFilter") private var selectedMyItemsFilterRawValue = MyItemsFilter.all.rawValue

    @State private var isMarkingAsRead = false

    private var selectedMainTab: MainTab {
        get { MainTab(rawValue: selectedMainTabRawValue) ?? .notifications }
        nonmutating set { selectedMainTabRawValue = newValue.rawValue }
    }

    private var selectedSubTab: SubTab {
        get { SubTab(rawValue: selectedSubTabRawValue) ?? .all }
        nonmutating set { selectedSubTabRawValue = newValue.rawValue }
    }

    private var selectedMyItemsFilter: MyItemsFilter {
        get { MyItemsFilter(rawValue: selectedMyItemsFilterRawValue) ?? .all }
        nonmutating set { selectedMyItemsFilterRawValue = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (fixed at top)
            headerView
            
            Divider()

            subTabPicker

            Divider()

            // Content fills remaining space
            contentSection
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 400, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            // Initial load using async context
            clearInitialFocus()
            await initialLoad()
        }
        .onChange(of: selectedMainTab) { _, newValue in
             Task { await refreshCurrentTab() }
        }
    }

    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Left: Main Tabs (gap-1 = 4pt)
            HStack(spacing: 4) {
                mainTabButton(
                    title: "menubar.tab.my_items".localized,
                    icon: "list.bullet.rectangle",
                    tab: .myItems
                )
                
                mainTabButton(
                    title: "menubar.tab.notifications".localized,
                    icon: "bell",
                    tab: .notifications,
                    showDot: notificationService.unreadCount > 0
                )
            }
            
            Spacer()
            
            // Right: Profile/Settings (gap-2 = 8pt)
            HStack(spacing: 8) {
                // Refresh Button (p-1.5 = 6pt, icon w-3.5 = 14pt)
                Button(action: {
                    Task { await refreshCurrentTab() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(notificationService.isLoading || myItemsService.isLoading ? 360 : 0))
                        .animation(
                            (notificationService.isLoading || myItemsService.isLoading) ?
                                Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: notificationService.isLoading || myItemsService.isLoading
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help("menubar.refresh".localized)
                
                // Divider (w-px h-4)
                Divider().frame(height: 16)
                
                // Settings Menu (gear icon)
                Menu {
                    if let login = notificationService.currentUser?.login {
                        Text("Signed in as \(login)")
                        Divider()
                    }
                    
                    Button("menubar.open.github.notifications".localized) {
                        closeMenuBarWindow()
                        openUnreadNotificationsInBrowser()
                    }

                    Divider()

                    Button("settings.title".localized) {
                        openSettingsAndBringToFront()
                    }
                    
                    Divider()
                    
                    Button("menubar.quit".localized) {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24, height: 24)
            }
        }
        .frame(height: 48) // h-12 = 48pt
        .padding(.horizontal, 12) // px-3 = 12pt
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
    
    // nav-tab button matching demo.html exactly
    private func mainTabButton(title: String, icon: String, tab: MainTab, showDot: Bool = false) -> some View {
        let isSelected = selectedMainTab == tab
        
        return Button(action: { selectedMainTab = tab }) {
            HStack(spacing: 8) { // gap-2 = 8pt
                Image(systemName: icon)
                    .font(.system(size: 14)) // w-4 h-4 = 16pt, but SF Symbols look better at 14
                
                Text(title)
                    .font(.system(size: 12, weight: .medium)) // text-xs font-medium
                    .lineLimit(1)
            }
            .fixedSize()
            .padding(.horizontal, 12) // px-3
            .padding(.vertical, 6) // py-1.5
            .background(
                isSelected 
                    ? Color.accentColor.opacity(0.1) // rgba(0,122,255,0.1)
                    : Color.clear
            )
            .foregroundStyle(isSelected ? Color.accentColor : .secondary) // #007aff vs #636366
            .clipShape(RoundedRectangle(cornerRadius: 6)) // rounded-md
            .overlay(
                Group {
                    if showDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -8)
                    }
                },
                alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sub Tab Picker (All / Issues / PRs)

    private var subTabPicker: some View {
        VStack(spacing: 12) {
            // Segmented Control Style
            HStack(spacing: 0) {
                subTabButton("menubar.tab.issues".localized, tab: .issues, count: currentIssuesCount, icon: "exclamationmark.circle")
                
                Divider()
                    .frame(height: 16)
                
                subTabButton("menubar.tab.prs".localized, tab: .prs, count: currentPrsCount, icon: "arrow.triangle.pull")
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // GitHub-style filter for My Items (Below Sub Tabs)
            if selectedMainTab == .myItems {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterButton("menubar.filter.assigned".localized, count: myItemsService.count(for: .assigned), filter: .assigned, color: .blue)
                        filterButton("menubar.filter.created".localized, count: myItemsService.count(for: .created), filter: .created, color: .green)
                        filterButton("menubar.filter.mentioned".localized, count: myItemsService.count(for: .mentioned), filter: .mentioned, color: .orange)
                        
                        if selectedSubTab != .issues {
                             filterButton("menubar.filter.review_requested".localized, count: myItemsService.count(for: .reviewRequested), filter: .reviewRequested, color: .purple)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            } else {
                // For Notifications tab, show "Mark as Read" or other controls if needed
                if selectedMainTab == .notifications {
                     HStack {
                         Spacer()
                         markAsReadButton
                     }
                     .padding(.horizontal, 16)
                     .padding(.bottom, 8)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func subTabButton(_ title: String, tab: SubTab, count: Int, icon: String) -> some View {
        let isSelected = selectedSubTab == tab
        return Button(action: {
            if selectedSubTab == tab {
                selectedSubTab = .all 
            } else {
                selectedSubTab = tab
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color(nsColor: .windowBackgroundColor) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }

    @ViewBuilder
    private func filterButton(_ title: String, count: Int, filter: MyItemsFilter, color: Color) -> some View {
        let isSelected = selectedMyItemsFilter == filter

        Button(action: { 
            if selectedMyItemsFilter == filter {
                selectedMyItemsFilter = .all // Deselect to show all
            } else {
                selectedMyItemsFilter = filter
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? color.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? color : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Section Router

    @ViewBuilder private var contentSection: some View {
        switch selectedMainTab {
        case .notifications:
            notificationsSection
        case .myItems:
            myItemsSection
        }
    }

    // MARK: - My Items Section

    @ViewBuilder private var myItemsSection: some View {
        if myItemsService.isLoading && myItemsService.items.isEmpty {
            MenuRowText("menubar.loading".localized)
        } else if let error = myItemsService.errorMessage {
            MenuRowText("\("menubar.error.title".localized): \(error)")

            MenuRowButton(title: "menubar.retry".localized) {
                Task {
                    await myItemsService.fetchMyItems()
                }
            }
        } else if filteredMyItems.isEmpty {
            Text("menubar.my_items.empty".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredMyItems.prefix(20))) { item in
                        myItemRow(for: item)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }
        let hours = Int(minutes / 60)
        if hours < 24 { return "\(hours)h" }
        let days = Int(hours / 24)
        if days < 30 { return "\(days)d" }
        let months = Int(days / 30)
        if months < 12 { return "\(months)mo" }
        return "\(Int(months / 12))y"
    }

    @ViewBuilder
    private func myItemRow(for item: SearchResultItem) -> some View {
        Button(action: {
            closeMenuBarWindow()
            openMyItem(item)
        }) {
            HStack(alignment: .top, spacing: 8) {
                // Avatar (Author)
                let avatarString = item.authorAvatarUrl ?? "https://github.com/\(item.repositoryOwner).png"
                KFImage(URL(string: avatarString))
                    .resizable()
                    .placeholder {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .fade(duration: 0.25)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    // Repository name + Issue/PR number + time ago
                    HStack(spacing: 4) {
                        Text(item.repositoryName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("#\(String(item.number))")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        Text(timeAgoString(from: item.updatedAt))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if let ciStatus = item.ciStatus {
                             Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)

                             ciStatusIcon(for: ciStatus)
                        }
                    }

                    // Title
                    Text(item.title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                // State icon
                myItemIcon(for: item)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func myItemIcon(for item: SearchResultItem) -> some View {
        let (iconName, color) = iconInfo(for: item)
        Image(systemName: iconName)
            .font(.system(size: 16))
            .foregroundStyle(color)
    }

    private func iconInfo(for item: SearchResultItem) -> (String, Color) {
        switch item.itemType {
        case .pullRequest:
            switch item.state.uppercased() {
            case "MERGED":
                return ("arrow.triangle.merge", .purple)
            case "CLOSED":
                return ("xmark.circle", .red)
            default:
                return ("arrow.triangle.pull", .green)
            }
        case .issue:
            switch item.state.uppercased() {
            case "CLOSED":
                return ("checkmark.circle", .purple)
            default:
                return ("circle.dotted", .green)
            }
        }
    }
    
    @ViewBuilder
    private func ciStatusIcon(for status: CIStatus) -> some View {
        switch status.state {
        case "SUCCESS":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case "FAILURE", "ERROR":
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
        case "PENDING":
             Image(systemName: "clock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    // MARK: - Notifications Section (existing)
    
    @ViewBuilder private var notificationsSection: some View {
        if notificationService.isLoading && notificationService.notifications.isEmpty {
            MenuRowText("menubar.loading".localized)
        } else if let error = notificationService.errorMessage {
            MenuRowText("\("menubar.error.title".localized): \(error)")

            MenuRowButton(title: "menubar.retry".localized) {
                Task {
                    await notificationService.fetchNotifications()
                }
            }
        } else if notificationService.notifications.isEmpty || filteredGroupedNotifications.isEmpty {
            // Show "All caught up!" message when no notifications
            Text("menubar.empty.subtitle".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredGroupedNotifications.prefix(20))) { group in
                        notificationGroupItem(for: group)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }

    @ViewBuilder
    private func notificationGroupItem(for group: NotificationGroup) -> some View {
        let notification = group.latestNotification
        let prState = notificationService.getPRState(for: notification)
        let issueState = notificationService.getIssueState(for: notification)

        Button(action: {
            closeMenuBarWindow()
            openNotificationGroup(group)
        }) {
            HStack(alignment: .top, spacing: 8) {
                // Avatar
                let avatarUrl = URL(string: "https://github.com/\(notification.repository.owner.login).png")
                KFImage(avatarUrl)
                    .resizable()
                    .placeholder {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .fade(duration: 0.25)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    // Repository name + Issue/PR number + time ago
                    HStack(spacing: 4) {
                        Text(notification.repository.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)

                        if let number = group.issueOrPRNumber {
                            Text("#\(String(number))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        Text(notification.updatedAt.timeAgo())
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    // Notification title
                    Text(notification.displayTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 8)

                // Icon on the right - use state-specific icon and color
                notificationIcon(for: notification, prState: prState, issueState: issueState)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func notificationIcon(for notification: GitHubNotification, prState: PRState?, issueState: IssueState?) -> some View {
        IconHelper.notificationIcon(for: notification, prState: prState, issueState: issueState, size: 16)
    }

    @ViewBuilder private var markAsReadButton: some View {
        Button(action: markFilteredNotificationsAsRead) {
            if isMarkingAsRead {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(filteredNotifications.isEmpty ? .tertiary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(filteredNotifications.isEmpty || isMarkingAsRead)
        .help(markAsReadButtonTitle)
    }

    private var markAsReadButtonTitle: String {
        switch selectedSubTab {
        case .all:
            "menubar.mark_all_read".localized
        case .issues:
            "menubar.mark_issues_read".localized
        case .prs:
            "menubar.mark_prs_read".localized
        }
    }

    private func markFilteredNotificationsAsRead() {
        guard !isMarkingAsRead else { return }

        isMarkingAsRead = true

        Task {
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
    }

    // MARK: - Computed Properties for Current Tab

    private var currentAllCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count
        case .myItems:
            myItemsService.items(for: selectedMyItemsFilter).count
        }
    }

    private var currentIssuesCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count(where: { $0.notificationType == .issue })
        case .myItems:
            myItemsService.issues(for: selectedMyItemsFilter).count
        }
    }

    private var currentPrsCount: Int {
        switch selectedMainTab {
        case .notifications:
            notificationService.notifications.count(where: { $0.notificationType == .pullRequest })
        case .myItems:
            myItemsService.pullRequests(for: selectedMyItemsFilter).count
        }
    }

    private var filteredMyItems: [SearchResultItem] {
        switch selectedSubTab {
        case .all:
            myItemsService.items(for: selectedMyItemsFilter)
        case .issues:
            myItemsService.issues(for: selectedMyItemsFilter)
        case .prs:
            myItemsService.pullRequests(for: selectedMyItemsFilter)
        }
    }

    private var filteredNotifications: [GitHubNotification] {
        switch selectedSubTab {
        case .all:
            notificationService.notifications
        case .issues:
            notificationService.notifications.filter { $0.notificationType == .issue }
        case .prs:
            notificationService.notifications.filter { $0.notificationType == .pullRequest }
        }
    }

    private var filteredGroupedNotifications: [NotificationGroup] {
        switch selectedSubTab {
        case .all:
            notificationService.groupedNotifications
        case .issues:
            notificationService.groupedNotifications.filter { $0.notificationType == .issue }
        case .prs:
            notificationService.groupedNotifications.filter { $0.notificationType == .pullRequest }
        }
    }

    private func openUnreadNotificationsInBrowser() {
        if let url = URL(string: "https://github.com/notifications?query=is%3Aunread") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openNotificationGroup(_ group: NotificationGroup) {
        let notification = group.latestNotification
        if let url = webURL(for: notification) {
            NSWorkspace.shared.open(url)

            Task {
                await notificationService.markGroupAsRead(group)
            }
        }
    }

    private func openNotification(_ notification: GitHubNotification) {
        if let url = webURL(for: notification) {
            NSWorkspace.shared.open(url)

            Task {
                await notificationService.markAsRead(notification: notification)
            }
        }
    }

    private func webURL(for notification: GitHubNotification) -> URL? {
        guard let apiURLString = notification.subject.url,
              let apiURL = URL(string: apiURLString),
              apiURL.host == "api.github.com" else {
            return notification.subject.url.flatMap(URL.init(string:))
        }

        let segments = apiURL.path.split(separator: "/").map(String.init)
        guard segments.count >= 3, segments.first == "repos" else {
            return URL(string: apiURLString.replacingOccurrences(of: "api.github.com", with: "github.com"))
        }

        let owner = segments[1]
        let repo = segments[2]
        let rest = Array(segments.dropFirst(3))

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

            let mapping: [String: String] = [
                "pulls": "pull",
                "commits": "commit",
            ]
            let mappedResource = mapping[resource] ?? resource
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
            NSRunningApplication.current.activate()
            try? await Task.sleep(for: .milliseconds(80))
            bringSettingsWindowToFront()
        }
    }

    private func bringSettingsWindowToFront() {
        let expectedTitle = "settings.title".localized

        if let window = NSApplication.shared.windows.first(where: { $0.title == expectedTitle }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        if let window = NSApplication.shared.windows.first(where: { $0.title.localizedCaseInsensitiveContains(expectedTitle) }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        if let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Helper Methods

    private func initialLoad() async {
        await notificationService.fetchCurrentUser()
        if notificationService.notifications.isEmpty {
            await notificationService.fetchNotifications()
        }
        if myItemsService.items.isEmpty {
            await myItemsService.fetchMyItems()
        }
    }

    private func refreshCurrentTab() async {
        switch selectedMainTab {
        case .notifications:
            await notificationService.fetchNotifications()
        case .myItems:
            await myItemsService.fetchMyItems()
        }
    }

    private func openMyItem(_ item: SearchResultItem) {
        if let url = item.webURL {
            NSWorkspace.shared.open(url)
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

private enum MainTab: String, CaseIterable {
    case notifications
    case myItems
}

private enum SubTab: String, CaseIterable {
    case all
    case issues
    case prs
}

private struct MenuRowText: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
    }
}

private struct MenuRowButton: View {
    enum LeadingIcon {
        case system(String)
        case nsImage(NSImage)
        case none
    }

    let leadingIcon: LeadingIcon
    let title: String
    let shortcutHint: String?
    let role: ButtonRole?
    let action: () -> Void

    @State private var isHovered = false

    init(systemImage: String, title: String, shortcutHint: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.leadingIcon = .system(systemImage)
        self.title = title
        self.shortcutHint = shortcutHint
        self.role = role
        self.action = action
    }

    init(nsImage: NSImage, title: String, shortcutHint: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.leadingIcon = .nsImage(nsImage)
        self.title = title
        self.shortcutHint = shortcutHint
        self.role = role
        self.action = action
    }

    init(title: String, shortcutHint: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.leadingIcon = .none
        self.title = title
        self.shortcutHint = shortcutHint
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                iconView
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if let shortcutHint {
                    Text(shortcutHint)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder private var iconView: some View {
        switch leadingIcon {
        case let .system(systemName):
            Image(systemName: systemName)
                .foregroundStyle(.secondary)
        case let .nsImage(image):
            if image.isTemplate {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .foregroundStyle(.secondary)
            } else {
                Image(nsImage: image)
            }
        case .none:
            Color.clear
        }
    }
}
