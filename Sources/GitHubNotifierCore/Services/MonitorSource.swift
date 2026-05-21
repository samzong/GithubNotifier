//
//  MonitorSource.swift
//  GitHubNotifierCore
//
//  Created by X on 5/21/26.
//

import Foundation

/// Protocol representing a monitor source that can fetch new events.
public protocol MonitorSource: Sendable {
    /// Fetches events from the source.
    ///
    /// - Parameters:
    ///   - definition: The monitor definition.
    ///   - cursor: An optional checkpoint cursor from the last sync.
    ///   - session: The authenticated GitHub session.
    /// - Returns: New monitor events, all freshly fetched canonical events for repair, and the next cursor to store.
    @MainActor
    func fetchEvents(
        definition: MonitorDefinition,
        cursor: String?,
        session: GitHubSession
    ) async throws -> (events: [MonitorEvent], fetchedEvents: [MonitorEvent], nextCursor: String?)
}

// MARK: - Account Events Monitor Source

public struct AccountEventsMonitorSource: MonitorSource {
    public init() {}

    @MainActor
    public func fetchEvents(
        definition: MonitorDefinition,
        cursor: String?,
        session: GitHubSession
    ) async throws -> (events: [MonitorEvent], fetchedEvents: [MonitorEvent], nextCursor: String?) {
        guard case let .account(login) = definition.target else {
            return ([], [], cursor)
        }
        guard let restClient = session.restClient else {
            return ([], [], cursor)
        }

        let rawEvents = try await restClient.fetchUserEvents(username: login)
        let fetchedEvents = rawEvents.map { monitorEvent(from: $0, definition: definition) }
        let (eventsToProcess, nextCursor) = rawEventsSinceCursor(rawEvents, cursor: cursor)
        let filteredEvents = eventsToProcess.filter { event in
            let kind = event.monitorKind
            if let enabled = definition.eventToggles[kind] {
                return enabled
            }
            return true // default enabled
        }

        var monitorEvents = filteredEvents.map { monitorEvent(from: $0, definition: definition) }

        // Sort ascending (oldest first) to apply events sequentially
        monitorEvents.sort { $0.occurredAt < $1.occurredAt }

        return (monitorEvents, fetchedEvents, nextCursor)
    }
}

// MARK: - Repository Events Monitor Source

public struct RepositoryEventsMonitorSource: MonitorSource {
    public init() {}

    @MainActor
    public func fetchEvents(
        definition: MonitorDefinition,
        cursor: String?,
        session: GitHubSession
    ) async throws -> (events: [MonitorEvent], fetchedEvents: [MonitorEvent], nextCursor: String?) {
        guard case let .repository(owner, name) = definition.target else {
            return ([], [], cursor)
        }
        guard let restClient = session.restClient else {
            return ([], [], cursor)
        }

        let rawEvents = try await restClient.fetchRepoEvents(owner: owner, repo: name)
        let fetchedEvents = rawEvents.map { monitorEvent(from: $0, definition: definition) }
        let (eventsToProcess, nextCursor) = rawEventsSinceCursor(rawEvents, cursor: cursor)
        let filteredEvents = eventsToProcess.filter { event in
            let kind = event.monitorKind
            if let enabled = definition.eventToggles[kind] {
                return enabled
            }
            return true
        }

        var monitorEvents = filteredEvents.map { monitorEvent(from: $0, definition: definition) }

        monitorEvents.sort { $0.occurredAt < $1.occurredAt }

        return (monitorEvents, fetchedEvents, nextCursor)
    }
}

// MARK: - Saved Search Monitor Source

public struct SavedSearchMonitorSource: MonitorSource {
    public init() {}

    @MainActor
    public func fetchEvents(
        definition: MonitorDefinition,
        cursor: String?,
        session: GitHubSession
    ) async throws -> (events: [MonitorEvent], fetchedEvents: [MonitorEvent], nextCursor: String?) {
        guard case let .search(query, _) = definition.target else {
            return ([], [], cursor)
        }
        guard let graphqlClient = session.graphqlClient else {
            return ([], [], cursor)
        }

        let results = try await graphqlClient.search(query: query, first: 30)

        let latestDate = results.map(\.updatedAt).max()
        let nextCursor = latestDate.map { ISO8601DateFormatter().string(from: $0) } ?? cursor

        var monitorEvents: [MonitorEvent] = []

        if let cursor, let cursorDate = ISO8601DateFormatter().date(from: cursor) {
            let newItems = results.filter { $0.updatedAt > cursorDate }
            monitorEvents = newItems.map { item in
                let kind = item.itemType == .pullRequest ? "pr" : "issue"
                return MonitorEvent(
                    id: monitorEventId(definition: definition, sourceId: item.id),
                    kind: kind,
                    targetId: definition.id,
                    actor: item.authorLogin ?? "",
                    repo: item.repositoryFullName,
                    title: item.title,
                    url: item.webURL?.absoluteString ?? "",
                    occurredAt: item.updatedAt
                )
            }
        }

        return (monitorEvents, monitorEvents, nextCursor)
    }
}

// MARK: - Code Keyword Monitor Source

public struct CodeKeywordMonitorSource: MonitorSource {
    public init() {}

    @MainActor
    public func fetchEvents(
        definition: MonitorDefinition,
        cursor: String?,
        session: GitHubSession
    ) async throws -> (events: [MonitorEvent], fetchedEvents: [MonitorEvent], nextCursor: String?) {
        guard case let .code(query, _) = definition.target else {
            return ([], [], cursor)
        }
        guard let restClient = session.restClient else {
            return ([], [], cursor)
        }

        let result = try await restClient.searchCode(query: query)

        // Code search does not provide timestamps per item.
        // We will store the set of SHAs in the cursor (separated by comma) to perform diffing.
        let currentSHAs = result.items.map(\.sha)
        let nextCursor = currentSHAs.joined(separator: ",")

        var monitorEvents: [MonitorEvent] = []

        if let cursor {
            let previousSHAs = Set(cursor.components(separatedBy: ","))
            let newItems = result.items.filter { !previousSHAs.contains($0.sha) }

            monitorEvents = newItems.map { item in
                MonitorEvent(
                    id: monitorEventId(definition: definition, sourceId: item.sha),
                    kind: "code_match",
                    targetId: definition.id,
                    actor: "",
                    repo: item.repository.fullName,
                    title: "Code match found in \(item.name) (\(item.path))",
                    url: item.htmlUrl,
                    occurredAt: Date()
                )
            }
        }

        return (monitorEvents, monitorEvents, nextCursor)
    }
}

private func monitorEvent(from event: GitHubEvent, definition: MonitorDefinition) -> MonitorEvent {
    MonitorEvent(
        id: monitorEventId(definition: definition, sourceId: event.id),
        kind: event.monitorKind,
        targetId: definition.id,
        actor: event.actor.login,
        repo: event.repo.name,
        title: event.monitorTitle,
        url: event.monitorURL,
        occurredAt: event.createdAt
    )
}

private func rawEventsSinceCursor(_ rawEvents: [GitHubEvent], cursor: String?) -> (events: [GitHubEvent], nextCursor: String?) {
    let nextCursor = rawEvents.first?.id ?? cursor
    guard let cursor else {
        return (rawEvents, nextCursor)
    }
    guard let cursorIndex = rawEvents.firstIndex(where: { $0.id == cursor }) else {
        return ([], nextCursor)
    }
    return (Array(rawEvents.prefix(upTo: cursorIndex)), nextCursor)
}

private func monitorEventId(definition: MonitorDefinition, sourceId: String) -> String {
    "\(definition.id.uuidString):\(sourceId)"
}
