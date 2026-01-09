import GitHubNotifierCore
import ServiceManagement
import SwiftUI

struct GeneralSettingsTab: View {
    @Environment(NotificationService.self) private var notificationService

    @AppStorage(UserPreferences.refreshIntervalKey) private var refreshInterval: Double = 60
    @AppStorage(UserPreferences.launchAtLoginKey) private var launchAtLogin = false
    @AppStorage("enableSystemNotifications") private var enableSystemNotifications = false

    @State private var isTestingNotification = false

    let settingsWidth: CGFloat

    private let refreshOptions: [(seconds: Double, label: String)] = [
        (60, "settings.refresh.1min".localized),
        (120, "settings.refresh.2min".localized),
        (300, "settings.refresh.5min".localized),
        (600, "settings.refresh.10min".localized),
    ]

    var body: some View {
        Form {
            Section {
                Picker("settings.refresh.title".localized, selection: $refreshInterval) {
                    ForEach(refreshOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: refreshInterval) { _, newValue in
                    notificationService.startAutoRefresh(interval: newValue)
                }

                Toggle("settings.startup.launch".localized, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section {
                Toggle("settings.notifications.enable".localized, isOn: $enableSystemNotifications)
                    .onChange(of: enableSystemNotifications) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }

                if enableSystemNotifications {
                    HStack {
                        Button("settings.notifications.test".localized) {
                            sendTestNotification()
                        }
                        .disabled(isTestingNotification)

                        if isTestingNotification {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.leading, 4)
                        }
                    }

                    Text("settings.notifications.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("settings.notifications.section".localized)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
        }
    }

    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationManager.shared.requestAuthorization()
            if !granted {
                await MainActor.run {
                    enableSystemNotifications = false
                }
            }
        }
    }

    private func sendTestNotification() {
        isTestingNotification = true
        Task {
            await NotificationManager.shared.sendTestNotification()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                isTestingNotification = false
            }
        }
    }
}
