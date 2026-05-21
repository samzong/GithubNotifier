//
//  MonitorEngine.swift
//  GitHubNotifierCore
//
//  Created by X on 5/21/26.
//

import Foundation
import Observation

/// The background scheduler that polls active monitors and triggers notifications.
@Observable
@MainActor
public final class MonitorEngine {
    private let session: GitHubSession
    private let store: MonitorStore
    private let notificationManager: NotificationManager?
    private let sourceFactory: @MainActor (MonitorTarget) -> MonitorSource?

    private var timer: Task<Void, Never>?
    public private(set) var isSyncing = false

    public init(
        session: GitHubSession,
        store: MonitorStore,
        notificationManager: NotificationManager? = nil,
        sourceFactory: (@MainActor (MonitorTarget) -> MonitorSource?)? = nil
    ) {
        self.session = session
        self.store = store
        self.notificationManager = notificationManager
        self.sourceFactory = sourceFactory ?? Self.defaultSource(for:)
    }

    /// Starts background polling with the specified interval.
    public func start(interval: TimeInterval = 300) {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncAll()
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    break
                }
            }
        }
    }

    /// Stops background polling.
    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Forces synchronization of all enabled monitors.
    public func syncAll() async {
        guard session.isAuthenticated, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let activeMonitors = store.monitors.filter(\.isEnabled)
        for monitor in activeMonitors {
            await sync(monitor: monitor)
        }
    }

    /// Synchronizes a single monitor.
    public func sync(monitor: MonitorDefinition) async {
        guard session.isAuthenticated else { return }
        guard let source = makeSource(for: monitor.target) else { return }

        let cursor = store.cursors[monitor.id]
        let isFirstSync = (cursor == nil)

        do {
            let (events, fetchedEvents, nextCursor) = try await source.fetchEvents(
                definition: monitor,
                cursor: cursor,
                session: session
            )
            store.repairEvents(using: fetchedEvents)
            store.recordSync(forMonitorId: monitor.id)

            if let nextCursor {
                store.saveCursor(nextCursor, forMonitorId: monitor.id)
            }

            if isFirstSync {
                // Baseline-first: initialize checkpoint without triggering notifications
                print("Baseline initialized for \(monitor.displayName)")
            } else {
                if !events.isEmpty {
                    store.addEvents(events)
                    if let notificationManager {
                        for event in events {
                            await notificationManager.sendMonitorNotification(for: event)
                        }
                    }
                }
            }
        } catch {
            print("Failed to sync monitor \(monitor.displayName): \(error)")
        }
    }

    private func makeSource(for target: MonitorTarget) -> MonitorSource? {
        sourceFactory(target)
    }

    private static func defaultSource(for target: MonitorTarget) -> MonitorSource? {
        switch target {
        case .account:
            AccountEventsMonitorSource()
        case .repository:
            RepositoryEventsMonitorSource()
        case .search:
            SavedSearchMonitorSource()
        case .code:
            CodeKeywordMonitorSource()
        }
    }
}
