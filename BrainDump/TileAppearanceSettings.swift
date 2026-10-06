import SwiftUI
import UIKit

enum TilePalette {
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
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "7565AB"
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Default tile colours") {
                    ColorPicker("Tile colour", selection: globalBinding(fill: true), supportsOpacity: false)
                    ColorPicker("Border colour", selection: globalBinding(fill: false), supportsOpacity: false)
                    preview(fill: defaultFill, border: defaultBorder, text: "Your thought")
                    Button("Reset defaults") { defaultFill = "E9E3FF"; defaultBorder = "7565AB" }
                }
                Section {
                    ForEach(store.tags.filter { $0.isDeleted != true }) { category in
                        NavigationLink(category.name) {
                            Form {
                                Section {
                                    ColorPicker("Tile colour", selection: categoryBinding(category.id, fill: true), supportsOpacity: false)
                                    ColorPicker("Border colour", selection: categoryBinding(category.id, fill: false), supportsOpacity: false)
                                    let current = store.tags.first { $0.id == category.id } ?? category
                                    preview(fill: current.fillHex ?? defaultFill, border: current.borderHex ?? defaultBorder, text: category.name)
                                    Button("Use default colours") {
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
            return TilePalette.color(fill ? (category?.fillHex ?? defaultFill) : (category?.borderHex ?? defaultBorder))
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
            .background(TilePalette.color(fill), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(TilePalette.color(border), lineWidth: 3) }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityLabel("Tile preview: \(text)")
    }
}
