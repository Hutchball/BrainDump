import Foundation
import Testing
@testable import BrainDump

@MainActor
struct ProStoreTests {
    #if DEBUG
    @Test func testUnlockPersistsAndCanReturnToFreeWithoutRemovingThoughts() async throws {
        let name = "ProStoreTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        let pro = ProStore(defaults: defaults, observeTransactions: false)
        let store = ThoughtStore(directory: directory, defaults: defaults)
        store.creationHasPro = { pro.hasPro }
        for index in 0..<25 { _ = try store.capture(text: "Thought \(index)") }
        #expect(!store.canCreateThought)
        pro.setTestUnlock(true)
        #expect(store.canCreateThought)
        _ = try store.capture(text: "Unlocked thought")
        await pro.refreshEntitlements()
        #expect(pro.hasPro)
        let relaunched = ProStore(defaults: defaults, observeTransactions: false)
        #expect(relaunched.testUnlockEnabled)
        #expect(relaunched.hasPro)
        pro.setTestUnlock(false)
        #expect(!pro.hasPro)
        #expect(!store.canCreateThought)
        #expect(store.activeThoughts.count == 26)
        #expect(!ProStore(defaults: defaults, observeTransactions: false).testUnlockEnabled)
    }
    #endif
}
