import GitHubNotifierCore
import SwiftUI

struct CIStatusBadge: View {
    let status: CIStatus

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: iconName)
                .font(.system(size: 9))
            if status.checks.count > 1 {
                Text("\(status.checks.count)")
                    .font(.system(size: 9))
            }
        }
        .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch status.state.uppercased() {
        case "SUCCESS": "checkmark.circle.fill"
        case "FAILURE", "ERROR": "xmark.circle.fill"
        case "PENDING": "clock.fill"
        default: "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch status.state.uppercased() {
        case "SUCCESS": .green
        case "FAILURE", "ERROR": .red
        case "PENDING": .orange
        default: .secondary
        }
    }
}
