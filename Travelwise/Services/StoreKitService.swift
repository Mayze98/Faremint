import Foundation
import StoreKit

@Observable
@MainActor
final class StoreKitService {

    // MARK: - Constants

    static let proMonthlyProductID = "com.travelwise.pro.monthly"
    private static let superuserEmail = "yzafc888@gmail.com"

    // MARK: - State

    var proProduct: Product?
    var isProSubscribed = false
    var purchaseInProgress = false
    var errorMessage: String?

    /// Set externally by TravelwiseApp when the signed-in user's email changes.
    var currentUserEmail: String?

    // MARK: - Computed

    var isSuperuser: Bool {
        guard let email = currentUserEmail else { return false }
        return email.lowercased() == Self.superuserEmail.lowercased()
    }

    /// Single source of truth: paying subscriber OR hardcoded superuser.
    var isProUser: Bool {
        isSuperuser || isProSubscribed
    }

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?

    // MARK: - Init / deinit

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product loading

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proMonthlyProductID])
            proProduct = products.first
        } catch {
            errorMessage = "Failed to load products."
        }
    }

    // MARK: - Purchase

    func purchasePro() async {
        guard let product = proProduct else { return }
        purchaseInProgress = true
        errorMessage = nil
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Subscription status

    func updateSubscriptionStatus() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.proMonthlyProductID,
               transaction.revocationDate == nil {
                hasActive = true
                break
            }
        }
        isProSubscribed = hasActive
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Verification helper

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }
}
