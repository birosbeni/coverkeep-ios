import SwiftUI
import SwiftData
import KeepCore

/// Home: the deadlines dashboard (active return windows counting down,
/// coverages entering their reminder window) above the vault itself, with
/// 2-second search across name, brand, seller, model, notes, and category.
struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderSync.self) private var reminderSync
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Item> { !$0.archived }, sort: \Item.createdAt, order: .reverse)
    private var items: [Item]

    @State private var showingNewItem = false
    @State private var showingPaywall = false
    @State private var searchText = ""
    @State private var categoryFilter: ItemCategory?
    @State private var exportArchive: ExportArchive?
    @State private var exportScratchDirectory: URL?
    @State private var exportError: String?

    private struct ExportArchive: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty || categoryFilter != nil
    }

    private var filteredItems: [Item] {
        ItemSearch.filter(items, query: searchText, category: categoryFilter)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    List {
                        if !isSearching {
                            dashboardSections
                        }
                        itemsSection
                    }
                    .searchable(text: $searchText, prompt: "Name, brand, seller…")
                }
            }
            .navigationTitle("Coverkeep")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ReceiptBrowserView()
                    } label: {
                        Label("Receipts", systemImage: "doc.text.image")
                    }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        categoryMenu
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") {
                        requestNewItem()
                    }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Export All…", systemImage: "square.and.arrow.up") {
                            exportVault()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewItem) {
                ItemFormView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(item: $exportArchive, onDismiss: cleanUpExport) { archive in
                ShareSheet(items: [archive.url])
            }
            .alert(
                "Export failed",
                isPresented: .init(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
        }
        .task {
            await reminderSync.resyncAll(in: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await reminderSync.resyncAll(in: modelContext) }
            }
        }
    }

    // MARK: Dashboard

    @ViewBuilder
    private var dashboardSections: some View {
        let returnWindows = Dashboard.returnWindows(in: items)
        let expiring = Dashboard.expiringSoon(in: items)

        if !returnWindows.isEmpty {
            Section("Return windows") {
                ForEach(returnWindows) { entry in
                    deadlineRow(entry)
                }
            }
        }
        if !expiring.isEmpty {
            Section("Expiring soon") {
                ForEach(expiring) { entry in
                    deadlineRow(entry)
                }
            }
        }
    }

    private func deadlineRow(_ entry: DeadlineEntry) -> some View {
        NavigationLink(value: entry.item) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.item.name)
                        .font(.headline)
                    Text("\(RightsCopy.title(for: entry.coverage.kind)) · until \(entry.coverage.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                DeadlineChip(
                    status: .of(
                        endDate: entry.coverage.endDate,
                        leadDays: entry.coverage.reminderLeadDays
                    )
                )
            }
        }
    }

    // MARK: Items

    private var itemsSection: some View {
        Section(isSearching ? "Results" : "Items") {
            if filteredItems.isEmpty {
                Text("Nothing matches — try fewer words.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredItems) { item in
                    NavigationLink(value: item) {
                        ItemRow(item: item)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $categoryFilter) {
                Text("All categories").tag(ItemCategory?.none)
                ForEach(ItemCategory.allCases) { category in
                    Label(category.label, systemImage: category.systemImage)
                        .tag(ItemCategory?.some(category))
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: categoryFilter == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No items yet", systemImage: "archivebox")
        } description: {
            Text("Add a purchase to see your warranty rights and deadlines — it takes 30 seconds.")
        } actions: {
            Button("Add Item") { requestNewItem() }
                .buttonStyle(.borderedProminent)
        }
    }

    /// The one gated creation point (CLAUDE.md Slice 6: free = 10 items,
    /// full-featured). Archived items count — the total is fetched fresh,
    /// not taken from the filtered query. While the launch entitlement
    /// check is still running we let the add through rather than flash a
    /// paywall at a paying user.
    private func requestNewItem() {
        let count = (try? modelContext.fetchCount(FetchDescriptor<Item>())) ?? 0
        let entitled = purchases.isEntitled || purchases.isLoadingEntitlement
        if FreeTier.canCreateItem(existingItemCount: count, isEntitled: entitled) {
            showingNewItem = true
        } else {
            showingPaywall = true
        }
    }

    /// Exports EVERYTHING — archived items included; an exit door that
    /// filters is not an exit door.
    private func exportVault() {
        cleanUpExport()
        do {
            let allItems = try modelContext.fetch(FetchDescriptor<Item>())
            let url = try VaultExport.makeArchive(items: allItems)
            exportScratchDirectory = url.deletingLastPathComponent()
            exportArchive = ExportArchive(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// The archive lives in its own temp subdirectory; per the
    /// ExportArchiveBuilder contract we remove it after sharing.
    private func cleanUpExport() {
        if let directory = exportScratchDirectory {
            try? FileManager.default.removeItem(at: directory)
            exportScratchDirectory = nil
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let doomed = offsets.map { filteredItems[$0] }
        for item in doomed {
            modelContext.delete(item)
        }
        Task { await reminderSync.resyncAll(in: modelContext) }
    }
}

struct ItemRow: View {
    let item: Item

    /// The coverage whose deadline matters next: the soonest end date still
    /// in the future, or the latest expired one when nothing is active.
    private var nextDeadline: Coverage? {
        let coverages = item.coverages ?? []
        let now = Calendar.current.startOfDay(for: .now)
        let active = coverages
            .filter { Calendar.current.startOfDay(for: $0.endDate) >= now }
            .min { $0.endDate < $1.endDate }
        return active ?? coverages.max { $0.endDate < $1.endDate }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } icon: {
                Image(systemName: item.category.systemImage)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let coverage = nextDeadline {
                DeadlineChip(
                    status: .of(endDate: coverage.endDate, leadDays: coverage.reminderLeadDays)
                )
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = [item.purchaseDate.formatted(date: .abbreviated, time: .omitted)]
        if let seller = item.seller {
            parts.append(seller)
        } else if let amount = item.priceAmount, let code = item.currencyCode {
            parts.append(Money.formatted(amount, code: code))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    ItemListView()
        .modelContainer(for: [Item.self], inMemory: true)
        .environment(ReminderSync())
        .environment(PurchaseManager(productIDs: CoverkeepProducts.ids))
}
