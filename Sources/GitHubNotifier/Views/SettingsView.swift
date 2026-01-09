import GitHubNotifierCore
import Sparkle
import SwiftUI

struct SettingsView: View {
    let updater: SPUUpdater
    @Environment(NotificationService.self) private var notificationService

    private let settingsWidth: CGFloat = 520
    private let settingsHeight: CGFloat = 360

    var body: some View {
        TabView {
            GeneralTab(settingsWidth: settingsWidth)
                .environment(notificationService)
                .tabItem {
                    Label("settings.tab.general".localized, systemImage: "gearshape")
                }

            AccountTab(settingsWidth: settingsWidth)
                .environment(notificationService)
                .tabItem {
                    Label("settings.tab.account".localized, systemImage: "person.crop.circle")
                }

            RulesTab(settingsWidth: settingsWidth)
                .tabItem {
                    Label("settings.tab.rules".localized, systemImage: "slider.horizontal.3")
                }

            AITab(settingsWidth: settingsWidth)
                .tabItem {
                    Label("settings.tab.ai".localized, systemImage: "sparkles")
                }

            AboutTab(updater: updater, settingsWidth: settingsWidth)
                .tabItem {
                    Label("settings.tab.about".localized, systemImage: "info.circle")
                }
        }
        .frame(width: settingsWidth, height: settingsHeight)
        .padding()
    }
}
