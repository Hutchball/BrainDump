import SwiftUI
import UIKit

enum TilePalette {
    private static let categorySwatches = Dictionary(uniqueKeysWithValues:
        TagColor.allCases.map { ($0.rawValue, hex($0.uiColor)) })
    private static let categoryBorders = categorySwatches.mapValues { prominentBorder($0) }

    static func prominentBorder(_ fill: String) -> String {
        guard let rgb = UInt32(fill, radix: 16) else { return "48404F" }
        let channels = [Double((rgb >> 16) & 255), Double((rgb >> 8) & 255), Double(rgb & 255)]
        let adjusted = channels.map { Int($0 * 0.42) }
        return String(format: "%02X%02X%02X", adjusted[0], adjusted[1], adjusted[2])
    }

    /// Explicit appearance wins; otherwise categorised thoughts inherit the category swatch.
    static func categoryFill(_ category: ThoughtCategory?, fallback: String) -> String {
        if let fill = category?.fillHex { return fill }
        guard let category, category.id != 0 else { return fallback }
        return categorySwatches[category.color] ?? fallback
    }

    static func categoryBorder(_ category: ThoughtCategory?, fallback: String) -> String {
        if let border = category?.borderHex { return border }
        guard let category, category.id != 0 else { return fallback }
        if let fill = category.fillHex { return prominentBorder(fill) }
        return categoryBorders[category.color] ?? fallback
    }

    static func color(_ hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let rgb = UInt32(cleaned, radix: 16) else { return Color(uiColor: .secondarySystemBackground) }
        return Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
    }

    static func hex(_ color: Color) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    static func foreground(_ hex: String) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color(hex)).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ value: CGFloat) -> CGFloat { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return (0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)) > 0.179 ? .black : .white
    }
}

struct TileAppearanceSettings: View {
    @ObservedObject var store: ThoughtStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "3C315C"
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Unsorted tile colours") {
                    ColorPicker("Tile colour", selection: globalBinding(fill: true), supportsOpacity: false)
                    ColorPicker("Border colour", selection: globalBinding(fill: false), supportsOpacity: false)
                    preview(fill: defaultFill, border: defaultBorder, text: "Your thought")
                    Button("Reset defaults") { defaultFill = "E9E3FF"; defaultBorder = "3C315C" }
                }
                Section {
                    ForEach(store.tags.filter { $0.isDeleted != true }) { category in
                        NavigationLink(category.name) {
                            Form {
                                Section {
                                    ColorPicker("Tile colour", selection: categoryBinding(category.id, fill: true), supportsOpacity: false)
                                    ColorPicker("Border colour", selection: categoryBinding(category.id, fill: false), supportsOpacity: false)
                                    let current = store.tags.first { $0.id == category.id } ?? category
                                    preview(fill: TilePalette.categoryFill(current, fallback: defaultFill), border: TilePalette.categoryBorder(current, fallback: defaultBorder), text: category.name)
                                    Button("Use category colour") {
                                        guard var current = store.tags.first(where: { $0.id == category.id }) else { return }
                                        current.fillHex = nil; current.borderHex = nil
                                        save(current)
                                    }
                                } footer: {
                                    Text("Thoughts inherit these colours unless you customise an individual tile.")
                                }
                            }
                            .navigationTitle(category.name)
                        }
                    }
                } header: { Text("Category colours") }
            }
            .navigationTitle("Tile appearance")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Colours could not be saved", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "Please try again.") }
        }
    }

    private func globalBinding(fill: Bool) -> Binding<Color> {
        Binding(get: { TilePalette.color(fill ? defaultFill : defaultBorder) }, set: {
            if fill { defaultFill = TilePalette.hex($0) } else { defaultBorder = TilePalette.hex($0) }
        })
    }

    private func categoryBinding(_ id: Int, fill: Bool) -> Binding<Color> {
        Binding(get: {
            let category = store.tags.first { $0.id == id }
            return TilePalette.color(fill ? (TilePalette.categoryFill(category, fallback: defaultFill)) : (TilePalette.categoryBorder(category, fallback: defaultBorder)))
        }, set: { color in
            guard var category = store.tags.first(where: { $0.id == id }) else { return }
            if fill { category.fillHex = TilePalette.hex(color) } else { category.borderHex = TilePalette.hex(color) }
            save(category)
        })
    }

    private func save(_ category: ThoughtCategory) {
        do { try store.updateCategory(category) } catch { saveError = error.localizedDescription }
    }

    private func preview(fill: String, border: String, text: String) -> some View {
        Text(text)
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(TilePalette.foreground(fill))
            .padding(16)
            .frame(width: 160, height: 160)
            .background { TileSurface(fill: TilePalette.color(fill)) }
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(TilePalette.color(border), lineWidth: 4) }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityLabel("Tile preview: \(text)")
    }
}
