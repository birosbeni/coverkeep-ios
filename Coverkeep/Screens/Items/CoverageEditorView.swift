import SwiftUI
import SwiftData
import WarrantyRules

/// Add a manual coverage, or adjust one. For computed coverages only the
/// reminder lead is editable — their dates and kind come from the vetted
/// rules and change only when the purchase facts do.
struct CoverageEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderSync.self) private var reminderSync
    @Environment(\.dismiss) private var dismiss

    let item: Item
    /// Nil when adding a new manual coverage.
    let editedCoverage: Coverage?

    @State private var kind: CoverageKind = .commercialWarranty
    @State private var startDate: Date = .now
    @State private var endDate: Date = .now
    @State private var reminderLeadDays: Int = 30

    private var isComputed: Bool {
        editedCoverage?.source == .computedFromRules
    }

    private var datesValid: Bool {
        startDate <= endDate
    }

    var body: some View {
        NavigationStack {
            Form {
                if isComputed {
                    Section {
                        Label(
                            "Computed from your country's rules — dates update when the purchase details change.",
                            systemImage: "checkmark.seal"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Coverage") {
                    Picker("Kind", selection: $kind) {
                        ForEach(CoverageKind.allCases, id: \.self) { kind in
                            Text(RightsCopy.title(for: kind)).tag(kind)
                        }
                    }
                    .disabled(isComputed)
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                        .disabled(isComputed)
                    DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                        .disabled(isComputed)
                }

                Section {
                    Stepper(value: $reminderLeadDays, in: 0...365) {
                        HStack {
                            Text("Remind me")
                            Spacer()
                            Text("\(reminderLeadDays) days before")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("The reminder fires this many days before the coverage ends.")
                }
            }
            .navigationTitle(editedCoverage == nil ? "Add Coverage" : "Edit Coverage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        Task { await reminderSync.resyncAll(in: modelContext) }
                        dismiss()
                    }
                    .disabled(!datesValid)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let coverage = editedCoverage else { return }
        kind = coverage.kind
        startDate = coverage.startDate
        endDate = coverage.endDate
        reminderLeadDays = coverage.reminderLeadDays
    }

    private func save() {
        if let coverage = editedCoverage {
            if !isComputed {
                coverage.kind = kind
                coverage.startDate = startDate
                coverage.endDate = endDate
            }
            coverage.reminderLeadDays = reminderLeadDays
        } else {
            let coverage = Coverage(
                kind: kind,
                startDate: startDate,
                endDate: endDate,
                reminderLeadDays: reminderLeadDays
            )
            coverage.item = item
            modelContext.insert(coverage)
        }
    }
}
