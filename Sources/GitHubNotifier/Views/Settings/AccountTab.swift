import GitHubNotifierCore
import SwiftUI

enum AuthMethod: String, CaseIterable {
    case classic
    case finegrained
    case webAuth

    var displayName: String {
        switch self {
        case .classic:
            "Classic Token"
        case .finegrained:
            "Fine-grained"
        case .webAuth:
            "Web Auth"
        }
    }

    var generateURL: URL? {
        switch self {
        case .classic:
            URL(string: "https://github.com/settings/tokens/new?scopes=notifications,read:user,repo&description=GitHubNotifier")
        case .finegrained:
            URL(string: "https://github.com/settings/personal-access-tokens/new")
        case .webAuth:
            nil
        }
    }

    var generateButtonText: String {
        switch self {
        case .classic:
            "account.generate.classic".localized
        case .finegrained:
            "account.generate.finegrained".localized
        case .webAuth:
            ""
        }
    }

    var isAvailable: Bool {
        switch self {
        case .classic, .finegrained:
            true
        case .webAuth:
            false
        }
    }
}

struct AccountTab: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(ActivityService.self) private var activityService

    @State private var token = ""
    @State private var hasLoadedToken = false
    @State private var selectedAuthMethod: AuthMethod = .classic
    @State private var showClearConfirmation = false
    @FocusState private var isTokenFocused: Bool

    let settingsWidth: CGFloat

    var body: some View {
        Form {
            // Section 1: Connection Status
            Section {
                connectionStatusView
            } header: {
                Text("account.status.header".localized)
            }

            // Section 2: Authentication Method (Unified)
            Section {
                authMethodView
            } header: {
                Text("account.auth.header".localized)
            }

            // Section 3: Token Input
            Section {
                tokenInputView
            } header: {
                Text("settings.token.title".localized)
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

    // MARK: - Connection Status View

    @ViewBuilder private var connectionStatusView: some View {
        HStack(spacing: 10) {
            if let user = notificationService.currentUser {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                Text("account.status.connected".localized)
                    .foregroundStyle(.secondary)
                Text("@\(user.login)")
                    .fontWeight(.medium)
            } else if token.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
                Text("account.status.not_configured".localized)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text("account.status.verifying".localized)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Auth Method View (Unified with Tabs)

    @ViewBuilder private var authMethodView: some View {
        // Tab Picker
        Picker("", selection: $selectedAuthMethod) {
            ForEach(AuthMethod.allCases, id: \.self) { method in
                Text(method.displayName).tag(method)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        // Content based on selected method
        if selectedAuthMethod.isAvailable {
            // Permissions for selected method
            permissionsForMethod(selectedAuthMethod)

            // Generate Button
            if let url = selectedAuthMethod.generateURL {
                HStack {
                    Spacer()
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text(selectedAuthMethod.generateButtonText)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        } else {
            // Coming Soon placeholder
            comingSoonView
        }
    }

    @ViewBuilder private var comingSoonView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text("account.webauth.coming_soon".localized)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("account.webauth.description".localized)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private func permissionsForMethod(_ method: AuthMethod) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch method {
            case .classic:
                PermissionRow(
                    scope: "notifications",
                    description: "account.perm.notifications",
                    level: .required
                )
                PermissionRow(
                    scope: "read:user",
                    description: "account.perm.read_user",
                    level: .required
                )
                PermissionRow(
                    scope: "repo",
                    description: "account.perm.repo",
                    level: .recommended
                )

            case .finegrained:
                PermissionRow(
                    scope: "Notifications",
                    description: "account.perm.fg.notifications",
                    level: .required
                )
                PermissionRow(
                    scope: "Email addresses",
                    description: "account.perm.fg.email",
                    level: .required
                )
                PermissionRow(
                    scope: "Contents",
                    description: "account.perm.fg.repo",
                    level: .recommended
                )

            case .webAuth:
                EmptyView()
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Token Input View

    @ViewBuilder private var tokenInputView: some View {
        HStack(spacing: 8) {
            SecureField("", text: $token, prompt: Text("ghp_xxxx..."))
                .focused($isTokenFocused)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .onSubmit {
                    saveTokenAutomatically(token)
                }
                .onChange(of: isTokenFocused) { _, focused in
                    if !focused {
                        saveTokenAutomatically(token)
                    }
                }

            if !token.isEmpty {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("account.token.clear".localized)
            }
        }
        .confirmationDialog(
            "account.token.clear.title".localized,
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("account.token.clear.confirm".localized, role: .destructive) {
                clearToken()
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("account.token.clear.message".localized)
        }
    }

    // MARK: - Token Management

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
        activityService.configure(token: trimmedToken)
        Task {
            await notificationService.fetchNotifications()
            await notificationService.fetchCurrentUser()
            await activityService.fetchMyItems()
        }
    }

    private func clearToken() {
        token = ""
        _ = KeychainHelper.shared.delete(forKey: UserPreferences.tokenKeychainKey)
        notificationService.clearToken()
        activityService.clearToken()
    }
}

#Preview {
    AccountTab(settingsWidth: 450)
}
