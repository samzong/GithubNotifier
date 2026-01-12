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

    @ViewBuilder private var content: some View {
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
            searchService.resultsBySearchId[selectedSearchId] ?? []
        } else {
            // Show all aggregated items
            searchService.items
        }
    }

    // MARK: - Results List

    @ViewBuilder private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedItems) { item in
                    SearchRowView(item: item)
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

    @ViewBuilder private var emptyStateNoSearches: some View {
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

    @ViewBuilder private var emptyStateNoResults: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "tray",
            description: Text("Your saved searches returned no results.")
        )
    }

    @ViewBuilder private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading searches...")
            Spacer()
        }
    }
}

#Preview {
    SearchListView(selectedSearchId: .constant(nil)) { _ in }
        .environment(SearchService())
        .frame(width: 360, height: 400)
}
