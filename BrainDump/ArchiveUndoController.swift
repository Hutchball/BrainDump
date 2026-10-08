import Foundation
import Combine

/// A brief undo window shared by collection and full-text actions.
@MainActor
final class ArchiveUndoController: ObservableObject {
    static let shared = ArchiveUndoController()
    @Published private(set) var thoughtID: String?
    private var archivedStatus: ThoughtRecord.Status?
    private var archivedAt: Date?
    private var previousCategoryID: Int?
    private var assignedCategoryID: Int?
    private var deadline = Date.distantPast
    private var expiryTask: Task<Void, Never>?

    func offerUndo(for thought: ThoughtRecord) {
        previousCategoryID = nil
        assignedCategoryID = nil
        beginWindow(for: thought)
    }

    func offerCategoryUndo(for thought: ThoughtRecord, previousCategoryID: Int) {
        guard thought.tagId != previousCategoryID else { return }
        self.previousCategoryID = previousCategoryID
        assignedCategoryID = thought.tagId
        beginWindow(for: thought)
    }

    func canRestoreCategory(_ categoryID: Int) -> Bool {
        thoughtID != nil && previousCategoryID == categoryID && Date() < deadline
    }

    private func beginWindow(for thought: ThoughtRecord) {
        expiryTask?.cancel()
        thoughtID = thought.id
        archivedStatus = thought.status
        archivedAt = thought.archivedAt
        deadline = Date().addingTimeInterval(2.5)
        expiryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(2500)) } catch { return }
            self?.clear()
        }
    }

    func undo(in store: ThoughtStore) throws -> ThoughtRecord? {
        guard Date() < deadline, let thoughtID,
              var thought = store.thought(id: thoughtID),
              thought.status == archivedStatus, thought.archivedAt == archivedAt else {
            clear()
            return nil
        }
        // Restore only the action's fields on the latest record.
        if let previousCategoryID {
            guard thought.tagId == assignedCategoryID,
                  store.tags.contains(where: { $0.id == previousCategoryID && $0.isDeleted != true }) else {
                clear()
                return nil
            }
            thought.tagId = previousCategoryID
        } else {
            thought.status = .active
            thought.archivedAt = nil
        }
        try store.update(thought)
        clear()
        return thought
    }

    private func clear() {
        expiryTask?.cancel()
        expiryTask = nil
        thoughtID = nil
        archivedStatus = nil
        archivedAt = nil
        previousCategoryID = nil
        assignedCategoryID = nil
        deadline = .distantPast
    }
}
