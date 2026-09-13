# Atlas UI vNext 06D-E Integration and Certification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Converge 06D-A/B/C/D across all seven connected workbenches, remove plain-text treatment from real operator commands, certify the exact frontend/backend boundary, and leave the existing #286 entrypoint cutover candidate ready for a separate rebase/re-certification decision.

**Architecture:** This is a closeout/certification slice, not a new feature layer. Use the shared 06D-A recipes to classify every remaining `utility` use by operator semantics, run full frontend and disposable Supabase regression certification, capture visual evidence at four standard viewports, and perform only read-only hosted verification. Do not merge, deploy production, or mutate Staging/live OPS.

**Tech Stack:** React 19.2.7, TypeScript 7.0.2, Chakra UI 3.37.0, Vitest 4.1.10, Storybook 10.5, Vite 8.1.4, pnpm 11.7.0, Supabase CLI 2.111.0, Cloudflare Pages branch previews.

**Spec:** `docs/superpowers/specs/2026-09-13-atlas-ui-vnext-06d-interaction-affordance-design.md`

## Global Constraints

- Requires 06D-A/B/C/D to be individually green before this plan begins.
- No schema, migration, RLS, RPC, Edge Function, domain-contract, Retool, or hosted business-data change.
- Keep one dominant business action per active operator decision.
- Real textual business commands use `businessPrimary`, `secondary`, `tertiary`, or `destructive`; transparent `utility` is not a generic text-button style.
- Keep shell navigation, tabs, link-like navigation affordances, and the intentional circular Refresh behavior semantically intact.
- Production entrypoint PR #286 remains Draft/open/unmerged during 06D.
- Live OPS project `qnthofvccilhnefdcxnz` is a hard no-write/no-Atlas target.
- Atlas Staging `rnzxmxiiqgtdevzregff` verification is read-only; expected frontier remains `20260908225248_purchase_preparation_replacement_frontier` until a separately authorized backend change exists.
- No Production Supabase project creation or production environment activation belongs to 06D.

---

### Task 1: Classify every remaining transparent utility control

**Files:**
- Modify as required under: `src/vnext/atlas/**`
- Test: `src/vnext/atlas/AtlasConvergence.test.tsx`
- Test: existing workbench tests touched by each variant change.

**Interfaces:**
- Consumes: 06D-A button variants.
- Produces: no ordinary operator command rendered as visually plain text by default.

- [ ] **Step 1: Capture the exact remaining utility inventory**

Run:

```bash
rg -n 'variant="utility"' src/vnext/atlas
```

Classify every match into one of these categories in the working notes before editing:

```text
KEEP_UTILITY_NAVIGATION  — shell navigation, compact navigator-only affordance
KEEP_ICON_UTILITY        — routine Refresh or icon-only close/calendar utility
CHANGE_TERTIARY          — low-emphasis real command: Xem, Sửa, Đóng, Kiểm tra, Bỏ
CHANGE_SECONDARY         — supporting command: Xuất, Áp dụng, Xem trước, Thêm when not dominant
CHANGE_PRIMARY           — sole dominant current business command only
```

Known baseline textual utility sites that require explicit review include:

```text
src/vnext/atlas/recipes/DishCatalogue.tsx
src/vnext/atlas/recipes/DishRecipeWorkbench.tsx
src/vnext/atlas/recipes/ChangeOrderWorkbench.tsx
src/vnext/atlas/recipes/ChangeOrderDetail.tsx
src/vnext/atlas/master-data/IngredientCatalogue.tsx
src/vnext/atlas/master-data/SupplierCatalogue.tsx
src/vnext/atlas/master-data/SupplierDetail.tsx
src/vnext/atlas/master-data/IngredientPriorityEditor.tsx
src/vnext/atlas/dispatch/SchoolPxkTable.tsx
src/vnext/atlas/dispatch/SchoolPxkDetail.tsx
src/vnext/atlas/planning/PlanningSourceReview.tsx
src/vnext/atlas/AtlasSchoolScope.tsx
src/vnext/atlas/AtlasVNextShell.tsx
```

Do not change a match merely because it appears in this list; apply the semantic categories above.

- [ ] **Step 2: Add a convergence regression for real command surfaces**

Extend `AtlasConvergence.test.tsx` with a helper that detects an enabled command's Chakra variant from emitted CSS/data attributes. Assert representative real commands use surfaced roles:

```text
School Defaults: Lưu thay đổi → businessPrimary
Ingredient row: Xem / sửa → tertiary
Recipe locked forward action: Tạo lệnh điều chỉnh → secondary
Planning Review: Đóng/Quay lại → tertiary or secondary according to existing hierarchy
PXK export → secondary
```

Also assert shell navigation remains navigation and is not promoted to a business-primary surface.

- [ ] **Step 3: Run convergence test and confirm the remaining failures**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx
```

Expected: FAIL only where textual business commands still use transparent `utility`.

- [ ] **Step 4: Apply the smallest semantic variant changes**

Examples:

```tsx
<Button variant="tertiary" size="sm">Xem / sửa</Button>
<Button variant="secondary" size="sm">Xuất XLSX</Button>
<Button variant="tertiary" size="sm">Đóng</Button>
```

Do not add per-component background/radius props to simulate buttons; use shared recipes.

- [ ] **Step 5: Re-run affected workbench tests and convergence**

```bash
pnpm exec vitest run src/vnext/atlas/AtlasConvergence.test.tsx src/vnext/atlas/master-data src/vnext/atlas/recipes src/vnext/atlas/planning src/vnext/atlas/dispatch src/vnext/atlas/reconciliation
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/vnext/atlas
git commit -m "refactor(atlas): converge operator command affordance"
```

---

### Task 2: Run exact full frontend certification

**Files:**
- No source edits unless a failure is proven to originate in 06D changes.

- [ ] **Step 1: Run focused 06D regressions first**

```bash
pnpm exec vitest run \
  src/vnext/atlas/AtlasDateInput.test.tsx \
  src/vnext/atlas/AtlasRefreshButton.test.tsx \
  src/vnext/atlas/AtlasDesignLanguageReference.test.tsx \
  src/vnext/atlas/schools \
  src/vnext/atlas/master-data \
  src/vnext/atlas/recipes \
  src/vnext/atlas/planning \
  src/vnext/atlas/dispatch \
  src/vnext/atlas/reconciliation \
  src/vnext/atlas/AtlasConvergence.test.tsx \
  src/vnext/atlas/AtlasModuleExit.test.tsx \
  src/vnext/atlas/AtlasPageTransition.test.tsx
```

Expected: PASS.

- [ ] **Step 2: Run the repository's authoritative frontend certification**

```bash
pnpm certify:frontend
```

Expected: PASS. If local resource-sensitive tests time out, do not increase timeout budgets or edit unrelated tests. Reproduce against the pre-06D baseline under equivalent conditions and classify environment vs regression using the same differential method proven in 06C1.

- [ ] **Step 3: Run explicit build/format boundaries**

```bash
pnpm ui:vnext:typegen
pnpm ui:vnext:check
pnpm typecheck
pnpm build
pnpm build-storybook
pnpm exec prettier --check src/vnext/atlas docs/ui/atlas-vnext-design-language-v1.md
git diff --check
```

Expected: PASS.

- [ ] **Step 4: Audit the built browser assets for secrets and legacy presentation leakage**

Inspect `dist/assets` and confirm:

```text
no service-role/secret key patterns
no live OPS project ref qnthofvccilhnefdcxnz
no unexpected staging credential material
no Mantine presentation dependency newly introduced by 06D
```

Project refs/publishable browser configuration are not treated as secret credentials; privileged keys are.

---

### Task 3: Capture final Product visual acceptance across all seven modules

**Files:**
- No repository screenshot commits. Store review evidence outside the public repo or as safe CI artifacts only.

- [ ] **Step 1: Build/use the existing local vNext review harness**

Run the normal development/review entry and inspect:

```text
schools
ingredients-suppliers
recipes
planning / confirmed need
procurement
pxk
reconciliation
```

Use viewports:

```text
1366×768
1440×900
1920×1080
360×800
```

- [ ] **Step 2: Verify the owner PPT findings explicitly**

Record PASS/FAIL for:

```text
PPT-1 School Defaults: direct Lưu, #, explicit status
PPT-2 Ingredient/Supplier: stable attached 62/38 detail
PPT-3 Recipe: duplicate ADD blocked with explicit adjustment transition
PPT-4 Recipe: lock state and forward action unmistakable
PPT-5 Menu: complete active Dish Type columns, local horizontal scroll
PPT-6 Pantry: School on every line, aligned fields, Ghi chú/Lý do semantics
```

- [ ] **Step 3: Verify the cross-cutting 06D interaction grammar**

Record:

```text
Vietnamese calendar opens from field/icon
month/day labels Vietnamese; week Monday-first
dd/mm/yyyy visible; ISO state retained
selected date and today visually distinct
button roles visibly surfaced at rest
8px normal controls; Refresh remains circular
hover/pressed/focus/disabled states distinct
no document-wide horizontal overflow
reduced motion suppresses sanctioned detail/page animations
no console warnings/errors attributable to 06D
```

- [ ] **Step 4: Stop on any Product acceptance failure**

Do not paper over visual failures with screenshots or notes. Fix only within the relevant 06D plan boundary, rerun focused tests, then repeat the affected viewport review.

---

### Task 4: Certify the backend boundary without changing it

**Files:**
- No backend/source changes expected.

- [ ] **Step 1: Run disposable local Supabase Full Integration once on exact final 06D head**

```bash
pnpm certify:supabase:full-integration
```

Expected: PASS with zero repository/backend changes.

If Docker cannot start, first prove the Docker/Linux engine is unavailable (`docker info` fails for environment reasons). Then use the existing GitHub Supabase Integration workflow on the exact 06D head; do not modify scripts or workflow to bypass local infrastructure.

- [ ] **Step 2: Recheck Staging read-only**

Run the existing read-only Staging verifier or equivalent protected metadata check and require:

```text
migration count: 72
frontier: 20260908225248_purchase_preparation_replacement_frontier
```

No migration, fixture import, business command, or Auth mutation is authorized.

- [ ] **Step 3: Confirm live OPS isolation**

Require environment guards still reject project ref:

```text
qnthofvccilhnefdcxnz
```

No connection from Atlas code to live OPS is added.

---

### Task 5: Exact-head branch preview and final status

**Files:**
- No production deployment file changes unless an existing preview configuration is demonstrably broken by 06D.

- [ ] **Step 1: Push the exact 06D head and wait for Frontend CI**

```bash
git status --short
git push origin HEAD
```

Require the exact pushed SHA to be clean locally and on origin. Require Frontend CI success.

- [ ] **Step 2: Inspect the Cloudflare branch preview**

The branch preview must boot the Chakra vNext review/connected surface appropriate to current entrypoint state, with:

```text
correct 06D styles
no console errors
no horizontal overflow on desktop/mobile
no privileged secrets in assets
```

If staging browser credentials remain unavailable, record `STAGING_BROWSER_AUTH_NOT_AVAILABLE`; do not request or expose passwords merely to clear 06D.

- [ ] **Step 3: Record final 06D state**

Use exactly one:

```text
UI_PRODUCT_ACCEPTANCE_READY
BLOCKED
```

`UI_PRODUCT_ACCEPTANCE_READY` requires all focused tests, full frontend certification, exact-head Supabase integration, four-viewport visual acceptance, and zero unauthorized backend/hosted writes.

- [ ] **Step 4: Commit only evidence/documentation that belongs in Git**

Do not commit screenshots containing real production/staging business data. If a small implementation-task closeout record is added, it may contain only safe test counts, SHAs, CI URLs, and PASS/BLOCKED classifications.

---

### Task 6: Prepare #286 for a separate cutover re-certification; do not merge it

**Files:**
- Draft PR #286 branch only after 06D is merged to `main` and owner separately authorizes updating that candidate.

- [ ] **Step 1: Stop at the 06D merge gate**

Do not rebase #286 while 06D is only a Draft implementation PR. Report the exact 06D head and wait for owner authorization to merge 06D.

- [ ] **Step 2: After an authorized 06D merge, rebase/recreate #286 from the new exact `main`**

Preserve #286's three-file intent:

```text
src/main.tsx
index.html
src/productionEntrypoint.test.ts
```

If the rebase creates domain/workbench changes in #286, classify `VNEXT06C_SCOPE_DRIFT` and stop.

- [ ] **Step 3: Re-run #286 cutover certification**

Require:

```bash
pnpm exec vitest run src/productionEntrypoint.test.ts src/vnext/atlas/AtlasPageTransition.test.tsx
pnpm certify:frontend
pnpm build
```

Also rerun exact-head Supabase Full Integration, preview, environment rejection, secret audit, and rollback proof as previously established in 06C/06C1.

- [ ] **Step 4: Leave #286 Draft/open/unmerged**

`ENTRYPOINT_CANDIDATE_READY` after 06D re-certification still does not authorize merge or Atlas Production backend activation.

## 06D Final Exit Gate

```text
06D-A shared interaction         PASS
06D-B master data                PASS
06D-C Recipe                     PASS
06D-D Planning                   PASS
Utility-command convergence      PASS
Full frontend certification      PASS
Supabase exact-head integration  PASS
Four-viewport Product acceptance PASS
Staging read-only frontier       PASS
Hosted business writes           ZERO
UI_PRODUCT_ACCEPTANCE_READY       YES
PR #286 merged                    NO
```
