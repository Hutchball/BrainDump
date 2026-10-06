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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var previewFont: CGFloat = 16
    @FocusState private var isFocused: Bool
    @State private var thumbnail: UIImage?
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

    private func computeLayout() -> (position: CGPoint, scale: CGFloat, opacity: Double, zIndex: Double) {
        if isFiltered, filteredIndices != nil {
            // List mode: tiles are in a ScrollView, so we don't use absolute positioning
            // The VStack handles vertical positioning, we just center horizontally
            let position = CGPoint(x: containerSize.width / 2, y: 0)
            let baseScale: CGFloat = isSelected ? 1.4 : 1.0
            let scale: CGFloat = baseScale + (isNewTile ? 0.18 : 0.0)
            let opacity: Double = 1.0
            // Ensure the centered/selected tile is always above other list tiles
            let zIndex: Double = isSelected ? 5000 : 0
            return (position, scale, opacity, zIndex)
        }

        // Sphere mode: use normal sphere calculations
        let point3D = SphereMath.generatePoint(index: index, total: totalCount)
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

        return (position, scale, finalOpacity, zIndex)
    }

    var body: some View {
        let layout = computeLayout()
        let tag = tagManager.getTag(byId: tagId) ?? tagManager.getDefaultTag()
        let fill = fillColor ?? tag.uiColor
        let border = borderColor ?? tag.uiColor
        let foreground = textColor(for: fill)
        let size: CGFloat = isFiltered ? (isSelected ? 160 : 144) : tileSize
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
        VStack(spacing: 6) {
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
            } else {
                Text(text.isEmpty ? "Empty thought" : text)
                    .lineLimit(isFiltered ? 6 : 4)
                    .truncationMode(.tail)
            }
        }
        .font(.system(size: max(14, previewFont), weight: .medium))
        .multilineTextAlignment(.center)
        .foregroundStyle(foreground)
        .padding(12)
        .frame(width: size, height: size)
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(border, lineWidth: isSelected ? 4 : 2)
        }
        .shadow(color: .black.opacity(isSelected ? 0.2 : 0.1), radius: isSelected ? 9 : 4, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .scaleEffect(isFiltered ? 1 : layout.scale)
        .opacity(isDeleting || isCompleting || isTagChanging ? 0 : layout.opacity)
        .zIndex(layout.zIndex)
        .modifier(ConditionalPositionModifier(isFiltered: isFiltered, position: layout.position))
        .animation(animation, value: isSelected)
        .animation(animation, value: isDeleting)
        .animation(animation, value: isCompleting)
        .animation(animation, value: isTagChanging)
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
                }
        )
        .accessibilityIdentifier("thought-tile-\(index)")
        .accessibilityElement(children: isEditing ? .contain : .ignore)
        .accessibilityLabel(text.isEmpty ? "Empty thought" : text)
        .accessibilityValue(isSelected ? "Selected, \(tag.name)" : tag.name)
        .accessibilityAddTraits(isEditing ? [] : .isButton)
        .accessibilityAction(named: "Select thought") { if isTapEnabled { onTap() } }
        .accessibilityAction(named: "Open full thought") { (onLongPress ?? onTap)() }
        .task(id: thumbnailURL) {
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
}

/// Reserved row bounds contain every selection state, so selection never shifts scroll geometry.
struct CylinderTileRow<Content: View>: View {
    let containerMidY: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let distance = abs(geometry.frame(in: .global).midY - containerMidY)
            let normalized = min(1, distance / 400)
            content()
                .scaleEffect(reduceMotion || isSelected ? 1 : 1 - normalized * 0.04)
                .opacity(isSelected ? 1 : 1 - normalized * 0.12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: max(184, rowHeight))
        .zIndex(isSelected ? 1000 : 0)
    }
}
