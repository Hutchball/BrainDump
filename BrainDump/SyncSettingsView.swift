import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject private var sync: CloudSyncService
    @ObservedObject private var store = ThoughtStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var confirmAccount = false
    @State private var confirmRebuild = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("iCloud") {
                    Label(sync.status, systemImage: "icloud").labelStyle(SettingsLabelStyle())
                    if let storageError = store.storageError {
                        Label(storageError, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                    Text("Thoughts save on this device first. Changes and images sync automatically when iCloud is available.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if store.accountSyncPaused {
                        Button("Resume with current iCloud account") { confirmAccount = true }
                    } else {
                        Button("Sync now") {
                            busy = true
                            Task { await sync.syncNow(); busy = false }
                        }.disabled(busy)
                    }
                    if busy { ProgressView() }
                    LabeledContent("Cloud environment", value: sync.environment)
                    LabeledContent("Active tiles on this device", value: String(store.activeThoughts.count))
                    LabeledContent("Changes waiting to upload", value: String(store.pendingIDs.count))
                    LabeledContent("Records uploaded this session", value: String(sync.uploadedRecords))
                    LabeledContent("Records received this session", value: String(sync.downloadedRecords))
                    if let date = sync.lastSuccessfulSync {
                        LabeledContent("Last successful check") { Text(date, style: .time) }
                    }
                    Text("Green means this device completed its latest check. It does not confirm delivery to your other devices.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Rebuild iCloud sync") { confirmRebuild = true }
                        .disabled(busy || store.accountSyncPaused || sync.indicatorState == .syncing)
                }
                Section {
                    NavigationLink("Export or restore a backup") { BackupSettingsView() }
                }
            }
            .navigationTitle("Sync and backups")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Rebuild iCloud sync?", isPresented: $confirmRebuild, titleVisibility: .visible) {
                Button("Upload retained thoughts and download iCloud records") {
                    busy = true
                    Task {
                        do { try await sync.rebuildSync() }
                        catch { self.error = error.localizedDescription }
                        busy = false
                    }
                }
            } message: {
                Text("Keeps your local thoughts and categories, queues them for upload, and downloads the cloud collection again. Use the same iCloud account on both devices.")
            }
            .confirmationDialog("Use the current iCloud account?", isPresented: $confirmAccount, titleVisibility: .visible) {
                Button("Sync local thoughts with this account") {
                    do { try sync.resumeWithCurrentAccount() }
                    catch { self.error = error.localizedDescription }
                }
            } message: { Text("This uploads thoughts retained on this device to your current iCloud account and downloads its thoughts.") }
            .alert("Couldn’t resume sync", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}
