import SwiftUI

/// A fixed highlight under the content: no animation, blur or offscreen drawing group.
struct TileSurface: View {
    let fill: Color
    var cornerRadius: CGFloat = 18
    @AppStorage("TileSheenEnabled") private var sheenEnabled = true
    @AppStorage("TileLightingEnabled") private var lightingEnabled = true
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                if (sheenEnabled || lightingEnabled) && contrast != .increased {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(stops: [
                            .init(color: .white.opacity(lightingEnabled ? (sheenEnabled ? 0.18 : 0.12) : 0.12), location: 0),
                            .init(color: .white.opacity(lightingEnabled ? 0.06 : 0.04), location: 0.35),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(lightingEnabled ? 0.07 : 0.04), location: 1)
                        ], startPoint: lightingEnabled ? .topTrailing : .topLeading,
                           endPoint: lightingEnabled ? .bottomLeading : .bottomTrailing))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}


/// The light itself remains outside the screen; only a faint wash enters the scene.
struct SceneLight: View {
    @AppStorage("TileLightingEnabled") private var enabled = true
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if enabled && contrast != .increased {
            GeometryReader { geometry in
                Rectangle().fill(RadialGradient(
                    colors: [.white.opacity(0.08), .white.opacity(0.025), .clear],
                    center: UnitPoint(x: 1.12, y: -0.12),
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 1.15))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
