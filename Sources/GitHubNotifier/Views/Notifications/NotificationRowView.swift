import GitHubNotifierCore
import SwiftUI

struct NotificationRowView: View {
    let group: NotificationGroup
    let prState: PRState?
    let issueState: IssueState?
    let onTap: () -> Void

    private var notification: GitHubNotification {
        group.latestNotification
    }

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                AvatarView(
                    urlString: "https://github.com/\(notification.repository.owner.login).png",
                    size: 24
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(notification.repository.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let number = notification.issueOrPRNumber {
                            Text("#\(number)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        if group.notifications.count > 1 {
                            Text("(\(group.notifications.count))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        TimeAgoText(date: notification.updatedAt)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(notification.subject.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 8)

                notificationIcon
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isHovering ? Color(nsColor: .quinaryLabel) : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var notificationIcon: some View {
        let (iconName, color) = iconInfo
        Image(systemName: iconName)
            .font(.system(size: 16))
            .foregroundStyle(color)
    }

    private var iconInfo: (String, Color) {
        if let prState {
            switch prState {
            case .merged:
                return ("arrow.triangle.merge", .purple)
            case .closed:
                return ("xmark.circle", .red)
            case .open:
                return ("arrow.triangle.pull", .green)
            case .draft:
                return ("circle.dashed", .secondary)
            }
        }

        if let issueState {
            switch issueState {
            case .closedCompleted:
                return ("checkmark.circle", .purple)
            case .closedNotPlanned:
                return ("xmark.circle", .secondary)
            case .open:
                return ("circle.dotted", .green)
            }
        }

        switch notification.notificationType {
        case .pullRequest:
            return ("arrow.triangle.pull", .green)
        case .issue:
            return ("circle.dotted", .green)
        default:
            return ("bell", .secondary)
        }
    }
}
