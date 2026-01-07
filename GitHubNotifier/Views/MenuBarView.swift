import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    @AppStorage("menubar.selectedTab") private var selectedTabRawValue = MenuBarTab.all.rawValue

    @State private var isMarkingAsRead = false

    private var selectedTab: MenuBarTab {
        get { MenuBarTab(rawValue: selectedTabRawValue) ?? .all }
        nonmutating set { selectedTabRawValue = newValue.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title and external link icon
            HStack {
                Text("menubar.title".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {
                    closeMenuBarWindow()
                    openUnreadNotificationsInBrowser()
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("menubar.open.github.notifications".localized)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            tabPicker

            Divider()

            notificationsSection

            Divider()

            // Footer menu
            MenuRowButton(systemImage: "arrow.clockwise", title: "menubar.refresh".localized, shortcutHint: "⌘R") {
                Task {
                    await notificationService.fetchNotifications()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            MenuRowButton(systemImage: "gearshape", title: "menubar.preferences".localized, shortcutHint: "⌘,") {
                openSettingsAndBringToFront()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            MenuRowButton(systemImage: "power", title: "menubar.quit".localized, shortcutHint: "⌘Q", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 360)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .task {
            clearInitialFocus()
            if notificationService.notifications.isEmpty {
                await notificationService.fetchNotifications()
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        if notificationService.isLoading && notificationService.notifications.isEmpty {
            MenuRowText("menubar.loading".localized)
        } else if let error = notificationService.errorMessage {
            MenuRowText("\("menubar.error.title".localized): \(error)")

            MenuRowButton(title: "menubar.retry".localized) {
                Task {
                    await notificationService.fetchNotifications()
                }
            }
        } else if notificationService.notifications.isEmpty || filteredNotifications.isEmpty {
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
                    ForEach(Array(filteredNotifications.prefix(20))) { notification in
                        notificationListItem(for: notification)
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }

    @ViewBuilder
    private func notificationListItem(for notification: GitHubNotification) -> some View {
        let prState = notificationService.getPRState(for: notification)
        let issueState = notificationService.getIssueState(for: notification)
        
        Button(action: {
            closeMenuBarWindow()
            openNotification(notification)
        }) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    // Repository name + time ago
                    HStack(spacing: 4) {
                        Text(notification.repository.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)

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
        switch notification.notificationType {
        case .pullRequest:
            if let state = prState {
                if let image = templateIcon(named: state.iconAssetName, size: 16) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundStyle(state.color)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: state.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(state.color)
                        .frame(width: 16, height: 16)
                }
            } else {
                // Fallback when state not yet loaded
                if let assetName = notification.notificationType.iconAssetName,
                   let image = templateIcon(named: assetName, size: 16) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: notification.notificationType.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
            }
        case .issue:
            if let state = issueState {
                if let image = templateIcon(named: state.iconAssetName, size: 16) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundStyle(state.color)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: state.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(state.color)
                        .frame(width: 16, height: 16)
                }
            } else {
                if let assetName = notification.notificationType.iconAssetName,
                   let image = templateIcon(named: assetName, size: 16) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: notification.notificationType.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
            }
        default:
            Image(systemName: notification.notificationType.icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            )) {
                Text("\("menubar.tab.all".localized)(\(allCount))")
                    .tag(MenuBarTab.all)
                Text("\("menubar.tab.issues".localized)(\(issuesCount))")
                    .tag(MenuBarTab.issues)
                Text("\("menubar.tab.prs".localized)(\(prsCount))")
                    .tag(MenuBarTab.prs)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)

            markAsReadButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var markAsReadButton: some View {
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
        switch selectedTab {
        case .all:
            return "menubar.mark_all_read".localized
        case .issues:
            return "menubar.mark_issues_read".localized
        case .prs:
            return "menubar.mark_prs_read".localized
        }
    }

    private func markFilteredNotificationsAsRead() {
        guard !isMarkingAsRead else { return }

        isMarkingAsRead = true

        Task {
            defer { isMarkingAsRead = false }

            switch selectedTab {
            case .all:
                await notificationService.markAllAsRead()
            case .issues, .prs:
                for notification in filteredNotifications {
                    await notificationService.markAsRead(notification: notification)
                }
            }
        }
    }

    private var allCount: Int { notificationService.notifications.count }

    private var issuesCount: Int {
        notificationService.notifications.filter { $0.notificationType == .issue }.count
    }

    private var prsCount: Int {
        notificationService.notifications.filter { $0.notificationType == .pullRequest }.count
    }

    private var filteredNotifications: [GitHubNotification] {
        switch selectedTab {
        case .all:
            return notificationService.notifications
        case .issues:
            return notificationService.notifications.filter { $0.notificationType == .issue }
        case .prs:
            return notificationService.notifications.filter { $0.notificationType == .pullRequest }
        }
    }

    private var emptyTitleForSelectedTab: String {
        switch selectedTab {
        case .all:
            return "menubar.empty.title".localized
        case .issues:
            return "menubar.empty.issues".localized
        case .prs:
            return "menubar.empty.prs".localized
        }
    }

    private func openUnreadNotificationsInBrowser() {
        if let url = URL(string: "https://github.com/notifications?query=is%3Aunread") {
            NSWorkspace.shared.open(url)
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

    private func menuTitle(for notification: GitHubNotification) -> String {
        let title = "\(notification.repository.fullName): \(notification.displayTitle)"
        return title.truncate(to: 180)
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
                "commits": "commit"
            ]
            let mappedResource = mapping[resource] ?? resource
            let path = ([owner, repo, mappedResource] + Array(rest.dropFirst(1))).joined(separator: "/")
            return URL(string: "https://github.com/\(path)")
        }

        return URL(string: "https://github.com/\(owner)/\(repo)")
    }

    private var githubIcon: NSImage {
        guard let image = NSImage(named: "GitHubLogo") else {
            return NSImage()
        }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }

    private func templateIcon(named name: String, size: CGFloat) -> NSImage? {
        guard let image = NSImage(named: name) else {
            return nil
        }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }

    private func clearInitialFocus() {
        DispatchQueue.main.async {
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
        }
    }

    private func openSettingsAndBringToFront() {
        closeMenuBarWindow()
        openSettings()

        DispatchQueue.main.async {
            _ = NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
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

    private func closeMenuBarWindow() {
        dismiss()

        if let keyWindow = NSApplication.shared.keyWindow {
            keyWindow.performClose(nil)
        }
    }
}

private enum MenuBarTab: String, CaseIterable {
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

    @ViewBuilder
    private var iconView: some View {
        switch leadingIcon {
        case .system(let systemName):
            Image(systemName: systemName)
                .foregroundStyle(.secondary)
        case .nsImage(let image):
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
