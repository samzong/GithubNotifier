import SwiftUI

struct TabButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let icon: String
    var isSelected: Bool = false
    var showDot: Bool = false
    var namespace: Namespace.ID?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))

                if showDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 38, height: 32)
            .background { selectedBackground }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(Text(title))
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: isSelected
        )
    }

    @ViewBuilder private var selectedBackground: some View {
        if isSelected {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

            if let namespace {
                shape
                    .fill(Color.accentColor.opacity(0.2))
                    .matchedGeometryEffect(id: "activeTabBackground", in: namespace)
            } else {
                shape
                    .fill(Color.accentColor.opacity(0.2))
            }
        }
    }
}
