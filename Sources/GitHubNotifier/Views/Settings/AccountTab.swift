import AppKit
import GitHubNotifierCore
import SwiftUI

// MARK: - Device Flow UI State

private enum DeviceFlowState: Equatable {
    case idle
    case requestingCode
    case showingCode(DeviceCodeResponse, secondsRemaining: Int)
    case success(username: String)
    case error(String)

    static func == (lhs: DeviceFlowState, rhs: DeviceFlowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.requestingCode, .requestingCode):
            true
        case let (.showingCode(lhsCode, lhsSeconds), .showingCode(rhsCode, rhsSeconds)):
            lhsCode.userCode == rhsCode.userCode && lhsSeconds == rhsSeconds
        case let (.success(lhsUser), .success(rhsUser)):
            lhsUser == rhsUser
        case let (.error(lhsMsg), .error(rhsMsg)):
            lhsMsg == rhsMsg
        default:
            false
        }
    }
}

struct AccountTab: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(ActivityService.self) private var activityService

    @State private var deviceFlowState: DeviceFlowState = .idle
    @State private var pollingTask: Task<Void, Never>?
    @State private var countdownTask: Task<Void, Never>?

    private let deviceFlowService = GitHubDeviceFlowService()

    let oauthClientID: String
    let settingsWidth: CGFloat

    var body: some View {
        Form {
            Section {
                webAuthView
            } header: {
                Text("account.auth.header".localized)
            }
        }
        .formStyle(.grouped)
        .frame(width: settingsWidth)
        .onAppear {
            Task {
                if notificationService.isAuthenticated, let user = notificationService.currentUser {
                    deviceFlowState = .success(username: user.login)
                } else if notificationService.isAuthenticated {
                    await notificationService.fetchCurrentUser()
                    if let user = notificationService.currentUser {
                        deviceFlowState = .success(username: user.login)
                    }
                }
            }
        }
        .onDisappear {
            cancelPolling()
        }
    }

    // MARK: - Web Auth View

    @ViewBuilder private var webAuthView: some View {
        switch deviceFlowState {
        case .idle:
            webAuthIdleView
        case .requestingCode:
            webAuthRequestingView
        case let .showingCode(response, seconds):
            webAuthCodeView(response: response, secondsRemaining: seconds)
        case let .success(username):
            webAuthSuccessView(username: username)
        case let .error(message):
            webAuthErrorView(message: message)
        }
    }

    @ViewBuilder private var webAuthIdleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.key.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text("account.webauth.description".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("account.webauth.signin".localized) {
                startDeviceFlow()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    @ViewBuilder private var webAuthRequestingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("account.webauth.requesting".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    @ViewBuilder private func webAuthCodeView(response: DeviceCodeResponse, secondsRemaining: Int) -> some View {
        VStack(spacing: 16) {
            Text("account.webauth.code_prompt".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(response.userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .tracking(4)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .liquidGlassSurface(cornerRadius: 10)

            HStack(spacing: 8) {
                Button("account.webauth.open_browser".localized) {
                    openVerificationURL(response: response)
                }
                .buttonStyle(.borderedProminent)

                Button("account.webauth.copy_code".localized) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(response.userCode, forType: .string)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("account.webauth.waiting".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(String(format: "account.webauth.expires_in".localized, formatSeconds(secondsRemaining)))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button("common.cancel".localized) {
                cancelPolling()
                deviceFlowState = .idle
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder private func webAuthSuccessView(username: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(username)")
                    .font(.headline)

                Text("account.webauth.signed_in".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = URL(string: "https://github.com/settings/apps/authorizations") {
                Link("account.webauth.manage_apps".localized, destination: url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("account.webauth.signout".localized) {
                signOut()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder private func webAuthErrorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("account.webauth.retry".localized) {
                deviceFlowState = .idle
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Device Flow Logic

    private func startDeviceFlow() {
        deviceFlowState = .requestingCode

        pollingTask = Task { @MainActor in
            do {
                let codeResponse = try await deviceFlowService.requestDeviceCode(clientId: oauthClientID)

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(codeResponse.userCode, forType: .string)

                openVerificationURL(response: codeResponse)

                deviceFlowState = .showingCode(codeResponse, secondsRemaining: codeResponse.expiresIn)
                startCountdown(expiresIn: codeResponse.expiresIn)

                var interval = codeResponse.interval
                let clock = ContinuousClock()
                let deadline = clock.now + .seconds(codeResponse.expiresIn)

                while !Task.isCancelled, clock.now < deadline {
                    try await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { break }

                    let result = try await deviceFlowService.pollForToken(
                        clientId: oauthClientID,
                        deviceCode: codeResponse.deviceCode
                    )

                    switch result {
                    case let .token(tokenResponse):
                        await AuthStore.shared.saveToken(tokenResponse.accessToken)
                        notificationService.configure(token: tokenResponse.accessToken)
                        activityService.configure(token: tokenResponse.accessToken)
                        await notificationService.fetchCurrentUser()
                        let username = notificationService.currentUser?.login ?? ""
                        countdownTask?.cancel()
                        deviceFlowState = .success(username: username)
                        return
                    case .pending:
                        break
                    case let .slowDown(newInterval):
                        interval = newInterval
                    case let .failed(err):
                        countdownTask?.cancel()
                        deviceFlowState = .error(err.localizedDescription)
                        return
                    }
                }

                if !Task.isCancelled {
                    countdownTask?.cancel()
                    deviceFlowState = .error(DeviceFlowError.expiredToken.localizedDescription)
                }
            } catch is CancellationError {
                // User cancelled
            } catch {
                deviceFlowState = .error(DeviceFlowError.networkError(underlying: error).localizedDescription)
            }
        }
    }

    private func startCountdown(expiresIn: Int) {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            var remaining = expiresIn
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                if case let .showingCode(resp, _) = deviceFlowState {
                    deviceFlowState = .showingCode(resp, secondsRemaining: remaining)
                }
            }
        }
    }

    private func cancelPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func signOut() {
        cancelPolling()
        Task {
            await AuthStore.shared.clearToken()
        }
        notificationService.clearToken()
        activityService.clearToken()
        deviceFlowState = .idle
    }

    private func openVerificationURL(response: DeviceCodeResponse) {
        let urlString = response.verificationUriComplete ?? response.verificationUri
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    AccountTab(oauthClientID: "preview-client-id", settingsWidth: 450)
}
