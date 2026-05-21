//
//  MonitorStore.swift
//  GitHubNotifierCore
//
//  Created by X on 5/21/26.
//

import Foundation

/// Stores and manages monitor definitions, sync cursors, and local monitor events.
@Observable
@MainActor
public final class MonitorStore {
    public private(set) var monitors: [MonitorDefinition] = []
    public private(set) var events: [MonitorEvent] = []
    public private(set) var cursors: [UUID: String] = [:]

    private let defaults: UserDefaults
    private let keyPrefix: String

    private var monitorsKey: String { "\(keyPrefix)monitor_definitions" }
    private var eventsKey: String { "\(keyPrefix)monitor_events" }
    private var cursorsKey: String { "\(keyPrefix)monitor_cursors" }

    public init(defaults: UserDefaults = .standard, keyPrefix: String = "") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        loadFromStorage()
    }

    /// Adds a new monitor definition.
    @discardableResult
    public func addMonitor(_ definition: MonitorDefinition) -> Bool {
        let targetId = definition.target.idString
        if monitors.contains(where: { $0.target.idString == targetId }) {
            return false
        }
        monitors.append(definition)
        saveMonitors()
        return true
    }

    /// Removes a monitor definition and its associated cursor and events.
    public func removeMonitor(id: UUID) {
        monitors.removeAll { $0.id == id }
        events.removeAll { $0.targetId == id }
        cursors.removeValue(forKey: id)
        saveMonitors()
        saveEvents()
        saveCursors()
    }

    /// Updates the enabled state of a monitor.
    public func updateMonitor(id: UUID, isEnabled: Bool) {
        if let index = monitors.firstIndex(where: { $0.id == id }) {
            monitors[index].isEnabled = isEnabled
            saveMonitors()
        }
    }

    /// Updates event filters toggle configurations.
    public func updateMonitorToggles(id: UUID, toggles: [String: Bool]) {
        if let index = monitors.firstIndex(where: { $0.id == id }) {
            monitors[index].eventToggles = toggles
            saveMonitors()
        }
    }

    /// Saves the sync cursor/checkpoint for a given monitor.
    public func saveCursor(_ cursor: String, forMonitorId monitorId: UUID) {
        cursors[monitorId] = cursor
        saveCursors()
    }

    /// Appends new events, filtering duplicates.
    public func addEvents(_ newEvents: [MonitorEvent]) {
        guard !newEvents.isEmpty else { return }

        var existingIds = Set(events.map(\.id))
        var added = false

        for event in newEvents where !existingIds.contains(event.id) {
            events.append(event)
            existingIds.insert(event.id)
            added = true
        }

        if added {
            events.sort { $0.occurredAt > $1.occurredAt }
            // Cap local inbox history
            if events.count > 500 {
                events = Array(events.prefix(500))
            }
            saveEvents()
        }
    }

    /// Repairs stored monitor events from freshly fetched canonical source events.
    public func repairEvents(using canonicalEvents: [MonitorEvent]) {
        guard !canonicalEvents.isEmpty, !events.isEmpty else { return }

        var exactMatches: [String: MonitorEvent] = [:]
        var legacyMatches: [String: MonitorEvent] = [:]
        for canonicalEvent in canonicalEvents {
            exactMatches[canonicalEvent.id] = canonicalEvent
            legacyMatches["\(canonicalEvent.targetId.uuidString):\(sourceId(from: canonicalEvent.id))"] = canonicalEvent
        }

        var repairedEvents: [MonitorEvent] = []
        var didRepair = false

        for event in events {
            let canonical = exactMatches[event.id] ?? legacyMatches["\(event.targetId.uuidString):\(event.id)"]
            guard let canonical else {
                repairedEvents.append(event)
                continue
            }

            let repaired = MonitorEvent(
                id: canonical.id,
                kind: canonical.kind,
                targetId: canonical.targetId,
                actor: canonical.actor,
                repo: canonical.repo,
                title: canonical.title,
                url: canonical.url,
                occurredAt: canonical.occurredAt,
                isRead: event.isRead
            )
            repairedEvents.append(repaired)
            didRepair = didRepair || repaired != event
        }

        if didRepair {
            events = repairedEvents.sorted { $0.occurredAt > $1.occurredAt }
            saveEvents()
        }
    }

    /// Marks an event as read.
    public func markEventRead(id: String) {
        if let index = events.firstIndex(where: { $0.id == id }) {
            events[index].isRead = true
            saveEvents()
        }
    }

    /// Marks all events as read.
    public func markAllEventsRead() {
        for index in events.indices {
            events[index].isRead = true
        }
        saveEvents()
    }

    /// Clears all events.
    public func clearEvents() {
        events = []
        saveEvents()
    }

    // MARK: - Persistence

    private func saveMonitors() {
        if let data = try? JSONEncoder().encode(monitors) {
            defaults.set(data, forKey: monitorsKey)
        }
    }

    private func saveEvents() {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: eventsKey)
        }
    }

    private func saveCursors() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: cursors.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: cursorsKey)
        }
    }

    private func loadFromStorage() {
        if let data = defaults.data(forKey: monitorsKey),
           let decoded = try? JSONDecoder().decode([MonitorDefinition].self, from: data) {
            self.monitors = decoded
        }

        if let data = defaults.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([MonitorEvent].self, from: data) {
            self.events = decoded
            repairLegacyStoredEvents()
        }

        if let data = defaults.data(forKey: cursorsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.cursors = Dictionary(uniqueKeysWithValues: decoded.compactMap { item in
                guard let uuid = UUID(uuidString: item.key) else { return nil }
                return (uuid, item.value)
            })
        }
    }

    private func repairLegacyStoredEvents() {
        var didRepair = false
        events = events.map { event in
            if let repairedEvent = repairedLegacyActivityEvent(event) {
                didRepair = true
                return repairedEvent
            }

            let repoHomeURL = "https://github.com/\(event.repo)"
            guard event.kind == "commit", event.url == repoHomeURL else {
                return event
            }

            didRepair = true
            return MonitorEvent(
                id: event.id,
                kind: event.kind,
                targetId: event.targetId,
                actor: event.actor,
                repo: event.repo,
                title: event.title,
                url: "\(repoHomeURL)/commits",
                occurredAt: event.occurredAt,
                isRead: event.isRead
            )
        }

        if didRepair {
            saveEvents()
        }
    }

    private func repairedLegacyActivityEvent(_ event: MonitorEvent) -> MonitorEvent? {
        guard event.kind == "activity" else { return nil }

        switch event.title {
        case "Triggered PushEvent activity":
            let repoHomeURL = "https://github.com/\(event.repo)"
            let url = event.url == repoHomeURL ? "\(repoHomeURL)/commits" : event.url
            return legacyEvent(from: event, kind: "commit", title: "Pushed commits to repository", url: url)
        case "Triggered IssueCommentEvent activity":
            return legacyEvent(from: event, kind: "comment", title: "Commented on issue", url: event.url)
        case "Triggered PullRequestReviewCommentEvent activity":
            return legacyEvent(from: event, kind: "comment", title: "Commented on pull request", url: event.url)
        case "Triggered CommitCommentEvent activity":
            return legacyEvent(from: event, kind: "comment", title: "Commented on commit", url: event.url)
        default:
            return nil
        }
    }

    private func legacyEvent(from event: MonitorEvent, kind: String, title: String, url: String) -> MonitorEvent {
        MonitorEvent(
            id: event.id,
            kind: kind,
            targetId: event.targetId,
            actor: event.actor,
            repo: event.repo,
            title: title,
            url: url,
            occurredAt: event.occurredAt,
            isRead: event.isRead
        )
    }

    private func sourceId(from eventId: String) -> String {
        guard let separatorIndex = eventId.firstIndex(of: ":") else {
            return eventId
        }
        return String(eventId[eventId.index(after: separatorIndex)...])
    }
}
