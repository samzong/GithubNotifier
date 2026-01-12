//
//  SearchListView.swift
//  GitHubNotifier
//
//  Content view for the Search tab in the MenuBar.
//  Displays aggregated results from all enabled saved searches.
//

import GitHubNotifierCore
import SwiftUI

struct SearchListView: View {
    @Environment(SearchService.self) private var searchService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

    // Selected search filter passed from parent (nil = All)
    @Binding var selectedSearchId: UUID?

    let onItemTapped: (SearchResultItem) -> Void

    var body: some View {
        content
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        Group {
            if searchService.savedSearches.isEmpty {
                emptyStateNoSearches
            } else if displayedItems.isEmpty {
                if searchService.isLoading {
                    loadingView
                } else {
                    emptyStateNoResults
                }
            } else {
                resultsList
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: displayedItems.count)
    }

    // MARK: - Computed Properties

    private var displayedItems: [SearchResultItem] {
        if let selectedSearchId {
            // Filter by specific search
            return searchService.resultsBySearchId[selectedSearchId] ?? []
        } else {
            // Show all aggregated items
            return searchService.items
        }
    }

    // MARK: - Results List

    @ViewBuilder
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedItems) { item in
                    SearchResultRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { onItemTapped(item) }

                    if item.id != displayedItems.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    // MARK: - Empty States

    @ViewBuilder
    private var emptyStateNoSearches: some View {
        ContentUnavailableView {
            Label("No Saved Searches", systemImage: "magnifyingglass")
        } description: {
            Text("Create saved searches to aggregate results here.")
        } actions: {
            Button("Manage Searches") {
                WindowManager.shared.activeWindow = .searchManagement
                openWindow(id: "auxiliary")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var emptyStateNoResults: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "tray",
            description: Text("Your saved searches returned no results.")
        )
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading searches...")
            Spacer()
        }
    }
}

// MARK: - Result Row

private struct SearchResultRow: View {
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
            return .green
        case "MERGED":
            return .purple
        case "CLOSED":
            return .red
        default:
            return .secondary
        }
    }
}

#Preview {
    SearchListView(selectedSearchId: .constant(nil)) { _ in }
        .environment(SearchService())
        .frame(width: 360, height: 400)
}
