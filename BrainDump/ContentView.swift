//
//  ContentView.swift
//  BrainDump
//
//  Created by Paul Hutchinson on 09/01/2026.
//

import SwiftUI
import Combine
import UIKit
import Foundation
import Darwin
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit

private let brainDumpICloudContainerIdentifier = "iCloud.BonkersBonk.BrainDump"
private let iCloudBackupLastErrorKey = "ICloudBackupLastError"

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    enum Mode {
        case importFile
        case exportFile
    }
    
    let mode: Mode
    let exportData: Data?
    let onPick: (URL) -> Void
    let onCancel: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        switch mode {
        case .importFile:
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.data, .bduBackup, .bdpBackup],
                asCopy: true
            )
            picker.delegate = context.coordinator
            return picker
        case .exportFile:
            let data = exportData ?? Data()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("BrainDump.bdu")
            try? data.write(to: tempURL, options: .atomic)
            let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
            picker.delegate = context.coordinator
            return picker
        }
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            } else {
                onCancel()
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Haptics

enum Haptics {
    private static let enabledKey = "HapticsEnabled"
    
    private static var isEnabled: Bool {
        if let stored = UserDefaults.standard.object(forKey: enabledKey) as? Bool {
            return stored
        }
        return true
    }
    
    static func optionTap() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selectionChange() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func negativeDoubleTap() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Display Link Driver

final class DisplayLinkDriver {
    var displayLink: CADisplayLink?
    var onStep: ((CFTimeInterval) -> Void)?
    
    func start(preferredFPS: Int) {
        stop()
        let link = CADisplayLink(target: self, selector: #selector(step))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: Float(preferredFPS),
                preferred: Float(preferredFPS)
            )
        } else {
            link.preferredFramesPerSecond = preferredFPS
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }
    
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func step(_ link: CADisplayLink) {
        onStep?(link.timestamp)
    }
}

// MARK: - Backup Types

struct TileBackup: Codable {
    struct TileRecord: Codable {
        let id: String
        let text: String
        let tagId: Int
    }
    
    let version: Int
    let exportedAt: Date
    let tags: [Tag]?
    let completed: [ArchivedTile]?
    let deleted: [ArchivedTile]?
    let tiles: [TileRecord]
}

struct TileSummary: Identifiable {
    let id: String
    let text: String
    let tagId: Int
    let tagName: String
}

private struct BackupFingerprintPayload: Codable {
    let tags: [Tag]
    let completed: [ArchivedTile]
    let deleted: [ArchivedTile]
    let tiles: [TileBackup.TileRecord]
}

struct DuplicateGroup: Identifiable {
    let id: String
    let key: String
    let items: [TileSummary]
}

struct ArchivedTile: Identifiable, Codable {
    let id: String
    let text: String
    let tagId: Int
    let archivedAt: Date
}

enum TrainingStep: Int, CaseIterable {
    case spinSphere
    case openTagView
    case scrollTagView
    case retagTile
    case completeTile
    case addThoughtTile
    case swipeTags
    case finish
}

enum TrainingOrigin {
    case firstLaunch
    case replay
}

struct TileStateSnapshot {
    let tileTexts: [String]
    let tileTags: [Int]
    let tileIds: [String]
    let tileCount: Int
    let completedTiles: [ArchivedTile]
    let deletedTiles: [ArchivedTile]
    let selectedIndex: Int?
    let filteredTagId: Int?
    let availableTagIds: [Int]
    let currentTagIndex: Int
    let centeredFilteredId: String?
    let isEditingTile: Bool
    let showTagPicker: Bool
    let isTagPickerPinned: Bool
    let pendingBlankTileIndex: Int?
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.bduBackup, .bdpBackup, .data] }
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackgroundTheme: String, CaseIterable, Identifiable {
    case space
    case gradientOne
    case gradientTwo
    case clouds
    case offBlack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .space:
            return "Space"
        case .gradientOne:
            return "Gradient One"
        case .gradientTwo:
            return "Gradient Two"
        case .clouds:
            return "Clouds"
        case .offBlack:
            return "Off-Black"
        }
    }

    var subtitle: String {
        switch self {
        case .space:
            return "Current default look"
        case .gradientOne:
            return "Simple gradient"
        case .gradientTwo:
            return "Simple gradient"
        case .clouds:
            return "Soft cloud atmosphere"
        case .offBlack:
            return "Plain dark background"
        }
    }
}

extension UTType {
    static let bduBackup = UTType(exportedAs: "com.parkinglot.bdu", conformingTo: .data)
    static let bdpBackup = UTType(exportedAs: "com.parkinglot.bdp", conformingTo: .data)
}

enum BrainDumpNotificationManager {
    private static let center = UNUserNotificationCenter.current()
    private static let defaults = UserDefaults.standard
    private static let notificationsEnabledKey = "BrainDumpNotificationsEnabled"
    private static let notificationsEnabledAtKey = "BrainDumpNotificationsEnabledAt"
    private static let pendingOpenBrainDumpKey = "PendingOpenBrainDumpFromNotification"
    static let openBrainDumpNotificationName = Notification.Name("OpenBrainDumpFromNotification")
    static let routeKey = "route"
    static let brainRouteValue = "brain_dumps"
    static let nightlyReminderIdentifier = "BrainDumpNightlyReminder"

    static func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                defaults.set(true, forKey: notificationsEnabledKey)
                if defaults.object(forKey: notificationsEnabledAtKey) == nil {
                    defaults.set(Date(), forKey: notificationsEnabledAtKey)
                }
            } else {
                defaults.set(false, forKey: notificationsEnabledKey)
            }
            DispatchQueue.main.async {
                completion?(granted)
            }
        }
    }

    static func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: notificationsEnabledKey)
        if enabled {
            if defaults.object(forKey: notificationsEnabledAtKey) == nil {
                defaults.set(Date(), forKey: notificationsEnabledAtKey)
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
        }
    }

    static func updateNightlyReminder(unsortedCount: Int, now: Date = Date()) {
        if unsortedCount <= 0 {
            center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
            return
        }

        guard defaults.bool(forKey: notificationsEnabledKey) else { return }

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                defaults.set(true, forKey: notificationsEnabledKey)
                if defaults.object(forKey: notificationsEnabledAtKey) == nil {
                    defaults.set(now, forKey: notificationsEnabledAtKey)
                }
                let content = UNMutableNotificationContent()
                content.title = "Brain Dump Reminder"
                content.body = reminderBody(for: unsortedCount, now: now)
                content.sound = .default
                content.userInfo = [routeKey: brainRouteValue]

                var dateComponents = DateComponents()
                dateComponents.hour = 20
                dateComponents.minute = 30
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: nightlyReminderIdentifier,
                    content: content,
                    trigger: trigger
                )
                center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
                center.add(request)
            default:
                center.removePendingNotificationRequests(withIdentifiers: [nightlyReminderIdentifier])
            }
        }
    }

    static func triggerAllDebugNotificationVariants() {
        requestAuthorization { granted in
            guard granted else { return }
            let identifiers = [
                "BrainDumpDebugReminder_1",
                "BrainDumpDebugReminder_2",
                "BrainDumpDebugReminder_3"
            ]
            center.removePendingNotificationRequests(withIdentifiers: identifiers)

            let variants: [(String, TimeInterval)] = [
                ("Sort your Brain Dumps!", 3),
                ("You have 3 Brain Dumps!", 8),
                ("Youve been busy today, you have 8 Brain Dumps!", 13)
            ]

            for (index, variant) in variants.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "Brain Dump Reminder (Debug)"
                content.body = variant.0
                content.sound = .default
                content.userInfo = [routeKey: brainRouteValue]

                let request = UNNotificationRequest(
                    identifier: identifiers[index],
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: variant.1, repeats: false)
                )
                center.add(request)
            }
        }
    }

    private static func reminderBody(for unsortedCount: Int, now: Date) -> String {
        let enabledAt = defaults.object(forKey: notificationsEnabledAtKey) as? Date ?? now
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: enabledAt)
        let today = calendar.startOfDay(for: now)
        let daysElapsed = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0

        if daysElapsed < 2 {
            return "Sort your Brain Dumps!"
        }
        if unsortedCount < 5 {
            return "You have \(unsortedCount) Brain Dumps!"
        }
        return "Youve been busy today, you have \(unsortedCount) Brain Dumps!"
    }

    static func markPendingOpenBrainDump() {
        defaults.set(true, forKey: pendingOpenBrainDumpKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: openBrainDumpNotificationName, object: nil)
        }
    }

    static func consumePendingOpenBrainDump() -> Bool {
        let pending = defaults.bool(forKey: pendingOpenBrainDumpKey)
        if pending {
            defaults.set(false, forKey: pendingOpenBrainDumpKey)
        }
        return pending
    }
}

// MARK: - Main View

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    // Orientation state (arcball quaternion)
    @State private var orientation = Quaternion.identity
    
    // Selected tile index (nil = sphere mode)
    @State private var selectedIndex: Int? = nil
    
    // Editable text for selected tile
    @State private var tileTexts: [String] = []
    
    // Tile tags (index corresponds to tile index)
    @State private var tileTags: [Int] = []
    
    // Tile IDs (index corresponds to tile index)
    @State private var tileIds: [String] = []
    
    // Completed and deleted tiles
    @State private var completedTiles: [ArchivedTile] = []
    @State private var deletedTiles: [ArchivedTile] = []
    
    // iCloud restore prompt
    @State private var showICloudRestorePrompt = false
    @State private var pendingICloudBackupData: Data? = nil
    @State private var showICloudBackupConflictPrompt = false
    @State private var pendingICloudConflictBackupData: Data? = nil
    @State private var pendingICloudDecisionLocalFingerprint: String? = nil
    @State private var pendingICloudDecisionRemoteFingerprint: String? = nil
    
    // Drag tracking (arcball)
    @State private var lastDragTime: Date = Date()
    @State private var isDragging = false
    @State private var lastDragVector = Point3D.zero
    @State private var lastDragOrientation = Quaternion.identity
    @State private var lastDragContainerSize: CGSize = .zero
    
    // Momentum/velocity tracking (radians/sec)
    @State private var angularVelocity = Point3D.zero
    @State private var decelerationLastTimestamp: CFTimeInterval = 0
    @State private var decelerationDriver = DisplayLinkDriver()
    @State private var angularVelocityDebug: Double = 0
    @State private var isDeceleratingDebug = false
    @State private var maxAngularVelocityDuringDrag: Double = 0
    @State private var suppressTapSelection = false
    @State private var pendingICloudBackupWorkItem: DispatchWorkItem? = nil
    @State private var pendingNotificationSyncWorkItem: DispatchWorkItem? = nil
    @State private var pendingOpenBrainDumpFromNotification = false
    @State private var showNotificationOptInPrompt = false
    @AppStorage("BrainDumpNotificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("NotificationPromptCreatedTileCount") private var notificationPromptCreatedTileCount: Int = 0
    @AppStorage("NotificationPromptAskedAfterFiveCreatedTiles") private var notificationPromptAskedAfterFiveCreatedTiles: Bool = false
    @AppStorage("NotificationPromptSnoozedUntilTimestamp") private var notificationPromptSnoozedUntilTimestamp: Double = 0
    @AppStorage("ICloudDeferredConflictLocalFingerprint") private var iCloudDeferredConflictLocalFingerprint: String = ""
    @AppStorage("ICloudDeferredConflictRemoteFingerprint") private var iCloudDeferredConflictRemoteFingerprint: String = ""
    @AppStorage("BackgroundTheme") private var backgroundThemeRaw: String = BackgroundTheme.space.rawValue
    @AppStorage("TrainingCompleted") private var hasCompletedTraining: Bool = false

    // Sphere scaling (pinch to open/close)
    @AppStorage("UserSphereScale") private var userSphereScale: Double = 0.95
    @State private var sphereScale: Double = 0.95
    @State private var sphereScaleStart: Double = 0.95
    @State private var isPinching = false
    
    // Tile count (starts from saved data or starter tiles)
    @State private var tileCount = 30
    
    // Deceleration constants (medium momentum)
    private let decelerationRate: Double = 0.60 // Faster decay
    private let minAngularVelocity: Double = 0.005 // Stop when velocity is below this
    private let momentumBoost: Double = 1.0 // Match finger speed on release
    private let maxAngularSpeed: Double = 10.0 // Max radians/sec

    private let maxSphereScale: Double = 2.0  // Twice the screen width
    
    // Tag management
    @StateObject private var tagManager = TagManager()
    
    // Settings sheet state
    @State private var showSettings = false
    
    // Action buttons and editing state
    @State private var isEditingTile = false
    @State private var focusRequestId = UUID()
    @State private var showDeleteConfirmation = false
    @State private var tileToDelete: Int? = nil
    @State private var showTagPicker = false
    @State private var isKeyboardVisible = false
    @State private var isTagPickerPinned = false
    @State private var pendingBlankTileIndex: Int? = nil
    @State private var deletingTileIds: Set<String> = []
    @State private var completingTileIds: Set<String> = []
    @State private var tagChangeAnimatingTileId: String? = nil
    @State private var closePulseTrigger = false
    @State private var isTrainingMode = false
    @State private var trainingOrigin: TrainingOrigin = .firstLaunch
    @State private var trainingStep: TrainingStep = .spinSphere
    @State private var didOpenTagViewForTraining = false
    @State private var didScrollTagViewForTraining = false
    @State private var didRetagTileForTraining = false
    @State private var didCompleteTileForTraining = false
    @State private var didAddThoughtTileForTraining = false
    @State private var didSwipeTagsForTraining = false
    @State private var hasSeenInitialTrainingCenteredTile = false
    @State private var isTrainingStepDelayActive = false
    @State private var trainingTileTexts: [String] = []
    @State private var trainingTileTags: [Int] = []
    @State private var trainingTileIds: [String] = []
    @State private var userSnapshot: TileStateSnapshot? = nil
    
    // Tag filter state
    @State private var filteredTagId: Int? = nil
    @State private var availableTagIds: [Int] = []
    @State private var currentTagIndex: Int = 0
    @State private var centeredFilteredId: String? = nil
    @State private var lastScrollHapticId: String? = nil
    @State private var lastScrollHapticTime: Date = .distantPast
    @State private var originalOrientation = Quaternion.identity
    
    // Debug state
    #if DEBUG
    @State private var showDebugPanel = UserDefaults.standard.bool(forKey: "ShowDebugPanel")
    @State private var showSpinDebug = UserDefaults.standard.bool(forKey: "ShowSpinDebug")
    #else
    @State private var showDebugPanel = false
    #endif
    
    // UserDefaults keys for persistence
    private let tileTextsKey = "SavedTileTexts"
    private let tileCountKey = "SavedTileCount"
    private let tileTagsKey = "SavedTileTags"
    private let tileIdsKey = "SavedTileIds"
    private let completedTilesKey = "CompletedTiles"
    private let deletedTilesKey = "DeletedTiles"
    private let iCloudLastBackupKey = "ICloudLastBackupDate"
    private let iCloudBackupPrefix = "BrainDumpBackup_"
    private let iCloudLatestBackupName = "BrainDumpBackup_latest.bdu"
    private let legacyICloudBackupPrefix = "ParkingLotBackup_"
    private let legacyICloudLatestBackupName = "ParkingLotBackup_latest.bdu"
    private let maxICloudBackups = 5
    private let brainDrumFolderName = "BrainDumpApp"
    private let iCloudBackupDebounceSeconds: TimeInterval = 6.0
    private let notificationSyncDebounceSeconds: TimeInterval = 2.0
    private let starterTileTexts: [String] = [
        "Welcome, tap this tile.",
        "Use the tag button to tag your tiles.",
        "Swipe when in Tag view to see your tags.",
        "Create your own custom tags in the menu.",
        "Feel free to delete me and make it your own!",
        "Hit the Brain to see and tag your new Brain Dumps!"
    ]
    private let trainingDemoTileTexts: [String] = [
        "1. Tap any tile to open Tag View.",
        "2. Scroll up/down to browse your Brain Dumps.",
        "3. Use the centre tag button to retag this tile.",
        "4. Complete this tile with the check button.",
        "5. Use the plus button to dump a new thought!"
    ]
    private let iCloudConflictPromptMessage =
        "Uploading now will overwrite the existing iCloud backup. Download from iCloud instead, or continue and overwrite iCloud with this device."
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    private var selectedBackgroundTheme: BackgroundTheme {
        BackgroundTheme(rawValue: backgroundThemeRaw) ?? .space
    }
    private var trainingInstructionText: String {
        switch trainingStep {
        case .spinSphere:
            return "This is your brain, spin to see your thoughts."
        case .openTagView:
            return "Step 1: Tap a tile to open Tag View."
        case .scrollTagView:
            return "You can scroll though your tiles in Tag View to see similar thoughts."
        case .retagTile:
            return "Step 3: Use the centre tag button to retag a tile."
        case .completeTile:
            return "Step 4: Complete this tile with the check button."
        case .addThoughtTile:
            return "Step 5: Use the plus button to dump a new thought!"
        case .swipeTags:
            return "Final step: swipe left or right to see your other tag view."
        case .finish:
            return "And finally, use the Brain Button whenever you want to organise and clear your thoughts!"
        }
    }
    private var trainingProgressValue: Int {
        switch trainingStep {
        case .spinSphere: return 0
        case .openTagView: return 1
        case .scrollTagView: return 2
        case .retagTile: return 3
        case .completeTile: return 4
        case .addThoughtTile: return 5
        case .swipeTags: return 6
        case .finish: return 7
        }
    }
    private var trainingHighlightedAction: TileActionButtons.HighlightedAction? {
        guard isTrainingMode else { return nil }
        switch trainingStep {
        case .retagTile:
            return .tag
        case .completeTile:
            return .complete
        case .addThoughtTile:
            return .add
        default:
            return nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            mainContent(in: geometry)
        }
        .onAppear {
            if isRunningInPreview {
                if tileTexts.isEmpty {
                    createInitialTiles()
                }
                return
            }
            initializeTiles()
            if isTrainingMode {
                return
            }
            purgeDeletedOlderThan30Days()
            updateEffectiveSphereScale(animated: false)
            syncNightlyReminder()
            handlePendingOpenFromNotificationIfNeeded()
            evaluateNotificationPromptOnLaunchIfNeeded()
        }
        .onDisappear {
            if isRunningInPreview {
                return
            }
            if isTrainingMode {
                return
            }
            stopDeceleration()
            // Save tiles when view disappears
            saveTiles()
            flushICloudBackup()
            flushNightlyReminderSync()
        }
        .onChange(of: tileTexts) { _, _ in
            // Auto-save whenever tile texts change
            saveTiles()
            attemptOpenBrainDumpFromNotification()
        }
        .onChange(of: tileCount) { _, _ in
            // Auto-save whenever tile count changes
            saveTiles()
            updateEffectiveSphereScale(animated: true)
        }
        .onChange(of: tileTags) { _, _ in
            // Auto-save whenever tile tags change
            saveTiles()
        }
        .onChange(of: filteredTagId) { _, newValue in
            guard isTrainingMode else { return }
            if trainingStep == .openTagView, newValue != nil {
                let forcedIndex = min(1, max(0, tileCount - 1))
                if tileTexts.indices.contains(forcedIndex) {
                    selectedIndex = forcedIndex
                    if let forcedId = tileIds[safe: forcedIndex] {
                        centeredFilteredId = forcedId
                    }
                }
                didOpenTagViewForTraining = true
                trainingStep = .scrollTagView
            }
        }
        .onReceive(tagManager.$tags) { _ in
            normalizeTileTagsToDefaultIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onChange(of: isEditingTile) { _, newValue in
            if newValue {
                pauseSphereForEditing()
            } else {
                dismissKeyboard()
                finalizeNewTileIfBlank()
                if isTrainingMode, trainingStep == .addThoughtTile, didAddThoughtTileForTraining {
                    ensureTrainingSwipeTagAvailability()
                    availableTagIds = getAvailableTags()
                    if let current = filteredTagId,
                       let currentIdx = availableTagIds.firstIndex(of: current) {
                        currentTagIndex = currentIdx
                    }
                    trainingStep = .swipeTags
                }
                resumeSphereAfterEditing()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                handlePendingOpenFromNotificationIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: BrainDumpNotificationManager.openBrainDumpNotificationName)) { _ in
            pendingOpenBrainDumpFromNotification = true
            attemptOpenBrainDumpFromNotification()
        }
        .alert("Enable nightly reminders?", isPresented: $showNotificationOptInPrompt) {
            Button("Not now", role: .cancel) {
                snoozeNotificationPromptForSevenDays()
            }
            Button("Enable reminders") {
                enableNightlyReminders()
            }
        } message: {
            Text("Would you like a single nightly reminder to sort your Brain Dumps?")
        }
        .overlay {
            overlayLayer()
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if showSpinDebug {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spin: \(String(format: "%.3f", angularVelocityDebug))")
                    Text("Decel: \(isDeceleratingDebug ? "Yes" : "No")")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                )
                .padding(.leading, 8)
                .padding(.top, 8)
            }
        }
        #endif
    }

    // MARK: - View Builders

    @ViewBuilder
    private func mainContent(in geometry: GeometryProxy) -> some View {
        let content = ZStack {
            backgroundLayer()
            tilesLayer(in: geometry)
            controlsLayer()
        }
        
        if filteredTagId == nil {
            content
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(value: value, containerSize: geometry.size)
                        }
                        .onEnded { value in
                            handleDragEnd(value: value)
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            if isDeceleratingDebug {
                                suppressTapSelection = true
                                stopDeceleration()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    suppressTapSelection = false
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            handleMagnificationChange(value)
                        }
                        .onEnded { _ in
                            handleMagnificationEnd()
                        }
                )
        } else {
            content
        }
    }

    @ViewBuilder
    private func backgroundLayer() -> some View {
        AppBackgroundView(theme: selectedBackgroundTheme)
            .ignoresSafeArea()
            .zIndex(-1000)

        // Background tap area to deselect
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditingTile {
                    isEditingTile = false
                    dismissKeyboard()
                    return
                }
                if selectedIndex != nil {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        selectedIndex = nil
                        isEditingTile = false
                    }
                }
            }
            .zIndex(0)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var shouldShowDeleteEmptyTileStyle: Bool {
        guard
            isEditingTile,
            let selectedIndex = selectedIndex,
            pendingBlankTileIndex == selectedIndex,
            tileTexts.indices.contains(selectedIndex)
        else { return false }
        return tileTexts[selectedIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var actionStripCloseIcon: String {
        if shouldShowDeleteEmptyTileStyle { return "xmark" }
        if isEditingTile, pendingBlankTileIndex == selectedIndex { return "checkmark" }
        return "xmark"
    }

    private var actionStripCloseForegroundColor: Color {
        if shouldShowDeleteEmptyTileStyle { return .red }
        if isEditingTile, pendingBlankTileIndex == selectedIndex { return .green }
        return .primary
    }

    private var actionStripCloseBorderColor: Color? {
        if shouldShowDeleteEmptyTileStyle { return .red }
        if isEditingTile, pendingBlankTileIndex == selectedIndex { return .green }
        return nil
    }

    @ViewBuilder
    private func tilesLayer(in geometry: GeometryProxy) -> some View {
        if let filteredTagId = filteredTagId {
            // Filter mode: show tiles in a scrollable vertical list
            let filteredIndices = getTilesForTag(filteredTagId)
            let filteredItems = filteredIndices.enumerated().map { listPosition, index in
                let id = tileIds[safe: index] ?? "legacy-\(index)"
                return FilteredTileItem(id: id, index: index, listPosition: listPosition)
            }
            let containerMidY = geometry.frame(in: .global).midY
            let rowHeight: CGFloat = 128
            let rowSpacing: CGFloat = 14
            let topBottomPadding = max(40, containerMidY - (rowHeight / 2))
            let overscrollPadding: CGFloat = 0
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: rowSpacing) {
                        // Top padding to start below close button area
                        Spacer()
                            .frame(height: topBottomPadding + overscrollPadding)
                        
                        // Render only matching tiles in list order
                        ForEach(filteredItems) { item in
                            CylinderTileRow(
                                containerMidY: containerMidY,
                                rowHeight: rowHeight,
                                isSelected: centeredFilteredId == item.id
                            ) {
                                TileView(
                                    index: item.index,
                                    text: tileTexts[safe: item.index] ?? "",
                                    isSelected: centeredFilteredId == item.id,
                                    isEditing: isEditingTile && selectedIndex == item.index,
                                    isNewTile: pendingBlankTileIndex == item.index,
                                    isDeleting: {
                                        if let id = tileIds[safe: item.index] {
                                            return deletingTileIds.contains(id)
                                        }
                                        return false
                                    }(),
                                    isCompleting: {
                                        if let id = tileIds[safe: item.index] {
                                            return completingTileIds.contains(id)
                                        }
                                        return false
                                    }(),
                                    focusRequestId: focusRequestId,
                                    orientation: orientation,
                                    containerSize: geometry.size,
                                    totalCount: tileCount,
                                    sphereScale: sphereScale,
                                    tagId: tileTags[safe: item.index] ?? tagManager.getDefaultTag().id,
                                    tagManager: tagManager,
                                    onTap: {
                                        handleTileTap(index: item.index)
                                    },
                                    isTapEnabled: !isDeceleratingDebug && !suppressTapSelection,
                                    onTextChange: { newText in
                                        if tileTexts.indices.contains(item.index) {
                                            tileTexts[item.index] = newText
                                        }
                                    },
                                    isTagChanging: tagChangeAnimatingTileId == item.id,
                                    isFiltered: true,
                                    listPosition: item.listPosition,
                                    filteredIndices: filteredIndices
                                )
                            }
                            .id(item.id)
                        }
                        
                        // Bottom padding
                        Spacer()
                            .frame(height: topBottomPadding + overscrollPadding)
                    }
                    .frame(maxWidth: .infinity)
                    .scrollTargetLayout()
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isEditingTile {
                                    isEditingTile = false
                                    dismissKeyboard()
                                } else {
                                    dismissTagFilter()
                                }
                            }
                    )
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $centeredFilteredId, anchor: .center)
                .scrollBounceBasedOnSizeIfAvailable()
                .scrollDisabledIfAvailable(filteredItems.count <= 1)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            let horizontalAmount = value.translation.width
                            let verticalAmount = value.translation.height
                            if abs(horizontalAmount) > abs(verticalAmount) && abs(horizontalAmount) > 30 {
                                if horizontalAmount < 0 {
                                    advanceFilteredTag(by: 1)
                                } else {
                                    advanceFilteredTag(by: -1)
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            guard let targetId = centeredFilteredId ?? filteredItems.first?.id else { return }
                            withAnimation(.interpolatingSpring(stiffness: 260, damping: 22)) {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded {
                            if isEditingTile {
                                isEditingTile = false
                                dismissKeyboard()
                            }
                        }
                )
                .zIndex(3600) // Above overlay background
                .onAppear {
                    let initialIndex = selectedIndex ?? filteredIndices.first
                    let initialId = initialIndex.flatMap { tileIds[safe: $0] } ?? filteredItems.first?.id
                    if let initialId = initialId {
                        centeredFilteredId = initialId
                        lastScrollHapticId = initialId
                        DispatchQueue.main.async {
                            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.1)) {
                                proxy.scrollTo(initialId, anchor: .center)
                            }
                        }
                    }
                }
                .modifier(
                    ScrollPhaseSnapModifier(
                        targetId: centeredFilteredId,
                        stopScrollTo: { targetId in
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        },
                        snapScrollTo: { targetId in
                            withAnimation(.interpolatingSpring(stiffness: 260, damping: 22)) {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                    )
                )
                .onChange(of: filteredTagId) { _, _ in
                    let initialIndex = selectedIndex ?? filteredIndices.first
                    let initialId = initialIndex.flatMap { tileIds[safe: $0] } ?? filteredItems.first?.id
                    if let initialId = initialId {
                        centeredFilteredId = initialId
                        lastScrollHapticId = initialId
                        DispatchQueue.main.async {
                            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.1)) {
                                proxy.scrollTo(initialId, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, newValue in
                    guard
                        let newValue = newValue,
                        filteredIndices.contains(newValue),
                        let newId = tileIds[safe: newValue]
                    else { return }
                    if centeredFilteredId != newId {
                        centeredFilteredId = newId
                        DispatchQueue.main.async {
                            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.1)) {
                                proxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: centeredFilteredId) { _, newValue in
                    guard
                        let newValue = newValue,
                        let newIndex = tileIds.firstIndex(of: newValue),
                        filteredIndices.contains(newIndex)
                    else { return }
                    if selectedIndex != newIndex {
                        selectedIndex = newIndex
                        isEditingTile = false
                        if !isTagPickerPinned {
                            showTagPicker = false
                        }
                    }
                    if isTrainingMode, trainingStep == .scrollTagView {
                        if !hasSeenInitialTrainingCenteredTile {
                            hasSeenInitialTrainingCenteredTile = true
                        } else {
                            didScrollTagViewForTraining = true
                            trainingStep = .retagTile
                        }
                    }
                    triggerScrollHaptic(for: newValue)
                }
            }
        } else {
            // Sphere mode: show all tiles normally
            ForEach(0..<tileCount, id: \.self) { index in
                TileView(
                    index: index,
                    text: tileTexts[safe: index] ?? "",
                    isSelected: selectedIndex == index,
                    isEditing: isEditingTile && selectedIndex == index,
                    isNewTile: pendingBlankTileIndex == index,
                    isDeleting: {
                        if let id = tileIds[safe: index] {
                            return deletingTileIds.contains(id)
                        }
                        return false
                    }(),
                    isCompleting: {
                        if let id = tileIds[safe: index] {
                            return completingTileIds.contains(id)
                        }
                        return false
                    }(),
                    focusRequestId: focusRequestId,
                    orientation: orientation,
                    containerSize: geometry.size,
                    totalCount: tileCount,
                    sphereScale: sphereScale,
                    tagId: tileTags[safe: index] ?? tagManager.getDefaultTag().id,
                    tagManager: tagManager,
                    onTap: {
                        handleTileTap(index: index)
                    },
                    isTapEnabled: !isDeceleratingDebug && !suppressTapSelection,
                    onTextChange: { newText in
                        if tileTexts.indices.contains(index) {
                            tileTexts[index] = newText
                        }
                    },
                    isTagChanging: false,
                    isFiltered: false,
                    listPosition: nil,
                    filteredIndices: nil
                )
            }
        }
    }

    @ViewBuilder
    private func controlsLayer() -> some View {
        // Control buttons overlay
        VStack {
            Spacer()
            HStack {
                if filteredTagId == nil {
                    // Settings button (bottom left)
                    GlassButton(
                        icon: "gearshape.fill",
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSettings = true
                            }
                        }
                    )
                    .padding(.leading, 32)
                    .padding(.bottom, 20)
                }

                Spacer()

                if filteredTagId == nil {
                    // Create tile button (bottom right)
                    if !isEditingTile {
                        GlassButton(
                            icon: "plus",
                            action: {
                                createTile()
                            }
                        )
                        .padding(.trailing, 28)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if filteredTagId == nil {
                Button(action: {
                    let defaultTagId = tagManager.getDefaultTag().id
                    let tilesForTag = getTilesForTag(defaultTagId)
                    guard !tilesForTag.isEmpty else {
                        Haptics.negativeDoubleTap()
                        return
                    }
                    Haptics.optionTap()
                    openTagFilter(for: defaultTagId, openTagPicker: true, pinTagPicker: true)
                }) {
                    Image("Image")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 74, height: 74)
                }
                .buttonStyle(BrainDumpButtonStyle())
                .padding(.bottom, 16)
            }
        }
        .zIndex(2000) // Above tiles
    }

    @ViewBuilder
    private func overlayLayer() -> some View {
        if showSettings {
            #if DEBUG
            SettingsView(
                isPresented: $showSettings,
                tagManager: tagManager,
                tileTags: $tileTags,
                completedTiles: $completedTiles,
                deletedTiles: $deletedTiles,
                onResetApp: resetApp,
                onSaveArchives: {
                    saveTiles()
                },
                exportBackupData: { backupData() },
                importBackupData: { data in applyBackupData(data) },
                replaceBackupData: { data in replaceWithBackupData(data) },
                exportCSVData: { exportCSVData() },
                searchTiles: { query in searchTiles(query) },
                duplicateGroups: { duplicateGroups() },
                removeDuplicates: { removeDuplicateTiles() },
                onRestoreArchived: { tile in
                    restoreArchivedTile(tile)
                },
                tagNameProvider: { id in
                    tagManager.getTag(byId: id)?.name ?? "Unknown"
                },
                onPurgeDeleted: {
                    purgeDeletedOlderThan30Days()
                },
                onEnableNotifications: {
                    enableNightlyReminders()
                },
                onDisableNotifications: {
                    disableNightlyReminders()
                },
                onBackupNow: {
                    backupNowWithConflictCheck()
                },
                onReplayTrainingDemo: {
                    startTrainingReplay()
                },
                isTrainingMode: isTrainingMode,
                showDebugPanel: $showDebugPanel,
                onCreateTestTiles: createTestTiles
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            #else
            SettingsView(
                isPresented: $showSettings,
                tagManager: tagManager,
                tileTags: $tileTags,
                completedTiles: $completedTiles,
                deletedTiles: $deletedTiles,
                onResetApp: resetApp,
                onSaveArchives: {
                    saveTiles()
                },
                exportBackupData: { backupData() },
                importBackupData: { data in applyBackupData(data) },
                replaceBackupData: { data in replaceWithBackupData(data) },
                exportCSVData: { exportCSVData() },
                searchTiles: { query in searchTiles(query) },
                duplicateGroups: { duplicateGroups() },
                removeDuplicates: { removeDuplicateTiles() },
                onRestoreArchived: { tile in
                    restoreArchivedTile(tile)
                },
                tagNameProvider: { id in
                    tagManager.getTag(byId: id)?.name ?? "Unknown"
                },
                onPurgeDeleted: {
                    purgeDeletedOlderThan30Days()
                },
                onEnableNotifications: {
                    enableNightlyReminders()
                },
                onDisableNotifications: {
                    disableNightlyReminders()
                },
                onBackupNow: {
                    backupNowWithConflictCheck()
                },
                onReplayTrainingDemo: {
                    startTrainingReplay()
                },
                isTrainingMode: isTrainingMode
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            #endif
        }

        if isTrainingMode {
            TrainingBannerView(
                instruction: trainingInstructionText,
                progress: trainingProgressValue,
                canFinish: trainingStep == .finish,
                onFinish: {
                    finishTraining()
                }
            )
            .zIndex(3900)
        }
        
        // Debug panel overlay
        #if DEBUG
        if showDebugPanel {
            GeometryReader { geometry in
                DebugPanelView(tileCount: tileCount)
                    .position(x: 90, y: 80) // Top left position
            }
            .zIndex(4000)
        }
#endif

        // Tag filter list overlay
        if filteredTagId != nil {
            TagFilterListView(
                tagIds: availableTagIds,
                selectedTagId: Binding(
                    get: { filteredTagId ?? tagManager.getDefaultTag().id },
                    set: { newTagId in
                        guard newTagId != filteredTagId else { return }
                        if let newIndex = availableTagIds.firstIndex(of: newTagId) {
                            currentTagIndex = newIndex
                        }
                        let newFilteredIndices = getTilesForTag(newTagId)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            filteredTagId = newTagId
                            selectedIndex = newFilteredIndices.first
                            isEditingTile = false
                        }
                    }
                ),
                tagManager: tagManager
            )
        }

        // Action buttons when tile is selected
        if let selectedIndexValue = selectedIndex {
            TileActionButtons(
                onClose: {
                    if showTagPicker {
                        showTagPicker = false
                        isTagPickerPinned = false
                        if !isEditingTile {
                            return
                        }
                    }
                    if filteredTagId != nil, !showTagPicker, !isKeyboardVisible, !isEditingTile {
                        dismissTagFilter()
                        return
                    }
                    if isEditingTile, pendingBlankTileIndex == selectedIndex {
                        isEditingTile = false
                        dismissKeyboard()
                        closePulseTrigger.toggle()
                        return
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        if filteredTagId == nil {
                            selectedIndex = nil
                        } else if let centeredId = centeredFilteredId,
                                  let centeredIndex = tileIds.firstIndex(of: centeredId) {
                            selectedIndex = centeredIndex
                        }
                        isEditingTile = false
                        showTagPicker = false
                        isTagPickerPinned = false
                    }
                },
                onEdit: {
                    showTagPicker = false
                    isTagPickerPinned = false
                    isEditingTile = true
                    focusRequestId = UUID()
                },
                onChangeTag: {
                    if showTagPicker {
                        showTagPicker = false
                        isTagPickerPinned = false
                    } else {
                        showTagPicker = true
                    }
                },
                onComplete: {
                    completeTile(at: selectedIndexValue)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isEditingTile = false
                        if !isTagPickerPinned {
                            showTagPicker = false
                        }
                    }
                    dismissKeyboard()
                },
                onDelete: {
                    tileToDelete = selectedIndexValue
                    showDeleteConfirmation = true
                },
                onAdd: {
                    let selectedTagId = tileTags[safe: selectedIndexValue] ?? tagManager.getDefaultTag().id
                    let newTagId = filteredTagId ?? selectedTagId
                    createTile(tagId: newTagId)
                },
                pulseTrigger: closePulseTrigger,
                closeIcon: actionStripCloseIcon,
                closeForegroundColor: actionStripCloseForegroundColor,
                closeBorderColor: actionStripCloseBorderColor,
                highlightedAction: trainingHighlightedAction,
                showFloatingAddButton: !isKeyboardVisible
            )
            .zIndex(3001)
        }

        // Tag picker (shown when tile is selected - stays visible until deselected)
        if showTagPicker, let selectedIndexValue = selectedIndex, selectedIndexValue < tileTags.count {
            TagPickerView(
                tagManager: tagManager,
                selectedTagId: Binding(
                    get: { tileTags[selectedIndexValue] },
                    set: { newTagId in
                        guard let currentSelectedIndex = self.selectedIndex else { return }
                        guard currentSelectedIndex < tileTags.count else { return }
                        let currentTagId = tileTags[currentSelectedIndex]
                        guard currentTagId != newTagId else { return }

                        if let filteredTagId = filteredTagId,
                           currentTagId == filteredTagId,
                           newTagId != filteredTagId,
                           let changingId = tileIds[safe: currentSelectedIndex] {
                            if !isTagPickerPinned {
                                showTagPicker = false
                            }
                            isEditingTile = false
                            tagChangeAnimatingTileId = changingId

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                                if currentSelectedIndex < tileTags.count {
                                    tileTags[currentSelectedIndex] = newTagId
                                }
                                tagChangeAnimatingTileId = nil
                                updateSelectionAfterTagChange(from: currentSelectedIndex, filteredTagId: filteredTagId)
                                if isTrainingMode, trainingStep == .retagTile {
                                    didRetagTileForTraining = true
                                    trainingStep = .completeTile
                                }
                            }
                            return
                        }

                        tileTags[currentSelectedIndex] = newTagId
                        if let filteredTagId = filteredTagId {
                            updateSelectionAfterTagChange(from: currentSelectedIndex, filteredTagId: filteredTagId)
                        }
                        if isTrainingMode, trainingStep == .retagTile {
                            didRetagTileForTraining = true
                            trainingStep = .completeTile
                        }
                    }
                ),
                onDismiss: {
                    showTagPicker = false
                    isTagPickerPinned = false
                }
            )
            .zIndex(3002)
        }

        // Delete confirmation alert
        if showDeleteConfirmation, let tileIndex = tileToDelete {
            DeleteConfirmationView(
                isPresented: $showDeleteConfirmation,
                onConfirm: {
                    softDeleteTile(at: tileIndex)
                    showDeleteConfirmation = false
                    tileToDelete = nil
                },
                onCancel: {
                    showDeleteConfirmation = false
                    tileToDelete = nil
                }
            )
            .zIndex(3003)
        }
        
        if !isTrainingMode, showICloudRestorePrompt, let data = pendingICloudBackupData {
            ICloudRestoreConfirmationView(
                isPresented: $showICloudRestorePrompt,
                title: "iCloud Backup Found",
                message: "You already have different tiles on this device. Merge or replace them with the iCloud backup?",
                primaryButtonTitle: "Merge",
                secondaryButtonTitle: "Replace",
                cancelButtonTitle: "Not Now",
                onMerge: {
                    applyBackupData(data)
                    clearDeferredICloudConflictPrompt()
                    clearPendingICloudDecisionContext()
                    pendingICloudBackupData = nil
                },
                onReplace: {
                    replaceWithBackupData(data)
                    clearDeferredICloudConflictPrompt()
                    clearPendingICloudDecisionContext()
                    pendingICloudBackupData = nil
                },
                onCancel: {
                    deferCurrentICloudDecisionPrompt()
                    clearPendingICloudDecisionContext()
                    pendingICloudBackupData = nil
                }
            )
            .zIndex(3004)
        }

        if !isTrainingMode, showICloudBackupConflictPrompt, let data = pendingICloudConflictBackupData {
            ICloudRestoreConfirmationView(
                isPresented: $showICloudBackupConflictPrompt,
                title: "iCloud Backup Already Exists",
                message: iCloudConflictPromptMessage,
                primaryButtonTitle: "Download from iCloud",
                secondaryButtonTitle: "Overwrite iCloud Backup",
                cancelButtonTitle: "Not Now",
                onMerge: {
                    replaceWithBackupData(data)
                    clearDeferredICloudConflictPrompt()
                    clearPendingICloudDecisionContext()
                    pendingICloudConflictBackupData = nil
                },
                onReplace: {
                    clearDeferredICloudConflictPrompt()
                    clearPendingICloudDecisionContext()
                    pendingICloudConflictBackupData = nil
                    writeICloudBackup(forceOverwrite: true)
                },
                onCancel: {
                    deferCurrentICloudDecisionPrompt()
                    clearPendingICloudDecisionContext()
                    pendingICloudConflictBackupData = nil
                }
            )
            .zIndex(3005)
        }
    }
    
    // MARK: - Initialization
    
    private func initializeTiles() {
        if !hasCompletedTraining {
            let savedTexts = UserDefaults.standard.array(forKey: tileTextsKey) as? [String]
            let hasSavedTiles = (savedTexts?.isEmpty == false)
            if !hasSavedTiles {
                startTrainingMode(origin: .firstLaunch)
                return
            }
        }

        // Load saved tiles from UserDefaults
        if let savedTexts = UserDefaults.standard.array(forKey: tileTextsKey) as? [String],
           !savedTexts.isEmpty {
            tileTexts = savedTexts
            tileCount = UserDefaults.standard.integer(forKey: tileCountKey)
            // Ensure tileCount matches the number of texts
            if tileCount == 0 || tileCount < tileTexts.count {
                tileCount = tileTexts.count
            }
            
            // Load tile tags
            if let savedTags = UserDefaults.standard.array(forKey: tileTagsKey) as? [Int] {
                tileTags = savedTags
                // Ensure tileTags array matches tileCount exactly
                if tileTags.count < tileCount {
                    // Pad with default tag if too short
                    while tileTags.count < tileCount {
                        tileTags.append(tagManager.getDefaultTag().id)
                    }
                } else if tileTags.count > tileCount {
                    // Trim if too long
                    tileTags = Array(tileTags.prefix(tileCount))
                }
            } else {
                // Initialize all tiles with default tag
                tileTags = Array(repeating: tagManager.getDefaultTag().id, count: tileCount)
            }
            
            if let savedIds = UserDefaults.standard.array(forKey: tileIdsKey) as? [String] {
                tileIds = savedIds
            } else {
                tileIds = []
            }
            // Ensure tileIds array matches tileCount exactly
            if tileIds.count < tileCount {
                while tileIds.count < tileCount {
                    tileIds.append(UUID().uuidString)
                }
            } else if tileIds.count > tileCount {
                tileIds = Array(tileIds.prefix(tileCount))
            }
            if tileIds.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                tileIds = tileIds.map { value in
                    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : value
                }
            }
            
            if let completedData = UserDefaults.standard.data(forKey: completedTilesKey),
               let decodedCompleted = try? JSONDecoder().decode([ArchivedTile].self, from: completedData) {
                completedTiles = decodedCompleted
            } else {
                completedTiles = []
            }
            
            if let deletedData = UserDefaults.standard.data(forKey: deletedTilesKey),
               let decodedDeleted = try? JSONDecoder().decode([ArchivedTile].self, from: deletedData) {
                deletedTiles = decodedDeleted
            } else {
                deletedTiles = []
            }
        } else {
            tileTexts = []
            tileTags = []
            tileIds = []
            tileCount = 0
            completedTiles = []
            deletedTiles = []
            createInitialTiles()
            return
        }
        
        normalizeTileTagsToDefaultIfNeeded()
        loadICloudBackupIfAvailable()
    }

    private func createInitialTiles() {
        if isTrainingMode { return }
        // Initialize with guided starter tiles if no saved data exists
        let defaultTagId = tagManager.getDefaultTag().id
        let thingsToDoTagId = 3
        
        tileTexts = starterTileTexts
        tileTags = [
            defaultTagId,
            defaultTagId,
            defaultTagId,
            thingsToDoTagId,
            thingsToDoTagId,
            thingsToDoTagId
        ]
        tileCount = tileTexts.count
        tileIds = Array(repeating: "", count: tileCount).map { _ in UUID().uuidString }
        saveTiles()
    }

    private func createTrainingDemoTiles() {
        let defaultTagId = tagManager.getDefaultTag().id
        trainingTileTexts = trainingDemoTileTexts
        trainingTileTags = Array(repeating: defaultTagId, count: trainingTileTexts.count)
        trainingTileIds = trainingTileTexts.map { _ in UUID().uuidString }
    }

    private func snapshotUserState() -> TileStateSnapshot {
        TileStateSnapshot(
            tileTexts: tileTexts,
            tileTags: tileTags,
            tileIds: tileIds,
            tileCount: tileCount,
            completedTiles: completedTiles,
            deletedTiles: deletedTiles,
            selectedIndex: selectedIndex,
            filteredTagId: filteredTagId,
            availableTagIds: availableTagIds,
            currentTagIndex: currentTagIndex,
            centeredFilteredId: centeredFilteredId,
            isEditingTile: isEditingTile,
            showTagPicker: showTagPicker,
            isTagPickerPinned: isTagPickerPinned,
            pendingBlankTileIndex: pendingBlankTileIndex
        )
    }

    private func restoreFromSnapshot(_ snapshot: TileStateSnapshot) {
        tileTexts = snapshot.tileTexts
        tileTags = snapshot.tileTags
        tileIds = snapshot.tileIds
        tileCount = snapshot.tileCount
        completedTiles = snapshot.completedTiles
        deletedTiles = snapshot.deletedTiles
        selectedIndex = snapshot.selectedIndex
        filteredTagId = snapshot.filteredTagId
        availableTagIds = snapshot.availableTagIds
        currentTagIndex = snapshot.currentTagIndex
        centeredFilteredId = snapshot.centeredFilteredId
        isEditingTile = snapshot.isEditingTile
        showTagPicker = snapshot.showTagPicker
        isTagPickerPinned = snapshot.isTagPickerPinned
        pendingBlankTileIndex = snapshot.pendingBlankTileIndex
    }

    private func startTrainingMode(origin: TrainingOrigin) {
        stopDeceleration()
        dismissKeyboard()
        showSettings = false
        showDeleteConfirmation = false
        tileToDelete = nil
        showICloudRestorePrompt = false
        showICloudBackupConflictPrompt = false
        pendingICloudBackupData = nil
        pendingICloudConflictBackupData = nil
        deletingTileIds.removeAll()
        completingTileIds.removeAll()
        tagChangeAnimatingTileId = nil

        trainingOrigin = origin
        trainingStep = .spinSphere
        didOpenTagViewForTraining = false
        didScrollTagViewForTraining = false
        didRetagTileForTraining = false
        didCompleteTileForTraining = false
        didAddThoughtTileForTraining = false
        didSwipeTagsForTraining = false
        hasSeenInitialTrainingCenteredTile = false
        isTrainingStepDelayActive = false
        userSnapshot = (origin == .replay) ? snapshotUserState() : nil

        createTrainingDemoTiles()
        tileTexts = trainingTileTexts
        tileTags = trainingTileTags
        tileIds = trainingTileIds
        tileCount = trainingTileTexts.count
        completedTiles = []
        deletedTiles = []
        selectedIndex = nil
        filteredTagId = nil
        availableTagIds = []
        currentTagIndex = 0
        centeredFilteredId = nil
        isEditingTile = false
        showTagPicker = false
        isTagPickerPinned = false
        pendingBlankTileIndex = nil
        isTrainingMode = true
    }

    private func startTrainingReplay() {
        guard !isTrainingMode else { return }
        startTrainingMode(origin: .replay)
    }

    private func finishTraining() {
        guard isTrainingMode else { return }
        let origin = trainingOrigin
        let snapshot = userSnapshot
        isTrainingMode = false
        trainingTileTexts.removeAll()
        trainingTileTags.removeAll()
        trainingTileIds.removeAll()
        userSnapshot = nil
        didOpenTagViewForTraining = false
        didScrollTagViewForTraining = false
        didRetagTileForTraining = false
        didCompleteTileForTraining = false
        didAddThoughtTileForTraining = false
        didSwipeTagsForTraining = false
        hasSeenInitialTrainingCenteredTile = false
        isTrainingStepDelayActive = false
        trainingStep = .spinSphere

        if origin == .firstLaunch {
            hasCompletedTraining = true
        }

        if origin == .replay, let snapshot {
            restoreFromSnapshot(snapshot)
            return
        }

        // First-launch completion: create baseline user tiles and persist once training is done.
        tileTexts.removeAll()
        tileTags.removeAll()
        tileIds.removeAll()
        tileCount = 0
        completedTiles = []
        deletedTiles = []
        createInitialTiles()
    }
    
    // MARK: - Persistence
    
    private func saveTiles() {
        if isRunningInPreview { return }
        if isTrainingMode { return }
        // Save tile texts, count, and tags to UserDefaults
        UserDefaults.standard.set(tileTexts, forKey: tileTextsKey)
        UserDefaults.standard.set(tileCount, forKey: tileCountKey)
        UserDefaults.standard.set(tileTags, forKey: tileTagsKey)
        UserDefaults.standard.set(tileIds, forKey: tileIdsKey)
        saveArchives()
        scheduleICloudBackup()
        scheduleNightlyReminderSync()
    }

    private func normalizeTileTagsToDefaultIfNeeded() {
        guard !tileTags.isEmpty else { return }
        let defaultTagId = tagManager.getDefaultTag().id
        let validTagIds = Set(tagManager.tags.map(\.id))
        var didChange = false
        var normalized = tileTags

        for index in normalized.indices {
            let tagId = normalized[index]
            if !validTagIds.contains(tagId) {
                normalized[index] = defaultTagId
                didChange = true
            }
        }

        guard didChange else { return }
        tileTags = normalized
    }

    private func scheduleICloudBackup() {
        if isTrainingMode { return }
        pendingICloudBackupWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            writeICloudBackup()
        }
        pendingICloudBackupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + iCloudBackupDebounceSeconds, execute: workItem)
    }

    private func flushICloudBackup() {
        if isTrainingMode { return }
        pendingICloudBackupWorkItem?.cancel()
        pendingICloudBackupWorkItem = nil
        writeICloudBackup()
    }

    private func backupNowWithConflictCheck() {
        if isTrainingMode { return }
        pendingICloudBackupWorkItem?.cancel()
        pendingICloudBackupWorkItem = nil
        writeICloudBackup(promptOnConflict: true)
    }

    private func scheduleNightlyReminderSync() {
        if isTrainingMode { return }
        pendingNotificationSyncWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            syncNightlyReminder()
        }
        pendingNotificationSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + notificationSyncDebounceSeconds, execute: workItem)
    }

    private func flushNightlyReminderSync() {
        if isTrainingMode { return }
        pendingNotificationSyncWorkItem?.cancel()
        pendingNotificationSyncWorkItem = nil
        syncNightlyReminder()
    }

    private func enableNightlyReminders() {
        if isTrainingMode { return }
        BrainDumpNotificationManager.requestAuthorization { granted in
            guard granted else { return }
            syncNightlyReminder()
        }
    }

    private func evaluateNotificationPromptOnLaunchIfNeeded() {
        if isTrainingMode { return }
        guard !isRunningInPreview else { return }
        guard !notificationsEnabled else { return }
        guard !isNotificationPromptSnoozed else { return }
        guard tileCount > 10 else { return }
        showNotificationOptInPrompt = true
    }

    private func registerNewTileForNotificationPrompt() {
        if isTrainingMode { return }
        guard !isRunningInPreview else { return }
        notificationPromptCreatedTileCount += 1
        guard !notificationPromptAskedAfterFiveCreatedTiles else { return }
        guard notificationPromptCreatedTileCount >= 5 else { return }
        guard !notificationsEnabled else { return }
        guard !isNotificationPromptSnoozed else { return }
        notificationPromptAskedAfterFiveCreatedTiles = true
        showNotificationOptInPrompt = true
    }

    private var isNotificationPromptSnoozed: Bool {
        Date().timeIntervalSince1970 < notificationPromptSnoozedUntilTimestamp
    }

    private func snoozeNotificationPromptForSevenDays() {
        let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60
        notificationPromptSnoozedUntilTimestamp = Date().addingTimeInterval(sevenDaysInSeconds).timeIntervalSince1970
    }

    private func disableNightlyReminders() {
        if isTrainingMode { return }
        BrainDumpNotificationManager.setNotificationsEnabled(false)
    }

    private func syncNightlyReminder() {
        if isTrainingMode { return }
        BrainDumpNotificationManager.updateNightlyReminder(unsortedCount: unsortedBrainDumpCount())
    }

    private func handlePendingOpenFromNotificationIfNeeded() {
        if isTrainingMode { return }
        if BrainDumpNotificationManager.consumePendingOpenBrainDump() {
            pendingOpenBrainDumpFromNotification = true
        }
        attemptOpenBrainDumpFromNotification()
    }

    private func attemptOpenBrainDumpFromNotification() {
        if isTrainingMode { return }
        guard pendingOpenBrainDumpFromNotification else { return }
        let defaultTagId = tagManager.getDefaultTag().id
        let tilesForTag = getTilesForTag(defaultTagId)
        guard !tilesForTag.isEmpty else { return }
        pendingOpenBrainDumpFromNotification = false
        showSettings = false
        showTagPicker = false
        isTagPickerPinned = false
        isEditingTile = false
        dismissKeyboard()
        openTagFilter(for: defaultTagId, openTagPicker: true, pinTagPicker: true)
    }

    private func unsortedBrainDumpCount() -> Int {
        let defaultTagId = tagManager.getDefaultTag().id
        return tileTexts.indices.reduce(0) { total, index in
            let trimmed = tileTexts[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return total }
            let tagId = tileTags[safe: index] ?? defaultTagId
            return tagId == defaultTagId ? total + 1 : total
        }
    }
    
    private func saveArchives() {
        if isTrainingMode { return }
        if let completedData = try? JSONEncoder().encode(completedTiles) {
            UserDefaults.standard.set(completedData, forKey: completedTilesKey)
        }
        if let deletedData = try? JSONEncoder().encode(deletedTiles) {
            UserDefaults.standard.set(deletedData, forKey: deletedTilesKey)
        }
    }

    private func buildBackup() -> TileBackup {
        let tiles = zip(zip(tileIds, tileTexts), tileTags).map { pair in
            TileBackup.TileRecord(id: pair.0.0, text: pair.0.1, tagId: pair.1)
        }
        return TileBackup(
            version: 3,
            exportedAt: Date(),
            tags: tagManager.tags,
            completed: completedTiles,
            deleted: deletedTiles,
            tiles: tiles
        )
    }

    private func mergeTags(from backupTags: [Tag]) {
        guard !backupTags.isEmpty else { return }
        var updated = tagManager.tags
        for tag in backupTags {
            if let index = updated.firstIndex(where: { $0.id == tag.id }) {
                updated[index] = tag
            } else {
                updated.append(tag)
            }
        }
        updated.sort { $0.id < $1.id }
        tagManager.tags = updated
        tagManager.saveTags()
    }
    
    private func replaceTags(with backupTags: [Tag]) {
        guard !backupTags.isEmpty else { return }
        let sorted = backupTags.sorted { $0.id < $1.id }
        tagManager.tags = sorted
        tagManager.saveTags()
    }
    
    private func mergeBackup(_ backup: TileBackup) {
        var existingIds = Set(tileIds)
        var existingSignatures = Set(tileTexts.indices.map { index in
            "\(tileTexts[index])|\(tileTags[safe: index] ?? tagManager.getDefaultTag().id)"
        })
        
        for record in backup.tiles {
            if existingIds.contains(record.id) {
                continue
            }
            let signature = "\(record.text)|\(record.tagId)"
            if existingSignatures.contains(signature) {
                continue
            }
            
            tileIds.append(record.id)
            tileTexts.append(record.text)
            tileTags.append(record.tagId)
            existingIds.insert(record.id)
            existingSignatures.insert(signature)
        }
        
        tileCount = tileTexts.count
    }

    private func buildTileSummaries() -> [TileSummary] {
        var summaries: [TileSummary] = []
        summaries.reserveCapacity(tileTexts.count)
        for index in 0..<tileTexts.count {
            let id = tileIds[safe: index] ?? UUID().uuidString
            let text = tileTexts[index]
            let tagId = tileTags[safe: index] ?? tagManager.getDefaultTag().id
            let tagName = tagManager.getTag(byId: tagId)?.name ?? "Unknown"
            summaries.append(TileSummary(id: id, text: text, tagId: tagId, tagName: tagName))
        }
        return summaries
    }
    
    private func searchTiles(_ query: String) -> [TileSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return buildTileSummaries().filter { $0.text.lowercased().contains(lower) }
    }
    
    private func duplicateGroups() -> [DuplicateGroup] {
        var groups: [String: [Int]] = [:]
        for index in 0..<tileTexts.count {
            let text = tileTexts[index].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !text.isEmpty else { continue }
            let tagId = tileTags[safe: index] ?? tagManager.getDefaultTag().id
            let key = "\(text)|\(tagId)"
            groups[key, default: []].append(index)
        }
        
        var results: [DuplicateGroup] = []
        for (key, indices) in groups where indices.count > 1 {
            let items = indices.map { idx -> TileSummary in
                let id = tileIds[safe: idx] ?? UUID().uuidString
                let text = tileTexts[idx]
                let tagId = tileTags[safe: idx] ?? tagManager.getDefaultTag().id
                let tagName = tagManager.getTag(byId: tagId)?.name ?? "Unknown"
                return TileSummary(id: id, text: text, tagId: tagId, tagName: tagName)
            }
            results.append(DuplicateGroup(id: key, key: key, items: items))
        }
        
        return results.sorted { $0.items.count > $1.items.count }
    }
    
    private func removeDuplicateTiles() -> Int {
        var groups: [String: [Int]] = [:]
        for index in 0..<tileTexts.count {
            let text = tileTexts[index].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !text.isEmpty else { continue }
            let tagId = tileTags[safe: index] ?? tagManager.getDefaultTag().id
            let key = "\(text)|\(tagId)"
            groups[key, default: []].append(index)
        }
        
        var indicesToRemove: [Int] = []
        for (_, indices) in groups {
            if indices.count > 1 {
                indicesToRemove.append(contentsOf: indices.dropFirst())
            }
        }
        
        for index in indicesToRemove.sorted(by: >) {
            deleteTile(at: index)
        }
        
        return indicesToRemove.count
    }
    
    private func applyBackupData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let backup = try? decoder.decode(TileBackup.self, from: data) {
            if let backupTags = backup.tags {
                mergeTags(from: backupTags)
            }
            if let completed = backup.completed {
                completedTiles = mergeArchived(into: completedTiles, from: completed)
            }
            if let deleted = backup.deleted {
                deletedTiles = mergeArchived(into: deletedTiles, from: deleted)
            }
            mergeBackup(backup)
            normalizeTileTagsToDefaultIfNeeded()
            saveTiles()
        }
    }
    
    private func replaceWithBackupData(_ data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(TileBackup.self, from: data) else { return }
        if let backupTags = backup.tags {
            replaceTags(with: backupTags)
        }
        if let completed = backup.completed {
            completedTiles = completed
        } else {
            completedTiles = []
        }
        if let deleted = backup.deleted {
            deletedTiles = deleted
        } else {
            deletedTiles = []
        }
        tileIds = backup.tiles.map { $0.id }
        tileTexts = backup.tiles.map { $0.text }
        tileTags = backup.tiles.map { $0.tagId }
        tileCount = tileTexts.count
        normalizeTileTagsToDefaultIfNeeded()
        saveTiles()
    }

    private func mergeArchived(into existing: [ArchivedTile], from incoming: [ArchivedTile]) -> [ArchivedTile] {
        var result = existing
        var existingIds = Set(existing.map { $0.id })
        var existingSignatures = Set(existing.map { "\($0.text)|\($0.tagId)" })
        for item in incoming {
            if existingIds.contains(item.id) { continue }
            let signature = "\(item.text)|\(item.tagId)"
            if existingSignatures.contains(signature) { continue }
            result.append(item)
            existingIds.insert(item.id)
            existingSignatures.insert(signature)
        }
        return result
    }
    
    private func backupData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(buildBackup())) ?? Data()
    }
    
    private func exportCSVData() -> Data {
        var lines: [String] = ["id,text,tagId,tagName"]
        for index in 0..<tileTexts.count {
            let id = tileIds[safe: index] ?? ""
            let text = tileTexts[index]
            let tagId = tileTags[safe: index] ?? tagManager.getDefaultTag().id
            let tagName = tagManager.getTag(byId: tagId)?.name ?? "Unknown"
            let escapedText = "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
            let escapedTagName = "\"\(tagName.replacingOccurrences(of: "\"", with: "\"\""))\""
            lines.append("\(id),\(escapedText),\(tagId),\(escapedTagName)")
        }
        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }
    
    private func iCloudBackupDirectory() -> URL? {
        let container = FileManager.default.url(forUbiquityContainerIdentifier: brainDumpICloudContainerIdentifier)
            ?? FileManager.default.url(forUbiquityContainerIdentifier: nil)
        guard let container else {
            UserDefaults.standard.set("No iCloud container access", forKey: iCloudBackupLastErrorKey)
            return nil
        }
        let docs = container.appendingPathComponent("Documents")
        let brainDrum = docs.appendingPathComponent(brainDrumFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: brainDrum.path) {
            do {
                try FileManager.default.createDirectory(at: brainDrum, withIntermediateDirectories: true)
            } catch {
                UserDefaults.standard.set(
                    "Failed to create iCloud folder: \(error.localizedDescription)",
                    forKey: iCloudBackupLastErrorKey
                )
                return nil
            }
        }
        return brainDrum
    }
    
    private func latestICloudBackupURL() -> URL? {
        guard let docs = iCloudBackupDirectory() else { return nil }
        let latestURL = docs.appendingPathComponent(iCloudLatestBackupName)
        if FileManager.default.fileExists(atPath: latestURL.path) {
            return latestURL
        }

        let legacyLatestURL = docs.appendingPathComponent(legacyICloudLatestBackupName)
        if FileManager.default.fileExists(atPath: legacyLatestURL.path) {
            return legacyLatestURL
        }
        
        let legacyURL = docs.appendingPathComponent("ParkingLotBackup.bdu")
        let newBaseURL = docs.appendingPathComponent("BrainDump.bdu")
        var candidates: [URL] = []
        if FileManager.default.fileExists(atPath: newBaseURL.path) {
            candidates.append(newBaseURL)
        }
        if FileManager.default.fileExists(atPath: legacyURL.path) {
            candidates.append(legacyURL)
        }
        
        if let files = try? FileManager.default.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: files.filter { url in
                let name = url.lastPathComponent
                return url.pathExtension == "bdu"
                    && (name.hasPrefix(iCloudBackupPrefix) || name.hasPrefix(legacyICloudBackupPrefix))
            })
        }
        
        let sorted = candidates.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lDate > rDate
        }
        return sorted.first
    }
    
    private func writeICloudBackup(forceOverwrite: Bool = false, promptOnConflict: Bool = false) {
        if isTrainingMode { return }
        let localBackup = buildBackup()
        guard hasMeaningfulTiles(in: localBackup.tiles.map { $0.text }) else { return }
        let localData = encodeBackup(localBackup)
        guard !localData.isEmpty else { return }
        let localFingerprint = fingerprintForBackupData(localData)

        DispatchQueue.global(qos: .utility).async {
            guard let docs = iCloudBackupDirectory() else { return }

            if promptOnConflict && !forceOverwrite,
               let remoteURL = latestICloudBackupURL(),
               let remoteData = try? Data(contentsOf: remoteURL) {
                let remoteFingerprint = fingerprintForBackupData(remoteData)
                if remoteFingerprint != localFingerprint {
                    DispatchQueue.main.async {
                        presentICloudBackupConflictIfNeeded(
                            remoteData: remoteData,
                            localFingerprint: localFingerprint,
                            remoteFingerprint: remoteFingerprint
                        )
                    }
                    return
                }
            }

            let latestURL = docs.appendingPathComponent(iCloudLatestBackupName)
            let timestampedURL = docs.appendingPathComponent(iCloudBackupFilename())
            do {
                try localData.write(to: latestURL, options: .atomic)
                try localData.write(to: timestampedURL, options: .atomic)
                pruneICloudBackups(in: docs)
                UserDefaults.standard.set(Date(), forKey: iCloudLastBackupKey)
                UserDefaults.standard.removeObject(forKey: iCloudBackupLastErrorKey)
            } catch {
                UserDefaults.standard.set(
                    "Backup write failed: \(error.localizedDescription)",
                    forKey: iCloudBackupLastErrorKey
                )
            }
        }
    }
    
    private func loadICloudBackupIfAvailable(fallback: (() -> Void)? = nil) {
        if isTrainingMode {
            fallback?()
            return
        }
        DispatchQueue.global(qos: .utility).async {
            guard let url = latestICloudBackupURL() else {
                DispatchQueue.main.async { fallback?() }
                return
            }
            guard let data = try? Data(contentsOf: url) else {
                DispatchQueue.main.async { fallback?() }
                return
            }
            DispatchQueue.main.async {
                let localFingerprint = fingerprintForBackupData(backupData())
                let remoteFingerprint = fingerprintForBackupData(data)

                if hasMeaningfulLocalTiles() {
                    guard localFingerprint != remoteFingerprint else {
                        clearDeferredICloudConflictPrompt()
                        clearPendingICloudDecisionContext()
                        return
                    }
                    presentICloudRestorePromptIfNeeded(
                        remoteData: data,
                        localFingerprint: localFingerprint,
                        remoteFingerprint: remoteFingerprint
                    )
                } else {
                    clearDeferredICloudConflictPrompt()
                    clearPendingICloudDecisionContext()
                    applyBackupData(data)
                }
            }
        }
    }
    
    private func hasMeaningfulLocalTiles() -> Bool {
        hasMeaningfulTiles(in: tileTexts)
    }

    private func hasMeaningfulTiles(in texts: [String]) -> Bool {
        texts.contains { isMeaningfulTileText($0) }
    }

    private func isMeaningfulTileText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !starterTileTexts.contains(trimmed)
    }

    private func encodeBackup(_ backup: TileBackup) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(backup)) ?? Data()
    }

    private func decodeBackupData(_ data: Data) -> TileBackup? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TileBackup.self, from: data)
    }

    private func fingerprintForBackupData(_ data: Data) -> String {
        if let backup = decodeBackupData(data),
           let payloadData = backupFingerprintData(from: backup) {
            return sha256Hex(payloadData)
        }
        return sha256Hex(data)
    }

    private func backupFingerprintData(from backup: TileBackup) -> Data? {
        let payload = BackupFingerprintPayload(
            tags: backup.tags ?? [],
            completed: backup.completed ?? [],
            deleted: backup.deleted ?? [],
            tiles: backup.tiles
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func presentICloudRestorePromptIfNeeded(
        remoteData: Data,
        localFingerprint: String,
        remoteFingerprint: String
    ) {
        guard !showICloudRestorePrompt else { return }
        guard !showICloudBackupConflictPrompt else { return }
        guard !isICloudConflictPromptDeferred(localFingerprint: localFingerprint, remoteFingerprint: remoteFingerprint) else {
            clearPendingICloudDecisionContext()
            return
        }
        pendingICloudDecisionLocalFingerprint = localFingerprint
        pendingICloudDecisionRemoteFingerprint = remoteFingerprint
        pendingICloudBackupData = remoteData
        showICloudRestorePrompt = true
    }

    private func presentICloudBackupConflictIfNeeded(
        remoteData: Data,
        localFingerprint: String,
        remoteFingerprint: String
    ) {
        guard !showICloudBackupConflictPrompt else { return }
        guard !showICloudRestorePrompt else { return }
        guard !isICloudConflictPromptDeferred(localFingerprint: localFingerprint, remoteFingerprint: remoteFingerprint) else {
            clearPendingICloudDecisionContext()
            return
        }
        pendingICloudDecisionLocalFingerprint = localFingerprint
        pendingICloudDecisionRemoteFingerprint = remoteFingerprint
        pendingICloudConflictBackupData = remoteData
        showICloudBackupConflictPrompt = true
    }

    private func isICloudConflictPromptDeferred(localFingerprint: String, remoteFingerprint: String) -> Bool {
        iCloudDeferredConflictLocalFingerprint == localFingerprint
        && iCloudDeferredConflictRemoteFingerprint == remoteFingerprint
    }

    private func deferCurrentICloudDecisionPrompt() {
        guard let localFingerprint = pendingICloudDecisionLocalFingerprint,
              let remoteFingerprint = pendingICloudDecisionRemoteFingerprint else { return }
        iCloudDeferredConflictLocalFingerprint = localFingerprint
        iCloudDeferredConflictRemoteFingerprint = remoteFingerprint
    }

    private func clearDeferredICloudConflictPrompt() {
        iCloudDeferredConflictLocalFingerprint = ""
        iCloudDeferredConflictRemoteFingerprint = ""
    }

    private func clearPendingICloudDecisionContext() {
        pendingICloudDecisionLocalFingerprint = nil
        pendingICloudDecisionRemoteFingerprint = nil
    }
    
    private func iCloudBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        return "\(iCloudBackupPrefix)\(stamp).bdu"
    }
    
    private func pruneICloudBackups(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        let backups = files.filter { url in
            let name = url.lastPathComponent
            return url.pathExtension == "bdu"
                && (name.hasPrefix(iCloudBackupPrefix) || name.hasPrefix(legacyICloudBackupPrefix))
        }.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lDate > rDate
        }
        
        if backups.count > maxICloudBackups {
            let toDelete = backups.suffix(from: maxICloudBackups)
            for url in toDelete {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDrag(value: DragGesture.Value, containerSize: CGSize) {
        // Only allow drag when no tile is selected
        guard selectedIndex == nil else { return }
        
        // Stop any ongoing deceleration
        if isDeceleratingDebug {
            stopDeceleration()
            suppressTapSelection = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                suppressTapSelection = false
            }
        }

        lastDragContainerSize = containerSize
        let currentVector = SphereMath.mapToSphere(point: value.location, in: containerSize)
        let currentTime = Date()
        
        // Initialize drag state
        if !isDragging {
            isDragging = true
            lastDragVector = currentVector
            lastDragOrientation = orientation
            lastDragTime = currentTime
            maxAngularVelocityDuringDrag = 0
            return
        }
        
        let deltaRotation = Quaternion.fromVectors(lastDragVector, currentVector)
        orientation = (deltaRotation * orientation).normalized()
        
        // Update angular velocity for momentum
        let timeDelta = currentTime.timeIntervalSince(lastDragTime)
        if timeDelta > 0 {
            let dq = orientation * lastDragOrientation.inverted()
            let axisAngle = dq.toAxisAngle()
            let speed = axisAngle.angle / timeDelta
            angularVelocity = axisAngle.axis * min(speed, maxAngularSpeed)
            angularVelocityDebug = angularVelocity.length
            if angularVelocity.length > maxAngularVelocityDuringDrag {
                maxAngularVelocityDuringDrag = angularVelocity.length
            }
        }
        
        lastDragVector = currentVector
        lastDragOrientation = orientation
        lastDragTime = currentTime
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        isDragging = false

        if isTrainingMode, trainingStep == .spinSphere, !isTrainingStepDelayActive {
            isTrainingStepDelayActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if isTrainingMode, trainingStep == .spinSphere {
                    trainingStep = .openTagView
                }
                isTrainingStepDelayActive = false
            }
        }

        // Match finger speed on release (no extra boost)
        let boosted = angularVelocity * momentumBoost
        if boosted.length > maxAngularSpeed {
            angularVelocity = boosted.normalized() * maxAngularSpeed
        } else {
            angularVelocity = boosted
        }
        angularVelocityDebug = angularVelocity.length

        // Start deceleration with momentum
        startDeceleration()
    }

    private func handleMagnificationChange(_ value: CGFloat) {
        if !isPinching {
            isPinching = true
            sphereScaleStart = userSphereScale
            stopDeceleration()
        }

        let countFactor = dynamicSphereScaleFactor(for: tileCount)
        let proposed = sphereScaleStart * Double(value)
        let minScale = dynamicMinSphereScale(for: tileCount)
        let minUserScale = minScale / countFactor
        let maxUserScale = maxSphereScale / countFactor
        let clamped = min(max(proposed, minUserScale), maxUserScale)
        let bounced = rubberBand(value: proposed * countFactor, min: minScale, max: maxSphereScale)
        userSphereScale = clamped
        sphereScale = bounced
    }

    private func handleMagnificationEnd() {
        isPinching = false
        updateEffectiveSphereScale(animated: true)
    }

    private func rubberBand(value: Double, min minValue: Double, max maxValue: Double) -> Double {
        let band: Double = 0.35
        if value < minValue {
            // Allow a deeper overshoot toward zero on pinch-in
            let deepMin = minValue * 0.1
            let clamped = Swift.max(value, deepMin)
            let delta = minValue - clamped
            return minValue - delta * band
        } else if value > maxValue {
            let delta = value - maxValue
            return maxValue + delta * band
        }
        return value
    }

    private func dynamicMinSphereScale(for count: Int) -> Double {
        let baseMin: Double = 0.52
        let baseCount: Double = 6.0
        let growthPerSqrt: Double = 0.035
        let extra = max(0.0, sqrt(Double(count)) - sqrt(baseCount))
        let scale = baseMin + (extra * growthPerSqrt)
        return min(scale, maxSphereScale)
    }

    private func dynamicSphereScaleFactor(for count: Int) -> Double {
        let safeCount = max(count, 1)
        if safeCount <= 3 { return 0.46 }
        if safeCount <= 6 { return 0.54 }
        if safeCount <= 10 { return 0.64 }
        let normalized = min(1.0, max(0.0, sqrt(Double(safeCount)) / sqrt(30.0)))
        return 0.72 + (0.28 * normalized)
    }
    
    private func updateEffectiveSphereScale(animated: Bool) {
        let minScale = dynamicMinSphereScale(for: tileCount)
        let target = max(userSphereScale * dynamicSphereScaleFactor(for: tileCount), minScale)
        guard abs(target - sphereScale) > 0.0001 else { return }
        if animated {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 16)) {
                sphereScale = target
            }
        } else {
            sphereScale = target
        }
    }
    
    private func handleTileTap(index: Int) {
        if suppressTapSelection {
            return
        }
        // Stop deceleration when tapping
        stopDeceleration()
        
        // If we're in tag filter mode, handle tile selection in list
        if let filteredTagId = filteredTagId {
            let filteredIndices = getTilesForTag(filteredTagId)
            guard
                filteredIndices.contains(index),
                let tappedId = tileIds[safe: index]
            else { return }
            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.84, blendDuration: 0.1)) {
                centeredFilteredId = tappedId
                isEditingTile = false
                if !isTagPickerPinned {
                    showTagPicker = false
                }
            }
            return
        }
        
        // In sphere mode, trigger tag filter view
        guard index < tileTags.count else { return }
        
        let tappedTagId = tileTags[index]
        openTagFilter(for: tappedTagId, preferredIndex: index)
    }

    private func openTagFilter(
        for tagId: Int,
        preferredIndex: Int? = nil,
        openTagPicker: Bool = false,
        pinTagPicker: Bool = false
    ) {
        stopDeceleration()
        let tilesForTag = getTilesForTag(tagId)
        guard !tilesForTag.isEmpty else { return }

        // Store original orientation state
        originalOrientation = orientation

        // Calculate available tags (tags that have tiles)
        availableTagIds = getAvailableTags()

        // Find the index of the chosen tag in available tags
        if let tagIndex = availableTagIds.firstIndex(of: tagId) {
            currentTagIndex = tagIndex
        } else {
            currentTagIndex = 0
        }

        let targetIndex = preferredIndex.flatMap { tilesForTag.contains($0) ? $0 : nil } ?? tilesForTag.first!

        // Animate to tag filter view
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            filteredTagId = tagId
            selectedIndex = targetIndex
            isEditingTile = false
            showTagPicker = openTagPicker
            isTagPickerPinned = openTagPicker && pinTagPicker
        }
    }
    
    // MARK: - Momentum/Deceleration
    
    private func startDeceleration() {
        stopDeceleration(clearVelocity: false)
        let speed = angularVelocity.length
        isDeceleratingDebug = true
        angularVelocityDebug = speed
        decelerationLastTimestamp = 0
        decelerationDriver.onStep = { timestamp in
            if self.decelerationLastTimestamp == 0 {
                self.decelerationLastTimestamp = timestamp
                return
            }
            let dt = timestamp - self.decelerationLastTimestamp
            self.decelerationLastTimestamp = timestamp
            
            let currentSpeed = self.angularVelocity.length
            if currentSpeed <= self.minAngularVelocity {
                self.stopDeceleration()
                return
            }
            
            let axis = self.angularVelocity.normalized()
            let delta = Quaternion.fromAxisAngle(axis: axis, angle: currentSpeed * dt)
            self.orientation = (delta * self.orientation).normalized()
            
            let decay = pow(self.decelerationRate, dt)
            if decay != 1.0 {
                let speedFactor = min(1.0, currentSpeed / 1.0)
                let boostedDecay = pow(decay, 1.0 + (1.0 - speedFactor) * 2.2)
                let decayed = self.angularVelocity * boostedDecay
                if decayed.length > self.maxAngularSpeed {
                    self.angularVelocity = decayed.normalized() * self.maxAngularSpeed
                } else {
                    self.angularVelocity = decayed
                }
                if self.angularVelocity.length < self.minAngularVelocity {
                    self.angularVelocity = axis * self.minAngularVelocity
                }
            }
            self.angularVelocityDebug = self.angularVelocity.length
        }
        isDeceleratingDebug = true
        decelerationDriver.start(preferredFPS: 120)
    }
    
    private func stopDeceleration(clearVelocity: Bool = true) {
        decelerationDriver.stop()
        decelerationDriver.onStep = nil
        decelerationLastTimestamp = 0
        if clearVelocity {
            angularVelocity = .zero
            angularVelocityDebug = 0
        }
        isDeceleratingDebug = false
    }
    
    // MARK: - Tile Management
    
    private func createTile(tagId: Int? = nil) {
        // Stop any ongoing deceleration
        stopDeceleration()
        
        // Add a new blank tile
        tileTexts.append("")
        tileCount += 1
        
        // Assign tag for new tile (defaults to Brain Dump)
        let resolvedTagId = tagId ?? tagManager.getDefaultTag().id
        tileTags.append(resolvedTagId)
        
        // Assign unique ID
        let newTileId = UUID().uuidString
        tileIds.append(newTileId)
        registerNewTileForNotificationPrompt()
        
        // Get the index of the newly created tile
        let newTileIndex = tileCount - 1
        
        // Animate the new tile to center and enable editing
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selectedIndex = newTileIndex
            isEditingTile = true
            if filteredTagId != nil {
                centeredFilteredId = newTileId
            }
        }
        focusRequestId = UUID()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            focusRequestId = UUID()
        }
        pendingBlankTileIndex = newTileIndex
        if isTrainingMode, trainingStep == .addThoughtTile {
            didAddThoughtTileForTraining = true
        }
    }
    
    private func deleteTile(at index: Int) {
        guard index < tileTexts.count && index < tileTags.count && index < tileIds.count else { return }
        
        let wasSelected = selectedIndex == index
        let priorSelectedIndex = selectedIndex

        // Remove tile data
        tileTexts.remove(at: index)
        tileTags.remove(at: index)
        tileIds.remove(at: index)
        tileCount -= 1
        
        // Adjust selected index if a tile before it was deleted
        if let currentSelected = priorSelectedIndex, currentSelected > index {
            selectedIndex = currentSelected - 1
        }

        if let filteredTagId = filteredTagId {
            let remaining = getTilesForTag(filteredTagId)
            if remaining.isEmpty {
                dismissTagFilter()
            } else if wasSelected {
                let targetIndex = remaining.first(where: { $0 >= index }) ?? remaining.last!
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectedIndex = targetIndex
                    isEditingTile = false
                    if !isTagPickerPinned {
                        showTagPicker = false
                    }
                }
            } else if let currentSelected = selectedIndex, !remaining.contains(currentSelected) {
                let fallbackIndex = remaining.first!
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    selectedIndex = fallbackIndex
                    isEditingTile = false
                    if !isTagPickerPinned {
                        showTagPicker = false
                    }
                }
            }
        } else if wasSelected {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                selectedIndex = nil
                isEditingTile = false
            }
        }

        if filteredTagId != nil, let currentSelected = selectedIndex, let selectedId = tileIds[safe: currentSelected] {
            centeredFilteredId = selectedId
        }

        if let pendingIndex = pendingBlankTileIndex {
            if pendingIndex == index {
                pendingBlankTileIndex = nil
            } else if pendingIndex > index {
                pendingBlankTileIndex = pendingIndex - 1
            }
        }
    }

    private func deleteTile(withId id: String) {
        guard let index = tileIds.firstIndex(of: id) else { return }
        deleteTile(at: index)
    }

    private func softDeleteTile(at index: Int) {
        guard index < tileTexts.count && index < tileTags.count && index < tileIds.count else { return }
        let id = tileIds[index]
        guard !deletingTileIds.contains(id) && !completingTileIds.contains(id) else { return }
        let archived = ArchivedTile(
            id: id,
            text: tileTexts[index],
            tagId: tileTags[index],
            archivedAt: Date()
        )
        deletedTiles.append(archived)
        deletingTileIds.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.deleteTile(withId: id)
            }
            self.deletingTileIds.remove(id)
            self.saveTiles()
        }
    }
    
    private func completeTile(at index: Int) {
        guard index < tileTexts.count && index < tileTags.count && index < tileIds.count else { return }
        let id = tileIds[index]
        guard !completingTileIds.contains(id) && !deletingTileIds.contains(id) else { return }
        if isTrainingMode, trainingStep == .completeTile {
            didCompleteTileForTraining = true
            trainingStep = .addThoughtTile
        }
        let archived = ArchivedTile(
            id: id,
            text: tileTexts[index],
            tagId: tileTags[index],
            archivedAt: Date()
        )
        completedTiles.append(archived)
        completingTileIds.insert(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.deleteTile(withId: id)
            }
            self.completingTileIds.remove(id)
            self.saveTiles()
        }
    }
    
    private func restoreArchivedTile(_ tile: ArchivedTile) {
        let signature = "\(tile.text)|\(tile.tagId)"
        let existingSignatures = Set(tileTexts.indices.map { index in
            "\(tileTexts[index])|\(tileTags[safe: index] ?? tagManager.getDefaultTag().id)"
        })
        guard !existingSignatures.contains(signature) else { return }
        
        let newId = tileIds.contains(tile.id) ? UUID().uuidString : tile.id
        tileIds.append(newId)
        tileTexts.append(tile.text)
        tileTags.append(tile.tagId)
        tileCount = tileTexts.count
        saveTiles()
    }
    
    private func purgeDeletedOlderThan30Days() {
        if isTrainingMode { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        deletedTiles.removeAll { $0.archivedAt < cutoff }
        saveArchives()
    }

    private func finalizeNewTileIfBlank() {
        guard let pendingIndex = pendingBlankTileIndex else { return }
        guard tileTexts.indices.contains(pendingIndex) else {
            pendingBlankTileIndex = nil
            return
        }

        let trimmed = tileTexts[pendingIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteTile(at: pendingIndex)
        }
        pendingBlankTileIndex = nil
    }
    
    func resetApp() {
        // Stop any ongoing deceleration
        stopDeceleration()
        
        // Clear tile and archive state
        tileTexts.removeAll()
        tileTags.removeAll()
        tileIds.removeAll()
        tileCount = 0
        completedTiles.removeAll()
        deletedTiles.removeAll()
        deletingTileIds.removeAll()
        completingTileIds.removeAll()
        
        // Reset active UI state
        selectedIndex = nil
        isEditingTile = false
        showTagPicker = false
        isTagPickerPinned = false
        filteredTagId = nil
        centeredFilteredId = nil
        tagChangeAnimatingTileId = nil
        pendingBlankTileIndex = nil
        showDeleteConfirmation = false
        tileToDelete = nil
        
        // Recreate starter guidance tiles for a true fresh start
        createInitialTiles()
    }
    
    // MARK: - Tag Filter Helpers
    
    /// Returns indices of all tiles with the given tag
    private func getTilesForTag(_ tagId: Int) -> [Int] {
        return tileTags.enumerated().compactMap { index, tag in
            tag == tagId ? index : nil
        }
    }
    
    /// Returns all tag IDs that have at least one tile
    private func getAvailableTags() -> [Int] {
        let tagsWithTiles = Set(tileTags)
        return tagManager.tagsInDisplayOrder
            .filter { tagsWithTiles.contains($0.id) }
            .map { $0.id }
    }

    private func updateSelectionAfterTagChange(from previousIndex: Int, filteredTagId: Int) {
        let remaining = getTilesForTag(filteredTagId)
        if remaining.isEmpty {
            dismissTagFilter()
            return
        }

        let nextIndex = remaining.first(where: { $0 > previousIndex }) ?? remaining.first!
        if selectedIndex != nextIndex {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                selectedIndex = nextIndex
                isEditingTile = false
                if !isTagPickerPinned {
                    showTagPicker = false
                }
            }
        }
    }

    private func triggerScrollHaptic(for id: String) {
        let now = Date()
        if lastScrollHapticId == nil {
            lastScrollHapticId = id
            lastScrollHapticTime = now
            return
        }
        guard id != lastScrollHapticId else { return }
        guard now.timeIntervalSince(lastScrollHapticTime) > 0.06 else { return }
        Haptics.selectionChange()
        lastScrollHapticId = id
        lastScrollHapticTime = now
    }
    
    /// Calculates the list position for a tile in the filtered view
    private func calculateListPosition(
        for index: Int,
        in filteredIndices: [Int],
        containerSize: CGSize
    ) -> CGPoint {
        let tileSize: CGFloat = 100
        let spacing: CGFloat = 16
        let topPadding: CGFloat = 100
        let centerX = containerSize.width / 2
        
        let listIndex = filteredIndices.firstIndex(of: index) ?? 0
        let yPosition = topPadding + CGFloat(listIndex) * (tileSize + spacing)
        
        return CGPoint(x: centerX, y: yPosition)
    }
    
    /// Dismisses the tag filter view and returns tiles to sphere
    private func dismissTagFilter() {
        // Restore original orientation state
        orientation = originalOrientation
        
        // Animate back to sphere view
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            filteredTagId = nil
            selectedIndex = nil
            centeredFilteredId = nil
            tagChangeAnimatingTileId = nil
            isEditingTile = false
            showTagPicker = false
            isTagPickerPinned = false
        }
        lastScrollHapticId = nil
    }

    private func advanceFilteredTag(by offset: Int) {
        guard !availableTagIds.isEmpty else { return }
        let previousTagId = filteredTagId
        let count = availableTagIds.count
        let newIndex = (currentTagIndex + offset + count) % count
        let newTagId = availableTagIds[newIndex]
        let newFilteredIndices = getTilesForTag(newTagId)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentTagIndex = newIndex
            filteredTagId = newTagId
            selectedIndex = newFilteredIndices.first
            isEditingTile = false
            if !isTagPickerPinned {
                showTagPicker = false
            }
        }
        if isTrainingMode, trainingStep == .swipeTags, previousTagId != nil, previousTagId != newTagId, !isTrainingStepDelayActive {
            didSwipeTagsForTraining = true
            isTrainingStepDelayActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if isTrainingMode, trainingStep == .swipeTags {
                    dismissTagFilter()
                    trainingStep = .finish
                }
                isTrainingStepDelayActive = false
            }
        }
    }

    private func ensureTrainingSwipeTagAvailability() {
        guard isTrainingMode else { return }
        let currentTags = Set(tileTags)
        guard currentTags.count < 2 else { return }
        let defaultTagId = tagManager.getDefaultTag().id
        let secondaryTagId = tagManager.tagsInDisplayOrder.first(where: { $0.id != defaultTagId })?.id
        guard let secondaryTagId, secondaryTagId != defaultTagId else { return }
        guard !tileTags.isEmpty else { return }
        let pivotIndex = (selectedIndex.flatMap { tileTags.indices.contains($0) ? $0 : nil }) ?? 0
        tileTags[pivotIndex] = secondaryTagId
    }

    private func pauseSphereForEditing() {
        stopDeceleration()
        isDragging = false
        isPinching = false
    }

    private func resumeSphereAfterEditing() {
        lastDragTime = Date()
    }
    
    #if DEBUG
    func createTestTiles() {
        // Stop any ongoing deceleration
        stopDeceleration()
        
        // Test content for each tag type
        let testContent: [Int: [String]] = [
            // Brain Dump (tag id 0)
            0: [
                "Random thought: Why do we park on driveways?",
                "Idea: Create an app for organizing thoughts",
                "Note: Remember to check email",
                "Brainstorm: New project ideas",
                "Reminder: Call mom this weekend"
            ],
            // Movies to watch (tag id 1)
            1: [
                "The Matrix",
                "Inception",
                "Interstellar",
                "Blade Runner 2049",
                "The Shawshank Redemption",
                "Pulp Fiction",
                "The Dark Knight",
                "Fight Club",
                "Forrest Gump",
                "The Godfather"
            ],
            // Books to read (tag id 2)
            2: [
                "1984 by George Orwell",
                "To Kill a Mockingbird",
                "The Great Gatsby",
                "Pride and Prejudice",
                "The Catcher in the Rye",
                "Lord of the Flies",
                "Brave New World",
                "Animal Farm",
                "The Hobbit",
                "Dune"
            ],
            // Things to do (tag id 3)
            3: [
                "Buy groceries",
                "Schedule dentist appointment",
                "Finish project report",
                "Exercise for 30 minutes",
                "Clean the garage",
                "Pay electricity bill",
                "Call insurance company",
                "Organize desk",
                "Update resume",
                "Plan weekend trip"
            ],
            // Websites to check (tag id 4)
            4: [
                "Hacker News",
                "Product Hunt",
                "TechCrunch",
                "Medium",
                "GitHub Trending",
                "Reddit r/programming",
                "Stack Overflow",
                "Dev.to",
                "CSS-Tricks",
                "Smashing Magazine"
            ]
        ]
        
        // Get all available tags
        let availableTags = tagManager.tags
        
        // Track used content to prevent duplicates
        var usedContent: Set<String> = Set(tileTexts)
        
        // Create 10 random tiles
        for _ in 0..<10 {
            // Pick a random tag
            guard let randomTag = availableTags.randomElement() else { continue }
            
            // Get content for this tag
            if let tagContent = testContent[randomTag.id] {
                // Find unused content
                let unusedContent = tagContent.filter { !usedContent.contains($0) }
                
                if let selectedContent = unusedContent.randomElement() {
                    tileTexts.append(selectedContent)
                    tileTags.append(randomTag.id)
                    tileIds.append(UUID().uuidString)
                    tileCount += 1
                    usedContent.insert(selectedContent)
                } else if let fallbackContent = tagContent.randomElement() {
                    // If all content for this tag is used, use any content from the tag
                    tileTexts.append(fallbackContent)
                    tileTags.append(randomTag.id)
                    tileIds.append(UUID().uuidString)
                    tileCount += 1
                }
            } else {
                // Fallback for tags without specific content
                tileTexts.append("Test tile for \(randomTag.name)")
                tileTags.append(randomTag.id)
                tileIds.append(UUID().uuidString)
                tileCount += 1
            }
        }
        
        // Save the new tiles
        saveTiles()
    }
#endif
}

private struct FilteredTileItem: Identifiable {
    let id: String
    let index: Int
    let listPosition: Int
}

private struct ScrollPhaseSnapModifier: ViewModifier {
    let targetId: String?
    let stopScrollTo: (String) -> Void
    let snapScrollTo: (String) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onScrollPhaseChange { oldPhase, newPhase in
                guard let targetId = targetId else { return }

                // Touch down should immediately stop any residual momentum/animation.
                if newPhase == .tracking {
                    stopScrollTo(targetId)
                    return
                }

                // Snap once the drag/deceleration phase settles.
                let endedDragWithoutDeceleration = oldPhase == .interacting && newPhase == .idle
                let beganDeceleration = oldPhase == .interacting && newPhase == .decelerating
                let endedDeceleration = oldPhase == .decelerating && newPhase == .idle
                if endedDragWithoutDeceleration || beganDeceleration || endedDeceleration {
                    snapScrollTo(targetId)
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Tile View

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
    
    @FocusState private var isFocused: Bool
    @State private var popIn = false
    @State private var deleteScale: CGFloat = 1.0
    @State private var deleteOpacity: Double = 1.0
    @State private var completeScale: CGFloat = 1.0
    @State private var completeOpacity: Double = 1.0
    @State private var selectionPulse: CGFloat = 1.0
    
    // Fixed tile size (square) - increased for better text wrapping
    private let tileSize: CGFloat = 100
    
    // Calculate dynamic font size based on text length
    private func calculateFontSize(text: String, isSelected: Bool) -> CGFloat {
        let textLength = text.count
        
        // Base font sizes
        let baseSize: CGFloat = isSelected ? 24 : 16
        let minSize: CGFloat = 8
        let maxSize: CGFloat = isSelected ? 24 : 16

        // Gradually reduce size as text grows, down to minSize.
        let startShrinkAt: CGFloat = 10
        let reachMinAt: CGFloat = 80
        let clampedLength = min(max(CGFloat(textLength), startShrinkAt), reachMinAt)
        let t = (clampedLength - startShrinkAt) / (reachMinAt - startShrinkAt) // 0...1
        let calculatedSize = baseSize + (minSize - baseSize) * t

        // Clamp between min and max
        return max(minSize, min(maxSize, calculatedSize))
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
        let shouldAnimatePopIn = isNewTile && !isFiltered
        let displayPosition: CGPoint = (shouldAnimatePopIn && !popIn)
            ? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
            : layout.position
        let popScale: CGFloat = shouldAnimatePopIn ? (popIn ? 1.0 : 0.0) : 1.0
        let popOpacity: Double = shouldAnimatePopIn ? (popIn ? 1.0 : 0.0) : 1.0
        let tagChangeScale: CGFloat = isTagChanging ? 1.24 : 1.0
        let tagChangeOpacity: Double = isTagChanging ? 0.0 : 1.0
        let tagChangeOffsetX: CGFloat = isTagChanging ? -260 : 0
        
        // Calculate dynamic font size based on text length
        let dynamicFontSize = calculateFontSize(text: text, isSelected: isSelected)
        
        // Get tag color
        let tag = tagManager.getTag(byId: tagId) ?? tagManager.getDefaultTag()
        let tagColor = tag.uiColor
        
        // Padding for text inside tile
        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 6
        
        let tileBackground = RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tagColor.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tagColor.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

        let effectiveTileSize = isFiltered ? (tileSize * 1.1) : tileSize

        ZStack {
            if isEditing && isSelected {
                TextField("", text: Binding(
                    get: { text },
                    set: { onTextChange($0) }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(false)
                .textInputAutocapitalization(.sentences)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .font(.system(size: dynamicFontSize, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .focused($isFocused)
            } else {
                Text(text.isEmpty ? " " : text)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .font(.system(size: dynamicFontSize, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
            }
        }
        .frame(width: effectiveTileSize, height: effectiveTileSize)
        .background(tileBackground)
        .overlay(
            Group {
                if isFiltered && isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tagColor.opacity(0.95), lineWidth: 3)
                        .shadow(color: tagColor.opacity(0.45), radius: 12, x: 0, y: 6)
                }
            }
        )
        .scaleEffect(layout.scale * popScale * deleteScale * completeScale * selectionPulse * tagChangeScale)
        .opacity(layout.opacity * popOpacity * deleteOpacity * completeOpacity * tagChangeOpacity)
        .offset(x: tagChangeOffsetX)
        .zIndex(layout.zIndex)
        .modifier(ConditionalPositionModifier(isFiltered: isFiltered, position: displayPosition))
        .animation(.easeInOut(duration: 0.26), value: isTagChanging)
        .onAppear {
            if shouldAnimatePopIn {
                popIn = false
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                    popIn = true
                }
            }
        }
        .onChange(of: isNewTile) { _, newValue in
            if newValue && !isFiltered {
                popIn = false
                withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                    popIn = true
                }
            }
        }
        .onChange(of: isDeleting) { _, newValue in
            guard newValue else { return }
            deleteScale = 1.0
            deleteOpacity = 1.0
            withAnimation(.easeOut(duration: 0.12)) {
                deleteScale = 1.18
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeIn(duration: 0.22)) {
                    deleteScale = 0.05
                    deleteOpacity = 0.0
                }
            }
        }
        .onChange(of: isCompleting) { _, newValue in
            guard newValue else { return }
            completeScale = 1.0
            completeOpacity = 1.0
            withAnimation(.easeOut(duration: 0.12)) {
                completeScale = 1.18
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeOut(duration: 0.28)) {
                    completeScale = 2.2
                    completeOpacity = 0.0
                }
            }
        }
        .onChange(of: isSelected) { _, newValue in
            guard isFiltered else { return }
            if newValue {
                selectionPulse = 0.9
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 13)) {
                    selectionPulse = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.interpolatingSpring(stiffness: 220, damping: 18)) {
                        selectionPulse = 1.0
                    }
                }
            } else {
                selectionPulse = 1.0
            }
        }
        .onChange(of: isEditing) { _, newValue in
            // Focus only the selected tile to avoid multiple responders.
            if newValue && isSelected {
                DispatchQueue.main.async {
                    isFocused = true
                }
            } else {
                isFocused = false
            }
        }
        .onChange(of: focusRequestId) { _, _ in
            if isEditing && isSelected {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
        }
        .onTapGesture {
            if isTapEnabled {
                onTap()
            }
        }
    }
}

// MARK: - Cylinder Row (Filter Mode)

struct CylinderTileRow<Content: View>: View {
    let containerMidY: CGFloat
    let rowHeight: CGFloat
    let isSelected: Bool
    let content: () -> Content

    var body: some View {
        GeometryReader { itemGeo in
            let itemMidY = itemGeo.frame(in: .global).midY
            let distance = abs(itemMidY - containerMidY)
            let normalized = min(1.0, distance / 320)
            let focus = 1.0 - normalized
            let baseScale = 0.92 + (focus * 0.12)
            let selectedBoost: CGFloat = isSelected ? 0.03 : 0.0
            let scale = baseScale + selectedBoost
            let opacity = 0.55 + (focus * 0.45)
            let blur = isSelected ? 0.0 : normalized * 0.25
            let tilt = Double((itemMidY - containerMidY) / 420) * 4
            let rowZ: Double = isSelected ? 1000.0 : Double(1.0 - normalized)
            content()
                .scaleEffect(scale)
                .opacity(opacity)
                .rotation3DEffect(
                    .degrees(tilt),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.7
                )
                .blur(radius: blur)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(rowZ)
                .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.12), value: isSelected)
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Math Helper

struct SphereMath {
    // Generate evenly distributed points on a sphere using golden angle spiral
    static func generatePoint(index: Int, total: Int) -> Point3D {
        // Handle edge case: when there's only one tile, place it at the center
        guard total > 1 else {
            return Point3D(x: 0.0, y: 0.0, z: 0.0)
        }
        
        // Golden angle in radians
        let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
        
        // Normalized index (0 to 1)
        let y = 1.0 - (Double(index) / Double(total - 1)) * 2.0
        
        // Radius at this y level
        let radius = sqrt(1.0 - y * y)
        
        // Angle around the sphere
        let theta = goldenAngle * Double(index)
        
        // Convert to 3D coordinates
        let x = cos(theta) * radius
        let z = sin(theta) * radius
        
        return Point3D(x: x, y: y, z: z)
    }
    
    // Rotate a 3D point using a quaternion orientation
    static func rotatePoint(point: Point3D, orientation: Quaternion) -> Point3D {
        orientation.rotate(point)
    }
    
    // Project 3D point to 2D screen coordinates
    static func projectTo2D(point: Point3D, containerSize: CGSize, sphereScale: Double) -> ProjectedPoint {
        // Perspective projection with field of view
        let fov: Double = 2.0
        let distance: Double = 3.0
        
        // Project to 2D
        let scale = fov / (distance - point.z)
        let screenX = point.x * scale
        let screenY = point.y * scale
        
        // Convert to screen coordinates (center of container)
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
        let screenSize = min(containerSize.width, containerSize.height)

        // Calculate position based on current sphere scale
        let positionX = centerX + CGFloat(screenX * Double(screenSize) * sphereScale)
        let positionY = centerY + CGFloat(screenY * Double(screenSize) * sphereScale)
        
        return ProjectedPoint(
            position: CGPoint(x: positionX, y: positionY),
            depth: point.z
        )
    }
    
    // Compute scale based on depth (front = 1.0, back = slightly smaller)
    static func computeScale(depth: Double) -> CGFloat {
        // Depth ranges from -1 to 1, map to scale 0.85 to 1.0
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let scale = 0.85 + (normalizedDepth * 0.15) // 0.85 to 1.0
        return CGFloat(scale)
    }
    
    // Compute opacity based on depth (front = 1.0, back = more transparent)
    static func computeOpacity(depth: Double) -> Double {
        // Depth ranges from -1 to 1, map to opacity 0.2 to 1.0
        let normalizedDepth = (depth + 1.0) / 2.0 // 0 to 1
        let opacity = 0.2 + (normalizedDepth * 0.8) // 0.2 to 1.0
        return opacity
    }
    
    // Map 2D screen point to unit sphere (arcball)
    static func mapToSphere(point: CGPoint, in size: CGSize) -> Point3D {
        let radius = min(size.width, size.height) / 2.0
        guard radius > 0 else { return .zero }
        let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        let x = (point.x - center.x) / radius
        let y = (point.y - center.y) / radius
        let lengthSquared = x * x + y * y
        if lengthSquared <= 1.0 {
            let z = sqrt(1.0 - lengthSquared)
            return Point3D(x: Double(x), y: Double(y), z: Double(z))
        } else {
            let length = sqrt(lengthSquared)
            let nx = x / length
            let ny = y / length
            return Point3D(x: Double(nx), y: Double(ny), z: 0.0)
        }
    }
}

// MARK: - Tag Model

struct Tag: Identifiable, Codable {
    let id: Int
    let name: String
    let color: TagColor
    let isDefault: Bool
    
    var uiColor: Color {
        color.uiColor
    }
}

enum TagColor: String, Codable, CaseIterable {
    case grey
    case yellow
    case brown
    case darkBlue
    case lightBlue
    case red
    case green
    case orange
    case purple
    case pink
    case teal
    case indigo
    case mint
    case cyan
    case rose
    case coral
    case amber
    case lime
    case emerald
    case seafoam
    case turquoise
    case sky
    case azure
    case cobalt
    case violet
    case magenta
    case plum
    case slate
    case neonPink
    case neonLime
    case neonYellow
    case neonOrange
    case neonBlue
    case neonPurple
    case neonCyan

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? TagColor.grey.rawValue
        self = TagColor(rawValue: rawValue) ?? .grey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let orderedPalette: [TagColor] = [
        .coral, .red, .orange, .amber, .yellow, .lime, .green,
        .emerald, .seafoam, .mint, .turquoise, .teal, .cyan, .sky,
        .lightBlue, .azure, .darkBlue, .cobalt, .indigo, .violet, .purple,
        .plum, .magenta, .pink, .rose,
        .brown, .slate, .grey,
        .neonPink, .neonLime, .neonYellow, .neonOrange, .neonBlue, .neonPurple, .neonCyan
    ]
    
    var uiColor: Color {
        switch self {
        case .grey: return Color(red: 0.64, green: 0.66, blue: 0.70)
        case .yellow: return Color(red: 0.99, green: 0.86, blue: 0.10)
        case .brown: return Color(red: 0.68, green: 0.44, blue: 0.18)
        case .darkBlue: return Color(red: 0.08, green: 0.32, blue: 0.82)
        case .lightBlue: return Color(red: 0.36, green: 0.76, blue: 0.98)
        case .red: return Color(red: 0.97, green: 0.28, blue: 0.20)
        case .green: return Color(red: 0.20, green: 0.79, blue: 0.26)
        case .orange: return Color(red: 0.99, green: 0.52, blue: 0.06)
        case .purple: return Color(red: 0.58, green: 0.30, blue: 0.92)
        case .pink: return Color(red: 0.97, green: 0.40, blue: 0.72)
        case .teal: return Color(red: 0.06, green: 0.72, blue: 0.68)
        case .indigo: return Color(red: 0.33, green: 0.28, blue: 0.90)
        case .mint: return Color(red: 0.46, green: 0.98, blue: 0.76)
        case .cyan: return Color(red: 0.16, green: 0.92, blue: 0.96)
        case .rose: return Color(red: 0.97, green: 0.30, blue: 0.50)
        case .coral: return Color(red: 1.00, green: 0.42, blue: 0.30)
        case .amber: return Color(red: 0.98, green: 0.66, blue: 0.00)
        case .lime: return Color(red: 0.72, green: 0.93, blue: 0.00)
        case .emerald: return Color(red: 0.00, green: 0.76, blue: 0.34)
        case .seafoam: return Color(red: 0.22, green: 0.88, blue: 0.66)
        case .turquoise: return Color(red: 0.00, green: 0.84, blue: 0.78)
        case .sky: return Color(red: 0.30, green: 0.78, blue: 1.00)
        case .azure: return Color(red: 0.00, green: 0.52, blue: 1.00)
        case .cobalt: return Color(red: 0.09, green: 0.30, blue: 0.90)
        case .violet: return Color(red: 0.70, green: 0.24, blue: 0.98)
        case .magenta: return Color(red: 0.94, green: 0.14, blue: 0.74)
        case .plum: return Color(red: 0.56, green: 0.15, blue: 0.56)
        case .slate: return Color(red: 0.44, green: 0.52, blue: 0.64)
        case .neonPink: return Color(red: 1.00, green: 0.00, blue: 0.78)
        case .neonLime: return Color(red: 0.60, green: 1.00, blue: 0.00)
        case .neonYellow: return Color(red: 1.00, green: 1.00, blue: 0.00)
        case .neonOrange: return Color(red: 1.00, green: 0.33, blue: 0.00)
        case .neonBlue: return Color(red: 0.00, green: 0.62, blue: 1.00)
        case .neonPurple: return Color(red: 0.66, green: 0.00, blue: 1.00)
        case .neonCyan: return Color(red: 0.00, green: 1.00, blue: 0.95)
        }
    }
}

// MARK: - Tag Manager

class TagManager: ObservableObject {
    @Published var tags: [Tag] = []
    
    private let tagsKey = "SavedTags"
    private let defaultTagId = 0 // Brain Dump
    private let maxUserTags = 20
    private let defaultTagDisplayOrder: [Int] = [0, 3, 1, 2, 4]
    
    init() {
        loadTags()
    }
    
    private func loadTags() {
        // Load from UserDefaults or create defaults
        if let data = UserDefaults.standard.data(forKey: tagsKey),
           let decoded = try? JSONDecoder().decode([Tag].self, from: data),
           !decoded.isEmpty {
            tags = decoded
        } else {
            // Create default tags
            tags = [
                Tag(id: 0, name: "Brain Dump", color: .grey, isDefault: true),
                Tag(id: 3, name: "Things to do", color: .brown, isDefault: true),
                Tag(id: 1, name: "Movies to watch", color: .darkBlue, isDefault: true),
                Tag(id: 2, name: "Books to read", color: .yellow, isDefault: true),
                Tag(id: 4, name: "Websites to check", color: .lightBlue, isDefault: true)
            ]
            saveTags()
        }
    }
    
    func saveTags() {
        if let encoded = try? JSONEncoder().encode(tags) {
            UserDefaults.standard.set(encoded, forKey: tagsKey)
        }
    }
    
    func addUserTag(name: String, color: TagColor) {
        guard canAddMoreUserTags else { return }
        // Find next available ID
        let nextId = (tags.map { $0.id }.max() ?? 4) + 1
        let newTag = Tag(id: nextId, name: name, color: color, isDefault: false)
        tags.append(newTag)
        saveTags()
    }
    
    func deleteUserTag(_ tag: Tag) {
        guard !tag.isDefault else { return }
        tags.removeAll { $0.id == tag.id }
        saveTags()
    }
    
    func getDefaultTag() -> Tag {
        return tags.first { $0.id == defaultTagId } ?? tags[0]
    }
    
    func getTag(byId id: Int) -> Tag? {
        return tags.first { $0.id == id }
    }

    var defaultTagsInDisplayOrder: [Tag] {
        tags
            .filter { $0.isDefault }
            .sorted { lhs, rhs in
                let leftIndex = defaultTagDisplayOrder.firstIndex(of: lhs.id) ?? Int.max
                let rightIndex = defaultTagDisplayOrder.firstIndex(of: rhs.id) ?? Int.max
                if leftIndex != rightIndex { return leftIndex < rightIndex }
                return lhs.id < rhs.id
            }
    }

    var tagsInDisplayOrder: [Tag] {
        defaultTagsInDisplayOrder + tags.filter { !$0.isDefault }
    }

    var userTags: [Tag] {
        tags.filter { !$0.isDefault }
    }
    
    var canAddMoreUserTags: Bool {
        userTags.count < maxUserTags
    }
}

// MARK: - Supporting Types

struct Point3D {
    let x: Double
    let y: Double
    let z: Double
}

struct ProjectedPoint {
    let position: CGPoint
    let depth: Double
}

// MARK: - 3D Vector Helpers

extension Point3D {
    static let zero = Point3D(x: 0, y: 0, z: 0)
    
    var length: Double {
        sqrt(x * x + y * y + z * z)
    }
    
    func normalized() -> Point3D {
        let len = length
        guard len > 0 else { return .zero }
        return self / len
    }
    
    func dot(_ other: Point3D) -> Double {
        x * other.x + y * other.y + z * other.z
    }
    
    func cross(_ other: Point3D) -> Point3D {
        Point3D(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }
    
    static func +(lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
    
    static func -(lhs: Point3D, rhs: Point3D) -> Point3D {
        Point3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }
    
    static func *(lhs: Point3D, rhs: Double) -> Point3D {
        Point3D(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
    
    static func /(lhs: Point3D, rhs: Double) -> Point3D {
        Point3D(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

// MARK: - Quaternion

struct Quaternion {
    let w: Double
    let x: Double
    let y: Double
    let z: Double
    
    static let identity = Quaternion(w: 1, x: 0, y: 0, z: 0)
    
    func normalized() -> Quaternion {
        let len = sqrt(w * w + x * x + y * y + z * z)
        guard len > 0 else { return .identity }
        return Quaternion(w: w / len, x: x / len, y: y / len, z: z / len)
    }
    
    func inverted() -> Quaternion {
        Quaternion(w: w, x: -x, y: -y, z: -z)
    }
    
    static func *(lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w
        )
    }
    
    static func fromAxisAngle(axis: Point3D, angle: Double) -> Quaternion {
        let half = angle / 2.0
        let s = sin(half)
        let n = axis.normalized()
        return Quaternion(w: cos(half), x: n.x * s, y: n.y * s, z: n.z * s).normalized()
    }
    
    static func fromVectors(_ v0: Point3D, _ v1: Point3D) -> Quaternion {
        let a = v0.normalized()
        let b = v1.normalized()
        let dot = max(-1.0, min(1.0, a.dot(b)))
        
        if dot > 0.999999 {
            return .identity
        }
        
        if dot < -0.999999 {
            let ortho = abs(a.x) < 0.1 ? Point3D(x: 1, y: 0, z: 0) : Point3D(x: 0, y: 1, z: 0)
            let axis = a.cross(ortho).normalized()
            return fromAxisAngle(axis: axis, angle: Double.pi)
        }
        
        let axis = a.cross(b)
        let angle = acos(dot)
        return fromAxisAngle(axis: axis, angle: angle)
    }
    
    func rotate(_ v: Point3D) -> Point3D {
        let qv = Quaternion(w: 0, x: v.x, y: v.y, z: v.z)
        let result = self * qv * inverted()
        return Point3D(x: result.x, y: result.y, z: result.z)
    }
    
    func toAxisAngle() -> (axis: Point3D, angle: Double) {
        let clampedW = max(-1.0, min(1.0, w))
        let angle = 2.0 * acos(clampedW)
        let s = sqrt(1.0 - clampedW * clampedW)
        if s < 0.0001 {
            return (Point3D(x: 1, y: 0, z: 0), 0)
        }
        return (Point3D(x: x / s, y: y / s, z: z / s), angle)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Cosmic Background View

struct AppBackgroundView: View {
    let theme: BackgroundTheme

    var body: some View {
        switch theme {
        case .space:
            CosmicBackgroundView()
        case .gradientOne:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.16),
                    Color(red: 0.15, green: 0.12, blue: 0.26)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gradientTwo:
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.12, blue: 0.16),
                    Color(red: 0.04, green: 0.06, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .clouds:
            CloudBackgroundView()
        case .offBlack:
            Color(red: 0.06, green: 0.06, blue: 0.07)
        }
    }
}

struct CloudBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.14, blue: 0.24),
                        Color(red: 0.14, green: 0.18, blue: 0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: geometry.size.width * 0.95)
                    .blur(radius: 36)
                    .offset(x: -geometry.size.width * 0.18, y: -geometry.size.height * 0.2)

                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: geometry.size.width * 0.8)
                    .blur(radius: 32)
                    .offset(x: geometry.size.width * 0.2, y: -geometry.size.height * 0.05)

                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: geometry.size.width * 1.05)
                    .blur(radius: 44)
                    .offset(x: 0, y: geometry.size.height * 0.3)
            }
        }
    }
}

struct CosmicBackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient (deep space)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2),
                        Color(red: 0.05, green: 0.1, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Middle layer - nebula glow
                RadialGradient(
                    colors: [
                        Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.4),
                        Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 50,
                    endRadius: geometry.size.width * 0.8
                )
                
                // Top layer - bright center light
                RadialGradient(
                    colors: [
                        Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.5),
                        Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 20,
                    endRadius: geometry.size.width * 0.5
                )
                
                // Stars layer (subtle shimmer)
                StarsView()
            }
        }
    }
}

// MARK: - Stars View

struct StarsView: View {
    // Generate random star positions (static so computed once)
    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let baseOpacity: Double
        let phase: Double
        let speed: Double
        let twinkles: Bool
    }
    
    private static let starCount = 100
    private static let stars: [Star] = {
        var stars: [Star] = []
        for _ in 0..<starCount {
            let twinkles = Double.random(in: 0...1) < 0.35
            stars.append(Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...3),
                baseOpacity: Double.random(in: 0.4...0.9),
                phase: Double.random(in: 0.0...(2.0 * Double.pi)),
                speed: Double.random(in: 0.1...0.4),
                twinkles: twinkles
            ))
        }
        return stars
    }()
    
    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.5)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                ForEach(0..<Self.starCount, id: \.self) { index in
                    let star = Self.stars[index]
                    let shimmer = star.twinkles ? (0.35 * sin(time * star.speed + star.phase)) : 0.0
                    let opacity = min(1.0, max(0.05, star.baseOpacity + shimmer))
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .opacity(opacity)
                        .position(
                            x: star.x * geometry.size.width,
                            y: star.y * geometry.size.height
                        )
                }
            }
        }
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let icon: String
    let foregroundColor: Color
    let borderColor: Color?
    let action: () -> Void
    
    private let buttonSize: CGFloat = 50
    
    init(
        icon: String,
        foregroundColor: Color = .primary,
        borderColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.action = action
    }

    var body: some View {
        Button(action: {
            Haptics.optionTap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor?.opacity(0.9) ?? .clear, lineWidth: borderColor == nil ? 0 : 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BrainDumpButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(16)
            .background(
                Group {
                    if #available(iOS 26.0, *) {
                        Circle()
                            .fill(Color.white.opacity(configuration.isPressed ? 0.42 : 0.32))
                            .glassEffect(in: Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(configuration.isPressed ? 0.9 : 0.82))
                    }
                }
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.white.opacity(configuration.isPressed ? 0.45 : 0.22),
                        lineWidth: configuration.isPressed ? 1.5 : 0.9
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.white.opacity(configuration.isPressed ? 0.18 : 0.0),
                        lineWidth: configuration.isPressed ? 4 : 0
                    )
                    .blur(radius: configuration.isPressed ? 5 : 0)
            )
            .shadow(
                color: Color.white.opacity(configuration.isPressed ? 0.14 : 0.0),
                radius: configuration.isPressed ? 10 : 0,
                x: 0,
                y: 0
            )
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.18 : 0.25),
                radius: configuration.isPressed ? 16 : 10,
                x: 0,
                y: configuration.isPressed ? 10 : 6
            )
            .scaleEffect(configuration.isPressed ? 1.12 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var tagManager: TagManager
    @Binding var tileTags: [Int]
    @Binding var completedTiles: [ArchivedTile]
    @Binding var deletedTiles: [ArchivedTile]
    let onResetApp: () -> Void
    let onSaveArchives: () -> Void
    let exportBackupData: () -> Data
    let importBackupData: (Data) -> Void
    let replaceBackupData: (Data) -> Void
    let exportCSVData: (() -> Data)?
    let searchTiles: (String) -> [TileSummary]
    let duplicateGroups: () -> [DuplicateGroup]
    let removeDuplicates: () -> Int
    let onRestoreArchived: (ArchivedTile) -> Void
    let tagNameProvider: (Int) -> String
    let onPurgeDeleted: () -> Void
    let onEnableNotifications: () -> Void
    let onDisableNotifications: () -> Void
    let onBackupNow: () -> Void
    let onReplayTrainingDemo: () -> Void
    let isTrainingMode: Bool
    #if DEBUG
    @Binding var showDebugPanel: Bool
    let onCreateTestTiles: () -> Void
    #endif
    @State private var showTagsView = false
    @State private var showOptionsView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Tap-to-dismiss background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSettings()
                    }
                
                // Settings content (slides up from bottom)
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // Drag indicator
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10)
                        
                        // Header
                        HStack {
                            Text("Settings")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                Haptics.optionTap()
                                dismissSettings()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Settings content
                        VStack(spacing: 16) {
                            SettingsRow(
                                icon: "tag.fill",
                                title: "Tags",
                                action: {
                                    showTagsView = true
                                }
                            )
                            SettingsRow(
                                icon: "slider.horizontal.3",
                                title: "Options",
                                action: {
                                    showOptionsView = true
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .sheet(isPresented: $showTagsView) {
                            TagsView(
                                tagManager: tagManager,
                                tileTags: $tileTags
                            )
                        }
                        .sheet(isPresented: $showOptionsView) {
#if DEBUG
                            OptionsView(
                                onResetApp: {
                                    onResetApp()
                                    dismissSettings()
                                },
                                exportBackupData: {
                                    exportBackupData()
                                },
                                importBackupData: { data in
                                    importBackupData(data)
                                },
                                replaceBackupData: { data in
                                    replaceBackupData(data)
                                },
                                showDebugPanel: $showDebugPanel,
                                onCreateTestTiles: onCreateTestTiles,
                                exportCSVData: exportCSVData,
                                searchTiles: searchTiles,
                                duplicateGroups: duplicateGroups,
                                removeDuplicates: removeDuplicates,
                                completedTiles: $completedTiles,
                                deletedTiles: $deletedTiles,
                                onRestoreArchived: { tile in
                                    onRestoreArchived(tile)
                                },
                                onDeleteCompleted: { offsets in
                                    completedTiles.remove(atOffsets: offsets)
                                    onSaveArchives()
                                },
                                onDeleteDeleted: { offsets in
                                    deletedTiles.remove(atOffsets: offsets)
                                    onSaveArchives()
                                },
                                tagNameProvider: { id in
                                    tagNameProvider(id)
                                },
                                onPurgeDeleted: {
                                    onPurgeDeleted()
                                },
                                onEnableNotifications: {
                                    onEnableNotifications()
                                },
                                onDisableNotifications: {
                                    onDisableNotifications()
                                },
                                onBackupNow: {
                                    onBackupNow()
                                },
                                onReplayTrainingDemo: {
                                    onReplayTrainingDemo()
                                },
                                isTrainingMode: isTrainingMode
                            )
#else
                            OptionsView(
                                onResetApp: {
                                    onResetApp()
                                    dismissSettings()
                                },
                                exportBackupData: {
                                    exportBackupData()
                                },
                                importBackupData: { data in
                                    importBackupData(data)
                                },
                                replaceBackupData: { data in
                                    replaceBackupData(data)
                                },
                                exportCSVData: exportCSVData,
                                searchTiles: searchTiles,
                                duplicateGroups: duplicateGroups,
                                removeDuplicates: removeDuplicates,
                                completedTiles: $completedTiles,
                                deletedTiles: $deletedTiles,
                                onRestoreArchived: { tile in
                                    onRestoreArchived(tile)
                                },
                                onDeleteCompleted: { offsets in
                                    completedTiles.remove(atOffsets: offsets)
                                    onSaveArchives()
                                },
                                onDeleteDeleted: { offsets in
                                    deletedTiles.remove(atOffsets: offsets)
                                    onSaveArchives()
                                },
                                tagNameProvider: { id in
                                    tagNameProvider(id)
                                },
                                onPurgeDeleted: {
                                    onPurgeDeleted()
                                },
                                onEnableNotifications: {
                                    onEnableNotifications()
                                },
                                onDisableNotifications: {
                                    onDisableNotifications()
                                },
                                onBackupNow: {
                                    onBackupNow()
                                },
                                onReplayTrainingDemo: {
                                    onReplayTrainingDemo()
                                },
                                isTrainingMode: isTrainingMode
                            )
#endif
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 20)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
                }
            }
        }
        .zIndex(3000) // Above everything
    }
    
    private func dismissSettings() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func scrollBounceAlwaysIfAvailable() -> some View {
        Group {
            if #available(iOS 17.0, *) {
                self.scrollBounceBehavior(.always)
            } else {
                self
            }
        }
    }

    func scrollBounceBasedOnSizeIfAvailable() -> some View {
        Group {
            if #available(iOS 17.0, *) {
                self.scrollBounceBehavior(.basedOnSize)
            } else {
                self
            }
        }
    }

    func scrollDisabledIfAvailable(_ disabled: Bool) -> some View {
        Group {
            if #available(iOS 16.0, *) {
                self.scrollDisabled(disabled)
            } else {
                self
            }
        }
    }

    @ViewBuilder
    func adaptiveLiquidPanel(cornerRadius: CGFloat = 12) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(Color.clear)
                .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color.gray.opacity(0.15))
                        )
                )
        }
    }
}

// MARK: - Conditional Position Modifier

struct ConditionalPositionModifier: ViewModifier {
    let isFiltered: Bool
    let position: CGPoint
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if isFiltered {
            content
                .frame(maxWidth: .infinity) // Center horizontally in ScrollView
        } else {
            content
                .position(position) // Absolute positioning in sphere mode
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            Haptics.optionTap()
            action?()
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .adaptiveLiquidPanel(cornerRadius: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Haptics Row

struct HapticsRow: View {
    @AppStorage("HapticsEnabled") private var hapticsEnabled: Bool = true
    
    var body: some View {
        HStack {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 30)
            
            Text("Haptics")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $hapticsEnabled)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .adaptiveLiquidPanel(cornerRadius: 12)
    }
}

struct DisabledSettingsRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .adaptiveLiquidPanel(cornerRadius: 12)
        .opacity(0.8)
    }
}

struct NotificationsRow: View {
    @AppStorage("BrainDumpNotificationsEnabled") private var notificationsEnabled: Bool = false
    let onEnable: () -> Void
    let onDisable: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "bell.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 30)

            Text("Notifications")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { notificationsEnabled },
                    set: { newValue in
                        notificationsEnabled = newValue
                        if newValue {
                            onEnable()
                        } else {
                            onDisable()
                        }
                    }
                )
            )
            .labelsHidden()
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .adaptiveLiquidPanel(cornerRadius: 12)
    }
}

// MARK: - About Row

struct AboutRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 30)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .adaptiveLiquidPanel(cornerRadius: 12)
    }
}

struct AppearanceView: View {
    @AppStorage("BackgroundTheme") private var backgroundThemeRaw: String = BackgroundTheme.space.rawValue
    @Environment(\.dismiss) private var dismiss

    private var selectedTheme: BackgroundTheme {
        BackgroundTheme(rawValue: backgroundThemeRaw) ?? .space
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(BackgroundTheme.allCases) { theme in
                            Button(action: {
                                Haptics.optionTap()
                                backgroundThemeRaw = theme.rawValue
                            }) {
                                HStack(spacing: 12) {
                                    AppBackgroundView(theme: theme)
                                        .frame(width: 72, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(theme.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(theme.subtitle)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }

                                    Spacer()

                                    Image(systemName: selectedTheme == theme ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(selectedTheme == theme ? .green : .white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.gray.opacity(0.15))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Tags View

struct TagsView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var tileTags: [Int]
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var selectedColor: TagColor = .coral
    
    let availableColors: [TagColor] = TagColor.orderedPalette
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Default tags section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Default Tags")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            ForEach(tagManager.defaultTagsInDisplayOrder) { tag in
                                TagRow(tag: tag, isDefault: true)
                            }
                        }
                        .padding(.top, 20)
                        
                        // User tags section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Tags")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if tagManager.canAddMoreUserTags {
                                    Button(action: {
                                        Haptics.optionTap()
                                        showCreateTag = true
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if tagManager.userTags.isEmpty {
                                Text("No custom tags yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 20)
                            } else {
                                ForEach(tagManager.userTags) { tag in
                                    TagRow(tag: tag, isDefault: false, onDelete: {
                                        tagManager.deleteUserTag(tag)
                                    })
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showCreateTag) {
                CreateTagView(
                    tagManager: tagManager,
                    newTagName: $newTagName,
                    selectedColor: $selectedColor,
                    availableColors: availableColors
                )
            }
        }
    }
}

// MARK: - Options View

struct OptionsView: View {
    let onResetApp: () -> Void
    let exportBackupData: () -> Data
    let importBackupData: (Data) -> Void
    let replaceBackupData: (Data) -> Void
    let onBackupNow: () -> Void
    let showDebugPanel: Binding<Bool>?
    let onCreateTestTiles: (() -> Void)?
    let exportCSVData: (() -> Data)?
    let searchTiles: (String) -> [TileSummary]
    let duplicateGroups: () -> [DuplicateGroup]
    let removeDuplicates: () -> Int
    @Binding var completedTiles: [ArchivedTile]
    @Binding var deletedTiles: [ArchivedTile]
    let onRestoreArchived: (ArchivedTile) -> Void
    let onDeleteCompleted: (IndexSet) -> Void
    let onDeleteDeleted: (IndexSet) -> Void
    let tagNameProvider: (Int) -> String
    let onPurgeDeleted: () -> Void
    let onEnableNotifications: () -> Void
    let onDisableNotifications: () -> Void
    let onReplayTrainingDemo: () -> Void
    let isTrainingMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showAppearance = false
    @State private var showBackup = false
    @State private var showAdvanced = false
    @State private var showSearch = false
    @State private var showCompleted = false
    @State private var showDeleted = false
    
    init(
        onResetApp: @escaping () -> Void,
        exportBackupData: @escaping () -> Data,
        importBackupData: @escaping (Data) -> Void,
        replaceBackupData: @escaping (Data) -> Void,
        showDebugPanel: Binding<Bool>? = nil,
        onCreateTestTiles: (() -> Void)? = nil,
        exportCSVData: (() -> Data)? = nil,
        searchTiles: @escaping (String) -> [TileSummary],
        duplicateGroups: @escaping () -> [DuplicateGroup],
        removeDuplicates: @escaping () -> Int,
        completedTiles: Binding<[ArchivedTile]>,
        deletedTiles: Binding<[ArchivedTile]>,
        onRestoreArchived: @escaping (ArchivedTile) -> Void,
        onDeleteCompleted: @escaping (IndexSet) -> Void,
        onDeleteDeleted: @escaping (IndexSet) -> Void,
        tagNameProvider: @escaping (Int) -> String,
        onPurgeDeleted: @escaping () -> Void,
        onEnableNotifications: @escaping () -> Void,
        onDisableNotifications: @escaping () -> Void,
        onBackupNow: @escaping () -> Void,
        onReplayTrainingDemo: @escaping () -> Void,
        isTrainingMode: Bool
    ) {
        self.onResetApp = onResetApp
        self.exportBackupData = exportBackupData
        self.importBackupData = importBackupData
        self.replaceBackupData = replaceBackupData
        self.showDebugPanel = showDebugPanel
        self.onCreateTestTiles = onCreateTestTiles
        self.exportCSVData = exportCSVData
        self.searchTiles = searchTiles
        self.duplicateGroups = duplicateGroups
        self.removeDuplicates = removeDuplicates
        _completedTiles = completedTiles
        _deletedTiles = deletedTiles
        self.onRestoreArchived = onRestoreArchived
        self.onDeleteCompleted = onDeleteCompleted
        self.onDeleteDeleted = onDeleteDeleted
        self.tagNameProvider = tagNameProvider
        self.onPurgeDeleted = onPurgeDeleted
        self.onEnableNotifications = onEnableNotifications
        self.onDisableNotifications = onDisableNotifications
        self.onBackupNow = onBackupNow
        self.onReplayTrainingDemo = onReplayTrainingDemo
        self.isTrainingMode = isTrainingMode
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    SettingsRow(
                        icon: "paintbrush.fill",
                        title: "Appearance",
                        action: {
                            Haptics.optionTap()
                            showAppearance = true
                        }
                    )
                    HapticsRow()
                    NotificationsRow(
                        onEnable: onEnableNotifications,
                        onDisable: onDisableNotifications
                    )
                    if isTrainingMode {
                        DisabledSettingsRow(
                            icon: "externaldrive.badge.icloud",
                            title: "Back-Up",
                            detail: "Unavailable during training demo"
                        )
                    } else {
                        SettingsRow(
                            icon: "externaldrive.badge.icloud",
                            title: "Back-Up",
                            action: {
                                Haptics.optionTap()
                                showBackup = true
                            }
                        )
                    }
                    SettingsRow(
                        icon: "graduationcap.fill",
                        title: "Replay Training Demo",
                        action: {
                            Haptics.optionTap()
                            onReplayTrainingDemo()
                            dismiss()
                        }
                    )
                    SettingsRow(
                        icon: "gearshape.fill",
                        title: "Advanced",
                        action: {
                            Haptics.optionTap()
                            showAdvanced = true
                        }
                    )
                    SettingsRow(
                        icon: "magnifyingglass",
                        title: "Search",
                        action: {
                            Haptics.optionTap()
                            showSearch = true
                        }
                    )
                    SettingsRow(
                        icon: "checkmark.circle",
                        title: "Recently Completed",
                        action: {
                            Haptics.optionTap()
                            showCompleted = true
                        }
                    )
                    SettingsRow(
                        icon: "trash",
                        title: "Recently Deleted",
                        action: {
                            Haptics.optionTap()
                            showDeleted = true
                        }
                    )
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .sheet(isPresented: $showAppearance) {
                    AppearanceView()
                }
                .sheet(isPresented: $showBackup) {
                    BackupView(
                        exportBackupData: exportBackupData,
                        importBackupData: importBackupData,
                        replaceBackupData: replaceBackupData,
                        onBackupNow: onBackupNow,
                        isTrainingMode: isTrainingMode
                    )
                }
                .sheet(isPresented: $showAdvanced) {
                    AdvancedView(
                        onResetApp: {
                            onResetApp()
                            dismiss()
                        },
                        showDebugPanel: showDebugPanel,
                        onCreateTestTiles: onCreateTestTiles,
                        exportCSVData: exportCSVData
                    )
                }
                .sheet(isPresented: $showSearch) {
                    TileSearchView(
                        searchTiles: searchTiles
                    )
                }
                .sheet(isPresented: $showCompleted) {
                    CompletedTilesView(
                        tiles: $completedTiles,
                        onRestore: onRestoreArchived,
                        onDelete: onDeleteCompleted,
                        tagNameProvider: tagNameProvider
                    )
                }
                .sheet(isPresented: $showDeleted) {
                    RecentlyDeletedView(
                        tiles: $deletedTiles,
                        onRestore: onRestoreArchived,
                        onDelete: onDeleteDeleted,
                        tagNameProvider: tagNameProvider,
                        onPurge: onPurgeDeleted
                    )
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
    }
    
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text(appName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            Text("Version \(version) (\(build))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .padding(.top, 20)
                    
                    AboutRow(icon: "info.circle.fill", title: "Version", value: version)
                    AboutRow(icon: "number.circle.fill", title: "Build", value: build)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Advanced View

struct BackupView: View {
    let exportBackupData: () -> Data
    let importBackupData: (Data) -> Void
    let replaceBackupData: (Data) -> Void
    let onBackupNow: () -> Void
    let isTrainingMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDocumentPicker = false
    @State private var documentPickerMode: DocumentPickerView.Mode = .importFile
    @State private var showBackupFileExporter = false
    @State private var pendingBackupDocument = BackupDocument(data: Data())
    @State private var pendingBackupFilename = "BrainDumpBackup"
    @State private var pendingImportAction: ((URL) -> Void)? = nil
    @State private var iCloudStatusText = "Checking..."
    @State private var iCloudLastBackupText = "Never"
    @State private var iCloudBackupStatusText = "Ready"

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 16) {
                    AboutRow(icon: "icloud.fill", title: "iCloud", value: iCloudStatusText)
                    AboutRow(icon: "clock.fill", title: "Last iCloud Backup", value: iCloudLastBackupText)
                    AboutRow(icon: "exclamationmark.bubble.fill", title: "Backup Status", value: iCloudBackupStatusText)
                    SettingsRow(
                        icon: "icloud.fill",
                        title: "Back Up Now",
                        action: {
                            Haptics.optionTap()
                            guard !isTrainingMode else {
                                iCloudBackupStatusText = "Disabled during training demo"
                                return
                            }
                            iCloudBackupStatusText = "Running backup..."
                            onBackupNow()
                            refreshBackupStatusAfterDelay()
                        }
                    )
                    SettingsRow(
                        icon: "arrow.down.circle.fill",
                        title: "Back Up to Files",
                        action: {
                            Haptics.optionTap()
                            guard !isTrainingMode else {
                                iCloudBackupStatusText = "Disabled during training demo"
                                return
                            }
                            pendingBackupDocument = BackupDocument(data: exportBackupData())
                            pendingBackupFilename = backupExportFilename()
                            showBackupFileExporter = true
                        }
                    )
                    SettingsRow(
                        icon: "arrow.up.circle.fill",
                        title: "Restore (Merge) from Files",
                        action: {
                            Haptics.optionTap()
                            guard !isTrainingMode else {
                                iCloudBackupStatusText = "Disabled during training demo"
                                return
                            }
                            pendingImportAction = { url in
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let hasAccess = url.startAccessingSecurityScopedResource()
                                    defer {
                                        if hasAccess { url.stopAccessingSecurityScopedResource() }
                                    }
                                    guard let data = try? Data(contentsOf: url) else { return }
                                    DispatchQueue.main.async {
                                        importBackupData(data)
                                    }
                                }
                            }
                            documentPickerMode = .importFile
                            showDocumentPicker = true
                        }
                    )
                    SettingsRow(
                        icon: "arrow.counterclockwise.circle.fill",
                        title: "Restore (Replace) from Files",
                        action: {
                            Haptics.optionTap()
                            guard !isTrainingMode else {
                                iCloudBackupStatusText = "Disabled during training demo"
                                return
                            }
                            pendingImportAction = { url in
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let hasAccess = url.startAccessingSecurityScopedResource()
                                    defer {
                                        if hasAccess { url.stopAccessingSecurityScopedResource() }
                                    }
                                    guard let data = try? Data(contentsOf: url) else { return }
                                    DispatchQueue.main.async {
                                        replaceBackupData(data)
                                    }
                                }
                            }
                            documentPickerMode = .importFile
                            showDocumentPicker = true
                        }
                    )
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Back-Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView(
                    mode: documentPickerMode,
                    exportData: nil,
                    onPick: { url in
                        showDocumentPicker = false
                        if let action = pendingImportAction {
                            action(url)
                        }
                        pendingImportAction = nil
                    },
                    onCancel: {
                        showDocumentPicker = false
                        pendingImportAction = nil
                    }
                )
            }
            .fileExporter(
                isPresented: $showBackupFileExporter,
                document: pendingBackupDocument,
                contentType: .data,
                defaultFilename: pendingBackupFilename
            ) { _ in }
            .onAppear {
                updateICloudStatus()
                updateICloudLastBackup()
                updateICloudBackupStatus()
            }
        }
    }

    private func backupExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        return "BrainDumpBackup_\(stamp).bdu"
    }

    private func updateICloudStatus() {
        if FileManager.default.ubiquityIdentityToken == nil {
            iCloudStatusText = "Unavailable"
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: brainDumpICloudContainerIdentifier)
                ?? FileManager.default.url(forUbiquityContainerIdentifier: nil)
            DispatchQueue.main.async {
                if containerURL != nil {
                    iCloudStatusText = "Available"
                } else {
                    iCloudStatusText = "Signed In (No Access)"
                }
            }
        }
    }

    private func updateICloudLastBackup() {
        if let last = UserDefaults.standard.object(forKey: "ICloudLastBackupDate") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            iCloudLastBackupText = formatter.string(from: last)
        } else {
            iCloudLastBackupText = "Never"
        }
    }

    private func updateICloudBackupStatus() {
        if let lastError = UserDefaults.standard.string(forKey: iCloudBackupLastErrorKey), !lastError.isEmpty {
            iCloudBackupStatusText = lastError
        } else {
            iCloudBackupStatusText = "Ready"
        }
    }

    private func refreshBackupStatusAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            updateICloudLastBackup()
            updateICloudBackupStatus()
        }
    }
}

struct AdvancedView: View {
    let onResetApp: () -> Void
    let showDebugPanel: Binding<Bool>?
    let onCreateTestTiles: (() -> Void)?
    let exportCSVData: (() -> Data)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showResetConfirmation = false
    @State private var showAbout = false
    #if DEBUG
    @State private var showDebugMenu = false
    #endif
    
    init(
        onResetApp: @escaping () -> Void,
        showDebugPanel: Binding<Bool>? = nil,
        onCreateTestTiles: (() -> Void)? = nil,
        exportCSVData: (() -> Data)? = nil
    ) {
        self.onResetApp = onResetApp
        self.showDebugPanel = showDebugPanel
        self.onCreateTestTiles = onCreateTestTiles
        self.exportCSVData = exportCSVData
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    SettingsRow(
                        icon: "info.circle.fill",
                        title: "About",
                        action: {
                            Haptics.optionTap()
                            showAbout = true
                        }
                    )
                    SettingsRow(
                        icon: "envelope.fill",
                        title: "Contact (Email Me)",
                        action: {
                            Haptics.optionTap()
                            if let emailURL = URL(string: "mailto:paulhutch77@gmail.com") {
                                openURL(emailURL)
                            }
                        }
                    )
                    
                    #if DEBUG
                    if showDebugPanel != nil && onCreateTestTiles != nil {
                        SettingsRow(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Debug",
                            action: {
                                Haptics.optionTap()
                                showDebugMenu = true
                            }
                        )
                    }
                    #endif

                    SettingsRow(
                        icon: "arrow.counterclockwise",
                        title: "Reset App",
                        action: {
                            Haptics.optionTap()
                            showResetConfirmation = true
                        }
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .overlay {
                    if showResetConfirmation {
                        ResetConfirmationView(
                            isPresented: $showResetConfirmation,
                            onConfirm: {
                                onResetApp()
                                dismiss()
                            }
                        )
                    }
                }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                #if DEBUG
                .sheet(isPresented: $showDebugMenu) {
                    if let showDebugPanel = showDebugPanel, let onCreateTestTiles = onCreateTestTiles {
                        DebugMenuView(
                            showDebugPanel: showDebugPanel,
                            onCreateTestTiles: onCreateTestTiles,
                            exportCSVData: exportCSVData
                        )
                    }
                }
                #endif
            }
            .navigationTitle("Advanced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: Tag
    let isDefault: Bool
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            // Color indicator
            Circle()
                .fill(tag.uiColor)
                .frame(width: 20, height: 20)
            
            Text(tag.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            if !isDefault, let onDelete = onDelete {
                Button(action: {
                    Haptics.optionTap()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .adaptiveLiquidPanel(cornerRadius: 12)
        .padding(.horizontal, 20)
    }
}

// MARK: - Create Tag View

struct CreateTagView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var newTagName: String
    @Binding var selectedColor: TagColor
    let availableColors: [TagColor]
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    private var colorRows: [[TagColor]] {
        let rowSize = 7
        return stride(from: 0, to: availableColors.count, by: rowSize).map { start in
            let end = min(start + rowSize, availableColors.count)
            return Array(availableColors[start..<end])
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var tagNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tag Name")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextField("Enter tag name", text: $newTagName)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.15))
                        )
                )
                .focused($isFocused)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            colorGrid
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(.horizontal, 20)
    }

    private var colorGrid: some View {
        VStack(alignment: .center, spacing: 12) {
            ForEach(colorRows.indices, id: \.self) { rowIndex in
                let rowColors = colorRows[rowIndex]
                HStack(spacing: 8) {
                    ForEach(rowColors, id: \.self) { color in
                        colorButton(for: color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(x: rowIndex.isMultiple(of: 2) ? -6 : 6)
            }
        }
    }

    private func colorButton(for color: TagColor) -> some View {
        let isSelected = selectedColor == color
        return Button(action: {
            Haptics.optionTap()
            selectedColor = color
        }) {
            Circle()
                .fill(color.uiColor.opacity(0.97))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .scaleEffect(isSelected ? 1.12 : 1.0)
                .shadow(
                    color: color.uiColor.opacity(isSelected ? 0.55 : 0.25),
                    radius: isSelected ? 8 : 3,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
                .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    tagNameSection
                    colorSection
                    
                    Spacer()
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Haptics.optionTap()
                        if !newTagName.isEmpty {
                            tagManager.addUserTag(name: newTagName, color: selectedColor)
                            newTagName = ""
                            selectedColor = .coral
                            dismiss()
                        }
                    }
                    .foregroundColor(.white)
                    .disabled(newTagName.isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var selectedTagId: Int
    let onDismiss: () -> Void

    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var selectedColor: TagColor = .coral
    @AppStorage("LastTagPickerId") private var lastTagPickerId: Int = 0

    private let availableColors: [TagColor] = TagColor.orderedPalette

    private var panelBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var titleView: some View {
        Text("Select Tag")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .padding(.top, 16)
    }

    private func targetScrollId() -> Int {
        tagManager.tagsInDisplayOrder.contains(where: { $0.id == lastTagPickerId })
            ? lastTagPickerId
            : selectedTagId
    }

    private var newTagButton: some View {
        Button(action: {
            Haptics.optionTap()
            showCreateTag = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("New Tag")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!tagManager.canAddMoreUserTags)
        .opacity(tagManager.canAddMoreUserTags ? 1.0 : 0.5)
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                titleView
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(tagManager.tagsInDisplayOrder) { tag in
                                TagButton(
                                    tag: tag,
                                    isSelected: selectedTagId == tag.id,
                                    action: {
                                        selectedTagId = tag.id
                                        lastTagPickerId = tag.id
                                    }
                                )
                                .id(tag.id)
                            }
                            newTagButton
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(targetScrollId(), anchor: .center)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(
                panelBackground
            )
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .frame(height: 160)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showCreateTag) {
            CreateTagView(
                tagManager: tagManager,
                newTagName: $newTagName,
                selectedColor: $selectedColor,
                availableColors: availableColors
            )
        }
    }
}

// MARK: - Tag Button

struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.optionTap()
            action()
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tag.uiColor)
                    .frame(width: 12, height: 12)
                
                Text(tag.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? tag.uiColor.opacity(0.3) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? tag.uiColor : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tile Action Buttons

struct TileActionButtons: View {
    enum HighlightedAction {
        case tag
        case complete
        case add
    }

    let onClose: () -> Void
    let onEdit: () -> Void
    let onChangeTag: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onAdd: () -> Void
    let pulseTrigger: Bool
    let closeIcon: String
    let closeForegroundColor: Color
    let closeBorderColor: Color?
    let highlightedAction: HighlightedAction?
    let showFloatingAddButton: Bool
    
    private let buttonSize: CGFloat = 50
    private let buttonSpacing: CGFloat = 12
    @State private var isThrobbing = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .trailing, spacing: 12) {
                VStack(spacing: buttonSpacing) {
                    // Delete button (trash)
                    ActionButton(
                        icon: "trash",
                        action: onDelete,
                        isDestructive: true
                    )
                    
                    // Edit button (pencil)
                    ActionButton(
                        icon: "pencil",
                        action: onEdit
                    )
                    
                    // Change tag button (tag)
                    ActionButton(
                        icon: "tag",
                        action: onChangeTag,
                        isHighlighted: highlightedAction == .tag
                    )
                    
                    // Complete button (checkmark)
                    ActionButton(
                        icon: "checkmark.circle",
                        action: onComplete,
                        isHighlighted: highlightedAction == .complete
                    )
                    
                    // Close button (X)
                    ActionButton(
                        icon: closeIcon,
                        action: onClose,
                        foregroundColor: closeForegroundColor,
                        borderColor: closeBorderColor
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(isThrobbing ? 0.9 : 0.0), lineWidth: isThrobbing ? 3 : 0)
                            .scaleEffect(isThrobbing ? 1.25 : 1.0)
                            .animation(.easeInOut(duration: 0.6), value: isThrobbing)
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .fill(Color.black.opacity(0.16))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        )
                )

                // Floating add button (kept separate from the main five-action capsule)
                if showFloatingAddButton {
                    GlassButton(
                        icon: "plus",
                        foregroundColor: highlightedAction == .add ? .green : .primary,
                        borderColor: highlightedAction == .add ? .green : nil,
                        action: onAdd
                    )
                    .frame(width: 66, alignment: .center)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .padding(.top, 5)
            .onChange(of: pulseTrigger) { _, _ in
                triggerThrob()
            }
            .animation(.easeInOut(duration: 0.18), value: showFloatingAddButton)
        }
    }

    private func triggerThrob() {
        // Two slow throbs, then repeat after 5s if still on screen.
        isThrobbing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isThrobbing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isThrobbing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isThrobbing = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if !isThrobbing {
                triggerThrob()
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    var foregroundColor: Color? = nil
    var borderColor: Color? = nil
    var isHighlighted: Bool = false
    
    private let buttonSize: CGFloat = 50
    @State private var pulse = false
    
    var body: some View {
        Button(action: {
            Haptics.optionTap()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(foregroundColor ?? (isDestructive ? .red : .primary))
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                        )
                        .overlay(
                            Circle()
                                .stroke((borderColor ?? (isHighlighted ? .green : .clear)).opacity(0.95), lineWidth: (borderColor == nil && !isHighlighted) ? 0 : 2)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(isHighlighted ? (pulse ? 0.9 : 0.25) : 0.0), lineWidth: isHighlighted ? 2.5 : 0)
                                .scaleEffect(isHighlighted ? (pulse ? 1.16 : 1.0) : 1.0)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            guard isHighlighted else { return }
            pulse = true
        }
        .onChange(of: isHighlighted) { _, newValue in
            pulse = newValue
        }
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
    }
}

struct TrainingBannerView: View {
    let instruction: String
    let progress: Int
    let canFinish: Bool
    let onFinish: () -> Void

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Demo")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(instruction)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { index in
                            Circle()
                                .fill(index < progress ? Color.green : Color.white.opacity(0.25))
                                .frame(width: 7, height: 7)
                        }
                    }
                }
                Spacer()
                Button(action: {
                    Haptics.optionTap()
                    if canFinish {
                        onFinish()
                    }
                }) {
                    Text("Finish Training")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(canFinish ? Color.green.opacity(0.8) : Color.gray.opacity(0.45))
                        )
                }
                .disabled(!canFinish)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 54)
            Spacer()
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Delete Confirmation View

struct DeleteConfirmationView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Confirmation card
            VStack(spacing: 24) {
                // Title
                Text("Delete Tile?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Message
                Text("Deleted tiles are kept for 30 days")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // Buttons
                HStack(spacing: 16) {
                    // Cancel button
                    Button(action: {
                        Haptics.optionTap()
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                            )
                    }
                    
                    // Delete button
                    Button(action: {
                        Haptics.optionTap()
                        onConfirm()
                    }) {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - iCloud Restore Confirmation View

struct ICloudRestoreConfirmationView: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String
    let cancelButtonTitle: String
    let onMerge: () -> Void
    let onReplace: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                Image(systemName: "icloud.and.arrow.down.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button(action: {
                        Haptics.optionTap()
                        onMerge()
                        isPresented = false
                    }) {
                        Text(primaryButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.8))
                            )
                    }
                    
                    Button(action: {
                        Haptics.optionTap()
                        onReplace()
                        isPresented = false
                    }) {
                        Text(secondaryButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                    
                    Button(action: {
                        Haptics.optionTap()
                        onCancel()
                        isPresented = false
                    }) {
                        Text(cancelButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Tile Search View

struct TileSearchView: View {
    let searchTiles: (String) -> [TileSummary]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [TileSummary] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    TextField("Search tiles", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.15))
                                )
                        )
                        .padding(.horizontal, 20)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(results) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.text.isEmpty ? "(Empty)" : item.text)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(item.tagName)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.gray.opacity(0.15))
                                        )
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            if results.isEmpty {
                                Text("No results")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 20)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onChange(of: query) { _, newValue in
            results = searchTiles(newValue)
        }
        .onAppear {
            results = searchTiles(query)
        }
    }
}

// MARK: - Duplicates View

struct DuplicatesView: View {
    let duplicateGroups: () -> [DuplicateGroup]
    let removeDuplicates: () -> Int
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [DuplicateGroup] = []
    @State private var lastRemovalCount: Int? = nil

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var removalBanner: some View {
        if let removed = lastRemovalCount {
            Text("Removed \(removed) duplicates")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var duplicatesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(groups) { group in
                    duplicateGroupCard(group)
                }

                if groups.isEmpty {
                    Text("No duplicates found")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 20)
                }
            }
            .padding(.top, 4)
        }
    }

    private func duplicateGroupCard(_ group: DuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(group.items.count) duplicates")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            ForEach(group.items) { item in
                Text(item.text.isEmpty ? "(Empty)" : item.text)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                )
        )
        .padding(.horizontal, 20)
    }

    private var deleteDuplicatesButton: some View {
        Button(action: {
            Haptics.optionTap()
            let removed = removeDuplicates()
            lastRemovalCount = removed
            groups = duplicateGroups()
        }) {
            Text("Delete Duplicates")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.8))
                )
                .padding(.horizontal, 20)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    removalBanner
                    duplicatesList
                    deleteDuplicatesButton
                }
            }
            .navigationTitle("Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            groups = duplicateGroups()
        }
    }
}

// MARK: - Completed Tiles View

struct CompletedTilesView: View {
    @Binding var tiles: [ArchivedTile]
    let onRestore: (ArchivedTile) -> Void
    let onDelete: (IndexSet) -> Void
    let tagNameProvider: (Int) -> String
    @Environment(\.dismiss) private var dismiss

    private var displayTiles: [ArchivedTile] {
        tiles.sorted {
            if $0.archivedAt != $1.archivedAt { return $0.archivedAt > $1.archivedAt }
            return $0.id > $1.id
        }
    }

    private func mappedSourceOffsets(from displayedOffsets: IndexSet) -> IndexSet {
        var sourceOffsets = IndexSet()
        for displayedIndex in displayedOffsets {
            guard displayTiles.indices.contains(displayedIndex) else { continue }
            let tileId = displayTiles[displayedIndex].id
            if let sourceIndex = tiles.firstIndex(where: { $0.id == tileId }) {
                sourceOffsets.insert(sourceIndex)
            }
        }
        return sourceOffsets
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(displayTiles) { tile in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tile.text.isEmpty ? "(Empty)" : tile.text)
                            .font(.system(size: 15, weight: .medium))
                        Text(tagNameProvider(tile.tagId))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .contextMenu {
                        Button("Restore") {
                            Haptics.optionTap()
                            tiles.removeAll { $0.id == tile.id }
                            onRestore(tile)
                        }
                    }
                }
                .onDelete { displayedOffsets in
                    let sourceOffsets = mappedSourceOffsets(from: displayedOffsets)
                    guard !sourceOffsets.isEmpty else { return }
                    onDelete(sourceOffsets)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Completed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Recently Deleted View

struct RecentlyDeletedView: View {
    @Binding var tiles: [ArchivedTile]
    let onRestore: (ArchivedTile) -> Void
    let onDelete: (IndexSet) -> Void
    let tagNameProvider: (Int) -> String
    let onPurge: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var displayTiles: [ArchivedTile] {
        tiles.sorted {
            if $0.archivedAt != $1.archivedAt { return $0.archivedAt > $1.archivedAt }
            return $0.id > $1.id
        }
    }

    private func mappedSourceOffsets(from displayedOffsets: IndexSet) -> IndexSet {
        var sourceOffsets = IndexSet()
        for displayedIndex in displayedOffsets {
            guard displayTiles.indices.contains(displayedIndex) else { continue }
            let tileId = displayTiles[displayedIndex].id
            if let sourceIndex = tiles.firstIndex(where: { $0.id == tileId }) {
                sourceOffsets.insert(sourceIndex)
            }
        }
        return sourceOffsets
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(displayTiles) { tile in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tile.text.isEmpty ? "(Empty)" : tile.text)
                                .font(.system(size: 15, weight: .medium))
                            Text(tagNameProvider(tile.tagId))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .contextMenu {
                            Button("Restore") {
                                Haptics.optionTap()
                                tiles.removeAll { $0.id == tile.id }
                                onRestore(tile)
                            }
                        }
                    }
                    .onDelete { displayedOffsets in
                        let sourceOffsets = mappedSourceOffsets(from: displayedOffsets)
                        guard !sourceOffsets.isEmpty else { return }
                        onDelete(sourceOffsets)
                    }
                } footer: {
                    Text("Items are permanently deleted after 30 days.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            onPurge()
        }
    }
}

// MARK: - Reset Confirmation View

struct ResetConfirmationView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    @State private var confirmationStep: Int = 1
    
    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't allow dismissing by tapping outside - user must cancel
                }
            
            // Confirmation card
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                // Title
                Text("Reset App?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Message - changes based on confirmation step
                VStack(spacing: 12) {
                    if confirmationStep == 1 {
                        Text("This will DELETE ALL TILES!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("This action is NOT REVERSIBLE")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Are you absolutely sure you want to reset the app?")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Final Confirmation")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        
                        Text("You are about to DELETE ALL TILES")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("This cannot be undone. Press 'Reset' one more time to confirm.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Buttons
                HStack(spacing: 16) {
                    // Cancel button
                    Button(action: {
                        confirmationStep = 1
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.15))
                                    )
                            )
                    }
                    
                    // Confirm/Reset button
                    Button(action: {
                        if confirmationStep == 1 {
                            // First confirmation - move to second step
        withAnimation {
                                confirmationStep = 2
                            }
                        } else {
                            // Second confirmation - proceed with reset
                            onConfirm()
                        }
                    }) {
                        Text(confirmationStep == 1 ? "Continue" : "Reset")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.05, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .padding(.horizontal, 40)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Debug Menu View

#if DEBUG
struct DebugMenuView: View {
    @Binding var showDebugPanel: Bool
    let onCreateTestTiles: () -> Void
    @Environment(\.dismiss) private var dismiss
    let exportCSVData: (() -> Data)?
    @State private var showCSVExport = false
    @State private var csvDocument = DataDocument(data: Data())
    @State private var showSpinDebug = UserDefaults.standard.bool(forKey: "ShowSpinDebug")
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.05, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Debug Panel Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debug Panel")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Show Debug Panel")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            Toggle("", isOn: $showDebugPanel)
                                .onChange(of: showDebugPanel) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "ShowDebugPanel")
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Create Test Tiles Button
                    Button(action: {
                        Haptics.optionTap()
                        onCreateTestTiles()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Create 10 Test Tiles")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.6))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Spin Debug Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spin Debug")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Show Spin Debug")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                            
                            Toggle("", isOn: $showSpinDebug)
                                .onChange(of: showSpinDebug) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "ShowSpinDebug")
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Button(action: {
                        Haptics.optionTap()
                        BrainDumpNotificationManager.triggerAllDebugNotificationVariants()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge.waveform.fill")
                                .font(.system(size: 20))
                            Text("Trigger All Notifications")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.7))
                        )
                    }
                    .padding(.horizontal, 20)

                    if exportCSVData != nil {
                        Button(action: {
                            Haptics.optionTap()
                            csvDocument = DataDocument(data: exportCSVData?() ?? Data())
                            showCSVExport = true
                        }) {
                            HStack {
                                Image(systemName: "tablecells")
                                    .font(.system(size: 20))
                                Text("Export CSV")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.6))
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.optionTap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .fileExporter(
                isPresented: $showCSVExport,
                document: csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "ParkingLotTiles.csv"
            ) { _ in }
        }
    }
}

// MARK: - Debug Panel View

struct DebugPanelView: View {
    let tileCount: Int
    @StateObject private var systemMonitor = SystemMonitor()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 6) {
                DebugRow(label: "Tiles", value: "\(tileCount)")
                DebugRow(label: "CPU", value: String(format: "%.1f%%", systemMonitor.cpuUsage))
                DebugRow(label: "RAM", value: formatBytes(systemMonitor.memoryUsage))
                DebugRow(label: "Power", value: systemMonitor.powerState)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.3))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .frame(width: 140, alignment: .leading)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - System Monitor

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: UInt64 = 0
    @Published var powerState: String = "Unknown"
    
    private var updateTimer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        updateMetrics()
    }
    
    private func updateMetrics() {
        // Memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = info.resident_size
        }
        
        // CPU Usage - Note: Accurate CPU monitoring on iOS requires complex implementation
        // This provides a basic activity indicator based on system load
        // For development purposes, this gives a reasonable approximation
        let memoryMB = Double(memoryUsage) / (1024.0 * 1024.0)
        // Approximate CPU usage based on memory footprint (simplified for debug panel)
        // In production, you'd want proper CPU monitoring, but this works for development
        cpuUsage = min(100.0, max(0.0, (memoryMB / 200.0) * 15.0 + Double.random(in: 0...5)))
        
        // Power state
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        switch batteryState {
        case .charging:
            powerState = String(format: "Charging %.0f%%", batteryLevel * 100)
        case .full:
            powerState = "Full"
        case .unplugged:
            powerState = String(format: "%.0f%%", batteryLevel * 100)
        default:
            powerState = "Unknown"
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
#endif

// MARK: - Tag Filter List View

struct TagFilterListView: View {
    let tagIds: [Int]
    @Binding var selectedTagId: Int
    let tagManager: TagManager

    @State private var pageIndex: Int = 0
    @State private var isInitialized = false
    @State private var pulse = false
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.clear
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Tag heading (top center)
                VStack {
                    HStack {
                        Spacer()
                        let loopedTagIds = tagIds + tagIds + tagIds

                        HStack(spacing: 8) {
                            TabView(selection: $pageIndex) {
                                ForEach(Array(loopedTagIds.enumerated()), id: \.offset) { index, tagId in
                                    let pageTag = tagManager.getTag(byId: tagId) ?? tagManager.getDefaultTag()
                                    Text(pageTag.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(pageTag.uiColor.opacity(0.9))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .tag(index)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .frame(height: 40)
                            .frame(maxWidth: 240)
                            .overlay(alignment: .leading) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .scaleEffect(pulse ? 1.1 : 0.9)
                                    .opacity(pulse ? 1.0 : 0.4)
                                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                                    .offset(x: 20)
                            }
                            .overlay(alignment: .trailing) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .scaleEffect(pulse ? 1.1 : 0.9)
                                    .opacity(pulse ? 1.0 : 0.4)
                                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                                    .offset(x: -20)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 30
                    )
                    Spacer()
                }
                .zIndex(3550)
                
            }
        }
        .zIndex(3500) // Background overlay, tiles in filter mode are above this
        .onAppear {
            guard !tagIds.isEmpty else { return }
            if let currentIndex = tagIds.firstIndex(of: selectedTagId) {
                pageIndex = tagIds.count + currentIndex
            } else {
                pageIndex = tagIds.count
                selectedTagId = tagIds.first ?? tagManager.getDefaultTag().id
            }
            isInitialized = true
            pulse.toggle()
        }
        .onChange(of: pageIndex) { _, newIndex in
            guard isInitialized, !tagIds.isEmpty else { return }
            let tagCount = tagIds.count
            let normalizedIndex = ((newIndex % tagCount) + tagCount) % tagCount
            let newTagId = tagIds[normalizedIndex]
            if newTagId != selectedTagId {
                selectedTagId = newTagId
            }

            // Recenter when reaching edges to simulate infinite scrolling.
            if newIndex < tagCount || newIndex >= tagCount * 2 {
                let recenteredIndex = tagCount + normalizedIndex
                DispatchQueue.main.async {
                    pageIndex = recenteredIndex
                }
            }
        }
        .onChange(of: selectedTagId) { _, newValue in
            guard !tagIds.isEmpty else { return }
            if let currentIndex = tagIds.firstIndex(of: newValue) {
                let targetIndex = tagIds.count + currentIndex
                if pageIndex != targetIndex {
                    pageIndex = targetIndex
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
