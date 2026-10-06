import Foundation
import Testing
@testable import BrainDump

@MainActor
struct BackupServiceTests {
    private func store() -> ThoughtStore {
        let name = "BrainDumpBackupTests-" + UUID().uuidString
        return ThoughtStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(name), defaults: UserDefaults(suiteName: name)!)
    }
    @Test func richMetadataRoundTrips() async throws {
        let original = store(), restored = store()
        defer { try? FileManager.default.removeItem(at: original.directory); try? FileManager.default.removeItem(at: restored.directory) }
        var thought = try original.capture(text: "A link", tagId: 3, attachments: [ThoughtAttachment(kind: .link, url: "https://developer.apple.com")])
        thought.fillHex = "FFFFFF"; thought.borderHex = "0066FF"; try original.update(thought)
        let data = try await BackupService.export(store: original)
        let backup = try JSONDecoder().decode(TileBackup.self, from: data)
        #expect(backup.version == 4)
        try await BackupService.restore(data: data, replacing: true, store: restored)
        #expect(restored.thought(id: thought.id)?.attachments == thought.attachments)
        #expect(restored.thought(id: thought.id)?.borderHex == "0066FF")
    }
    @Test func restoresVersionThreeArchivesAndDeduplicatesLegacyText() async throws {
        let destination = store(); defer { try? FileManager.default.removeItem(at: destination.directory) }
        _ = try destination.capture(text: "Remember milk", tagId: 3)
        let archive = ArchivedTile(id: "archive", text: "Finished", tagId: 0, archivedAt: Date())
        let backup = TileBackup(version: 3, exportedAt: Date(), tags: nil, completed: [archive], deleted: [], tiles: [.init(id: "legacy", text: "Remember milk", tagId: 3)])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try await BackupService.restore(data: encoder.encode(backup), replacing: false, store: destination)
        #expect(destination.activeThoughts.count == 1)
        #expect(destination.thought(id: "archive")?.status == .completed)
        #expect(destination.tags.contains { $0.id == 0 })
    }
    @Test func invalidAttachmentDoesNotChangeStore() async throws {
        let destination = store(); defer { try? FileManager.default.removeItem(at: destination.directory) }
        let existing = try destination.capture(text: "Keep this safe")
        var backup = TileBackup(version: 4, exportedAt: Date(), tags: nil, completed: nil, deleted: nil, tiles: [])
        backup.records = [ThoughtRecord(text: "Image", attachments: [ThoughtAttachment(kind: .image, filename: "../escape.png")])]
        backup.attachmentData = ["../escape.png": Data()]
        do { try await BackupService.restore(data: JSONEncoder().encode(backup), replacing: true, store: destination); Issue.record("Invalid backup was accepted") }
        catch { #expect(destination.thought(id: existing.id)?.status == .active) }
    }
    @Test func mergedCategoryCollisionPreservesOriginalCategory() async throws {
        let destination = store(); defer { try? FileManager.default.removeItem(at: destination.directory) }
        try destination.updateCategory(ThoughtCategory(id: 10, name: "Personal", color: "grey", isDefault: false))
        var backup = TileBackup(version: 4, exportedAt: Date(), tags: nil, completed: nil, deleted: nil, tiles: [])
        backup.records = [ThoughtRecord(id: "imported", text: "Work task", tagId: 10)]
        backup.categories = [ThoughtCategory(id: 10, name: "Work", color: "grey", isDefault: false)]
        try await BackupService.restore(data: JSONEncoder().encode(backup), replacing: false, store: destination)
        #expect(destination.tags.first { $0.id == 10 }?.name == "Personal")
        let imported = destination.thought(id: "imported")
        #expect(imported?.tagId != 10)
        #expect(destination.tags.first { $0.id == imported?.tagId }?.name == "Work")
    }
}
