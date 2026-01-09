import SwiftUI

struct RulesTab: View {
    let settingsWidth: CGFloat

    var body: some View {
        ComingSoonView(
            icon: "slider.horizontal.3",
            iconColor: .orange,
            title: "settings.tab.rules".localized,
            settingsWidth: settingsWidth
        )
    }
}
