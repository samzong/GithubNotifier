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
        HStack {
            HStack(spacing: 4) {
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
