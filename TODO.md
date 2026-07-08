# TODO — Coverkeep launch tracker

The single living tracker of everything left before launch.

**Rules:** every item has a checkbox and a one-line "why it matters". When work
completes, tick it and note the commit hash. Never delete items — move them to
**Done** at the bottom. Newly discovered work goes into the right section
*first*, then gets done. Keep this file updated in every session.

**Rule-content freeze:** the four bundled rule files
(`WarrantyRules/Sources/WarrantyRules/Rules/{EU,HU,DE,AT}.json`) are
owner-vetted as of 2026-07-07 and FROZEN. Any content change (durations,
thresholds, clocks, sources, re-verification bumps) requires the owner's
explicit sign-off, recorded as an Owner item here before the edit is made.

## Code (Claude)

- [ ] Slice 5 — CloudKit private-database sync — *models are CloudKit-shaped
      from Slice 0; this turns it on.*
- [ ] Slice 6 — paywall via KeepCore (free: 10 items full-featured) — *IDs
      below must match the StoreKit config exactly.*
- [ ] Slice 8 — onboarding, settings, empty states, accessibility, HU strings
      — *home market + the EU story in its own language.*
- [ ] Add a rule-content re-verification checklist (re-check njt.hu,
      gesetze-im-internet.de, ris.bka.gv.at, EUR-Lex; bump `ruleSetVersion`
      and `contentVerified`) before every App Store release — *statutes
      change; the 2026 jótállás amendment proved it.*

## Owner (me) — in dependency order

- [ ] **🔒 Slice 7 corpus gate: collect 50–100 real receipt photos** (varied
      shops, thermal + laser, crumpled + flat, HU + foreign) — *OCR/AI capture
      is not built, not even Phase A measurement, until this corpus exists.*
- [ ] Enroll in the Apple Developer Program — *prerequisite for CloudKit
      provisioning, device builds, App Store Connect, TestFlight.*
- [ ] Set the team on the Coverkeep target in Xcode (automatic signing) —
      *provisions the `iCloud.com.birosbenedek.coverkeep` container and
      unblocks device builds (free teams can't carry the CloudKit
      entitlement).*
- [ ] Multi-device CloudKit sync test after Slice 5 (two devices, same Apple
      ID) — *the only sync behavior that can't be verified without a paid
      team.*
- [ ] Register the app's domain; host `/privacy` (and optionally `/terms`)
      plus a landing page — *the in-app Privacy Policy link and the App Store
      privacy URL must resolve.*
- [ ] Accept the Paid Applications agreement (App Store Connect → Agreements,
      Tax, and Banking) — *subscriptions don't work at all without it, even
      in TestFlight.*
- [ ] Create the app record (bundle ID `com.birosbenedek.coverkeep`) —
      *container for builds, IAP, and metadata.*
- [ ] Create the IAP products, exact IDs and prices: subscription group
      "Coverkeep" with `com.birosbenedek.coverkeep.annual` (~€14.99/yr,
      preselected in-app) and `com.birosbenedek.coverkeep.monthly` (~€1.99/mo),
      plus non-consumable `com.birosbenedek.coverkeep.lifetime` (~€34.99) —
      *IDs must match the StoreKit configuration or the paywall loads nothing
      in production.*
- [ ] Apply to the App Store Small Business Program BEFORE launch — *15%
      commission instead of 30%; must be approved before revenue starts.*
- [ ] App Privacy questionnaire: "Data Not Collected" — *truthful (no
      analytics, no servers, private-DB CloudKit only) and a selling point.*
- [ ] Have the in-app legal copy sanity-checked (rights explanations state
      "general information, not legal advice") — *the EU-rights brain is the
      product; its copy must not read as legal advice.*

## Done

- [x] Slice 4 — events + export: claim/repair/return history per item with
      one optional archival attachment each, and full ZIP export via
      KeepCore's ExportArchiveBuilder — deterministic JSON (full fidelity
      incl. rule provenance, money as decimal strings) + attachments/ with
      collision-deduped names shared between JSON references and files;
      exports include archived items — *an exit door that filters is not
      an exit door.*
- [x] Slice 3 — deadlines dashboard (return windows counting down from day
      one, coverages entering their lead window), 2-second diacritic-
      insensitive search across name/brand/seller/model/notes/category
      with a category filter, and reminder scheduling through KeepCore:
      one notification per live coverage, full resync after every
      mutation and on foreground, permission requested only once there is
      something to remind about — *"where is the vacuum receipt" and
      "remind me before it expires" delivered.*
- [x] Slice 2 — receipt capture + archive: multi-page receipts (camera /
      photo library / PDF via KeepCore's AttachmentsEditor), byte-for-byte
      external storage with camera captures at archival quality (KeepCore
      gained a non-breaking compressionQuality parameter), paper-framed
      document cards, QuickLook viewing with zoom/share, and the
      all-receipts browser — *thermal paper fades; the photo is the durable
      copy.*
- [x] Slice 1 — item entry + computed coverages: fast manual add with locale
      prefill, LIVE "Your rights" preview in the form, detail screen with
      countdown chips, plain-language explanations, official source links,
      assumed-clock and skipped-rule notes, manual coverage editor, and
      regeneration on edit that preserves manual coverages and lead
      overrides — *the wow moment.* English copy for all nine explanation
      keys plus the not-legal-advice disclaimer, guarded by a test that
      fails if a rule ever ships without copy.
- [x] Vet the four bundled rule files against their source links (Owner,
      2026-07-07) — *content approved as drafted, including the two-tier HU
      jótállás finding and all documented simplifications; files are now
      vetted-frozen (see rule above).*
- [x] Slice 0 — project skeleton (XcodeGen, KeepCore linked, SwiftData
      models) + complete WarrantyRules engine with HU/DE/AT/EU rule sets as
      versioned JSON, content verified against live official sources
      (njt.hu, gesetze-im-internet.de, ris.bka.gv.at, Your Europe) on
      2026-07-07, exhaustive engine tests, and golden expectation tables
      finalized against the owner-vetted content — *the rules engine is the
      credibility of the product, so it ships first and fully tested.*
