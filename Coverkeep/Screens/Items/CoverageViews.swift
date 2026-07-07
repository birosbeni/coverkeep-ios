import SwiftUI
import WarrantyRules

/// The countdown chip: green active → amber expiring → gray expired,
/// monospaced digits per the design direction.
struct DeadlineChip: View {
    let status: DeadlineStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.medium).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.tint.opacity(0.18), in: Capsule())
            .foregroundStyle(status.tint)
    }
}

/// One right in the live form preview: what it is, until when — compact,
/// because the form's job is speed.
struct CoveragePreviewRow: View {
    let coverage: ComputedCoverage

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(RightsCopy.title(for: coverage.kind))
                    .font(.subheadline.weight(.medium))
                if coverage.clockStartAssumed {
                    Text(RightsCopy.assumedClockNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("until \(coverage.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.monospacedDigit())
                DeadlineChip(
                    status: .of(
                        endDate: coverage.endDate,
                        leadDays: Coverage.defaultReminderLeadDays(for: coverage.kind)
                    )
                )
            }
        }
    }
}

/// A stored coverage on the detail screen: chip, dates, plain-language
/// explanation, and official source links.
struct CoverageCard: View {
    let coverage: Coverage
    /// Live engine sources for computed coverages (looked up by rule ID);
    /// empty for manual coverages.
    let sources: [RuleSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(RightsCopy.title(for: coverage.kind))
                    .font(.headline)
                Spacer()
                DeadlineChip(
                    status: .of(endDate: coverage.endDate, leadDays: coverage.reminderLeadDays)
                )
            }

            Text("\(coverage.startDate.formatted(date: .abbreviated, time: .omitted)) – \(coverage.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            if let burdenEnd = coverage.burdenOfProofEndDate {
                Text(RightsCopy.burdenOfProofNote(until: burdenEnd))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if coverage.clockStartAssumed {
                Label(RightsCopy.assumedClockNote, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let key = coverage.explanationKey,
                let explanation = RightsCopy.explanation(forKey: key)
            {
                Text(explanation)
                    .font(.footnote)
            }

            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sources, id: \.url) { source in
                        if let url = URL(string: source.url) {
                            Link(destination: url) {
                                Label(source.title, systemImage: "text.book.closed")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if coverage.source == .manual {
                Text("Added manually")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
