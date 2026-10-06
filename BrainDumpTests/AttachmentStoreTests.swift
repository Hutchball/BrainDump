import Foundation
import ImageIO
import UIKit
import Testing
@testable import BrainDump

@MainActor
struct AttachmentStoreTests {
    @Test func rejectsAttachmentTraversalNames() {
        #expect(!AttachmentStore.isSafeFilename("../secret.png"))
        #expect(!AttachmentStore.isSafeFilename(".."))
        #expect(!AttachmentStore.isSafeFilename("folder\\image.png"))
        #expect(!AttachmentStore.isSafeFilename("file:secret"))
        #expect(AttachmentStore.isSafeFilename("A4F9B7.png"))
    }
    @Test func siriCaptureUsesInboxAndRejectsEmptyDictation() throws {
        let name = "SiriCaptureTests-" + UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { try? FileManager.default.removeItem(at: directory); defaults.removePersistentDomain(forName: name) }
        let store = ThoughtStore(directory: directory, defaults: defaults)
        let intent = AddBrainDumpThoughtIntent()
        intent.thought = "  Remember the appointment \n"
        let saved = try intent.save(to: store)
        #expect(saved.text == "Remember the appointment")
        #expect(saved.tagId == 0)
        #expect(store.thought(id: saved.id) != nil)
        intent.thought = " \n "
        #expect(throws: (any Error).self) { try intent.save(to: store) }
        #expect(store.thoughts.count == 1)
    }
    @Test func rejectsUnsupportedAndCredentialBearingURLs() {
        #expect(AttachmentStore.webURL("javascript:alert(1)") == nil)
        #expect(AttachmentStore.webURL("file:///private/example") == nil)
        #expect(AttachmentStore.webURL("https://name:secret@example.com") == nil)
        #expect(AttachmentStore.webURL(" https://example.com/path?q=hello ")?.host == "example.com")
    }
    @Test func corruptImageDoesNotBecomeAnAttachment() async {
        do {
            _ = try await AttachmentStore.prepareImage(Data("not an image".utf8))
            Issue.record("Corrupt input was accepted")
        } catch { #expect(error is AttachmentStore.ImportError) }
    }
    @Test func oversizeImageIsRejectedBeforeDecode() async {
        do {
            _ = try await AttachmentStore.prepareImage(Data(count: 30 * 1_024 * 1_024 + 1))
            Issue.record("Oversize input was accepted")
        } catch { #expect(error is AttachmentStore.ImportError) }
    }
    @Test func screenshotIsStoredAsReadablePNG() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
            ("Brain Dump" as NSString).draw(at: CGPoint(x: 5, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
        }
        let encoded = try #require(image.pngData())
        let prepared = try await AttachmentStore.prepareImage(encoded)
        let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 100)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 200)
    }
}
