import Foundation

/// Everything the engine needs to know about a purchase to compute the
/// buyer's protections. Price and currency are only consulted by
/// price-banded rules (e.g. the Hungarian jótállás).
public struct PurchaseContext: Sendable, Equatable {
    /// ISO 3166-1 alpha-2; selects the rule set (EU fallback otherwise).
    public let countryCode: String
    public let channel: PurchaseChannel
    public let purchaseDate: Date
    /// When the goods reached the buyer. Delivery-clock rules (withdrawal,
    /// legal guarantee) fall back to `purchaseDate` when nil and flag the
    /// coverage as assumed.
    public let deliveryDate: Date?
    public let price: Decimal?
    /// ISO 4217 code for `price`.
    public let currencyCode: String?

    public init(
        countryCode: String,
        channel: PurchaseChannel,
        purchaseDate: Date,
        deliveryDate: Date? = nil,
        price: Decimal? = nil,
        currencyCode: String? = nil
    ) {
        self.countryCode = countryCode
        self.channel = channel
        self.purchaseDate = purchaseDate
        self.deliveryDate = deliveryDate
        self.price = price
        self.currencyCode = currencyCode
    }
}
