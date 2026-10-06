import Foundation

struct ThoughtAttachment: Identifiable, Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case image, link }
    var id: String = UUID().uuidString
    var kind: Kind
    var filename: String?
    var url: String?
    var title: String?
    var contentType: String?
}

struct ThoughtRecord: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, completed, deleted }
    var id: String = UUID().uuidString
    var text: String
    var tagId: Int = 0
    var status: Status = .active
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var archivedAt: Date?
    var fillHex: String?
    var borderHex: String?
    var attachments: [ThoughtAttachment] = []
}

struct ThoughtCategory: Identifiable, Codable, Equatable, Sendable {
    var id: Int
    var name: String
    var color: String
    var isDefault: Bool
    var fillHex: String?
    var borderHex: String?
    var modifiedAt: Date = Date()
    var isDeleted: Bool?
}

struct ThoughtDatabase: Codable, Equatable, Sendable {
    var version = 1
    var thoughts: [ThoughtRecord] = []
    var tags: [ThoughtCategory] = []
    var pendingIDs: Set<String> = []
    var cloudRecords: [String: Data] = [:]
    var syncState: Data?
    var cloudSyncEnvironment: String?
    var accountSyncPaused: Bool?
    var cloudAttachmentSlots: [String: [String?]]?
}
