import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @ObservedObject private var store = ThoughtStore.shared
    @State private var busy = false
    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingRestore: Data?
    @State private var showingRestoreChoice = false
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                Text("iCloud sync saves changes automatically. A portable backup also protects your thoughts, colours, categories, and images.")
                    .foregroundStyle(.secondary)
                Button("Export backup", systemImage: "square.and.arrow.up") { exportBackup() }
                Button("Restore backup", systemImage: "square.and.arrow.down") { showingImporter = true }
                if busy { ProgressView("Preparing your thoughts…") }
            }
            Section {
                Text("Merging retains your current thoughts. Replacing moves thoughts absent from the backup to Recently Deleted. Both actions sync to your other devices.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backups")
        .disabled(busy)
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .bduBackup, defaultFilename: "BrainDump-\(Date().formatted(.iso8601.year().month().day()))") { result in
            if case .failure(let error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.bduBackup, .bdpBackup, .json, .data]) { result in
            switch result {
            case .success(let url):
                busy = true
                Task {
                    do {
                        pendingRestore = try await Task.detached(priority: .userInitiated) {
                            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                            let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                            guard size <= BackupService.maximumBytes else { throw BackupService.BackupError.tooLarge }
                            return try Data(contentsOf: url)
                        }.value
                        showingRestoreChoice = true
                    } catch { message = error.localizedDescription }
                    busy = false
                }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .confirmationDialog("Restore this backup", isPresented: $showingRestoreChoice, titleVisibility: .visible) {
            Button("Merge with current thoughts") { restore(replacing: false) }
            Button("Replace current thoughts", role: .destructive) { restore(replacing: true) }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        }
        .alert("BrainDump backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }
    private func exportBackup() {
        busy = true
        Task {
            do { exportDocument = BackupDocument(data: try await BackupService.export(store: store)); showingExporter = true }
            catch { message = error.localizedDescription }
            busy = false
        }
    }
    private func restore(replacing: Bool) {
        guard let data = pendingRestore else { return }
        pendingRestore = nil; busy = true
        Task {
            do { try await BackupService.restore(data: data, replacing: replacing, store: store); message = "Your backup has been restored on this device. Changes will sync when iCloud is available." }
            catch { message = error.localizedDescription }
            busy = false
        }
    }
}
