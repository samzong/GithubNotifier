import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlassSurface(
        cornerRadius: CGFloat = 12,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            let glass = tint.map { Glass.regular.tint($0) } ?? .regular
            self.glassEffect(interactive ? glass.interactive() : glass, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    @ViewBuilder
    func liquidGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        } else if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func liquidGlassIconButtonStyle() -> some View {
        self.buttonStyle(.borderless)
    }

    @ViewBuilder
    func liquidSearchToolbarBehavior() -> some View {
        if #available(macOS 26.0, *) {
            self.searchToolbarBehavior(.automatic)
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidAutomaticScrollEdgeEffect(for edges: Edge.Set = .all) -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.automatic, for: edges)
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidWindowBackground() -> some View {
        if #available(macOS 26.0, *) {
            self.containerBackground(.ultraThickMaterial, for: .window)
        } else {
            self.background(.ultraThickMaterial)
        }
    }

    @ViewBuilder
    func liquidReadableWindowBackground() -> some View {
        if #available(macOS 26.0, *) {
            self
                .containerBackground(.ultraThickMaterial, for: .window)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
        } else {
            self.background(Color(nsColor: .windowBackgroundColor))
        }
    }
}
