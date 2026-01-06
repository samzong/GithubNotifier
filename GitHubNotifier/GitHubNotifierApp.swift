//
//  GitHubNotifierApp.swift
//  GitHubNotifier
//
//  Created by X on 1/6/26.
//

import SwiftUI
import AppKit

@main
struct GitHubNotifierApp: App {
    @State private var notificationService: NotificationService

    init() {
        let token = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey)
        _notificationService = State(initialValue: NotificationService(token: token))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(notificationService)
        } label: {
            MenuBarLabel(unreadCount: notificationService.unreadCount)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(notificationService)
        }
    }
}

struct MenuBarLabel: View {
    let unreadCount: Int

    @AppStorage(UserPreferences.showNotificationCountKey) private var showCount = true

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: menuBarIcon)
            if unreadCount > 0 && showCount {
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
