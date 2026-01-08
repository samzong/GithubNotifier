import Foundation

/// Filter category matching GitHub's tabs
public enum MyItemsFilter: String, CaseIterable, Sendable {
    case all
    case created      // author:@me
    case assigned     // assignee:@me
    case mentioned    // mentions:@me
    case reviewRequested  // review-requested:@me (PRs only)
}

/// Service for fetching user-related Issues and Pull Requests
/// Aggregates results from author:@me, assignee:@me, mentions:@me queries
@Observable
@MainActor
public class MyItemsService {
    // Unified items (all combined, deduplicated)
    public private(set) var items: [SearchResultItem] = []

    // Category-separated storage (for quick filtering)
    public private(set) var createdItems: [SearchResultItem] = []
    public private(set) var assignedItems: [SearchResultItem] = []
    public private(set) var mentionedItems: [SearchResultItem] = []
    public private(set) var reviewRequestedItems: [SearchResultItem] = []

    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private var graphqlClient: GitHubGraphQLClient?

    public init() {}

    public func configure(token: String) {
        self.graphqlClient = GitHubGraphQLClient(token: token)
    }

    public func clearToken() {
        graphqlClient = nil
        items = []
        createdItems = []
        assignedItems = []
        mentionedItems = []
        reviewRequestedItems = []
        errorMessage = nil
    }

    /// Fetch all user-related Issues and Pull Requests
    public func fetchMyItems() async {
        guard let graphqlClient else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Parallel fetch for all query types
            async let created = graphqlClient.search(query: "is:open author:@me", first: 30)
            async let assigned = graphqlClient.search(query: "is:open assignee:@me", first: 30)
            async let mentioned = graphqlClient.search(query: "is:open mentions:@me", first: 30)
            async let reviewRequested = graphqlClient.search(query: "is:open review-requested:@me", first: 30)

            createdItems = try await created
            assignedItems = try await assigned
            mentionedItems = try await mentioned
            reviewRequestedItems = try await reviewRequested

            // Merge and deduplicate for unified view
            var seenIds = Set<String>()
            var mergedItems: [SearchResultItem] = []

            for batch in [createdItems, assignedItems, mentionedItems, reviewRequestedItems] {
                for item in batch {
                    if !seenIds.contains(item.id) {
                        seenIds.insert(item.id)
                        mergedItems.append(item)
                    }
                }
            }

            // Sort by updatedAt descending
            items = mergedItems.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtered Accessors

    public func items(for filter: MyItemsFilter) -> [SearchResultItem] {
        switch filter {
        case .all: items
        case .created: createdItems
        case .assigned: assignedItems
        case .mentioned: mentionedItems
        case .reviewRequested: reviewRequestedItems
        }
    }

    public func pullRequests(for filter: MyItemsFilter) -> [SearchResultItem] {
        items(for: filter).filter { $0.itemType == .pullRequest }
    }

    public func issues(for filter: MyItemsFilter) -> [SearchResultItem] {
        items(for: filter).filter { $0.itemType == .issue }
    }

    public func count(for filter: MyItemsFilter) -> Int {
        items(for: filter).count
    }

    // MARK: - Legacy Accessors (for backward compatibility)

    public var pullRequests: [SearchResultItem] { pullRequests(for: .all) }
    public var issues: [SearchResultItem] { issues(for: .all) }
    public var itemCount: Int { items.count }
    public var pullRequestCount: Int { pullRequests.count }
    public var issueCount: Int { issues.count }
}
