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
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("#\(item.number.formatted(.number.grouping(.never)))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        TimeAgoText(date: item.updatedAt)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let ciStatus = item.ciStatus {
                            CIStatusBadge(status: ciStatus)
                        }
                    }

                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.listRow)
    }
}
