import SwiftUI
import AppKit

struct NotificationRow: View {
    let notification: GitHubNotification
    let prState: PRState?
    let issueState: IssueState?
    let onOpen: () -> Void
    let onMarkAsRead: () -> Void

    @State private var isHovering = false
    @State private var showingPreview = false
    @State private var bodyPreview: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(notification.displaySubtitle)
                    .font(.callout)
                    .foregroundColor(.secondary)

                Text(notification.updatedAt.timeAgo())
                    .font(.caption)
                    .foregroundColor(.secondary)

                if showingPreview, let preview = bodyPreview {
                    Text(preview.markdownPreview.truncate(to: 150))
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .padding(.leading, 8)
                        .overlay(
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 2),
                            alignment: .leading
                        )
                }
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onMarkAsRead) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("notification.mark.as.read".localized)

                    Button(action: {
                        showingPreview.toggle()
                    }) {
                        Image(systemName: showingPreview ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showingPreview ? "notification.hide.preview".localized : "notification.show.preview".localized)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovering ? Color.notificationHover : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onOpen()
        }
        .task {
            if showingPreview && bodyPreview == nil {
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch notification.notificationType {
        case .pullRequest:
            if let state = prState {
                if let image = templateIcon(named: state.iconAssetName, size: 20) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundColor(state.color)
                } else {
                    Image(systemName: state.icon)
                        .foregroundColor(state.color)
                }
            } else {
                if let assetName = notification.notificationType.iconAssetName,
                   let image = templateIcon(named: assetName, size: 20) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: notification.notificationType.icon)
                        .foregroundColor(.secondary)
                }
            }
        case .issue:
            if let state = issueState {
                if let image = templateIcon(named: state.iconAssetName, size: 20) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundColor(state.color)
                } else {
                    Image(systemName: state.icon)
                        .foregroundColor(state.color)
                }
            } else {
                if let assetName = notification.notificationType.iconAssetName,
                   let image = templateIcon(named: assetName, size: 20) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: notification.notificationType.icon)
                        .foregroundColor(.secondary)
                }
            }
        default:
            Image(systemName: notification.notificationType.icon)
                .foregroundColor(.secondary)
        }
    }

    private func templateIcon(named name: String, size: CGFloat) -> NSImage? {
        guard let image = NSImage(named: name) else {
            return nil
        }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }
}

#Preview {
    VStack {
        NotificationRow(
            notification: GitHubNotification(
                id: "1",
                unread: true,
                reason: "mention",
                updatedAt: Date().addingTimeInterval(-3600),
                lastReadAt: nil,
                subject: GitHubNotification.Subject(
                    title: "Fix: Update authentication flow",
                    url: "https://api.github.com/repos/owner/repo/issues/123",
                    latestCommentUrl: nil,
                    type: "PullRequest"
                ),
                repository: GitHubNotification.Repository(
                    id: 1,
                    name: "repo",
                    fullName: "owner/repo",
                    htmlUrl: "https://github.com/owner/repo",
                    owner: GitHubNotification.Repository.Owner(login: "owner")
                ),
                url: "https://api.github.com/notifications/threads/1"
            ),
            prState: .open,
            issueState: nil,
            onOpen: {},
            onMarkAsRead: {}
        )
    }
    .frame(width: 400)
}
