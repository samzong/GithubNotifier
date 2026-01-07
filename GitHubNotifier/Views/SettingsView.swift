import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(NotificationService.self) private var notificationService
    @AppStorage(UserPreferences.refreshIntervalKey) private var refreshInterval: Double = 60
    @AppStorage(UserPreferences.launchAtLoginKey) private var launchAtLogin = false
    @AppStorage("enableSystemNotifications") private var enableSystemNotifications = false
    @State private var token = ""
    @State private var hasLoadedToken = false
    @FocusState private var isTokenFocused: Bool
    @State private var isTestingNotification = false
    private let settingsWidth: CGFloat = 480
    
    private let refreshOptions: [(seconds: Double, label: String)] = [
        (60, "settings.refresh.1min".localized),
        (120, "settings.refresh.2min".localized),
        (300, "settings.refresh.5min".localized),
        (600, "settings.refresh.10min".localized)
    ]
    
    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("settings.tab.general".localized, systemImage: "gearshape")
                }
            
            accountSettings
                .tabItem {
                    Label("settings.tab.account".localized, systemImage: "person.crop.circle")
                }
        }
        .frame(width: settingsWidth)
        .padding()
        .onAppear {
            if let savedToken = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey) {
                token = savedToken
            }
            hasLoadedToken = true
        }
    }

    private var generalSettings: some View {
        Form {
            Section {
                Picker("settings.refresh.title".localized, selection: $refreshInterval) {
                    ForEach(refreshOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu) // Native macOS popup button
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
    
    private var accountSettings: some View {
        Form {
            Section {
                SecureField("settings.token.title".localized, text: $token)
                    .focused($isTokenFocused)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        saveTokenAutomatically(token)
                    }
                    .onChange(of: isTokenFocused) { _, focused in
                        if !focused {
                            saveTokenAutomatically(token)
                        }
                    }
                
                Link("settings.token.generate.link".localized, destination: URL(string: "https://github.com/settings/tokens/new")!)
                    .font(.caption)
                    .foregroundStyle(.link)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
    }
    
    private func saveTokenAutomatically(_ newToken: String) {
        guard hasLoadedToken else { return }
        
        let trimmedToken = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedToken.isEmpty {
            clearToken()
            return
        }
        
        // Only save if it's different from what's potentially already saved (optimization)
        let currentSaved = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey)
        if currentSaved == trimmedToken {
            return
        }
        
        guard KeychainHelper.shared.save(trimmedToken, forKey: UserPreferences.tokenKeychainKey) else { return }
        
        notificationService.configure(token: trimmedToken)
        Task {
            await notificationService.fetchNotifications()
        }
    }
    
    private func clearToken() {
        token = ""
        _ = KeychainHelper.shared.delete(forKey: UserPreferences.tokenKeychainKey)
        notificationService.clearToken()
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
