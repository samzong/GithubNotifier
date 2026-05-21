import SwiftUI

struct ComingSoonView: View {
    let icon: String
    let title: String
    let settingsWidth: CGFloat

    var body: some View {
        PolishedEmptyStateView(
            title: title,
            message: "settings.coming_soon.subtitle".localized,
            systemImage: icon,
            accent: .secondary
        )
        .frame(width: settingsWidth, height: 300)
    }
}
