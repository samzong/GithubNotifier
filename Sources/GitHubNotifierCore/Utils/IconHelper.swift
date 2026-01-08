//
//  IconHelper.swift
//  GitHubNotifier
//
//  Utility for consolidating icon rendering logic across views.
//  Provides centralized icon creation and notification icon rendering to maintain consistency.
//

import AppKit
import SwiftUI

public enum IconHelper {
    /// Creates a template icon from the asset catalog.
    ///
    /// - Parameters:
    ///   - name: The name of the image asset
    ///   - size: The desired size for the icon (width and height)
    /// - Returns: An NSImage configured as a template, or nil if the asset doesn't exist
    public static func templateIcon(named name: String, size: CGFloat) -> NSImage? {
        guard let image = NSImage(named: name) else {
            return nil
        }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }

    /// Renders a notification icon based on notification type and current state.
    ///
    /// Displays different icons and colors depending on whether the notification is a PR or Issue,
    /// and reflects the current state (open, closed, merged, etc.). Falls back to generic icons
    /// when specific state information is unavailable.
    ///
    /// - Parameters:
    ///   - notification: The GitHub notification to render an icon for
    ///   - prState: The pull request state, if applicable
    ///   - issueState: The issue state, if applicable
    ///   - size: The desired icon size in points
    /// - Returns: A view containing the appropriate icon with correct styling
    @ViewBuilder
    public static func notificationIcon(
        for notification: GitHubNotification,
        prState: PRState?,
        issueState: IssueState?,
        size: CGFloat
    ) -> some View {
        let fontSize = size - 2

        switch notification.notificationType {
        case .pullRequest:
            if let state = prState {
                if let image = templateIcon(named: state.iconAssetName, size: size) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundStyle(state.color)
                        .frame(width: size, height: size)
                } else {
                    Image(systemName: state.icon)
                        .font(.system(size: fontSize))
                        .foregroundStyle(state.color)
                        .frame(width: size, height: size)
                }
            } else {
                fallbackIcon(for: notification, size: size, fontSize: fontSize)
            }
        case .issue:
            if let state = issueState {
                if let image = templateIcon(named: state.iconAssetName, size: size) {
                    Image(nsImage: image)
                        .renderingMode(.template)
                        .foregroundStyle(state.color)
                        .frame(width: size, height: size)
                } else {
                    Image(systemName: state.icon)
                        .font(.system(size: fontSize))
                        .foregroundStyle(state.color)
                        .frame(width: size, height: size)
                }
            } else {
                fallbackIcon(for: notification, size: size, fontSize: fontSize)
            }
        default:
            Image(systemName: notification.notificationType.icon)
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }

    /// Renders a fallback icon when specific state information is unavailable.
    ///
    /// - Parameters:
    ///   - notification: The GitHub notification to render a fallback icon for
    ///   - size: The desired icon size in points
    ///   - fontSize: The font size for system icons
    /// - Returns: A view containing the fallback icon with secondary styling
    @ViewBuilder
    private static func fallbackIcon(for notification: GitHubNotification, size: CGFloat, fontSize: CGFloat) -> some View {
        if let assetName = notification.notificationType.iconAssetName,
           let image = templateIcon(named: assetName, size: size) {
            Image(nsImage: image)
                .renderingMode(.template)
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        } else {
            Image(systemName: notification.notificationType.icon)
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}
