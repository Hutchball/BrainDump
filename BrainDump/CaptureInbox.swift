import Foundation

/// Share extensions write complete jobs atomically; only the main app writes the database.
@MainActor
final class CaptureInbox {
    static let shared = CaptureInbox()
    private var importing = false
    /// Returns failed-job descriptions. Failed jobs remain on disk for a later retry.
    func importPending() async -> [String] {
        guard !importing else { return [] }
        importing = true
        defer { importing = false }
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.BonkersBonk.BrainDump") else { return [] }
        let inbox = group.appendingPathComponent("CaptureInbox", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) else { return [] }
        var errors: [String] = []
        for file in files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let data = try Data(contentsOf: file)
                guard data.count < 2_000_000,
                      let job = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id = job["id"] as? String, UUID(uuidString: id) != nil else { throw InboxError.invalid }
                let images = job["images"] as? [String] ?? []
                // Stable IDs make a retry after a crash idempotent.
                if ThoughtStore.shared.thought(id: id) == nil {
                    var attachments: [ThoughtAttachment] = []
                    for filename in images {
                        guard AttachmentStore.isSafeFilename(filename) else { throw InboxError.invalid }
                        let imageData = try Data(contentsOf: inbox.appendingPathComponent(filename))
                        let prepared = try await AttachmentStore.prepareImage(imageData)
                        let stored = try ThoughtStore.shared.importAttachment(data: prepared, extension: "png")
                        attachments.append(ThoughtAttachment(kind: .image, filename: stored, title: "Shared image", contentType: "image/png"))
                    }
                    for value in job["links"] as? [String] ?? [] {
                        if let url = AttachmentStore.webURL(value) {
                            attachments.append(ThoughtAttachment(kind: .link, url: url.absoluteString, title: url.host))
                        }
                    }
                    let text = (job["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallback = attachments.first?.kind == .image ? "Screenshot or image" : attachments.first?.url ?? "Shared thought"
                    try ThoughtStore.shared.update(ThoughtRecord(id: id, text: text.isEmpty ? fallback : text, attachments: attachments))
                }
                try FileManager.default.removeItem(at: file)
                for filename in images where AttachmentStore.isSafeFilename(filename) {
                    try? FileManager.default.removeItem(at: inbox.appendingPathComponent(filename))
                }
            } catch { errors.append(error.localizedDescription) }
        }
        return errors
    }
    private enum InboxError: LocalizedError {
        case invalid
        var errorDescription: String? { "A shared capture could not be read. It has been kept for recovery." }
    }
}
