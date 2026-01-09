import AppKit
import GitHubNotifierCore
import SwiftUI

struct NotificationListView: View {
    @Environment(NotificationService.self) private var service

    let subTab: MenuBarSubTab
    let onGroupTap: (NotificationGroup) -> Void

    var body: some View {
        Group {
            if service.isLoading, service.notifications.isEmpty {
                loadingView
            } else if let error = service.errorMessage {
                errorView(error)
            } else if filteredGroups.isEmpty {
                emptyView
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredGroups) { group in
                    NotificationRowView(
                        group: group,
                        prState: service.getPRState(for: group.latestNotification),
                        issueState: service.getIssueState(for: group.latestNotification)
                    ) {
                        onGroupTap(group)
                    }

                    if group.id != filteredGroups.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("menubar.loading".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(error)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("menubar.no_items".localized)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var filteredGroups: [NotificationGroup] {
        switch subTab {
        case .all:
            service.groupedNotifications
        case .issues:
            service.groupedNotifications.filter { $0.latestNotification.notificationType == .issue }
        case .prs:
            service.groupedNotifications.filter { $0.latestNotification.notificationType == .pullRequest }
        }
    }
}
