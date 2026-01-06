import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var notificationService: NotificationService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let token = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey)
        notificationService = NotificationService(token: token)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateStatusBarIcon(unreadCount: 0)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 600)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(notificationService)
        )

        let refreshInterval = UserDefaults.standard.double(forKey: UserPreferences.refreshIntervalKey)
        notificationService.startAutoRefresh(interval: refreshInterval > 0 ? refreshInterval : 60)

        Task {
            await notificationService.fetchNotifications()
        }

        NotificationCenter.default.addObserver(
            forName: .notificationsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateStatusBarIcon(unreadCount: self.notificationService.notifications.count)
            }
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func updateStatusBarIcon(unreadCount: Int) {
        guard let button = statusItem.button else { return }

        let showCount = UserDefaults.standard.bool(forKey: UserPreferences.showNotificationCountKey)

        if unreadCount > 0 {
            let image = NSImage(named: "GitHubLogoUnread")
            image?.size = NSSize(width: 16, height: 16)
            image?.isTemplate = true
            button.image = image

            if showCount {
                button.title = " \(unreadCount)"
            } else {
                button.title = ""
            }
        } else {
            let image = NSImage(named: "GitHubLogo")
            image?.size = NSSize(width: 16, height: 16)
            image?.isTemplate = true
            button.image = image
            button.title = ""
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notificationService.stopAutoRefresh()
    }
}
