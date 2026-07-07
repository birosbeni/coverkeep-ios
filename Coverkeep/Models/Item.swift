import Foundation
import SwiftData
import WarrantyRules

/// A purchased thing whose receipts, coverages, and claim history the vault
/// tracks.
///
/// CloudKit compatibility: every stored property is optional or defaulted,
/// there are no unique constraints, and every relationship is optional with
/// an explicit inverse (declared here, on the to-many side).
@Model
final class Item {
    var name: String = ""
    /// Raw `ItemCategory`; enums are not persisted directly.
    var categoryRawValue: String = ItemCategory.other.rawValue
    var brand: String?
    /// Manufacturer model designation (e.g. "MacBook Pro 14, 2026").
    var modelName: String?
    var serialNumber: String?
    var purchaseDate: Date = Date.now
    /// When the goods reached the buyer. Delivery-clock coverages
    /// (withdrawal, legal guarantee) start here; when nil the engine falls
    /// back to `purchaseDate` and flags the coverage as assumed.
    var deliveryDate: Date?
    var priceAmount: Decimal?
    /// ISO 4217 code for `priceAmount`.
    var currencyCode: String?
    var seller: String?
    /// Raw `PurchaseChannel` (WarrantyRules); distance-selling rights only
    /// attach to online purchases.
    var channelRawValue: String = PurchaseChannel.inStore.rawValue
    /// ISO 3166-1 alpha-2; selects the WarrantyRules rule set.
    var countryCode: String = ""
    var notes: String = ""
    var archived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Receipt.item)
    var receipts: [Receipt]?

    @Relationship(deleteRule: .cascade, inverse: \Coverage.item)
    var coverages: [Coverage]?

    @Relationship(deleteRule: .cascade, inverse: \Event.item)
    var events: [Event]?

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }

    var channel: PurchaseChannel {
        get { PurchaseChannel(rawValue: channelRawValue) ?? .inStore }
        set { channelRawValue = newValue.rawValue }
    }

    init(
        name: String,
        category: ItemCategory = .other,
        brand: String? = nil,
        modelName: String? = nil,
        serialNumber: String? = nil,
        purchaseDate: Date = .now,
        deliveryDate: Date? = nil,
        priceAmount: Decimal? = nil,
        currencyCode: String? = nil,
        seller: String? = nil,
        channel: PurchaseChannel = .inStore,
        countryCode: String = "",
        notes: String = ""
    ) {
        self.name = name
        self.categoryRawValue = category.rawValue
        self.brand = brand
        self.modelName = modelName
        self.serialNumber = serialNumber
        self.purchaseDate = purchaseDate
        self.deliveryDate = deliveryDate
        self.priceAmount = priceAmount
        self.currencyCode = currencyCode
        self.seller = seller
        self.channelRawValue = channel.rawValue
        self.countryCode = countryCode
        self.notes = notes
        self.archived = false
        self.createdAt = .now
    }
}
