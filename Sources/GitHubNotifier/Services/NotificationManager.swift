//
//  NotificationManager.swift
//  GitHubNotifier
//
//  Created on 2026-01-07.
//

import AppKit
import Foundation
import UserNotifications

@MainActor
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    weak var notificationService: NotificationService?

    override private init() {
        super.init()
        notificationCenter.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    func sendNotification(for notification: GitHubNotification) async {
        guard UserDefaults.standard.bool(forKey: "enableSystemNotifications") else {
            return
        }

        let status = await checkAuthorizationStatus()
        guard status == .authorized else {
            return
        }

        let content = UNMutableNotificationContent()

        let typeName = notification.notificationType.displayName
        content.title = "\(typeName) - \(notification.repository.fullName)"

        content.subtitle = notification.subject.title

        var bodyParts: [String] = []

        let reasonText = formatReason(notification.reason)
        bodyParts.append(reasonText)

        let timeText = notification.updatedAt.timeAgo()
        bodyParts.append(timeText)

        content.body = bodyParts.joined(separator: " • ")

        content.sound = .default

        var userInfo: [String: Any] = ["notificationId": notification.id]
        if let htmlURL = buildHTMLURL(for: notification) {
            userInfo["url"] = htmlURL
        }
        content.userInfo = userInfo

        let identifier = notification.id
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }

    func sendNotifications(for notifications: [GitHubNotification]) async {
        let limit = 5

        let limitedNotifications = Array(notifications.prefix(limit))

        for notification in limitedNotifications {
            await sendNotification(for: notification)
        }

        if notifications.count > limit {
            await sendSummaryNotification(remainingCount: notifications.count - limit)
        }
    }

    private func sendSummaryNotification(remainingCount: Int) async {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.summary.title", comment: "")
        content.body = String(format: NSLocalizedString("notification.summary.body", comment: ""), remainingCount)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "summary-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        try? await notificationCenter.add(request)
    }

    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    func clearNotification(withId id: String) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func sendTestNotification() async {
        let status = await checkAuthorizationStatus()
        guard status == .authorized else {
            print("Notification permission not granted")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.test.title", comment: "")
        content.subtitle = NSLocalizedString("notification.test.subtitle", comment: "")
        content.body = NSLocalizedString("notification.test.body", comment: "")
        content.sound = .default

        content.userInfo = ["url": "https://github.com/notifications"]

        let identifier = "test-notification-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
            print("Test notification sent successfully")
        } catch {
            print("Failed to send test notification: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            let userInfo = response.notification.request.content.userInfo

            if let urlString = userInfo["url"] as? String,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }

            if let notificationId = userInfo["notificationId"] as? String {
                await self.markNotificationAsRead(notificationId)
            }

            completionHandler()
        }
    }

    private func markNotificationAsRead(_ notificationId: String) async {
        guard let service = notificationService else {
            print("NotificationService not available")
            return
        }

        if let notification = service.notifications.first(where: { $0.id == notificationId }) {
            await service.markAsRead(notification: notification)
            print("Notification marked as read: \(notificationId)")
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Helper Methods

    private func buildHTMLURL(for notification: GitHubNotification) -> String? {
        let owner = notification.repository.owner.login
        let repo = notification.repository.name

        switch notification.notificationType {
        case .pullRequest, .issue:
            guard let number = notification.issueOrPRNumber else {
                return notification.repository.htmlUrl
            }
            let type = notification.notificationType == .pullRequest ? "pull" : "issues"
            return "https://github.com/\(owner)/\(repo)/\(type)/\(number)"
        default:
            return notification.repository.htmlUrl
        }
    }

    private func formatReason(_ reason: String) -> String {
        switch reason {
        case "assign":
            NSLocalizedString("notification.reason.assign", comment: "")
        case "author":
            NSLocalizedString("notification.reason.author", comment: "")
        case "comment":
            NSLocalizedString("notification.reason.comment", comment: "")
        case "ci_activity":
            NSLocalizedString("notification.reason.ci_activity", comment: "")
        case "invitation":
            NSLocalizedString("notification.reason.invitation", comment: "")
        case "manual":
            NSLocalizedString("notification.reason.manual", comment: "")
        case "mention":
            NSLocalizedString("notification.reason.mention", comment: "")
        case "review_requested":
            NSLocalizedString("notification.reason.review_requested", comment: "")
        case "security_alert":
            NSLocalizedString("notification.reason.security_alert", comment: "")
        case "state_change":
            NSLocalizedString("notification.reason.state_change", comment: "")
        case "subscribed":
            NSLocalizedString("notification.reason.subscribed", comment: "")
        case "team_mention":
            NSLocalizedString("notification.reason.team_mention", comment: "")
        default:
            reason.capitalized
        }
    }
}
