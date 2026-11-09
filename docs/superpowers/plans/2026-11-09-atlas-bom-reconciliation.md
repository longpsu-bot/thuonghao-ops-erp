# Atlas bounded BOM reconciliation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans task by task.

**Goal:** Reconcile fresh v1 composition and apply only faithful, proven Staging corrections.

**Architecture:** Reuse existing missing-Dish catch-up and history archive runners.
For exactly four proven actual source global replacements, reuse the unchanged
local SQL importer inside a new session-local guarded Staging transaction. No
effective-view rows become authored adjustment facts.

**Tech stack:** Existing Node ESM, PostgreSQL, pgTAP, Vitest, GitHub Actions.

**Spec:** `docs/testing/atlas-bom-reconciliation-2026-11-09.md` and the existing
RMVP-02B adjustment architecture/API, amended below for this exact Staging adoption.

## Constraints and ruling

Owner requested reconciliation and DB update on 9 November. Source OPS v1 and
Production are NO-WRITE; Warehouse and Supplier commitment cancellation remain
excluded. No schema, API, resolver, precedence, dependency, grant or RLS changes.
Preserve all released Recipe/operational history, existing native roots/revisions,
master identities, mappings, weekday defaults and prior receipts.

Ruling: adopt only actual source Ingredient orders7/11/12/14, with exact edges
1043→1039,1029→1067,836→904,1040→1208. Atlas effective authority starts
`2026-11-09`, retaining original source dates/rows in archive/evidence. This is
current adoption, not recreated historic Atlas issuance. Order13 is excluded:
its1042→1041 edge creates27 duplicate-final contexts in the pre-catch-up target.
Do not generate snapshot-delta rules or silently aggregate away stable lines.
If post-catch-up validation blocks any of the four, apply none of the four and
retain the concrete blocker. No missing policy is inferred from parity totals.

## Task 1 — missing Dish closure (parent owns existing files)

- [x] Fresh read-only system and affected-School captures, exact rational comparison.
- [x] Pin29 active source Dishes, excluding source test1983.
- [x] Explicit Dish scopes exclude historical School reconciliation; add regression
      coverage for Preview/Apply/replay/full School preservation.
- [x] Focused50 Vitest and151 local pgTAP checks; initial failures retained in report.
- [x] Latest-head review/CI, corrected no-write Preview, merge and exact-main CI.
- [x] Guarded Apply/replay/readback; fresh canonical completeness and preservation.

## Task 2 — four faithful global replacements (bounded implementer)

Create only a new `scripts/adopt-atlas-staging-global-replacements.mjs`, its
Vitest test, `supabase/packages/atlas-staging-global-replacements.sql`, focused
pgTAP test/wrapper, and `.github/workflows/atlas-staging-global-replacements.yml`.
Any existing certification registration change is explicitly coordinated by parent.

- [x] Reuse history read-only extractor, protected-value/current-main/full-CI checks,
      verified PostgreSQL transport, technical MIGRATION Actor and private importer.
- [x] Pin exact four source identities/edges and active payloads; fail on changed,
      missing, duplicate or extra global source order. Known excluded13 stays evidence.
      Bind preview plan to source content, target state, mappings, Actor and fixed date.
- [x] Preview actually runs importer plus canonical assertions inside a rollback
      boundary; leaves no receipt/root/revision. Do not weaken local importer guards.
- [x] Apply rechecks under locks, adds exactly4 roots/4 revisions/1 receipt and proves
      identical replay. No unknown-outcome automatic retry or generic import option.
- [x] Fresh post-catch-up before/after canonical resolution covers all mapped typed
      contexts and preserves readiness, quantities, Units and stable identities; only
      the four ingredient substitutions and their new lineage steps are permitted.
      Preserve existing lineage exactly. Prove native/system/School/future interaction
      absence for this scope or block; do not use a naïve final-line oracle across
      interacting native rules. Protect all other Atlas tables/old rows and receipts.
- [x] Test source/target drift, duplicate destination rollback, native interaction
      blockers, dates, preserved history, exact delta and replay. Use focused local tests
      and GitHub full certification. No hosted mutation by the worker.
- [x] Independent spec/security/code review before main/Apply. Document partial
      faithful adoption and remaining order13/system/School blockers accurately.

## Task 3 — archive, final readback and evidence (parent)

- [x] Refresh archive from603 to the fresh605 surviving records through existing
      separate Preview/reviewed-content/Apply workflow; never activate archived rows.
- [x] Capture final independent system/School comparisons, actual receipts, run
      IDs, checksum/replay/preservation results and unresolved semantic blockers.
- [x] Update active task/Autopilot/affected API/testing docs in same reviewed change.
      Recovery is forward correction, not deletion/reset/backdating. No Production or
      staff-pilot claim. Stop at actual unresolved business decisions with named evidence.

## Task 4 — Owner pork fact and comparison separator

- [x] Existing authenticated SYSTEM_DISH REPLACE UI saved Recipe3529/type2 from
      9 November: beef1037→current pork1208; retain5.5kg/100 portions, stable
      identity, other ingredients, historical day8, type1 and released operations.
- [x] Independent readback: exact new root/revision in evidence; prior7/7 native
      rows,16 mapped-master fingerprint groups and82 operational tables unchanged.
- [x] Keep CLI prototype preserved unmerged/unexecuted; ship no redundant backend
      path, grant, dependency or command for an existing product action.
- [x] One decorative neutral responsive comparison divider, four existing action
      Review tests and independent rendered review; no new business behavior.
- [ ] Latest-head Frontend CI, final review and integration of UI/evidence closeout.

Final system totals1,195/331/0/8 (match/difference/missing/source absent) include
one intentional Owner difference. Affected Schools remain1,905 differences and
57 inactive blockers. Proven bounded corrections are delivered, not full v1
parity. No next mutation starts automatically; recovery remains forward correction.
