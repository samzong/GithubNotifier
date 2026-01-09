import SwiftUI

/// A ButtonStyle for list rows that provides native-feeling hover feedback.
/// Use this for consistent, HIG-compliant hover states across Notification and Activity rows.
struct ListRowButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering
                }
            }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            Color(nsColor: .quaternaryLabelColor)
        } else if isHovering {
            Color(nsColor: .quinaryLabel)
        } else {
            Color.clear
        }
    }
}

extension ButtonStyle where Self == ListRowButtonStyle {
    static var listRow: ListRowButtonStyle { ListRowButtonStyle() }
}
