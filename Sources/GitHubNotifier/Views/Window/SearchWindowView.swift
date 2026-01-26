//
//  SearchWindowView.swift
//  GitHubNotifier
//
//

import GitHubNotifierCore
import SwiftUI

struct SearchWindowView: View {
    @Environment(SearchService.self) private var searchService
    @State private var selectedSearchId: UUID?
    @State private var editingName = ""
    @State private var editingQuery = ""
    @State private var editingType: SearchType = .all
    @State private var editingIsPinned = false
    @State private var previewResults: [SearchResultItem] = []
    @State private var previewRepositories: [RepositorySearchItem] = []
    @State private var isLoadingPreview = false
    @State private var isNewSearch = false
    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var queryWebURL: URL? {
        let query = isEditing || isNewSearch ? editingQuery : (currentSearch?.query ?? "")
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://github.com/search?q=\(encoded)")
    }

    private var currentSearch: SavedSearch? {
        guard let id = selectedSearchId else { return nil }
        return searchService.savedSearches.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        if isEditing || isNewSearch {
                            TextField("Search Name", text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        } else if let search = currentSearch {
                            Text(search.name)
                                .font(.headline)
                        }
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        if isEditing || isNewSearch {
                            Button("Cancel") {
                                if isNewSearch {
                                    isNewSearch = false
                                    isEditing = false
                                } else {
                                    loadSelectedSearch(selectedSearchId)
                                }
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.secondary)

                            Button("Save") { saveCurrentSearch() }
                                .buttonStyle(.borderedProminent)
                                .disabled(editingName.isEmpty || editingQuery.isEmpty)
                        } else if selectedSearchId != nil {
                            Button("Edit") { isEditing = true }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)

                            Button("Delete") {
                                showDeleteConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle("")
        .confirmationDialog(
            "Delete Search",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = selectedSearchId {
                    deleteSearch(id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this search? This action cannot be undone.")
        }
    }

    // MARK: - Sidebar

    @ViewBuilder private var sidebar: some View {
        List(selection: $selectedSearchId) {
            ForEach(searchService.savedSearches) { search in
                SearchSidebarRow(search: search)
                    .tag(search.id)
                    .contextMenu {
                        Button(search.isPinned ? "Unpin from Tab" : "Pin to Tab") {
                            searchService.updateSearch(
                                id: search.id,
                                options: .init(isPinned: !search.isPinned)
                            )
                        }
                        Button(search.isEnabled ? "Disable" : "Enable") {
                            searchService.toggleSearch(id: search.id)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            deleteSearch(search.id)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Saved Searches")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { createNewSearch() } label: {
                    Image(systemName: "plus")
                }
                .help("Add new search")
            }
        }
        .onChange(of: selectedSearchId) { _, newId in
            loadSelectedSearch(newId)
        }
    }

    // MARK: - Detail View

    @ViewBuilder private var detailView: some View {
        if selectedSearchId != nil || isNewSearch {
            contentSection
        } else {
            ContentUnavailableView(
                "No Search Selected",
                systemImage: "magnifyingglass",
                description: Text("Select a search from the sidebar or create a new one.")
            )
        }
    }

    // MARK: - Content Section

    @ViewBuilder private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            querySection

            if let url = queryWebURL {
                Link(url.absoluteString, destination: url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Divider()

            previewSection
        }
        .padding(16)
    }

    // MARK: - Query Section

    @ViewBuilder private var querySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditing || isNewSearch {
                HStack {
                    Text("Type:")
                        .foregroundStyle(.secondary)
                    Picker("", selection: $editingType) {
                        ForEach(SearchType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Spacer()
                }
            } else if let search = currentSearch {
                HStack {
                    Text("Type:")
                        .foregroundStyle(.secondary)
                    Label(search.type.displayName, systemImage: search.type.icon)
                        .foregroundStyle(.primary)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                if isEditing || isNewSearch {
                    TextEditor(text: $editingQuery)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 60, maxHeight: 120)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                } else if let search = currentSearch {
                    Text(search.query)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(spacing: 8) {
                    Button("Preview") {
                        if !isEditing, let search = currentSearch {
                            editingQuery = search.query
                            editingType = search.type
                        }
                        Task { await runPreview() }
                    }
                    .disabled((isEditing || isNewSearch) && editingQuery.isEmpty)

                    if isLoadingPreview {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Preview Section

    @ViewBuilder private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview Results")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !previewResults.isEmpty || !previewRepositories.isEmpty {
                    Text("\(previewResults.count + previewRepositories.count) items")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if previewResults.isEmpty, previewRepositories.isEmpty {
                ContentUnavailableView(
                    "No Preview",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Click Preview to test the query.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !previewRepositories.isEmpty {
                List(previewRepositories) { repo in
                    RepositoryPreviewRow(repository: repo)
                }
                .listStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                List(previewResults) { item in
                    SearchPreviewRow(item: item)
                }
                .listStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createNewSearch() {
        isNewSearch = true
        isEditing = true
        selectedSearchId = nil
        editingName = ""
        editingQuery = ""
        editingType = .all
        editingIsPinned = false
        previewResults = []
        previewRepositories = []
    }

    private func loadSelectedSearch(_ id: UUID?) {
        guard let id, let search = searchService.savedSearches.first(where: { $0.id == id }) else {
            return
        }
        isNewSearch = false
        isEditing = false
        editingName = search.name
        editingQuery = search.query
        editingType = search.type
        editingIsPinned = search.isPinned
        previewResults = []
        previewRepositories = []
    }

    private func saveCurrentSearch() {
        if isNewSearch {
            searchService.addSearch(
                name: editingName,
                query: editingQuery,
                type: editingType,
                isPinned: editingIsPinned
            )
            if let newSearch = searchService.savedSearches.last {
                selectedSearchId = newSearch.id
            }
            isNewSearch = false
            isEditing = false
        } else if let id = selectedSearchId {
            searchService.updateSearch(
                id: id,
                options: .init(
                    name: editingName,
                    query: editingQuery,
                    isPinned: editingIsPinned,
                    type: editingType
                )
            )
            isEditing = false
        }
    }

    private func deleteSearch(_ id: UUID) {
        searchService.deleteSearch(id: id)
        if selectedSearchId == id {
            selectedSearchId = nil
            editingName = ""
            editingQuery = ""
            editingIsPinned = false
            previewResults = []
            previewRepositories = []
            isEditing = false
        }
    }

    @MainActor
    private func runPreview() async {
        isLoadingPreview = true
        if editingType == .repository {
            previewRepositories = await searchService.fetchRepositoryPreview(query: editingQuery)
            previewResults = []
        } else {
            previewResults = await searchService.fetchPreview(query: editingQuery)
            previewRepositories = []
        }
        isLoadingPreview = false
    }
}

// MARK: - Supporting Views

private struct SearchSidebarRow: View {
    let search: SavedSearch

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(search.name)
                    .lineLimit(1)
                if search.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(search.query)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .opacity(search.isEnabled ? 1.0 : 0.6)
    }
}

private struct SearchPreviewRow: View {
    let item: SearchResultItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.itemType == .pullRequest ? "arrow.triangle.pull" : "circle.dotted")
                .font(.body)
                .foregroundStyle(item.itemType == .pullRequest ? .purple : .green)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .lineLimit(1)
                    .font(.callout)
                HStack(spacing: 6) {
                    Text("\(item.repositoryOwner)/\(item.repositoryName)")
                    Text("#\(item.number)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.state)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(stateColor.opacity(0.15))
                .foregroundStyle(stateColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
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

private struct RepositoryPreviewRow: View {
    let repository: RepositorySearchItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: repository.isPrivate ? "lock.fill" : "folder")
                .font(.body)
                .foregroundStyle(repository.isFork ? .secondary : .primary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(repository.fullName)
                    .lineLimit(1)
                    .font(.callout)
                HStack(spacing: 6) {
                    if let language = repository.language {
                        Text(language)
                    }
                    Text(repository.createdAt.timeAgo())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "star")
                Text("\(repository.stargazerCount)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchWindowView()
        .environment(SearchService())
}
