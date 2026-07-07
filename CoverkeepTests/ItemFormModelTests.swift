import Foundation
import SwiftData
import Testing
import WarrantyRules
@testable import Coverkeep

@Suite("Item form model")
@MainActor
struct ItemFormModelTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Item.self, Receipt.self, Coverage.self, Event.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    // MARK: Prefill and validation

    @Test("a new form prefills country from the locale and requires only a name")
    func prefillAndValidation() {
        let model = ItemFormModel(locale: Locale(identifier: "hu_HU"))
        #expect(model.countryCode == "HU")
        #expect(!model.canSave)
        model.name = "  Laptop  "
        #expect(model.canSave)
    }

    // MARK: Price parsing

    @Test("Hungarian-formatted input parses exactly")
    func hungarianPrice() {
        let locale = Locale(identifier: "hu_HU")
        #expect(ItemFormModel.parsePrice("649990", locale: locale) == Decimal(649_990))
        #expect(ItemFormModel.parsePrice("649 990", locale: locale) == Decimal(649_990))
        #expect(
            ItemFormModel.parsePrice("649\u{00A0}990,50", locale: locale)
                == Decimal(string: "649990.50")
        )
    }

    @Test("German-formatted input parses exactly")
    func germanPrice() {
        let locale = Locale(identifier: "de_DE")
        #expect(
            ItemFormModel.parsePrice("1.349,99", locale: locale) == Decimal(string: "1349.99")
        )
    }

    @Test("garbage and empty input yield nil, never zero")
    func badPrice() {
        let locale = Locale(identifier: "en_US")
        #expect(ItemFormModel.parsePrice("", locale: locale) == nil)
        #expect(ItemFormModel.parsePrice("abc", locale: locale) == nil)
    }

    // MARK: The wow moment — live preview and save

    @Test("the live preview shows Hungarian rights before saving")
    func livePreview() throws {
        let model = ItemFormModel(locale: Locale(identifier: "hu_HU"))
        model.name = "Laptop"
        model.countryCode = "HU"
        model.channel = .online
        model.purchaseDate = date(2026, 7, 7)
        model.priceText = "649990"
        model.currencyCode = "HUF"

        let preview = model.preview(engine: .shared, calendar: calendar)
        #expect(preview.ruleSetID == "HU")
        #expect(preview.coverages.map(\.kind).sorted { $0.rawValue < $1.rawValue }
            == [.commercialWarranty, .legalGuarantee, .withdrawal])
        #expect(preview.skipped.isEmpty)
    }

    @Test("saving persists the item with its computed coverages and provenance")
    func saveCreatesCoverages() throws {
        let context = try makeContext()
        let model = ItemFormModel(locale: Locale(identifier: "hu_HU"))
        model.name = "Washing machine"
        model.countryCode = "HU"
        model.channel = .inStore
        model.purchaseDate = date(2026, 7, 7)
        model.priceText = "189 990"
        model.currencyCode = "HUF"

        let item = model.save(in: context, engine: .shared, calendar: calendar)
        try context.save()

        let coverages = item.coverages ?? []
        #expect(coverages.count == 2) // guarantee + jótállás; no withdrawal in store
        #expect(coverages.allSatisfy { $0.source == .computedFromRules })
        #expect(coverages.allSatisfy { $0.ruleSetID == "HU" })
        #expect(item.priceAmount == Decimal(189_990))
    }

    @Test("editing purchase facts regenerates computed coverages, keeps manual ones")
    func editRegenerates() throws {
        let context = try makeContext()
        let model = ItemFormModel(locale: Locale(identifier: "hu_HU"))
        model.name = "Phone"
        model.countryCode = "HU"
        model.channel = .online
        model.purchaseDate = date(2026, 7, 7)

        let item = model.save(in: context, engine: .shared, calendar: calendar)
        let manual = Coverage(
            kind: .extendedWarranty, startDate: date(2026, 7, 7), endDate: date(2031, 7, 7)
        )
        manual.item = item
        context.insert(manual)
        try context.save()

        // The parcel arrived three days later — fix the delivery date.
        let editModel = ItemFormModel(item: item, locale: Locale(identifier: "hu_HU"))
        editModel.hasDeliveryDate = true
        editModel.deliveryDate = date(2026, 7, 10)
        editModel.save(in: context, engine: .shared, calendar: calendar)
        try context.save()

        let coverages = item.coverages ?? []
        let withdrawal = try #require(coverages.first { $0.kind == .withdrawal })
        #expect(
            calendar.dateComponents([.year, .month, .day], from: withdrawal.endDate)
                == DateComponents(year: 2026, month: 7, day: 24)
        )
        #expect(!withdrawal.clockStartAssumed)
        #expect(coverages.contains { $0.kind == .extendedWarranty }) // manual survived
    }

    @Test("a reminder-lead override on a computed coverage survives regeneration")
    func leadOverrideSurvives() throws {
        let context = try makeContext()
        let model = ItemFormModel(locale: Locale(identifier: "hu_HU"))
        model.name = "Camera"
        model.countryCode = "HU"
        model.channel = .online
        model.purchaseDate = date(2026, 7, 7)
        let item = model.save(in: context, engine: .shared, calendar: calendar)

        let guarantee = try #require(
            (item.coverages ?? []).first { $0.kind == .legalGuarantee }
        )
        guarantee.reminderLeadDays = 60
        try context.save()

        let editModel = ItemFormModel(item: item, locale: Locale(identifier: "hu_HU"))
        editModel.hasDeliveryDate = true
        editModel.deliveryDate = date(2026, 7, 9)
        editModel.save(in: context, engine: .shared, calendar: calendar)
        try context.save()

        let regenerated = try #require(
            (item.coverages ?? []).first { $0.kind == .legalGuarantee }
        )
        #expect(regenerated.reminderLeadDays == 60)
    }
}
