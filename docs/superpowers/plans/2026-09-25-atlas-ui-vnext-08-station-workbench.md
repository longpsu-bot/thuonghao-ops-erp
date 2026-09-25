# Atlas UI vNext 08 Station Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan. The product owner requires one UI writer, so execute the implementation tasks below as one bounded writer assignment, then stop writing until the production render and finish-review gates complete.

**Goal:** Transfer the approved refined `Trạm Điều Hành` direction into the production Procurement allocation and Ingredient catalogue/detail surfaces without changing business behavior.

**Architecture:** Keep the existing vNext workbench controllers, bridges, commands, and state machines authoritative. Add one presentation-only task-context primitive if both primary surfaces confirm the same grammar, compose it beside the existing master/detail workbenches, and refine table/detail presentation locally. Desktop uses a 196px context plane plus a flexible master surface and an exact 320px attached detail; mobile replaces the plane with an 88px context block and keeps the detail below the table.

**Tech Stack:** React 19, TypeScript, Chakra UI v3 semantic tokens, Vitest, Testing Library, Playwright review harness.

**Spec:** `docs/ui/atlas-vnext-08-art-direction-options.md`

## Global Constraints

- Work only on `feat/atlas-ui-vnext-08-station-workbench`, based on refreshed design authority SHA `e97903b75eb1a9490028bfb02d010e49bf12d892`.
- Primary surfaces only: Procurement `Phân bổ nhà cung ứng` and Ingredients `Nguyên liệu` catalogue/detail.
- Secondary jobs may inherit a genuinely shared context primitive, but their internal composition must not change.
- Desktop task context is exactly `196px`; mobile task context is exactly `88px`; attached desktop detail is exactly `320px`.
- Target table header is approximately `38px`, rows approximately `42px`, and sticky identity approximately `178px` where the current table structure supports it.
- Mobile interactive targets are at least `44px`.
- Preserve local horizontal table scrolling and its continuation cue.
- Use existing shaped/read/controller values only. Do not invent metrics or reconstruct missing business facts in React.
- `AtlasTaskContext`, if created, is presentation-only: no navigation ownership, backend derivation, permissions, calculations, lifecycle interpretation, commands, or API calls.
- Reuse existing semantic tokens. `bg.context` may be added only for the durable context surface and must map to `#DDE7E1`; no raw production colors and no brand-palette change.
- Selection clay and eucalyptus keyboard focus remain visually distinct. No zebra striping, heavy grid, excessive badges, table card wrapper, fake KPI, stretched sparse rows, or filler.
- Keep Procurement exact quantity helpers, controller validation, command eligibility, participating-versus-eligible supplier meaning, and focus safeguards authoritative.
- Keep Ingredient 360-row density, explicit `Xem / sửa`, supplier condensation, permissions, lifecycle, dirty exit, review flow, commands, and stale/unknown recovery authoritative.
- Zero changes to Supabase, migrations, schema, RLS, API contracts, bridges, backend commands, Planning, Purchase Handoff, PO lifecycle, recipes, schools, Retool, or hosted business data.
- Do not edit `src/vnext/atlas/AtlasTaskTabs.ts`.
- Use TDD: add a focused failing assertion first, confirm the expected failure, implement the smallest production change, and rerun the focused test before proceeding.
- Do not weaken or delete certified tests. Commit implementation and documentation; do not push, merge, or open/modify PRs from the implementer assignment.

## Review Focus

- The task context must read as durable current-job orientation, not a second navigation sidebar.
- Sparse Procurement must look intentional through hierarchy, natural-height table geometry, and calm canvas.
- Dense Ingredients must remain operationally efficient and keep the catalogue dominant.
- The selected detail must feel physically attached to the work surface, not like a floating card.
- Production should be immediately closer to the refined Station prototype than to the #315 baseline.
- Accessibility evidence must cover unique action names, `aria-selected`, `aria-expanded`, focus entry/return, keyboard table access, visible focus, readable disabled controls, reduced motion, and 44px mobile targets.

---

### Task 1: Establish the shared Station context grammar

**Files:**

- Create: `src/vnext/atlas/AtlasTaskContext.tsx`
- Create: `src/vnext/atlas/AtlasTaskContext.test.tsx`
- Modify: `src/vnext/atlas/system.ts`
- Modify: `src/vnext/atlas/system.test.tsx`

**Steps:**

1. Add failing system assertions proving a semantic `bg.context` token maps to `#DDE7E1`, while selected-row and focus colors remain distinct.
2. Run `pnpm exec vitest run src/vnext/atlas/system.test.tsx` and confirm the new assertion fails for the missing token.
3. Add the smallest raw/semantic token definition necessary for `bg.context`; do not otherwise alter the palette.
4. Add focused component tests for:
   - semantic context background rather than a raw color;
   - `196px` desktop width;
   - `88px` mobile height;
   - module label, current-job identity, and concise existing summary content;
   - presentation-only markup with no navigation role or interactive control ownership.
5. Run `pnpm exec vitest run src/vnext/atlas/AtlasTaskContext.test.tsx` and confirm the missing component fails.
6. Implement a small responsive `AtlasTaskContext` using Chakra responsive props. Keep its API limited to display-ready React content already supplied by its parent.
7. Rerun both focused suites until green.

### Task 2: Transfer Station composition to Procurement allocation

**Files:**

- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementAllocationTable.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementSupplierDetail.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx`
- Modify only if an existing assertion belongs there: `src/vnext/atlas/AtlasTableViewport.test.tsx`

**Steps:**

1. Add failing assertions for the allocation job's visible context label/job/scope, a `196px` desktop context plane, an `88px` mobile block, flexible master width, exact `320px` desktop detail, and detail-below-table mobile order.
2. Add or strengthen failing interaction assertions proving:
   - the initiating row action has a unique accessible name and correct `aria-expanded`;
   - the selected row exposes `aria-selected`;
   - opening moves focus into the detail;
   - closing returns focus to the exact initiating row action;
   - `Lưu phân bổ` remains the dominant authorized action;
   - `Tiếp tục lên đơn` is not presented as a competing dominant action while detail is open;
   - existing disabled/error/uncertain behavior remains unchanged.
3. Run the Procurement-focused suites and confirm only the new presentation assertions fail.
4. Compose the allocation stage as context plus live operating surface. Keep secondary `Đơn mua` internals unchanged.
5. Refine the table to a quiet approximately `38px` header, approximately `42px` natural-height rows, intentional column proportions, approximately `178px` sticky identity where appropriate, tabular quantity/unit adjacency, restrained separators, clay selection rail, and eucalyptus focus treatment.
6. Keep the detail attached with no card elevation/gap treatment and an exact `320px` desktop width. Use only current Ingredient, quantity, unit, participating supplier, allocated quantity, difference/remainder, eligible supplier, and recommendation data.
7. Ensure one-to-three rows retain natural height with calm remaining canvas; add no KPI, filler, decoration, or row stretching.
8. Preserve the local horizontal viewport and continuation cue at tablet/mobile widths; ensure mobile actions are at least `44px`.
9. Rerun the focused Procurement and table-viewport suites until green.

### Task 3: Transfer Station composition to Ingredient catalogue/detail

**Files:**

- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientDetail.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
- Modify or create the nearest existing Ingredient detail test only when needed for focused coverage.

**Steps:**

1. Add failing assertions for the Ingredient module/job/scope context, `196px` desktop plane, `88px` mobile block, flexible catalogue, exact `320px` desktop detail, and mobile detail placement below the catalogue.
2. Add or strengthen failing interaction assertions proving:
   - explicit `Xem / sửa` remains the documented row action with a unique accessible name;
   - selection opens the correct Ingredient detail and moves focus into it;
   - close returns focus to the exact initiating `Xem / sửa` action;
   - editing preserves the actual `Xem thay đổi` workflow;
   - permission, lifecycle, dirty-exit, error, read-only, and stale/unknown behavior remains unchanged.
3. Run the Ingredient-focused suites and confirm only the new presentation/focus-return assertions fail.
4. Compose the Ingredient job as context plus dominant catalogue and attached detail. Keep the Supplier secondary job's internal composition unchanged.
5. Preserve all 360-row behavior while refining quiet headers, compact row rhythm, horizontal rules, human identity hierarchy, tabular quantities, restrained statuses, and existing supplier-priority condensation.
6. Keep Ingredient name dominant; unit, status, and supplier priority remain secondary. Do not make the row itself an undocumented navigation target.
7. Keep the detail attached at exactly `320px` on desktop and complete below the master table on mobile. Preserve controller-owned review/command behavior.
8. Preserve the local horizontal viewport and continuation cue; ensure mobile actions are at least `44px`.
9. Rerun the focused Ingredient suites until green.

### Task 4: Record the implementation boundary and self-verify the integrated change

**Files:**

- Create: `docs/implementation-tasks/TASK-ATLAS-UI-VNEXT-08-STATION-WORKBENCH.md`
- Modify: `docs/ui/atlas-vnext-08-art-direction-options.md`
- Modify only when an existing repository fixture is needed to expose an already-supported state: the relevant vNext review fixture file.

**Steps:**

1. Update the design authority status to record the locked product decisions: refined Station selected, Ledger density/restraint only, exact `320px` desktop detail, `196px` desktop context, `88px` mobile context, and no secondary-job redesign.
2. Add an implementation record containing scope, acceptance evidence, accessibility/security boundary, validation commands, screenshot matrix, rollback statement, and remaining risks. Do not claim render/reviewer/CI results before they exist; leave those evidence fields explicitly pending production capture rather than using ambiguous TODO placeholders.
3. Review the branch diff against the strict boundary. Revert any accidental bridge, backend, Planning, API, domain-model, or secondary-job composition edit.
4. Run the target suites one file/process at a time to avoid known aggregate-runner contention:
   - `src/vnext/atlas/system.test.tsx`
   - `src/vnext/atlas/AtlasTaskContext.test.tsx`
   - `src/vnext/atlas/AtlasTableViewport.test.tsx`
   - `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
   - `src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx`
   - `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
   - any additional directly changed detail test.
5. Run `pnpm typecheck` and `pnpm ui:vnext:check`.
6. Run targeted Prettier checks over every changed source, test, and document file, then `git diff --check`.
7. Self-review the full diff for semantics, accessibility, responsive geometry, production token use, and unnecessary complexity.
8. Commit the bounded implementation and report exact commits, commands, pass counts, changed files, and concerns. Stop before push, PR mutation, screenshots, or finish review.

### Task 5: Controller-owned render, evidence, and finish review gates

This task is not delegated to the UI writer until a bounded correction is required.

**Steps:**

1. Run the real production review harness and capture Procurement at `1440` no selection, `1440` selected, `1280` no selection, `768` no selection, `390` no selection, and `390` selected.
2. Capture Ingredients at `1440` catalogue, `1440` selected, `1280` catalogue, `768` catalogue, `390` catalogue, and `390` selected.
3. Capture existing fixture-backed loading, empty/no-match, error, permission/read-only, and stale/uncertain states when supported. Do not add business state solely for screenshots.
4. Create a contact sheet for Procurement `1440`/`390` and Ingredients `1440`/`390`, each ordered `#315 baseline → refined Station prototype → production implementation`.
5. If production remains visually closer to #315 than the prototype, classify it as a blocking transfer failure before review.
6. Package the exact branch diff, design specification, baseline screenshots, refined prototype screenshots, production screenshots, contact sheet, and test output for `atlas-ui-finish-reviewer`.
7. Require the reviewer to answer every finish-review question in the task brief and classify findings as `BLOCK`, `MAJOR`, or `MINOR`.
8. Send all `BLOCK` and `MAJOR` findings as one bounded correction wave to the original implementer; render the affected viewport/state again, rerun covering tests, and request one scoped re-review. Subjective `MINOR` findings are recorded without automatic churn.
9. Push the meaningful branch, open a dependent Draft PR targeting `design/atlas-ui-vnext-08-art-direction`, attach it to the task, and use GitHub Frontend CI as the authoritative routine suite.
10. Verify Cloudflare status, PR stack state, and that PR #286 remains untouched before the final report.
