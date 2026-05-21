import XCTest
@testable import GitHubNotifier
@testable import GitHubNotifierCore

final class MonitorTests: XCTestCase {

    // MARK: - Target Parsing Tests

    func testMonitorTargetParsing() {
        let targetUser1 = MonitorTarget.parse(input: "samzong", type: "account")
        XCTAssertEqual(targetUser1, .account(login: "samzong"))

        let targetUser2 = MonitorTarget.parse(input: "@google", type: "account")
        XCTAssertEqual(targetUser2, .account(login: "google"))

        let targetUserURL = MonitorTarget.parse(input: "https://github.com/apple", type: "account")
        XCTAssertEqual(targetUserURL, .account(login: "apple"))

        let targetRepo1 = MonitorTarget.parse(input: "samzong/GithubNotifier", type: "repository")
        XCTAssertEqual(targetRepo1, .repository(owner: "samzong", name: "GithubNotifier"))

        let targetRepoURL = MonitorTarget.parse(input: "https://github.com/apple/swift", type: "repository")
        XCTAssertEqual(targetRepoURL, .repository(owner: "apple", name: "swift"))

        let targetSearch = MonitorTarget.parse(input: "is:pr is:open", type: "search", name: "My PRs")
        XCTAssertEqual(targetSearch, .search(query: "is:pr is:open", name: "My PRs"))

        let targetCode = MonitorTarget.parse(input: "TODO: fix", type: "code", name: "Fix Todo")
        XCTAssertEqual(targetCode, .code(query: "TODO: fix", name: "Fix Todo"))

        let targetInvalidURL = MonitorTarget.parse(input: "https://google.com/apple/swift", type: "repository")
        XCTAssertNil(targetInvalidURL)
    }

    func testGitHubEventDecodesPullRequestURLForNotificationClick() throws {
        let json = """
        {
          "id": "event_123",
          "type": "PullRequestEvent",
          "actor": { "login": "octocat" },
          "repo": { "name": "owner/repo" },
          "created_at": "2026-05-21T06:30:00Z",
          "payload": {
            "action": "opened",
            "pull_request": {
              "title": "Fix notification URL",
              "html_url": "https://github.com/owner/repo/pull/42"
            }
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(GitHubEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event.monitorKind, "pr")
        XCTAssertEqual(event.monitorURL, "https://github.com/owner/repo/pull/42")
        XCTAssertEqual(event.monitorTitle, "Opened PR: Fix notification URL")
    }

    func testGitHubEventBuildsPushCommitURLForNotificationClick() throws {
        let json = """
        {
          "id": "event_456",
          "type": "PushEvent",
          "actor": { "login": "octocat" },
          "repo": { "name": "owner/repo" },
          "created_at": "2026-05-21T06:35:00Z",
          "payload": {
            "commits": [
              {
                "sha": "abc123",
                "message": "Fix monitor click target"
              }
            ]
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(GitHubEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event.monitorKind, "commit")
        XCTAssertEqual(event.monitorURL, "https://github.com/owner/repo/commit/abc123")
        XCTAssertEqual(event.monitorTitle, "Pushed commit: Fix monitor click target")
    }

    func testGitHubEventUsesIssueCommentURLForNotificationClick() throws {
        let json = """
        {
          "id": "event_789",
          "type": "IssueCommentEvent",
          "actor": { "login": "octocat" },
          "repo": { "name": "owner/repo" },
          "created_at": "2026-05-21T06:40:00Z",
          "payload": {
            "action": "created",
            "issue": {
              "title": "Fix monitor links",
              "html_url": "https://github.com/owner/repo/issues/7"
            },
            "comment": {
              "body": "The notification should open this comment.",
              "html_url": "https://github.com/owner/repo/issues/7#issuecomment-123"
            }
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(GitHubEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event.monitorKind, "comment")
        XCTAssertEqual(event.monitorURL, "https://github.com/owner/repo/issues/7#issuecomment-123")
        XCTAssertEqual(event.monitorTitle, "Commented on: Fix monitor links")
    }

    func testGitHubEventBuildsPushHeadURLWhenCommitsAreMissing() throws {
        let json = """
        {
          "id": "event_999",
          "type": "PushEvent",
          "actor": { "login": "octocat" },
          "repo": { "name": "owner/repo" },
          "created_at": "2026-05-21T06:45:00Z",
          "payload": {
            "head": "def456"
          }
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try decoder.decode(GitHubEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event.monitorKind, "commit")
        XCTAssertEqual(event.monitorURL, "https://github.com/owner/repo/commit/def456")
        XCTAssertEqual(event.monitorTitle, "Pushed commits to repository")
    }

    // MARK: - Store Tests

    @MainActor
    func testMonitorStoreLifecycle() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        XCTAssertTrue(store.monitors.isEmpty)

        let def1 = MonitorDefinition(target: .account(login: "samzong"))
        let def2 = MonitorDefinition(target: .repository(owner: "apple", name: "swift"))

        store.addMonitor(def1)
        XCTAssertEqual(store.monitors.count, 1)

        store.addMonitor(MonitorDefinition(target: .account(login: "samzong")))
        XCTAssertEqual(store.monitors.count, 1)

        store.addMonitor(def2)
        XCTAssertEqual(store.monitors.count, 2)

        store.updateMonitor(id: def1.id, isEnabled: false)
        XCTAssertFalse(store.monitors.first(where: { $0.id == def1.id })?.isEnabled ?? true)

        store.removeMonitor(id: def1.id)
        XCTAssertEqual(store.monitors.count, 1)
        XCTAssertNil(store.monitors.first(where: { $0.id == def1.id }))

        store.removeMonitor(id: def2.id)
    }

    @MainActor
    func testMonitorStoreEventsAndCursors() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitorId = UUID()

        store.saveCursor("cursor_123", forMonitorId: monitorId)
        XCTAssertEqual(store.cursors[monitorId], "cursor_123")

        let event1 = MonitorEvent(
            id: "event_1",
            kind: "commit",
            targetId: monitorId,
            actor: "developer",
            repo: "org/repo",
            title: "Pushed commit",
            url: "https://github.com/org/repo/commit/1",
            occurredAt: Date()
        )

        let event2 = MonitorEvent(
            id: "event_2",
            kind: "issue",
            targetId: monitorId,
            actor: "tester",
            repo: "org/repo",
            title: "Opened issue",
            url: "https://github.com/org/repo/issues/2",
            occurredAt: Date().addingTimeInterval(10)
        )

        store.addEvents([event1, event2])
        XCTAssertEqual(store.events.count, 2)

        XCTAssertEqual(store.events.first?.id, "event_2")

        store.addEvents([event1])
        XCTAssertEqual(store.events.count, 2)

        XCTAssertFalse(store.events[0].isRead)
        store.markEventRead(id: "event_2")
        XCTAssertTrue(store.events.first(where: { $0.id == "event_2" })?.isRead ?? false)

        store.markAllEventsRead()
        XCTAssertTrue(store.events.allSatisfy(\.isRead))

        store.clearEvents()
        XCTAssertTrue(store.events.isEmpty)
    }

    @MainActor
    func testMonitorStoreRepairsLegacyEventURLUsingCanonicalEvent() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitorId = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_779_349_500)
        let legacyEvent = MonitorEvent(
            id: "event_999",
            kind: "commit",
            targetId: monitorId,
            actor: "octocat",
            repo: "owner/repo",
            title: "Triggered PushEvent activity",
            url: "https://github.com/owner/repo",
            occurredAt: occurredAt,
            isRead: true
        )
        let canonicalEvent = MonitorEvent(
            id: "\(monitorId.uuidString):event_999",
            kind: "commit",
            targetId: monitorId,
            actor: "octocat",
            repo: "owner/repo",
            title: "Pushed commits to repository",
            url: "https://github.com/owner/repo/commit/def456",
            occurredAt: occurredAt
        )

        store.addEvents([legacyEvent])
        store.repairEvents(using: [canonicalEvent])

        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events[0].id, "\(monitorId.uuidString):event_999")
        XCTAssertEqual(store.events[0].url, "https://github.com/owner/repo/commit/def456")
        XCTAssertEqual(store.events[0].title, "Pushed commits to repository")
        XCTAssertTrue(store.events[0].isRead)
    }

    @MainActor
    func testMonitorStoreRepairsLegacyPushHomepageURLOnLoad() throws {
        let suiteName = "MonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let legacyEvent = MonitorEvent(
            id: "event_999",
            kind: "commit",
            targetId: UUID(),
            actor: "octocat",
            repo: "owner/repo",
            title: "Pushed commits to repository",
            url: "https://github.com/owner/repo",
            occurredAt: Date(timeIntervalSince1970: 1_779_349_500)
        )
        defaults.set(try JSONEncoder().encode([legacyEvent]), forKey: "monitor_events")

        let store = MonitorStore(defaults: defaults)

        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events[0].url, "https://github.com/owner/repo/commits")
    }

    @MainActor
    func testMonitorStoreRepairsLegacyActivityPushHomepageURLOnLoad() throws {
        let suiteName = "MonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let legacyEvent = MonitorEvent(
            id: "event_999",
            kind: "activity",
            targetId: UUID(),
            actor: "octocat",
            repo: "owner/repo",
            title: "Triggered PushEvent activity",
            url: "https://github.com/owner/repo",
            occurredAt: Date(timeIntervalSince1970: 1_779_349_500),
            isRead: true
        )
        defaults.set(try JSONEncoder().encode([legacyEvent]), forKey: "monitor_events")

        let store = MonitorStore(defaults: defaults)

        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events[0].kind, "commit")
        XCTAssertEqual(store.events[0].title, "Pushed commits to repository")
        XCTAssertEqual(store.events[0].url, "https://github.com/owner/repo/commits")
        XCTAssertTrue(store.events[0].isRead)
    }

    @MainActor
    func testMonitorStoreRepairsLegacyIssueCommentActivityOnLoad() throws {
        let suiteName = "MonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let legacyEvent = MonitorEvent(
            id: "event_789",
            kind: "activity",
            targetId: UUID(),
            actor: "octocat",
            repo: "owner/repo",
            title: "Triggered IssueCommentEvent activity",
            url: "https://github.com/owner/repo/issues/7",
            occurredAt: Date(timeIntervalSince1970: 1_779_349_500)
        )
        defaults.set(try JSONEncoder().encode([legacyEvent]), forKey: "monitor_events")

        let store = MonitorStore(defaults: defaults)

        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.events[0].kind, "comment")
        XCTAssertEqual(store.events[0].title, "Commented on issue")
        XCTAssertEqual(store.events[0].url, "https://github.com/owner/repo/issues/7")
    }

    @MainActor
    private func makeIsolatedStore() -> (MonitorStore, () -> Void) {
        let suiteName = "MonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = MonitorStore(defaults: defaults)
        return (store, {
            defaults.removePersistentDomain(forName: suiteName)
        })
    }
}
