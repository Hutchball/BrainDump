import SwiftUI

/// The enlarged thought remains a tile, with readable content and explicit actions.
struct ThoughtFocusView: View {
    let thoughtID: String
    @ObservedObject private var store = ThoughtStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var zoomedImage: ThoughtAttachment?
    @State private var confirmDelete = false
    @State private var error: String?
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "7565AB"

    private var thought: ThoughtRecord? { store.thought(id: thoughtID) }

    var body: some View {
        NavigationStack {
            if let thought {
                let category = store.tags.first { $0.id == thought.tagId }
                let fill = TilePalette.color(thought.fillHex ?? category?.fillHex ?? defaultFill)
                let border = TilePalette.color(thought.borderHex ?? category?.borderHex ?? defaultBorder)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(thought.text.isEmpty ? "New thought" : thought.text)
                            .font(.title3).textSelection(.enabled)
                            .accessibilityIdentifier("thought-detail-text")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(thought.attachments) { attachment in
                            if attachment.kind == .image, let name = attachment.filename, AttachmentStore.isSafeFilename(name) {
                                Button { zoomedImage = attachment } label: {
                                    AttachmentImageView(url: store.attachmentDirectory.appendingPathComponent(name))
                                        .frame(maxWidth: .infinity).frame(height: 260)
                                }.buttonStyle(.plain).accessibilityLabel("Open image to zoom")
                            } else if let value = attachment.url, let url = AttachmentStore.webURL(value) {
                                Link(destination: url) { Label(url.host ?? value, systemImage: "link") }
                            }
                        }
                    }
                    .padding(24)
                    .foregroundStyle(TilePalette.foreground(thought.fillHex ?? category?.fillHex ?? defaultFill))
                    .background(fill, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(border, lineWidth: 3))
                    .padding(20)
                }
                .navigationTitle(category?.name ?? "Thought")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }.accessibilityIdentifier("thought-detail-close")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { editing = true } label: { Label("Edit thought", systemImage: "pencil") }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button { changeStatus(.completed) } label: { Label("Complete", systemImage: "checkmark.circle") }
                        Spacer()
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                    }.buttonStyle(.bordered).padding().background(.regularMaterial)
                }
                .sheet(isPresented: $editing) { ThoughtDetailView(thought: thought) }
            } else {
                ContentUnavailableView("Thought unavailable", systemImage: "brain")
            }
        }
        .sheet(item: $zoomedImage) { attachment in
            if let filename = attachment.filename, AttachmentStore.isSafeFilename(filename) {
                ImageZoomView(url: store.attachmentDirectory.appendingPathComponent(filename))
            }
        }
        .confirmationDialog("Delete thought?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { changeStatus(.deleted) }
        } message: { Text("You can restore it from Recently Deleted for 30 days.") }
        .alert("Couldn’t save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func changeStatus(_ status: ThoughtRecord.Status) {
        guard var thought else { return }
        thought.status = status
        thought.archivedAt = Date()
        do { try store.update(thought); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
