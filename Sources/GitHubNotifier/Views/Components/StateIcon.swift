import GitHubNotifierCore
import SwiftUI

struct StateIcon: View {
    let type: ItemType
    let state: ItemState

    enum ItemType { case issue, pullRequest }
    enum ItemState { case open, closed, merged, draft }

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch (type, state) {
        case (.issue, .open):
            "circle.dotted"
        case (.issue, .closed):
            "checkmark.circle"
        case (.issue, .merged), (.issue, .draft):
            "circle.dotted"
        case (.pullRequest, .open):
            "arrow.triangle.pull"
        case (.pullRequest, .merged):
            "arrow.triangle.merge"
        case (.pullRequest, .closed):
            "xmark.circle"
        case (.pullRequest, .draft):
            "circle.dashed"
        }
    }

    private var iconColor: Color {
        switch state {
        case .open: .green
        case .closed: .red
        case .merged: .purple
        case .draft: .secondary
        }
    }
}
