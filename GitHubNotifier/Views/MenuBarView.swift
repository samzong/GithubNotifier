import SwiftUI

struct MenuBarView: View {
    @Environment(NotificationService.self) private var notificationService
    @State private var filterOptions = FilterOptions()
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()

            if notificationService.isLoading && notificationService.notifications.isEmpty {
                loadingView
            } else if let error = notificationService.errorMessage {
                errorView(error)
            } else if notificationService.notifications.isEmpty {
                emptyView
            } else {
                notificationList
            }

            Divider()

            footerSection
        }
        .frame(width: 400, height: 600)
    }

    private var headerSection: some View {
        HStack {
            Text("menubar.title".localized)
                .font(.headline)

            Spacer()

            Button(action: {
                Task {
                    await notificationService.fetchNotifications()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(notificationService.isLoading)

            Button(action: {
                showingSettings.toggle()
            }) {
                Image(systemName: "gear")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingSettings) {
                SettingsView()
                    .environment(notificationService)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notificationService.notifications) { notification in
                    NotificationRow(
                        notification: notification,
                        prState: notificationService.getPRState(for: notification),
                        issueState: notificationService.getIssueState(for: notification),
                        onOpen: {
                            openNotification(notification)
                        },
                        onMarkAsRead: {
                            Task {
                                await notificationService.markAsRead(notification: notification)
                            }
                        }
                    )

                    if notification.id != notificationService.notifications.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button("menubar.mark.all.read".localized) {
                Task {
                    await notificationService.markAllAsRead()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(notificationService.notifications.isEmpty)

            Menu {
                Toggle("filter.only.merged.prs".localized, isOn: $filterOptions.onlyMergedPRs)
                Toggle("filter.only.closed.issues".localized, isOn: $filterOptions.onlyClosedIssues)

                Divider()

                Button("filter.apply.smart.mark".localized) {
                    notificationService.filterOptions = filterOptions
                    Task {
                        await notificationService.smartMarkAsRead()
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text("menubar.smart.mark".localized)
            }
            .disabled(notificationService.notifications.isEmpty)

            Spacer()

            Button(action: {
                if let url = URL(string: "https://github.com/notifications") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "arrow.up.forward.square")
            }
            .buttonStyle(.plain)
            .help("menubar.open.in.browser".localized)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("menubar.loading".localized)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("menubar.empty.title".localized)
                .font(.headline)
            Text("menubar.empty.subtitle".localized)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("menubar.error.title".localized)
                .font(.headline)
            Text(error)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            Button("menubar.retry".localized) {
                Task {
                    await notificationService.fetchNotifications()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func openNotification(_ notification: GitHubNotification) {
        if let urlString = notification.subject.url,
           let url = URL(string: urlString.replacingOccurrences(of: "api.github.com/repos", with: "github.com")) {
            NSWorkspace.shared.open(url)

            Task {
                await notificationService.markAsRead(notification: notification)
            }
        }
    }
}
