import GitHubNotifierCore
import SwiftUI

struct HeaderView: View {
    @Binding var selectedTab: MenuBarMainTab
    let unreadCount: Int
    let isLoading: Bool
    let currentUserLogin: String?

    let onRefresh: () async -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                TabButton(
                    title: "menubar.tab.activity".localized,
                    icon: "list.bullet.rectangle",
                    isSelected: selectedTab == .activity,
                    action: { selectedTab = .activity }
                )

                TabButton(
                    title: "menubar.tab.notifications".localized,
                    icon: "bell",
                    isSelected: selectedTab == .notifications,
                    showDot: unreadCount > 0,
                    action: { selectedTab = .notifications }
                )
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await onRefresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(isLoading)

                Divider()
                    .frame(height: 16)

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
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
}
