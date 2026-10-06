import SwiftUI
import Combine
import UIKit
import Foundation
import UniformTypeIdentifiers
import QuartzCore
import UserNotifications
import CryptoKit
import Darwin

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    enum Mode {
        case importFile
        case exportFile
    }

    let mode: Mode
    let exportData: Data?
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        switch mode {
        case .importFile:
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.data, .bduBackup, .bdpBackup],
                asCopy: true
            )
            picker.delegate = context.coordinator
            return picker
        case .exportFile:
            let data = exportData ?? Data()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("BrainDump.bdu")
            try? data.write(to: tempURL, options: .atomic)
            let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
            picker.delegate = context.coordinator
            return picker
        }
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            } else {
                onCancel()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Haptics

enum Haptics {
    private static let enabledKey = "HapticsEnabled"

    private static var isEnabled: Bool {
        if let stored = UserDefaults.standard.object(forKey: enabledKey) as? Bool {
            return stored
        }
        return true
    }

    static func optionTap() {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selectionChange() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func negativeDoubleTap() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Display Link Driver

final class DisplayLinkDriver {
    var displayLink: CADisplayLink?
    var onStep: ((CFTimeInterval) -> Void)?

    func start(preferredFPS: Int) {
        stop()
        let link = CADisplayLink(target: self, selector: #selector(step))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 30,
                maximum: Float(preferredFPS),
                preferred: Float(preferredFPS)
            )
        } else {
            link.preferredFramesPerSecond = preferredFPS
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        onStep?(link.timestamp)
    }
}
