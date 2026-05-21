//
//  WindowIdentifier.swift
//  GitHubNotifier
//

import Foundation

/// Identifiers for auxiliary windows in the application.
/// New window types can be added here to extend functionality.
public enum WindowIdentifier: String, CaseIterable, Identifiable, Sendable {
    case searchManagement
    case monitorManagement

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .searchManagement:
            "Manage Saved Searches"
        case .monitorManagement:
            "Manage Monitors"
        }
    }

    public var defaultSize: (width: CGFloat, height: CGFloat) {
        switch self {
        case .searchManagement:
            (720, 520)
        case .monitorManagement:
            (760, 560)
        }
    }
}
