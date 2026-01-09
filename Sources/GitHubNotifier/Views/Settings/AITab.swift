import SwiftUI

struct AITab: View {
    let settingsWidth: CGFloat

    var body: some View {
        ComingSoonView(
            icon: "sparkles",
            iconColor: .purple,
            title: "settings.tab.ai".localized,
            settingsWidth: settingsWidth
        )
    }
}
