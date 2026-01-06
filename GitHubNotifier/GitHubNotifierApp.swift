//
//  GitHubNotifierApp.swift
//  GitHubNotifier
//
//  Created by X on 1/6/26.
//

import SwiftUI

@main
struct GitHubNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
