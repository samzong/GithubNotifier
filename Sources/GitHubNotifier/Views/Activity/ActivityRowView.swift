import GitHubNotifierCore
import SwiftUI

struct ActivityRowView: View {
    let item: SearchResultItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                AvatarView(
                    urlString: item.authorAvatarUrl ?? "https://github.com/\(item.repositoryOwner).png",
                    size: 20
                )
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.repositoryName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text("#\(item.number)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        Spacer()

                        TimeAgoText(date: item.updatedAt)

                        if let ciStatus = item.ciStatus {
                            CIStatusBadge(status: ciStatus)
                        }
                    }

                    Text(item.title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                itemIcon
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var itemIcon: some View {
        let (iconName, color) = iconInfo
        Image(systemName: iconName)
            .font(.system(size: 16))
            .foregroundStyle(color)
    }

    private var iconInfo: (String, Color) {
        switch item.itemType {
        case .pullRequest:
            switch item.state.uppercased() {
            case "MERGED":
                ("arrow.triangle.merge", .purple)
            case "CLOSED":
                ("xmark.circle", .red)
            case "DRAFT":
                ("circle.dashed", .secondary)
            default:
                ("arrow.triangle.pull", .green)
            }
        case .issue:
            switch item.state.uppercased() {
            case "CLOSED":
                ("checkmark.circle", .purple)
            default:
                ("circle.dotted", .green)
            }
        }
    }
}
