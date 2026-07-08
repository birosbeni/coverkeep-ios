import SwiftUI
import SwiftData

/// Every receipt in the vault, newest first, presented like a drawer of
/// archived documents. Item-level capture lives on the item; this is the
/// "where is the vacuum receipt" view across everything.
struct ReceiptBrowserView: View {
    @Query(sort: \Receipt.createdAt, order: .reverse)
    private var receipts: [Receipt]

    @State private var viewedReceipt: Receipt?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 16)]

    var body: some View {
        Group {
            if receipts.isEmpty {
                ContentUnavailableView {
                    Label("No receipts yet", systemImage: "doc.text.image")
                } description: {
                    Text("Capture receipts from an item — they are archived here before the paper fades.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(receipts) { receipt in
                            Button {
                                viewedReceipt = receipt
                            } label: {
                                VStack(spacing: 4) {
                                    ReceiptCard(receipt: receipt, thumbnailSize: 96)
                                    if let itemName = receipt.item?.name {
                                        Text(itemName)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Receipts")
        .sheet(item: $viewedReceipt) { receipt in
            ReceiptQuickLook(receipt: receipt)
                .ignoresSafeArea()
        }
    }
}
