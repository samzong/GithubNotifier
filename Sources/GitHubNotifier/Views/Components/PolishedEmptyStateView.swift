import SwiftUI

struct PolishedEmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    let systemImage: String
    let accent: Color
    @ViewBuilder let actions: Actions

    init(
        title: String,
        message: String,
        systemImage: String,
        accent: Color = .accentColor,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accent = accent
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .liquidGlassSurface(cornerRadius: 16, tint: accent.opacity(0.06))

            VStack(spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
                .padding(.top, 2)
        }
        .frame(maxWidth: 290)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

extension PolishedEmptyStateView where Actions == EmptyView {
    init(
        title: String,
        message: String,
        systemImage: String,
        accent: Color = .accentColor
    ) {
        self.init(
            title: title,
            message: message,
            systemImage: systemImage,
            accent: accent,
            actions: { EmptyView() }
        )
    }
}
