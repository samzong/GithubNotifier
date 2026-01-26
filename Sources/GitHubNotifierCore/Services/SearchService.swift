//
//  SearchService.swift
//  GitHubNotifierCore
//

import Foundation

@Observable
@MainActor
public class SearchService {
    // MARK: - Published State

    public private(set) var items: [SearchResultItem] = []
    public private(set) var repositoryItems: [RepositorySearchItem] = []
    public private(set) var savedSearches: [SavedSearch] = []
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public private(set) var resultsBySearchId: [UUID: [SearchResultItem]] = [:]
    public private(set) var repositoryResultsBySearchId: [UUID: [RepositorySearchItem]] = [:]

    // MARK: - Private

    private var graphqlClient: GitHubGraphQLClient?
    private let storageKey = "savedSearches"

    @ObservationIgnored private nonisolated(unsafe) var autoRefreshTask: Task<Void, Never>?
    private var previousItemIds: Set<String> = []
    private var previousRepositoryIds: Set<String> = []

    private let refreshInterval: TimeInterval = 300 // 5 min

    // MARK: - Initialization

    public init() {
        loadFromStorage()
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    public func configure(token: String) {
        graphqlClient = GitHubGraphQLClient(token: token)
        startAutoRefresh()
    }

    public func clearToken() {
        stopAutoRefresh()
        graphqlClient = nil
        items = []
        repositoryItems = []
        resultsBySearchId = [:]
        repositoryResultsBySearchId = [:]
        previousItemIds = []
        previousRepositoryIds = []
        errorMessage = nil
    }

    // MARK: - CRUD Operations

    public func addSearch(name: String, query: String, type: SearchType = .all, isPinned: Bool = false) {
        let search = SavedSearch(name: name, query: query, isPinned: isPinned, type: type)
        savedSearches.append(search)
        saveToStorage()
    }

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
        repositoryResultsBySearchId.removeValue(forKey: id)
        saveToStorage()
        aggregateResults()
        aggregateRepositoryResults()
    }

    public func toggleSearch(id: UUID) {
        guard let index = savedSearches.firstIndex(where: { $0.id == id }) else { return }
        savedSearches[index].isEnabled.toggle()
        saveToStorage()
        aggregateResults()
        aggregateRepositoryResults()
    }

    // MARK: - Fetching

    public func fetchAll(isAutoRefresh: Bool = false) async {
        guard let graphqlClient else {
            if !isAutoRefresh {
                errorMessage = "Not authenticated"
            }
            return
        }

        if !isAutoRefresh {
            isLoading = true
        }
        errorMessage = nil

        let enabledSearches = savedSearches.filter(\.isEnabled)
        let issueSearches = enabledSearches.filter { $0.type != .repository }
        let repoSearches = enabledSearches.filter { $0.type == .repository }

        for search in issueSearches {
            do {
                let results = try await graphqlClient.search(query: search.query, first: 30)
                resultsBySearchId[search.id] = results
            } catch {
                if !isAutoRefresh {
                    print("Error fetching search \(search.name): \(error)")
                }
            }
        }

        for search in repoSearches {
            do {
                let results = try await graphqlClient.searchRepositories(query: search.query, first: 30)
                repositoryResultsBySearchId[search.id] = results
            } catch {
                if !isAutoRefresh {
                    print("Error fetching repo search \(search.name): \(error)")
                }
            }
        }

        aggregateResults()
        aggregateRepositoryResults()

        if isAutoRefresh {
            await detectAndNotifyNewItems()
            await detectAndNotifyNewRepositories()
        }

        previousItemIds = Set(items.map(\.id))
        previousRepositoryIds = Set(repositoryItems.map(\.id))

        if !isAutoRefresh {
            isLoading = false
        }
    }

    // MARK: - Auto-Refresh

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            await self?.fetchAll(isAutoRefresh: false)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.refreshInterval ?? 300))
                guard !Task.isCancelled else { break }
                await self?.fetchAll(isAutoRefresh: true)
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // MARK: - Diff Detection & Notification

    private func detectAndNotifyNewItems() async {
        guard !previousItemIds.isEmpty else { return }

        let currentIds = Set(items.map(\.id))
        let newIds = currentIds.subtracting(previousItemIds)
        let newItems = items.filter { newIds.contains($0.id) }

        for item in newItems.prefix(5) {
            await NotificationManager.shared.sendSearchResultNotification(for: item)
        }
    }

    private func detectAndNotifyNewRepositories() async {
        guard !previousRepositoryIds.isEmpty else { return }

        let currentIds = Set(repositoryItems.map(\.id))
        let newIds = currentIds.subtracting(previousRepositoryIds)
        let newRepos = repositoryItems.filter { newIds.contains($0.id) }

        for repo in newRepos.prefix(5) {
            await NotificationManager.shared.sendRepositoryNotification(for: repo)
        }
    }

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

    public func fetchRepositoryPreview(query: String) async -> [RepositorySearchItem] {
        guard let graphqlClient else {
            return []
        }

        do {
            return try await graphqlClient.searchRepositories(query: query, first: 20)
        } catch {
            print("Error fetching repository preview: \(error)")
            return []
        }
    }

    // MARK: - Private Helpers

    private func aggregateResults() {
        let enabledSearches = savedSearches.filter { $0.isEnabled && $0.type != .repository }
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

    private func aggregateRepositoryResults() {
        let enabledSearches = savedSearches.filter { $0.isEnabled && $0.type == .repository }
        let enabledIds = Set(enabledSearches.map(\.id))

        var seenIds = Set<String>()
        var merged: [RepositorySearchItem] = []

        for (searchId, results) in repositoryResultsBySearchId where enabledIds.contains(searchId) {
            for item in results where !seenIds.contains(item.id) {
                seenIds.insert(item.id)
                merged.append(item)
            }
        }

        repositoryItems = merged.sorted { $0.createdAt > $1.createdAt }
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
