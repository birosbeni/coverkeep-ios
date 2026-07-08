import SwiftUI
import QuickLook
import KeepCore

/// Full-screen receipt viewing via QuickLook: system-grade zoom for reading
/// thermal-paper fine print, built-in paging across pages, PDF rendering,
/// and sharing — no custom viewer to maintain.
///
/// QuickLook needs file URLs, so pages are materialized into a private
/// temporary directory that is removed when the viewer disappears.
struct ReceiptQuickLook: UIViewControllerRepresentable {
    let receipt: Receipt
    let initialPageIndex: Int

    init(receipt: Receipt, initialPageIndex: Int = 0) {
        self.receipt = receipt
        self.initialPageIndex = initialPageIndex
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(receipt: receipt, initialPageIndex: initialPageIndex)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.currentPreviewItemIndex = context.coordinator.itemURLs.isEmpty
            ? 0
            : min(initialPageIndex, context.coordinator.itemURLs.count - 1)
        // Wrapping in a navigation controller gives QuickLook its Done
        // button when presented as a sheet.
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    static func dismantleUIViewController(_ controller: UINavigationController, coordinator: Coordinator) {
        coordinator.cleanUp()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let itemURLs: [URL]
        private let scratchDirectory: URL?

        init(receipt: Receipt, initialPageIndex: Int) {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("receipt-preview-\(UUID().uuidString)", isDirectory: true)
            var urls: [URL] = []
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for (index, page) in receipt.sortedPages.enumerated() {
                    guard let data = page.data else { continue }
                    let name = page.fileName.isEmpty
                        ? "page-\(index + 1).\(page.kind == .pdf ? "pdf" : "jpg")"
                        : page.fileName
                    let url = directory.appendingPathComponent("\(index + 1)-\(name)")
                    try data.write(to: url)
                    urls.append(url)
                }
                self.scratchDirectory = directory
            } catch {
                // Preview is a read-only convenience; the archival bytes are
                // untouched in the store. Show what was written, if anything.
                assertionFailure("Failed to materialize receipt pages for preview: \(error)")
                self.scratchDirectory = directory
            }
            self.itemURLs = urls
        }

        func cleanUp() {
            guard let scratchDirectory else { return }
            try? FileManager.default.removeItem(at: scratchDirectory)
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            itemURLs.count
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            itemURLs[index] as NSURL
        }
    }
}
