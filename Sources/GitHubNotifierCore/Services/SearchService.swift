//
//  SearchService.swift
//  GitHubNotifierCore
//

import Foundation

/// Service for managing saved searches and fetching aggregated results.
/// Follows the same Observable pattern as ActivityService.
@Observable
@MainActor
public class SearchService {
    // MARK: - Published State

    /// Aggregated, deduplicated results from all enabled searches
    public private(set) var items: [SearchResultItem] = []
    public private(set) var savedSearches: [SavedSearch] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    /// Results per search for preview purposes
    public private(set) var resultsBySearchId: [UUID: [SearchResultItem]] = [:]

    // MARK: - Private

    private var graphqlClient: GitHubGraphQLClient?
    private let storageKey = "savedSearches"

    // MARK: - Initialization

    public init() {
        loadFromStorage()
    }

    public func configure(token: String) {
        graphqlClient = GitHubGraphQLClient(token: token)
    }

    public func clearToken() {
        graphqlClient = nil
        items = []
        resultsBySearchId = [:]
        errorMessage = nil
    }

    // MARK: - CRUD Operations

    public func addSearch(name: String, query: String, type: SearchType = .all, isPinned: Bool = false) {
        let search = SavedSearch(name: name, query: query, isPinned: isPinned, type: type)
        savedSearches.append(search)
        saveToStorage()
    }

    /// Options for updating a saved search
    public struct UpdateOptions: Sendable {
        public var name: String?
        public var query: String?
        public var isEnabled: Bool?
        public var isPinned: Bool?
        public var type: SearchType?

        public init(
            name: String? = nil,
            query: String? = nil,
            isEnabled: Bool? = nil,
            isPinned: Bool? = nil,
            type: SearchType? = nil
        ) {
            self.name = name
            self.query = query
            self.isEnabled = isEnabled
            self.isPinned = isPinned
            self.type = type
        }
    }

    public func updateSearch(id: UUID, options: UpdateOptions) {
        guard let index = savedSearches.firstIndex(where: { $0.id == id }) else { return }
        if let name = options.name { savedSearches[index].name = name }
        if let query = options.query { savedSearches[index].query = query }
        if let isEnabled = options.isEnabled { savedSearches[index].isEnabled = isEnabled }
        if let isPinned = options.isPinned { savedSearches[index].isPinned = isPinned }
        if let type = options.type { savedSearches[index].type = type }
        saveToStorage()
    }

    public func deleteSearch(id: UUID) {
        savedSearches.removeAll { $0.id == id }
        resultsBySearchId.removeValue(forKey: id)
        saveToStorage()
        aggregateResults()
    }

    public func toggleSearch(id: UUID) {
        guard let index = savedSearches.firstIndex(where: { $0.id == id }) else { return }
        savedSearches[index].isEnabled.toggle()
        saveToStorage()
        aggregateResults()
    }

    // MARK: - Fetching

    /// Fetch results for all enabled searches
    public func fetchAll() async {
        guard let graphqlClient else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        let enabledSearches = savedSearches.filter(\.isEnabled)

        do {
            try await withThrowingTaskGroup(of: (UUID, [SearchResultItem]).self) { group in
                for search in enabledSearches {
                    group.addTask {
                        let results = try await graphqlClient.search(query: search.query, first: 30)
                        return (search.id, results)
                    }
                }

                for try await (id, results) in group {
                    resultsBySearchId[id] = results
                }
            }
            aggregateResults()
        } catch {
            errorMessage = error.localizedDescription
            print("Error fetching searches: \(error)")
        }

        isLoading = false
    }

    /// Fetch results for a single search (for preview)
    public func fetchPreview(query: String) async -> [SearchResultItem] {
        guard let graphqlClient else {
            return []
        }

        do {
            return try await graphqlClient.search(query: query, first: 20)
        } catch {
            print("Error fetching preview: \(error)")
            return []
        }
    }

    // MARK: - Private Helpers

    private func aggregateResults() {
        let enabledSearches = savedSearches.filter(\.isEnabled)
        let enabledIds = Set(enabledSearches.map(\.id))

        var seenIds = Set<String>()
        var merged: [SearchResultItem] = []

        for (searchId, results) in resultsBySearchId where enabledIds.contains(searchId) {
            for item in results where !seenIds.contains(item.id) {
                seenIds.insert(item.id)
                merged.append(item)
            }
        }

        items = merged.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            savedSearches = try JSONDecoder().decode([SavedSearch].self, from: data)
        } catch {
            print("Failed to load saved searches: \(error)")
        }
    }

    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(savedSearches)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save searches: \(error)")
        }
    }
}
