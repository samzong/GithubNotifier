import Foundation

/// Filter category matching GitHub's tabs
public enum ActivityFilter: String, CaseIterable, Sendable {
    case all
    case created // author:@me
    case assigned // assignee:@me
    case mentioned // mentions:@me
    case reviewRequested // review-requested:@me (PRs only)
}

/// Service for fetching user-related Issues and Pull Requests
/// Aggregates results from author:@me, assignee:@me, mentions:@me queries
@Observable
@MainActor
public class ActivityService {
    // Unified items (all combined, deduplicated)
    public var items: [SearchResultItem] {
        let all = (createdItems + assignedItems + mentionedItems + reviewRequestedItems)
        var seenIds = Set<String>()
        var merged: [SearchResultItem] = []
        for item in all where !seenIds.contains(item.id) {
            seenIds.insert(item.id)
            merged.append(item)
        }
        return merged.sorted { $0.updatedAt > $1.updatedAt }
    }

    // Category-separated storage (computed from underlying typed storage)
    public var createdItems: [SearchResultItem] {
        (createdIssues + createdPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    public var assignedItems: [SearchResultItem] {
        (assignedIssues + assignedPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    public var mentionedItems: [SearchResultItem] {
        (mentionedIssues + mentionedPRs).sorted { $0.updatedAt > $1.updatedAt }
    }

    public var reviewRequestedItems: [SearchResultItem] {
        reviewRequestedPRs.sorted { $0.updatedAt > $1.updatedAt }
    }

    // Underlying typed storage
    private var createdIssues: [SearchResultItem] = []
    private var createdPRs: [SearchResultItem] = []

    private var assignedIssues: [SearchResultItem] = []
    private var assignedPRs: [SearchResultItem] = []

    private var mentionedIssues: [SearchResultItem] = []
    private var mentionedPRs: [SearchResultItem] = []

    // Review requested is only for PRs
    private var reviewRequestedPRs: [SearchResultItem] = []

    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private var graphqlClient: GitHubGraphQLClient?

    public init() {}

    public func configure(token: String) {
        self.graphqlClient = GitHubGraphQLClient(token: token)
    }

    public func clearToken() {
        graphqlClient = nil
        createdIssues = []
        createdPRs = []
        assignedIssues = []
        assignedPRs = []
        mentionedIssues = []
        mentionedPRs = []
        reviewRequestedPRs = []
        errorMessage = nil
    }

    /// Fetch user-related Items, optionally filtered by type
    public func fetchMyItems(type: SearchResultItem.ItemType? = nil) async {
        guard let graphqlClient else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            if type == nil || type == .issue {
                async let created = graphqlClient.search(query: "is:open is:issue author:@me", first: 30)
                async let assigned = graphqlClient.search(query: "is:open is:issue assignee:@me", first: 30)
                async let mentioned = graphqlClient.search(query: "is:open is:issue mentions:@me", first: 30)

                createdIssues = try await created
                assignedIssues = try await assigned
                mentionedIssues = try await mentioned
            }

            if type == nil || type == .pullRequest {
                async let created = graphqlClient.search(query: "is:open is:pr author:@me", first: 30)
                async let assigned = graphqlClient.search(query: "is:open is:pr assignee:@me", first: 30)
                async let mentioned = graphqlClient.search(query: "is:open is:pr mentions:@me", first: 30)
                async let reviewRequested = graphqlClient.search(query: "is:open is:pr review-requested:@me", first: 30)

                createdPRs = try await created
                assignedPRs = try await assigned
                mentionedPRs = try await mentioned
                reviewRequestedPRs = try await reviewRequested
            }

        } catch {
            errorMessage = error.localizedDescription
            print("Error fetching items: \(error)")
        }

        isLoading = false
    }

    // MARK: - Filtered Accessors

    public func items(for filter: ActivityFilter) -> [SearchResultItem] {
        switch filter {
        case .all: items
        case .created: createdItems
        case .assigned: assignedItems
        case .mentioned: mentionedItems
        case .reviewRequested: reviewRequestedItems
        }
    }

    public func pullRequests(for filter: ActivityFilter) -> [SearchResultItem] {
        items(for: filter).filter { $0.itemType == .pullRequest }
    }

    public func issues(for filter: ActivityFilter) -> [SearchResultItem] {
        items(for: filter).filter { $0.itemType == .issue }
    }

    public func count(for filter: ActivityFilter) -> Int {
        items(for: filter).count
    }

    // MARK: - Legacy Accessors (for backward compatibility)

    public var pullRequests: [SearchResultItem] { pullRequests(for: .all) }
    public var issues: [SearchResultItem] { issues(for: .all) }
    public var itemCount: Int { items.count }
    public var pullRequestCount: Int { pullRequests.count }
    public var issueCount: Int { issues.count }
}
