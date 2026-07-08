import SwiftUI
import SwiftData
import KeepCore

/// Log what happened to an item: a claim, a repair, a return — with an
/// optional attachment (repair quote, claim confirmation).
struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: Item
    /// Nil when adding.
    let editedEvent: Event?

    @State private var kind: EventKind = .claim
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var drafts: [AttachmentDraft] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened") {
                    Picker("Kind", selection: $kind) {
                        ForEach(EventKind.allCases, id: \.self) { kind in
                            Label(kind.label, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(1...5)
                }

                Section {
                    AttachmentsEditor(
                        drafts: $drafts,
                        cameraCompressionQuality: ReceiptFormModel.archivalCameraQuality
                    )
                } header: {
                    Text("Attachment")
                } footer: {
                    Text("One attachment per entry — adding another replaces it.")
                }
            }
            .navigationTitle(editedEvent == nil ? "Log Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: load)
            .onChange(of: drafts.count) { _, count in
                // The data model holds exactly one attachment per event
                // (see Event); keep the newest when a second is added.
                if count > 1 {
                    drafts.removeFirst(count - 1)
                }
            }
        }
    }

    private func load() {
        guard let event = editedEvent else { return }
        kind = event.kind
        date = event.date
        note = event.note
        drafts = [event.attachmentDraft].compactMap { $0 }
    }

    private func save() {
        let event = editedEvent ?? Event(kind: kind)
        event.kind = kind
        event.date = date
        event.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        event.setAttachment(drafts.first)
        if editedEvent == nil {
            event.item = item
            modelContext.insert(event)
        }
    }
}
