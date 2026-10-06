import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject private var sync: CloudSyncService
    @ObservedObject private var store = ThoughtStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var confirmAccount = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("iCloud") {
                    Label(sync.status, systemImage: "icloud")
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
                }
                Section {
                    NavigationLink("Export or restore a backup") { BackupSettingsView() }
                }
            }
            .navigationTitle("Sync and backups")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
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
