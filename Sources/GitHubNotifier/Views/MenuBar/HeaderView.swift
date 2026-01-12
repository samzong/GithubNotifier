import GitHubNotifierCore
import SwiftUI

struct HeaderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabAnimation

    @Binding var selectedTab: MenuBarMainTab
    let unreadCount: Int
    let currentUserLogin: String?

    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    init(
        selectedTab: Binding<MenuBarMainTab>,
        unreadCount: Int,
        currentUserLogin: String?,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self._selectedTab = selectedTab
        self.unreadCount = unreadCount
        self.currentUserLogin = currentUserLogin
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                TabButton(
                    title: "menubar.tab.notifications".localized,
                    icon: "bell",
                    isSelected: selectedTab == .notifications,
                    showDot: unreadCount > 0,
                    namespace: tabAnimation,
                    action: { switchTab(to: .notifications) }
                )

                TabButton(
                    title: "menubar.tab.activity".localized,
                    icon: "list.bullet.rectangle",
                    isSelected: selectedTab == .activity,
                    namespace: tabAnimation,
                    action: { switchTab(to: .activity) }
                )

                TabButton(
                    title: "menubar.tab.search".localized,
                    icon: "magnifyingglass",
                    isSelected: selectedTab == .search,
                    namespace: tabAnimation,
                    action: { switchTab(to: .search) }
                )
            }

            Spacer()

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
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: selectedTab
        )
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
