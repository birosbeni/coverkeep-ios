import SwiftUI
import SwiftData
import UserNotifications
import KeepCore
import WarrantyRules

/// Settings: Pro status, notification health, the rule sets' verification
/// trail (the product's credibility, surfaced), legal links, and version.
struct SettingsView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(ReminderSync.self) private var reminderSync
    @Environment(\.warrantyEngine) private var engine

    @State private var showingPaywall = false

    var body: some View {
        List {
            proSection
            notificationsSection
            ruleSetsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .task {
            await reminderSync.scheduler.refreshAuthorizationStatus()
        }
    }

    private var proSection: some View {
        Section("Coverkeep Pro") {
            if purchases.isEntitled {
                Label("Pro is active — unlimited items", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    Label("Upgrade — the free vault holds \(FreeTier.maxItems) items", systemImage: "infinity")
                }
                Button("Restore Purchases") {
                    Task { await purchases.restore() }
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            switch reminderSync.scheduler.authorizationStatus {
            case .denied:
                Label(
                    "Notifications are off — deadline reminders can't fire.",
                    systemImage: "bell.slash"
                )
                .foregroundStyle(.orange)
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    Link("Turn on in Settings", destination: url)
                }
            case .authorized, .provisional, .ephemeral:
                Label("Deadline reminders are on.", systemImage: "bell.badge")
            default:
                Label(
                    "You'll be asked for permission when your first deadline exists.",
                    systemImage: "bell"
                )
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Reminders")
        }
    }

    /// The EU brain, accountable: which rule sets this build carries, when
    /// their content was last verified against the official texts.
    private var ruleSetsSection: some View {
        Section {
            ForEach(
                engine.store.ruleSets.values.sorted(by: { $0.ruleSetID < $1.ruleSetID }),
                id: \.ruleSetID
            ) { ruleSet in
                LabeledContent(ruleSetName(ruleSet.ruleSetID)) {
                    Text("verified \(ruleSet.contentVerified)")
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        } header: {
            Text("Consumer-rights rule sets")
        } footer: {
            Text(RightsCopy.disclaimer)
        }
    }

    private var aboutSection: some View {
        Section {
            Label(
                "No account, no server, no analytics. Your documents stay on your device.",
                systemImage: "lock"
            )
            .font(.footnote)
            Link(destination: LegalLinks.privacyPolicy) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: LegalLinks.terms) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            LabeledContent("Version", value: Self.versionString)
        } header: {
            Text("About")
        }
    }

    private func ruleSetName(_ id: String) -> String {
        if id == RuleStore.fallbackRuleSetID {
            return String(localized: "EU minimum (fallback)")
        }
        return Locale.current.localizedString(forRegionCode: id) ?? id
    }

    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return "\(version ?? "?") (\(build ?? "?"))"
    }
}
