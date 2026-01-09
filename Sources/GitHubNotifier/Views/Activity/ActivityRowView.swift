import GitHubNotifierCore
import SwiftUI

struct ActivityRowView: View {
    let item: SearchResultItem
    let onTap: () -> Void

    @State private var isHovering = false

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

                itemIcon
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovering ? Color(nsColor: .quinaryLabel) : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var itemIcon: some View {
        let (iconName, color) = iconInfo
        Image(systemName: iconName)
            .font(.body) // Was system(size: 16), .body is ~13pt but scales. Might need .title3 or .headline for 16pt equivalent.
            // Let's stick to semantic. .title3 is usually larger. .headline is semibold.
            // Using .system(size: 16) is acceptable for icons if specific alignment is needed, but .title3 is safer for dynamic type.
            // However, 16pt is a specific icon size. Let's use .title3 which is ~20pt or .headline ~17pt.
            // Actually, keep .system(size: 16) for icons as they often need fixed visual weight, or use .callout.
            // Let's use .system(size: 16) to ensure layout stability for now, or match text.
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
