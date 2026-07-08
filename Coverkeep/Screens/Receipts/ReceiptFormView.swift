import SwiftUI
import SwiftData
import KeepCore

/// Capture or edit a receipt: pages via KeepCore's attachment pipeline
/// (camera at archival quality, photo library and PDFs byte-for-byte),
/// plus an optional label.
struct ReceiptFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: Item

    @State private var model: ReceiptFormModel

    init(item: Item, receipt: Receipt? = nil) {
        self.item = item
        _model = State(initialValue: ReceiptFormModel(receipt: receipt))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AttachmentsEditor(
                        drafts: $model.drafts,
                        cameraCompressionQuality: ReceiptFormModel.archivalCameraQuality
                    )
                } header: {
                    Text("Pages")
                } footer: {
                    Text("Photograph long receipts in sections — pages stay together as one document. Originals are stored at full quality.")
                }

                Section("Label") {
                    TextField("Receipt, warranty card, invoice…", text: $model.label)
                }
            }
            .navigationTitle(model.isEditing ? "Edit Receipt" : "Add Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(for: item, in: modelContext)
                        dismiss()
                    }
                    .disabled(!model.canSave)
                }
            }
        }
    }
}
