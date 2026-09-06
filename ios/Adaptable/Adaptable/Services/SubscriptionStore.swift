import Foundation
import StoreKit
import Supabase

/// StoreKit 2 subscriptions for Adaptable Plus.
///
/// App Store Connect (same subscription group, same rank):
///   `adaptable_monthly`  — 1 month, $4.99
///   `adaptable_annual`   — 1 year,  $39.99
/// Attach a 7-day free intro on yearly in Connect if you want a trial;
/// the paywall reads it from StoreKit and will not claim a trial otherwise.
@MainActor
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()
    private init() {}

    static let monthlyID = "adaptable_monthly"
    static let yearlyID = "adaptable_annual"
    static let productIDs: Set<String> = [monthlyID, yearlyID]

    @Published private(set) var monthly: Product?
    @Published private(set) var yearly: Product?
    @Published private(set) var isPlus = false
    @Published private(set) var currentProductID: String?
    @Published private(set) var loadingProducts = false
    @Published var lastError: String?
    /// Presented from `RootView` as a fullScreenCover so iPad's floating tab bar
    /// cannot swallow the paywall the way a child `.sheet` can.
    @Published var isPaywallPresented = false

    private var listener: Task<Void, Never>?

    var products: [Product] {
        [yearly, monthly].compactMap { $0 }
    }

    func start() {
        guard listener == nil else { return }
        listener = Task { await listenForTransactions() }
        Task { await refresh() }
        // reportEntitlementToServer no-ops without a session. Re-run after
        // sign-in so an existing Plus subscriber is not stuck on the free cap.
        if !SupabaseManager.isDemo {
            Task { await listenForAuthAndReport() }
        }
    }

    /// Opens the StoreKit paywall. Always presents a real UI — never a silent no-op.
    func presentPaywall() {
        lastError = nil
        isPaywallPresented = true
        Task { await refresh() }
    }

    func refresh() async {
        loadingProducts = true
        lastError = nil
        defer { loadingProducts = false }
        do {
            let found = try await Product.products(for: Self.productIDs)
            yearly = found.first { $0.id == Self.yearlyID }
            monthly = found.first { $0.id == Self.monthlyID }
            if found.isEmpty {
                lastError = "Subscriptions are not available yet. Try again in a moment."
            }
            await updateEntitlement()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// Returns true when the user is entitled (purchase finished).
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateEntitlement()
                Haptics.success()
                return isPlus
            case .userCancelled:
                return false
            case .pending:
                lastError = "This purchase is pending approval. You’ll get Plus when it’s approved."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        lastError = nil
        do {
            try await AppStore.sync()
            await updateEntitlement()
            if !isPlus {
                lastError = "No active subscription found for this Apple ID."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func yearlySavingsPercent() -> Int? {
        guard let monthly, let yearly else { return nil }
        let billedMonthly = monthly.price * 12
        guard billedMonthly > 0, yearly.price < billedMonthly else { return nil }
        let saved = billedMonthly - yearly.price
        let percent = (saved / billedMonthly) * 100
        return NSDecimalNumber(decimal: percent).intValue
    }

    func yearlyEquivalentMonthly() -> String? {
        guard let yearly else { return nil }
        let perMonth = yearly.price / 12
        return perMonth.formatted(yearly.priceFormatStyle)
    }

    static func introOfferLabel(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        switch offer.paymentMode {
        case .freeTrial:
            return "Start \(periodPhrase(offer.period)) free trial"
        case .payAsYouGo:
            return "Then \(product.displayPrice) per \(periodUnit(product))"
        case .payUpFront:
            return "Introductory price \(offer.displayPrice)"
        default:
            return nil
        }
    }

    static func periodPhrase(_ period: Product.SubscriptionPeriod) -> String {
        let n = period.value
        switch period.unit {
        case .day: return n == 1 ? "1-day" : "\(n)-day"
        case .week: return n == 1 ? "7-day" : "\(n)-week"
        case .month: return n == 1 ? "1-month" : "\(n)-month"
        case .year: return n == 1 ? "1-year" : "\(n)-year"
        @unknown default: return "\(n)"
        }
    }

    static func periodUnit(_ product: Product) -> String {
        guard let unit = product.subscription?.subscriptionPeriod.unit else { return "period" }
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }

    static func lengthLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        let n = period.value
        switch period.unit {
        case .day: return n == 1 ? "1 day" : "\(n) days"
        case .week: return n == 1 ? "1 week" : "\(n) weeks"
        case .month: return n == 1 ? "1 month" : "\(n) months"
        case .year: return n == 1 ? "1 year" : "\(n) years"
        @unknown default: return ""
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await updateEntitlement()
            }
        }
    }

    private func listenForAuthAndReport() async {
        for await (_, session) in SupabaseManager.client.auth.authStateChanges {
            if session != nil {
                await reportEntitlementToServer()
            }
        }
    }

    private func updateEntitlement() async {
        var entitled = false
        var activeID: String?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                entitled = true
                activeID = transaction.productID
            }
        }
        isPlus = entitled
        currentProductID = activeID
        await reportEntitlementToServer()
    }

    /// Server generate/keep cap reads plus_entitlements, not this isPlus flag.
    private func reportEntitlementToServer() async {
        guard !SupabaseManager.isDemo else { return }
        guard (try? await SupabaseManager.client.auth.session) != nil else { return }

        var jws: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }
            jws = result.jwsRepresentation
            break
        }
        guard let jws else { return }
        do {
            try await API.reportPlusEntitlement(signedTransactionInfo: jws)
        } catch {
            print("[SubscriptionStore] report-plus-entitlement failed: \(error)")
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
