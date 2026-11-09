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
- [ ] Latest-head review/CI, corrected no-write Preview, merge and exact-main CI.
- [ ] Guarded Apply/replay/readback; fresh canonical completeness and preservation.

## Task 2 — four faithful global replacements (bounded implementer)

Create only a new `scripts/adopt-atlas-staging-global-replacements.mjs`, its
Vitest test, `supabase/packages/atlas-staging-global-replacements.sql`, focused
pgTAP test/wrapper, and `.github/workflows/atlas-staging-global-replacements.yml`.
Any existing certification registration change is explicitly coordinated by parent.

- [ ] Reuse history read-only extractor, protected-value/current-main/full-CI checks,
      verified PostgreSQL transport, technical MIGRATION Actor and private importer.
- [ ] Pin exact four source identities/edges and active payloads; fail on changed,
      missing, duplicate or extra global source order. Known excluded13 stays evidence.
      Bind preview plan to source content, target state, mappings, Actor and fixed date.
- [ ] Preview actually runs importer plus canonical assertions inside a rollback
      boundary; leaves no receipt/root/revision. Do not weaken local importer guards.
- [ ] Apply rechecks under locks, adds exactly4 roots/4 revisions/1 receipt and proves
      identical replay. No unknown-outcome automatic retry or generic import option.
- [ ] Fresh post-catch-up before/after canonical resolution covers all mapped typed
      contexts and preserves readiness, quantities, Units and stable identities; only
      the four ingredient substitutions and their new lineage steps are permitted.
      Preserve existing lineage exactly. Prove native/system/School/future interaction
      absence for this scope or block; do not use a naïve final-line oracle across
      interacting native rules. Protect all other Atlas tables/old rows and receipts.
- [ ] Test source/target drift, duplicate destination rollback, native interaction
      blockers, dates, preserved history, exact delta and replay. Use focused local tests
      and GitHub full certification. No hosted mutation by the worker.
- [ ] Independent spec/security/code review before main/Apply. Document partial
      faithful adoption and remaining order13/system/School blockers accurately.

## Task 3 — archive, final readback and evidence (parent)

- [ ] Refresh archive from603 to the fresh605 surviving records through existing
      separate Preview/reviewed-content/Apply workflow; never activate archived rows.
- [ ] Capture final independent system/School comparisons, actual receipts, run
      IDs, checksum/replay/preservation results and unresolved semantic blockers.
- [ ] Update active task/Autopilot/affected API/testing docs in same reviewed change.
      Recovery is forward correction, not deletion/reset/backdating. No Production or
      staff-pilot claim. Stop at actual unresolved business decisions with named evidence.

## Task 4 — Owner-confirmed Recipe3529 correction

The Owner first requested keeping the ambiguous Recipe unchanged, then explicitly
clarified **“thịt heo xay nha”**. The later factual confirmation governs. Source
Recipe3529 is Dish2071 / School Type2; its name says pork, while its base line14590
uses Ingredient1037 (beef) at5.5kg/100 portions. Atlas's corresponding stable line
is `b72261a4-a7b1-5a0d-14ae-0b692dc52a13`. The same Dish's Type1 already uses
Ingredient1208 (Nạc vai heo xay), the current pork mince selected by actual source
global order14. Use that exact Ingredient, not the retired1040 target.

- [ ] New bounded normal-auth runner, focused Vitest, protected manual workflow and
      API note: `correct-atlas-staging-recipe3529.mjs`, its test,
      `atlas-staging-recipe3529.yml`, and `staging-recipe3529-owner-correction.md`.
      Parent owns shared CI path registration and broad task/evidence documents.
- [ ] Use actual authenticated browser-key RPCs only: canonical typed reads,
      `preview_recipe_composition_adjustment`, `create_recipe_composition_adjustment`,
      exact replay and canonical readback. No SQL, Management API write, service-role
      key, Actor impersonation, source-v1 write or released-base edit.
- [ ] Exactly one SYSTEM_DISH / REPLACE at Type2, effective9 November, stable line
      above, substitute1208. Preserve5.5kg/100, all other lines, current Type1, pre-date
      resolution and released operations. Source evidence is the Owner's new decision,
      never a fabricated OPS-v1 order or old source issuer. Write a clear Vietnamese
      reason and explicit confirmation evidence. Use stable command/rule/revision IDs.
- [ ] Preview is read-only and hashes the exact proposed command plus canonical
      selected contexts/Actor. Apply requires reviewed checksum and fixed Staging,
      real-user auth/subject matching, canonical prerequisites, exact-main/Full CI.
      Recheck immediately before the one transactional native command; no blind retry
      after unknown outcome. Always close the local auth session.
- [ ] Focused tests prove wrong target/type/line/substitute/quantity/readiness,
      missing permission, stale preview, no-write Preview, exact Create/replay/readback,
      and logout on success/failure. Existing backend REPLACE/RLS tests remain.
- [ ] Independent review, actual CI, separately reviewed hosted Preview then Apply.
      Sequence after the four-global operation so its conservative native-interaction
      gate remains valid. Record the intentional source/Atlas difference separately
      from unresolved reconciliation gaps. Do not change the shared Dish name or Type1.
