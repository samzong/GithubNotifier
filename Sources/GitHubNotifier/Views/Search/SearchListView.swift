//
//  SearchListView.swift
//  GitHubNotifier
//
//

import GitHubNotifierCore
import SwiftUI

struct SearchListView: View {
    @Environment(SearchService.self) private var searchService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow

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
            } else if searchService.isLoading, displayedItems.isEmpty, displayedRepositories.isEmpty {
                loadingView
            } else if selectedSearchId == nil {
                if displayedItems.isEmpty, displayedRepositories.isEmpty {
                    emptyStateNoResults
                } else {
                    combinedResultsList
                }
            } else if isRepositorySearch {
                repositoryContent
            } else {
                if displayedItems.isEmpty {
                    emptyStateNoResults
                } else {
                    resultsList
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: displayedItems.count)
    }

    // MARK: - Computed Properties

    private var isRepositorySearch: Bool {
        guard let selectedSearchId else { return false }
        return searchService.savedSearches.first { $0.id == selectedSearchId }?.type == .repository
    }

    private var displayedItems: [SearchResultItem] {
        if let selectedSearchId {
            searchService.resultsBySearchId[selectedSearchId] ?? []
        } else {
            searchService.items
        }
    }

    private var displayedRepositories: [RepositorySearchItem] {
        if let selectedSearchId {
            searchService.repositoryResultsBySearchId[selectedSearchId] ?? []
        } else {
            searchService.repositoryItems
        }
    }

    // MARK: - Combined Results List (All mode)

    @ViewBuilder private var combinedResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedItems) { item in
                    SearchRowView(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { onItemTapped(item) }

                    if item.id != displayedItems.last?.id || !displayedRepositories.isEmpty {
                        Divider()
                            .padding(.leading, 44)
                    }
                }

                ForEach(displayedRepositories) { repo in
                    RepositoryRowView(repository: repo) {
                        if let url = repo.webURL {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    if repo.id != displayedRepositories.last?.id {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
    }

    // MARK: - Results List (Issue/PR only)

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

    // MARK: - Repository Content

    @ViewBuilder private var repositoryContent: some View {
        if displayedRepositories.isEmpty {
            if searchService.isLoading {
                loadingView
            } else {
                emptyStateNoResults
            }
        } else {
            repositoryList
        }
    }

    @ViewBuilder private var repositoryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedRepositories) { repo in
                    RepositoryRowView(repository: repo) {
                        if let url = repo.webURL {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    if repo.id != displayedRepositories.last?.id {
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
