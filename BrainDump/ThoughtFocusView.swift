import SwiftUI

/// The enlarged thought remains a tile, with readable content and explicit actions.
struct ThoughtFocusView: View {
    let thoughtID: String
    @ObservedObject private var store = ThoughtStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing = false
    @State private var zoomedImage: ThoughtAttachment?
    @State private var confirmDelete = false
    @State private var error: String?
    @State private var completing = false
    @State private var completionFlight = false
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "3C315C"

    private var thought: ThoughtRecord? { store.thought(id: thoughtID) }

    var body: some View {
        NavigationStack {
            if let thought {
                let category = store.tags.first { $0.id == thought.tagId }
                let fill = completing ? Color.green : TilePalette.color(thought.fillHex ?? TilePalette.categoryFill(category, fallback: defaultFill))
                let border = TilePalette.color(thought.borderHex ?? TilePalette.categoryBorder(category, fallback: defaultBorder))
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
                    .foregroundStyle(completing ? Color.black : TilePalette.foreground(thought.fillHex ?? TilePalette.categoryFill(category, fallback: defaultFill)))
                    .background { TileSurface(fill: fill, cornerRadius: 24) }
                    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(border, lineWidth: 4))
                    .padding(20)
                    .scaleEffect(completionFlight ? 5 : 1)
                    .opacity(completionFlight ? 0 : 1)
                    .animation(.easeOut(duration: 0.12), value: completing)
                    .animation(.easeIn(duration: 0.45), value: completionFlight)
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
                    }.buttonStyle(.bordered).disabled(completing).padding().background(.regularMaterial)
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
        .alert("Delete thought?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) { confirmDelete = false }
            Button("Delete", role: .destructive) { changeStatus(.deleted) }
        } message: { Text("You can restore it from Recently Deleted for 30 days.") }
        .alert("Couldn’t save", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private func changeStatus(_ status: ThoughtRecord.Status) {
        guard !completing else { return }
        guard status == .completed && !reduceMotion else { commitStatus(status); return }
        completing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            completionFlight = true
            try? await Task.sleep(for: .milliseconds(450))
            commitStatus(status)
        }
    }

    private func commitStatus(_ status: ThoughtRecord.Status) {
        guard var thought else { return }
        thought.status = status
        thought.archivedAt = Date()
        do { try store.update(thought); dismiss() }
        catch { completing = false; completionFlight = false; self.error = error.localizedDescription }
    }
}
