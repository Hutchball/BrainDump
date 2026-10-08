import SwiftUI

/// The enlarged thought remains a tile, with readable content and explicit actions.
struct ThoughtFocusView: View {
    let thoughtID: String
    var initialThought: ThoughtRecord? = nil
    var sourceFrame: CGRect = CGRect(x: 0, y: 0, width: 160, height: 160)
    var readOnly = false
    var isDemo = false
    var onClose: () -> Void = {}
    @ObservedObject private var store = ThoughtStore.shared
    @ObservedObject private var archiveUndo = ArchiveUndoController.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var angle = 0.0
    @State private var expansion = 0.0
    @State private var showsBack = false
    @State private var transitioning = true
    @State private var closing = false
    @State private var actionsVisible = false
    @ScaledMetric(relativeTo: .title3) private var expandedTextSize: CGFloat = 24
    @State private var animationID = UUID()
    @AccessibilityFocusState private var closeFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing = false
    @State private var zoomedImage: ThoughtAttachment?
    @State private var confirmDelete = false
    @State private var error: String?
    @State private var completing = false
    @State private var completionFlight = false
    @State private var deleting = false
    @State private var deletionShrink = false
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "3C315C"

    private var thought: ThoughtRecord? { readOnly ? initialThought : store.thought(id: thoughtID) }

    var body: some View {
        GeometryReader { geometry in
            if let thought {
                let category = store.tags.first { $0.id == thought.tagId }
                let fillHex = thought.fillHex ?? TilePalette.categoryFill(category, fallback: defaultFill)
                let fill = deleting ? Color.red : (completing ? Color.green : TilePalette.color(fillHex))
                let border = TilePalette.color(thought.borderHex ?? TilePalette.categoryBorder(category, fallback: defaultBorder))
                // Keep the tile square and leave 16 points clear on every constrained edge.
                let side = min(620, max(1, min(geometry.size.width, geometry.size.height) - 32))
                let width = side
                let height = side
                ZStack {
                    Color.black.opacity(0.55 * expansion).ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { closeThought() }
                        .allowsHitTesting(!transitioning && !closing)
                    if transitioning || closing {
                        Group {
                            if showsBack {
                                expandedContent(thought, categoryName: category?.name ?? "Thought", height: height)
                            } else {
                                preview(thought)
                            }
                        }
                        .foregroundStyle(completing || deleting ? Color.black : TilePalette.foreground(fillHex))
                        .frame(width: sourceFrame.width + (width - sourceFrame.width) * expansion,
                               height: sourceFrame.height + (height - sourceFrame.height) * expansion)
                        .background { TileSurface(fill: fill, cornerRadius: 24) }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(border, lineWidth: 6)
                            .allowsHitTesting(false).accessibilityHidden(true))
                        // The back face uses the equivalent facing angle, ending at zero.
                        // This keeps native button/scroll hit testing free of nested 180° transforms.
                        .rotation3DEffect(.degrees(showsBack ? angle - 180 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                        .scaleEffect(deletionShrink ? 0.001 : (completionFlight ? 5 : 1))
                        .opacity(completionFlight || deletionShrink ? 0 : 1)
                        .position(x: sourceFrame.midX + (geometry.size.width / 2 - sourceFrame.midX) * expansion,
                                  y: sourceFrame.midY + (geometry.size.height / 2 - sourceFrame.midY) * expansion)
                        .animation(.easeOut(duration: 0.15), value: deleting)
                        .animation(.easeIn(duration: 0.4), value: deletionShrink)
                        .animation(.easeOut(duration: 0.12), value: completing)
                        .animation(.easeIn(duration: 0.45), value: completionFlight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    } else {
                        expandedContent(thought, categoryName: category?.name ?? "Thought", height: height)
                            .foregroundStyle(completing || deleting ? Color.black : TilePalette.foreground(fillHex))
                            .frame(width: width, height: height)
                            .background { TileSurface(fill: fill, cornerRadius: 24) }
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(border, lineWidth: 6)
                                .allowsHitTesting(false).accessibilityHidden(true))
                            .scaleEffect(deletionShrink ? 0.001 : (completionFlight ? 5 : 1))
                            .opacity(completionFlight || deletionShrink ? 0 : 1)
                            .animation(.easeOut(duration: 0.15), value: deleting)
                            .animation(.easeIn(duration: 0.4), value: deletionShrink)
                            .animation(.easeOut(duration: 0.12), value: completing)
                            .animation(.easeIn(duration: 0.45), value: completionFlight)
                            .disabled(completing || deleting)
                            .contentShape(RoundedRectangle(cornerRadius: 24))
                            .onTapGesture { } // Consume taps within the tile instead of its backdrop.
                            .highPriorityGesture(
                                LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                                    .onEnded { _ in
                                        guard !editing, zoomedImage == nil else { return }
                                        closeThought()
                                    }
                            )
                            .accessibilityAction(.escape) { closeThought() }
                            .task {
                                guard !readOnly else { return }
                                // Render the resting tile with hidden actions before their fade begins.
                                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                                guard !Task.isCancelled, !transitioning, !closing, scenePhase == .active else { return }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { actionsVisible = true }
                            }
                            .zIndex(1)
                    }
                }
                .task { animateFlip(opening: true) }
                .sheet(isPresented: $editing) { ThoughtDetailView(thought: thought) }
            } else {
                ContentUnavailableView("Thought unavailable", systemImage: "brain")
                    .onAppear { onClose() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { settleFlip() }
        }
        .onChange(of: reduceMotion) { _, enabled in if enabled { settleFlip() } }
        .onDisappear { animationID = UUID() }
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

    private func preview(_ thought: ThoughtRecord) -> some View {
        VStack(spacing: 6) {
            if isDemo { Text("DEMO").font(.caption2.bold()) }
            if let image = thought.attachments.first(where: { $0.kind == .image }),
               let filename = image.filename, AttachmentStore.isSafeFilename(filename) {
                AttachmentImageView(url: store.attachmentDirectory.appendingPathComponent(filename), maximumSize: 480)
                    .frame(height: 40)
            }
            Text(thought.text.isEmpty ? "Empty thought" : thought.text)
                .font(.body.weight(.medium)).lineLimit(4).multilineTextAlignment(.center)
        }.padding(12)
    }

    private func expandedContent(_ thought: ThoughtRecord, categoryName: String, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(isDemo ? "DEMO · \(categoryName)" : categoryName)
                    .font(.headline).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if !readOnly {
                    Button { editing = true } label: { Image(systemName: "pencil") }
                        .frame(width: 44, height: 44).contentShape(Rectangle()).accessibilityLabel("Edit thought")
                }
            }.buttonStyle(.plain).padding(.horizontal, 16).padding(.top, 8)
            GeometryReader { contentGeometry in
                ScrollView {
                    VStack(spacing: 24) {
                        if !thought.text.isEmpty {
                            Text(thought.text)
                                .font(.system(size: expandedTextSize)).textSelection(.enabled)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel((isDemo ? "Demo thought: " : "") + thought.text)
                                .accessibilityIdentifier("thought-detail-text")
                        }
                        ForEach(thought.attachments) { attachment in
                            if attachment.kind == .image, let name = attachment.filename, AttachmentStore.isSafeFilename(name) {
                                Button { zoomedImage = attachment } label: {
                                    AttachmentImageView(url: store.attachmentDirectory.appendingPathComponent(name))
                                        .frame(maxWidth: .infinity)
                                        .frame(maxHeight: max(160, height * 0.45))
                                }.buttonStyle(.plain).accessibilityLabel("Open image to zoom")
                            } else if let value = attachment.url, let url = AttachmentStore.webURL(value) {
                                Link(destination: url) {
                                    VStack(spacing: 6) {
                                        Label(attachment.title ?? url.host ?? "Web link", systemImage: "link")
                                            .font(.headline)
                                        Text(value).font(.callout).underline()
                                    }
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity).padding(12)
                                    .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: contentGeometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("thought-detail-scroll")
            }
            if !readOnly {
                ViewThatFits(in: .horizontal) {
                    thoughtActions(showLabels: true)
                    thoughtActions(showLabels: false)
                }
                .padding(12)
                .opacity(actionsVisible && !transitioning && !closing ? 1 : 0)
                .allowsHitTesting(actionsVisible && !transitioning && !closing)
                .accessibilityHidden(!actionsVisible || transitioning || closing)
            }
            closeButton
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
        }
    }

    private var closeButton: some View {
        Button { closeThought() } label: {
            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(width: 26, height: 26)
                .background(Color(uiColor: .systemGray5), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close full thought")
        .accessibilityIdentifier("thought-detail-close")
        .accessibilityFocused($closeFocused)
    }

    private func thoughtActions(showLabels: Bool) -> some View {
        HStack {
            Button { changeStatus(.completed) } label: {
                Label("Complete", systemImage: "checkmark.circle")
                    .labelStyle(AdaptiveThoughtActionStyle(showTitle: showLabels))
            }
            Spacer(minLength: 8)
            if archiveUndo.thoughtID == thoughtID {
                Button("Undo") {
                    do { _ = try archiveUndo.undo(in: store) }
                    catch { self.error = error.localizedDescription }
                }.accessibilityLabel("Undo last thought action")
            }
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
                    .labelStyle(AdaptiveThoughtActionStyle(showTitle: showLabels, iconTrailing: true))
            }
        }.buttonStyle(.bordered).controlSize(.large)
    }

    private func closeThought() {
        guard !transitioning, !closing, !completing, !deleting else { return }
        Haptics.tilePop()
        closing = true
        actionsVisible = false
        transitioning = true
        let id = UUID()
        animationID = id
        // Materialise the decorative face at its resting angle before reversing it.
        Task { @MainActor in
            await Task.yield()
            guard animationID == id, scenePhase == .active else { return }
            animateFlip(opening: false)
        }
    }

    /// Each half completes at the edge-on position before exchanging the faces.
    /// Completion callbacks avoid timer drift and also run the exact reverse on close.
    private func animateFlip(opening: Bool) {
        closing = !opening
        transitioning = true
        closeFocused = false
        let id = UUID()
        animationID = id
        guard !reduceMotion else { settleFlip(); return }
        withAnimation(.easeIn(duration: 0.45), completionCriteria: .removed) {
            angle = 90
            expansion = 0.5
        } completion: {
            guard animationID == id else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { showsBack = opening }
            Task { @MainActor in
                // Give the edge-on face swap one display interval to lay out before unfolding.
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                guard animationID == id, scenePhase == .active else { return }
                withAnimation(.easeOut(duration: 0.45), completionCriteria: .removed) {
                    angle = opening ? 180 : 0
                    expansion = opening ? 1 : 0
                } completion: {
                    guard animationID == id else { return }
                    if opening {
                        transitioning = false
                        closeFocused = true
                    } else {
                        // Keep the source-sized animated face until the transparent presentation dismisses.
                        onClose()
                    }
                }
            }
        }
    }

    private func settleFlip() {
        animationID = UUID()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            angle = closing ? 0 : 180
            expansion = closing ? 0 : 1
            showsBack = !closing
            transitioning = closing
            actionsVisible = !closing
        }
        if closing { onClose() } else { closeFocused = true }
    }

    private func changeStatus(_ status: ThoughtRecord.Status) {
        guard !completing, !deleting else { return }
        guard !reduceMotion else { commitStatus(status); return }
        if status == .deleted {
            deleting = true
            Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                deletionShrink = true
                do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                commitStatus(status)
            }
            return
        }
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
        do {
            try store.update(thought)
            ArchiveUndoController.shared.offerUndo(for: store.thought(id: thought.id) ?? thought)
            onClose()
        }
        catch { deleting = false; deletionShrink = false; completing = false; completionFlight = false; self.error = error.localizedDescription }
    }
}

private struct AdaptiveThoughtActionStyle: LabelStyle {
    let showTitle: Bool
    var iconTrailing = false
    func makeBody(configuration: Configuration) -> some View {
        if showTitle {
            HStack {
                if iconTrailing { configuration.title; configuration.icon }
                else { configuration.icon; configuration.title }
            }
        } else { configuration.icon }
    }
}
