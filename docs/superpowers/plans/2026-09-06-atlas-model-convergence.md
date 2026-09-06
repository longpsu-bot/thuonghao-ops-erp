# ATLAS-MODEL-CONVERGENCE-01 Implementation Plan

> **For agentic workers:** Use the installed `superpowers:subagent-driven-development` workflow, adapted to the explicit ownership and safety limits below. Do not dispatch nested agents or duplicate whole-repository exploration. Checkboxes are execution records, not claims that the work is done.

**Goal:** Adopt canonical Recipe authority in normal operator workflows, document explicit/derived/generated boundaries through Procurement, and produce exact-head acceptance evidence without hosted writes.

**Architecture:** Reuse existing PostgreSQL commands and shaped reads. React must not recreate effective selection, applicability, history, locks or copy materialization. Preserve working Planning/Procurement boundaries; record hosted readiness separately.

**Tech stack:** Repository-pinned React, TypeScript, Mantine, Supabase/PostgreSQL, Vitest/Testing Library and GitHub Actions. The inspected package uses Node 24 and pnpm 11; use the repository's actual pinned versions at execution time, not global defaults.

**Spec:** `docs/superpowers/specs/2026-09-06-atlas-model-convergence-design.md`.

> **Final integration amendment:** This plan records the original execution constraints. The later authorized `ATLAS-MODEL-CONVERGENCE-FINAL-01` integration adds the certified A07 and A12 components from Draft PRs #259/#260 to Draft PR #258, including migrations `20260906085653_recipe_system_command_context_01.sql` and `20260906105509_recipe_legacy_issuance_read_01.sql`. Current results and gates are recorded in `docs/implementation-tasks/TASK-ATLAS-MODEL-CONVERGENCE-01.md`.

## Global constraints

- Repository: `longpsu-bot/thuonghao-ops-erp`.
- Inspected baseline: `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`; verify current `origin/main` and relevant changes before editing.
- Current task-selected checkout is authoritative only after `AGENTS.md` preflight. Old remembered drive paths are not authorization.
- Work only in an isolated verified task worktree/branch. No reset, stash manipulation, untracked-file overwrite, or force push.
- Live OPS `qnthofvccilhnefdcxnz`, Retool and all hosted environments: no writes. Atlas Staging `rnzxmxiiqgtdevzregff`: bounded read-only readiness inspection only.
- No merge, no explicit deployment, no data cutover, no compatibility API deletion, no new role/capability/table/lifecycle/library.
- No migration planned. Report a required unsupported backend contract instead of authoring an unapproved replacement.
- Existing immutable evidence, exact quantities, security, concurrency, receipts and unknown-outcome protections remain intact.
- Full routine frontend and database validation belongs to GitHub Actions. Do not independently start/reset Supabase in each worker.
- One lead plus at most three active workers; no nested spawning. Code owners do not edit shared files concurrently.
- Finish required bounded work without repeated approval questions. Genuine security, destructive, scope/contract or environment blockers remain blockers; complete safe independent tasks and report them.

## Task 0 — Verify baseline and freeze ownership

**Owner:** Lead. **Files changed:** none before preflight passes.

- [ ] Read `AGENTS.md` and its mandatory project documents, the packet decision/spec/matrix, current corrected Recipe spec/API contracts, and only affected implementation/tests.
- [ ] Run the repository's workspace verification:

```sh
git rev-parse --show-toplevel
git remote -v
git fetch origin
git branch --show-current
git status --short
pnpm ops:workspace
git rev-parse origin/main
```

- [ ] Confirm PR #257 is merged and required canonical Recipe APIs/models are present. If main advanced, inspect the relevant delta, identify already completed work, and record the selected execution baseline. Do not apply a stale patch or restore an old SHA over new work.
- [ ] Establish the task branch, suggested `codex/atlas-model-convergence-01`, in an isolated verified workspace using existing worktree practices. A colliding active task branch must not be overwritten.
- [ ] Keep the packet outside the checkout until the authorized integration. Integrate its `docs/` files after preflight; do not recursively overwrite unrelated existing documents.
- [ ] Create one task ledger in the existing ignored task workspace. Record baseline, assigned files, contracts, task progress, tests, commits, gaps and rulings. Recover from that ledger after compaction rather than restarting completed work.

**Done:** verified baseline, clean initial workspace, fixed ownership map, no hosted mutation.

## Task 1 — Map existing contracts and integrate authority documents

**Owner:** Worker A, with lead approval of the contract map. Starts before other code workers; documentation can continue concurrently after interface freeze.

**Read:**

```text
src/modules/atlas/recipes/recipeApi.ts
src/modules/atlas/recipes/recipeModel.ts
src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.ts
src/modules/atlas/recipe-adjustments/recipeAdjustmentModel.ts
src/modules/admin/DishRecipeAdminWorkbench.tsx
src/modules/admin/RecipeAdjustmentWorkbench.tsx
docs/api/rmvp-02a-recipes-bom.md
docs/api/rmvp-02b-recipe-adjustments-effective-bom.md
docs/superpowers/specs/2026-09-05-recipe-effective-product-model-correction-design.md
```

**Modify:** packet documentation; targeted living sections of `docs/current-context.md`, `docs/architecture/roadmap.md`, `docs/decisions/decision-register.md`, `docs/api/rmvp-03b-planning-input-readiness.md`; add links in affected current Recipe/Planning/Procurement API documents only where required. No broad historical rewrite.

**Produces:** one contract-to-UI mapping, with method/field/owner and acceptance ID; one evidence-backed normal/support command map. Production source is read-only for Worker A.

- [ ] Map catalog/reference loading, selected `base_authoring`, effective result, copy target Dish version, two returned scope results, stable target XOR, system-only preview/create, temporal state, and nullable legacy attribution.
- [ ] Specifically verify the system Preview/Create path and whether any accepted catalog search requires unsupported whole-catalog effective data. Do not assume that new target-context reads alone fixed all command-envelope requirements.
- [ ] Identify existing parser holes affecting newly consumed data; give Worker B/C exact cases, not a generic validation framework.
- [ ] Lead freezes interfaces and ownership. Unsupported required contracts become explicit blockers for the affected behavior, not fabricated payloads or proxy Schools.
- [ ] Integrate decision and authority-map documents. Register the named decision using the repository convention; do not invent a preapproved numbered ADR or renumber history.
- [ ] Correct the stale living Attendance setup description and demand-flag description against the final amendment. Preserve historical statements with clear supersession links.
- [ ] Report documentation diff, current/support distinctions and any backend gaps to the lead.

**Done:** G0 mapped; documentary authority aligned; no unsupported business rules introduced.

## Task 2 — Connect canonical Recipe display, typed authoring and atomic copy

**Owner:** Worker B. Starts only after Task 1 interface freeze.

**Owns:**

```text
src/modules/admin/DishRecipeAdminWorkbench.tsx
src/modules/admin/DishRecipeAdminWorkbench.test.tsx (reuse if present; otherwise create)
src/modules/atlas/recipes/recipeApi.ts
src/modules/atlas/recipes/recipeApi.test.ts
src/modules/atlas/recipes/recipeModel.ts
src/modules/atlas/recipes/recipeModel.test.ts
src/modules/atlas/recipes/reviewRecipeApi.ts
```

Existing Recipe-specific story/test siblings may be updated after verifying their actual paths. Shared adjustment types, global CSS, RPC registry and parent shell integration remain lead-owned unless ownership is explicitly transferred in the ledger.

**Consumes:** existing `getEffectiveWorkbench`, `dishRecipeOperatorWorkbenchFromResult`, `base_authoring`, `dishRecipeCopyRequest`, `dishRecipeCopyFromResult`, `saveRecipe` and `RecipeEffectiveContext`.

**Produces:** one connected normal Recipe surface with explicit contexts and correct authoritative command routing.

- [ ] Write failing component tests for R01–R15 and C01/C03/C08/C09/C11 using current fixture conventions. Make base and effective composition disagree in R07. Introduce only missing cases.
- [ ] Run the affected component/API/model tests before implementation and record the expected failure, not merely a setup error.
- [ ] Replace local effective-version selection in normal current/effective display with authoritative workbench data. Keep any base reference view explicitly distinct.
- [ ] Use canonical returned roots/types for normal authoring; preserve root-only editability and backend Save/lock authority. Remove nullable GENERAL from normal navigation without deleting compatibility types/functions.
- [ ] Preserve useful search with truthful scope, selected-detail lazy loading, read-only context navigation and dirty-work guards.
- [ ] Replace browser-only version cloning with one atomic Dish-copy request, target Dish version, explicit date/reason, both-scope result validation and authoritative DRAFT readback. Preserve complete retry intent only under supported recovery rules.
- [ ] Protect all touched mutation success paths from malformed responses, failed readback and late context changes. Do not clear uncertainty after an unrelated read.
- [ ] Update review fixtures to return shaped backend semantics, including divergent base/effective facts, two-scope output and fault cases. Do not implement a second resolver in fixtures.
- [ ] Rerun focused tests and format only touched files. Commit the independently testable Recipe change and return file list, evidence and gaps.

Example request-contract test, to integrate with existing imports and harness rather than duplicate a file:

```ts
import { expect, it } from "vitest";
import { dishRecipeCopyRequest } from "./recipeApi";

it("keeps the explicit date and target Dish version in copy intent", () => {
  const request = dishRecipeCopyRequest({
    authSubject: "actor-subject",
    correlationId: "correlation",
    commandId: "copy-command",
    idempotencyKey: "copy-key",
    requestedAt: "2026-09-06T01:00:00.000Z",
    expectedVersion: 7,
    reasonCode: "TEST_COPY_SERIALIZATION",
    reasonNote: "Copy reviewed system recipe pair",
    sourceDishId: "source-dish",
    targetDishId: "target-dish",
    asOfDate: "2026-09-07",
  });
  expect(request.contract_version).toBe("RECIPE-EFFECTIVE.v1");
  expect(request.expected_version).toBe(7);
  expect(request.payload).toEqual({
    source_dish_id: "source-dish",
    target_dish_id: "target-dish",
    as_of_date: "2026-09-07",
  });
});
```

This is a serialization unit test, not a valid authenticated DB request or proof of the backend reason-code vocabulary. The connected implementation must use the accepted command reason code verified from the actual backend validator. The essential adoption test is that the real component calls this command once, not merely that the builder exists.

## Task 3 — Connect effective Change Order targets and history

**Owner:** Worker C. Runs concurrently with Task 2 only after contract/type freeze.

**Owns:**

```text
src/modules/admin/RecipeAdjustmentWorkbench.tsx
src/modules/admin/RecipeAdjustmentWorkbench.test.tsx (reuse if present; otherwise create)
src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.ts
src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.test.ts
src/modules/atlas/recipe-adjustments/recipeAdjustmentModel.ts
```

Verify actual adjustment model-test/review-fixture siblings before editing. No writes to Worker B files. Any required shared type change is proposed to the lead before dependent work starts.

**Consumes:** existing `getEffectiveTargetContext`, `RecipeEffectiveContext`, stable line origin, current Preview/Create/Supersede/Cancel envelopes and backend ledger fields.

**Produces:** target selection preserving base/ADD identity and exact reviewed context, plus backend-owned temporal/history presentation.

- [ ] Add failing tests for A01–A12 not already covered. Include a SYSTEM_DISH ADD target, a SCHOOL_DISH ADD target, a late Preview result, and unrelated same-type School rules.
- [ ] Run targeted tests and record RED evidence.
- [ ] Replace raw Recipe-line filtering with effective-target reads for non-ADD Dish-scoped operations. Preserve the exact target-kind/ID XOR through all touched commands and corrections.
- [ ] Keep Ingredient-level operations and ADD on their established contracts. Verify Unit semantics; do not infer a Unit from the first active catalog row when the selected evidence governs it.
- [ ] Remove representative-School proxies from normal system context. If existing Preview/Create cannot support the accepted context, record the tested gap instead of contaminating it with a School result.
- [ ] Invalidate reviewed proposals on changed intent and ignore superseded responses. Preserve authorization and unknown-outcome constraints.
- [ ] Render backend history periods, material exception counts and temporal applicability, including legitimate unattributed history. No local revision replay or inferred effectiveness.
- [ ] Run focused GREEN checks, format touched files, commit and return exact evidence.

## Task 4 — Integrate, preserve cross-domain boundaries, and record Staging readiness

**Owner:** Lead. Do not modify Worker B/C files until ownership is returned.

**Lead-owned shared files:** `src/styles.css` only scoped Recipe selectors; parent shell wiring if demonstrably required; RPC registry only for verified existing identity alignment; relevant existing CI registration only for a genuinely new required test; final report. No dependency or global design-system changes.

- [ ] Inspect each worker diff and integrate without overwriting another worker's work. Review root/child context propagation and mutual use of shared types.
- [ ] Map P01–P07, Q01–Q07 and S01–S04 to existing tests. Add only missing regression coverage in existing test locations; Planning/Procurement production modules remain unchanged.
- [ ] Register any added executable suite using the existing workflow/registry mechanism. Do not create an unused test file and count it as coverage.
- [ ] Capture scoped browser/Storybook artifacts using the existing project tooling, at a normal desktop width and narrower width. Show root-only editing, locked effective view, School exception, copy review/DRAFT readback, prior ADD target and failure recovery. Report any inability to run a real browser; do not call static markup a browser test.
- [ ] Perform the [read-only Staging runbook](../../runbooks/atlas-model-convergence-staging-readiness.md) only through authorized access. Mark unavailable access NOT VERIFIED. Never run a verifier merely because its name sounds read-only; inspect its actual side effects.
- [ ] Record named gaps and deferred P2 cleanup. Do not backfill GENERAL rows or deploy #257 just to make the report look green.

## Task 5 — Independent review and exact-head validation

**Owners:** Lead orchestrates fresh read-only reviewers after implementation workers release ownership. Reviewer 1 checks spec/authority; Reviewer 2 checks safety, correctness, races and test sufficiency. Maximum three child threads remains in force.

- [ ] Give each reviewer the spec, matrix, baseline/head SHA, integrated diff and concise test evidence; do not inherit the whole exploration history.
- [ ] Address substantive findings with the owning worker or lead. Record rulings for non-blocking style suggestions; do not use “complexity” alone to expand scope.
- [ ] Run focused development validation, using actual affected files to narrow further when useful:

```sh
pnpm exec vitest run src/modules/admin src/modules/atlas/recipes src/modules/atlas/recipe-adjustments
pnpm typecheck
git diff --check
```

- [ ] Run Prettier on the exact changed supported files; do not reformat the entire repository.
- [ ] Commit the reviewed integration and record its SHA. Push only the task branch and open one meaningful Draft PR. Do not merge, force push, or change the PR to Ready automatically.
- [ ] Let existing Frontend CI run. Inspect failures and fix only relevant defects; do not rerun successful broad suites repeatedly.
- [ ] After confirming the current integration workflow remains disposable/non-hosted, dispatch exactly one final `supabase-integration.yml` run for the task branch using the existing `workflow_dispatch`. Freeze the head while it runs. Verify the returned run's SHA equals the reviewed integration SHA and required jobs/suites actually execute. A skipped/neutral job is not a pass.
- [ ] If a fix changes the head, rerun the affected gate on the new final head; never combine old-head results into a claim of exact-head acceptance.
- [ ] Return PR URL, base/head SHA, changed files, acceptance-to-evidence map, tests/results, reviewers/findings, unresolved contract gaps, Staging readiness and explicit no-merge/no-hosted-write status.

## Execution discipline

Prefer isolated worker worktrees and lead-controlled integration. If the runtime shares one worktree, file ownership remains disjoint and only the lead stages/commits after a worker hands back ownership; workers must not race on Git’s shared index. The lead runs cross-worker checks and dispatches CI; workers do not each run the full matrix. Use extra-high reasoning for integration and nontrivial code/review work; high is sufficient for narrowly mechanical documentation inventory. Maintain small commits but one coherent PR for this bounded work.

Tasks may pause for unsupported contracts or protected operations, not for routine “continue?” questions. Complete safe independent deliverables when blocked and name exactly which acceptance IDs remain open. Do not mark the entire philosophy “implemented” while required Recipe consumers or hosted readiness are unresolved.
