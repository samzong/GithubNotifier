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

    func testMonitorDefinitionUsesCustomDisplayName() {
        let definition = MonitorDefinition(target: .account(login: "samzong"), name: "Release Watch")

        XCTAssertEqual(definition.displayName, "Release Watch")
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

    func testRawEventsSinceCursorProcessesFetchedEventsWhenCursorIsMissing() {
        let events = [
            makeGitHubEvent(id: "event_newest", occurredAt: Date(timeIntervalSince1970: 200)),
            makeGitHubEvent(id: "event_older", occurredAt: Date(timeIntervalSince1970: 100)),
        ]

        let result = rawEventsSinceCursor(events, cursor: "event_missing")

        XCTAssertEqual(result.events.map(\.id), ["event_newest", "event_older"])
        XCTAssertEqual(result.nextCursor, "event_newest")
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

        let syncedAt = Date(timeIntervalSince1970: 1_779_350_100)
        store.recordSync(forMonitorId: monitorId, at: syncedAt)
        XCTAssertEqual(store.lastSyncedAt[monitorId], syncedAt)

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
    func testMonitorStorePersistsLastSyncedAt() {
        let suiteName = "MonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let monitorId = UUID()
        let syncedAt = Date(timeIntervalSince1970: 1_779_350_200)

        let store = MonitorStore(defaults: defaults)
        store.recordSync(forMonitorId: monitorId, at: syncedAt)

        let reloadedStore = MonitorStore(defaults: defaults)
        XCTAssertEqual(reloadedStore.lastSyncedAt[monitorId], syncedAt)
    }

    @MainActor
    func testMonitorEngineRecordsLastSyncedAfterSuccessfulSingleSync() async {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitor = MonitorDefinition(target: .account(login: "samzong"))
        store.addMonitor(monitor)

        let session = GitHubSession()
        session.configure(token: "test-token")

        let fetchedEvent = MonitorEvent(
            id: "\(monitor.id.uuidString):event_1",
            kind: "commit",
            targetId: monitor.id,
            actor: "octocat",
            repo: "owner/repo",
            title: "Pushed commit",
            url: "https://github.com/owner/repo/commit/1",
            occurredAt: Date(timeIntervalSince1970: 1_779_350_600)
        )
        let engine = MonitorEngine(
            session: session,
            store: store,
            sourceFactory: { target in
                XCTAssertEqual(target, monitor.target)
                return StubMonitorSource(
                    events: [fetchedEvent],
                    fetchedEvents: [fetchedEvent],
                    nextCursor: "cursor_after_sync"
                )
            }
        )

        await engine.sync(monitor: monitor)

        XCTAssertNotNil(store.lastSyncedAt[monitor.id])
        XCTAssertEqual(store.cursors[monitor.id], "cursor_after_sync")
        XCTAssertTrue(store.events.isEmpty)
    }

    @MainActor
    func testMonitorStoreClearsEventsForSingleMonitor() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitorId = UUID()
        let otherMonitorId = UUID()

        store.addEvents([
            MonitorEvent(
                id: "event_1",
                kind: "commit",
                targetId: monitorId,
                actor: "developer",
                repo: "org/repo",
                title: "Pushed commit",
                url: "https://github.com/org/repo/commit/1",
                occurredAt: Date()
            ),
            MonitorEvent(
                id: "event_2",
                kind: "issue",
                targetId: otherMonitorId,
                actor: "tester",
                repo: "org/other",
                title: "Opened issue",
                url: "https://github.com/org/other/issues/2",
                occurredAt: Date().addingTimeInterval(10)
            ),
        ])

        store.clearEvents(forMonitorId: monitorId)

        XCTAssertEqual(store.events.map(\.id), ["event_2"])
    }

    @MainActor
    func testMonitorStoreRemoveMonitorClearsEventsAndCursor() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitor = MonitorDefinition(target: .account(login: "samzong"))
        let otherMonitor = MonitorDefinition(target: .account(login: "octocat"))
        store.addMonitor(monitor)
        store.addMonitor(otherMonitor)
        store.saveCursor("cursor_123", forMonitorId: monitor.id)
        store.recordSync(forMonitorId: monitor.id, at: Date(timeIntervalSince1970: 1_779_350_300))
        store.addEvents([
            MonitorEvent(
                id: "event_1",
                kind: "commit",
                targetId: monitor.id,
                actor: "developer",
                repo: "org/repo",
                title: "Pushed commit",
                url: "https://github.com/org/repo/commit/1",
                occurredAt: Date()
            ),
            MonitorEvent(
                id: "event_2",
                kind: "issue",
                targetId: otherMonitor.id,
                actor: "tester",
                repo: "org/other",
                title: "Opened issue",
                url: "https://github.com/org/other/issues/2",
                occurredAt: Date().addingTimeInterval(10)
            ),
        ])

        store.removeMonitor(id: monitor.id)

        XCTAssertNil(store.monitors.first { $0.id == monitor.id })
        XCTAssertNil(store.cursors[monitor.id])
        XCTAssertNil(store.lastSyncedAt[monitor.id])
        XCTAssertEqual(store.events.map(\.id), ["event_2"])
    }

    @MainActor
    func testMonitorStoreUpdatesNameWithoutClearingState() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitor = MonitorDefinition(target: .account(login: "samzong"))
        store.addMonitor(monitor)
        let syncedAt = Date(timeIntervalSince1970: 1_779_350_400)
        store.saveCursor("cursor_123", forMonitorId: monitor.id)
        store.recordSync(forMonitorId: monitor.id, at: syncedAt)
        store.addEvents([
            MonitorEvent(
                id: "event_1",
                kind: "commit",
                targetId: monitor.id,
                actor: "developer",
                repo: "org/repo",
                title: "Pushed commit",
                url: "https://github.com/org/repo/commit/1",
                occurredAt: Date()
            ),
        ])

        XCTAssertTrue(store.updateMonitorDetails(id: monitor.id, target: monitor.target, name: "Core Watch"))

        XCTAssertEqual(store.monitors.first?.displayName, "Core Watch")
        XCTAssertEqual(store.cursors[monitor.id], "cursor_123")
        XCTAssertEqual(store.lastSyncedAt[monitor.id], syncedAt)
        XCTAssertEqual(store.events.map(\.id), ["event_1"])
    }

    @MainActor
    func testMonitorStoreUpdatesTargetAndClearsStaleState() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitor = MonitorDefinition(target: .account(login: "samzong"))
        store.addMonitor(monitor)
        store.saveCursor("cursor_123", forMonitorId: monitor.id)
        store.recordSync(forMonitorId: monitor.id, at: Date(timeIntervalSince1970: 1_779_350_500))
        store.addEvents([
            MonitorEvent(
                id: "event_1",
                kind: "commit",
                targetId: monitor.id,
                actor: "developer",
                repo: "org/repo",
                title: "Pushed commit",
                url: "https://github.com/org/repo/commit/1",
                occurredAt: Date()
            ),
        ])

        XCTAssertTrue(store.updateMonitorDetails(
            id: monitor.id,
            target: .repository(owner: "apple", name: "swift"),
            name: "Swift Watch"
        ))

        XCTAssertEqual(store.monitors.first?.target, .repository(owner: "apple", name: "swift"))
        XCTAssertEqual(store.monitors.first?.displayName, "Swift Watch")
        XCTAssertNil(store.cursors[monitor.id])
        XCTAssertNil(store.lastSyncedAt[monitor.id])
        XCTAssertTrue(store.events.isEmpty)
    }

    @MainActor
    func testMonitorStoreRejectsDuplicateTargetUpdates() {
        let (store, cleanup) = makeIsolatedStore()
        defer { cleanup() }

        let monitor = MonitorDefinition(target: .account(login: "samzong"))
        let otherMonitor = MonitorDefinition(target: .repository(owner: "apple", name: "swift"))
        store.addMonitor(monitor)
        store.addMonitor(otherMonitor)

        XCTAssertFalse(store.updateMonitorDetails(
            id: monitor.id,
            target: .repository(owner: "apple", name: "swift"),
            name: nil
        ))
        XCTAssertEqual(store.monitors.first { $0.id == monitor.id }?.target, .account(login: "samzong"))
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

    private func makeGitHubEvent(id: String, occurredAt: Date) -> GitHubEvent {
        GitHubEvent(
            id: id,
            type: "PushEvent",
            actor: .init(login: "octocat"),
            repo: .init(name: "owner/repo"),
            createdAt: occurredAt,
            payload: nil
        )
    }

    private struct StubMonitorSource: MonitorSource {
        let events: [MonitorEvent]
        let fetchedEvents: [MonitorEvent]
        let nextCursor: String?

        @MainActor
        func fetchEvents(
            definition _: MonitorDefinition,
            cursor _: String?,
            session _: GitHubSession
        ) async throws -> (events: [MonitorEvent], fetchedEvents: [MonitorEvent], nextCursor: String?) {
            (events, fetchedEvents, nextCursor)
        }
    }
}
