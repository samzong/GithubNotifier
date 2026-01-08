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
    @State private var latestVersion: String?
    @State private var latestReleaseURL: String?
    @State private var isCheckingUpdate = false
    @State private var updateCheckResult: UpdateCheckResult = .none
    private let settingsWidth: CGFloat = 480
    private let repoOwner = "samzong"
    private let repoName = "GitHubNotifier"

    private enum UpdateCheckResult {
        case none
        case upToDate
        case newVersionAvailable
        case error(String)
    }
    
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

            aboutSettings
                .tabItem {
                    Label("settings.tab.about".localized, systemImage: "info.circle")
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

    private var aboutSettings: some View {
        VStack(spacing: 20) {
            Spacer()

            // App Logo placeholder
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            // App Name
            Text("GitHubNotifier")
                .font(.title)
                .fontWeight(.bold)

            Spacer().frame(height: 10)

            // Links Section
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/\(repoOwner)/\(repoName)")!) {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text("about.github.repo".localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(repoOwner)/\(repoName)")
                            .foregroundStyle(.blue)
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "https://github.com/\(repoOwner)/\(repoName)/issues/new")!) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundStyle(.blue)
                        Text("about.report.issue".localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            // Version Section
            VStack(spacing: 8) {
                HStack {
                    Text("about.version".localized)
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(action: checkForUpdates) {
                        if isCheckingUpdate {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("about.check.update".localized)
                        }
                    }
                    .disabled(isCheckingUpdate)
                }

                // Update check result feedback
                switch updateCheckResult {
                case .upToDate:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("about.up.to.date".localized)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .font(.callout)
                case .newVersionAvailable:
                    if let latestVersion = latestVersion {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                            Text("about.new.version".localized)
                            Text("v\(latestVersion)")
                                .fontWeight(.medium)
                            Spacer()
                            if let url = latestReleaseURL, let releaseURL = URL(string: url) {
                                Link("about.download".localized, destination: releaseURL)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.blue)
                    }
                case .error(let message):
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(message)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .font(.callout)
                case .none:
                    EmptyView()
                }
            }
            .padding(.horizontal, 40)

            // License
            HStack {
                Text("about.license".localized)
                Text("MIT")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(width: settingsWidth, height: 380)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }


    private func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.replacingOccurrences(of: "v", with: "").split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.replacingOccurrences(of: "v", with: "").split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(parts1.count, parts2.count) {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 != p2 { return p1 > p2 ? 1 : -1 }
        }
        return 0
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        latestVersion = nil
        latestReleaseURL = nil
        updateCheckResult = .none

        Task {
            defer { isCheckingUpdate = false }

            guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
                await MainActor.run {
                    updateCheckResult = .error("about.error.invalid.url".localized)
                }
                return
            }

            var request = URLRequest(url: url)
            request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.addValue("GitHubNotifier", forHTTPHeaderField: "User-Agent")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                // Check for 404 (no releases yet)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    await MainActor.run {
                        updateCheckResult = .upToDate
                    }
                    return
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tagName = json["tag_name"] as? String,
                   let htmlUrl = json["html_url"] as? String {
                    let cleanVersion = tagName.replacingOccurrences(of: "v", with: "")
                    await MainActor.run {
                        self.latestVersion = cleanVersion
                        self.latestReleaseURL = htmlUrl

                        if compareVersions(cleanVersion, appVersion) > 0 {
                            updateCheckResult = .newVersionAvailable
                        } else {
                            updateCheckResult = .upToDate
                        }
                    }
                } else {
                    await MainActor.run {
                        updateCheckResult = .error("about.error.parse".localized)
                    }
                }
            } catch {
                await MainActor.run {
                    updateCheckResult = .error("about.error.network".localized)
                }
            }
        }
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
