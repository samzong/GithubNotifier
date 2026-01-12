//
//  GitHubNotifierApp.swift
//  GitHubNotifier
//
//  Created by X on 1/6/26.
//

import AppKit
import GitHubNotifierCore
import Sparkle
import SwiftUI

@main
struct GitHubNotifierApp: App {
    @State private var notificationService: NotificationService
    @State private var activityService: ActivityService
    @State private var searchService: SearchService
    @State private var ruleStorage = RuleStorage()

    /// Sparkle updater controller for automatic updates
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let token = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey)
        let service = NotificationService(token: token)
        _notificationService = State(initialValue: service)

        let itemsService = ActivityService()
        if let token {
            itemsService.configure(token: token)
        }
        _activityService = State(initialValue: itemsService)

        let search = SearchService()
        if let token {
            search.configure(token: token)
        }
        _searchService = State(initialValue: search)

        // Create rule storage and inject into notification service
        let storage = RuleStorage()
        _ruleStorage = State(initialValue: storage)

        Task { @MainActor in
            NotificationManager.shared.notificationService = service
            service.ruleStorage = storage
        }

        if UserDefaults.standard.bool(forKey: "enableSystemNotifications") {
            Task {
                await NotificationManager.shared.requestAuthorization()
            }
        }

        if token != nil {
            Task { @MainActor in
                await service.fetchCurrentUser()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(notificationService)
                .environment(activityService)
                .environment(searchService)
        } label: {
            MenuBarLabel(unreadCount: notificationService.unreadCount)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(notificationService)
                .environment(activityService)
                .environment(searchService)
                .environment(ruleStorage)
        }

        // Auxiliary windows (Search Management, future: Kanban, AI, etc.)
        WindowGroup("GitHub Notifier", id: "auxiliary") {
            WindowView()
                .environment(searchService)
                .onOpenURL { url in
                    // Handle URL opening logic if needed, or rely on WindowManager's state
                    // The WindowManager.shared.activeWindow might be set by the caller before opening,
                    // or we can parse the URL here.
                    if let host = url.host, host == "window" {
                        let path = url.path.trimmingCharacters(in: .init(charactersIn: "/"))
                        if let windowId = WindowIdentifier(rawValue: path) {
                            WindowManager.shared.activeWindow = windowId
                        }
                    }
                }
        }
        .defaultSize(width: 720, height: 520)
        .handlesExternalEvents(matching: Set(arrayLiteral: "window"))
    }
}

struct MenuBarLabel: View {
    let unreadCount: Int

    @AppStorage(UserPreferences.showNotificationCountKey) private var showCount = true

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: menuBarIcon)
            if unreadCount > 0, showCount {
                Text("\(unreadCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }

    private var menuBarIcon: NSImage {
        let imageName = unreadCount > 0 ? "GitHubLogoUnread" : "GitHubLogo"
        guard let image = NSImage(named: imageName) else {
            return NSImage()
        }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }
}
