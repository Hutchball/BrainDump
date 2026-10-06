import StoreKit
import Combine

@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()
    static let monthlyID = "BonkersBonk.BrainDump.pro.monthly.v2"
    static let lifetimeID = "BonkersBonk.BrainDump.pro.lifetime.v2"
    static let productIDs = [monthlyID, lifetimeID]
    static let freeTileLimit = 25

    @Published private(set) var hasPro = false
    @Published private(set) var hasSandboxEntitlement = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var busy = false
    @Published private(set) var loading = false
    @Published private(set) var eligibleForTrial = false
    @Published var message: String?
    private var verifiedPro = false
    #if DEBUG
    private let testingDefaults: UserDefaults
    @Published private(set) var testUnlockEnabled: Bool

    func setTestUnlock(_ enabled: Bool) {
        testUnlockEnabled = enabled
        testingDefaults.set(enabled, forKey: "debugProUnlock")
        hasPro = verifiedPro || enabled
    }
    #endif
    private var updates: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, observeTransactions: Bool = true) {
        #if DEBUG
        testingDefaults = defaults
        testUnlockEnabled = defaults.bool(forKey: "debugProUnlock")
        hasPro = testUnlockEnabled
        #endif
        guard observeTransactions else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result,
                   Self.productIDs.contains(transaction.productID) {
                    await self.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
    deinit { updates?.cancel() }

    func refreshEntitlements() async {
        var unlocked = false
        var sandbox = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                unlocked = true
                sandbox = sandbox || transaction.environment == .sandbox
            }
        }
        hasSandboxEntitlement = sandbox
        verifiedPro = unlocked
        #if DEBUG
        hasPro = unlocked || testUnlockEnabled
        #else
        hasPro = unlocked
        #endif
    }

    func load() async {
        guard !loading, !busy else { return }
        loading = true
        eligibleForTrial = false
        defer { loading = false }
        message = nil
        await refreshEntitlements()
        do {
            products = try await Product.products(for: Self.productIDs)
            if let subscription = products.first(where: { $0.id == Self.monthlyID })?.subscription {
                eligibleForTrial = await subscription.isEligibleForIntroOffer
            }
            if products.count < Self.productIDs.count { message = "Some purchase options are unavailable right now. Please refresh to try again." }
        } catch { message = "Couldn’t load purchase options. Please try again." }
    }

    func purchase(_ product: Product) async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    message = "The purchase couldn’t be verified. Please restore purchases or try again."; return
                }
                await refreshEntitlements()
                await transaction.finish()
            case .pending: message = "Your purchase is awaiting approval. Pro will unlock when it’s approved."
            case .userCancelled: break
            @unknown default: message = "Please try again."
            }
        } catch { message = "The purchase couldn’t be completed. Please try again." }
    }

    func restore() async {
        guard !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = hasPro ? "Pro restored. Welcome back!" : "No Pro purchase was found for this Apple Account."
        } catch { message = "Couldn’t restore purchases. Please try again." }
    }
}
