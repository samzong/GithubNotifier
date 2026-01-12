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
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                if isSelected {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity),
                                    removal: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity)
                                )
                        )
                }

                if showDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, isSelected ? 10 : 8)
            .padding(.vertical, 6)
            .background {
                if isSelected, let namespace {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                        .matchedGeometryEffect(id: "activeTabBackground", in: namespace)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.1))
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: isSelected
        )
    }
}
