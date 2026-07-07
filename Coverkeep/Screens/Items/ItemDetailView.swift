import SwiftUI
import SwiftData
import KeepCore
import WarrantyRules

/// One item: its facts, and the "you have these rights until these dates"
/// list with explanations and official sources.
struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.warrantyEngine) private var engine
    @Environment(\.dismiss) private var dismiss

    let item: Item

    @State private var showingEdit = false
    @State private var editingCoverage: Coverage?
    @State private var addingCoverage = false
    @State private var confirmingDelete = false

    private var sortedCoverages: [Coverage] {
        (item.coverages ?? []).sorted { $0.endDate < $1.endDate }
    }

    /// Live engine view of this purchase — for skip notes ("enter the price
    /// to see the jótállás") and source links. Stored coverages stay the
    /// source of truth for dates.
    private var computation: CoverageComputation {
        engine.computeCoverages(for: CoverageDerivation.purchaseContext(for: item))
    }

    var body: some View {
        List {
            detailsSection
            rightsSection
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit Item", systemImage: "pencil") { showingEdit = true }
                    Button("Add Coverage", systemImage: "plus.shield.checkered") {
                        addingCoverage = true
                    }
                    Divider()
                    Button("Delete Item", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ItemFormView(item: item)
        }
        .sheet(item: $editingCoverage) { coverage in
            CoverageEditorView(item: item, editedCoverage: coverage)
        }
        .sheet(isPresented: $addingCoverage) {
            CoverageEditorView(item: item, editedCoverage: nil)
        }
        .confirmationDialog(
            "Delete this item and everything attached to it?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive) {
                modelContext.delete(item)
                dismiss()
            }
        }
    }

    private var detailsSection: some View {
        Section {
            LabeledContent("Category") {
                Label(item.category.label, systemImage: item.category.systemImage)
            }
            if let brand = item.brand {
                LabeledContent("Brand", value: brand)
            }
            if let modelName = item.modelName {
                LabeledContent("Model", value: modelName)
            }
            if let serial = item.serialNumber {
                LabeledContent("Serial number") {
                    Text(serial).monospaced()
                }
            }
            LabeledContent("Purchased") {
                Text(item.purchaseDate.formatted(date: .long, time: .omitted))
                    .monospacedDigit()
            }
            if let delivery = item.deliveryDate {
                LabeledContent("Delivered") {
                    Text(delivery.formatted(date: .long, time: .omitted))
                        .monospacedDigit()
                }
            }
            if let amount = item.priceAmount, let code = item.currencyCode {
                LabeledContent("Price") {
                    Text(Money.formatted(amount, code: code))
                        .monospacedDigit()
                }
            }
            if let seller = item.seller {
                LabeledContent("Seller", value: seller)
            }
            LabeledContent("Bought") {
                Text(item.channel == .online ? "Online" : "In store")
            }
            LabeledContent("Country", value: CountryOptions.name(item.countryCode))
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rightsSection: some View {
        Section {
            ForEach(sortedCoverages) { coverage in
                CoverageCard(coverage: coverage, sources: sources(for: coverage))
                    .contentShape(Rectangle())
                    .onTapGesture { editingCoverage = coverage }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            modelContext.delete(coverage)
                        }
                    }
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

    /// Official source links for a computed coverage, looked up live from
    /// the engine output by rule ID.
    private func sources(for coverage: Coverage) -> [RuleSource] {
        guard coverage.source == .computedFromRules, let ruleID = coverage.ruleID else {
            return []
        }
        return computation.coverages.first { $0.ruleID == ruleID }?.sources ?? []
    }
}
