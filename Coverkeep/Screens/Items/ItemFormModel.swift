import Foundation
import SwiftData
import KeepCore
import WarrantyRules

/// Editor state for adding or editing an item. The form shows the computed
/// rights live (`preview`) while the user types — the wow moment — and only
/// persists on save.
@Observable
final class ItemFormModel {
    var name: String = ""
    var category: ItemCategory = .other
    var brand: String = ""
    var modelName: String = ""
    var serialNumber: String = ""
    var purchaseDate: Date = .now
    var hasDeliveryDate: Bool = false
    var deliveryDate: Date = .now
    var priceText: String = ""
    var currencyCode: String
    var seller: String = ""
    var channel: PurchaseChannel = .inStore
    var countryCode: String
    var notes: String = ""

    private let locale: Locale
    /// Nil when adding; the edited item otherwise.
    private let editedItem: Item?

    var isEditing: Bool { editedItem != nil }

    /// Fast add: only the name is required; everything else is prefilled
    /// from the locale or optional.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(item: Item? = nil, locale: Locale = .current) {
        self.locale = locale
        self.editedItem = item
        self.currencyCode = Money.localeCurrencyCode
        self.countryCode = CountryOptions.defaultCode(for: locale)

        if let item {
            name = item.name
            category = item.category
            brand = item.brand ?? ""
            modelName = item.modelName ?? ""
            serialNumber = item.serialNumber ?? ""
            purchaseDate = item.purchaseDate
            hasDeliveryDate = item.deliveryDate != nil
            deliveryDate = item.deliveryDate ?? item.purchaseDate
            if let amount = item.priceAmount {
                priceText = amount.formatted(.number.grouping(.never).locale(locale))
            }
            currencyCode = item.currencyCode ?? Money.localeCurrencyCode
            seller = item.seller ?? ""
            channel = item.channel
            countryCode = item.countryCode
            notes = item.notes
        }
    }

    var price: Decimal? {
        Self.parsePrice(priceText, locale: locale)
    }

    /// Parses user-typed money: tolerates grouping separators and spaces
    /// (including the narrow no-break space Hungarian formatting uses) and
    /// the locale's decimal separator. Money is Decimal, never Double.
    static func parsePrice(_ text: String, locale: Locale) -> Decimal? {
        var normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: " ", with: "")
        if let grouping = locale.groupingSeparator, !grouping.isEmpty {
            normalized = normalized.replacingOccurrences(of: grouping, with: "")
        }
        if let decimal = locale.decimalSeparator, decimal != "." {
            normalized = normalized.replacingOccurrences(of: decimal, with: ".")
        }
        guard !normalized.isEmpty else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The rights the current form values would produce — recomputed on
    /// every field change, shown live in the form.
    func preview(
        engine: WarrantyRulesEngine,
        calendar: Calendar = .current
    ) -> CoverageComputation {
        let context = PurchaseContext(
            countryCode: countryCode,
            channel: channel,
            purchaseDate: purchaseDate,
            deliveryDate: hasDeliveryDate ? deliveryDate : nil,
            price: price,
            currencyCode: price == nil ? nil : currencyCode
        )
        return engine.computeCoverages(for: context, calendar: calendar)
    }

    /// Persists the form: creates or updates the item, then regenerates its
    /// computed coverages from the (possibly changed) purchase facts.
    @discardableResult
    func save(
        in context: ModelContext,
        engine: WarrantyRulesEngine,
        calendar: Calendar = .current
    ) -> Item {
        let item = editedItem ?? Item(name: "")
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.category = category
        item.brand = brand.isEmpty ? nil : brand
        item.modelName = modelName.isEmpty ? nil : modelName
        item.serialNumber = serialNumber.isEmpty ? nil : serialNumber
        item.purchaseDate = purchaseDate
        item.deliveryDate = hasDeliveryDate ? deliveryDate : nil
        item.priceAmount = price
        item.currencyCode = price == nil ? nil : currencyCode
        item.seller = seller.isEmpty ? nil : seller
        item.channel = channel
        item.countryCode = countryCode
        item.notes = notes

        if editedItem == nil {
            context.insert(item)
        }
        CoverageDerivation.regenerateComputedCoverages(
            for: item, engine: engine, in: context, calendar: calendar
        )
        return item
    }
}
