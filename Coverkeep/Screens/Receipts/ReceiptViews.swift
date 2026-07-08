import SwiftUI
import KeepCore

/// A receipt presented like an archived document: the first page in a
/// subtle paper frame with a soft shadow, page count and label beneath.
struct ReceiptCard: View {
    let receipt: Receipt
    var thumbnailSize: CGFloat = 84

    private var firstPage: ReceiptPage? {
        receipt.sortedPages.first
    }

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let page = firstPage, let data = page.data {
                    AttachmentThumbnail(kind: page.kind, data: data, size: thumbnailSize)
                } else {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                }
            }
            .padding(6)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)

            VStack(spacing: 1) {
                Text(receipt.label.isEmpty ? String(localized: "Receipt") : receipt.label)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Text(receipt.createdAt.formatted(date: .numeric, time: .omitted))
                        .monospacedDigit()
                    if receipt.sortedPages.count > 1 {
                        Text("· \(receipt.sortedPages.count) pages")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
