import GitHubNotifierCore
import SwiftUI

struct AccountTab: View {
    @Environment(NotificationService.self) private var notificationService

    @State private var token = ""
    @State private var hasLoadedToken = false
    @FocusState private var isTokenFocused: Bool

    let settingsWidth: CGFloat

    var body: some View {
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
        .onAppear {
            if let savedToken = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey) {
                token = savedToken
            }
            hasLoadedToken = true
        }
    }

    private func saveTokenAutomatically(_ newToken: String) {
        guard hasLoadedToken else { return }

        let trimmedToken = newToken.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedToken.isEmpty {
            clearToken()
            return
        }

        let currentSaved = KeychainHelper.shared.get(forKey: UserPreferences.tokenKeychainKey)
        if currentSaved == trimmedToken {
            return
        }

        guard KeychainHelper.shared.save(trimmedToken, forKey: UserPreferences.tokenKeychainKey) else { return }

        notificationService.configure(token: trimmedToken)
        Task {
            await notificationService.fetchNotifications()
            await notificationService.fetchCurrentUser()
        }
    }

    private func clearToken() {
        token = ""
        _ = KeychainHelper.shared.delete(forKey: UserPreferences.tokenKeychainKey)
        notificationService.clearToken()
    }
}
