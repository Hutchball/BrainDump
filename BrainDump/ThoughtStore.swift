import Foundation
import Combine
import CryptoKit

/// A local-first durable store. Legacy defaults remain intact as a recovery source.
@MainActor
final class ThoughtStore: ObservableObject {
    static let shared: ThoughtStore = {
        if ProcessInfo.processInfo.arguments.contains("--living-brain-fixture") {
            let name = "BrainDump-UIFixture-" + UUID().uuidString
            return ThoughtStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(name), defaults: UserDefaults(suiteName: name)!)
        }
        return ThoughtStore()
    }()
    @Published private(set) var thoughts: [ThoughtRecord] = []
    @Published private(set) var tags: [ThoughtCategory] = []
    @Published private(set) var storageError: String?
    let directory: URL
    var attachmentDirectory: URL { directory.appendingPathComponent("Attachments", isDirectory: true) }
    private var database = ThoughtDatabase()
    private var thoughtPositions: [String: Int] = [:]
    private var activeRecords: [ThoughtRecord] = []
    private let fileURL: URL
    private var loadFailed = false
    var didChange: ((Set<String>) -> Void)?

    init(directory: URL? = nil, defaults: UserDefaults = .standard) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("BrainDump", isDirectory: true)
        fileURL = self.directory.appendingPathComponent("thoughts-v1.json")
        do {
            try FileManager.default.createDirectory(at: attachmentDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                database = try JSONDecoder().decode(ThoughtDatabase.self, from: Data(contentsOf: fileURL))
            } else {
                database = try Self.migrate(defaults)
                try persist(database)
            }
            publish()
        } catch { loadFailed = true; storageError = error.localizedDescription }
    }
    var activeThoughts: [ThoughtRecord] { activeRecords }
    func thought(id: String) -> ThoughtRecord? {
        guard let position = thoughtPositions[id], database.thoughts.indices.contains(position) else { return nil }
        return database.thoughts[position]
    }
    @discardableResult
    func capture(text: String, tagId: Int = 0, attachments: [ThoughtAttachment] = []) throws -> ThoughtRecord {
        let record = ThoughtRecord(text: text, tagId: tagId, attachments: attachments)
        try update(record)
        return record
    }
    func update(_ thought: ThoughtRecord) throws {
        try Self.validate(thought)
        guard thought.attachments.count <= 10, thought.text.utf8.count <= 1_024 * 1_024 else { throw ValidationError.thoughtTooLarge }
        var record = thought
        record.modifiedAt = Date()
        var next = database
        if let index = next.thoughts.firstIndex(where: { $0.id == record.id }) { next.thoughts[index] = record }
        else { next.thoughts.append(record) }
        next.pendingIDs.insert(record.id)
        try commit(next)
        didChange?([record.id])
    }
    func importAttachment(data: Data, extension fileExtension: String) throws -> String {
        let cleanExtension = fileExtension.filter { $0.isLetter || $0.isNumber }.prefix(10)
        let filename = UUID().uuidString + "." + cleanExtension
        guard !cleanExtension.isEmpty else { throw CocoaError(.fileWriteInvalidFileName) }
        try data.write(to: attachmentDirectory.appendingPathComponent(filename), options: .atomic)
        return filename
    }
    /// Bridges legacy UI while retaining appearance and attachments by stable ID.
    func replaceLegacySnapshot(texts: [String], tagIDs: [Int], ids: [String], completed: [ArchivedTile], deleted: [ArchivedTile], tags legacyTags: [Tag], knownIDs: Set<String>? = nil, baseline: [ThoughtRecord]? = nil, categoryBaseline: [ThoughtCategory]? = nil) throws {
        var next = database
        var changed = Set<String>()
        var incoming: [ThoughtRecord] = []
        var concurrentRecoveries: [ThoughtRecord] = []
        for index in texts.indices {
            let id = index < ids.count ? ids[index] : UUID().uuidString
            var record = thought(id: id) ?? ThoughtRecord(id: id, text: texts[index])
            let base = baseline?.first { $0.id == id }
            if let base, record.text != base.text, texts[index] != base.text, record.text != texts[index] {
                let recovered = Self.recoveredCopy(record)
                if !thoughts.contains(where: { $0.id == recovered.id }) { concurrentRecoveries.append(recovered) }
            }
            if base == nil || base?.text != texts[index] { record.text = texts[index] }
            let tagId = index < tagIDs.count ? tagIDs[index] : 0
            if base == nil || base?.tagId != tagId { record.tagId = tagId }
            if base == nil || base?.status != .active { record.status = .active; record.archivedAt = nil }
            incoming.append(record)
        }
        for (archive, status) in [(completed, ThoughtRecord.Status.completed), (deleted, .deleted)] {
            for item in archive {
                var record = thought(id: item.id) ?? ThoughtRecord(id: item.id, text: item.text)
                let base = baseline?.first { $0.id == item.id }
                if base == nil || base?.text != item.text { record.text = item.text }
                if base == nil || base?.tagId != item.tagId { record.tagId = item.tagId }
                if base == nil || base?.status != status { record.status = status; record.archivedAt = item.archivedAt }
                incoming.append(record)
            }
        }
        incoming += concurrentRecoveries
        // Archive state takes precedence if a malformed legacy snapshot repeats an ID.
        incoming = incoming.reduce(into: [String: ThoughtRecord]()) { $0[$1.id] = $1 }.values.sorted { $0.createdAt < $1.createdAt }
        let incomingIDs = Set(incoming.map(\.id))
        // Keep deletion tombstones so another device cannot resurrect removed thoughts.
        for var record in thoughts where !incomingIDs.contains(record.id) {
            if record.status != .deleted && (knownIDs == nil || knownIDs!.contains(record.id)) { record.status = .deleted; record.archivedAt = Date(); record.modifiedAt = Date(); changed.insert(record.id) }
            incoming.append(record)
        }
        for index in incoming.indices {
            if let old = thought(id: incoming[index].id), old == incoming[index] { continue }
            incoming[index].modifiedAt = Date(); changed.insert(incoming[index].id)
        }
        next.thoughts = incoming
        next.tags = legacyTags.map { tag in
            var category = database.tags.first { $0.id == tag.id } ?? ThoughtCategory(id: tag.id, name: tag.name, color: tag.color.rawValue, isDefault: tag.isDefault)
            let base = categoryBaseline?.first { $0.id == tag.id }
            let previous = category
            if base == nil || base?.name != tag.name { category.name = tag.name }
            if base == nil || base?.color != tag.color.rawValue { category.color = tag.color.rawValue }
            category.isDefault = tag.isDefault
            if category != previous { category.modifiedAt = Date() }
            return category
        }
        let liveTagIDs = Set(next.tags.map(\.id))
        for var category in database.tags where !liveTagIDs.contains(category.id) {
            if category.isDeleted != true && (categoryBaseline == nil || categoryBaseline!.contains(where: { $0.id == category.id })) {
                category.isDeleted = true; category.modifiedAt = Date()
            }
            next.tags.append(category)
        }
        for category in next.tags where !database.tags.contains(category) { changed.insert("category:\(category.id)") }
        next.pendingIDs.formUnion(changed)
        try commit(next)
        if !changed.isEmpty { didChange?(changed) }
    }
    /// Compare against the editor's opening snapshot; preserve both versions on a concurrent edit.
    func saveEdit(_ draft: ThoughtRecord, original: ThoughtRecord) throws -> (ThoughtRecord, Bool) {
        guard let current = thought(id: original.id) else {
            try update(draft)
            return (thought(id: draft.id) ?? draft, false)
        }
        var saved = draft
        let conflict = current != original && current != draft
        if conflict { saved.id = UUID().uuidString; saved.status = .active; saved.archivedAt = nil }
        try update(saved)
        return (thought(id: saved.id) ?? saved, conflict)
    }
    func importRecords(_ records: [ThoughtRecord], replacing: Bool) throws {
        try records.forEach(Self.validate)
        guard Set(records.map(\.id)).count == records.count, records.allSatisfy({ !$0.id.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
        var next = database
        var changed = Set<String>()
        let incoming = Set(records.map(\.id))
        if replacing {
            for index in next.thoughts.indices where !incoming.contains(next.thoughts[index].id) {
                next.thoughts[index].status = .deleted; next.thoughts[index].archivedAt = Date(); next.thoughts[index].modifiedAt = Date(); changed.insert(next.thoughts[index].id)
            }
        }
        for var record in records {
            record.modifiedAt = Date()
            if let index = next.thoughts.firstIndex(where: { $0.id == record.id }) { next.thoughts[index] = record }
            else { next.thoughts.append(record) }
            changed.insert(record.id)
        }
        next.pendingIDs.formUnion(changed); try commit(next); didChange?(changed)
    }
    func importBackup(records: [ThoughtRecord], categories: [ThoughtCategory]?, replacing: Bool) throws {
        try records.forEach(Self.validate)
        guard Set(records.map(\.id)).count == records.count, records.allSatisfy({ !$0.id.isEmpty }),
              categories == nil || Set(categories!.map(\.id)).count == categories!.count else { throw CocoaError(.fileReadCorruptFile) }
        var next = database; var changed = Set<String>()
        let incoming = Set(records.map(\.id))
        if replacing {
            for index in next.thoughts.indices where !incoming.contains(next.thoughts[index].id) {
                next.thoughts[index].status = .deleted; next.thoughts[index].archivedAt = Date(); next.thoughts[index].modifiedAt = Date(); changed.insert(next.thoughts[index].id)
            }
        }
        for var record in records {
            record.modifiedAt = Date()
            if let index = next.thoughts.firstIndex(where: { $0.id == record.id }) { next.thoughts[index] = record }
            else { next.thoughts.append(record) }
            changed.insert(record.id)
        }
        if let categories {
            let categoryIDs = Set(categories.map(\.id))
            if replacing {
                for index in next.tags.indices where !categoryIDs.contains(next.tags[index].id) && !next.tags[index].isDefault {
                    next.tags[index].isDeleted = true; next.tags[index].modifiedAt = Date(); changed.insert("category:\(next.tags[index].id)")
                }
            }
            for var category in categories {
                category.modifiedAt = Date()
                if let index = next.tags.firstIndex(where: { $0.id == category.id }) { next.tags[index] = category }
                else { next.tags.append(category) }
                changed.insert("category:\(category.id)")
            }
        }
        next.pendingIDs.formUnion(changed); try commit(next); didChange?(changed)
    }
    func updateCategory(_ category: ThoughtCategory) throws {
        var next = database; var category = category; category.modifiedAt = Date()
        if let index = next.tags.firstIndex(where: { $0.id == category.id }) { next.tags[index] = category }
        else { next.tags.append(category) }
        let key = "category:\(category.id)"; next.pendingIDs.insert(key); try commit(next); didChange?([key])
    }
    func applyCategorySnapshot(_ categories: [ThoughtCategory]) throws {
        var next = database
        let changed = categories.filter { category in !next.tags.contains(category) }.map { "category:\($0.id)" }
        next.tags = categories; next.pendingIDs.formUnion(changed)
        try commit(next); didChange?(Set(changed))
    }
    var accountSyncPaused: Bool { database.accountSyncPaused ?? false }
    func resumeAccountSync() throws { var next = database; next.accountSyncPaused = false; next.syncState = nil; next.cloudRecords = [:]; next.cloudAttachmentSlots = nil; next.pendingIDs.formUnion(next.thoughts.map(\.id)); next.pendingIDs.formUnion(next.tags.map { "category:\($0.id)" }); try commit(next) }
    func pauseAccountSync() throws { var next = database; next.accountSyncPaused = true; try commit(next) }
    func mergeRemoteCategory(_ category: ThoughtCategory, systemFields: Data) throws {
        var next = database; let key = "category:\(category.id)"
        if let index = next.tags.firstIndex(where: { $0.id == category.id }) {
            if category.modifiedAt >= next.tags[index].modifiedAt { next.tags[index] = category; next.pendingIDs.remove(key) }
        } else { next.tags.append(category) }
        next.cloudRecords[key] = systemFields; try commit(next); didChange?(next.pendingIDs)
    }
    var pendingIDs: Set<String> { database.pendingIDs }
    var syncState: Data? { database.syncState }
    func saveSyncState(_ state: Data) throws { var next = database; next.syncState = state; try commit(next) }
    func cloudRecordData(id: String) -> Data? { database.cloudRecords[id] }
    func cloudAttachmentSlots(id: String) -> [String?]? { database.cloudAttachmentSlots?[id] }
    func acknowledge(id: String, systemFields: Data, sentModifiedAt: Date?, attachmentSlots: [String?]? = nil) throws {
        var next = database; next.cloudRecords[id] = systemFields
        if let attachmentSlots {
            if next.cloudAttachmentSlots == nil { next.cloudAttachmentSlots = [:] }
            next.cloudAttachmentSlots?[id] = attachmentSlots
        }
        if (id.hasPrefix("category:") ? tags.first { "category:\($0.id)" == id }?.modifiedAt : thought(id: id)?.modifiedAt) == sentModifiedAt { next.pendingIDs.remove(id) }
        try commit(next)
    }
    func mergeRemote(_ record: ThoughtRecord, systemFields: Data) throws {
        try Self.validate(record)
        var next = database
        if let index = next.thoughts.firstIndex(where: { $0.id == record.id }) {
            let local = next.thoughts[index]
            if next.pendingIDs.contains(record.id), local.text != record.text || local.attachments != record.attachments {
                // Preserve the losing text as a separate thought, including attachments.
                var recovered = local.modifiedAt > record.modifiedAt ? record : local
                recovered = Self.recoveredCopy(recovered)
                if !next.thoughts.contains(where: { $0.id == recovered.id }) {
                    next.thoughts.append(recovered); next.pendingIDs.insert(recovered.id)
                }
            }
            if record.modifiedAt >= local.modifiedAt { next.thoughts[index] = record; next.pendingIDs.remove(record.id) }
        } else { next.thoughts.append(record) }
        next.cloudRecords[record.id] = systemFields
        if next.cloudAttachmentSlots == nil { next.cloudAttachmentSlots = [:] }
        next.cloudAttachmentSlots?[record.id] = record.attachments.map(\.filename)
        try commit(next)
        didChange?(next.pendingIDs)
    }
    enum ValidationError: LocalizedError {
        case tooManyAttachments, invalidAttachment, thoughtTooLarge
        var errorDescription: String? {
            switch self {
            case .thoughtTooLarge: return "This thought is too large. Split it into smaller thoughts."
            case .tooManyAttachments: return "A thought can hold up to 10 attachments. Add another thought to keep capturing."
            case .invalidAttachment: return "This thought contains an invalid attachment."
            }
        }
    }
    private static func validate(_ record: ThoughtRecord) throws {
        guard !record.id.isEmpty, record.id.utf8.count <= 255, !record.id.hasPrefix("category:") else { throw ValidationError.invalidAttachment }
        guard record.attachments.count <= 10 else { throw ValidationError.tooManyAttachments }
        guard Set(record.attachments.map(\.id)).count == record.attachments.count else { throw ValidationError.invalidAttachment }
        for attachment in record.attachments {
            guard !attachment.id.isEmpty else { throw ValidationError.invalidAttachment }
            switch attachment.kind {
            case .image: guard let filename = attachment.filename, AttachmentStore.isSafeFilename(filename) else { throw ValidationError.invalidAttachment }
            case .link: guard let url = attachment.url, AttachmentStore.webURL(url) != nil, attachment.filename == nil else { throw ValidationError.invalidAttachment }
            }
        }
    }
    private static func recoveredCopy(_ source: ThoughtRecord) -> ThoughtRecord {
        var recovered = source
        let fingerprint = SHA256.hash(data: Data((source.id + source.text + String(source.modifiedAt.timeIntervalSince1970)).utf8)).map { String(format: "%02x", $0) }.joined()
        recovered.id = "recovered-" + fingerprint
        recovered.text += "\n\n[Recovered concurrent edit]"; recovered.status = .active; recovered.archivedAt = nil; recovered.modifiedAt = Date()
        return recovered
    }
    private func commit(_ next: ThoughtDatabase) throws {
        guard !loadFailed else { throw CocoaError(.fileReadCorruptFile) }
        guard next.thoughts.allSatisfy({ $0.attachments.count <= 10 && $0.text.utf8.count <= 1_024 * 1_024 }) else { throw ValidationError.thoughtTooLarge }
        guard next != database else { return }
        do { try persist(next); database = next; publish(); storageError = nil }
        catch { storageError = error.localizedDescription; throw error }
    }
    private func persist(_ value: ThoughtDatabase) throws {
        try JSONEncoder().encode(value).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    private func publish() {
        thoughtPositions = Dictionary(database.thoughts.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { _, newest in newest })
        activeRecords = database.thoughts.filter { $0.status == .active }
        if thoughts != database.thoughts { thoughts = database.thoughts }
        if tags != database.tags { tags = database.tags }
    }
    private static func migrate(_ defaults: UserDefaults) throws -> ThoughtDatabase {
        var result = ThoughtDatabase()
        let texts = defaults.stringArray(forKey: "SavedTileTexts") ?? []
        let ids = defaults.stringArray(forKey: "SavedTileIds") ?? []
        let tagIDs = defaults.array(forKey: "SavedTileTags") as? [Int] ?? []
        result.thoughts = texts.indices.map { ThoughtRecord(id: $0 < ids.count ? ids[$0] : UUID().uuidString, text: texts[$0], tagId: $0 < tagIDs.count ? tagIDs[$0] : 0) }
        for (key, status) in [("CompletedTiles", ThoughtRecord.Status.completed), ("DeletedTiles", .deleted)] {
            if let data = defaults.data(forKey: key) {
                let archives = try JSONDecoder().decode([ArchivedTile].self, from: data)
                result.thoughts += archives.map { ThoughtRecord(id: $0.id, text: $0.text, tagId: $0.tagId, status: status, archivedAt: $0.archivedAt) }
            }
        }
        if let data = defaults.data(forKey: "SavedTags") {
            let tags = try JSONDecoder().decode([Tag].self, from: data)
            result.tags = tags.map { ThoughtCategory(id: $0.id, name: $0.name, color: $0.color.rawValue, isDefault: $0.isDefault) }
        }
        if result.tags.isEmpty {
            result.tags = [
                ThoughtCategory(id: 0, name: "Brain Dump", color: "grey", isDefault: true),
                ThoughtCategory(id: 3, name: "Things to do", color: "brown", isDefault: true),
                ThoughtCategory(id: 1, name: "Movies to watch", color: "darkBlue", isDefault: true),
                ThoughtCategory(id: 2, name: "Books to read", color: "yellow", isDefault: true),
                ThoughtCategory(id: 4, name: "Websites to check", color: "lightBlue", isDefault: true)
            ]
        }
        result.thoughts = result.thoughts.reduce(into: [String: ThoughtRecord]()) { $0[$1.id] = $1 }.values.sorted { $0.createdAt < $1.createdAt }
        result.pendingIDs = Set(result.thoughts.map(\.id) + result.tags.map { "category:\($0.id)" })
        return result
    }
}
