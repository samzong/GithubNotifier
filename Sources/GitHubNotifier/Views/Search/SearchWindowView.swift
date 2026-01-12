//
//  SearchWindowView.swift
//  GitHubNotifier
//
//  Management window for saved searches with left sidebar and right editor/preview.
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
    @State private var isLoadingPreview = false
    @State private var isNewSearch = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, minHeight: 480)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSearchId) {
                ForEach(searchService.savedSearches) { search in
                    SearchSidebarRow(search: search)
                        .tag(search.id)
                        .contextMenu {
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
            .onChange(of: selectedSearchId) { _, newId in
                loadSelectedSearch(newId)
            }

            Divider()

            HStack {
                Button {
                    createNewSearch()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add new search")

                Spacer()
            }
            .padding(8)
        }
        .navigationTitle("Saved Searches")
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if selectedSearchId != nil || isNewSearch {
            VStack(spacing: 0) {
                editorSection
                Divider()
                previewSection
            }
        } else {
            ContentUnavailableView(
                "No Search Selected",
                systemImage: "magnifyingglass",
                description: Text("Select a search from the sidebar or create a new one.")
            )
        }
    }

    // MARK: - Editor Section

    @ViewBuilder
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isNewSearch ? "New Search" : "Edit Search")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    saveCurrentSearch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(editingName.isEmpty || editingQuery.isEmpty)
            }

            HStack {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.roundedBorder)

                Picker("Type", selection: $editingType) {
                    ForEach(SearchType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .frame(width: 140)

                Toggle(isOn: $editingIsPinned) {
                    Image(systemName: editingIsPinned ? "pin.fill" : "pin.slash")
                        .foregroundStyle(editingIsPinned ? .orange : .secondary)
                }
                .toggleStyle(.button)
                .help("Pin to Search Tab")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Query")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $editingQuery)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60, maxHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                if !editingQuery.isEmpty,
                   let encoded = editingQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "https://github.com/search?q=\(encoded)") {
                    Link(destination: url) {
                        Label("View on GitHub (Web)", systemImage: "safari")
                            .font(.caption)
                    }
                    .padding(.top, 4)
                }
            }

            HStack {
                Button("Preview") {
                    Task { await runPreview() }
                }
                .disabled(editingQuery.isEmpty)

                if isLoadingPreview {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }

                Spacer()

                Link(destination: URL(string: "https://docs.github.com/en/search-github/searching-on-github")!) {
                    Label("Search Syntax Help", systemImage: "questionmark.circle")
                        .font(.caption)
                }
            }
        }
        .padding(16)
    }

    // MARK: - Preview Section

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview Results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(previewResults.count) items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if previewResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Run a preview to see search results.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List(previewResults) { item in
                    SearchPreviewRow(item: item)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createNewSearch() {
        isNewSearch = true
        selectedSearchId = nil
        editingName = ""
        editingQuery = ""
        editingType = .all
        editingIsPinned = false
        previewResults = []
    }

    private func loadSelectedSearch(_ id: UUID?) {
        guard let id, let search = searchService.savedSearches.first(where: { $0.id == id }) else {
            return
        }
        isNewSearch = false
        editingName = search.name
        editingQuery = search.query
        editingType = search.type
        editingIsPinned = search.isPinned
        previewResults = searchService.resultsBySearchId[id] ?? []
    }

    private func saveCurrentSearch() {
        if isNewSearch {
            searchService.addSearch(name: editingName, query: editingQuery, type: editingType, isPinned: editingIsPinned)
            // Select the newly created search
            if let newSearch = searchService.savedSearches.last {
                selectedSearchId = newSearch.id
            }
            isNewSearch = false
        } else if let id = selectedSearchId {
            searchService.updateSearch(
                id: id,
                name: editingName,
                query: editingQuery,
                isEnabled: nil,
                isPinned: editingIsPinned,
                type: editingType
            )
        }
    }

    private func deleteSearch(_ id: UUID) {
        searchService.deleteSearch(id: id)
        if selectedSearchId == id {
            selectedSearchId = nil
            editingName = ""
            editingQuery = ""
            editingType = .all
            editingIsPinned = false
            previewResults = []
        }
    }

    @MainActor
    private func runPreview() async {
        isLoadingPreview = true
        previewResults = await searchService.fetchPreview(query: editingQuery)
        isLoadingPreview = false
    }
}

// MARK: - Supporting Views

private struct SearchSidebarRow: View {
    let search: SavedSearch

    var body: some View {
        HStack {
            Image(systemName: search.type.icon)
                .foregroundStyle(search.isEnabled ? .primary : .secondary)

            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(search.name)
                        .lineLimit(1)
                    if search.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                }
                Text(search.query)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(search.isEnabled ? 1.0 : 0.6)
    }
}

private struct SearchPreviewRow: View {
    let item: SearchResultItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.itemType == .pullRequest ? "arrow.triangle.pull" : "circle.dotted")
                .foregroundStyle(item.itemType == .pullRequest ? .purple : .green)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)
                    .font(.callout)
                HStack(spacing: 4) {
                    Text("\(item.repositoryOwner)/\(item.repositoryName)")
                    Text("#\(item.number)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.state)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(stateColor.opacity(0.15))
                .foregroundStyle(stateColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
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
    SearchWindowView()
        .environment(SearchService())
}
