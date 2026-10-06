import SwiftUI
import Combine
import UIKit

let brainDumpICloudContainerIdentifier = "iCloud.BonkersBonk.BrainDump"
let iCloudBackupLastErrorKey = "ICloudBackupLastError"

/// Views select and mutate records by ID. Scrolling never changes the identity of a thought.
struct ContentView: View {
    @ObservedObject private var store = ThoughtStore.shared
    @StateObject private var tagManager = TagManager()
    @EnvironmentObject private var sync: CloudSyncService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BackgroundTheme") private var theme = BackgroundTheme.space.rawValue
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "7565AB"
    @AppStorage("UserSphereScale") private var sphereScale = 0.95
    @AppStorage("TrainingCompleted") private var trainingCompleted = false
    @AppStorage("BrainDumpNotificationsEnabled") private var notificationsEnabled = false
    @AppStorage("NotificationPromptCreatedTileCount") private var captureCount = 0
    @AppStorage("NotificationPromptAskedAfterFiveCreatedTiles") private var reminderAsked = false
    @AppStorage("NotificationPromptSnoozedUntilTimestamp") private var reminderSnooze: Double = 0
    @State private var orientation = Quaternion.identity
    @State private var originalOrientation = Quaternion.identity
    @State private var dragOrientation = Quaternion.identity
    @State private var dragStart: Point3D?
    @State private var lastDragPoint = Point3D.zero
    @State private var lastDragTime = Date()
    @State private var angularVelocity = Point3D.zero
    @State private var displayDriver = DisplayLinkDriver()
    @State private var lastFrame: CFTimeInterval = 0
    @State private var spinning = false
    @State private var pinchStart: Double?
    @State private var selectedID: String?
    @State private var categoryID: Int?
    @State private var centeredID: String?
    @State private var categoryPositions: [Int: String] = [:]
    @State private var focused: ThoughtRecord?
    @State private var editor: ThoughtRecord?
    @State private var showTags = false
    @State private var showSettings = false
    @State private var showDelete = false
    @State private var showReminderPrompt = false
    @State private var error: String?
    @State private var initialised = false
    @State private var demo: [ThoughtRecord]?
    @State private var trainingStep = TrainingStep.spinSphere
    @State private var previousTrainingSelection: String?
    @State private var replayCategory: Int?
    @State private var replaySelection: String?
    @State private var pendingFocusTask: Task<Void, Never>?
    #if DEBUG
    @AppStorage("ShowDebugPanel") private var showDebug = false
    #endif

    private var fixture: Bool { ProcessInfo.processInfo.arguments.contains("--living-brain-fixture") }
    private var thoughts: [ThoughtRecord] { demo ?? store.activeThoughts }
    private var selected: ThoughtRecord? { thoughts.first { $0.id == selectedID } }
    private var categoryThoughts: [ThoughtRecord] { thoughts.filter { $0.tagId == categoryID } }
    private var populatedCategories: [Int] {
        tagManager.tagsInDisplayOrder.map(\.id).filter { id in thoughts.contains { $0.tagId == id } }
    }
    private var transition: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppBackgroundView(theme: BackgroundTheme(rawValue: theme) ?? .space).ignoresSafeArea()
                if categoryID != nil { categoryTiles(in: geometry) }
                else { sphere(in: geometry) }
                controls
                if categoryID != nil { categoryHeader }
                if let selected { actions(for: selected) }
                if demo != nil {
                    TrainingBannerView(instruction: trainingText, progress: trainingStep.rawValue,
                        canFinish: true, onFinish: finishTraining)
                        .zIndex(30)
                }
                #if DEBUG
                if showDebug { DebugPanelView(tileCount: thoughts.count).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding().allowsHitTesting(false) }
                #endif
            }
        }
        .task { await initialise() }
        .sheet(isPresented: $showSettings) { settings }
        .sheet(item: $focused, onDismiss: reconcileSelection) { ThoughtFocusView(thoughtID: $0.id) }
        .sheet(item: $editor, onDismiss: reconcileSelection) { thought in
            if demo != nil {
                TrainingThoughtEditor(thought: thought) { updated in
                    mutateDemo(updated)
                    if trainingStep == .addThoughtTile { trainingStep = .swipeTags }
                }
            } else {
                ThoughtDetailView(thought: thought) { saved in
                    registerCaptureIfNeeded(thought)
                    if categoryID != nil { openCategory(saved.tagId, preferred: saved.id) }
                    else { selectedID = saved.id }
                }
            }
        }
        .sheet(isPresented: $showTags) {
            if let selected {
                TagPickerView(tagManager: tagManager, selectedTagId: Binding(get: {
                    thoughts.first { $0.id == selected.id }?.tagId ?? 0
                }, set: { retag(selected.id, to: $0) }), onDismiss: { showTags = false })
                .presentationDetents([.height(220)])
            }
        }
        .confirmationDialog("Delete thought?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let selected { archive(selected, status: .deleted) } }
        } message: { Text("You can restore it from Recently Deleted for 30 days.") }
        .alert("Couldn’t complete this action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .alert("Enable nightly reminders?", isPresented: $showReminderPrompt) {
            Button("Not now", role: .cancel) { reminderSnooze = Date().addingTimeInterval(7 * 86400).timeIntervalSince1970 }
            Button("Enable reminders", action: enableReminders)
        } message: { Text("Receive a single nightly reminder to organise your Brain Dumps.") }
        .onChange(of: store.thoughts) { _, _ in
            reconcileSelection()
            updateReminders()
        }
        .onChange(of: store.tags) { _, _ in refreshCategories() }
        .onChange(of: tagManager.saveError) { _, value in if let value { error = value } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await importSharedCaptures(); openPendingNotification() }
            } else { stopSpin(); pendingFocusTask?.cancel() }
        }
        .onChange(of: reduceMotion) { _, enabled in if enabled { stopSpin() } }
        .onReceive(NotificationCenter.default.publisher(for: BrainDumpNotificationManager.openBrainDumpNotificationName)) { _ in openPendingNotification() }
        .onDisappear { stopSpin(); pendingFocusTask?.cancel() }
    }

    private func sphere(in geometry: GeometryProxy) -> some View {
        ZStack {
            Color.clear.contentShape(Rectangle())
            ForEach(Array(thoughts.enumerated()), id: \.element.id) { index, thought in
                tile(thought, index: index, geometry: geometry, filtered: false)
            }
            if thoughts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "brain").font(.largeTitle)
                    Text("Room for a new thought").font(.title3.weight(.semibold))
                    Text("Tap +, share a screenshot or link, or ask Siri to add to Brain Dump.")
                        .font(.body).multilineTextAlignment(.center)
                }.foregroundStyle(.white).padding(40).allowsHitTesting(false)
            }
        }
        .gesture(DragGesture(minimumDistance: 12).onChanged { drag($0, size: geometry.size) }.onEnded { _ in endDrag() })
        .simultaneousGesture(MagnifyGesture().onChanged { value in
            stopSpin()
            if pinchStart == nil { pinchStart = sphereScale }
            sphereScale = min(1.6, max(0.45, (pinchStart ?? sphereScale) * value.magnification))
        }.onEnded { _ in pinchStart = nil })
    }

    private func categoryTiles(in geometry: GeometryProxy) -> some View {
        let rowHeight: CGFloat = 184
        let padding = max(0, (geometry.size.height - rowHeight) / 2)
        let indices = Dictionary(thoughts.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        return ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(categoryThoughts) { thought in
                    let index = indices[thought.id] ?? 0
                    CylinderTileRow(containerMidY: geometry.frame(in: .global).midY,
                        rowHeight: rowHeight, isSelected: centeredID == thought.id) {
                        tile(thought, index: index, geometry: geometry, filtered: true)
                    }
                    .id(thought.id)
                    .zIndex(centeredID == thought.id ? 10 : 0)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.vertical, padding, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centeredID, anchor: .center)
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("thought-category-scroll")
        .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            cycleCategory(value.translation.width < 0 ? 1 : -1)
        })
        .onChange(of: centeredID) { _, id in
            guard let id, categoryThoughts.contains(where: { $0.id == id }) else { return }
            selectedID = id
            if let categoryID { categoryPositions[categoryID] = id }
            if demo != nil, trainingStep == .scrollTagView,
               let previousTrainingSelection, previousTrainingSelection != id { trainingStep = .retagTile }
            previousTrainingSelection = id
        }
        .onAppear { centeredID = selectedID ?? categoryThoughts.first?.id }
    }

    private func tile(_ thought: ThoughtRecord, index: Int, geometry: GeometryProxy, filtered: Bool) -> some View {
        let category = store.tags.first { $0.id == thought.tagId }
        return TileView(index: index, text: thought.text,
            isSelected: filtered ? centeredID == thought.id : selectedID == thought.id,
            isEditing: false, isNewTile: false, isDeleting: false, isCompleting: false,
            focusRequestId: thought.id.stableUUID, orientation: orientation, containerSize: geometry.size,
            totalCount: thoughts.count, sphereScale: sphereScale, tagId: thought.tagId,
            tagManager: tagManager, onTap: { select(thought) }, isTapEnabled: true,
            onTextChange: { _ in }, isTagChanging: false, isFiltered: filtered,
            listPosition: filtered ? index : nil,
            filteredIndices: filtered ? [index] : nil,
            fillColor: TilePalette.color(thought.fillHex ?? category?.fillHex ?? defaultFill),
            borderColor: TilePalette.color(thought.borderHex ?? category?.borderHex ?? defaultBorder),
            thumbnailURL: thumbnail(for: thought), onLongPress: { bringForward(thought, index: index) })
    }

    private var categoryHeader: some View {
        VStack {
            TagFilterListView(tagIds: populatedCategories, selectedTagId: Binding(get: { categoryID ?? 0 }, set: { openCategory($0) }), tagManager: tagManager)
                .frame(height: 96)
            Spacer().allowsHitTesting(false)
        }.zIndex(20)
    }

    private var controls: some View {
        VStack {
            Spacer().allowsHitTesting(false)
            HStack {
                if categoryID == nil {
                    GlassButton(icon: "gearshape.fill") { stopSpin(); showSettings = true }
                    Spacer()
                    Button { openCategory(0, showPicker: true) } label: {
                        Image("Image").resizable().scaledToFit().frame(width: 62, height: 62)
                    }.buttonStyle(BrainDumpButtonStyle()).accessibilityLabel("Organise Brain Dump inbox")
                    Spacer()
                    GlassButton(icon: "plus") { addThought() }
                }
            }.padding(.horizontal, 24).padding(.bottom, 16)
        }.zIndex(15)
    }

    private func actions(for thought: ThoughtRecord) -> some View {
        TileActionButtons(onClose: closeCategory, onEdit: { stopSpin(); editor = thought },
            onChangeTag: { showTags = true }, onComplete: { archive(thought, status: .completed) },
            onDelete: { showDelete = true }, onAdd: { addThought(tagID: categoryID ?? thought.tagId) },
            pulseTrigger: false, closeIcon: "xmark", closeForegroundColor: .primary,
            closeBorderColor: nil, highlightedAction: trainingHighlight, showFloatingAddButton: true)
            .zIndex(25)
    }

    private func select(_ thought: ThoughtRecord) {
        stopSpin()
        if categoryID == nil { openCategory(thought.tagId, preferred: thought.id) }
        else { withAnimation(transition) { centeredID = thought.id; selectedID = thought.id } }
        if demo != nil && trainingStep == .openTagView {
            trainingStep = .scrollTagView; previousTrainingSelection = thought.id
        }
    }

    private func openCategory(_ id: Int, preferred: String? = nil, showPicker: Bool = false) {
        let candidates = thoughts.filter { $0.tagId == id }
        guard !candidates.isEmpty else { Haptics.negativeDoubleTap(); return }
        stopSpin()
        if categoryID == nil { originalOrientation = orientation }
        let remembered = preferred ?? categoryPositions[id]
        let target = candidates.first(where: { $0.id == remembered })?.id ?? candidates[0].id
        withAnimation(transition) { categoryID = id; selectedID = target; centeredID = target }
        showTags = showPicker
    }
    private func closeCategory() {
        stopSpin()
        withAnimation(transition) { categoryID = nil; selectedID = nil; centeredID = nil; orientation = originalOrientation }
        showTags = false
    }
    private func cycleCategory(_ offset: Int) {
        guard let current = categoryID, let index = populatedCategories.firstIndex(of: current), !populatedCategories.isEmpty else { return }
        let ids = populatedCategories
        openCategory(ids[(index + offset + ids.count) % ids.count])
        if demo != nil && trainingStep == .swipeTags { trainingStep = .finish }
    }
    private func reconcileSelection() {
        guard initialised, demo == nil else { return }
        if let categoryID {
            let candidates = thoughts.filter { $0.tagId == categoryID }
            if candidates.isEmpty { closeCategory() }
            else if !candidates.contains(where: { $0.id == selectedID }) {
                selectedID = candidates.first?.id; centeredID = selectedID
            }
        } else if !thoughts.contains(where: { $0.id == selectedID }) { selectedID = nil }
    }
    private func bringForward(_ thought: ThoughtRecord, index: Int) {
        stopSpin()
        guard demo == nil else { editor = thought; return }
        if categoryID == nil {
            let current = orientation.rotate(SphereMath.generatePoint(index: index, total: thoughts.count))
            let delta = Quaternion.fromVectors(current, Point3D(x: 0, y: 0, z: 1))
            withAnimation(transition) { orientation = (delta * orientation).normalized(); selectedID = thought.id }
        }
        pendingFocusTask?.cancel()
        pendingFocusTask = Task { @MainActor in
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(250)) }
            guard !Task.isCancelled else { return }
            focused = thought
        }
    }
    private func addThought(tagID: Int = 0) {
        stopSpin()
        let new = ThoughtRecord(text: "", tagId: tagID)
        if demo != nil {
            demo?.append(new)
            selectedID = new.id
            if categoryID != nil { centeredID = new.id }
        }
        editor = new
    }
    private func registerCaptureIfNeeded(_ original: ThoughtRecord) {
        if original.text.isEmpty && !fixture {
            captureCount += 1
            if captureCount >= 5 && !reminderAsked && !notificationsEnabled && Date().timeIntervalSince1970 >= reminderSnooze {
                reminderAsked = true; showReminderPrompt = true
            }
        }
    }
    private func retag(_ id: String, to category: Int) {
        guard var thought = thoughts.first(where: { $0.id == id }) else { return }
        chooseNeighbour(removing: id)
        thought.tagId = category
        if demo != nil { mutateDemo(thought); if trainingStep == .retagTile { trainingStep = .completeTile } }
        else { perform { try store.update(thought) } }
        showTags = false
        reconcileDemoSelection()
    }
    private func chooseNeighbour(removing id: String) {
        guard selectedID == id, let index = categoryThoughts.firstIndex(where: { $0.id == id }) else { return }
        let candidates = categoryThoughts
        let neighbour = index + 1 < candidates.count ? candidates[index + 1].id : (index > 0 ? candidates[index - 1].id : nil)
        selectedID = neighbour; centeredID = neighbour
    }
    private func archive(_ thought: ThoughtRecord, status: ThoughtRecord.Status) {
        chooseNeighbour(removing: thought.id)
        if demo != nil {
            demo?.removeAll { $0.id == thought.id }
            if trainingStep == .completeTile { trainingStep = .addThoughtTile }
            reconcileDemoSelection()
        } else {
            var updated = thought; updated.status = status; updated.archivedAt = Date()
            perform { try store.update(updated) }
        }
    }
    private func thumbnail(for thought: ThoughtRecord) -> URL? {
        guard let name = thought.attachments.first(where: { $0.kind == .image })?.filename,
              AttachmentStore.isSafeFilename(name) else { return nil }
        return store.attachmentDirectory.appendingPathComponent(name)
    }

    private func drag(_ value: DragGesture.Value, size: CGSize) {
        stopSpin()
        let point = SphereMath.mapToSphere(point: value.location, in: size)
        if dragStart == nil {
            dragStart = SphereMath.mapToSphere(point: value.startLocation, in: size)
            dragOrientation = orientation; lastDragPoint = dragStart!; lastDragTime = Date()
        }
        guard let dragStart else { return }
        let now = Date(), dt = max(0.001, now.timeIntervalSince(lastDragTime))
        let delta = Quaternion.fromVectors(lastDragPoint, point).toAxisAngle()
        angularVelocity = delta.axis * min(8, delta.angle / dt)
        orientation = (Quaternion.fromVectors(dragStart, point) * dragOrientation).normalized()
        lastDragPoint = point; lastDragTime = now
        if demo != nil && trainingStep == .spinSphere { trainingStep = .openTagView }
    }
    private func endDrag() {
        dragStart = nil
        guard !reduceMotion, angularVelocity.length > 0.04 else { stopSpin(); return }
        spinning = true; lastFrame = 0
        displayDriver.onStep = { time in
            guard scenePhase == .active, spinning else { stopSpin(); return }
            guard lastFrame > 0 else { lastFrame = time; return }
            let dt = min(0.05, time - lastFrame); lastFrame = time
            let speed = angularVelocity.length
            guard speed > 0.04 else { stopSpin(); return }
            orientation = (Quaternion.fromAxisAngle(axis: angularVelocity.normalized(), angle: speed * dt) * orientation).normalized()
            angularVelocity = angularVelocity * exp(-2.2 * dt)
        }
        displayDriver.start(preferredFPS: ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60)
    }
    private func stopSpin() { displayDriver.stop(); displayDriver.onStep = nil; spinning = false; lastFrame = 0 }

    private func initialise() async {
        guard !initialised else { return }; initialised = true
        refreshCategories()
        if fixture {
            let records = (1...12).map { number in
                ThoughtRecord(id: "fixture-\(number)", text: String(format: "Fixture thought %02d", number) + (number == 1 ? "\nThe complete thought remains readable after opening the expanded tile." : ""))
            }
            perform { try store.importRecords(records, replacing: true) }
            openCategory(0, preferred: "fixture-1")
            return
        }
        if let storageError = store.storageError { error = storageError; return }
        await importSharedCaptures()
        if store.thoughts.isEmpty && !trainingCompleted { startTraining() }
        openPendingNotification(); updateReminders()
    }
    private func refreshCategories() {
        let visible = store.tags.filter { $0.isDeleted != true }
        if !visible.isEmpty { tagManager.tags = visible.map { Tag(id: $0.id, name: $0.name, color: TagColor(rawValue: $0.color) ?? .grey, isDefault: $0.isDefault) } }
        reconcileSelection()
    }
    private func importSharedCaptures() async {
        guard !fixture else { return }
        let errors = await CaptureInbox.shared.importPending()
        if !errors.isEmpty { error = errors.joined(separator: "\n") }
    }
    private func updateReminders() {
        guard demo == nil, !fixture else { return }
        BrainDumpNotificationManager.updateNightlyReminder(unsortedCount: store.activeThoughts.filter { $0.tagId == 0 }.count)
    }
    private func enableReminders() {
        BrainDumpNotificationManager.requestAuthorization { granted in
            if granted { updateReminders() }
        }
    }
    private func openPendingNotification() {
        guard demo == nil, BrainDumpNotificationManager.consumePendingOpenBrainDump() else { return }
        openCategory(0, showPicker: true)
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }

    private var settings: some View {
        Group {
        #if DEBUG
        SettingsView(isPresented: $showSettings, tagManager: tagManager,
            tileTags: Binding(get: { store.activeThoughts.map(\.tagId) }, set: { tags in
                for (thought, tag) in zip(store.activeThoughts, tags) where thought.tagId != tag {
                    var updated = thought; updated.tagId = tag; perform { try store.update(updated) }
                }
            }), completedTiles: archiveBinding(.completed), deletedTiles: archiveBinding(.deleted),
            onResetApp: { perform { try store.importRecords([], replacing: true) }; closeCategory() },
            onSaveArchives: {}, exportBackupData: { Data() }, importBackupData: { _ in },
            replaceBackupData: { _ in }, exportCSVData: exportCSV,
            searchTiles: { query in
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
                return summaries.filter { $0.text.localizedCaseInsensitiveContains(query) }
            }, duplicateGroups: duplicates, removeDuplicates: removeDuplicates,
            onRestoreArchived: { archive in
                guard var thought = store.thought(id: archive.id) else { return }
                thought.status = .active; thought.archivedAt = nil
                perform { try store.update(thought) }
            }, tagNameProvider: { tagManager.getTag(byId: $0)?.name ?? "Brain Dump" },
            onPurgeDeleted: {}, onEnableNotifications: enableReminders,
            onDisableNotifications: { BrainDumpNotificationManager.setNotificationsEnabled(false) },
            onBackupNow: { Task { await sync.syncNow() } }, onReplayTrainingDemo: startTraining,
            isTrainingMode: demo != nil, showDebugPanel: $showDebug, onCreateTestTiles: createTestTiles
        )
        #else
        SettingsView(isPresented: $showSettings, tagManager: tagManager,
            tileTags: Binding(get: { store.activeThoughts.map(\.tagId) }, set: { tags in
                for (thought, tag) in zip(store.activeThoughts, tags) where thought.tagId != tag {
                    var updated = thought; updated.tagId = tag; perform { try store.update(updated) }
                }
            }), completedTiles: archiveBinding(.completed), deletedTiles: archiveBinding(.deleted),
            onResetApp: { perform { try store.importRecords([], replacing: true) }; closeCategory() },
            onSaveArchives: {}, exportBackupData: { Data() }, importBackupData: { _ in },
            replaceBackupData: { _ in }, exportCSVData: exportCSV,
            searchTiles: { query in
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
                return summaries.filter { $0.text.localizedCaseInsensitiveContains(query) }
            }, duplicateGroups: duplicates, removeDuplicates: removeDuplicates,
            onRestoreArchived: { archive in
                guard var thought = store.thought(id: archive.id) else { return }
                thought.status = .active; thought.archivedAt = nil
                perform { try store.update(thought) }
            }, tagNameProvider: { tagManager.getTag(byId: $0)?.name ?? "Brain Dump" },
            onPurgeDeleted: {}, onEnableNotifications: enableReminders,
            onDisableNotifications: { BrainDumpNotificationManager.setNotificationsEnabled(false) },
            onBackupNow: { Task { await sync.syncNow() } }, onReplayTrainingDemo: startTraining,
            isTrainingMode: demo != nil
        )
        #endif
        }
        .presentationDetents([.medium, .large])
    }
    private func archiveBinding(_ status: ThoughtRecord.Status) -> Binding<[ArchivedTile]> {
        Binding(get: {
            store.thoughts.filter { $0.status == status && (status != .deleted || ($0.archivedAt ?? $0.modifiedAt) > Date().addingTimeInterval(-30 * 86400)) }.map {
                ArchivedTile(id: $0.id, text: $0.text, tagId: $0.tagId, archivedAt: $0.archivedAt ?? $0.modifiedAt)
            }
        }, set: { archives in
            let retained = Set(archives.map(\.id))
            for var thought in store.thoughts where thought.status == status && !retained.contains(thought.id) {
                thought.status = .deleted
                // Keep a sync tombstone without displaying a permanently removed archive.
                thought.archivedAt = .distantPast
                perform { try store.update(thought) }
            }
        })
    }
    private var summaries: [TileSummary] {
        store.activeThoughts.map { TileSummary(id: $0.id, text: $0.text, tagId: $0.tagId,
            tagName: tagManager.getTag(byId: $0.tagId)?.name ?? "Brain Dump") }
    }
    private func duplicates() -> [DuplicateGroup] {
        let grouped = Dictionary(grouping: summaries.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            "\($0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\($0.tagId)"
        }
        return grouped.filter { $0.value.count > 1 }.map { DuplicateGroup(id: $0.key, key: $0.key, items: $0.value) }.sorted { $0.items.count > $1.items.count }
    }
    private func removeDuplicates() -> Int {
        let ids = duplicates().flatMap { $0.items.dropFirst().map(\.id) }
        for id in ids { if let thought = store.thought(id: id) { archive(thought, status: .deleted) } }
        return ids.count
    }
    private func exportCSV() -> Data {
        func quoted(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let rows = summaries.map { [quoted($0.id), quoted($0.text), String($0.tagId), quoted($0.tagName)].joined(separator: ",") }
        return (["id,text,tagId,tagName"] + rows).joined(separator: "\n").data(using: .utf8) ?? Data()
    }
    #if DEBUG
    private func createTestTiles() {
        for index in 1...10 { perform { try store.capture(text: "Test thought \(index)") } }
    }
    #endif

    private var trainingText: String {
        switch trainingStep {
        case .spinSphere: "This is your living brain. Drag to explore your thoughts."
        case .openTagView: "Tap a tile to bring its category forward."
        case .scrollTagView: "Scroll through this category’s tiles."
        case .retagTile: "Use the tag button to organise a thought."
        case .completeTile: "Use the checkmark to complete a thought."
        case .addThoughtTile: "Tap + to capture a new thought."
        case .swipeTags: "Swipe sideways or use the arrows to explore another category."
        case .finish: "Long press any tile to read the whole thought. Your brain is ready."
        }
    }
    private var trainingHighlight: TileActionButtons.HighlightedAction? {
        guard demo != nil else { return nil }
        switch trainingStep {
        case .retagTile: return .tag
        case .completeTile: return .complete
        case .addThoughtTile: return .add
        default: return nil
        }
    }
    private func startTraining() {
        stopSpin(); showSettings = false
        replayCategory = categoryID; replaySelection = selectedID
        demo = [
            ThoughtRecord(text: "Tap a thought to bring its category forward."),
            ThoughtRecord(text: "Scroll through your thoughts."),
            ThoughtRecord(text: "Use the tag button to organise this thought."),
            ThoughtRecord(text: "Complete a thought with the checkmark."),
            ThoughtRecord(text: "Capture a new thought with +.", tagId: 3)
        ]
        categoryID = nil; selectedID = nil; centeredID = nil; trainingStep = .spinSphere
    }
    private func finishTraining() {
        demo = nil; trainingCompleted = true; categoryID = replayCategory; selectedID = replaySelection
        centeredID = selectedID; reconcileSelection(); openPendingNotification()
    }
    private func mutateDemo(_ thought: ThoughtRecord) {
        if let index = demo?.firstIndex(where: { $0.id == thought.id }) { demo?[index] = thought }
        else { demo?.append(thought) }
        reconcileDemoSelection()
    }
    private func reconcileDemoSelection() {
        guard demo != nil, let categoryID else { return }
        let candidates = thoughts.filter { $0.tagId == categoryID }
        if candidates.isEmpty { closeCategory() }
        else if !candidates.contains(where: { $0.id == selectedID }) { selectedID = candidates.first?.id; centeredID = selectedID }
    }
}

private struct TrainingThoughtEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var thought: ThoughtRecord
    var save: (ThoughtRecord) -> Void
    var body: some View {
        NavigationStack {
            TextEditor(text: $thought.text).font(.body).padding()
                .navigationTitle("Practice thought")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save(thought); dismiss() }.disabled(thought.text.isEmpty) }
                }
        }
    }
}

#Preview {
    ContentView().environmentObject(CloudSyncService(store: .shared))
}
