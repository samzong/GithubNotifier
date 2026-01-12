//
//  WindowView.swift
//  GitHubNotifier
//
//  Main entry point for auxiliary windows.
//  Routes to the appropriate sub-module view based on the active window identifier.
//

import GitHubNotifierCore
import SwiftUI

/// Main window view that functions as a shell for different sub-modules.
/// Similar to MenuBarView or SettingsView, it manages the top-level structure
/// and content switching for auxiliary windows.
struct WindowView: View {
    @Environment(SearchService.self) private var searchService
    @ObservedObject private var windowManager = WindowManager.shared

    var body: some View {
        Group {
            if let activeWindow = windowManager.activeWindow {
                contentView(for: activeWindow)
            } else {
                // Fallback: default to search management if opened without context
                SearchWindowView()
            }
        }
        .environment(searchService)
    }

    @ViewBuilder
    private func contentView(for window: WindowIdentifier) -> some View {
        switch window {
        case .searchManagement:
            SearchWindowView()
        }
    }
}
