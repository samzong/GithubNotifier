import GitHubNotifierCore
import Sparkle
import SwiftUI

struct SettingsView: View {
    let updater: SPUUpdater
    @Environment(NotificationService.self) private var notificationService
    @AppStorage("settings.selectedTab") private var selectedTab: SettingsTab = .general

    private let settingsWidth: CGFloat = 640
    private let settingsHeight: CGFloat = 540

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab(settingsWidth: settingsWidth)
                .environment(notificationService)
                .tabItem {
                    Label("settings.tab.general".localized, systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            AccountTab(settingsWidth: settingsWidth)
                .environment(notificationService)
                .tabItem {
                    Label("settings.tab.account".localized, systemImage: "person.crop.circle")
                }
                .tag(SettingsTab.account)

            RulesTab(settingsWidth: settingsWidth)
                .tabItem {
                    Label("settings.tab.rules".localized, systemImage: "slider.horizontal.3")
                }
                .tag(SettingsTab.rules)

            AITab(settingsWidth: settingsWidth)
                .tabItem {
                    Label("settings.tab.ai".localized, systemImage: "sparkles")
                }
                .tag(SettingsTab.aiFeatures)

            AboutTab(updater: updater, settingsWidth: settingsWidth)
                .tabItem {
                    Label("settings.tab.about".localized, systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: settingsWidth, height: settingsHeight)
        .padding()
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case account
    case rules
    case aiFeatures = "ai"
    case about

    var id: String { rawValue }
}
