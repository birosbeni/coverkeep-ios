import SwiftUI
import SwiftData
import KeepCore
import WarrantyRules

/// Add/edit a purchase. The "Your rights" section updates live as the user
/// fills the form — rights appear before they even save.
struct ItemFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.warrantyEngine) private var engine
    @Environment(ReminderSync.self) private var reminderSync
    @Environment(\.dismiss) private var dismiss

    @State private var model: ItemFormModel

    init(item: Item? = nil) {
        _model = State(initialValue: ItemFormModel(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $model.name)
                    Picker("Category", selection: $model.category) {
                        ForEach(ItemCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    TextField("Brand", text: $model.brand)
                    TextField("Model", text: $model.modelName)
                    TextField("Serial number", text: $model.serialNumber)
                }

                Section("Purchase") {
                    DatePicker("Purchase date", selection: $model.purchaseDate, displayedComponents: .date)
                    Toggle("Delivered later", isOn: $model.hasDeliveryDate)
                    if model.hasDeliveryDate {
                        DatePicker("Delivery date", selection: $model.deliveryDate, displayedComponents: .date)
                    }
                    Picker("Bought", selection: $model.channel) {
                        Text("In store").tag(PurchaseChannel.inStore)
                        Text("Online").tag(PurchaseChannel.online)
                    }
                    .pickerStyle(.segmented)
                    Picker("Country", selection: $model.countryCode) {
                        ForEach(CountryOptions.pickerCodes(), id: \.self) { code in
                            Text(CountryOptions.name(code)).tag(code)
                        }
                    }
                    TextField("Seller", text: $model.seller)
                }

                Section("Price") {
                    HStack {
                        TextField("Amount", text: $model.priceText)
                            .keyboardType(.decimalPad)
                            .font(.body.monospacedDigit())
                        Picker("Currency", selection: $model.currencyCode) {
                            ForEach(Money.pickerCurrencyCodes, id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $model.notes, axis: .vertical)
                        .lineLimit(1...4)
                }

                rightsSection
            }
            .navigationTitle(model.isEditing ? "Edit Item" : "New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(in: modelContext, engine: engine)
                        Task { await reminderSync.resyncAll(in: modelContext) }
                        dismiss()
                    }
                    .disabled(!model.canSave)
                }
            }
        }
    }

    /// The wow moment: computed rights, live, before saving.
    private var rightsSection: some View {
        let computation = model.preview(engine: engine)
        return Section {
            ForEach(computation.coverages, id: \.ruleID) { coverage in
                CoveragePreviewRow(coverage: coverage)
            }
            ForEach(computation.skipped, id: \.ruleID) { skipped in
                Label(RightsCopy.message(for: skipped), systemImage: "questionmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if computation.usedFallbackRuleSet {
                Label(RightsCopy.fallbackRuleSetNote, systemImage: "globe.europe.africa")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Your rights")
        } footer: {
            Text(RightsCopy.disclaimer)
        }
    }
}

#Preview {
    ItemFormView()
        .modelContainer(for: [Item.self], inMemory: true)
        .environment(ReminderSync())
}
