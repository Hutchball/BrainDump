import Foundation
import Testing
@testable import BrainDump

@MainActor
struct ThoughtStoreTests {
    private func fixture() -> (URL, UserDefaults) {
        let name = "BrainDumpTests-" + UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        return (directory, UserDefaults(suiteName: name)!)
    }
    @Test func categoryNamesAndOrderSurviveReloadAndLegacyDecoding() throws {
        let legacy = Data(#"{"id":3,"name":"Things to do","color":"yellow","isDefault":true,"modifiedAt":0}"#.utf8)
        let decoded = try JSONDecoder().decode(ThoughtCategory.self, from: legacy)
        #expect(decoded.displayOrder == nil)
        let (directory, defaults) = fixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let thought = try store.capture(text: "Keep category membership")
        var categories = store.tags
        for index in categories.indices {
            categories[index].displayOrder = categories.count - index - 1
            categories[index].modifiedAt = Date()
        }
        let id = try #require(categories.first?.id)
        categories[0].name = "Renamed category"
        try store.applyCategorySnapshot(categories)
        let reloaded = ThoughtStore(directory: directory, defaults: defaults)
        #expect(reloaded.tags == categories)
        #expect(reloaded.thought(id: thought.id)?.tagId == thought.tagId)
        #expect(reloaded.pendingIDs.contains("category:\(id)"))
    }

    @Test func environmentChangeRequeuesAcknowledgedLibraryWithoutChangingThoughts() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let captured = try store.capture(text: "Keep this thought")
        let thought = try #require(store.thought(id: captured.id))
        try store.prepareCloudSync(environment: "Development")
        try store.acknowledge(id: thought.id, systemFields: Data([1]), sentModifiedAt: thought.modifiedAt)
        try store.saveSyncState(Data([2]))
        let original = store.thoughts
        #expect(!store.pendingIDs.contains(thought.id))
        try store.prepareCloudSync(environment: "Production")
        #expect(store.thoughts == original)
        #expect(store.pendingIDs.contains(thought.id))
        #expect(store.syncState == nil)
        #expect(store.cloudRecordData(id: thought.id) == nil)
        #expect(store.pendingIDs.isSuperset(of: store.tags.map { "category:\($0.id)" }))
        try store.acknowledge(id: thought.id, systemFields: Data([3]), sentModifiedAt: thought.modifiedAt)
        try store.saveSyncState(Data([4]))
        let reloaded = ThoughtStore(directory: directory, defaults: defaults)
        try reloaded.prepareCloudSync(environment: "Production")
        #expect(!reloaded.pendingIDs.contains(thought.id))
        #expect(reloaded.syncState == Data([4]))
        #expect(reloaded.thoughts == original)
    }

    @Test func legacySyncBaselineAndManualRecoveryPreserveArchivesAndTombstones() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        var thought = try store.capture(text: "Archived")
        thought.status = .deleted; thought.archivedAt = Date()
        try store.update(thought)
        thought = try #require(store.thought(id: thought.id))
        try store.acknowledge(id: thought.id, systemFields: Data([1]), sentModifiedAt: thought.modifiedAt)
        try store.prepareCloudSync(environment: "Production")
        #expect(store.pendingIDs.contains(thought.id))
        #expect(store.thought(id: thought.id) == thought)
        try store.acknowledge(id: thought.id, systemFields: Data([1]), sentModifiedAt: thought.modifiedAt)
        try store.prepareCloudSync(environment: "Production", force: true)
        #expect(store.pendingIDs.contains(thought.id))
        #expect(store.thought(id: thought.id) == thought)
    }

    @Test func syncRecoveryDoesNotBypassAccountPause() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        try store.saveSyncState(Data([8]))
        try store.pauseAccountSync()
        try store.prepareCloudSync(environment: "Production", force: true)
        #expect(store.accountSyncPaused)
        #expect(store.syncState == Data([8]))
    }

    @Test func freeLimitProtectsExistingThoughtsAndProAllowsMore() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        var pro = false
        store.creationHasPro = { pro }
        for index in 0..<25 { _ = try store.capture(text: "Thought \(index)") }
        #expect(!store.canCreateThought)
        #expect(throws: ThoughtStore.ValidationError.self) { try store.capture(text: "Over limit") }
        var first = store.activeThoughts[0]
        first.text = "Still editable"
        try store.update(first)
        #expect(store.thought(id: first.id)?.text == "Still editable")
        first.status = .completed
        try store.update(first)
        #expect(store.canCreateThought)
        _ = try store.capture(text: "Space reclaimed")
        pro = true
        _ = try store.capture(text: "Pro thought")
        #expect(store.activeThoughts.count == 26)
        pro = false
        #expect(!store.canCreateThought)
        #expect(store.activeThoughts.count == 26)
    }

    @Test func categoryColoursRespectExplicitAppearance() {
        var category = ThoughtCategory(id: 3, name: "Things to do", color: "brown", isDefault: true)
        let automatic = TilePalette.categoryFill(category, fallback: "E9E3FF")
        #expect(automatic == TilePalette.hex(TagColor.brown.uiColor))
        category.fillHex = "FFFFFF"
        category.borderHex = "000000"
        #expect(TilePalette.categoryFill(category, fallback: "E9E3FF") == "FFFFFF")
        #expect(TilePalette.categoryBorder(category, fallback: "7565AB") == "000000")
        category.id = 0; category.fillHex = nil; category.borderHex = nil
        #expect(TilePalette.categoryFill(category, fallback: "E9E3FF") == "E9E3FF")
        #expect(TilePalette.categoryBorder(category, fallback: "7565AB") == "7565AB")
    }

    @Test func migratesLegacyAndPreservesDefaults() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        defaults.set(["Remember milk"], forKey: "SavedTileTexts")
        defaults.set(["stable-id"], forKey: "SavedTileIds")
        defaults.set([3], forKey: "SavedTileTags")
        let archive = ArchivedTile(id: "archive", text: "Finished", tagId: 2, archivedAt: Date())
        defaults.set(try JSONEncoder().encode([archive]), forKey: "CompletedTiles")
        let store = ThoughtStore(directory: directory, defaults: defaults)
        #expect(store.thought(id: "stable-id")?.tagId == 3)
        #expect(store.thought(id: "archive")?.status == .completed)
        #expect(defaults.stringArray(forKey: "SavedTileTexts") == ["Remember milk"])
        let reloaded = ThoughtStore(directory: directory, defaults: defaults)
        #expect(reloaded.thoughts == store.thoughts)
    }
    @Test func upgradePreservesLargeLibraryAndCustomCategoriesAcrossLaunches() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let texts = (0..<80).map { "Existing tile \($0)" }
        let ids = (0..<80).map { "legacy-\($0)" }
        let assignments = (0..<80).map { $0.isMultiple(of: 2) ? 42 : 2 }
        let categories = [Tag(id: 0, name: "Brain Dump", color: .grey, isDefault: true),
                          Tag(id: 2, name: "My reading list", color: .purple, isDefault: true),
                          Tag(id: 42, name: "Holiday plans", color: .coral, isDefault: false)]
        defaults.set(texts, forKey: "SavedTileTexts")
        defaults.set(ids, forKey: "SavedTileIds")
        defaults.set(assignments, forKey: "SavedTileTags")
        let categoryData = try JSONEncoder().encode(categories)
        defaults.set(categoryData, forKey: "SavedTags")
        let deleted = ArchivedTile(id: "deleted", text: "Removed", tagId: 42, archivedAt: Date())
        defaults.set(try JSONEncoder().encode([deleted]), forKey: "DeletedTiles")
        let migrated = ThoughtStore(directory: directory, defaults: defaults)
        migrated.creationHasPro = { false }
        #expect(migrated.storageError == nil)
        #expect(migrated.activeThoughts.count == 80)
        #expect(!migrated.canCreateThought)
        for index in ids.indices {
            #expect(migrated.thought(id: ids[index])?.text == texts[index])
            #expect(migrated.thought(id: ids[index])?.tagId == assignments[index])
        }
        #expect(migrated.tags.map(\.id) == categories.map(\.id))
        #expect(migrated.tags.map(\.name) == categories.map(\.name))
        #expect(migrated.tags.map(\.color) == categories.map { $0.color.rawValue })
        #expect(migrated.thought(id: "deleted")?.status == .deleted)
        #expect(defaults.data(forKey: "SavedTags") == categoryData)
        var edited = migrated.thought(id: ids[0])!; edited.text = "Edited after upgrade"
        try migrated.update(edited)
        let reopened = ThoughtStore(directory: directory, defaults: defaults)
        #expect(reopened.thoughts == migrated.thoughts)
        #expect(reopened.tags == migrated.tags)
        #expect(reopened.pendingIDs == migrated.pendingIDs)
    }
    @Test func cloudZoneRecoveryRequeuesEntireLibraryWithoutChangingContent() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let record = try store.capture(text: "Keep category", tagId: 2)
        try store.acknowledge(id: record.id, systemFields: Data([1]), sentModifiedAt: record.modifiedAt, attachmentSlots: ["image.png"])
        let thoughts = store.thoughts, categories = store.tags
        try store.requeueAllCloudRecords()
        #expect(store.thoughts == thoughts)
        #expect(store.tags == categories)
        #expect(store.cloudRecordData(id: record.id) == nil)
        #expect(store.cloudAttachmentSlots(id: record.id) == nil)
        #expect(store.pendingIDs == Set(thoughts.map(\.id) + categories.map { "category:\($0.id)" }))
        try store.pauseAccountSync()
        let reopened = ThoughtStore(directory: directory, defaults: defaults)
        #expect(reopened.accountSyncPaused)
        #expect(reopened.thoughts == thoughts)
        try reopened.resumeAccountSync()
        #expect(!reopened.accountSyncPaused)
        #expect(reopened.thoughts == thoughts)
        #expect(reopened.tags == categories)
    }
    @Test func snapshotsRetainAttachmentsAndAppearance() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        var record = try store.capture(text: "Original")
        record.fillHex = "FFFFFF"; record.borderHex = "000000"
        record.attachments = [ThoughtAttachment(kind: .link, url: "https://apple.com")]
        try store.update(record)
        try store.replaceLegacySnapshot(texts: ["Changed"], tagIDs: [2], ids: [record.id], completed: [], deleted: [], tags: [])
        #expect(store.thought(id: record.id)?.fillHex == "FFFFFF")
        #expect(store.thought(id: record.id)?.attachments == record.attachments)
        #expect(store.thought(id: record.id)?.text == "Changed")
    }
    @Test func emptyActiveSnapshotPreservesArchivesAndDeletionTombstones() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let first = try store.capture(text: "Completed")
        let second = try store.capture(text: "Deleted")
        let archive = ArchivedTile(id: first.id, text: first.text, tagId: 0, archivedAt: Date())
        try store.replaceLegacySnapshot(texts: [], tagIDs: [], ids: [], completed: [archive], deleted: [], tags: [])
        #expect(store.activeThoughts.isEmpty)
        #expect(store.thought(id: first.id)?.status == .completed)
        #expect(store.thought(id: second.id)?.status == .deleted)
        #expect(store.pendingIDs.contains(second.id))
    }
    @Test func conflictingPendingTextIsRecovered() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let local = try store.capture(text: "Local edit")
        var remote = local; remote.text = "Remote edit"; remote.modifiedAt = local.modifiedAt.addingTimeInterval(1)
        try store.mergeRemote(remote, systemFields: Data())
        #expect(store.thought(id: local.id)?.text == "Remote edit")
        #expect(store.thoughts.contains { $0.id != local.id && $0.text.hasPrefix("Local edit") })
        #expect(store.pendingIDs.filter { !$0.hasPrefix("category:") }.count == 1)
    }
    @Test func staleProjectionCannotDeleteNewCaptureOrOverwriteRemoteText() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let original = try store.capture(text: "Initial")
        let baseline = store.thoughts
        let newThought = try store.capture(text: "From Siri")
        var remote = original; remote.text = "New cloud text"; remote.modifiedAt = Date().addingTimeInterval(1)
        try store.mergeRemote(remote, systemFields: Data())
        try store.replaceLegacySnapshot(texts: [original.text], tagIDs: [0], ids: [original.id], completed: [], deleted: [], tags: [], knownIDs: Set(baseline.map(\.id)), baseline: baseline)
        #expect(store.thought(id: newThought.id)?.status == .active)
        #expect(store.thought(id: original.id)?.text == "New cloud text")
    }
    @Test func editorConflictKeepsBothVersions() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let original = try store.capture(text: "Initial")
        var other = original; other.text = "Other edit"; try store.update(other)
        var draft = original; draft.text = "My edit"
        let (saved, conflict) = try store.saveEdit(draft, original: original)
        #expect(conflict)
        #expect(saved.id != original.id)
        #expect(store.thought(id: original.id)?.text == "Other edit")
        #expect(store.thought(id: saved.id)?.text == "My edit")
    }
    @Test func aNewEditorDraftSavesWithoutAnExistingRecord() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let opening = ThoughtRecord(text: "")
        var draft = opening; draft.text = "Newly captured thought"
        let (saved, conflict) = try store.saveEdit(draft, original: opening)
        #expect(!conflict)
        #expect(saved.id == opening.id)
        #expect(store.thought(id: saved.id)?.text == "Newly captured thought")
    }
    @Test func cloudAcknowledgementDoesNotDropAnEditMadeDuringUpload() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let sent = try store.capture(text: "Uploaded version")
        var edited = sent; edited.text = "Changed during upload"
        try store.update(edited)
        try store.acknowledge(id: sent.id, systemFields: Data(), sentModifiedAt: sent.modifiedAt, attachmentSlots: ["image.png"])
        #expect(store.pendingIDs.contains(sent.id))
        #expect(store.thought(id: sent.id)?.text == "Changed during upload")
        #expect(store.cloudAttachmentSlots(id: sent.id) == ["image.png"])
    }
    @Test func corruptDatabaseCannotBeOverwritten() throws {
        let (directory, defaults) = fixture(); defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("thoughts-v1.json")
        let corrupt = Data("broken".utf8); try corrupt.write(to: file)
        let store = ThoughtStore(directory: directory, defaults: defaults)
        #expect(store.storageError != nil)
        #expect(throws: CocoaError.self) { try store.capture(text: "New thought") }
        #expect(try Data(contentsOf: file) == corrupt)
    }
}
