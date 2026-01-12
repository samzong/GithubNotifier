import GitHubNotifierCore
import SwiftUI

struct HeaderView: View {
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
                    action: { selectedTab = .notifications }
                )

                TabButton(
                    title: "menubar.tab.activity".localized,
                    icon: "list.bullet.rectangle",
                    isSelected: selectedTab == .activity,
                    action: { selectedTab = .activity }
                )

                TabButton(
                    title: "menubar.tab.search".localized,
                    icon: "magnifyingglass",
                    isSelected: selectedTab == .search,
                    action: { selectedTab = .search }
                )
            }

            Spacer()

            if selectedTab != .search {
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
        }
        .frame(height: 48)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
    }
}
