import SwiftUI

struct ComingSoonView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let settingsWidth: CGFloat

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text("settings.coming_soon.title".localized)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                Text("settings.coming_soon.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(width: settingsWidth, height: 300)
    }
}
