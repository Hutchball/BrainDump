import SwiftUI
import StoreKit
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
    let onOpenSearchTile: (String) -> Void
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
    @State private var showCategoriesView = false
    @State private var showOptionsView = false

    @State private var showPro = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showCategoriesView = true } label: { Label("Categories", systemImage: "tag.fill").labelStyle(SettingsLabelStyle()) }
                    Button { showOptionsView = true } label: { Label("Options", systemImage: "slider.horizontal.3").labelStyle(SettingsLabelStyle()) }
                }
                Section {
                    Button { showPro = true } label: {
                        Label("Meet BrainDump Pro", systemImage: "sparkles").labelStyle(SettingsLabelStyle())
                    }
                }
                Section {
                    Button { showAbout = true } label: { Label("About & Privacy", systemImage: "info.circle").labelStyle(SettingsLabelStyle()) }
                    Link(destination: URL(string: "mailto:braindumpfeedback@cakesquared.co.uk")!) {
                        Label("Send Feedback", systemImage: "envelope").labelStyle(SettingsLabelStyle())
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismissSettings).accessibilityIdentifier("settings-done")
                }
            }
                        .sheet(isPresented: $showCategoriesView) {
                            CategoriesView(
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
                                onOpenSearchTile: onOpenSearchTile,
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
                                onOpenSearchTile: onOpenSearchTile,
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
            .sheet(isPresented: $showPro) { ProPurchaseView() }
            .sheet(isPresented: $showAbout) { AboutView() }
        }
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
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
                .background(Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

/// Keep settings symbols neutral even inside tinted buttons and toggles.
struct SettingsLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon.foregroundStyle(Color.secondary)
            configuration.title.foregroundStyle(Color.primary)
        }
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
                    .foregroundStyle(Color.secondary)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondary)
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
                .foregroundStyle(Color.secondary)
                .frame(width: 30)

            Text("Haptics")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)

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
                .foregroundStyle(Color.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.secondary)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
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
                .foregroundStyle(Color.secondary)
                .frame(width: 30)

            Text("Notifications")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)

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
                .foregroundStyle(Color.secondary)
                .frame(width: 30)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .adaptiveLiquidPanel(cornerRadius: 12)
    }
}

struct AppearanceView: View {
    @AppStorage("SphereEdgeBlurEnabled") private var sphereEdgeBlurEnabled = true
    @AppStorage("TileLightingEnabled") private var tileLightingEnabled = true
    @AppStorage("TileSheenEnabled") private var tileSheenEnabled = true
    @AppStorage("BackgroundTheme") private var backgroundThemeRaw: String = BackgroundTheme.space.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var showTileAppearance = false

    private var selectedTheme: BackgroundTheme {
        BackgroundTheme(rawValue: backgroundThemeRaw) ?? .space
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
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
                                            .foregroundStyle(.primary)
                                        Text(theme.subtitle)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedTheme == theme ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(selectedTheme == theme ? .green : .secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .adaptiveLiquidPanel(cornerRadius: 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        SettingsRow(icon: "paintpalette.fill", title: "Tile and border colours", action: { showTileAppearance = true })
                        Toggle(isOn: $sphereEdgeBlurEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sphere edge blur").font(.headline)
                                Text("Gently softens the sphere’s outer edge as you resize it.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("sphere-edge-blur-toggle")
                        .foregroundStyle(.primary)
                        .tint(.green)
                        .padding(16)
                        .adaptiveLiquidPanel(cornerRadius: 12)
                        Toggle(isOn: $tileSheenEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tile sheen & gradient").font(.headline)
                                Text("A subtle, static highlight on tiles.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("tile-sheen-toggle")
                        .foregroundStyle(.primary)
                        .tint(.green)
                        .padding(16)
                        .adaptiveLiquidPanel(cornerRadius: 12)
                        Toggle(isOn: $tileLightingEnabled) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Top-right lighting").font(.headline)
                                Text("Soft light from just above the screen.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("tile-lighting-toggle")
                        .foregroundStyle(.primary)
                        .tint(.green)
                        .padding(16)
                        .adaptiveLiquidPanel(cornerRadius: 12)
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
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}

// MARK: - Categories View

struct CategoriesView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var tileTags: [Int]
    @Environment(\.dismiss) private var dismiss
    @State private var categoryEditMode: EditMode = .inactive
    @State private var confirmReset = false
    @State private var renaming: Tag?
    @State private var categoryName = ""
    @State private var pendingDeletion: Tag?
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var selectedColor: TagColor = .coral

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tagManager.tagsInDisplayOrder.filter(\.isDefault)) { tag in
                        editableCategoryRow(tag)
                            .moveDisabled(!categoryEditMode.isEditing)
                    }
                    .onMove { source, destination in
                        tagManager.moveCategories(from: source, to: destination, defaults: true)
                    }
                    Button("Reset to Default") { confirmReset = true }
                        .buttonStyle(.borderless)
                } header: {
                    Text("Default Categories")
                } footer: {
                    Text("Restores default category names, colours and order. Your thoughts and custom categories are kept.")
                }
                Section {
                    ForEach(tagManager.tagsInDisplayOrder.filter { !$0.isDefault }) { tag in
                        editableCategoryRow(tag)
                            .moveDisabled(!categoryEditMode.isEditing)
                    }
                    .onMove { source, destination in
                        tagManager.moveCategories(from: source, to: destination, defaults: false)
                    }
                    if tagManager.canAddMoreUserTags {
                        Button { showCreateTag = true } label: {
                            Label("New category", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Your Categories")
                } footer: {
                    Text("Tap Edit to rename categories, delete custom categories, or drag the reorder handles within each section.")
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $categoryEditMode)
            .alert("Delete category?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { tag in
                Button("Delete", role: .destructive) {
                    tagManager.deleteUserTag(tag)
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { tag in
                Text("Are you sure you want to delete \(tag.name)? Its tiles will move to Unsorted.")
            }
            .alert("Rename category", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Category name", text: $categoryName)
                Button("Save") {
                    if let renaming { tagManager.rename(renaming, to: categoryName) }
                    renaming = nil
                }.disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) { renaming = nil }
            }
            .alert("Reset default categories?", isPresented: $confirmReset) {
                Button("Reset to Default", role: .destructive) { tagManager.resetDefaultCategories() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Default names, colours and order will be restored. Your thoughts and custom categories will be kept.")
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(categoryEditMode.isEditing ? "Finish Editing" : "Edit") {
                        categoryEditMode = categoryEditMode.isEditing ? .inactive : .active
                    }
                    .accessibilityIdentifier("categories-edit-toggle")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showCreateTag) {
                CreateCategoryView(tagManager: tagManager, newTagName: $newTagName,
                                   selectedColor: $selectedColor, availableColors: TagColor.orderedPalette)
            }
            .alert("Category could not be saved", isPresented: Binding(
                get: { !showCreateTag && tagManager.saveError != nil }, set: { if !$0 { tagManager.saveError = nil } })) {
                Button("OK") { tagManager.saveError = nil }
            } message: { Text(tagManager.saveError ?? "Please try again.") }
        }
    }
    private func editableCategoryRow(_ tag: Tag) -> some View {
        HStack(spacing: 8) {
            categoryButton(tag)
            if categoryEditMode.isEditing && !tag.isDefault {
                Button(role: .destructive) { pendingDeletion = tag } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete category \(tag.name)")
                .accessibilityIdentifier("category-delete-\(tag.id)")
            }
        }
        .accessibilityAction(named: "Move up") {
            if categoryEditMode.isEditing { moveCategory(tag, by: -1) }
        }
        .accessibilityAction(named: "Move down") {
            if categoryEditMode.isEditing { moveCategory(tag, by: 1) }
        }
    }

    private func moveCategory(_ tag: Tag, by offset: Int) {
        let group = tagManager.tagsInDisplayOrder.filter { $0.isDefault == tag.isDefault }
        guard let from = group.firstIndex(where: { $0.id == tag.id }) else { return }
        let to = from + offset
        guard group.indices.contains(to) else { return }
        tagManager.moveCategories(from: IndexSet(integer: from), to: to > from ? to + 1 : to, defaults: tag.isDefault)
    }

    private func categoryButton(_ tag: Tag) -> some View {
        CategoryRow(tag: tag, isDefault: tag.isDefault)
            .contentShape(Rectangle())
            .onTapGesture {
                guard categoryEditMode.isEditing else { return }
                renaming = tag
                categoryName = tag.name
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("category-row-\(tag.id)")
            .accessibilityHint(categoryEditMode.isEditing ? "Tap to rename" : "Tap Edit to rename or reorder categories")
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
    let onOpenSearchTile: (String) -> Void
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
    @State private var showAdvanced = false
    @State private var showAbout = false
    @AppStorage("HapticsEnabled") private var hapticsEnabled = true
    @AppStorage("BrainDumpNotificationsEnabled") private var notificationsEnabled = false
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
        onOpenSearchTile: @escaping (String) -> Void,
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
        self.onOpenSearchTile = onOpenSearchTile
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

    private func optionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.optionTap()
            action()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .labelStyle(SettingsLabelStyle())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
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

                List {
                    Section {
                        optionButton("Search", icon: "magnifyingglass") { showSearch = true }
                        optionButton("Recently Completed", icon: "checkmark.circle") { showCompleted = true }
                        optionButton("Recently Deleted", icon: "trash") { showDeleted = true }
                    }
                    Section {
                        optionButton("Appearance", icon: "paintbrush.fill") { showAppearance = true }
                        Toggle(isOn: $hapticsEnabled) {
                            Label {
                                Text("Haptics").foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "hand.tap.fill").foregroundStyle(Color.secondary)
                            }
                        }
                        Toggle(isOn: Binding(
                            get: { notificationsEnabled },
                            set: { enabled in
                                notificationsEnabled = enabled
                                if enabled { onEnableNotifications() } else { onDisableNotifications() }
                            }
                        )) {
                            Label {
                                Text("Notifications").foregroundStyle(Color.primary)
                            } icon: {
                                Image(systemName: "bell.fill").foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    Section {
                        optionButton("Advanced", icon: "gearshape.fill") { showAdvanced = true }
                        optionButton("About", icon: "info.circle.fill") { showAbout = true }
                    }
                }
                .listStyle(.insetGrouped)
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showAppearance) {
                    AppearanceView()
                }
                .sheet(isPresented: $showAdvanced) {
                    AdvancedView(
                        onResetApp: {
                            onResetApp()
                            dismiss()
                        },
                        onReplayTrainingDemo: {
                            onReplayTrainingDemo()
                            dismiss()
                        },
                        isTrainingMode: isTrainingMode,
                        showDebugPanel: showDebugPanel,
                        onCreateTestTiles: onCreateTestTiles,
                        exportCSVData: exportCSVData
                    )
                }
                .sheet(isPresented: $showSearch) {
                    TileSearchView(
                        searchTiles: searchTiles,
                        onOpenSearchTile: onOpenSearchTile
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
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unavailable" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unavailable" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) {
                            Text("BrainDump").font(.title2.bold()).fixedSize()
                            Text("Capture now. Sort later.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BrainDump").font(.title2.bold())
                            Text("Capture now. Sort later.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Link("Privacy Policy", destination: URL(string: "https://cakesquared.co.uk/privacy-policy.html")!)

                    Link("CakeSquared Website", destination: URL(string: "https://cakesquared.co.uk")!)
                    Link(destination: URL(string: "mailto:braindumpfeedback@cakesquared.co.uk")!) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    NavigationLink("How BrainDump handles your data") { BrainDumpPrivacyView() }
                }
                Section {
                    LabeledContent("Version", value: version)
                        .accessibilityIdentifier("about-version")
                    LabeledContent("Build", value: build)
                        .accessibilityIdentifier("about-build")
                    Text("© \(Calendar.current.component(.year, from: Date()).formatted(.number.grouping(.never))) BrainDump")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("About & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct BrainDumpPrivacyView: View {
    var body: some View {
        Form {
            Section("Your thoughts") {
                Text("BrainDump stores thoughts and attachments on your device. Its iCloud sync uses your private CloudKit database to synchronise supported data between your devices.")
            }
            Section("Photos and shared content") {
                Text("You choose which photos, screenshots, links and text to add. Photos are not imported automatically. Imported images are processed to remove metadata.")
            }
            Section("Backups and exports") {
                Text("Exported backups can contain your thoughts and attachments. You choose where to save or share them.")
            }
            Section("Notifications") {
                Text("Nightly reminders require your permission and can be turned off in Settings.")
            }
            Section("Privacy Policy") {
                Link("Read the Privacy Policy", destination: URL(string: "https://cakesquared.co.uk/privacy-policy.html")!)
            }
            Section("Contact") {
                Link("braindumpfeedback@cakesquared.co.uk", destination: URL(string: "mailto:braindumpfeedback@cakesquared.co.uk")!)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Advanced View

struct AdvancedView: View {
    let onResetApp: () -> Void
    let onReplayTrainingDemo: () -> Void
    let isTrainingMode: Bool
    let showDebugPanel: Binding<Bool>?
    let onCreateTestTiles: (() -> Void)?
    let exportCSVData: (() -> Data)?
    @Environment(\.dismiss) private var dismiss
    @State private var showBackup = false
    @State private var showResetConfirmation = false
    #if DEBUG
    @State private var showDebugMenu = false
    #endif

    init(
        onResetApp: @escaping () -> Void,
        onReplayTrainingDemo: @escaping () -> Void,
        isTrainingMode: Bool,
        showDebugPanel: Binding<Bool>? = nil,
        onCreateTestTiles: (() -> Void)? = nil,
        exportCSVData: (() -> Data)? = nil
    ) {
        self.onResetApp = onResetApp
        self.onReplayTrainingDemo = onReplayTrainingDemo
        self.isTrainingMode = isTrainingMode
        self.showDebugPanel = showDebugPanel
        self.onCreateTestTiles = onCreateTestTiles
        self.exportCSVData = exportCSVData
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    if isTrainingMode {
                        DisabledSettingsRow(icon: "externaldrive.badge.icloud", title: "Back-Up", detail: "Unavailable during training demo")
                    } else {
                        SettingsRow(icon: "externaldrive.badge.icloud", title: "Back-Up", action: { showBackup = true })
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
                .sheet(isPresented: $showBackup) {
                    SyncSettingsView()
                }
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
                }
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let tag: Tag
    let isDefault: Bool
    @ObservedObject private var store = ThoughtStore.shared
    @AppStorage("DefaultTileFillHex") private var defaultFill = "E9E3FF"
    @AppStorage("DefaultTileBorderHex") private var defaultBorder = "3C315C"

    var body: some View {
        let category = store.tags.first { $0.id == tag.id }
        HStack(spacing: 14) {
            Circle()
                .fill(TilePalette.color(TilePalette.categoryFill(category, fallback: defaultFill)))
                .overlay {
                    Circle().strokeBorder(TilePalette.color(TilePalette.categoryBorder(category, fallback: defaultBorder)), lineWidth: 4)
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            Text(tag.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

        }
        .frame(minHeight: 44)
    }
}

// MARK: - Create Category View

struct CreateCategoryView: View {
    @ObservedObject var tagManager: TagManager
    @Binding var newTagName: String
    @Binding var selectedColor: TagColor
    let availableColors: [TagColor]
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var fillHex = TilePalette.hex(TagColor.coral.uiColor)
    @State private var borderHex = TilePalette.prominentBorder(TilePalette.hex(TagColor.coral.uiColor))
    @State private var customBorder = false

    private var cleanName: String { newTagName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var tileColour: Binding<Color> {
        Binding(get: { TilePalette.color(fillHex) }, set: {
            fillHex = TilePalette.hex($0)
            if !customBorder { borderHex = TilePalette.prominentBorder(fillHex) }
        })
    }

    private var borderColour: Binding<Color> {
        Binding(get: { TilePalette.color(borderHex) }, set: {
            borderHex = TilePalette.hex($0)
            customBorder = true
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category name") {
                    TextField("Enter category name", text: $newTagName)
                        .focused($isFocused).submitLabel(.done)
                }
                Section {
                    ColorPicker("Tile colour", selection: tileColour, supportsOpacity: false)
                    ColorPicker("Border colour", selection: borderColour, supportsOpacity: false)
                    if customBorder {
                        Button("Use darker automatic border") {
                            customBorder = false
                            borderHex = TilePalette.prominentBorder(fillHex)
                        }
                    }
                } header: {
                    Text("Category colours")
                } footer: {
                    Text("The border follows your tile colour with a darker shade until you choose your own border colour.")
                }
                Section("Preview") {
                    Text(cleanName.isEmpty ? "Your category" : cleanName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(TilePalette.foreground(fillHex))
                        .multilineTextAlignment(.center)
                        .padding(24).frame(maxWidth: .infinity, minHeight: 130)
                        .background(TilePalette.color(fillHex), in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(TilePalette.color(borderHex), lineWidth: 4)
                        }
                }
            }
            .navigationTitle("New Category").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard tagManager.addUserTag(name: cleanName, color: selectedColor,
                                                   fillHex: fillHex, borderHex: borderHex) else { return }
                        Haptics.optionTap()
                        newTagName = ""; selectedColor = .coral
                        dismiss()
                    }.disabled(cleanName.isEmpty || !tagManager.canAddMoreUserTags)
                }
            }
            .onAppear {
                fillHex = TilePalette.hex(selectedColor.uiColor)
                borderHex = TilePalette.prominentBorder(fillHex)
                customBorder = false
                isFocused = true
            }
            .alert("Category could not be saved", isPresented: Binding(
                get: { tagManager.saveError != nil }, set: { if !$0 { tagManager.saveError = nil } })) {
                Button("OK") { tagManager.saveError = nil }
            } message: { Text(tagManager.saveError ?? "Please try again.") }
        }
    }
}

// MARK: - Category Picker View

struct CategoryPickerView: View {
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
        Text("Categorise thought")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .padding(.top, 16)
    }

    private func targetScrollId() -> Int {
        tagManager.tagsInDisplayOrder.contains(where: { $0.id == lastTagPickerId })
            ? lastTagPickerId
            : selectedTagId
    }

    private var newCategoryChoiceButton: some View {
        Button(action: {
            Haptics.optionTap()
            showCreateTag = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("New Category")
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
                                CategoryChoiceButton(
                                    tag: tag,
                                    isSelected: selectedTagId == tag.id,
                                    action: {
                                        selectedTagId = tag.id
                                        lastTagPickerId = tag.id
                                    }
                                )
                                .id(tag.id)
                            }
                            newCategoryChoiceButton
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
            CreateCategoryView(
                tagManager: tagManager,
                newTagName: $newTagName,
                selectedColor: $selectedColor,
                availableColors: availableColors
            )
        }
    }
}

// MARK: - Category Choice Button

struct CategoryChoiceButton: View {
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
        .accessibilityIdentifier("category-choice-\(tag.id)")
    }
}

// MARK: - Tile Action Buttons

struct TileActionButtons: View {
    enum HighlightedAction {
        case tag
        case complete
        case add
        case close
    }

    let onClose: () -> Void
    let onEdit: () -> Void
    let onChangeTag: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onAdd: () -> Void
    let closeIcon: String
    let closeForegroundColor: Color
    let closeBorderColor: Color?
    let highlightedAction: HighlightedAction?
    let showFloatingAddButton: Bool
    var trainingRestricted = false

    private let buttonSize: CGFloat = 50
    private let buttonSpacing: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: buttonSpacing) {
                    // Delete button (trash)
                    ActionButton(
                        icon: "trash",
                        action: onDelete,
                        isDestructive: true
                    )
                    .disabled(trainingRestricted)

                    // Edit button (pencil)
                    ActionButton(
                        icon: "pencil",
                        action: onEdit,
                        foregroundColor: .yellow
                    )
                    .disabled(trainingRestricted)

                    // Change category button
                    ActionButton(
                        icon: "tag",
                        action: onChangeTag,
                        foregroundColor: .orange,
                        isHighlighted: highlightedAction == .tag
                    )
                    .disabled(trainingRestricted && highlightedAction != .tag)

                    // Complete button (checkmark)
                    ActionButton(
                        icon: "checkmark.circle",
                        action: onComplete,
                        foregroundColor: .green,
                        isHighlighted: highlightedAction == .complete,
                        iconSize: 28
                    )
                    .disabled(trainingRestricted && highlightedAction != .complete)

                    // Close button (X)
                    ActionButton(
                        icon: closeIcon,
                        action: onClose,
                        foregroundColor: closeIcon == "xmark" ? .gray : closeForegroundColor,
                        borderColor: highlightedAction == .close ? .yellow : closeBorderColor
                    )
                    .disabled(trainingRestricted && highlightedAction != .close)

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

                // Keep the capsule centred on the tile; + sits below without shifting it.
                .overlay(alignment: .bottom) {
                    if showFloatingAddButton {
                        GlassButton(
                            icon: "plus",
                            foregroundColor: highlightedAction == .add ? .green : .primary,
                            borderColor: highlightedAction == .add ? .green : nil,
                            action: onAdd
                        )
                        .disabled(trainingRestricted && highlightedAction != .add)
                        .frame(width: 66, alignment: .center)
                        .offset(y: buttonSize + buttonSpacing)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
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
    var iconSize: CGFloat = 18

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
                .font(.system(size: iconSize, weight: .medium))
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
                        .accessibilityIdentifier("training-instruction")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(0..<(TrainingStep.allCases.count - 1), id: \.self) { index in
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
                .accessibilityIdentifier("finish-training")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 108)
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
    let onOpenSearchTile: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool
    @State private var query = ""
    @State private var results: [TileSummary] = []

    private func resultRow(_ item: TileSummary) -> some View {
        let statusLabel = item.status == .active ? "Live" : item.status == .completed ? "Completed" : "Deleted"
        let symbol = item.status == .active ? "globe" : item.status == .completed ? "checkmark.circle.fill" : "trash"
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(item.status == .active ? Color.green : Color.gray)
                .frame(width: 28)
                .accessibilityLabel(statusLabel)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.text.isEmpty ? "(Empty)" : item.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(item.tagName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .adaptiveLiquidPanel()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    TextField("Search tiles", text: $query)
                        .focused($searchFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
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
                                Group {
                                    if item.status == .active {
                                        Button {
                                            Haptics.optionTap()
                                            onOpenSearchTile(item.id)
                                        } label: {
                                            resultRow(item)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityHint("Opens this tile in its category")
                                    } else {
                                        resultRow(item)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }

                            if results.isEmpty {
                                Text("No results")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
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
                }
            }
        }
        .onChange(of: query) { _, newValue in
            results = searchTiles(newValue)
        }
        .onAppear {
            results = searchTiles(query)
            searchFocused = true
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
        NavigationStack {
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
        NavigationStack {
            List {
                ForEach(displayTiles) { tile in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(tile.text.isEmpty ? "(Empty)" : tile.text)
                                .font(.body)
                            Text(tagNameProvider(tile.tagId))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Restore") {
                            Haptics.optionTap()
                            onRestore(tile)
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Restore \(tile.text.isEmpty ? "empty tile" : tile.text)")
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
        NavigationStack {
            List {
                Section {
                    ForEach(displayTiles) { tile in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tile.text.isEmpty ? "(Empty)" : tile.text)
                                    .font(.body)
                                Text(tagNameProvider(tile.tagId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Restore") {
                                Haptics.optionTap()
                                onRestore(tile)
                            }
                            .buttonStyle(.borderless)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Restore \(tile.text.isEmpty ? "empty tile" : tile.text)")
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


struct ProPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pro = ProStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    ZStack {
                        Circle().fill(.indigo.opacity(0.12)).frame(width: 180, height: 180)
                        Image(systemName: "brain").font(.system(size: 82)).foregroundStyle(.indigo)
                        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.orange).offset(x: 62, y: -58)
                    }.accessibilityHidden(true)
                    VStack(spacing: 12) {
                        Text(pro.hasPro ? "Hello, limitless brain." : "More room for your thoughts.")
                            .font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Text(pro.hasPro ? "BrainDump Pro is active" : "Give your ideas room to grow with BrainDump Pro.")
                            .font(.title3).multilineTextAlignment(.center)
                        Label("Unlimited active tiles", systemImage: "square.grid.3x3.fill").font(.headline).foregroundStyle(.indigo)
                        Text("Capture now. Sort later.").foregroundStyle(.secondary)
                    }
                    purchaseOption(id: ProStore.monthlyID)
                    purchaseOption(id: ProStore.lifetimeID)
                    if pro.hasSandboxEntitlement {
                        Text("Sandbox Pro is active. Test purchases do not charge you. To repeat a first purchase or free trial, clear your Sandbox Apple Account’s purchase history, then refresh purchase options.")
                            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if let message = pro.message { Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    if pro.busy { ProgressView().accessibilityLabel("Processing purchase") }
                    #if DEBUG
                    VStack(spacing: 10) {
                        Toggle("Unlock Pro for testing", isOn: Binding(
                            get: { pro.testUnlockEnabled }, set: { pro.setTestUnlock($0) }))
                            .accessibilityIdentifier("pro-test-unlock")
                        Text("Development only. No purchase or payment. Turn off to test the free limit again.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    #endif
                    Button("Restore purchases") { Task { await pro.restore() } }.disabled(pro.busy)
                    Button("Refresh purchase options") { Task { await pro.load() } }.disabled(pro.busy || pro.loading)
                    HStack {
                        Link("Privacy", destination: URL(string: "https://cakesquared.co.uk/privacy-policy.html")!)
                        Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }.font(.footnote)
                    Text("Free includes 25 active tiles. Your saved thoughts remain yours, even if your subscription ends.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("BrainDump Pro").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .task { await pro.load() }
    }

    private func purchaseOption(id: String) -> some View {
        let product = pro.products.first { $0.id == id }
        let monthly = id == ProStore.monthlyID
        let offersOneMonthFree = monthly && product?.subscription?.introductoryOffer?.paymentMode == .freeTrial
            && product?.subscription?.introductoryOffer?.period.unit == .month
            && product?.subscription?.introductoryOffer?.period.value == 1
        let trial = offersOneMonthFree && pro.eligibleForTrial
        return VStack(alignment: .leading, spacing: 14) {
            Label(monthly ? "Monthly" : "Lifetime", systemImage: monthly ? "calendar" : "infinity")
                .font(.headline).foregroundStyle(.indigo)
            if offersOneMonthFree {
                Text(trial ? "One month free" : "One month free for eligible new subscribers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }
            if let product {
                Text(monthly ? "\(product.displayPrice) / month" : "\(product.displayPrice) once")
                    .font(.title2.bold())
            } else if pro.loading {
                ProgressView("Loading price…").font(.subheadline)
            } else {
                Text("Price unavailable").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(monthly ? (trial ? "1 month free, then \(product?.displayPrice ?? "") per month. Auto-renews until cancelled." : "Unlimited active tiles. Billed monthly. Auto-renews until cancelled.") : "Unlimited active tiles for life. One payment, no subscription.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                guard let product else { return }
                Task { await pro.purchase(product) }
            } label: {
                Text(monthly ? (trial ? "Start 1-month free trial" : "Subscribe monthly") : "Get lifetime Pro")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .disabled(product == nil || pro.busy || pro.loading || (pro.hasPro && !pro.hasSandboxEntitlement))
            .accessibilityIdentifier(monthly ? "pro-monthly-purchase" : "pro-lifetime-purchase")
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    }
}
