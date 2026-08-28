import StoreKit
import SwiftUI

/// App Store subscription paywall for Adaptable Plus.
/// Prices and intro offers come from StoreKit (never hardcoded as the charge).
/// Includes Guideline 3.1.2 items: title, length, price, Privacy, Terms, restore.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptions: SubscriptionStore

    @State private var selectedID = SubscriptionStore.yearlyID
    @State private var purchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        benefits
                        plans
                        afterExpiry
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                footer
            }
            .background(Theme.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 36, height: 36)
                            .background(Theme.sunken, in: Circle())
                    }
                    .accessibilityLabel("Close")
                }
            }
            .task {
                await subscriptions.refresh()
                if subscriptions.product(id: selectedID) == nil {
                    selectedID = subscriptions.yearly?.id
                        ?? subscriptions.monthly?.id
                        ?? selectedID
                }
            }
            .onChange(of: subscriptions.isPlus) { _, plus in
                if plus { dismiss() }
            }
            .alert(
                "Couldn’t complete purchase",
                isPresented: Binding(
                    get: { subscriptions.lastError != nil },
                    set: { if !$0 { subscriptions.lastError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { subscriptions.lastError = nil }
            } message: {
                Text(subscriptions.lastError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.heroGradient)
                .frame(width: 64, height: 64)
                .shadow(color: Theme.accent.opacity(0.25), radius: 16, y: 8)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                )
            Text("ADAPTABLE PLUS")
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(Theme.accent)
            Text("Cook without rationing the AI.")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.4)
            Text("Unlimited generations and imports, with your taste profile on every recipe. Cancel anytime in your Apple ID settings.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("sparkles", "Unlimited AI recipes from a prompt")
            benefit("camera", "Import from a link, photo, or cookbook page")
            benefit("arrow.triangle.2.circlepath", "Remix any recipe to your diet")
            benefit("leaf", "Fridge mode and meal-prep bundles")
        }
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var plans: some View {
        if subscriptions.loadingProducts && subscriptions.products.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if subscriptions.products.isEmpty {
            VStack(spacing: 10) {
                Text("Couldn’t load prices from the App Store.")
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.muted)
                Button("Try again") {
                    Task { await subscriptions.refresh() }
                }
                .font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            VStack(spacing: 10) {
                if let yearly = subscriptions.yearly {
                    planCard(yearly, kind: .yearly)
                }
                if let monthly = subscriptions.monthly {
                    planCard(monthly, kind: .monthly)
                }
            }
        }
    }

    private enum PlanKind { case yearly, monthly }

    private func planCard(_ product: Product, kind: PlanKind) -> some View {
        let selected = selectedID == product.id
        return Button {
            Haptics.selection()
            selectedID = product.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.accent : Theme.faint)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(kind == .yearly ? "Yearly" : "Monthly")
                            .font(.system(size: 17, weight: .heavy))
                        if kind == .yearly, let save = subscriptions.yearlySavingsPercent(), save > 0 {
                            Text("Save \(save)%")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(Theme.surface)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.accent, in: Capsule())
                        }
                    }
                    Text("\(product.displayPrice) / \(SubscriptionStore.periodUnit(product))")
                        .font(.system(size: 15, weight: .bold))
                    Text(planSubtitle(product, kind: kind))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(accessibilityPlan(product, kind: kind))
    }

    private func planSubtitle(_ product: Product, kind: PlanKind) -> String {
        var parts = ["Auto-renews. \(SubscriptionStore.lengthLabel(product))"]
        if kind == .yearly, let eq = subscriptions.yearlyEquivalentMonthly() {
            parts.append("\(eq) / month")
        }
        if let intro = SubscriptionStore.introOfferLabel(for: product) {
            parts.append(intro)
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityPlan(_ product: Product, kind: PlanKind) -> String {
        let name = kind == .yearly ? "Yearly" : "Monthly"
        return "\(name), \(product.displayPrice) per \(SubscriptionStore.periodUnit(product)), \(planSubtitle(product, kind: kind))"
    }

    private var afterExpiry: some View {
        Text("If Plus ends, you keep your cookbook, Cook Mode, and grocery list. AI generation goes back to the free allowance.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                HStack {
                    if purchasing {
                        ProgressView().tint(Theme.surface)
                    }
                    Text(ctaTitle)
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(Theme.surface)
                .background(canBuy ? Theme.content : Theme.content.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(!canBuy || purchasing)
            .accessibilityHint("Charges your Apple ID for Adaptable Plus.")

            Button("Restore purchases") {
                Task { await subscriptions.restore() }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.muted)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: SiteConfig.termsURL)
                Text("·").foregroundStyle(Theme.faint)
                Link("Privacy Policy", destination: SiteConfig.privacyURL)
                Text("·").foregroundStyle(Theme.faint)
                Button("Redeem code") { redeemCode() }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.muted)

            Text(legalCopy)
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Theme.surface)
        .overlay(alignment: .top) { Divider().background(Theme.line) }
    }

    private var selectedProduct: Product? {
        subscriptions.product(id: selectedID) ?? subscriptions.yearly ?? subscriptions.monthly
    }

    private var canBuy: Bool { selectedProduct != nil && !subscriptions.isPlus }

    private var ctaTitle: String {
        if subscriptions.isPlus { return "You’re subscribed" }
        guard let product = selectedProduct else { return "Subscribe" }
        if let intro = SubscriptionStore.introOfferLabel(for: product),
           intro.lowercased().contains("trial") {
            return intro
        }
        return "Subscribe \(product.displayPrice) / \(SubscriptionStore.periodUnit(product))"
    }

    private var legalCopy: String {
        let priceBit: String = {
            guard let product = selectedProduct else {
                return "Price is shown above."
            }
            return "The \(SubscriptionStore.lengthLabel(product)) plan is \(product.displayPrice)."
        }()
        return """
        \(priceBit) Payment is charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at the same price. Manage or cancel in Settings → Apple ID → Subscriptions. Any unused portion of a free trial is forfeited when you buy a subscription.
        """
    }

    private func buy() async {
        guard let product = selectedProduct else { return }
        purchasing = true
        let ok = await subscriptions.purchase(product)
        purchasing = false
        if ok { dismiss() }
    }

    private func redeemCode() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        Task {
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            } catch {
                subscriptions.lastError = error.localizedDescription
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionStore.shared)
}
