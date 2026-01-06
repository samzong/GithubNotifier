import Foundation

@Observable
@MainActor
class NotificationService {
    var notifications: [GitHubNotification] = []
    var isLoading = false
    var errorMessage: String?
    var filterOptions = FilterOptions()

    var unreadCount: Int { notifications.count }

    private var api: GitHubAPI?
    private var refreshTimer: Timer?
    private var prStateCache: [String: PRState] = [:]
    private var issueStateCache: [String: IssueState] = [:]

    init(token: String? = nil) {
        if let token = token {
            self.api = GitHubAPI(token: token)
        }
        startAutoRefreshIfNeeded()
    }

    private func startAutoRefreshIfNeeded() {
        let interval = UserDefaults.standard.double(forKey: UserPreferences.refreshIntervalKey)
        startAutoRefresh(interval: interval > 0 ? interval : 60)

        Task {
            await fetchNotifications()
        }
    }

    func configure(token: String) {
        self.api = GitHubAPI(token: token)
    }

    func fetchNotifications() async {
        guard let api = api else {
            errorMessage = "GitHub token not configured"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedNotifications = try await api.fetchNotifications()
            notifications = fetchedNotifications

            await loadNotificationStates()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadNotificationStates() async {
        guard let api = api else { return }

        // Collect notifications that need state loading
        var prRequests: [(cacheKey: String, owner: String, repo: String, number: Int)] = []
        var issueRequests: [(cacheKey: String, owner: String, repo: String, number: Int)] = []

        for notification in notifications {
            let owner = notification.repository.owner.login
            let repo = notification.repository.name

            switch notification.notificationType {
            case .pullRequest:
                if let number = notification.issueOrPRNumber {
                    let cacheKey = "\(owner)/\(repo)/pr/\(number)"
                    if prStateCache[cacheKey] == nil {
                        prRequests.append((cacheKey, owner, repo, number))
                    }
                }
            case .issue:
                if let number = notification.issueOrPRNumber {
                    let cacheKey = "\(owner)/\(repo)/issue/\(number)"
                    if issueStateCache[cacheKey] == nil {
                        issueRequests.append((cacheKey, owner, repo, number))
                    }
                }
            default:
                break
            }
        }

        // Fetch PR states concurrently
        await withTaskGroup(of: (String, PRState?).self) { group in
            for request in prRequests {
                group.addTask {
                    if let pr = try? await api.fetchPullRequest(
                        owner: request.owner,
                        repo: request.repo,
                        number: request.number
                    ) {
                        return (request.cacheKey, self.determinePRState(pr))
                    }
                    return (request.cacheKey, nil)
                }
            }

            for await (cacheKey, state) in group {
                if let state = state {
                    prStateCache[cacheKey] = state
                }
            }
        }

        // Fetch Issue states concurrently
        await withTaskGroup(of: (String, IssueState?).self) { group in
            for request in issueRequests {
                group.addTask {
                    if let issue = try? await api.fetchIssue(
                        owner: request.owner,
                        repo: request.repo,
                        number: request.number
                    ) {
                        return (request.cacheKey, self.determineIssueState(issue))
                    }
                    return (request.cacheKey, nil)
                }
            }

            for await (cacheKey, state) in group {
                if let state = state {
                    issueStateCache[cacheKey] = state
                }
            }
        }
    }

    func getPRState(for notification: GitHubNotification) -> PRState? {
        guard notification.notificationType == .pullRequest,
              let number = notification.issueOrPRNumber else {
            return nil
        }

        let owner = notification.repository.owner.login
        let repo = notification.repository.name
        let cacheKey = "\(owner)/\(repo)/pr/\(number)"

        return prStateCache[cacheKey]
    }

    func getIssueState(for notification: GitHubNotification) -> IssueState? {
        guard notification.notificationType == .issue,
              let number = notification.issueOrPRNumber else {
            return nil
        }

        let owner = notification.repository.owner.login
        let repo = notification.repository.name
        let cacheKey = "\(owner)/\(repo)/issue/\(number)"

        return issueStateCache[cacheKey]
    }

    func getNotificationBody(for notification: GitHubNotification) async -> String? {
        guard let api = api else { return nil }

        let owner = notification.repository.owner.login
        let repo = notification.repository.name
        guard let number = notification.issueOrPRNumber else { return nil }

        do {
            switch notification.notificationType {
            case .pullRequest:
                let pr = try await api.fetchPullRequest(owner: owner, repo: repo, number: number)
                return pr.body
            case .issue:
                let issue = try await api.fetchIssue(owner: owner, repo: repo, number: number)
                return issue.body
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    func markAsRead(notification: GitHubNotification) async {
        guard let api = api else { return }

        do {
            try await api.markNotificationAsRead(threadId: notification.id)
            notifications.removeAll { $0.id == notification.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        guard let api = api else { return }

        do {
            try await api.markAllNotificationsAsRead()
            notifications.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func smartMarkAsRead() async {
        guard let api = api else { return }

        var toMarkAsRead: [GitHubNotification] = []

        for notification in notifications {
            let prState = getPRState(for: notification)
            let issueState = getIssueState(for: notification)

            if filterOptions.shouldMarkAsRead(notification: notification, prState: prState, issueState: issueState) {
                toMarkAsRead.append(notification)
            }
        }

        for notification in toMarkAsRead {
            do {
                try await api.markNotificationAsRead(threadId: notification.id)
                notifications.removeAll { $0.id == notification.id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startAutoRefresh(interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchNotifications()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    nonisolated private func determinePRState(_ pr: PullRequest) -> PRState {
        if pr.merged {
            return .merged
        } else if pr.state == "closed" {
            return .closed
        } else if pr.draft {
            return .draft
        } else {
            return .open
        }
    }

    nonisolated private func determineIssueState(_ issue: Issue) -> IssueState {
        if issue.state == "closed" {
            if issue.stateReason == "completed" {
                return .closedCompleted
            } else {
                return .closedNotPlanned
            }
        } else {
            return .open
        }
    }
}
