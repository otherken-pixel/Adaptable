import Foundation

/// Guideline 3.1.2 copy. Never claims a price is on screen unless StoreKit
/// actually supplied a localized `displayPrice`.
enum PaywallCopy {
    static let missingPriceLegal =
        "Subscription prices load from the App Store and appear on the plan cards when available."

    static func legalText(lengthLabel: String?, displayPrice: String?) -> String {
        let priceBit: String
        if let lengthLabel, let displayPrice, !displayPrice.isEmpty, !lengthLabel.isEmpty {
            priceBit = "The \(lengthLabel) plan is \(displayPrice)."
        } else {
            priceBit = missingPriceLegal
        }
        return """
        \(priceBit) Payment is charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at the same price. Manage or cancel in Settings → Apple ID → Subscriptions. Any unused portion of a free trial is forfeited when you buy a subscription.
        """
    }
}
