import Foundation
import CoreTransferable
import ImageIO
import UniformTypeIdentifiers

/// Decodes bounded images off the UI thread and strips incidental metadata on export.
enum AttachmentStore {
    nonisolated static func prepareImage(_ data: Data, maximumInputBytes: Int = 30 * 1_024 * 1_024) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard data.count <= min(maximumInputBytes, 40 * 1_024 * 1_024) else { throw ImportError.tooLarge }
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let type = CGImageSourceGetType(source), UTType(type as String)?.conforms(to: .image) == true,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 30_000, height <= 30_000, width * height <= 100_000_000 else { throw ImportError.invalidImage }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                           kCGImageSourceCreateThumbnailWithTransform: true,
                                           kCGImageSourceThumbnailMaxPixelSize: 4_096,
                                           kCGImageSourceShouldCacheImmediately: true]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ImportError.invalidImage }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw ImportError.invalidImage }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination), output.length <= 40 * 1_024 * 1_024 else { throw ImportError.tooLarge }
            return output as Data
        }.value
    }

    nonisolated static func imagePreview(at url: URL, maximumSize: Int = 1_600) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: maximumSize] as CFDictionary) else { return nil }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return data as Data
        }.value
    }

    /// Attachment names are generated locally; imported backup names must never escape their directory.
    nonisolated static func isSafeFilename(_ filename: String) -> Bool {
        !filename.isEmpty && filename != "." && filename != ".." && !filename.contains("/") && !filename.contains("\\") && !filename.contains(":") && !filename.contains("\0") && filename.utf8.count <= 255
    }

    nonisolated static func webURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }

    enum ImportError: LocalizedError {
        case tooLarge, invalidImage
        nonisolated var errorDescription: String? {
            switch self {
            case .tooLarge: return "This image is too large. Choose an image under 30 MB with fewer than 100 million pixels."
            case .invalidImage: return "This file could not be read as an image. Try another screenshot or photo."
            }
        }
    }
}

/// File transfer checks the input size before bringing a selected photo into memory.
nonisolated struct ImportedPhoto: Transferable, Sendable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let size = (try received.file.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            guard size > 0, size <= 30 * 1_024 * 1_024 else { throw AttachmentStore.ImportError.tooLarge }
            return ImportedPhoto(data: try Data(contentsOf: received.file))
        }
    }
}
