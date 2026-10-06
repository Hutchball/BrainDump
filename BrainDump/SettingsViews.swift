import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

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
    @State private var showTileAppearance = false

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
                        SettingsRow(icon: "paintpalette.fill", title: "Tile and border colours", action: { showTileAppearance = true })
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
            .sheet(isPresented: $showTileAppearance) { TileAppearanceSettings(store: .shared) }
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
                    SyncSettingsView()
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: isThrobbing)
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
            .task(id: "\(pulseTrigger)-\(scenePhase == .active)-\(reduceMotion)") {
                isThrobbing = false
                guard scenePhase == .active, !reduceMotion else { return }
                do {
                    // Two finite reminders; cancellation follows the view lifecycle and task identity.
                    for _ in 0..<2 {
                        isThrobbing = true
                        try await Task.sleep(for: .milliseconds(600))
                        isThrobbing = false
                        try await Task.sleep(for: .milliseconds(600))
                    }
                } catch { isThrobbing = false }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showFloatingAddButton)
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


    private var actionLabel: String {
        switch icon {
        case "trash": return "Delete thought"
        case "pencil": return "Edit thought"
        case "tag": return "Change category"
        case "checkmark.circle": return "Complete thought"
        case "checkmark": return "Save thought"
        case "xmark": return "Close thought"
        case "plus": return "Add thought"
        default: return "Thought action"
        }
    }

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
                                .stroke(Color.green.opacity(isHighlighted ? 0.65 : 0.0), lineWidth: isHighlighted ? 2.5 : 0)
                                .scaleEffect(isHighlighted ? 1.0 : 1.0)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(actionLabel)

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
