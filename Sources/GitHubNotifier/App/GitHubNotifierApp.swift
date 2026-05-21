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
    @State private var session: GitHubSession
    @State private var notificationService: NotificationService
    @State private var activityService: ActivityService
    @State private var searchService: SearchService
    @State private var ruleStorage = RuleStorage()
    @State private var settingsNavigationState = SettingsNavigationState()
    @State private var monitorStore: MonitorStore
    @State private var monitorEngine: MonitorEngine
    private let appConfiguration: AppConfiguration

    /// Sparkle updater controller for automatic updates
    private let updaterController: SPUStandardUpdaterController

    init() {
        appConfiguration = .load()

        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let sessionInstance = GitHubSession()
        _session = State(initialValue: sessionInstance)

        let service = NotificationService(session: sessionInstance)
        _notificationService = State(initialValue: service)

        let itemsService = ActivityService(session: sessionInstance)
        _activityService = State(initialValue: itemsService)

        let search = SearchService(session: sessionInstance)
        _searchService = State(initialValue: search)

        // Create rule storage and inject into notification service
        let storage = RuleStorage()
        _ruleStorage = State(initialValue: storage)

        let store = MonitorStore()
        _monitorStore = State(initialValue: store)

        let engine = MonitorEngine(session: sessionInstance, store: store, notificationManager: NotificationManager.shared)
        _monitorEngine = State(initialValue: engine)

        Task { @MainActor in
            NotificationManager.shared.notificationService = service
            NotificationManager.shared.monitorStore = store
            service.ruleStorage = storage
        }

        if UserDefaults.standard.bool(forKey: "enableSystemNotifications") {
            Task {
                await NotificationManager.shared.requestAuthorization()
            }
        }

        Task { @MainActor in
            if let token = await AuthStore.shared.currentToken() {
                sessionInstance.configure(token: token)
                service.configure()
                itemsService.configure()
                search.configure()

                await service.fetchCurrentUser()
                await service.fetchNotifications()
                await itemsService.fetchMyItems()
                await search.fetchAll()

                engine.start()
                await engine.syncAll()
            }

            await AuthStore.shared.cleanLegacyKeys()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(session)
                .environment(notificationService)
                .environment(activityService)
                .environment(searchService)
                .environment(monitorStore)
                .environment(monitorEngine)
                .environment(settingsNavigationState)
        } label: {
            MenuBarLabel(unreadCount: notificationService.unreadCount)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: session.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                monitorEngine.start()
                Task {
                    await monitorEngine.syncAll()
                }
            } else {
                monitorEngine.stop()
                monitorStore.clearEvents()
            }
        }

        Settings {
            SettingsView(
                updater: updaterController.updater,
                oauthClientID: appConfiguration.githubOAuthClientID
            )
            .environment(session)
            .environment(notificationService)
            .environment(activityService)
            .environment(searchService)
            .environment(ruleStorage)
            .environment(settingsNavigationState)
        }

        // Auxiliary windows (Search Management, future: Kanban, AI, etc.)
        WindowGroup("Branchlight", id: "auxiliary") {
            WindowView()
                .environment(session)
                .environment(searchService)
                .environment(monitorStore)
                .environment(monitorEngine)
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
        .defaultSize(width: 800, height: 600)
        .handlesExternalEvents(matching: ["window"])
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
