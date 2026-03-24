import StoreKit
import Foundation

/// Manages App Store subscriptions using StoreKit 2.
/// Product IDs must match exactly what is configured in App Store Connect.
@MainActor
final class StoreKitService: ObservableObject {

    // MARK: - Product IDs

    static let monthlyID = "com.arman.sqlacademy.plus.monthly"
    static let yearlyID  = "com.arman.sqlacademy.plus.yearly"
    static let allProductIDs: Set<String> = [monthlyID, yearlyID]

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isPurchasing = false
    @Published var purchaseError: String?

    var isSubscribed: Bool { !purchasedProductIDs.isEmpty }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct: Product?  { products.first { $0.id == Self.yearlyID  } }

    // MARK: - Private

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        transactionListenerTask = startTransactionListener()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            // Sort: monthly first, then yearly
            products = fetched.sorted { p1, _ in p1.id == Self.monthlyID }
            log("Loaded \(fetched.count) products")
        } catch {
            log("Product load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(productID: String) async -> Bool {
        guard let product = products.first(where: { $0.id == productID }) else {
            purchaseError = "Product not available. Please try again."
            return false
        }
        return await purchase(product)
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshSubscriptionStatus()
                await transaction.finish()
                log("Purchase successful: \(product.id)")
                return true
            case .userCancelled:
                log("User cancelled purchase")
                return false
            case .pending:
                log("Purchase pending (Ask to Buy)")
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            log("Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            log("Restore completed. Subscribed: \(isSubscribed)")
        } catch {
            purchaseError = error.localizedDescription
            log("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription Status

    func refreshSubscriptionStatus() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
        log("Active subscriptions: \(active)")
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await refreshSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value):      return value
        }
    }

    private func log(_ msg: String) {
        #if DEBUG
        print("[StoreKit] \(msg)")
        #endif
    }
}
