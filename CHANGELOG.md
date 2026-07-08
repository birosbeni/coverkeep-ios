# Changelog

All notable changes to Coverkeep, one entry per vertical slice.

## Pre-flight (2026-07-08)

Same audit as Sawkeep and Realmkeep before the freeze:

- **Namespace**: every identifier is personal —
  `com.birosbenedek.coverkeep` bundle ID, `.pro.*` product IDs; no
  employer-derived prefixes anywhere (grep-verified).
- **Compliance**: `PrivacyInfo.xcprivacy` (no tracking, no collected
  data, UserDefaults required-reason CA92.1 — the only required-reason
  API in use), `ITSAppUsesNonExemptEncryption = NO`, localized camera
  usage description, privacy/terms placeholder links at
  `https://coverkeep.app/{privacy,terms}` in Settings and the paywall.
- **Bundle audit**: only the four vetted rule files ship (debug/test
  duplicates are packaging artifacts absent from release archives); no
  `.storekit` file in the bundle (scheme-only); `en.lproj` + `hu.lproj`
  present.
- **Destructive-action audit**: confirmations on item delete (list and
  detail) and — added in this pass — on receipt delete, whose cascade
  destroys the archival pages. Coverage/event deletes stay one-swipe
  (recomputable or low-stakes).
- **Copy audit**: one stale string found and fixed in Slice 8 (reminder
  footer); disclaimer present under every rights list.
- 101 tests green (50 WarrantyRules + 51 app). **Code frozen** until the
  owner's Developer enrollment lands (then: Slice 5 CloudKit in one
  pass) and the receipt corpus exists (then: Slice 7, Phase A only).

## Slice 8 — TestFlight polish (2026-07-08)

Slice 7 (OCR/AI capture) remains 🔒 hard-gated on the owner's receipt
corpus and is untouched.

### Added
- **Onboarding**: first-run walkthrough in four beats — Europe's rules
  built in, receipts that don't fade, reminded before it's too late,
  yours entirely — closing with the not-legal-advice disclaimer. Shown
  once (KeepCore's shared onboarding flag).
- **Settings**: Pro status / upgrade / restore; notification health with
  a "Turn on in Settings" path when denied; the bundled rule sets listed
  with their `contentVerified` dates (the credibility trail, surfaced to
  users); data-ownership note; Privacy Policy + Terms links; version.
- **Hungarian localization**: all 159 user-facing strings, including the
  nine rights explanations, notification copy, onboarding, and paywall.
  `SWIFT_EMIT_LOC_STRINGS` enabled; keys enumerated via
  `xcodebuild -exportLocalizations`; `hu.lproj` verified in the bundle.
  Tests guard that every bundled rule explanation has HU copy, that the
  jótállás copy states the vetted two-tier thresholds, and that the HU
  disclaimer exists. Camera permission prompt localized via
  `InfoPlist.xcstrings`. HU rights copy queued for owner vetting
  (TODO.md).
- **Placeholder app icon**, programmatically generated (CoreGraphics
  script, same approach as Sawkeep/Realmkeep): paper receipt with a torn
  edge and a shield-check on the brand ink blue.
- Delete confirmation for swipe-deleting items from the list (the
  cascade destroys the receipt archive; one tap shouldn't).
- Accessibility labels on icon-only controls (item actions menu, event
  attachment button).

### Fixed
- Stale coverage-editor footer claimed reminders "arrive in a later
  update" — they shipped in Slice 3.

## Slice 6 — Monetization (2026-07-08)

Slice 5 (CloudKit sync) is deferred by owner decision: blocked on Apple
Developer enrollment, to be done in one pass when the entitlement can be
provisioned and sync-tested. Monetization runs fully against a local
StoreKit configuration, so it lands first.

### Added
- **Coverkeep Pro** via KeepCore's StoreKit 2 `PurchaseManager`: annual
  €14.99 (preselected, "best value"), monthly €1.99, lifetime €34.99 —
  product IDs `com.birosbenedek.coverkeep.pro.{annual,monthly,lifetime}`
  in a subscription group plus a non-consumable. A test guards that the
  IDs in code appear verbatim in `Coverkeep.storekit`.
- **Free tier ("hard-ish paywall")**: 10 items, FULL-featured — receipts,
  coverages, events, reminders, search, and export all work on every
  item. Only creating the 11th item is gated; archived items count toward
  the limit (archiving is organization, not a slot-freeing trick).
  Existing data is never locked away.
- **PaywallView**: benefits (unlimited items, EU rights on every item,
  no account/no server, export always free), live products with localized
  prices, restore purchases, renewal disclosure, privacy/terms links;
  dismissible — it blocks the action, not the app. While the launch
  entitlement check is still running, adds pass through rather than
  flashing the paywall at a paying user.
- `Coverkeep.storekit` wired into the run scheme, so purchases are fully
  testable in the simulator before any App Store record exists.
- 3 new tests; 47 app + 50 package tests green.

## Slice 4 — Events + export (2026-07-08)

### Added
- History section on the item: claim / repair / return / note entries with
  date and note, newest first, plus one optional attachment per entry (a
  repair quote, a claim confirmation) captured through the same archival
  pipeline as receipts and viewable via QuickLook.
- **Full vault export** ("Export All…" on the home screen): a ZIP built by
  KeepCore's `ExportArchiveBuilder` containing `data.json` — the entire
  vault at full fidelity, including coverage rule provenance (rule ID,
  rule-set version), money as exact decimal strings, and archived items —
  plus `attachments/` with every receipt page and event attachment.
  File-name collisions are deduplicated once and the same mapping feeds
  both the JSON references and the written files, so the archive is
  always self-consistent (tested). JSON is deterministic (sorted keys,
  ISO-8601) and byte-stable through a decode/re-encode round-trip.
- Share sheet handoff with temp-directory cleanup per the
  ExportArchiveBuilder contract; export failures surface in an alert, not
  silently.
- QuickLook viewer generalized from receipts to any stored file
  (`QuickLookPreview`), reused for event attachments.
- 6 new tests (export fidelity, reference/file agreement, page order
  after dedup, ZIP magic bytes, event attachment round-trip);
  44 app + 50 package tests green.

## Slice 3 — Deadlines + search (2026-07-08)

### Added
- Home dashboard above the vault: **Return windows** (every active
  withdrawal counting down in days from day one — they are short and
  irreversible) and **Expiring soon** (non-withdrawal coverages that have
  entered their reminder lead window, so the chip, the dashboard, and the
  future notification always agree). Rows link straight to the item.
- 2-second search: `.searchable` across name, brand, seller, model,
  notes, and category label — case- and diacritic-insensitive (porszivo
  finds Porszívó), multi-term AND across fields ("bosch drill"), plus a
  category filter menu that combines with text.
- Reminder scheduling through KeepCore's `ReminderScheduler`: one local
  notification per live coverage of every unarchived item, fired
  `reminderLeadDays` before the end date (30 default, 3 for withdrawal).
  `ReminderSync` wipes and rebuilds the pending set after every mutation
  (item/coverage save or delete) and on foregrounding — idempotent, so
  stale and deleted deadlines can't linger. Notification permission is
  requested only when the first coverage exists, and the app stays fully
  functional if denied.
- `Coverage.reminderID` (stable UUID) so edits replace rather than
  duplicate notifications.
- 11 new tests (search matching, dashboard selection incl. archived and
  expired exclusion, reminder planning with end-today boundary and body
  copy); 38 app + 50 package tests green.

## Slice 2 — Receipt capture + archive (2026-07-08)

### Added
- Receipt capture on the item detail screen through KeepCore's attachment
  pipeline: camera, photo library, and PDF import, with multi-page
  receipts as one ordered document (long thermal rolls photographed in
  sections stay together).
- **The archival promise, enforced**: library picks and PDFs persist
  byte-for-byte (`ReceiptPage.data` with external storage, verified by a
  byte-fidelity test); camera captures are encoded once at JPEG 0.95.
  KeepCore gained a non-breaking `compressionQuality` parameter on
  `CameraPicker`/`AttachmentsEditor` (default unchanged at 0.8) rather
  than an app-local reimplementation.
- Receipts presented like archived documents: paper-framed first-page
  thumbnails with label, date, and page count — on the item and in a new
  all-receipts browser grid ("where is the vacuum receipt").
- Full-screen viewing via QuickLook: system zoom for thermal-paper fine
  print, built-in page swiping, PDF rendering, and sharing. Pages are
  materialized to a private temp directory and removed on dismissal.
- Receipt editing (add/remove/reorder pages, relabel) replaces pages
  wholesale with no orphaned rows; cascade deletes verified item →
  receipt → pages.
- `NSCameraUsageDescription` added to the generated Info.plist.
- 7 new receipt tests; 27 app + 50 package tests green. Store migration
  from the Slice 1 schema verified by launching over the previous install.

## Slice 1 — Item entry + coverages (2026-07-07)

### Added
- Fast manual item entry: name is the only required field; country and
  currency prefill from the locale, channel/category/dates are one tap.
  Price parsing is locale-aware Decimal (Hungarian narrow-space grouping,
  German comma decimals) — money is never Double.
- **The wow moment**: a live "Your rights" section in the add/edit form —
  computed coverages appear with end dates and countdown chips while the
  user is still typing, before anything is saved.
- Item detail screen: purchase facts (monospaced digits for dates and
  amounts), and every coverage as a card with the green→amber→gray
  countdown chip, date range, burden-of-proof note, plain-language
  explanation, and official source links resolved live from the engine.
- Plain-language English copy for all nine bundled explanation keys, the
  "general information, not legal advice" disclaimer under every rights
  list, honest notes for documented simplifications (calendar-day
  counting, jótállás annex caveat), and skip-reason messages ("enter the
  price to see whether a mandatory warranty applies"). A test fails if a
  bundled rule ever ships without copy.
- Delivery-date handling end to end: "Delivered later" toggle in the form;
  coverages counted from the purchase date carry an amber "set the
  delivery date if it arrived later" note.
- Coverage editing: manual coverages (kind, dates, reminder lead) can be
  added and edited; computed coverages expose only the reminder lead —
  their dates come from the vetted rules. Editing purchase facts
  regenerates computed coverages while preserving manual ones and
  reminder-lead overrides (matched by rule ID).
- Item list with nearest-deadline chip per row, empty state, swipe delete;
  EU-fallback banner when a country has no vetted rule set.
- 17 new app tests (rights copy coverage, deadline-status boundaries,
  form model prefill/parsing/save/regeneration); 70 tests total across
  package and app.

### Changed
- Reminder *scheduling* through KeepCore lands with Slice 3 (deadlines);
  leads are already stored per coverage.

## Slice 0 — Skeleton + WarrantyRules engine (2026-07-07)

### Added
- **WarrantyRules** local Swift package: the pure rules engine. Country rule
  sets live as versioned, bundled JSON (`schemaVersion`, `ruleSetVersion`,
  `contentVerified` stamps); the engine computes coverages — legal guarantee,
  withdrawal window, price-banded mandatory warranties — from
  (country, channel, purchase/delivery date, price). Zero UI imports.
- Bundled rule sets for **HU, DE, AT, and an EU-minimum fallback**, every
  duration and threshold verified against the live official texts on
  2026-07-07 (njt.hu, gesetze-im-internet.de, ris.bka.gv.at, Your Europe).
  Notably: the Hungarian jótállás price tiers were re-verified verbatim —
  the in-force text (amended through 415/2025) has **two** tiers
  (10 000–250 000 Ft → 2 years, above → 3 years); the old 1-year tier is
  gone. Each rule carries its official source links and a maintainer comment
  with the verification trail and documented simplifications.
- Delivery-vs-purchase clock: EU law starts the legal guarantee and the
  withdrawal window at delivery. The engine uses the delivery date when
  known and otherwise falls back to the purchase date, flagging the coverage
  (`clockStartAssumed`) so the UI can invite a correction.
- 50 engine tests: loader/validation of all bundled sets, month-end and
  leap-day clamping, DST transitions, year boundaries, burden-of-proof
  boundaries, jótállás price-band boundaries (inclusive/exclusive per the
  statute's wording), delivery-clock fallback, time-zone determinism
  (UTC / Budapest / Kiritimati / Los Angeles), and golden per-country
  expectation tables (9 cases) finalized against the owner-vetted content.
  The rule files are vetted-frozen: content changes require owner sign-off,
  tracked in TODO.md.
- Xcode project via XcodeGen (`com.birosbenedek.coverkeep`), KeepCore linked
  as a path dependency, SwiftData models (`Item`, `Receipt`, `Coverage`,
  `Event`) with CloudKit-compatibility constraints observed and commented,
  placeholder home screen, String Catalog, privacy manifest.
- `Coverage(computed:)` maps engine output into the data model with full
  provenance (rule ID, rule-set version) and the CLAUDE.md reminder
  defaults (30-day lead; 3 days for withdrawal windows).
- TODO.md launch tracker seeded, including the 🔒 Slice 7 OCR corpus gate
  as an Owner item.
