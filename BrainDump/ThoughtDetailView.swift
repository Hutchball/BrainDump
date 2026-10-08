import SwiftUI
import PhotosUI
import UIKit

struct ThoughtDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ThoughtStore.shared
    @State private var draft: ThoughtRecord
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var unsavedImageFiles: [String] = []
    @State private var error: String?
    @State private var linkText = ""
    @State private var zoomedAttachment: ThoughtAttachment?
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "3C315C"
    private let original: ThoughtRecord
    @State private var conflictSaved = false
    var onSave: (ThoughtRecord) -> Void

    init(thought: ThoughtRecord, onSave: @escaping (ThoughtRecord) -> Void = { _ in }) {
        _draft = State(initialValue: thought)
        self.original = thought
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft.text)
                        .font(.body)
                        .frame(minHeight: 180)
                        .accessibilityLabel("Thought text")
                        .accessibilityIdentifier("thought-editor-text")
                }
                Section {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Add image or screenshot", systemImage: "photo.badge.plus")
                    }.disabled(importing)
                    if importing { ProgressView("Preparing image…") }
                    ForEach(draft.attachments.filter { $0.kind == .image }) { attachment in
                        VStack(alignment: .leading) {
                            if let filename = attachment.filename, AttachmentStore.isSafeFilename(filename) {
                                Button { zoomedAttachment = attachment } label: {
                                    AttachmentImageView(url: store.attachmentDirectory.appendingPathComponent(filename))
                                        .frame(maxWidth: .infinity).frame(height: 180).clipped()
                                }.buttonStyle(.plain).accessibilityLabel("Open image. Pinch to zoom.")
                            }
                            Button("Remove image", role: .destructive) { remove(attachment) }
                        }
                    }
                }
                Section("Add weblinks") {
                    TextField("https://example.com", text: $linkText)
                        .textContentType(.URL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    HStack {
                        PasteButton(payloadType: String.self) { values in linkText = values.first ?? "" }
                        Spacer()
                        Button("Add link", action: addLink).disabled(linkText.isEmpty)
                    }
                    ForEach(draft.attachments.filter { $0.kind == .link }) { attachment in
                        if let value = attachment.url, let url = AttachmentStore.webURL(value) {
                            VStack(alignment: .leading, spacing: 8) {
                                Link(destination: url) {
                                    Label(url.host ?? value, systemImage: "link").font(.body.weight(.semibold))
                                }
                                Text(value).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                                Button("Remove link", role: .destructive) { remove(attachment) }
                            }
                        }
                    }
                }
                Section {
                    Picker("Category", selection: $draft.tagId) {
                        ForEach(store.tags.filter { $0.isDeleted != true }) { category in Text(category.name).tag(category.id) }
                    }
                }
                Section("Tile appearance") {
                    ColorPicker("Tile colour", selection: fillBinding, supportsOpacity: false)
                    ColorPicker("Border colour", selection: borderBinding, supportsOpacity: false)
                    TileSurface(fill: fillBinding.wrappedValue)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(borderBinding.wrappedValue, lineWidth: 3))
                        .overlay(Text(draft.text.isEmpty ? "Your thought" : draft.text).font(.body.weight(.medium))
                            .foregroundStyle(readableTextColor).lineLimit(4).padding())
                        .frame(height: 130)
                        .accessibilityLabel("Tile appearance preview")
                    Button("Use default category colours") { draft.fillHex = nil; draft.borderHex = nil }
                }
            }
            .interactiveDismissDisabled(importing || draft != original || !unsavedImageFiles.isEmpty)
            .navigationTitle("Tile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { discardImportedImages(); dismiss() }.disabled(importing) }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("thought-save").disabled(importing || (draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.attachments.isEmpty)) }
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
            .alert("Saved both versions", isPresented: $conflictSaved) {
                Button("OK") { dismiss() }
            } message: {
                Text("This thought changed elsewhere while you were editing. Your edits were saved as a separate thought so neither version is lost.")
            }
            .sheet(item: $zoomedAttachment) { attachment in
                if let filename = attachment.filename, AttachmentStore.isSafeFilename(filename) {
                    ImageZoomView(url: store.attachmentDirectory.appendingPathComponent(filename))
                }
            }
        }
    }

    private var category: ThoughtCategory? { store.tags.first { $0.id == draft.tagId } }
    private var fillBinding: Binding<Color> {
        Binding(get: { Color(uiColor: Self.uiColor(draft.fillHex ?? TilePalette.categoryFill(category, fallback: defaultFill))) },
                set: { draft.fillHex = Self.hex($0) })
    }
    private var borderBinding: Binding<Color> {
        Binding(get: { Color(uiColor: Self.uiColor(draft.borderHex ?? TilePalette.categoryBorder(category, fallback: defaultBorder))) },
                set: { draft.borderHex = Self.hex($0) })
    }
    private var readableTextColor: Color {
        let color = Self.uiColor(draft.fillHex ?? TilePalette.categoryFill(category, fallback: defaultFill))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b) > 0.179 ? .black : .white
    }
    private static func uiColor(_ hex: String) -> UIColor {
        let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0xE9E3FF
        return UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
    }
    private static func hex(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
    private func remove(_ attachment: ThoughtAttachment) { draft.attachments.removeAll { $0.id == attachment.id } }
    private func addLink() {
        guard draft.attachments.count < 10 else { error = "A thought can hold up to 10 attachments."; return }
        guard let url = AttachmentStore.webURL(linkText) else { error = "Enter a complete http or https web address."; return }
        draft.attachments.append(ThoughtAttachment(kind: .link, url: url.absoluteString, title: url.host))
        linkText = ""
    }
    private func importPhoto(_ item: PhotosPickerItem) async {
        guard draft.attachments.count < 10 else { error = "A thought can hold up to 10 attachments."; photo = nil; return }
        importing = true
        defer { importing = false; photo = nil }
        do {
            guard let photo = try await item.loadTransferable(type: ImportedPhoto.self) else { throw AttachmentStore.ImportError.invalidImage }
            let prepared = try await AttachmentStore.prepareImage(photo.data)
            let filename = try store.importAttachment(data: prepared, extension: "png")
            unsavedImageFiles.append(filename)
            draft.attachments.append(ThoughtAttachment(kind: .image, filename: filename, title: "Image", contentType: "image/png"))
        } catch { self.error = error.localizedDescription }
    }
    private func discardImportedImages() {
        for filename in unsavedImageFiles where AttachmentStore.isSafeFilename(filename) {
            let referenced = store.thoughts.contains { $0.attachments.contains { $0.filename == filename } }
            if !referenced { try? FileManager.default.removeItem(at: store.attachmentDirectory.appendingPathComponent(filename)) }
        }
        unsavedImageFiles = []
    }
    private func save() {
        do {
            draft.text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let (saved, recovered) = try store.saveEdit(draft, original: original)
            draft = saved
            if !recovered, original.tagId != saved.tagId {
                ArchiveUndoController.shared.offerCategoryUndo(for: saved, previousCategoryID: original.tagId)
            }
            let used = Set(draft.attachments.compactMap(\.filename))
            for filename in unsavedImageFiles where !used.contains(filename) && AttachmentStore.isSafeFilename(filename) && !store.thoughts.contains(where: { $0.attachments.contains(where: { $0.filename == filename }) }) {
                try? FileManager.default.removeItem(at: store.attachmentDirectory.appendingPathComponent(filename))
            }
            unsavedImageFiles = []
            onSave(draft)
            if recovered { conflictSaved = true } else { dismiss() }
        } catch { self.error = error.localizedDescription }
    }
}

struct AttachmentImageView: View {
    let url: URL
    var maximumSize = 1_600
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { ContentUnavailableView("Image unavailable", systemImage: "photo") }
        }.task(id: url) {
            let directory = ThoughtStore.shared.attachmentDirectory.standardizedFileURL
            guard url.standardizedFileURL.deletingLastPathComponent() == directory,
                  AttachmentStore.isSafeFilename(url.lastPathComponent) else { return }
            if let data = await AttachmentStore.imagePreview(at: url, maximumSize: maximumSize) { image = UIImage(data: data) }
        }
    }
}

struct ImageZoomView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    AttachmentImageView(url: url, maximumSize: 4_096)
                        .frame(width: geometry.size.width * scale * magnification,
                               height: geometry.size.height * scale * magnification)
                        .gesture(MagnifyGesture().updating($magnification) { value, state, _ in state = value.magnification }
                            .onEnded { value in scale = min(5, max(1, scale * value.magnification)) })
                }
            }
            .navigationTitle("Image").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button("Zoom out") { scale = max(1, scale - 0.5) }.disabled(scale <= 1)
                        Spacer()
                        Button("Zoom in") { scale = min(5, scale + 0.5) }.disabled(scale >= 5)
                    }
                }
            }
        }
    }
}
