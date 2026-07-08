import SwiftUI
import QuickLook
import KeepCore

/// One file to preview: a name (used for the temp file, so its extension
/// drives QuickLook's rendering) and the bytes.
struct QuickLookFile {
    let fileName: String
    let kind: AttachmentKind
    let data: Data
}

/// Full-screen document viewing via QuickLook: system-grade zoom for
/// reading thermal-paper fine print, built-in paging, PDF rendering, and
/// sharing — no custom viewer to maintain.
///
/// QuickLook needs file URLs, so files are materialized into a private
/// temporary directory that is removed when the viewer disappears.
struct QuickLookPreview: UIViewControllerRepresentable {
    let files: [QuickLookFile]
    let initialIndex: Int

    init(files: [QuickLookFile], initialIndex: Int = 0) {
        self.files = files
        self.initialIndex = initialIndex
    }

    /// All pages of a receipt.
    init(receipt: Receipt) {
        self.init(
            files: receipt.sortedPages.compactMap { page in
                guard let data = page.data else { return nil }
                return QuickLookFile(fileName: page.fileName, kind: page.kind, data: data)
            }
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(files: files)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.currentPreviewItemIndex = context.coordinator.itemURLs.isEmpty
            ? 0
            : min(initialIndex, context.coordinator.itemURLs.count - 1)
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

        init(files: [QuickLookFile]) {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("quicklook-\(UUID().uuidString)", isDirectory: true)
            var urls: [URL] = []
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for (index, file) in files.enumerated() {
                    let name = file.fileName.isEmpty
                        ? "file-\(index + 1).\(file.kind == .pdf ? "pdf" : "jpg")"
                        : file.fileName
                    let url = directory.appendingPathComponent("\(index + 1)-\(name)")
                    try file.data.write(to: url)
                    urls.append(url)
                }
                self.scratchDirectory = directory
            } catch {
                // Preview is a read-only convenience; the archival bytes are
                // untouched in the store. Show what was written, if anything.
                assertionFailure("Failed to materialize files for preview: \(error)")
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
