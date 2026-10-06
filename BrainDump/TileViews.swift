import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

struct TileView: View {
    let index: Int
    let text: String
    let isSelected: Bool
    let isEditing: Bool
    let isNewTile: Bool
    let isDeleting: Bool
    let isCompleting: Bool
    let focusRequestId: UUID
    let orientation: Quaternion
    let containerSize: CGSize
    let totalCount: Int
    let sphereScale: Double
    let tagId: Int
    let tagManager: TagManager
    let onTap: () -> Void
    let isTapEnabled: Bool
    let onTextChange: (String) -> Void
    let isTagChanging: Bool

    // Filter mode parameters
    let isFiltered: Bool
    let listPosition: Int?
    let filteredIndices: [Int]?

    var fillColor: Color? = nil
    var borderColor: Color? = nil
    var thumbnailURL: URL? = nil
    var onLongPress: (() -> Void)? = nil
    var isDiscarding = false
    var sphereIndex: Int? = nil
    var sphereFlightPosition: CGPoint? = nil
    var isDemo = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage("SphereEdgeBlurEnabled") private var sphereEdgeBlurEnabled = true
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var previewFont: CGFloat = 16
    @FocusState private var isFocused: Bool
    @State private var thumbnail: UIImage?
    @State private var materialised = false
    @State private var completionFlight = false
    private let tileSize: CGFloat = 112

    private func textColor(for fill: Color) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let color = UIColor(fill).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return .primary }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return luminance > 0.179 ? .black : .white
    }

    private func computeLayout() -> (position: CGPoint, scale: CGFloat, opacity: Double, zIndex: Double, edgeBlur: CGFloat) {
        if isFiltered, filteredIndices != nil {
            // List mode: tiles are in a ScrollView, so we don't use absolute positioning
            // The VStack handles vertical positioning, we just center horizontally
            let position = CGPoint(x: containerSize.width / 2, y: 0)
            let baseScale: CGFloat = isSelected ? 1.4 : 1.0
            let scale: CGFloat = baseScale + (isNewTile ? 0.18 : 0.0)
            let opacity: Double = 1.0
            // Ensure the centered/selected tile is always above other list tiles
            let zIndex: Double = isSelected ? 5000 : 0
            return (position, scale, opacity, zIndex, 0)
        }

        // Sphere mode: use normal sphere calculations
        let point3D = SphereMath.generatePoint(index: sphereIndex ?? index, total: totalCount)
        let rotatedPoint = SphereMath.rotatePoint(
            point: point3D,
            orientation: orientation
        )
        let projected = SphereMath.projectTo2D(
            point: rotatedPoint,
            containerSize: containerSize,
            sphereScale: sphereScale
        )
        let depth = rotatedPoint.z
        let opacity = SphereMath.computeOpacity(depth: depth)

        // Center position for selected tile
        let position = isSelected
            ? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
            : projected.position

        let baseScale: CGFloat = isSelected ? 1.4 : 1.0 // 40% larger when selected
        let depthScale: CGFloat = isSelected ? 1.0 : SphereMath.computeScale(depth: depth)
        let scale: CGFloat = (baseScale * depthScale) + (isNewTile ? 0.18 : 0.0)
        let finalOpacity: Double = isSelected ? 1.0 : opacity

        // Z-index ordering (ensure tiles are always above background)
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let zIndex = isSelected ? 1000 : (normalizedDepth + 1.0) // 1 to 2 for normal tiles

        // The perspective sphere silhouette has radius sqrt(1/2) * screenSize * scale.
        // Soften only its outer band, keeping focused/capture tiles crisp.
        let screenSize = min(containerSize.width, containerSize.height)
        let radius = screenSize * CGFloat(sphereScale) / sqrt(2)
        let distance = hypot(projected.position.x - containerSize.width / 2,
                             projected.position.y - containerSize.height / 2)
        let edge = radius > 0 ? min(1, max(0, (distance / radius - 0.72) / 0.28)) : 0
        let blur: CGFloat = sphereEdgeBlurEnabled && contrast != .increased && !isSelected && !isEditing && sphereFlightPosition == nil
            ? edge * edge * min(3, radius * 0.008) : 0
        return (sphereFlightPosition ?? position, scale, finalOpacity, zIndex, blur)
    }

    var body: some View {
        let layout = computeLayout()
        let tag = tagManager.getTag(byId: tagId) ?? tagManager.getDefaultTag()
        let fill = isCompleting ? Color.green : (fillColor ?? tag.uiColor)
        let border = isCompleting ? Color(red: 0.04, green: 0.28, blue: 0.10) : (borderColor ?? tag.uiColor)
        let foreground = textColor(for: fill)
        let size: CGFloat = isFiltered ? (isSelected ? 160 : 144) : tileSize
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
        let surface = VStack(spacing: 6) {
            if isDemo {
                Text("DEMO")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(foreground.opacity(0.12), in: Capsule())
                    .accessibilityHidden(true)
            }
            if let thumbnail, !isEditing {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(height: isFiltered ? 48 : 28)
                    .clipped()
                    .accessibilityHidden(true)
            }
            if isEditing && isSelected {
                TextField("Thought", text: Binding(get: { text }, set: onTextChange), axis: .vertical)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.sentences)
                    .focused($isFocused)
                    .accessibilityLabel("Thought text")
                    .accessibilityIdentifier("thought-editor-text")
            } else {
                Text(text.isEmpty ? "Empty thought" : text)
                    .accessibilityLabel((isDemo ? "Demo thought: " : "") + (text.isEmpty ? "Empty thought" : text))
                    .lineLimit(isFiltered ? 6 : 4)
                    .truncationMode(.tail)
            }
        }
        .font(.system(size: max(14, previewFont), weight: .medium))
        .multilineTextAlignment(.center)
        .foregroundStyle(foreground)
        .padding(12)
        .frame(width: size, height: size)
        .background { TileSurface(fill: fill) }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(border, lineWidth: isSelected ? 6 : 4)
        }
        .overlay {
            if isNewTile && !reduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(border.opacity(0.7), lineWidth: 2)
                    .scaleEffect(materialised ? 1.85 : 0.7)
                    .opacity(materialised ? 0 : 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(isDiscarding ? 0.001 : (isNewTile && !materialised && !reduceMotion ? 0.3 : 1))
        .opacity(isDiscarding ? 0 : 1)
        .animation(reduceMotion ? nil : .easeIn(duration: 0.38), value: isDiscarding)
        .rotation3DEffect(.degrees(isNewTile && !materialised && !reduceMotion ? -55 : 0),
                          axis: (x: 1, y: 0.3, z: 0), perspective: 0.4)
        .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 9 : 4, y: 3)
        return surface
        .blur(radius: layout.edgeBlur)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .scaleEffect((isFiltered ? 1 : layout.scale) * (completionFlight && !reduceMotion ? 5 : 1))
        .opacity(isDeleting || completionFlight || isTagChanging ? 0 : layout.opacity)
        .zIndex(layout.zIndex)
        .modifier(ConditionalPositionModifier(isFiltered: isFiltered, position: layout.position))
        .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8), value: isSelected)
        .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8), value: isNewTile)
        .task(id: isNewTile) {
            guard isNewTile else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.72)) {
                materialised = true
            }
        }
        .animation(animation, value: isDeleting)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isCompleting)
        .animation(reduceMotion ? nil : .easeIn(duration: 0.45), value: completionFlight)
        .task(id: isCompleting) {
            guard isCompleting else { completionFlight = false; return }
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            completionFlight = true
        }
        .animation(animation, value: isTagChanging)
        .onAppear { isFocused = isEditing && isSelected }
        .onChange(of: isDiscarding) { _, discarding in if discarding { isFocused = false } }
        .onChange(of: isSelected) { _, selected in isFocused = isEditing && selected }
        .onChange(of: isEditing) { _, editing in isFocused = editing && isSelected }
        .onChange(of: focusRequestId) { _, _ in isFocused = isEditing && isSelected }
        .gesture(
            LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                .exclusively(before: TapGesture())
                .onEnded { gesture in
                    switch gesture {
                    case .first:
                        if !isEditing { (onLongPress ?? onTap)() }
                    case .second:
                        if isTapEnabled { onTap() }
                    }
                },
            including: isEditing ? .subviews : .all
        )
        .accessibilityIdentifier(isEditing ? "thought-editor-text" : "thought-tile-\(index)")
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel((isDemo ? "Demo thought: " : "") + (text.isEmpty ? "Empty thought" : text))
        .accessibilityValue(isSelected ? "Selected, \(tag.name)" : tag.name)
        .accessibilityAddTraits(isEditing ? [] : .isButton)
        .accessibilityAction(named: "Select thought") { if isTapEnabled { onTap() } }
        .accessibilityAction(named: "Open full thought") { (onLongPress ?? onTap)() }
        .task(id: thumbnailURL) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        thumbnail = nil
        guard let url = thumbnailURL, url.isFileURL else { return }
        let data = await Task.detached(priority: .utility) { () -> Data? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 480,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { return nil }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return output as Data
        }.value
        guard !Task.isCancelled, let data else { return }
        thumbnail = UIImage(data: data)
    }
}

/// Reserved row bounds contain every selection state, so selection never shifts scroll geometry.
struct CylinderTileRow<Content: View>: View {
    let containerMidY: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    var flightOrigin: CGPoint? = nil
    let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let distance = abs(frame.midY - containerMidY)
            let normalized = min(1, distance / 400)
            content()
                .scaleEffect(reduceMotion || isSelected ? 1 : 1 - normalized * 0.04)
                .opacity(isSelected ? 1 : 1 - normalized * 0.12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(flightOrigin != nil && !reduceMotion ? 0.7 : 1)
                .offset(x: reduceMotion ? 0 : flightOrigin.map { $0.x - frame.midX } ?? 0,
                        y: reduceMotion ? 0 : flightOrigin.map { $0.y - frame.midY } ?? 0)
        }
        .frame(height: max(184, rowHeight))
        .zIndex(isSelected ? 1000 : 0)
    }
}
