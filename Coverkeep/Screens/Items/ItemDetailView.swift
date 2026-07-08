import SwiftUI
import SwiftData
import KeepCore
import WarrantyRules

/// One item: its facts, and the "you have these rights until these dates"
/// list with explanations and official sources.
struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.warrantyEngine) private var engine
    @Environment(ReminderSync.self) private var reminderSync
    @Environment(\.dismiss) private var dismiss

    let item: Item

    @State private var showingEdit = false
    @State private var editingCoverage: Coverage?
    @State private var addingCoverage = false
    @State private var confirmingDelete = false
    @State private var addingReceipt = false
    @State private var editingReceipt: Receipt?
    @State private var viewedReceipt: Receipt?
    @State private var addingEvent = false
    @State private var editingEvent: Event?
    @State private var viewedAttachmentEvent: Event?

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
            receiptsSection
            rightsSection
            eventsSection
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit Item", systemImage: "pencil") { showingEdit = true }
                    Button("Add Receipt", systemImage: "doc.viewfinder") {
                        addingReceipt = true
                    }
                    Button("Add Coverage", systemImage: "plus.shield.checkered") {
                        addingCoverage = true
                    }
                    Button("Log Event", systemImage: "clock.badge.exclamationmark") {
                        addingEvent = true
                    }
                    Divider()
                    Button("Delete Item", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Item actions")
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
        .sheet(isPresented: $addingReceipt) {
            ReceiptFormView(item: item)
        }
        .sheet(item: $editingReceipt) { receipt in
            ReceiptFormView(item: item, receipt: receipt)
        }
        .sheet(item: $viewedReceipt) { receipt in
            QuickLookPreview(receipt: receipt)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $addingEvent) {
            EventFormView(item: item, editedEvent: nil)
        }
        .sheet(item: $editingEvent) { event in
            EventFormView(item: item, editedEvent: event)
        }
        .sheet(item: $viewedAttachmentEvent) { event in
            if let draft = event.attachmentDraft {
                QuickLookPreview(
                    files: [QuickLookFile(fileName: draft.fileName, kind: draft.kind, data: draft.data)]
                )
                .ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "Delete this item and everything attached to it?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive) {
                modelContext.delete(item)
                Task { await reminderSync.resyncAll(in: modelContext) }
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

    private var receiptsSection: some View {
        Section {
            let receipts = (item.receipts ?? []).sorted { $0.createdAt < $1.createdAt }
            if receipts.isEmpty {
                Button {
                    addingReceipt = true
                } label: {
                    Label("Photograph the receipt before it fades", systemImage: "doc.viewfinder")
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(receipts) { receipt in
                            Button {
                                viewedReceipt = receipt
                            } label: {
                                ReceiptCard(receipt: receipt)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit", systemImage: "pencil") {
                                    editingReceipt = receipt
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(receipt)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Receipts")
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
                            Task { await reminderSync.resyncAll(in: modelContext) }
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

    private var eventsSection: some View {
        Section {
            let events = (item.events ?? []).sorted { $0.date > $1.date }
            if events.isEmpty {
                Button {
                    addingEvent = true
                } label: {
                    Label("Log a claim, repair, or return", systemImage: "clock.badge.exclamationmark")
                }
            } else {
                ForEach(events) { event in
                    HStack(alignment: .firstTextBaseline) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(event.kind.label)
                                        .font(.subheadline.weight(.medium))
                                    if event.attachmentData != nil {
                                        Button {
                                            viewedAttachmentEvent = event
                                        } label: {
                                            Image(systemName: "paperclip")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("View attachment")
                                    }
                                }
                                if !event.note.isEmpty {
                                    Text(event.note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: event.kind.systemImage)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingEvent = event }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            modelContext.delete(event)
                        }
                    }
                }
            }
        } header: {
            Text("History")
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
