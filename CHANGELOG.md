# Changelog

All notable changes to Coverkeep, one entry per vertical slice.

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
