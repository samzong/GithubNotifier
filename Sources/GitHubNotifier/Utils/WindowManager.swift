//
//  WindowManager.swift
//  GitHubNotifier
//

import AppKit
import Foundation
import SwiftUI

/// Thread-safe singleton for managing auxiliary windows.
/// Provides a centralized way to open specific window types from anywhere in the app.
@MainActor
public final class WindowManager: ObservableObject {
    public static let shared = WindowManager()

    /// Currently requested window to open (used by WindowGroup scene)
    @Published public var activeWindow: WindowIdentifier?

    private init() {}

    /// Opens the specified auxiliary window.
    /// - Parameter window: The window type to open.
    public func open(_ window: WindowIdentifier) {
        activeWindow = window

        // Use NSWorkspace to open the window via URL scheme
        if let url = URL(string: "githubnotifier://window/\(window.rawValue)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Closes the auxiliary window if open.
    public func close() {
        activeWindow = nil
    }
}
