import GitHubNotifierCore
import SwiftUI

struct HeaderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabAnimation

    @Binding var selectedTab: MenuBarMainTab
    let visibleTabs: [MenuBarMainTab]
    let unreadCount: Int
    let currentUserLogin: String?

    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            tabGroup

            Spacer()

            settingsMenu
        }
        .frame(height: 52)
        .padding(.horizontal, 12)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: selectedTab
        )
    }

    @ViewBuilder private var tabGroup: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 4) {
                tabs
            }
        } else {
            tabs
        }
    }

    private var tabs: some View {
        HStack(spacing: 3) {
            ForEach(visibleTabs, id: \.self) { tab in
                TabButton(
                    title: tab.titleKey.localized,
                    icon: tab.iconName,
                    isSelected: selectedTab == tab,
                    showDot: tab == .notifications && unreadCount > 0,
                    namespace: tabAnimation,
                    action: { switchTab(to: tab) }
                )
            }
        }
        .padding(4)
        .liquidGlassSurface(cornerRadius: 15, interactive: true)
    }

    private var settingsMenu: some View {
        Menu {
            if let login = currentUserLogin {
                Text("settings.user".localized + ": @\(login)")
            }

            Divider()

            Button {
                onOpenSettings()
            } label: {
                Label("settings.title".localized, systemImage: "gearshape")
            }

            Divider()

            Button(role: .destructive) {
                onQuit()
            } label: {
                Label("menubar.quit".localized, systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 32)
                .liquidGlassSurface(cornerRadius: 11, interactive: true)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .liquidGlassIconButtonStyle()
        .help("settings.title".localized)
    }

    private func switchTab(to tab: MenuBarMainTab) {
        guard selectedTab != tab else { return }
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }
    }
}
