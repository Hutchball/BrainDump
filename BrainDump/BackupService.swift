import Foundation

/// Portable recovery stays separate from automatic, record-based iCloud sync.
enum BackupService {
    nonisolated static let maximumBytes = 200 * 1_024 * 1_024
    @MainActor
    static func export(store: ThoughtStore) async throws -> Data {
        guard store.storageError == nil else { throw CocoaError(.fileReadCorruptFile) }
        let records = store.thoughts, categories = store.tags, directory = store.attachmentDirectory
        return try await Task.detached(priority: .utility) {
            var assets: [String: Data] = [:]
            var total = 0
            for attachment in records.flatMap(\.attachments) {
                guard let filename = attachment.filename else { continue }
                guard AttachmentStore.isSafeFilename(filename) else { throw BackupError.invalidAttachment }
                if assets[filename] != nil { continue }
                let url = directory.appendingPathComponent(filename)
                let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                guard size > 0, size <= 40 * 1_024 * 1_024, total + size <= maximumBytes * 3 / 4 else { throw BackupError.tooLarge }
                let data = try Data(contentsOf: url); total += data.count; assets[filename] = data
            }
            let active = records.filter { $0.status == .active }
            let tags = categories.filter { $0.isDeleted != true }.map { Tag(id: $0.id, name: $0.name, color: TagColor(rawValue: $0.color) ?? .grey, isDefault: $0.isDefault) }
            let completed = records.filter { $0.status == .completed }.map { ArchivedTile(id: $0.id, text: $0.text, tagId: $0.tagId, archivedAt: $0.archivedAt ?? $0.modifiedAt) }
            let deleted = records.filter { $0.status == .deleted }.map { ArchivedTile(id: $0.id, text: $0.text, tagId: $0.tagId, archivedAt: $0.archivedAt ?? $0.modifiedAt) }
            var backup = TileBackup(version: 4, exportedAt: Date(), tags: tags, completed: completed, deleted: deleted,
                tiles: active.map { TileBackup.TileRecord(id: $0.id, text: $0.text, tagId: $0.tagId) })
            backup.records = records; backup.categories = categories; backup.attachmentData = assets
            let output = try JSONEncoder().encode(backup)
            guard output.count <= maximumBytes else { throw BackupError.tooLarge }
            return output
        }.value
    }
    @MainActor
    static func restore(data: Data, replacing: Bool, store: ThoughtStore) async throws {
        let existing = store.thoughts, existingCategories = store.tags, directory = store.attachmentDirectory
        let prepared = try await Task.detached(priority: .userInitiated) {
            guard data.count <= maximumBytes else { throw BackupError.tooLarge }
            let legacyDecoder = JSONDecoder()
            legacyDecoder.dateDecodingStrategy = .iso8601
            let backup: TileBackup
            if let legacy = try? legacyDecoder.decode(TileBackup.self, from: data) { backup = legacy }
            else { backup = try JSONDecoder().decode(TileBackup.self, from: data) }
            guard (1...4).contains(backup.version) else { throw BackupError.unsupportedVersion }
            var records: [ThoughtRecord]
            if let saved = backup.records { records = saved }
            else {
                records = backup.tiles.map { ThoughtRecord(id: $0.id, text: $0.text, tagId: $0.tagId) }
                records += (backup.completed ?? []).map { ThoughtRecord(id: $0.id, text: $0.text, tagId: $0.tagId, status: .completed, archivedAt: $0.archivedAt) }
                records += (backup.deleted ?? []).map { ThoughtRecord(id: $0.id, text: $0.text, tagId: $0.tagId, status: .deleted, archivedAt: $0.archivedAt) }
                // Old archives occasionally repeated an active ID; the archive is authoritative.
                var positions: [String: Int] = [:], unique: [ThoughtRecord] = []
                for record in records {
                    if let index = positions[record.id] { unique[index] = record }
                    else { positions[record.id] = unique.count; unique.append(record) }
                }
                records = unique
            }
            guard records.count <= 100_000, Set(records.map(\.id)).count == records.count,
                  records.allSatisfy({ !$0.id.isEmpty && $0.id.utf8.count <= 255 && $0.text.utf8.count <= 1_024 * 1_024 && $0.attachments.count <= 10 }) else { throw BackupError.invalidBackup }
            var assets: [String: Data] = [:]
            var filenameMap: [String: String] = [:]
            for index in records.indices {
                guard validColour(records[index].fillHex), validColour(records[index].borderHex) else { throw BackupError.invalidBackup }
                for attachmentIndex in records[index].attachments.indices {
                    var attachment = records[index].attachments[attachmentIndex]
                    guard !attachment.id.isEmpty else { throw BackupError.invalidAttachment }
                    if attachment.kind == .link {
                        guard let link = attachment.url, AttachmentStore.webURL(link) != nil, attachment.filename == nil else { throw BackupError.invalidAttachment }
                    } else {
                        guard let filename = attachment.filename, AttachmentStore.isSafeFilename(filename), let imageData = backup.attachmentData?[filename] else { throw BackupError.invalidAttachment }
                        if filenameMap[filename] == nil {
                            let sanitised = try await AttachmentStore.prepareImage(imageData)
                            let name = UUID().uuidString + ".png"
                            guard assets.values.reduce(0, { $0 + $1.count }) + sanitised.count <= maximumBytes * 3 / 4 else { throw BackupError.tooLarge }
                            filenameMap[filename] = name; assets[name] = sanitised
                        }
                        attachment.filename = filenameMap[filename]; attachment.contentType = "public.png"
                    }
                    records[index].attachments[attachmentIndex] = attachment
                }
            }
            var categories = backup.categories ?? backup.tags?.map { ThoughtCategory(id: $0.id, name: $0.name, color: $0.color.rawValue, isDefault: $0.isDefault) }
            if let categories {
                guard categories.count <= 1_000, Set(categories.map(\.id)).count == categories.count,
                      categories.allSatisfy({ !$0.name.isEmpty && $0.name.utf8.count <= 1_024 && validColour($0.fillHex) && validColour($0.borderHex) }) else { throw BackupError.invalidBackup }
            }
            if !replacing, var importedCategories = categories {
                var nextID = max(existingCategories.map(\.id).max() ?? 4, importedCategories.map(\.id).max() ?? 4) + 1
                var retained: [ThoughtCategory] = []
                for var category in importedCategories {
                    if let current = existingCategories.first(where: { $0.id == category.id }) {
                        if category.isDefault || current.name == category.name { continue }
                        let oldID = category.id; category.id = nextID; nextID += 1
                        for index in records.indices where records[index].tagId == oldID { records[index].tagId = category.id }
                    }
                    retained.append(category)
                }
                importedCategories = retained; categories = importedCategories
            }
            if !replacing {
                let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                let signatures = Set(existing.filter { $0.attachments.isEmpty }.map(signature))
                records = records.compactMap { record in
                    if record.attachments.isEmpty && signatures.contains(signature(record)) { return nil }
                    if existingByID[record.id] == record { return nil }
                    var record = record
                    if existingByID[record.id] != nil { record.id = UUID().uuidString }
                    return record
                }
            }
            let referencedFiles = Set(records.flatMap(\.attachments).compactMap(\.filename))
            assets = assets.filter { referencedFiles.contains($0.key) }
            var written: [URL] = []
            do {
                for (filename, bytes) in assets {
                    let url = directory.appendingPathComponent(filename)
                    try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); written.append(url)
                }
            } catch { for url in written { try? FileManager.default.removeItem(at: url) }; throw error }
            return PreparedBackup(records: records, categories: categories, writtenFiles: written)
        }.value
        do { try store.importBackup(records: prepared.records, categories: prepared.categories, replacing: replacing) }
        catch {
            await Task.detached(priority: .utility) { for url in prepared.writtenFiles { try? FileManager.default.removeItem(at: url) } }.value
            throw error
        }
    }
    nonisolated private static func signature(_ record: ThoughtRecord) -> String {
        record.status.rawValue + "|" + String(record.tagId) + "|" + record.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    nonisolated private static func validColour(_ value: String?) -> Bool {
        guard let value else { return true }
        let text = value.hasPrefix("#") ? String(value.dropFirst()) : value
        return text.count == 6 && text.allSatisfy { $0.isHexDigit }
    }
    private struct PreparedBackup: Sendable {
        let records: [ThoughtRecord]
        let categories: [ThoughtCategory]?
        let writtenFiles: [URL]
    }
    enum BackupError: LocalizedError {
        case tooLarge, unsupportedVersion, invalidBackup, invalidAttachment
        nonisolated var errorDescription: String? {
            switch self {
            case .tooLarge: return "This backup exceeds the 200 MB limit."
            case .unsupportedVersion: return "This backup was made by a newer version of BrainDump. Update the app before restoring it."
            case .invalidBackup: return "This backup contains invalid thought or category data. Your existing thoughts have not changed."
            case .invalidAttachment: return "An attachment is missing or invalid. Your existing thoughts have not changed."
            }
        }
    }
}
