import Foundation

/// The "where is the vacuum receipt in 2 seconds" filter: matches items by
/// name, brand, seller, model, notes, or category label, case- and
/// diacritic-insensitively (porszívó finds porszivo), optionally narrowed
/// to one category.
enum ItemSearch {

    static func filter(
        _ items: [Item],
        query: String,
        category: ItemCategory? = nil
    ) -> [Item] {
        items.filter { item in
            if let category, item.category != category {
                return false
            }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return true }
            return matches(item, query: trimmed)
        }
    }

    static func matches(_ item: Item, query: String) -> Bool {
        let haystacks = [
            item.name,
            item.brand ?? "",
            item.seller ?? "",
            item.modelName ?? "",
            item.notes,
            item.category.label,
        ]
        // Every whitespace-separated term must match somewhere, so
        // "bosch hammer" finds the Bosch hammer drill.
        let terms = query.split(separator: " ").map(String.init)
        return terms.allSatisfy { term in
            haystacks.contains { $0.localizedStandardContains(term) }
        }
    }
}
