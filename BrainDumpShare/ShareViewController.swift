import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let status = UILabel()
    private let save = UIButton(type: .system)
    private let text = UITextView()
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Add to Brain Dump"
        status.text = "Add a thought, link, or screenshot to your inbox."
        status.numberOfLines = 0
        text.font = .preferredFont(forTextStyle: .body)
        text.adjustsFontForContentSizeCategory = true
        text.accessibilityLabel = "Additional thought"
        save.setTitle("Save to Brain Dump", for: .normal)
        save.addTarget(self, action: #selector(saveCapture), for: .touchUpInside)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [status, text, save, cancel])
        stack.axis = .vertical; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            text.heightAnchor.constraint(equalToConstant: 160)])
    }
    @objc private func cancelCapture() { extensionContext?.completeRequest(returningItems: nil) }
    @objc private func saveCapture() {
        guard !started else { return }; started = true; save.isEnabled = false
        Task {
            do {
                guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.BonkersBonk.BrainDump") else { throw CaptureError.unavailable }
                let inbox = group.appendingPathComponent("CaptureInbox", isDirectory: true)
                try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
                let id = UUID().uuidString
                var body = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
                var links: [String] = []; var images: [String] = []
                let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
                guard providers.count <= 10 else { throw CaptureError.tooMany }
                for provider in providers {
                    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        let data = try await loadData(provider, type: UTType.image.identifier)
                        guard data.count <= 30 * 1_024 * 1_024 else { throw CaptureError.tooLarge }
                        let filename = id + "-" + UUID().uuidString + ".image"
                        try data.write(to: inbox.appendingPathComponent(filename), options: .atomic)
                        images.append(filename)
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        let item = try await loadItem(provider, type: UTType.url.identifier)
                        if let url = item as? URL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { links.append(url.absoluteString) }
                    } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        let item = try await loadItem(provider, type: UTType.plainText.identifier)
                        if let value = item as? String { body += (body.isEmpty ? "" : "\n") + value }
                    }
                }
                guard !body.isEmpty || !links.isEmpty || !images.isEmpty else { throw CaptureError.empty }
                guard body.utf8.count <= 1_000_000 else { throw CaptureError.tooLarge }
                let job: [String: Any] = ["id": id, "text": body, "links": links, "images": images]
                let data = try JSONSerialization.data(withJSONObject: job)
                // The JSON is written last: its presence means the capture is complete.
                try data.write(to: inbox.appendingPathComponent(id + ".json"), options: .atomic)
                status.text = "Saved. Your thought will appear when you open Brain Dump."
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                status.text = error.localizedDescription
                started = false; save.isEnabled = true
            }
        }
    }
    private func loadData(_ provider: NSItemProvider, type: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? CaptureError.empty) }
            }
        }
    }
    private func loadItem(_ provider: NSItemProvider, type: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                if let item { continuation.resume(returning: item) }
                else { continuation.resume(throwing: error ?? CaptureError.empty) }
            }
        }
    }
    enum CaptureError: LocalizedError {
        case unavailable, tooLarge, tooMany, empty
        var errorDescription: String? {
            switch self {
            case .unavailable: "Shared capture is unavailable. Open Brain Dump once and try again."
            case .tooLarge: "This item is too large to capture. Images must be under 30 MB."
            case .tooMany: "Share up to 10 items at a time."
            case .empty: "No supported text, web links, or images were found."
            }
        }
    }
}
