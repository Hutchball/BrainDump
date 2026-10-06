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
