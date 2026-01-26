import Foundation

@Observable
@MainActor
public class NotificationService {
    public var notifications: [GitHubNotification] = [] {
        didSet {
            updateGroupedNotifications()
        }
    }

    public private(set) var groupedNotifications: [NotificationGroup] = []

    public var currentUser: GitHubGraphQLClient.ViewerInfo?
    public var isLoading = false
    public var errorMessage: String?

    public var unreadCount: Int { notifications.count }

    private var restClient: GitHubAPI?
    private var graphqlClient: GitHubGraphQLClient?
    // nonisolated(unsafe) required for mutable properties accessed from deinit
    @ObservationIgnored private nonisolated(unsafe) var autoRefreshTask: Task<Void, Never>?
    @ObservationIgnored private nonisolated(unsafe) var initialFetchTask: Task<Void, Never>?
    private var prStateCache: [String: PRState] = [:]
    private var issueStateCache: [String: IssueState] = [:]
    private var detailsCache: [String: NotificationDetails] = [:]
    private var previousNotificationIds: Set<String> = []

    // Rule engine integration
    public var ruleStorage: RuleStorage?
    private let ruleEngine = RuleEngine()

    public init(token: String? = nil) {
        if let token {
            self.restClient = GitHubAPI(token: token)
            self.graphqlClient = GitHubGraphQLClient(token: token)
        }
        startAutoRefreshIfNeeded()
    }

    deinit {
        autoRefreshTask?.cancel()
        initialFetchTask?.cancel()
    }

    private func startAutoRefreshIfNeeded() {
        let interval = UserDefaults.standard.double(forKey: UserPreferences.refreshIntervalKey)
        startAutoRefresh(interval: interval > 0 ? interval : 60)

        initialFetchTask = Task { [weak self] in
            await self?.fetchNotifications()
        }
    }

    public func configure(token: String) {
        self.restClient = GitHubAPI(token: token)
        self.graphqlClient = GitHubGraphQLClient(token: token)
        startAutoRefreshIfNeeded()
    }

    public func clearToken() {
        stopAutoRefresh()
        initialFetchTask?.cancel()
        restClient = nil
        graphqlClient = nil
        notifications = []
        errorMessage = nil
        isLoading = false
        prStateCache = [:]
        issueStateCache = [:]
        detailsCache = [:]
        previousNotificationIds = []
    }

    public func fetchNotifications(isAutoRefresh: Bool = false) async {
        guard let restClient else {
            errorMessage = "GitHub token not configured"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var fetchedNotifications = try await restClient.fetchNotifications()

            if isAutoRefresh {
                let markedAsReadIds = await detectAndNotifyNewNotifications(fetchedNotifications)
                // Filter out notifications that were auto-marked as read by rules
                fetchedNotifications = fetchedNotifications.filter { !markedAsReadIds.contains($0.id) }
            }

            notifications = fetchedNotifications
            pruneStaleCache()

            await loadNotificationDetails()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    public func fetchCurrentUser() async {
        guard let graphqlClient else { return }
        do {
            currentUser = try await graphqlClient.fetchViewer()
        } catch {
            print("Failed to fetch current user: \(error)")
        }
    }

    private func loadNotificationDetails() async {
        guard let graphqlClient else { return }

        var requests: [(cacheKey: String, owner: String, repo: String, number: Int, type: NotificationSubjectType)] = []

        for notification in notifications {
            let owner = notification.repository.owner.login
            let repo = notification.repository.name

            guard let number = notification.issueOrPRNumber else { continue }

            let type: NotificationSubjectType
            switch notification.notificationType {
            case .pullRequest:
                type = .pullRequest
                let key = cacheKey(owner: owner, repo: repo, type: .pullRequest, number: number)
                if detailsCache[key] == nil {
                    requests.append((key, owner, repo, number, type))
                }
            case .issue:
                type = .issue
                let key = cacheKey(owner: owner, repo: repo, type: .issue, number: number)
                if detailsCache[key] == nil {
                    requests.append((key, owner, repo, number, type))
                }
            default:
                continue
            }
        }

        await withTaskGroup(of: (String, NotificationDetails?, NotificationSubjectType).self) { group in
            for request in requests {
                group.addTask {
                    let details = try? await graphqlClient.fetchNotificationDetails(
                        owner: request.owner,
                        repo: request.repo,
                        number: request.number,
                        type: request.type
                    )
                    return (request.cacheKey, details, request.type)
                }
            }

            for await (cacheKey, details, type) in group {
                if let details {
                    detailsCache[cacheKey] = details

                    if type == .pullRequest {
                        prStateCache[cacheKey] = determinePRStateFromGraphQL(details)
                    } else {
                        issueStateCache[cacheKey] = determineIssueStateFromGraphQL(details)
                    }
                }
            }
        }
    }

    public func getPRState(for notification: GitHubNotification) -> PRState? {
        guard notification.notificationType == .pullRequest,
              let number = notification.issueOrPRNumber else {
            return nil
        }

        let owner = notification.repository.owner.login
        let repo = notification.repository.name
        let key = cacheKey(owner: owner, repo: repo, type: .pullRequest, number: number)

        return prStateCache[key]
    }

    public func getIssueState(for notification: GitHubNotification) -> IssueState? {
        guard notification.notificationType == .issue,
              let number = notification.issueOrPRNumber else {
            return nil
        }

        let owner = notification.repository.owner.login
        let repo = notification.repository.name
        let key = cacheKey(owner: owner, repo: repo, type: .issue, number: number)

        return issueStateCache[key]
    }

    public func getNotificationDetails(for notification: GitHubNotification) -> NotificationDetails? {
        let owner = notification.repository.owner.login
        let repo = notification.repository.name
        guard let number = notification.issueOrPRNumber else { return nil }

        let type: NotificationSubjectType = notification.notificationType == .pullRequest ? .pullRequest : .issue
        let key = cacheKey(owner: owner, repo: repo, type: type, number: number)

        return detailsCache[key]
    }

    public func markAsRead(notification: GitHubNotification) async {
        guard let restClient else { return }

        do {
            try await restClient.markNotificationAsRead(threadId: notification.id)
            notifications.removeAll { $0.id == notification.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Updates the cached grouped notifications
    private func updateGroupedNotifications() {
        let groups = Dictionary(grouping: notifications) { notification -> String in
            notification.groupKey ?? notification.id
        }

        groupedNotifications = groups.map { key, notifications in
            NotificationGroup(id: key, notifications: notifications)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Mark all notifications in a group as read
    public func markGroupAsRead(_ group: NotificationGroup) async {
        guard let restClient else { return }

        for notification in group.notifications {
            do {
                try await restClient.markNotificationAsRead(threadId: notification.id)
            } catch {
                // Continue marking others even if one fails
            }
        }

        let groupIds = Set(group.notifications.map(\.id))
        notifications.removeAll { groupIds.contains($0.id) }
    }

    public func markAllAsRead() async {
        guard let restClient else { return }

        do {
            try await restClient.markAllNotificationsAsRead()
            notifications.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func startAutoRefresh(interval: TimeInterval) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.fetchNotifications(isAutoRefresh: true)
            }
        }
    }

    public func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    /// Returns the set of notification IDs that were marked as read by rules
    private func detectAndNotifyNewNotifications(_ fetchedNotifications: [GitHubNotification]) async -> Set<String> {
        var markedAsReadIds: Set<String> = []
        let currentIds = Set(fetchedNotifications.map(\.id))

        if previousNotificationIds.isEmpty {
            previousNotificationIds = currentIds
            return markedAsReadIds
        }

        let newIds = currentIds.subtracting(previousNotificationIds)

        var newNotifications = fetchedNotifications.filter { notification in
            newIds.contains(notification.id) &&
                (notification.notificationType == .issue || notification.notificationType == .pullRequest)
        }

        // Apply rules to new notifications
        if let ruleStorage {
            var notificationsToSend: [GitHubNotification] = []

            for notification in newNotifications {
                let result = ruleEngine.evaluate(
                    notification: notification,
                    rules: ruleStorage.rules
                )

                // Mark as read if rule dictates
                if result.shouldMarkAsRead {
                    await markAsRead(notification: notification)
                    markedAsReadIds.insert(notification.id)
                }

                // Only send system notification if not suppressed
                if !result.shouldSuppressNotification, !result.shouldMarkAsRead {
                    notificationsToSend.append(notification)
                }
            }

            newNotifications = notificationsToSend
        }

        if !newNotifications.isEmpty {
            await NotificationManager.shared.sendNotifications(for: newNotifications)
        }

        previousNotificationIds = currentIds
        return markedAsReadIds
    }

    private nonisolated func determinePRStateFromGraphQL(_ details: NotificationDetails) -> PRState {
        switch details.state.uppercased() {
        case "MERGED":
            .merged
        case "CLOSED":
            .closed
        case "DRAFT":
            .draft
        default:
            .open
        }
    }

    private nonisolated func determineIssueStateFromGraphQL(_ details: NotificationDetails) -> IssueState {
        switch details.state.uppercased() {
        case "CLOSED":
            .closedCompleted
        default:
            .open
        }
    }

    private func cacheKey(owner: String, repo: String, type: NotificationSubjectType, number: Int) -> String {
        let prefix = type == .pullRequest ? "pr" : "issue"
        return "\(owner)/\(repo)/\(prefix)/\(number)"
    }

    private func pruneStaleCache() {
        // Collect all active keys from current notifications
        var activeKeys: Set<String> = []
        for notification in notifications {
            guard let number = notification.issueOrPRNumber else { continue }
            let owner = notification.repository.owner.login
            let repo = notification.repository.name
            let type: NotificationSubjectType = notification.notificationType == .pullRequest ? .pullRequest : .issue
            activeKeys.insert(cacheKey(owner: owner, repo: repo, type: type, number: number))
        }

        // Remove cache entries that are no longer in active keys
        // Note: This is a simple strategy. For more robustness, we might want to keep them for a while.
        // But since we persist nothing and this is an in-memory session cache, syncing with 'notifications' list is acceptable.

        let keysToRemove = Set(detailsCache.keys).subtracting(activeKeys)

        for key in keysToRemove {
            detailsCache.removeValue(forKey: key)
            prStateCache.removeValue(forKey: key)
            issueStateCache.removeValue(forKey: key)
        }
    }
}
