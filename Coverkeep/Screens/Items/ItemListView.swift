import SwiftUI
import SwiftData
import KeepCore

/// The vault: every unarchived purchase, newest first, each with its
/// nearest deadline at a glance. Search and the deadlines dashboard arrive
/// in Slice 3.
struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Item> { !$0.archived }, sort: \Item.createdAt, order: .reverse)
    private var items: [Item]

    @State private var showingNewItem = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("No items yet", systemImage: "archivebox")
                    } description: {
                        Text("Add a purchase to see your warranty rights and deadlines — it takes 30 seconds.")
                    } actions: {
                        Button("Add Item") { showingNewItem = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                ItemRow(item: item)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Coverkeep")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") {
                        showingNewItem = true
                    }
                }
            }
            .sheet(isPresented: $showingNewItem) {
                ItemFormView()
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
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
}
