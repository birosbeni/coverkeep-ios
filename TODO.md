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

- [ ] Slice 1 — item entry + computed coverages with plain-language rights
      explanations and source links — *the product's wow moment; polish the
      copy.*
- [ ] Slice 2 — receipt capture + archival-quality photo storage via KeepCore
      — *thermal paper fades; the photo is the durable copy.*
- [ ] Slice 3 — deadlines dashboard + 2-second search — *"where is the vacuum
      receipt" is a core promise.*
- [ ] Slice 4 — claim/repair events + full ZIP export — *"your data, your
      iCloud" needs a working exit door.*
- [ ] Slice 5 — CloudKit private-database sync — *models are CloudKit-shaped
      from Slice 0; this turns it on.*
- [ ] Slice 6 — paywall via KeepCore (free: 10 items full-featured) — *IDs
      below must match the StoreKit config exactly.*
- [ ] Slice 8 — onboarding, settings, empty states, accessibility, HU strings
      — *home market + the EU story in its own language.*
- [ ] Write the String Catalog copy for every `explanationKey` in the bundled
      rule sets, including the "general information, not legal advice"
      disclaimer and each rule's documented simplifications (annex-goods
      caveat for jótállás, calendar-day withdrawal counting) — *the rules
      engine's credibility reaches users only through this copy.*
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
