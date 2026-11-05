# Recipe Change Order history implementation plan

> Execute inline using superpowers:executing-plans; request one read-only review
> of the completed branch. Owner approved implementation and the new latest-main
> task branch in the 5 November 2026 session.

**Goal:** retain surviving OPS v1 Change Orders and let staff inspect them without
changing effective recipes or fabricating missing historical events.

**Architecture:** use the existing private import receipt for immutable source
snapshots, extend the existing authenticated adjustment read, and add a read-only
disclosure to the existing workbench. No new business object or runtime API.

**Tech stack:** existing Node/pnpm, PostgreSQL/Supabase, React/Chakra, Vitest/pgTAP.

**Spec:** [Recipe history contract](../../api/recipe-change-order-history.md).

## Constraints

Source OPS v1 read-only; no hosted writes; exact decimal text; no invented
issuance/cancellation; no native adjustment or released-history mutation. Keep
the authorized E: checkout, existing hotfix branch, schema ownership/RLS and all
existing RPC versions. Use an independent local database, not an existing stack.

## Tasks and evidence ledger

- [x] Source adapter and guarded runner: create
      `scripts/recipe-change-order-history.mjs` and `.test.mjs`. Export
      `buildRecipeHistorySourceSql()`, `normalizeRecipeHistorySnapshot(raw, identity)`
      and `extractRecipeHistorySnapshot(options)`. Reuse canonical checksum/file
      writing and the existing disposable-target validator. Test source completeness,
      duplicate IDs, exact decimals, missing metadata and read-only source access
      before implementation; run the focused Vitest file RED then GREEN.
- [x] Receipt-only persistence/read: add the CLI-generated migration
      `20261105032000_recipe_change_order_history.sql` and focused
      `supabase/tests/recipe_change_order_history.sql`. Private
      `atlas_legacy.import_recipe_change_order_history(snapshot, actor, plan_checksum)`
      previews by default and writes only completed import receipts on reviewed
      apply. Private `atlas_legacy.recipe_change_order_history()` shapes retained
      latest-observed identities. Enrich the existing v2 operator read after its
      existing authorization. Test receipt/replay/security and unchanged native roots.
- [x] Staff display: extend `recipeAdjustmentModel.ts` with validated optional
      `legacy_history`; add `LegacyChangeOrderHistory.tsx` and its tests; mount inside
      `ChangeOrderWorkbench.tsx`. Reuse Chakra tokens, native disclosure,
      AtlasTableViewport and existing text folding. Show at most 25 matches initially;
      expand explicitly. Do not add a mutation or derive operational applicability.
- [x] Local evidence: run the focused tests on an independent disposable
      database, use one real immutable source snapshot, preview/apply/replay it,
      and verify receipt/read counts and unchanged adjustment roots. Keep raw data
      private. Record observed results and remaining limits in the contract/runbook.
- [ ] Finish: format changed files, focused typecheck/tests, independent read-only
      review, bounded commit/push/draft PR, and inspect latest-head Frontend CI.
      No merge or hosted deployment.

Ruling: archive source records before activating legacy rules. The source lacks
the event history needed to prove dated cancellation and uses a latest-row
selection rule that cannot silently replace Atlas precedence. Cost: this change
does not yet activate missing legacy business rules; doing so requires an exact
context reconciliation task with its own operative mapping.

Evidence checkpoint: 603 real source rows, 17 inactive, exact same-receipt replay,
zero native writes. Recipe history pgTAP: 33 checks, including preservation of a
nonempty native root and revision. Platform security catalog: 32 checks. Focused
frontend/script tests: 185 passing; TypeScript passes. Component rendering passes
at 1440px and 390px. Raw evidence remains private outside Git.

Ruling: update the existing local-query decoder for the pinned CLI's boundary/rows
envelope, preserving the older array result and all cardinality validation. The
new runner exposed this existing incompatibility; its callers and tests now agree.

Ruling: pin the exact additional policy, two private invokers, and three runtime
read privileges in the existing platform security catalog. No catalog assertion
was removed or weakened. The new pgTAP file is registered in full Integration CI.

Local test discovery also matched stale ignored baseline copies under
`.superpowers/sdd`. Focused runs exclude that local temporary directory only;
repository tests and CI configuration are not excluded or disabled.

Independent read-only review found no functional/security defect. Its whitespace
finding on two SQL file endings is corrected. Additional pgTAP cases cover
same-time observation conflict, a changed importer on replay, and latest source
observation selection. Latest-head CI remains pending at this checkpoint.

CI found two retained RMVP-01 privilege assertions that assumed the read runtime
had no legacy access at all. Updated them to the approved archive-only SELECT
exception while still rejecting importer execution, receipt writes, mapping
access and all direct browser grants. Added a real RLS isolation check against
an unrelated private receipt. Six focused master/Recipe/catalog pgTAP files now
pass 247 checks; no runtime implementation changed for this correction.

The next Integration run exposed one remaining cross-module total-policy pin in
the Pantry suite. Exhaustive search of legacy totals/digests found only this
remaining stale expectation: all policies are now 691 (690 normal plus the
unchanged isolated Unit-lock policy). Updated that exact total, retaining every
named-policy assertion. The 144 Pantry checks plus 33 history and 32 catalog
checks pass; no Pantry behavior or runtime code changed.
