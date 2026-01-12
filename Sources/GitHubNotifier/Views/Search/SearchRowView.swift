//
//  SearchRowView.swift
//  GitHubNotifier
//
//  Row view for displaying a search result item.
//

import GitHubNotifierCore
import SwiftUI

struct SearchRowView: View {
    let item: SearchResultItem

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: item.itemType == .pullRequest ? "arrow.triangle.pull" : "circle.dotted")
                .font(.system(size: 14))
                .foregroundStyle(item.itemType == .pullRequest ? .purple : .green)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text("\(item.repositoryOwner)/\(item.repositoryName)")
                        .foregroundStyle(.secondary)

                    Text("#\(item.number)")
                        .foregroundStyle(.tertiary)

                    if let ciStatus = item.ciStatus {
                        CIStatusBadge(status: ciStatus)
                    }
                }
                .font(.caption)
            }

            Spacer()

            // State badge
            Text(item.state)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(stateColor.opacity(0.15))
                .foregroundStyle(stateColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var stateColor: Color {
        switch item.state.uppercased() {
        case "OPEN":
            .green
        case "MERGED":
            .purple
        case "CLOSED":
            .red
        default:
            .secondary
        }
    }
}
