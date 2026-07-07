# Changelog

All notable changes to Coverkeep, one entry per vertical slice.

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
