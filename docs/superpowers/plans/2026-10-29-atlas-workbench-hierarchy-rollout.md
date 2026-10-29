# Atlas Workbench Hierarchy Rollout Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to execute these bounded families sequentially, with independent review and a final integration review. Do not stop between families for repeated approval.

**Goal:** Carry the accepted Allocation hierarchy through every active Atlas workbench and shared page.

**Architecture:** Preserve thirteen persistent owners and their existing view/controller/backend boundaries. Reuse Atlas's Chakra components and semantic roles; change presentation and local focus/disclosure state only. Keep each family independently testable and committed.

**Tech Stack:** React, TypeScript, Chakra UI v3, Vitest, existing Playwright review fixture.

**Spec:** `docs/ui/atlas-workbench-hierarchy-rollout.md`.

## Global constraints

- User-approved reference is `777d3237` / PR #446. Palette, Inter, type roles, provider and semantic meanings stay fixed.
- Warehouse Receiving remains paused; existing PXK and reconciliation UI are included.
- No controller/model/bridge/API/SQL/dependency/export-format/business-rule changes.
- Preserve 40px desktop and 44px narrow controls, exact Units, loaded-scope explanations, stable row identity, permissions, dirty/exit/UNKNOWN locks and focus restoration.
- Source truth wins over prettier screenshots; never rewrite synthetic dates, quantities, warnings or statuses.
- Target widths: 1920, 1440, 1366, 1024, 650, 390 and 360px. Test critical selected/edit states as well as default lists.
- Use the canonical E-drive checkout on `codex/atlas-workbench-hierarchy-rollout`. Verify workspace before editing. Only one implementation worker edits at a time; read-only assessment/review may overlap.
- Run one focused Vitest process at a time. GitHub Actions owns full routine validation. No repeated full local suite.
- Workers own only their named view files and affected tests; root owns task/plan/rollout documentation and shared evidence. Do not spawn further agents or revert others' work.

## Task 1: Shared shell and page foundations

**Files:** `src/vnext/atlas/AtlasSessionGate.tsx`, `AtlasVNextShell.tsx`, `AtlasTaskContext.tsx`, `AtlasWorkbar.tsx`, `AtlasTableViewport.tsx`, their direct tests. `AtlasVNextApp.tsx` only if a verified layout defect cannot be fixed in the view that owns it. Registry, provider and state/owner hooks are read-only.

**Interfaces:** Existing public props and navigation/owner callbacks stay identical. Other tasks consume the current components without a new generic page abstraction.

- [ ] Inspect baseline captures and the independent design/mechanical reports. Record which shared pages need changes and which already meet the spec.
- [ ] Correct only shared causes: common reading axes, wrapped utility actions, meaningful context and reachable sign-in fields. Retain legal company identity and all session states.
- [ ] If focus/disclosure behavior changes, add a targeted failing interaction test before implementation. For reversible spacing, use computed browser checks and existing behavioral tests rather than tests that mirror CSS.
- [ ] Run `pnpm exec vitest run src/vnext/atlas/AtlasSessionGate.test.tsx src/vnext/atlas/AtlasVNextShell.test.tsx src/vnext/atlas/AtlasWorkbar.contract.test.ts src/vnext/atlas/AtlasTaskContext.test.tsx --maxWorkers=1 --no-file-parallelism` for files that exist and are affected; check names against the repo first.
- [ ] Capture 1440/390/360px shared states, verify keyboard/scroll/targets, format changed files, commit and write the report.

## Task 2: Planning inputs and confirmed need

**Files:** View files in `src/vnext/atlas/planning/` and `planning-confirmed/`, excluding hooks, bridges, capability/model/quantity helpers and review-only design prototypes. Primary files: `PlanningSourcesWorkbench.tsx`, `PlanningMenuStage.tsx`, `PlanningAttendanceStage.tsx`, `PlanningPantryStage.tsx`, `PlanningSourceReview.tsx`, `ConfirmedNeedWorkbench.tsx`, `ConfirmedNeedTable.tsx`, `ConfirmedNeedCorrection.tsx`, `ConfirmedNeedSupportDetail.tsx`, `ConfirmedNeedIssuedOrders.tsx`, and direct tests.

**Contracts:** `docs/api/rmvp-03a-planning-inputs.md`, `pantry-02-source.md`, `rmvp-05-connected-confirmed-need-review.md`, `confirmed-need-save-release-v2.md`. Existing props and commands are unchanged.

- [ ] Keep period/school scope visible; group peer controls and move supporting review/history utilities behind existing disclosure when appropriate.
- [ ] Make attendance and confirmed quantities/Units usable on narrow widths without erasing the full desktop comparison. Use labeled, lined records where horizontal tables conceal the decision.
- [ ] Preserve source-row identity, explicit zero/blank distinctions, complete-write membership, import/paste review, backend Preview/Save/Approve and dirty/recovery semantics.
- [ ] Add a failing test only for changed interaction/focus; run direct changed component tests in one focused process, plus Planning/Need owner retention cases if affected.
- [ ] Capture default and representative edit/review states at 1440/1024/390/360px. Check exact labels/Units, focus, primary actions and local scrolling. Format, commit and report.

## Task 3: Purchase documents, PXK and reconciliation

**Files:** `src/vnext/atlas/procurement/ProcurementOrdersStage.tsx`, `ProcurementWorkbench.tsx`, `ProcurementPxkImpact.tsx`; `dispatch/SchoolPxkWorkbench.tsx`, `SchoolPxkTable.tsx`, `SchoolPxkDetail.tsx`, feedback/dialog views; `reconciliation/SchoolFulfilmentWorkbench.tsx`, `SchoolFulfilmentTable.tsx`, `SchoolFulfilmentDetail.tsx`, feedback view; direct tests. Allocation is the accepted reference: change it only for an evidenced integration regression.

**Contracts:** `docs/api/school-catering-procurement.md`, `school-dispatch-release.md`, and the reconciliation contract linked by its view/API type. No hooks, writers, release/export arrays or document snapshots change.

- [ ] Keep scope and selected document identity visible. Give broad selected documents their workplane and keep utility counts/export controls secondary to the document decision.
- [ ] Make narrow records intentionally labeled and primary commands reachable. Preserve complete loaded-period export/bulk-action explanations even when search filters the visible list.
- [ ] Retain draft/released/replacement/cancellation evidence, immutable numbers, guards and dirty notes. Do not invoke browser Save/release/export side effects.
- [ ] Run direct changed view tests and relevant export-scope/dirty/UNKNOWN regressions in one process. Add a failing focus test for any new dynamic transition.
- [ ] Capture default and selected document/detail states at 1440/1024/390/360px, including long action labels. Format, commit and report.

## Task 4: Schools, ingredients and suppliers

**Files:** View files in `src/vnext/atlas/schools/` and `master-data/`, excluding hooks, bridge/domain/lifecycle helpers and fixtures unless a visual case is missing. Include catalogues, details, priority/eligibility editors, cooking/dispatch membership views and existing review/dialog surfaces. Direct tests are included.

**Contracts:** Master Data and School defaults contracts referenced by those modules; `docs/business-rules/business-rule-register.md`. No catalogue sort identity, lifecycle, priority or allowed-action changes.

- [ ] Normalize title/context/workbar/body levels without hiding active/visible/unsaved counts or membership scope.
- [ ] Make selected record forms one clear workplane; align peer fields, distinguish immutable identity/supporting metadata, and keep mobile numeric defaults visible with their labels.
- [ ] Preserve full-draft Save membership, hidden-unsaved guards, lifecycle confirmations, supplier priority review and typed Units.
- [ ] Run direct changed view and relevant group/priority/lifecycle regression tests. Exercise navigation/focus after detail close and dynamic additions.
- [ ] Capture 1440/1024/390/360px list/detail/configuration states supported by fixtures, format, commit and report.

## Task 5: Recipes and change orders

**Files:** View files in `src/vnext/atlas/recipes/`, excluding hooks, domain/bridge/quantity helpers. Include `DishRecipeWorkbench.tsx`, `DishCatalogue.tsx`, `DishEditor.tsx`, `BaseRecipeEditor.tsx`, `EffectiveRecipeView.tsx`, `RecipeReview.tsx`, recipe dialogs, and the Change Order workbench/editor/detail/dialogs. Direct tests are included.

**Contracts:** `docs/api/rmvp-02a-recipes-bom.md`, `rmvp-02b-recipe-adjustments-effective-bom.md`, D-038 and existing adjustment precedence. No version, effective-date, preview, save/use-lock, copy/import or cancellation semantics change.

- [ ] Keep catalogue identity and active scope compact; give the selected recipe/change order a broad, clearly leveled workplane.
- [ ] Group ingredient/quantity/Unit rows and peer form fields; keep provenance, history and optional metadata secondary. Preserve the current recipe/change-order ownership split.
- [ ] Keep create/import/edit/preview/review/Save and destructive confirmations discoverable, with guards and return focus intact.
- [ ] Run changed component and relevant workflow/dirty/copy/import/effective-scope tests in one process; add a failing test only for new interaction behavior.
- [ ] Capture 1440/1024/390/360px catalogue, editor and review/detail states, format, commit and report.

## Task 6: Complete coverage and integration review

**Files:** `docs/ui/atlas-workbench-hierarchy-rollout.md`, `docs/ui/atlas-current-ui-inventory.md`, `docs/ui/atlas-design-language-v3.md`, `docs/autopilot/ACTIVE_TASK.md`, `docs/autopilot/ATLAS-AUTOPILOT.md`, phone-accessible artifacts under `docs/testing/artifacts/atlas-workbench-hierarchy/`. Only targeted fixes from the integrated review can touch earlier view files.

- [ ] Reconcile every owner and shared page against the spec; record review-only/no-change cases explicitly.
- [ ] Run the seven-width default/list matrix and family-specific selected/edit/review checks. Check shell navigation, retained owner drafts, guarded exit, keyboard focus, labels, exact quantities/Units and horizontal overflow.
- [ ] Run `pnpm typecheck`, changed-file Prettier, `pnpm ui:vnext:check`, `git diff --check`, and focused persistent-owner integration checks. Do not repeat successful module suites without a new reason.
- [ ] Run independent visual finish plus source/contract review. Resolve concrete findings in one batch and confirm once; record narrow limits instead of an endless polish loop.
- [ ] Publish phone contact sheets and a thirteen-owner coverage table, update documentation, commit, push one meaningful branch, create/attach the PR and inspect exact-head Frontend CI.
- [ ] Close the active rollout record with factual coverage and remaining physical-device/AT/hosted limits. Preserve old data-task and Warehouse evidence; no automatic data work or merge/deployment follows.
