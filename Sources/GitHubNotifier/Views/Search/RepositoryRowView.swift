//
//  RepositoryRowView.swift
//  GitHubNotifier
//
//

import GitHubNotifierCore
import SwiftUI

struct RepositoryRowView: View {
    let repository: RepositorySearchItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: repository.isPrivate ? "lock.fill" : "folder")
                    .font(.system(size: 16))
                    .foregroundStyle(repository.isFork ? .secondary : .primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repository.fullName)
                        .font(.headline)
                        .lineLimit(1)

                    if let description = repository.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        if let language = repository.language {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(languageColor(for: language))
                                    .frame(width: 8, height: 8)
                                Text(language)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        Text(repository.createdAt.timeAgo())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star")
                    Text("\(repository.stargazerCount)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func languageColor(for language: String) -> Color {
        switch language.lowercased() {
        case "swift": Color.orange
        case "python": Color.blue
        case "javascript": Color.yellow
        case "typescript": Color.blue
        case "go": Color.cyan
        case "rust": Color.orange
        case "java": Color.brown
        case "c++", "cpp": Color.pink
        case "c": Color.gray
        case "ruby": Color.red
        case "shell", "bash": Color.green
        default: Color.gray
        }
    }
}
