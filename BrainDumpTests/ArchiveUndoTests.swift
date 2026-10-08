import Foundation
import Testing
@testable import BrainDump

@MainActor
struct ArchiveUndoTests {
    private func store() -> ThoughtStore {
        let name = "BrainDumpUndoTests-" + UUID().uuidString
        return ThoughtStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(name), defaults: UserDefaults(suiteName: name)!)
    }

    @Test func restoresCompletionAndDeletionWithoutOverwritingNewerContent() throws {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        for status in [ThoughtRecord.Status.completed, .deleted] {
            var thought = try store.capture(text: "Original", tagId: 3)
            thought.status = status; thought.archivedAt = Date()
            try store.update(thought)
            let undo = ArchiveUndoController()
            undo.offerUndo(for: thought)
            thought.text = "Newer edit"
            try store.update(thought)
            let result = try undo.undo(in: store)
            let restored = try #require(result)
            #expect(restored.status == .active)
            #expect(restored.archivedAt == nil)
            #expect(restored.text == "Newer edit")
            #expect(restored.tagId == 3)
            #expect(undo.thoughtID == nil)
        }
    }

    @Test func doesNotUndoAReplacementArchive() throws {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var thought = try store.capture(text: "Keep newer archive")
        thought.status = .completed; thought.archivedAt = Date()
        try store.update(thought)
        let undo = ArchiveUndoController()
        undo.offerUndo(for: thought)
        thought.status = .deleted; thought.archivedAt = Date().addingTimeInterval(1)
        try store.update(thought)
        #expect(try undo.undo(in: store) == nil)
        #expect(store.thought(id: thought.id)?.status == .deleted)
    }

    @Test func categoryUndoPreservesNewerContentAndOriginalMembership() throws {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var thought = try store.capture(text: "Original", tagId: 0)
        thought.tagId = 3
        try store.update(thought)
        let undo = ArchiveUndoController()
        undo.offerCategoryUndo(for: thought, previousCategoryID: 0)
        thought.text = "Updated text"
        thought.attachments = [ThoughtAttachment(kind: .link, url: "https://developer.apple.com")]
        try store.update(thought)
        let result = try undo.undo(in: store)
        let restored = try #require(result)
        #expect(restored.tagId == 0)
        #expect(restored.status == .active)
        #expect(restored.text == thought.text)
        #expect(restored.attachments == thought.attachments)
    }

    @Test func categoryUndoDoesNotOverwriteLaterAssignment() throws {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var thought = try store.capture(text: "Newer category wins", tagId: 0)
        thought.tagId = 3
        try store.update(thought)
        let undo = ArchiveUndoController()
        undo.offerCategoryUndo(for: thought, previousCategoryID: 0)
        thought.tagId = 1
        try store.update(thought)
        #expect(try undo.undo(in: store) == nil)
        #expect(store.thought(id: thought.id)?.tagId == 1)
    }

    @Test func undoExpiresAfterTwoAndAHalfSeconds() async throws {
        let store = store()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        var thought = try store.capture(text: "Expired")
        thought.status = .completed; thought.archivedAt = Date()
        try store.update(thought)
        let undo = ArchiveUndoController()
        undo.offerUndo(for: thought)
        try await Task.sleep(for: .milliseconds(2600))
        #expect(undo.thoughtID == nil)
        #expect(try undo.undo(in: store) == nil)
        #expect(store.thought(id: thought.id)?.status == .completed)
    }
}
