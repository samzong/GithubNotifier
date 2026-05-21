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
    @State private var sidebarSearchText = ""

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

    private var isFilteringSidebar: Bool {
        !sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSavedSearches: [SavedSearch] {
        let searchText = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return searchService.savedSearches }

        return searchService.savedSearches.filter { search in
            search.name.localizedStandardContains(searchText) ||
                search.query.localizedStandardContains(searchText) ||
                search.type.displayName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        if isEditing || isNewSearch {
                            TextField("search.management.name.placeholder".localized, text: $editingName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                        } else if let search = currentSearch {
                            Text(search.name)
                                .font(.headline)
                        }
                    }

                    if isEditing || isNewSearch {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.cancel".localized) {
                                if isNewSearch {
                                    isNewSearch = false
                                    isEditing = false
                                } else {
                                    loadSelectedSearch(selectedSearchId)
                                }
                            }
                            .foregroundStyle(.secondary)
                            .liquidGlassButtonStyle()
                        }

                        if #available(macOS 26.0, *) {
                            ToolbarSpacer(.fixed, placement: .primaryAction)
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.save".localized) { saveCurrentSearch() }
                                .liquidGlassButtonStyle(prominent: true)
                                .disabled(editingName.isEmpty || editingQuery.isEmpty)
                        }
                    } else {
                        ToolbarItem(placement: .primaryAction) {
                            Button { createNewSearch() } label: {
                                Label("search.management.add".localized, systemImage: "plus")
                            }
                            .help("search.management.add".localized)
                        }

                        if selectedSearchId != nil {
                            if #available(macOS 26.0, *) {
                                ToolbarSpacer(.fixed, placement: .primaryAction)
                            }

                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    isEditing = true
                                } label: {
                                    Label("common.edit".localized, systemImage: "pencil")
                                }
                                .liquidGlassButtonStyle(prominent: true)
                            }

                            if #available(macOS 26.0, *) {
                                ToolbarSpacer(.fixed, placement: .primaryAction)
                            }

                            ToolbarItem(placement: .primaryAction) {
                                Button(role: .destructive) {
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("common.delete".localized, systemImage: "trash")
                                }
                                .liquidGlassButtonStyle()
                            }
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 800, minHeight: 600)
        .liquidWindowBackground()
        .navigationTitle("")
        .searchable(
            text: $sidebarSearchText,
            placement: .toolbar,
            prompt: Text("search.management.filter.placeholder".localized)
        )
        .liquidSearchToolbarBehavior()
        .liquidAutomaticScrollEdgeEffect(for: .top)
        .confirmationDialog(
            "search.management.delete.title".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.delete".localized, role: .destructive) {
                if let id = selectedSearchId {
                    deleteSearch(id)
                }
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("search.management.delete.message".localized)
        }
    }

    // MARK: - Sidebar

    @ViewBuilder private var sidebar: some View {
        List(selection: $selectedSearchId) {
            if filteredSavedSearches.isEmpty {
                sidebarEmptyView
            } else {
                ForEach(filteredSavedSearches) { search in
                    SearchSidebarRow(search: search)
                        .tag(search.id)
                        .contextMenu {
                            Button(search.isPinned ? "search.management.unpin".localized : "search.management.pin".localized) {
                                searchService.updateSearch(
                                    id: search.id,
                                    options: .init(isPinned: !search.isPinned)
                                )
                            }
                            Button(search.isEnabled ? "search.management.disable".localized : "search.management.enable".localized) {
                                searchService.toggleSearch(id: search.id)
                            }
                            Divider()
                            Button("common.delete".localized, role: .destructive) {
                                deleteSearch(search.id)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("search.management.title".localized)
        .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        .onChange(of: selectedSearchId) { _, newId in
            loadSelectedSearch(newId)
        }
    }

    private var sidebarEmptyView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                isFilteringSidebar
                    ? "search.management.no_matches".localized
                    : "search.management.empty.title".localized,
                systemImage: "magnifyingglass"
            )
            .font(.callout.weight(.medium))

            Text(
                isFilteringSidebar
                    ? "search.management.no_matches.description".localized
                    : "search.management.empty.description".localized
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Detail View

    @ViewBuilder private var detailView: some View {
        if selectedSearchId != nil || isNewSearch {
            contentSection
        } else {
            PolishedEmptyStateView(
                title: "search.management.no_selection.title".localized,
                message: "search.management.no_selection.description".localized,
                systemImage: "magnifyingglass"
            ) {
                Button {
                    createNewSearch()
                } label: {
                    Label("search.management.add".localized, systemImage: "plus")
                }
                .liquidGlassButtonStyle(prominent: true)
                .controlSize(.small)
            }
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
                    Text("search.management.type".localized)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $editingType) {
                        ForEach(SearchType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    Spacer()
                }
            } else if let search = currentSearch {
                HStack {
                    Text("search.management.type".localized)
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
                        .liquidGlassSurface(cornerRadius: 8, interactive: true)
                } else if let search = currentSearch {
                    Text(search.query)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .liquidGlassSurface(cornerRadius: 8)
                }

                VStack(spacing: 8) {
                    Button("search.management.preview".localized) {
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
                Text("search.management.preview.results".localized)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !previewResults.isEmpty || !previewRepositories.isEmpty {
                    Text(String(format: "search.management.preview.count".localized, previewResults.count + previewRepositories.count))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if previewResults.isEmpty, previewRepositories.isEmpty {
                PolishedEmptyStateView(
                    title: "search.management.preview.empty.title".localized,
                    message: "search.management.preview.empty.description".localized,
                    systemImage: "doc.text.magnifyingglass",
                    accent: .secondary
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !previewRepositories.isEmpty {
                List(previewRepositories) { repo in
                    RepositoryPreviewRow(repository: repo)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            } else {
                List(previewResults) { item in
                    SearchPreviewRow(item: item)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
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
