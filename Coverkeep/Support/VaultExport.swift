import Foundation
import SwiftData
import KeepCore

/// The export document: the entire vault as JSON, full fidelity — every
/// field, including rule provenance, so an export is a complete, honest
/// exit door ("your data, your iCloud"). Encoded with
/// `DeterministicJSON.encoder()` (sorted keys, ISO-8601).
///
/// Money exports as decimal STRINGS: `JSONEncoder` routes `Decimal`
/// through floating point, and 649990.10 must not become 649990.09999….
struct ExportDocument: Codable, Equatable {
    var schemaVersion = 1
    var app = "Coverkeep"
    let exportedAt: Date
    let items: [ExportItem]
}

struct ExportItem: Codable, Equatable {
    let name: String
    let category: String
    let brand: String?
    let modelName: String?
    let serialNumber: String?
    let purchaseDate: Date
    let deliveryDate: Date?
    let price: String?
    let currencyCode: String?
    let seller: String?
    let channel: String
    let countryCode: String
    let notes: String
    let archived: Bool
    let createdAt: Date
    let coverages: [ExportCoverage]
    let events: [ExportEvent]
    let receipts: [ExportReceipt]
}

struct ExportCoverage: Codable, Equatable {
    let kind: String
    let startDate: Date
    let endDate: Date
    let burdenOfProofEndDate: Date?
    let source: String
    let ruleID: String?
    let ruleSetID: String?
    let ruleSetVersion: String?
    let explanationKey: String?
    let clockStartAssumed: Bool
    let reminderLeadDays: Int
}

struct ExportEvent: Codable, Equatable {
    let date: Date
    let kind: String
    let note: String
    /// File name under `attachments/` in the archive, when one exists.
    let attachmentFile: String?
}

struct ExportReceipt: Codable, Equatable {
    let label: String
    let originalKept: Bool
    let createdAt: Date
    /// File names under `attachments/` in the archive, in page order.
    let pageFiles: [String]
}

/// Maps the vault into the export document + attachment payloads, with the
/// JSON references and the written files guaranteed to agree: both come
/// from `ExportArchiveBuilder.assignedNames`, computed once.
enum VaultExport {

    struct Prepared {
        let document: ExportDocument
        let attachments: [ExportArchiveBuilder.Attachment]
    }

    static let archiveName = "Coverkeep Export.zip"

    /// Builds the ZIP (JSON + attachments/) and returns its URL in a
    /// unique temp directory. The caller shares it and then removes its
    /// parent directory.
    static func makeArchive(items: [Item], exportedAt: Date = .now) throws -> URL {
        let prepared = prepare(items: items, exportedAt: exportedAt)
        let jsonData = try DeterministicJSON.encoder().encode(prepared.document)
        return try ExportArchiveBuilder.makeArchive(
            jsonData: jsonData,
            attachments: prepared.attachments,
            archiveName: archiveName
        )
    }

    static func prepare(items: [Item], exportedAt: Date) -> Prepared {
        // Pass 1: collect every attachment payload with an ephemeral
        // identity, so the shared name assignment sees the whole set.
        var attachments: [ExportArchiveBuilder.Attachment] = []
        var pageIDs: [PersistentIdentifier: UUID] = [:]
        var eventIDs: [PersistentIdentifier: UUID] = [:]

        let sortedItems = items.sorted { $0.createdAt < $1.createdAt }
        for item in sortedItems {
            for receipt in (item.receipts ?? []).sorted(by: { $0.createdAt < $1.createdAt }) {
                for page in receipt.sortedPages {
                    guard let data = page.data else { continue }
                    let id = UUID()
                    pageIDs[page.persistentModelID] = id
                    attachments.append(
                        ExportArchiveBuilder.Attachment(
                            id: id,
                            fileName: page.fileName.isEmpty ? "receipt.jpg" : page.fileName,
                            data: data,
                            sortDate: page.createdAt
                        )
                    )
                }
            }
            for event in (item.events ?? []).sorted(by: { $0.date < $1.date }) {
                guard let data = event.attachmentData else { continue }
                let id = UUID()
                eventIDs[event.persistentModelID] = id
                attachments.append(
                    ExportArchiveBuilder.Attachment(
                        id: id,
                        fileName: event.attachmentFileName ?? "event-attachment",
                        data: data,
                        sortDate: event.createdAt
                    )
                )
            }
        }

        // Pass 2: build the document against the single name assignment.
        let names = ExportArchiveBuilder.assignedNames(for: attachments)

        let exportItems = sortedItems.map { item in
            ExportItem(
                name: item.name,
                category: item.categoryRawValue,
                brand: item.brand,
                modelName: item.modelName,
                serialNumber: item.serialNumber,
                purchaseDate: item.purchaseDate,
                deliveryDate: item.deliveryDate,
                price: item.priceAmount.map { "\($0)" },
                currencyCode: item.currencyCode,
                seller: item.seller,
                channel: item.channelRawValue,
                countryCode: item.countryCode,
                notes: item.notes,
                archived: item.archived,
                createdAt: item.createdAt,
                coverages: (item.coverages ?? [])
                    .sorted { $0.endDate < $1.endDate }
                    .map { coverage in
                        ExportCoverage(
                            kind: coverage.kindRawValue,
                            startDate: coverage.startDate,
                            endDate: coverage.endDate,
                            burdenOfProofEndDate: coverage.burdenOfProofEndDate,
                            source: coverage.sourceRawValue,
                            ruleID: coverage.ruleID,
                            ruleSetID: coverage.ruleSetID,
                            ruleSetVersion: coverage.ruleSetVersion,
                            explanationKey: coverage.explanationKey,
                            clockStartAssumed: coverage.clockStartAssumed,
                            reminderLeadDays: coverage.reminderLeadDays
                        )
                    },
                events: (item.events ?? [])
                    .sorted { $0.date < $1.date }
                    .map { event in
                        ExportEvent(
                            date: event.date,
                            kind: event.kindRawValue,
                            note: event.note,
                            attachmentFile: eventIDs[event.persistentModelID]
                                .flatMap { names[$0] }
                        )
                    },
                receipts: (item.receipts ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                    .map { receipt in
                        ExportReceipt(
                            label: receipt.label,
                            originalKept: receipt.originalKept,
                            createdAt: receipt.createdAt,
                            pageFiles: receipt.sortedPages.compactMap { page in
                                pageIDs[page.persistentModelID].flatMap { names[$0] }
                            }
                        )
                    }
            )
        }

        return Prepared(
            document: ExportDocument(exportedAt: exportedAt, items: exportItems),
            attachments: attachments
        )
    }
}
