# CLAUDE.md — Coverkeep

> Project brief for Claude Code. Read fully before writing any code.
> Single source of truth for scope, architecture, and conventions.

## 1. What we are building

**Coverkeep** is a native iOS warranty and receipt vault with a European
brain: photograph or file a receipt, and the app knows your actual rights —
the EU 2-year legal guarantee, national extensions, the 14-day online
withdrawal window, seller vs. manufacturer warranty — and reminds you
before each one expires.

**One-sentence pitch:** Your receipts, your rights, your deadlines —
Europe's warranty rules built in, everything stored in your own iCloud.

**Positioning (from market research):**
- **The EU angle is the reason this app exists.** A US competitor
  (HomeProof) already owns the "privacy-first on-device warranty vault"
  position. We differentiate on what they don't do: EU/national consumer-
  rights logic as data-driven rules (legal guarantee vs. commercial
  warranty distinction, 14-day distance-selling withdrawal countdown,
  country-specific durations), EU receipt/date formats, EUR/HUF/multi-
  currency. If a feature decision arises, prefer the EU-consumer story.
- **Rules are DATA, not code.** Country rule sets live in bundled,
  versioned JSON (duration, burden-of-proof periods, notes + official
  source links). v1 ships a small vetted set (HU, DE, AT, plus an EU
  default). The app states rules with sources; it does NOT give legal
  advice — copy must say "general information, not legal advice."
- **Receipt photo archive is a core promise** — thermal paper fades;
  the photo is the durable copy. Original photos are never recompressed
  below archival quality.
- **Manual entry is first-class; OCR is an accelerator.** The app must be
  fully useful with manual entry alone. The OCR/AI slice is HARD-GATED:
  it is not built until a real-world receipt corpus (50–100 photos)
  exists and Vision extraction has been measured on it (see Slice 7).
- **"Your data, your iCloud."** SwiftData + private CloudKit, no accounts,
  no servers, full export. Same brand DNA as the rest of the portfolio.

**Target user:** EU consumers (English-first UI, HU localization early);
anyone who buys electronics/appliances and loses receipts.

## 2. Tech stack (fixed decisions)

- Swift 5.10+, SwiftUI, iOS 17 minimum
- SwiftData + CloudKit private DB — CloudKit compatibility rules apply
  (all properties optional/defaulted, no unique constraints, optional
  relationships with explicit inverses; comment on each model)
- **Depends on shared `KeepCore` package** (sibling repo, `../keepcore`):
  reminders, attachments, export, paywall, sync helpers. Do not
  reimplement; propose generic additions upstream.
- Local package **WarrantyRules**: pure rules engine (country rule sets,
  deadline computation) — exhaustively unit-tested, zero UI imports.
- Vision framework OCR only in the gated Slice 7; Foundation Models /
  cloud LLM structuring decided AFTER corpus measurement.
- StoreKit 2 (late slice); no third-party deps, no analytics, no backend.

## 3. Data model

```
Item            — what you bought: name, category enum, brand?, model?,
                  serialNumber?, purchaseDate, price (Decimal) +
                  currencyCode, seller?, channel enum (inStore/online),
                  countryCode (drives rules), notes, archived
  └── Receipt   — photo(s)/PDF via KeepCore attachments, originalKept flag
  └── Coverage  — one per protection: kind enum (legalGuarantee /
                  commercialWarranty / extendedWarranty / withdrawal),
                  startDate, durationMonths or endDate, source
                  (computed-from-rules vs manual), reminder lead days.
                  Multiple coverages per item is the NORM (withdrawal +
                  legal guarantee + manufacturer warranty coexist).
  └── Event     — claim/repair/return log: date, kind, note, attachment
```

`WarrantyRules` computes default Coverages from (countryCode, channel,
purchaseDate): e.g. HU/online → 14-day withdrawal + 2-year legal
guarantee (+ burden-of-proof note at 1 year). User can edit/add anything;
computed coverages show their rule source.

Deadline engine: all reminder scheduling through KeepCore; every coverage
end date gets a reminder (default lead: 30 days; withdrawal: 3 days).

## 4. Build order — vertical slices

**Slice 0 — Skeleton + WarrantyRules engine.** Project via XcodeGen,
KeepCore linked, SwiftData models, and the complete WarrantyRules package
with HU/DE/AT/EU-default rule sets as versioned JSON + exhaustive tests
(date math across DST/leap years, month-end purchases, rule-set
versioning). The rules engine is this app's CutListCore — it is the
credibility of the product, so it ships first and fully tested.

**Slice 1 — Item entry + coverages.** Fast manual add (name, price,
date, seller, channel, country prefilled from locale) → computed
coverages appear immediately with plain-language explanations + source
links. Edit/add coverage. This "you have these rights until these dates"
moment is the product's wow — polish the copy.

**Slice 2 — Receipt capture + archive.** Camera/photo/PDF via KeepCore,
multi-page receipts, archival-quality storage, receipt browser.

**Slice 3 — Deadlines + search.** Home dashboard: expiring soon,
active withdrawal windows counting down in days, search ("where is the
vacuum receipt" in 2 seconds — name/brand/seller/category), categories.

**Slice 4 — Events + export.** Claim/repair log per item; full ZIP export
(JSON + all receipt images) via KeepCore.

**Slice 5 — CloudKit sync.**

**Slice 6 — Monetization.** Free: 10 items full-featured. Paid: unlimited
+ (future) scanning. Annual ~€14.99 + lifetime ~€34.99, monthly ~€1.99.
Hard-ish paywall via KeepCore.

**Slice 7 — OCR/AI capture. 🔒 GATED — do not start until the owner
provides the receipt corpus (50–100 real photos) and approves.**
Phase A: measure Vision OCR raw extraction on the corpus, report
per-field accuracy (total, date, merchant). Phase B: only if raw text is
viable, build structuring (on-device Foundation Models first; propose
cloud fallback only with owner approval — GDPR implications). Phase C:
confirm-before-save UI, never auto-save. If accuracy < 90% usable,
recommend repositioning scanning as "photo archive + smart crop" and
STOP.

**Slice 8 — TestFlight polish.** Onboarding, settings, empty states,
accessibility. Localization-ready throughout; HU strings early (home
market + EU story).

Out of scope v1: expense tracking/budgets (explicitly rejected product
direction), bank integrations, email-forward ingestion (v1.x candidate),
loyalty cards, US rule sets, Android, web.

## 5. Design direction

Trust and clarity: document-vault calm (paper white / ink dark palettes),
countdown chips with unambiguous color semantics (green active → amber
expiring → gray expired), plain-language rights explanations over legal
jargon, receipt photos presented like archived documents (subtle paper
frame), monospaced digits for dates/amounts. No playfulness — this app
holds people's money-adjacent documents.

## 6. Conventions

Same as the portfolio: English code/comments/commits; String Catalog
from first screen; @Observable view models, dumb views; Decimal + ISO
currency codes for money; dates via engine, never inline math; no silent
catches; green tests + CHANGELOG per slice; ask before dependencies/
entitlements. Maintain TODO.md from Slice 0 using the Hauskeep rules —
include the corpus-gate as an Owner item from day one.

## 7. Definition of done for v1.0

An EU consumer can: add yesterday's laptop purchase in 30 seconds and
immediately see their withdrawal countdown and 2-year guarantee with
sources, photograph the receipt before it fades, get reminded 30 days
before any coverage expires, find any receipt in 2 seconds, log a
warranty claim, and export the entire vault — no account, manual-entry
complete without any AI, their documents in their own iCloud.
