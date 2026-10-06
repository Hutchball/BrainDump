import Foundation
import CloudKit
import Combine

/// Read the signed provisioning profile when available; TestFlight/App Store use Production.
private enum CloudEnvironment {
    static var current: String {
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url),
           let start = data.range(of: Data("<?xml".utf8)),
           let end = data.range(of: Data("</plist>".utf8)),
           start.lowerBound < end.upperBound,
           let profile = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
           let entitlements = profile["Entitlements"] as? [String: Any],
           let environment = entitlements["com.apple.developer.icloud-container-environment"] as? String {
            return environment
        }
        #if DEBUG
        return "Development"
        #else
        return "Production"
        #endif
    }
}

/// CloudKit schedules work and retries transient failures; local capture never waits for it.
@MainActor
final class CloudSyncService: ObservableObject, CKSyncEngineDelegate {
    enum IndicatorState { case waiting, syncing, upToDate }
    var indicatorState: IndicatorState {
        if status == "Syncing with iCloud" { return .syncing }
        if status == "Up to date with iCloud" { return .upToDate }
        return .waiting
    }
    @Published private(set) var status = "Saved on this device" {
        didSet {
            if status.hasPrefix("Saved locally ·") { lastIssue = status; cycleFailed = true }
        }
    }
    let environment = CloudEnvironment.current
    @Published private(set) var uploadedRecords = 0
    @Published private(set) var downloadedRecords = 0
    @Published private(set) var lastSuccessfulSync: Date?
    private var lastIssue = "Waiting for iCloud"
    private var requestedSync: Task<Void, Never>?
    private var syncing = false
    private var syncRequested = false
    private var operationCount = 0
    private var cycleFailed = false
    private let store: ThoughtStore
    private let zoneID = CKRecordZone.ID(zoneName: "BrainDumpThoughts")
    private var engine: CKSyncEngine?
    private var accountBlocked = false

    init(store: ThoughtStore) {
        self.store = store; accountBlocked = store.accountSyncPaused
        if accountBlocked { status = "iCloud account changed · sync paused; local thoughts are safe" }
    }
    func start() {
        #if targetEnvironment(simulator)
        // Unsigned simulator builds cannot instantiate CKContainer without entitlements.
        status = "Saved on this simulator · iCloud requires a signed device"
        return
        #else
        guard engine == nil, !accountBlocked else { return }
        do { try store.prepareCloudSync(environment: environment) }
        catch { status = "Saved locally · " + error.localizedDescription; return }
        let state = store.syncState.flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
        let configuration = CKSyncEngine.Configuration(database: CKContainer(identifier: "iCloud.BonkersBonk.BrainDump").privateCloudDatabase, stateSerialization: state, delegate: self)
        let engine = CKSyncEngine(configuration); self.engine = engine
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        store.didChange = { [weak self] ids in self?.enqueue(ids) }
        enqueue(store.pendingIDs)
        Task {
            do {
                let account = try await CKContainer(identifier: "iCloud.BonkersBonk.BrainDump").accountStatus()
                switch account {
                case .available: requestSync()
                case .noAccount: status = "Saved on this device · sign in to iCloud to sync"
                case .restricted: status = "Saved on this device · iCloud access is restricted"
                case .couldNotDetermine, .temporarilyUnavailable: status = "Saved on this device · iCloud is unavailable"
                @unknown default: status = "Saved on this device · iCloud is unavailable"
                }
            } catch { status = "Saved on this device · " + error.localizedDescription }
        }
        #endif
    }
    /// Explicit user action: sync the retained local collection with the current account.
    func resumeWithCurrentAccount() throws {
        try store.resumeAccountSync(); accountBlocked = false; engine = nil; start()
    }
    /// Rebuild only cloud bookkeeping; retain every local thought and tombstone.
    func rebuildSync() async throws {
        guard !accountBlocked, !syncing, operationCount == 0 else { return }
        requestedSync?.cancel(); requestedSync = nil
        let previous = engine
        engine = nil // Ignore events from the old engine before resetting durable metadata.
        await previous?.cancelOperations()
        try store.prepareCloudSync(environment: environment, force: true)
        start()
        await syncNow()
    }
    func enqueue(_ ids: Set<String>) {
        guard !accountBlocked, let engine else { return }
        engine.state.add(pendingRecordZoneChanges: ids.map { .saveRecord(CKRecord.ID(recordName: $0, zoneID: zoneID)) })
        if !ids.isEmpty {
            if operationCount == 0 { status = "Waiting for iCloud" }
            requestSync()
        }
    }
    /// Coalesce saves in one main-actor turn; never poll or spin on a failed request.
    func requestSync() {
        guard !accountBlocked, engine != nil else { return }
        syncRequested = true
        guard requestedSync == nil, !syncing else { return }
        requestedSync = Task { [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.requestedSync = nil
            await self.syncNow()
        }
    }
    func syncNow() async {
        guard !accountBlocked, let engine else { return }
        if syncing { syncRequested = true; return }
        syncing = true
        defer { syncing = false }
        repeat {
            syncRequested = false
            cycleFailed = false
            status = "Syncing with iCloud"
            do {
                // Upload even if downloading fails, and download even if uploading fails.
                do { try await engine.sendChanges() }
                catch { cycleFailed = true; status = "Saved locally · " + error.localizedDescription }
                guard !accountBlocked, self.engine === engine else { return }
                do { try await engine.fetchChanges() }
                catch { cycleFailed = true; status = "Saved locally · " + error.localizedDescription }
                guard !accountBlocked, self.engine === engine else { return }
                if !cycleFailed && store.pendingIDs.isEmpty { lastSuccessfulSync = Date() }
                status = cycleFailed ? lastIssue : (store.pendingIDs.isEmpty ? "Up to date with iCloud" : "Waiting for iCloud")
            }
        } while syncRequested && !cycleFailed && !accountBlocked
    }
    nonisolated func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { id in await self.makeRecord(id) }
    }
    private func makeRecord(_ id: CKRecord.ID) -> CKRecord? {
        guard !accountBlocked else { return nil }
        if id.recordName.hasPrefix("category:"), let category = store.tags.first(where: { "category:\($0.id)" == id.recordName }), let payload = try? JSONEncoder().encode(category) {
            let record = store.cloudRecordData(id: id.recordName).flatMap(Self.decodeSystemFields) ?? CKRecord(recordType: "Category", recordID: id)
            record["payload"] = payload as CKRecordValue
            return record
        }
        guard !accountBlocked, let thought = store.thought(id: id.recordName), let payload = try? JSONEncoder().encode(thought) else { return nil }
        let record = store.cloudRecordData(id: thought.id).flatMap(Self.decodeSystemFields) ?? CKRecord(recordType: "Thought", recordID: id)
        record["payload"] = payload as CKRecordValue
        let previous = store.cloudAttachmentSlots(id: thought.id)
        let filenames = thought.attachments.map(\.filename)
        for index in 0..<10 {
            let filename = index < filenames.count ? filenames[index] : nil
            let prior: String? = previous.flatMap { index < $0.count ? $0[index] : nil }
            // Unchanged image fields stay untouched; editing text doesn't resend screenshots.
            if previous != nil && filename == prior { continue }
            let key = "asset_\(index)"
            guard let filename else { record[key] = nil; continue }
            guard AttachmentStore.isSafeFilename(filename) else { return nil }
            let url = store.attachmentDirectory.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                status = "Saved locally · an image is unavailable for upload"
                return nil
            }
            record[key] = CKAsset(fileURL: url)
        }
        return record
    }
    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await process(event, engine: syncEngine)
    }
    private func process(_ event: CKSyncEngine.Event, engine: CKSyncEngine) async {
        // Ignore callbacks from an engine replaced after an account change.
        guard self.engine === engine else { return }
        do {
            switch event {
            case .stateUpdate(let update): try store.saveSyncState(JSONEncoder().encode(update.stateSerialization))
            case .fetchedRecordZoneChanges(let changes):
                for change in changes.modifications {
                    try await receive(change.record)
                    downloadedRecords += 1
                }
                // App deletions use durable status tombstones, rather than physical record removal.
            case .sentRecordZoneChanges(let changes):
                uploadedRecords += changes.savedRecords.count
                for record in changes.savedRecords {
                    let sent = (record["payload"] as? Data).flatMap { try? JSONDecoder().decode(ThoughtRecord.self, from: $0) }
                    try store.acknowledge(id: record.recordID.recordName, systemFields: Self.encodeSystemFields(record), sentModifiedAt: sent?.modifiedAt ?? (record["payload"] as? Data).flatMap { try? JSONDecoder().decode(ThoughtCategory.self, from: $0) }?.modifiedAt, attachmentSlots: sent?.attachments.map(\.filename))
                }
                for failure in changes.failedRecordSaves {
                    if failure.error.code == .serverRecordChanged, let server = failure.error.serverRecord {
                        try await receive(server)
                        enqueue(store.pendingIDs)
                    } else if failure.error.code == .zoneNotFound {
                        try store.requeueAllCloudRecords()
                        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))]); enqueue(store.pendingIDs)
                    } else if failure.error.code == .unknownItem {
                        try store.resetCloudRecord(id: failure.record.recordID.recordName)
                        enqueue(store.pendingIDs)
                    } else { cycleFailed = true; status = "Saved locally · " + failure.error.localizedDescription }
                }
                // A successful upload may have raced with a newer local edit. The
                // engine removes the sent change; schedule the durable newer version.
                if !changes.savedRecords.isEmpty { enqueue(store.pendingIDs) }
                if !changes.failedRecordSaves.isEmpty { cycleFailed = true }
            case .sentDatabaseChanges(let changes):
                if let failure = changes.failedZoneSaves.first { cycleFailed = true; status = "Saved locally · " + failure.error.localizedDescription }
            case .accountChange(let change):
                // Never upload one account's local collection automatically into another account.
                switch change.changeType {
                case .signIn: if !accountBlocked { enqueue(store.pendingIDs) }
                case .signOut, .switchAccounts:
                    accountBlocked = true; try store.pauseAccountSync(); status = "iCloud account changed · sync paused; local thoughts are safe"
                @unknown default:
                    accountBlocked = true; try store.pauseAccountSync()
                    status = "iCloud account changed · sync paused; local thoughts are safe"
                }
            case .willSendChanges, .willFetchChanges:
                if operationCount == 0 && !syncing { cycleFailed = false }
                operationCount += 1
                status = "Syncing with iCloud"
            case .didSendChanges, .didFetchChanges:
                operationCount = max(0, operationCount - 1)
                if operationCount == 0 && !syncing && !accountBlocked {
                    status = cycleFailed ? lastIssue : (store.pendingIDs.isEmpty ? "Up to date with iCloud" : "Waiting for iCloud")
                }
            case .didFetchRecordZoneChanges(let result): if let error = result.error { cycleFailed = true; status = "Saved locally · " + error.localizedDescription }
            default: break
            }
        } catch { cycleFailed = true; status = "Saved locally · " + error.localizedDescription }
    }
    private func receive(_ record: CKRecord) async throws {
        guard !accountBlocked else { return }
        guard record.recordType == "Thought" || record.recordType == "Category" else { return }
        guard let data = record["payload"] as? Data else {
            throw NSError(domain: "BrainDump.CloudSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "An iCloud record has no readable payload. Sync needs recovery."])
        }
        if record.recordType == "Category" {
            try store.mergeRemoteCategory(JSONDecoder().decode(ThoughtCategory.self, from: data), systemFields: Self.encodeSystemFields(record)); return
        }
        let thought = try JSONDecoder().decode(ThoughtRecord.self, from: data)
        guard thought.attachments.count <= 10 else { throw ThoughtStore.ValidationError.tooManyAttachments }
        let copies: [(URL, URL)] = thought.attachments.enumerated().compactMap { index, attachment in
            guard let filename = attachment.filename, AttachmentStore.isSafeFilename(filename),
                  let asset = record["asset_\(index)"] as? CKAsset, let source = asset.fileURL else { return nil }
            return (source, store.attachmentDirectory.appendingPathComponent(filename))
        }
        try await Task.detached(priority: .utility) {
            for (source, destination) in copies where !FileManager.default.fileExists(atPath: destination.path) {
                let size = (try source.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
                guard size > 0, size <= 40 * 1_024 * 1_024 else { throw AttachmentStore.ImportError.tooLarge }
                let sanitised = try await AttachmentStore.prepareImage(Data(contentsOf: source), maximumInputBytes: 40 * 1_024 * 1_024)
                try sanitised.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }.value
        try store.mergeRemote(thought, systemFields: Self.encodeSystemFields(record))
    }
    private static func encodeSystemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true); record.encodeSystemFields(with: coder); coder.finishEncoding(); return coder.encodedData
    }
    private static func decodeSystemFields(_ data: Data) -> CKRecord? {
        guard let coder = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        coder.requiresSecureCoding = true; defer { coder.finishDecoding() }; return CKRecord(coder: coder)
    }
}
