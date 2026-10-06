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
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "3C315C"
    @AppStorage("UserSphereScale") private var sphereScale = 0.95
    @AppStorage("TrainingCompleted") private var trainingCompleted = false
    @AppStorage("BrainDumpNotificationsEnabled") private var notificationsEnabled = false
    @AppStorage("NotificationPromptCreatedTileCount") private var captureCount = 0
    @AppStorage("NotificationPromptAskedAfterFiveCreatedTiles") private var reminderAsked = false
    @AppStorage("NotificationPromptSnoozedUntilTimestamp") private var reminderSnooze: Double = 0
    @State private var spherePositions: [String: Int] = [:]
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
    @State private var sphereStaged = false
    @State private var categoryTilesArrived = true
    @State private var categoryFlightID = UUID()
    @State private var categoryTransitioning = false
    @State private var focused: ThoughtRecord?
    @State private var editor: ThoughtRecord?
    @State private var capture: ThoughtRecord?
    @State private var captureSaved: ThoughtRecord?
    @State private var captureSaveTask: Task<Void, Never>?
    @State private var captureOrientation = Quaternion.identity
    @State private var discardingCapture = false
    @State private var captureDismissTask: Task<Void, Never>?
    @State private var organisingInbox = false
    @State private var departingThoughtID: String?
    @State private var completingThoughtID: String?
    @State private var completionTask: Task<Void, Never>?
    @State private var categorisationTask: Task<Void, Never>?
    @State private var showTags = false
    @State private var showSettings = false
    @State private var pendingSearchTileID: String?
    @State private var showPro = false
    @State private var showDelete = false
    @State private var showReminderPrompt = false
    @State private var error: String?
    @State private var initialised = false
    @State private var demo: [ThoughtRecord]?
    @State private var trainingStep = TrainingStep.spinSphere
    @State private var trainingReadPresented = false
    @State private var trainingCaptureID: String?
    @State private var keepsTrainingCapture = false
    @State private var previousTrainingSelection: String?
    @State private var replayCategory: Int?
    @State private var replaySelection: String?
    @State private var pendingFocusTask: Task<Void, Never>?
    #if DEBUG
    @AppStorage("ShowDebugPanel") private var showDebug = false
    #endif

    private var fixture: Bool { ProcessInfo.processInfo.arguments.contains("--living-brain-fixture") }
    private var thoughts: [ThoughtRecord] {
        let records = demo ?? store.activeThoughts
        if let capture, !records.contains(where: { $0.id == capture.id }) { return records + [capture] }
        return records
    }
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
                SceneLight()
                if categoryID != nil { categoryTiles(in: geometry) }
                else {
                    sphere(in: geometry).zIndex(1)
                        .task {
                            guard sphereStaged, !reduceMotion else { return }
                            let flightID = categoryFlightID
                            await Task.yield()
                            guard !Task.isCancelled, categoryFlightID == flightID else { return }
                            withAnimation(.easeInOut(duration: 0.4), completionCriteria: .removed) {
                                sphereStaged = false
                            } completion: {
                                guard categoryFlightID == flightID else { return }
                                categoryTransitioning = false
                            }
                        }
                }
                if capture == nil { controls }
                else {
                    VStack {
                        Text(tagManager.getTag(byId: capture?.tagId ?? 0)?.name ?? "Unsorted").font(.headline).padding(12).background(.regularMaterial, in: Capsule())
                        Spacer()
                        Button("Done") { finishCapture() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("thought-save")
                            .disabled(discardingCapture)
                            .padding()
                    }.zIndex(25)
                }
                if categoryID != nil { categoryHeader }
                if capture == nil, let selected { actions(for: selected) }
                if demo != nil {
                    TrainingBannerView(instruction: trainingText, progress: trainingStep.rawValue,
                        canFinish: trainingStep == .finish, onFinish: finishTraining)
                        .zIndex(30)
                }
                #if DEBUG
                if showDebug { DebugPanelView(tileCount: thoughts.count).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding().allowsHitTesting(false) }
                #endif
            }
            .allowsHitTesting(!categoryTransitioning)
        }
        .overlay(alignment: .bottom) {
            if showTags, let selected {
                CategoryPickerView(tagManager: tagManager, selectedTagId: Binding(get: {
                    thoughts.first { $0.id == selected.id }?.tagId ?? 0
                }, set: { retag(selected.id, to: $0) }), onDismiss: { showTags = false })
                .frame(height: 160)
                .accessibilityIdentifier("thought-category-picker")
                .disabled(departingThoughtID != nil || categoryTransitioning)
            }
        }
        .task { await initialise(); refreshSphereLayout() }
        .sheet(isPresented: $showPro) { ProPurchaseView() }
        .sheet(item: $focused, onDismiss: reconcileSelection) { ThoughtFocusView(thoughtID: $0.id) }
        .sheet(item: $editor, onDismiss: {
            if demo != nil && trainingStep == .readThought && trainingReadPresented {
                trainingReadPresented = false
                trainingStep = .returnHome
            }
            reconcileSelection()
        }) { thought in
            if demo != nil {
                TrainingThoughtEditor(thought: thought, readOnly: trainingStep == .readThought) { updated in
                    mutateDemo(updated)
                }
            } else {
                ThoughtDetailView(thought: thought) { saved in
                    registerCaptureIfNeeded(thought)
                    if categoryID != nil { openCategory(saved.tagId, preferred: saved.id) }
                    else { selectedID = saved.id }
                }
            }
        }
        .alert("Delete thought?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) { showDelete = false }
            Button("Delete", role: .destructive) { if let selected { archive(selected, status: .deleted) } }
        } message: { Text("You can restore it from Recently Deleted for 30 days.") }
        .alert("Couldn’t complete this action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
        .alert("Enable nightly reminders?", isPresented: $showReminderPrompt) {
            Button("Not now", role: .cancel) { reminderSnooze = Date().addingTimeInterval(7 * 86400).timeIntervalSince1970 }
            Button("Enable reminders", action: enableReminders)
        } message: { Text("Receive a single nightly reminder to organise your Brain Dumps.") }
        .onChange(of: thoughts.map(\.id)) { _, _ in refreshSphereLayout() }
        .onChange(of: store.thoughts) { _, _ in
            reconcileSelection()
            updateReminders()
        }
        .onChange(of: store.tags) { _, _ in refreshCategories() }
        .onChange(of: tagManager.saveError) { _, value in if let value { error = value } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await ProStore.shared.refreshEntitlements(); await importSharedCaptures(); openPendingNotification() }
            } else {
                stopSpin(); pendingFocusTask?.cancel()
                cancelCategoryFlight()
                _ = persistCapture()
                if phase == .background { finishCapture() }
            }
        }
        .onChange(of: reduceMotion) { _, enabled in if enabled { stopSpin() } }
        .onReceive(NotificationCenter.default.publisher(for: BrainDumpNotificationManager.openBrainDumpNotificationName)) { _ in openPendingNotification() }
        .onDisappear { stopSpin(); pendingFocusTask?.cancel(); cancelCategoryFlight(); _ = persistCapture() }
    }

    /// Layout metadata only: record order and category browsing remain unchanged.
    private func refreshSphereLayout() {
        let ids = thoughts.map(\.id)
        let active = Set(ids)
        guard active != Set(spherePositions.keys) else { return }
        var order = spherePositions.sorted { $0.value < $1.value }.map(\.key).filter { active.contains($0) }
        let existing = Set(order)
        for id in ids.filter({ !existing.contains($0) }).shuffled() {
            order.insert(id, at: Int.random(in: 0...order.count))
        }
        spherePositions = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
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
        .gesture(DragGesture(minimumDistance: 12).onChanged { drag($0, size: geometry.size) }.onEnded { _ in endDrag() }, including: capture == nil ? .all : .subviews)
        .simultaneousGesture(MagnifyGesture().onChanged { value in
            guard demo == nil else { return }
            stopSpin()
            if pinchStart == nil { pinchStart = sphereScale }
            sphereScale = min(1.6, max(0.45, (pinchStart ?? sphereScale) * value.magnification))
        }.onEnded { _ in pinchStart = nil }, including: capture == nil ? .all : .subviews)
    }

    private func categoryTiles(in geometry: GeometryProxy) -> some View {
        let rowHeight: CGFloat = 184
        let padding = max(0, (geometry.size.height - rowHeight) / 2)
        let indices = Dictionary(thoughts.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
        return ScrollViewReader { proxy in
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(categoryThoughts) { thought in
                    let index = indices[thought.id] ?? 0
                    CylinderTileRow(containerMidY: geometry.frame(in: .global).midY,
                        rowHeight: rowHeight, isSelected: centeredID == thought.id,
                        flightOrigin: categoryTilesArrived || reduceMotion ? nil : categoryFlightOrigin(index: index, in: geometry)) {
                        tile(thought, index: index, geometry: geometry, filtered: true)
                            .offset(x: departingThoughtID == thought.id ? geometry.size.width : 0,
                                    y: departingThoughtID == thought.id ? -80 : 0)
                            .opacity(departingThoughtID == thought.id ? 0 : 1)
                    }
                    .background {
                        Color.clear.contentShape(Rectangle()).onTapGesture {
                            guard capture == nil, demo == nil else { return }
                            handleCategoryBackgroundTap()
                        }
                    }
                    .id(thought.id)
                    .zIndex(completingThoughtID == thought.id ? 100 : (centeredID == thought.id ? 10 : 0))
                }
            }
            .scrollTargetLayout()
        }
        .background {
            Color.clear.contentShape(Rectangle()).onTapGesture {
                guard capture == nil, demo == nil else { return }
                handleCategoryBackgroundTap()
            }
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
            guard let id, !categoryTransitioning, categoryThoughts.contains(where: { $0.id == id }) else { return }
            selectedID = id
            if let categoryID { categoryPositions[categoryID] = id }
            if demo != nil, trainingStep == .scrollTagView,
               let previousTrainingSelection, previousTrainingSelection != id { trainingStep = .retagTile }
            previousTrainingSelection = id
        }
        .task(id: categoryID) {
            let target = selectedID ?? categoryThoughts.first?.id
            await Task.yield()
            if let target { proxy.scrollTo(target, anchor: .center); centeredID = target }
            // Allow native scroll positioning to settle before the tiles land.
            do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
            guard !Task.isCancelled, !categoryTilesArrived else { return }
            let flightID = categoryFlightID
            withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.88), completionCriteria: .removed) {
                categoryTilesArrived = true
            } completion: {
                guard categoryFlightID == flightID else { return }
                categoryTransitioning = false
            }
        }
        .onChange(of: capture?.id) { _, id in
            if let id { proxy.scrollTo(id, anchor: .center); centeredID = id }
        }
        }

    }

    /// Fixed ring outside every screen edge, calculated only for materialised lazy rows.
    private func categoryFlightOrigin(index: Int, in geometry: GeometryProxy) -> CGPoint {
        let frame = geometry.frame(in: .global)
        let radius = hypot(geometry.size.width, geometry.size.height) / 2 + 160
        let angle = Double(index) * 2.399963229728653 // Golden angle keeps origins spread out.
        return CGPoint(x: frame.midX + radius * cos(angle), y: frame.midY + radius * sin(angle))
    }

    private func tile(_ thought: ThoughtRecord, index: Int, geometry: GeometryProxy, filtered: Bool) -> some View {
        let category = store.tags.first { $0.id == thought.tagId }
        return TileView(index: index, text: capture?.id == thought.id ? capture?.text ?? thought.text : thought.text,
            isSelected: filtered ? centeredID == thought.id : selectedID == thought.id,
            isEditing: capture?.id == thought.id, isNewTile: capture?.id == thought.id, isDeleting: false, isCompleting: completingThoughtID == thought.id,
            focusRequestId: thought.id.stableUUID, orientation: orientation, containerSize: geometry.size,
            totalCount: thoughts.count, sphereScale: sphereScale, tagId: thought.tagId,
            tagManager: tagManager, onTap: { select(thought) }, isTapEnabled: capture == nil && (demo == nil || trainingStep == .openTagView),
            onTextChange: { updateCaptureText($0) }, isTagChanging: false, isFiltered: filtered,
            listPosition: filtered ? index : nil,
            filteredIndices: filtered ? [index] : nil,
            fillColor: TilePalette.color(thought.fillHex ?? TilePalette.categoryFill(category, fallback: defaultFill)),
            borderColor: TilePalette.color(thought.borderHex ?? TilePalette.categoryBorder(category, fallback: defaultBorder)),
            thumbnailURL: thumbnail(for: thought), onLongPress: { bringForward(thought, index: index) },
            isDiscarding: discardingCapture && capture?.id == thought.id,
            sphereIndex: spherePositions[thought.id] ?? index,
            sphereFlightPosition: !filtered && sphereStaged && !reduceMotion
                ? CGPoint(x: categoryFlightOrigin(index: index, in: geometry).x - geometry.frame(in: .global).minX,
                          y: categoryFlightOrigin(index: index, in: geometry).y - geometry.frame(in: .global).minY) : nil,
            isDemo: demo != nil && !(keepsTrainingCapture && thought.id == trainingCaptureID))
    }

    private var categoryHeader: some View {
        VStack {
            TagFilterListView(tagIds: populatedCategories, selectedTagId: Binding(get: { categoryID ?? 0 }, set: { openCategory($0) }), tagManager: tagManager)
                .frame(height: 96)
                .disabled(demo != nil && trainingStep != .swipeTags)
            Spacer().allowsHitTesting(false)
        }.zIndex(20)
    }

    @State private var showSyncStatus = false

    private var controls: some View {
        VStack {
            if categoryID == nil {
                HStack {
                    Spacer()
                    Button { showSyncStatus = true } label: {
                        Group {
                            if sync.indicatorState == .syncing {
                                ProgressView().tint(.primary)
                            } else {
                                Image(systemName: sync.indicatorState == .upToDate ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(sync.indicatorState == .upToDate ? Color.green : Color.orange)
                            }
                        }.frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("iCloud sync")
                    .accessibilityValue(sync.status)
                    .accessibilityHint("Opens sync status and controls")
                    .disabled(demo != nil)
                }.padding(.horizontal, 24).padding(.top, 8)
            }
            Spacer().allowsHitTesting(false)
            HStack {
                if categoryID == nil {
                    GlassButton(icon: "gearshape.fill") { stopSpin(); showSettings = true }
                        .disabled(demo != nil)
                    Spacer()
                    Button { openCategory(0, showPicker: true) } label: {
                        Image("Image").resizable().scaledToFit().frame(width: 62, height: 62)
                    }.buttonStyle(BrainDumpButtonStyle()).accessibilityLabel("Organise Brain Dump inbox")
                    .disabled(demo != nil)
                    Spacer()
                    GlassButton(icon: "plus") { addThought() }
                        .disabled(demo != nil && trainingStep != .addThoughtTile)
                }
            }.padding(.horizontal, 24).padding(.bottom, 16)
        }.zIndex(15)
        .sheet(isPresented: $showSettings, onDismiss: openSearchTile) { settings }
        .sheet(isPresented: $showSyncStatus) { SyncSettingsView() }
    }

    private func actions(for thought: ThoughtRecord) -> some View {
        TileActionButtons(onClose: closeCategory, onEdit: { stopSpin(); editor = thought },
            onChangeTag: { showTags.toggle() }, onComplete: { archive(thought, status: .completed) },
            onDelete: { showDelete = true }, onAdd: { addThought() },
            closeIcon: "xmark", closeForegroundColor: .primary,
            closeBorderColor: nil, highlightedAction: trainingHighlight, showFloatingAddButton: true,
            trainingRestricted: demo != nil)
            .disabled(completingThoughtID != nil)
            .zIndex(25)
    }

    private func select(_ thought: ThoughtRecord) {
        guard demo == nil || trainingStep == .openTagView else { return }
        stopSpin()
        if categoryID == nil { openCategory(thought.tagId, preferred: thought.id) }
        else { withAnimation(transition) { centeredID = thought.id; selectedID = thought.id } }
        if demo != nil && trainingStep == .openTagView {
            trainingStep = .scrollTagView; previousTrainingSelection = thought.id
        }
    }

    private func openCategory(_ id: Int, preferred: String? = nil, showPicker: Bool = false, animateDeparture: Bool = true) {
        guard !categoryTransitioning else { return }
        let sortingInbox = showPicker || (id == 0 && demo == nil)
        let candidates = thoughts.filter { $0.tagId == id }
        guard !candidates.isEmpty else { Haptics.negativeDoubleTap(); return }
        stopSpin()
        if animateDeparture, let current = categoryID, current != id, !reduceMotion {
            flyCategoryOut {
                openCategory(id, preferred: preferred, showPicker: showPicker, animateDeparture: false)
            }
            return
        }
        if animateDeparture, categoryID == nil, !reduceMotion {
            originalOrientation = orientation
            let flightID = UUID()
            categoryFlightID = flightID
            categoryTransitioning = true
            withAnimation(.easeInOut(duration: 0.4), completionCriteria: .removed) {
                sphereStaged = true
            } completion: {
                guard categoryFlightID == flightID else { return }
                categoryTransitioning = false
                openCategory(id, preferred: preferred, showPicker: showPicker, animateDeparture: false)
            }
            return
        }
        if categoryID == nil { originalOrientation = orientation }
        let remembered = preferred ?? categoryPositions[id]
        let target = candidates.first(where: { $0.id == remembered })?.id ?? candidates.first?.id
        if demo != nil, trainingStep == .swipeTags, let current = categoryID, current != id {
            trainingStep = .readThought
        }
        if categoryID != id {
            // Position the collection before flying it in from the offscreen ring.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                categoryFlightID = UUID()
                categoryTransitioning = !reduceMotion
                categoryTilesArrived = reduceMotion
                categoryID = id; selectedID = target; centeredID = target
            }
        } else {
            withAnimation(transition) { selectedID = target; centeredID = target }
        }
        showTags = sortingInbox
        organisingInbox = sortingInbox
    }
    private func handleCategoryBackgroundTap() {
        if showTags {
            showTags = false
        } else {
            closeCategory()
        }
    }

    private func closeCategory() {
        guard demo == nil || trainingStep == .returnHome else { return }
        guard !categoryTransitioning else { return }
        stopSpin()
        if categoryID != nil, !reduceMotion {
            flyCategoryOut { finishClosingCategory() }
        } else { finishClosingCategory() }
    }

    private func finishClosingCategory() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            categoryID = nil; selectedID = nil; centeredID = nil
            orientation = originalOrientation; categoryTilesArrived = true
            categoryTransitioning = sphereStaged && !reduceMotion
        }
        showTags = false
        organisingInbox = false
        if demo != nil && trainingStep == .returnHome { trainingStep = .finish }
    }

    /// Finish every animated frame before replacing or dismissing the collection.
    private func flyCategoryOut(then action: @escaping @MainActor () -> Void) {
        let flightID = UUID()
        categoryFlightID = flightID
        categoryTransitioning = true
        withAnimation(.easeInOut(duration: 0.3), completionCriteria: .removed) {
            categoryTilesArrived = false
        } completion: {
            guard categoryFlightID == flightID else { return }
            categoryTransitioning = false
            action()
        }
    }

    private func cancelCategoryFlight() {
        categoryFlightID = UUID()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            categoryTransitioning = false
            sphereStaged = false
            categoryTilesArrived = true
        }
    }
    private func cycleCategory(_ offset: Int) {
        guard demo == nil || trainingStep == .swipeTags else { return }
        guard let current = categoryID, let index = populatedCategories.firstIndex(of: current), !populatedCategories.isEmpty else { return }
        let ids = populatedCategories
        openCategory(ids[(index + offset + ids.count) % ids.count])
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
        guard demo == nil else {
            guard trainingStep == .readThought, !categoryTransitioning else { return }
            trainingReadPresented = true
            editor = thought
            return
        }
        if categoryID == nil {
            let current = orientation.rotate(SphereMath.generatePoint(index: spherePositions[thought.id] ?? index, total: thoughts.count))
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
    private func addThought() {
        guard demo == nil || trainingStep == .addThoughtTile || trainingStep == .createFirstTile else { return }
        stopSpin()
        guard demo != nil || store.canCreateThought else { showPro = true; return }
        let new = ThoughtRecord(text: "", tagId: categoryID ?? 0)
        let saved: ThoughtRecord
        if demo != nil {
            demo?.append(new)
            trainingCaptureID = new.id
            trainingStep = .createFirstTile
            saved = new
        } else {
            // A blank capture is only a transient sphere tile, never a saved record.
            saved = new
        }
        captureOrientation = orientation
        captureSaved = saved
        capture = saved
        refreshSphereLayout()
        if categoryID != nil {
            selectedID = saved.id
            centeredID = saved.id
            showTags = false
        } else if let index = thoughts.firstIndex(where: { $0.id == saved.id }) {
            let point = orientation.rotate(SphereMath.generatePoint(index: spherePositions[saved.id] ?? index, total: thoughts.count))
            let delta = Quaternion.fromVectors(point, Point3D(x: 0, y: 0, z: 1))
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.78)) {
                orientation = (delta * orientation).normalized()
                selectedID = saved.id
            }
        }
    }
    private func updateCaptureText(_ text: String) {
        capture?.text = text
        captureSaveTask?.cancel()
        captureSaveTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            _ = persistCapture()
        }
    }

    @discardableResult
    private func persistCapture() -> Bool {
        captureSaveTask?.cancel()
        guard !discardingCapture, let draft = capture, let original = captureSaved,
              !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.attachments.isEmpty,
              draft != original else { return true }
        if demo != nil && !keepsTrainingCapture {
            mutateDemo(draft)
            captureSaved = draft
            return true
        }
        do {
            let (saved, _) = try store.saveEdit(draft, original: original)
            captureSaved = saved
            capture = saved
            if demo != nil { mutateDemo(saved) }
            selectedID = saved.id
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    private func finishCapture() {
        guard let draft = capture else { return }
        if discardingCapture {
            if scenePhase != .active { captureDismissTask?.cancel(); releaseCapture(turnSphere: false) }
            return
        }
        let isEmpty = draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.attachments.isEmpty
        if isEmpty {
            do {
                if demo != nil { demo?.removeAll { $0.id == draft.id } }
                if (demo == nil || keepsTrainingCapture), var stored = store.thought(id: draft.id), stored == captureSaved {
                    // Clearing an autosaved capture must also remove it from the inbox.
                    // Keep a hidden deletion marker so synced devices cannot resurrect it.
                    stored.status = .deleted
                    stored.archivedAt = .distantPast
                    try store.update(stored)
                }
            } catch { self.error = error.localizedDescription; return }
            if reduceMotion || scenePhase != .active { releaseCapture(turnSphere: false); return }
            withAnimation(.easeIn(duration: 0.38)) { discardingCapture = true }
            captureDismissTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(380)) } catch { return }
                releaseCapture(turnSphere: false)
            }
            return
        }
        guard persistCapture() else { return }
        if demo != nil && trainingStep == .createFirstTile { trainingStep = .swipeTags }
        if demo == nil { registerCaptureIfNeeded(ThoughtRecord(text: "")) }
        releaseCapture(turnSphere: true)
    }

    private func releaseCapture(turnSphere: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.88)) {
            capture = nil
            captureSaved = nil
            // Compact shuffled slots in the same transaction as removing the draft.
            refreshSphereLayout()
            if let categoryID {
                let target = thoughts.first(where: { $0.id == selectedID })?.id ?? categoryThoughts.first?.id
                selectedID = target
                centeredID = target
                categoryPositions[categoryID] = target
                showTags = organisingInbox
            } else { selectedID = nil }
            discardingCapture = false
            if turnSphere && !reduceMotion && scenePhase == .active {
                let turn = Quaternion.fromAxisAngle(axis: Point3D(x: 0, y: 1, z: 0), angle: 0.65)
                orientation = (turn * orientation).normalized()
            } else { orientation = captureOrientation }
        }
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
        guard demo == nil || trainingStep == .retagTile else { return }
        guard let thought = thoughts.first(where: { $0.id == id }), thought.tagId != category,
              departingThoughtID == nil else { return }
        if organisingInbox && !reduceMotion && demo == nil {
            withAnimation(.easeIn(duration: 0.25)) { departingThoughtID = id }
            categorisationTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                commitCategory(id, to: category)
                departingThoughtID = nil
            }
        } else { commitCategory(id, to: category) }
    }

    private func commitCategory(_ id: String, to category: Int) {
        guard var thought = thoughts.first(where: { $0.id == id }) else { return }
        thought.tagId = category
        if demo != nil {
            chooseNeighbour(removing: id)
            mutateDemo(thought)
            if trainingStep == .retagTile { trainingStep = .completeTile }
        } else {
            do {
                try store.update(thought)
            } catch { self.error = error.localizedDescription; return }
        }
        showTags = organisingInbox
        reconcileDemoSelection()
    }
    private func chooseNeighbour(removing id: String) {
        guard selectedID == id, let index = categoryThoughts.firstIndex(where: { $0.id == id }) else { return }
        let candidates = categoryThoughts
        let neighbour = index + 1 < candidates.count ? candidates[index + 1].id : (index > 0 ? candidates[index - 1].id : nil)
        selectedID = neighbour; centeredID = neighbour
    }
    private func archive(_ thought: ThoughtRecord, status: ThoughtRecord.Status) {
        guard demo == nil || (trainingStep == .completeTile && status == .completed) else { return }
        guard completingThoughtID == nil else { return }
        if status == .completed && !reduceMotion {
            stopSpin()
            withAnimation(.easeIn(duration: 0.6)) { completingThoughtID = thought.id }
            completionTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                commitArchive(thought, status: status)
                completingThoughtID = nil
            }
        } else { commitArchive(thought, status: status) }
    }

    private func commitArchive(_ thought: ThoughtRecord, status: ThoughtRecord.Status) {
        // Animate the row removal and native scroll selection together so the
        // neighbouring tile visibly settles into the centre after archiving.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            chooseNeighbour(removing: thought.id)
            if demo != nil {
                demo?.removeAll { $0.id == thought.id }
                if trainingStep == .completeTile { trainingStep = .addThoughtTile }
                reconcileDemoSelection()
            } else {
                var updated = store.thought(id: thought.id) ?? thought
                updated.status = status
                updated.archivedAt = Date()
                perform { try store.update(updated) }
            }
        }
    }
    private func thumbnail(for thought: ThoughtRecord) -> URL? {
        guard let name = thought.attachments.first(where: { $0.kind == .image })?.filename,
              AttachmentStore.isSafeFilename(name) else { return nil }
        return store.attachmentDirectory.appendingPathComponent(name)
    }

    private func drag(_ value: DragGesture.Value, size: CGSize) {
        guard demo == nil || trainingStep == .spinSphere || trainingStep == .openTagView else { return }
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
        #if DEBUG
        if fixture && ProcessInfo.processInfo.arguments.contains("--app-store-screenshots") {
            prepareScreenshotLibrary()
            return
        }
        #endif
        if ProcessInfo.processInfo.arguments.contains("--training-fixture") {
            startTraining()
            return
        }
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
                return searchableSummaries.filter { $0.text.localizedCaseInsensitiveContains(query) }
            }, onOpenSearchTile: { id in
                pendingSearchTileID = id
                showSettings = false
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
                return searchableSummaries.filter { $0.text.localizedCaseInsensitiveContains(query) }
            }, onOpenSearchTile: { id in
                pendingSearchTileID = id
                showSettings = false
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
    private func openSearchTile() {
        guard let id = pendingSearchTileID else { return }
        pendingSearchTileID = nil
        guard let thought = store.thought(id: id), thought.status == .active else { return }
        openCategory(thought.tagId, preferred: id)
    }
    private var searchableSummaries: [TileSummary] {
        store.thoughts.filter {
            $0.status != .deleted || ($0.archivedAt ?? $0.modifiedAt) > Date().addingTimeInterval(-30 * 86400)
        }.map {
            TileSummary(id: $0.id, text: $0.text, tagId: $0.tagId,
                tagName: tagManager.getTag(byId: $0.tagId)?.name ?? "Brain Dump", status: $0.status)
        }
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
        return (["id,text,categoryId,categoryName"] + rows).joined(separator: "\n").data(using: .utf8) ?? Data()
    }
    #if DEBUG
    /// Marketing captures use the isolated UI-fixture store, never the saved library.
    private func prepareScreenshotLibrary() {
        let examples: [Int: [String]] = [
            0: ["A Sunday with no plans", "Start a recipe journal", "A reading corner by the window", "Take the train somewhere new", "Learn to make fresh pasta", "A photo book of ordinary days", "Ask Dad about his childhood", "A little more time outdoors"],
            1: ["Arrival", "Spirited Away", "The Grand Budapest Hotel", "Paddington 2", "The Truman Show", "Knives Out", "Interstellar", "Fantastic Mr. Fox"],
            2: ["Project Hail Mary", "Piranesi", "The Thursday Murder Club", "The Hobbit", "A Wizard of Earthsea", "The Midnight Library", "Good Omens", "The Hitchhiker’s Guide to the Galaxy"],
            3: ["Book the dentist", "Call Mum on Sunday", "Back up the family photos", "Plan meals for next week", "Return the library books", "Fix the bike light", "Make time for a long walk", "Send Sam the holiday photos"],
            4: ["bbc.co.uk/food", "gutenberg.org", "nationaltrust.org.uk", "alltrails.com", "nasa.gov", "ifixit.com", "tate.org.uk", "goodreads.com"]
        ]
        var records = tagManager.tagsInDisplayOrder.flatMap { category in
            (examples[category.id] ?? []).enumerated().map { index, text in
                ThoughtRecord(id: "screenshot-\(category.id)-\(index)", text: text, tagId: category.id)
            }
        }
        records.append(ThoughtRecord(id: "screenshot-full", text: "A Sunday with no plans\n\nWalk to the bakery. Take a book to the park. Leave the afternoon open.\n\nNot every free day needs a to-do list. Sometimes the best idea is to make a little room.", tagId: 0))
        perform { try store.importRecords(records, replacing: true) }
        showDebug = false
        sphereScale = UIDevice.current.userInterfaceIdiom == .pad ? 0.52 : 0.95
        let view = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--screenshot-view=") }?.split(separator: "=").last.map(String.init) ?? "home"
        switch view {
        case "books": openCategory(2, preferred: "screenshot-2-0")
        case "films": openCategory(1, preferred: "screenshot-1-0")
        case "sort": openCategory(0, preferred: "screenshot-0-1", showPicker: true)
        case "capture":
            addThought()
            updateCaptureText("Bookshop coffee idea")
        case "full": focused = records.last
        default: break
        }
    }

    private func createTestTiles() {
        let categories = [0] + tagManager.tagsInDisplayOrder.map(\.id).filter { $0 != 0 }
        let examples: [Int: [String]] = [
            0: ["An idea for the weekend", "Remember that conversation from lunch", "Could this be a new project?", "A question to come back to later", "Something useful I heard today", "Plan a surprise for a friend", "Try a different morning routine", "A sketch for the spare room", "Look into that recommendation", "What made today feel productive?", "A small improvement for home", "Remember the place we walked past", "An idea for a birthday gift", "Something to discuss next week", "Save this before I forget", "A thought from the train journey", "What would make this easier?", "An interesting topic to explore", "A possible holiday idea", "Make time for a creative afternoon"],
            3: ["Book a dentist appointment", "Water the plants", "Pick up the parcel", "Plan meals for next week", "Back up the family photos", "Repair the squeaky door", "Call Mum this evening", "Make a shopping list", "Book the car service", "Return the library books", "Clear out the kitchen drawer", "Arrange a catch-up with Sam", "Replace the hallway bulb", "Schedule a haircut", "Take the recycling out", "Send the birthday card", "Organise the desk", "Check the smoke alarms", "Print the travel tickets", "Prepare tomorrow’s lunch"],
            1: ["Watch Arrival", "Watch Spirited Away", "Watch The Grand Budapest Hotel", "Watch Paddington 2", "Watch Interstellar", "Watch The Truman Show", "Watch The Martian", "Watch Knives Out", "Watch Coco", "Watch The Iron Giant", "Watch Dune", "Watch Fantastic Mr. Fox", "Watch The Princess Bride", "Watch Inside Out", "Watch WALL-E", "Watch The Prestige", "Watch Singin’ in the Rain", "Watch Apollo 13", "Watch Hunt for the Wilderpeople", "Watch Everything Everywhere All at Once"],
            2: ["Read Project Hail Mary", "Read The Hobbit", "Read A Wizard of Earthsea", "Read Pride and Prejudice", "Read The Thursday Murder Club", "Read Dune", "Read The Little Prince", "Read Piranesi", "Read The Secret Garden", "Read The Martian", "Read Good Omens", "Read The Wind in the Willows", "Read Jane Eyre", "Read The Hitchhiker’s Guide to the Galaxy", "Read The Left Hand of Darkness", "Read Frankenstein", "Read The Time Machine", "Read The Count of Monte Cristo", "Read The Night Circus", "Read The Adventures of Sherlock Holmes"],
            4: ["Explore developer.apple.com", "Browse swift.org", "Visit nationaltrust.org.uk", "Explore bbc.co.uk/food", "Browse gutenberg.org", "Visit metoffice.gov.uk", "Explore nasa.gov", "Browse wikipedia.org", "Visit tate.org.uk", "Explore britishmuseum.org", "Browse alltrails.com", "Visit rsgb.org", "Explore khanacademy.org", "Browse ifixit.com", "Visit archive.org", "Explore royalparks.org.uk", "Browse visitbritain.com", "Visit rspb.org.uk", "Explore openstreetmap.org", "Browse goodreads.com"]
        ]
        let records = (0..<100).map { index in
            let categoryID = categories[index % categories.count]
            let name = categoryID == 0 ? "Unsorted" : tagManager.getTag(byId: categoryID)?.name ?? "Category"
            let sampleIndex = index / categories.count
            let samples = examples[categoryID] ?? ["Explore an idea for \(name)", "Follow up on \(name)", "Save a recommendation for \(name)"]
            return ThoughtRecord(text: samples[sampleIndex % samples.count], tagId: categoryID)
        }
        // One durable commit instead of rewriting the entire database 100 times.
        perform { try store.importRecords(records, replacing: false) }
        showSettings = false
        closeCategory()
    }
    #endif

    private var trainingText: String {
        switch trainingStep {
        case .spinSphere: "This is your BrainDump. Drag the tiles around to explore your thoughts."
        case .openTagView: "Tap any tile to view all tiles of that category."
        case .scrollTagView: "Scroll to look through all this category’s tiles."
        case .retagTile: "In the sidebar, use the category button to change the category. Change it now."
        case .completeTile: "Use the checkmark to complete a tile."
        case .addThoughtTile: "Use the Plus button to create a blank tile in this category."
        case .createFirstTile: keepsTrainingCapture ? "Create your first tile. Type a thought, then tap Done. This tile is yours to keep." : "Create a practice tile. Type a thought, then tap Done."
        case .swipeTags: "Swipe sideways to view all your categories."
        case .readThought: "Long press a tile to deep view it, then tap Done."
        case .returnHome: "Go to the home page using the Close button in the sidebar."
        case .finish: "Use the Plus button to quickly create many new tiles, then press the brain to categorise them later. Tap Finish Training to begin."
        }
    }
    private var trainingHighlight: TileActionButtons.HighlightedAction? {
        guard demo != nil else { return nil }
        switch trainingStep {
        case .retagTile: return .tag
        case .completeTile: return .complete
        case .addThoughtTile, .createFirstTile: return .add
        case .returnHome: return .close
        default: return nil
        }
    }
    private func startTraining() {
        guard demo == nil else { return }
        stopSpin(); showSettings = false
        cancelCategoryFlight()
        trainingReadPresented = false
        previousTrainingSelection = nil
        replayCategory = categoryID; replaySelection = selectedID
        keepsTrainingCapture = !trainingCompleted && store.activeThoughts.isEmpty && !ProcessInfo.processInfo.arguments.contains("--training-fixture")
        trainingCaptureID = nil
        let examples: [Int: [String]] = [
            0: ["An idea for a weekend adventure", "Start a small creative project", "A question to explore", "A thought for later", "Try something new", "Plan a surprise"],
            1: ["Paddington 2", "Spirited Away", "The Grand Budapest Hotel", "Arrival", "WALL-E", "The Martian"],
            2: ["The Hobbit", "Atomic Habits", "A Man Called Ove", "The Midnight Library", "Dune", "The Little Prince"],
            3: ["Water the plants", "Plan a walk", "Call a friend", "Organise the desk", "Book a haircut", "Try a new recipe"],
            4: ["https://www.nasa.gov", "https://www.bbc.co.uk", "https://www.wikipedia.org", "https://www.apple.com", "https://www.swift.org", "https://www.nationaltrust.org.uk"]
        ]
        demo = tagManager.tagsInDisplayOrder.flatMap { category in
            (examples[category.id] ?? (1...6).map { "An idea for \(category.name) \($0)" })
                .map { ThoughtRecord(text: $0, tagId: category.id) }
        }
        categoryID = nil; selectedID = nil; centeredID = nil; trainingStep = .spinSphere
    }
    private func finishTraining() {
        guard demo != nil, trainingStep == .finish else { return }
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
    var readOnly = false
    var save: (ThoughtRecord) -> Void
    var body: some View {
        NavigationStack {
            Group {
                if readOnly {
                    ScrollView { Text(thought.text).font(.body).frame(maxWidth: .infinity, alignment: .leading).padding() }
                } else {
                    TextEditor(text: $thought.text).font(.body).padding()
                }
            }
                .navigationTitle("Demo thought")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        if readOnly { Button("Done") { dismiss() } }
                        else { Button("Save") { save(thought); dismiss() }.disabled(thought.text.isEmpty) }
                    }
                }
        }
    }
}

#Preview {
    ContentView().environmentObject(CloudSyncService(store: .shared))
}
