import Foundation
import StoreKit

@Observable
final class StoreKitService {

    // MARK: - Constants

    static let proMonthlyProductID = "com.faremint.pro.monthly"
    static let freeTripsLimit = 2

    // MARK: - State

    var proProduct: Product?
    var isProSubscribed = false
    var purchaseInProgress = false
    var errorMessage: String?

    /// Set externally by FaremintApp when the signed-in user's email changes.
    var currentUserEmail: String? {
        didSet {
            // When the user signs out (email becomes nil) or switches accounts,
            // immediately revoke Pro access so stale status is never shown to
            // the new user. updateSubscriptionStatus() will re-check entitlements
            // for the new account after login.
            if currentUserEmail == nil {
                isProSubscribed = false
            }
        }
    }

    // MARK: - Computed

    /// Single source of truth: paying subscriber.
    var isProUser: Bool {
        isProSubscribed
    }

    /// Returns true if the user can create another trip (Pro users always can).
    func canAddTrip(currentTripCount: Int) -> Bool {
        isProUser || currentTripCount < Self.freeTripsLimit
    }

    // MARK: - Init

    init() {
        // Start listening for transaction updates immediately. The task is fire-and-forget;
        // StoreKitService is an app-lifetime singleton so cleanup is not needed.
        Task { [weak self] in
            await self?.loadProducts()
            await self?.updateSubscriptionStatus()
        }
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if let transaction = try? Self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Product loading

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proMonthlyProductID])
            await MainActor.run { proProduct = products.first }
        } catch {
            await MainActor.run { errorMessage = "Failed to load products." }
        }
    }

    // MARK: - Purchase

    func purchasePro() async {
        guard let product = proProduct else { return }
        await MainActor.run { purchaseInProgress = true; errorMessage = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                await MainActor.run { errorMessage = "Purchase is pending approval." }
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { errorMessage = "Purchase failed: \(error.localizedDescription)" }
        }
        await MainActor.run { purchaseInProgress = false }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            await MainActor.run { errorMessage = "Restore failed: \(error.localizedDescription)" }
        }
    }

    // MARK: - Subscription status

    func updateSubscriptionStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.productID == Self.proMonthlyProductID,
               transaction.revocationDate == nil {
                hasActive = true
                break
            }
        }
        await MainActor.run { isProSubscribed = hasActive }
    }

    // MARK: - Verification helper

    nonisolated static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }
}
