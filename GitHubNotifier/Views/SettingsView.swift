import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var notificationService: NotificationService
    @AppStorage(UserPreferences.refreshIntervalKey) private var refreshInterval: Double = 60
    @AppStorage(UserPreferences.showNotificationCountKey) private var showNotificationCount = true
    @State private var token = ""
    @State private var showingTokenSaved = false
    @State private var viewID = UUID()

    private var isLoggedIn: Bool {
        guard let savedToken = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey) else {
            return false
        }
        return !savedToken.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settings.title".localized)
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("settings.github.token.title".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("settings.github.connected".localized)
                            .foregroundColor(.green)
                    }

                    if let savedToken = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey),
                       savedToken.count > 10 {
                        Text("Token: \(String(savedToken.prefix(10)))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("settings.github.logout".localized) {
                        logout()
                    }
                    .buttonStyle(.bordered)
                } else {
                    SecureField("ghp_...", text: $token)
                        .textFieldStyle(.roundedBorder)

                    Button("settings.github.save.token".localized) {
                        saveToken()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(token.isEmpty)

                    if showingTokenSaved {
                        Text("settings.github.token.saved".localized)
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Text("settings.github.token.hint".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "settings.refresh.interval".localized, Int(refreshInterval)))
                    .font(.subheadline)

                Slider(value: $refreshInterval, in: 30...300, step: 30)
            }

            Toggle("settings.show.notification.count".localized, isOn: $showNotificationCount)

            Spacer()
        }
        .padding()
        .frame(width: 400, height: 350)
        .id(viewID)
    }

    private func saveToken() {
        if KeychainHelper.shared.save(token, forKey: UserPreferences.tokenKeychainKey) {
            notificationService.configure(token: token)
            showingTokenSaved = true
            viewID = UUID()

            Task {
                await notificationService.fetchNotifications()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingTokenSaved = false
            }
        }
    }

    private func logout() {
        _ = KeychainHelper.shared.delete(forKey: UserPreferences.tokenKeychainKey)
        token = ""
        viewID = UUID()
    }
}
