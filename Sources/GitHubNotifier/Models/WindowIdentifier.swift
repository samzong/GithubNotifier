//
//  WindowIdentifier.swift
//  GitHubNotifier
//

import Foundation

/// Identifiers for auxiliary windows in the application.
/// New window types can be added here to extend functionality.
public enum WindowIdentifier: String, CaseIterable, Identifiable, Sendable {
    case searchManagement

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .searchManagement:
            return "Manage Saved Searches"
        }
    }

    public var defaultSize: (width: CGFloat, height: CGFloat) {
        switch self {
        case .searchManagement:
            return (720, 520)
        }
    }
}
