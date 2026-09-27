# Atlas UI-09 Post-Planning Station Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development while implementing each task. The parent controller retains orchestration; `atlas-chakra-implementer` is the sole repository writer for Tasks 1–6; `atlas-ui-finish-reviewer` is read-only. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge Procurement, Ingredients, Planning Sources and Confirmed Need on the approved Atlas Station presentation without changing current backend or business behavior.

**Architecture:** Add two presentation-only shared Station primitives and one semantic context token, then adapt each current workbench in place. Current hooks, bridges, API contracts, exact-quantity helpers, permissions, command semantics and certification selectors remain unchanged. Review-only fixtures and stories provide render evidence without hosted writes.

**Tech Stack:** React 19, TypeScript, Chakra UI v3, Vitest/Testing Library, Storybook/Vite.

**Spec:** `docs/ui/atlas-vnext-09-post-planning-design.md`

## Global Constraints

- Start from current `origin/main` baseline `42e473b5b856100869538f4e41ef5a325b99c893` on `feat/atlas-ui-vnext-09-post-planning-convergence`.
- Use pinned UI reference `ea154020bef6a068c1a9f70f5b6ba93d65ccc4a0` only as presentation authority; never overwrite newer current-main behavior.
- The implementer must rerun the six canonical workspace-verification commands before editing and stop on mismatch.
- No changes to `supabase/**`, migrations, RLS, privileges, RPC/API contracts, Planning/Confirmed Need hooks or draft/authority helpers, retained Staging data, Retool, PR #286, `index.html`, or `src/main.tsx`.
- No hosted Generate, Save, D046, Handoff, Procurement release or other business write.
- No Mantine in vNext and no new framework, grid, virtualizer, state manager, date helper or decimal helper.
- Use semantic tokens/recipes; `bg.context` is the only authorized new palette token.
- TDD is mandatory for changed behavior: write the focused test, verify the expected RED, implement the minimum, verify GREEN, then refactor.
- Exclude `.worktrees/**` from local Vitest discovery; repository-local worktrees otherwise duplicate suites.
- Preserve exact quantities, stable line selectors, accessible labels, dirty guards, permission maximums, recovery and authoritative readback.
- Commit coherent phases; do not combine backend or unrelated visual changes.

## Review Focus

- Long Vietnamese Ingredient/School/location names at 200% zoom must wrap without document-wide overflow or displaced authoritative actions; cover in shared/surface layout tests and renders.
- A read error must never appear as a successful zero count; cover Ingredient and context display tests.
- A valid Confirmed Need adjustment must remain visually distinct from invalid input and preserve exact decimal strings; cover table tests.
- Detail/review focus must enter the opened region and return to the exact row/trigger that opened it; cover Procurement, Ingredient and Planning tests.
- Local overflow must be named and keyboard reachable at desktop/tablet/mobile without hiding business fields; cover the shared viewport test and render matrix.

---

### Task 1: Shared Station foundation

**Files:**

- Create: `src/vnext/atlas/AtlasTaskContext.tsx`
- Create: `src/vnext/atlas/AtlasTaskContext.test.tsx`
- Create: `src/vnext/atlas/AtlasTableViewport.tsx`
- Create: `src/vnext/atlas/AtlasTableViewport.test.tsx`
- Modify: `src/vnext/atlas/system.ts`
- Modify: `src/vnext/atlas/system.test.tsx`

**Interfaces:**

- Consumes: existing Chakra system semantic tokens, spacing, table recipe and structural CSS-variable convention.
- Produces: presentation-only `AtlasTaskContext` and `AtlasTableViewport`; semantic `bg.context` for Tasks 2–5.

- [x] **Step 1: Inspect the pinned components and current test conventions**

Use `git show ea154020bef6a068c1a9f70f5b6ba93d65ccc4a0:<path>` for the old shared components/tests and compare against current Chakra patterns. Do not copy stale consumer/controller code.

- [x] **Step 2: Write failing shared tests**

Test observable contracts: one supplied H1, explicit accessible summary, 196px desktop/88px compact composition, `bg.context`, named focusable region, local overflow and continuation cues, native children rendering, reduced-motion-compatible presentation, and no callback/business-state API.

- [x] **Step 3: Verify RED**

Run:

```bash
pnpm exec vitest run --exclude ".worktrees/**" src/vnext/atlas/AtlasTaskContext.test.tsx src/vnext/atlas/AtlasTableViewport.test.tsx src/vnext/atlas/system.test.tsx
```

Expected: new component imports/contracts fail because they do not exist yet.

- [x] **Step 4: Implement the minimum shared presentation**

Adapt the pinned task context for explicit accessible text and current consumers. Port the table viewport without rows, columns, selection, filtering, sorting, pagination or business state. Add only the approved `bg.context` semantic token.

- [x] **Step 5: Verify GREEN and refactor**

Run the Task 1 test command and `pnpm ui:vnext:check`. Keep presentation responsibilities explicit.

- [x] **Step 6: Commit**

```bash
git add src/vnext/atlas/AtlasTaskContext.tsx src/vnext/atlas/AtlasTaskContext.test.tsx src/vnext/atlas/AtlasTableViewport.tsx src/vnext/atlas/AtlasTableViewport.test.tsx src/vnext/atlas/system.ts src/vnext/atlas/system.test.tsx
git commit -m "feat(atlas-ui): converge shared Station presentation"
```

### Task 2: Procurement Station port

**Files:**

- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementAllocationTable.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementSupplierDetail.tsx`
- Modify only if presentation requires: `src/vnext/atlas/procurement/ProcurementSchoolScope.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.stories.tsx`
- Modify only for review data: `src/vnext/atlas/procurement/procurementReviewFixtures.ts`

**Interfaces:**

- Consumes: Task 1 shared primitives and current `useProcurementWorkbench`, bridge/models and exact-quantity helpers unchanged.
- Produces: current Procurement behavior inside Station context, natural-height table and fixed desktop detail.

- [x] **Step 1: Write failing Procurement tests**

Add focused assertions for Station H1/context, named local viewport, eight preserved columns, unique Ingredient+location row actions, synchronized `aria-selected`/`aria-expanded`, exact 320px desktop detail contract, 44px mobile targets, focus entry/return and editing action hierarchy. Retain every existing behavior assertion.

- [x] **Step 2: Verify RED**

```bash
pnpm exec vitest run --exclude ".worktrees/**" src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx src/vnext/atlas/AtlasProcurementExit.test.tsx src/vnext/atlas/procurement/useProcurementWorkbench.test.tsx
```

Expected: only new Station/layout/accessibility assertions fail.

- [x] **Step 3: Implement the Station composition**

Use current controller outputs verbatim. Keep Orders stage behavior current. Make `Lưu phân bổ` dominant while detail is dirty/editable, preserve supplier participation/eligibility distinctions and keep routine refresh/continuation subordinate according to current state.

- [x] **Step 4: Verify GREEN**

Run the Task 2 command. Rerun any load-sensitive timeout individually instead of increasing global timeouts or weakening assertions.

- [x] **Step 5: Commit**

```bash
git add src/vnext/atlas/procurement
git commit -m "feat(atlas-ui): port Station Procurement"
```

### Task 3: Ingredient Station port

**Files:**

- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientDetail.tsx`
- Modify only if presentation requires: `src/vnext/atlas/master-data/IngredientPriorityEditor.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.stories.tsx`
- Modify only for review data: `src/vnext/atlas/master-data/ingredientSupplierReviewFixtures.ts`

**Interfaces:**

- Consumes: Task 1 primitives and current Ingredient/Supplier controller/model unchanged.
- Produces: 360-row catalogue within Station context and fixed desktop Ingredient detail.

- [x] **Step 1: Write failing Ingredient tests**

Cover truthful/unknown result count, 360 rows, condensed priority suppliers, restrained status text, unique explicit row actions, named viewport, selected state, exact 320px detail, archived/read-only presentation and focus entry/return. Preserve lifecycle, priority, review, dirty-exit, permission and validation tests.

- [x] **Step 2: Verify RED**

```bash
pnpm exec vitest run --exclude ".worktrees/**" src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx src/vnext/atlas/master-data/ingredientSupplierReviewFixtures.test.ts src/vnext/atlas/master-data/ingredientSupplierModel.test.ts src/vnext/atlas/master-data/useIngredientSupplierWorkbench.test.tsx
```

- [x] **Step 3: Implement the catalogue/detail composition**

Keep Supplier inner workflow current. Do not add pagination/virtualization or change lifecycle authority. Ensure `Tạo nguyên liệu` dominates only when no detail/review is active.

- [x] **Step 4: Verify GREEN**

Run the Task 3 command; validate the 360-row assertion separately if aggregate execution reaches the inherited five-second timeout.

- [x] **Step 5: Commit**

```bash
git add src/vnext/atlas/master-data
git commit -m "feat(atlas-ui): port Station Ingredients"
```

### Task 4: Planning Sources Station extension

**Files:**

- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.tsx`
- Modify: `src/vnext/atlas/planning/PlanningMenuStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningAttendanceStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningPantryStage.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourceReview.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning/planningSourceIsolation.test.tsx`
- Modify: `src/vnext/atlas/planning/PlanningSourcesWorkbench.stories.tsx`
- Modify only for review data: `src/vnext/atlas/planning/planningStoryFixtures.ts`, `src/vnext/atlas/planning/planningReviewFixtures.ts`

**Interfaces:**

- Consumes: Task 1 primitives; current `usePlanningSources`, Planning APIs, payload/currentness semantics unchanged.
- Produces: three current source jobs with Station hierarchy and a task-specific wide comparison review.

- [x] **Step 1: Write failing Planning tests**

Cover visible current-job H1, context/workbar order, truthful mobile filter summary, named viewports and source-specific minimum-width/sticky behavior. Add focus-entry/return and review geometry assertions. Preserve week/date/School transitions, search, refresh, warnings, errors, imports, explicit zero/no-additions, correction, dirty exit and Save command counts.

- [x] **Step 2: Verify RED**

```bash
pnpm exec vitest run --exclude ".worktrees/**" src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx src/vnext/atlas/planning/planningSourceIsolation.test.tsx src/vnext/atlas/planning/planningPantryReviewRows.test.ts src/vnext/atlas/planning/usePlanningSources.test.tsx src/vnext/atlas/AtlasModuleExit.test.tsx
```

- [x] **Step 3: Implement Station context and source-specific surfaces**

Keep `PlanningCapability` navigation unchanged. Do not hide fields. Keep Menu, Attendance and Pantry utilities/semantics intact. Apply local viewports and the desktop `minmax(330px, .9fr) / minmax(440px, 1.1fr)` review; stack at 768px and below.

- [x] **Step 4: Verify GREEN**

Run the Task 4 command. Confirm frozen review disables routine refresh and focus returns to the exact trigger.

- [x] **Step 5: Commit**

```bash
git add src/vnext/atlas/planning
git commit -m "feat(atlas-ui): apply Station hierarchy to Planning sources"
```

### Task 5: Confirmed Need Station extension

**Files:**

- Modify: `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.tsx`
- Modify: `src/vnext/atlas/planning-confirmed/ConfirmedNeedTable.tsx`
- Modify only if presentation requires: `src/vnext/atlas/planning-confirmed/ConfirmedNeedSupportDetail.tsx`
- Modify only if presentation requires: `src/vnext/atlas/planning-confirmed/ConfirmedNeedCommandFeedback.tsx`
- Modify: `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.test.tsx`
- Modify: `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.stories.tsx`
- Modify/add review-only fixture coverage: `src/vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures.ts`

**Interfaces:**

- Consumes: Task 1 primitives and current `useConfirmedNeedWorkbench`, `useConfirmedNeedDraft`, authority/draft helpers and bridge/contracts unchanged.
- Produces: seven-function decision surface, correct Save/Continue hierarchy and UI-09 certified-shape review fixture.

- [x] **Step 1: Write failing Confirmed Need tests**

Cover Station context, named table viewport, all seven semantic columns, proposal/confirmation/delta distinction, valid-adjustment versus invalid styling, both rounding-step disclosures, exact/historical strings, protected stable selector, secondary utilities/support detail, dirty Save dominance, clean authorized continuation dominance, read-only state, and 248 current rows with 249 historical identities only in fixture evidence.

- [x] **Step 2: Verify RED**

```bash
pnpm exec vitest run --exclude ".worktrees/**" src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.test.tsx src/vnext/atlas/planning-confirmed/confirmedNeedDraft.test.ts src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.test.tsx src/vnext/atlas/AtlasOperationStatus.test.tsx src/vnext/atlas/AtlasUnresolvedExit.test.tsx src/vnext/atlas/formatExactQuantity.test.ts
```

- [x] **Step 3: Implement the decision composition**

Keep operation timing/status outside the table subtree. Do not change exact arithmetic, accessible field labels, stable selectors, generation/Save payloads or navigation semantics. Valid business adjustment is not a warning. Shopping-list and support actions stay secondary.

- [x] **Step 4: Verify GREEN**

Run the Task 5 command. Confirm timer ticks do not unnecessarily rerender the 248-row table using existing component boundaries/tests rather than new persisted state.

- [x] **Step 5: Commit**

```bash
git add src/vnext/atlas/planning-confirmed
git commit -m "feat(atlas-ui): refine Confirmed Need Station"
```

### Task 6: Integrated evidence, documentation and writer handoff

**Files:**

- Create: `docs/implementation-tasks/TASK-ATLAS-UI-VNEXT-09-POST-PLANNING-CONVERGENCE.md`
- Modify: `docs/ui/atlas-vnext-09-post-planning-design.md` only for implementation-evidence corrections, not historical rewrite
- Modify: this plan to check completed steps and record actual commands/results
- Store screenshot binaries/manifests/contact sheet outside Git under the task visualization directory

**Interfaces:**

- Consumes: completed Tasks 1–5 and actual production review stories.
- Produces: review package for `atlas-ui-finish-reviewer`, complete evidence record and protected-boundary proof.

- [x] **Step 1: Run focused regression suites**

Run all Task 1–5 commands with `.worktrees/**` excluded. If aggregate execution times out, record it and rerun the timed-out tests individually; never weaken assertions or globally increase limits as a substitute for behavior proof.

- [x] **Step 2: Run required static validation**

```bash
pnpm typecheck
pnpm ui:vnext:check
git diff --check
```

List every tracked file changed from the baseline with `git diff --name-only 42e473b5b856100869538f4e41ef5a325b99c893...HEAD`, classify which paths Prettier supports, and run `pnpm exec prettier --check` with that explicit path list. Record the exact list and result in the implementation record.

- [x] **Step 3: Capture current production renders**

Use review stories/fixtures without hosted writes. Capture Procurement, Ingredients, Planning Sources and Confirmed Need at 1440×900, 1280×800, 768×1024 and 390×844, including the state variants required by the design. Record browser/DPR, console and network. Label each image with exact commit SHA, surface, state, viewport and fixture. Produce a compact contact sheet outside Git.

- [x] **Step 4: Perform manual interaction review**

Check keyboard order, focus entry/return, local versus document overflow, 44px mobile targets, 200% zoom, large text, long Vietnamese labels and reduced motion.

- [x] **Step 5: Write the implementation record**

Record baseline/reference SHAs, director verdict, transfer ledger, actual files, test/render evidence, security review, zero database/migration rollback, protected paths and remaining evidence-backed risks.

- [x] **Step 6: Verify protected files**

Compare from `42e473b5b856100869538f4e41ef5a325b99c893` and confirm zero unauthorized changes under `supabase/**`, Planning certification/closeout/performance scripts and workflows, `index.html`, and `src/main.tsx`.

- [x] **Step 7: Commit**

```bash
git add docs/implementation-tasks/TASK-ATLAS-UI-VNEXT-09-POST-PLANNING-CONVERGENCE.md docs/ui/atlas-vnext-09-post-planning-design.md docs/superpowers/plans/2026-09-27-atlas-ui-vnext-09-post-planning-convergence.md
git commit -m "test/docs(atlas-ui): add UI-09 acceptance evidence"
```

### Task 6 actual results

- Focused Tasks 1–5: 22 files passed, 315 tests passed, zero failed.
- Task 6 evidence-defect TDD: initial mobile-target RED was 2 failed/12 passed; first GREEN was 14/14; remaining date/tab RED was 2 failed/26 passed; final GREEN was 28/28.
- Static checks: `pnpm typecheck`, `pnpm ui:vnext:check`, explicit Prettier for all supported changed files, and `git diff --check` passed.
- Production evidence SHA: `d00d8ddd11428d9251ab6222294db6a3ec395919`; exact baseline SHA: `42e473b5b856100869538f4e41ef5a325b99c893`.
- Render evidence: 40 current captures plus four exact-baseline 1440×900 comparisons; zero non-loopback requests, zero document overflow, zero 44px target violations, zero missing local continuation cues and zero focus-entry/return failures.
- Evidence root: `C:\Users\hp\.codex\visualizations\2026\09\27\01a0e35e-6f81-7113-9bd0-ed7c6a5400c2\atlas-ui-09-evidence`.
- Protected diff across `supabase/**`, `.github/workflows/**`, `scripts/**`, `index.html` and `src/main.tsx`: zero paths.
- Full details, console/runtime limitation, security review, rollback and remaining risks are recorded in `docs/implementation-tasks/TASK-ATLAS-UI-VNEXT-09-POST-PLANNING-CONVERGENCE.md`.

## Finish-review loop

After Task 6, the controller supplies the director design, this plan, transfer ledger, changed-file list, tests, render matrix, contact sheet and current-main baseline to the read-only `atlas-ui-finish-reviewer`.

- Any BLOCK or MAJOR finding returns to the same `atlas-chakra-implementer` through `followup_task`.
- The implementer adds a failing regression test where behavior changed, performs the smallest presentation correction, reruns affected tests/renders and commits.
- The controller reruns affected validation and sends the revised evidence to the same finish reviewer.
- Repeat until there is no BLOCK or MAJOR finding. Record deferred MINOR items only when fixing them would materially expand scope.

## Delivery

After fresh verification and a PASS/no-BLOCK-no-MAJOR review, push the exact branch, open one Draft PR against current `main`, attach the PR to this task, and wait for exact-head `Frontend CI / Format, typecheck, test, build`. Do not merge or cut over production.
