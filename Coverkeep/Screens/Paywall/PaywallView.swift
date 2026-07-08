import SwiftUI
import StoreKit
import KeepCore

/// The Coverkeep Pro paywall. "Hard-ish": it blocks adding an 11th item,
/// never access to existing data — every stored item stays full-featured.
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    productButtons
                    footer
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .task {
                if purchases.products.isEmpty {
                    await purchases.loadProducts()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coverkeep Pro")
                .font(.largeTitle.bold())
            Text("The free vault holds \(FreeTier.maxItems) items, full-featured. Pro removes the limit.")
                .foregroundStyle(.secondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Unlimited items", systemImage: "infinity")
            Label("Every EU right computed with sources, on every item", systemImage: "checkmark.seal")
            Label("No account, no server — your documents stay in your iCloud", systemImage: "lock")
            Label("Full export, always free", systemImage: "square.and.arrow.up")
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var productButtons: some View {
        if purchases.products.isEmpty && purchases.lastError == nil {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else {
            VStack(spacing: 10) {
                ForEach(purchases.products, id: \.id) { product in
                    productButton(product)
                }
            }
        }
    }

    private func productButton(_ product: Product) -> some View {
        Button {
            Task {
                await purchases.purchase(product)
                if purchases.isEntitled {
                    dismiss()
                }
            }
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(product.displayName)
                        .bold()
                    if product.id == CoverkeepProducts.annual {
                        Text("BEST VALUE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.2), in: Capsule())
                    }
                }
                Text(priceLabel(for: product))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Restore Purchases") {
                Task { await purchases.restore() }
            }
            .font(.subheadline)
            if let error = purchases.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("Subscriptions renew automatically until cancelled. Manage them in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: LegalLinks.privacyPolicy)
                Link("Terms of Use", destination: LegalLinks.terms)
            }
            .font(.caption)
        }
    }

    private func priceLabel(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return String(localized: "\(product.displayPrice) · one-time purchase")
        }
        switch period.unit {
        case .year: return String(localized: "\(product.displayPrice) / year")
        case .month: return String(localized: "\(product.displayPrice) / month")
        case .week: return String(localized: "\(product.displayPrice) / week")
        case .day: return String(localized: "\(product.displayPrice) / day")
        @unknown default: return product.displayPrice
        }
    }
}
