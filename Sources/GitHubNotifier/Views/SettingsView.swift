import GitHubNotifierCore
import Sparkle
import SwiftUI

struct SettingsView: View {
    let updater: SPUUpdater
    let oauthClientID: String
    @Environment(SettingsNavigationState.self) private var settingsNavigationState
    @Environment(NotificationService.self) private var notificationService
    @AppStorage("settings.selectedTab") private var selectedTab: SettingsTab = .general
    @State private var tabSelection = SettingsTabSelection(savedTab: .general)

    private let settingsWidth: CGFloat = 700
    private let settingsHeight: CGFloat = 440
    private let sidebarWidth: CGFloat = 176
    private let contentWidth: CGFloat = 500

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detail
                .frame(width: settingsWidth - sidebarWidth - 1, height: settingsHeight)
        }
        .frame(width: settingsWidth, height: settingsHeight)
        .liquidWindowBackground()
        .onAppear {
            tabSelection.restoreSavedTab(selectedTab)
            applyPendingTabIfNeeded()
        }
        .onChange(of: settingsNavigationState.pendingTab) { _, pendingTab in
            guard pendingTab != nil else { return }
            applyPendingTabIfNeeded()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            sidebarHeader

            VStack(spacing: 5) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarButton(
                        tab: tab,
                        isSelected: tabSelection.displayedTab == tab,
                        action: {
                            tabSelection.userSelectedTab(tab)
                            selectedTab = tabSelection.savedTab
                        }
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .frame(width: sidebarWidth, height: settingsHeight, alignment: .topLeading)
        .background(.bar)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 9) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("GitHub Notifier")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text("settings.title".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder private var detail: some View {
        switch selectedTabBinding.wrappedValue {
        case .general:
            GeneralTab(settingsWidth: contentWidth)
                .environment(notificationService)

        case .account:
            AccountTab(oauthClientID: oauthClientID, settingsWidth: contentWidth)
                .environment(notificationService)

        case .rules:
            RulesTab(settingsWidth: contentWidth)

        case .aiFeatures:
            AITab(settingsWidth: contentWidth)

        case .about:
            AboutTab(updater: updater, settingsWidth: contentWidth)
        }
    }

    private var selectedTabBinding: Binding<SettingsTab> {
        Binding(
            get: { tabSelection.displayedTab },
            set: { newValue in
                tabSelection.userSelectedTab(newValue)
                selectedTab = tabSelection.savedTab
            }
        )
    }

    private func applyPendingTabIfNeeded() {
        tabSelection.applyPendingTab(settingsNavigationState.consumePendingTab())
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case account
    case rules
    case aiFeatures = "ai"
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            "settings.tab.general".localized
        case .account:
            "settings.tab.account".localized
        case .rules:
            "settings.tab.rules".localized
        case .aiFeatures:
            "settings.tab.ai".localized
        case .about:
            "settings.tab.about".localized
        }
    }

    var icon: String {
        switch self {
        case .general:
            "gearshape"
        case .account:
            "person.crop.circle"
        case .rules:
            "slider.horizontal.3"
        case .aiFeatures:
            "sparkles"
        case .about:
            "info.circle"
        }
    }
}

private struct SettingsSidebarButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)

                Text(tab.title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))

                Spacer()
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
