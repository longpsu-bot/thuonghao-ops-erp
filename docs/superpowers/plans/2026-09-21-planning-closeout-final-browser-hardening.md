# Planning Closeout Final Browser Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the protected Planning closeout harness accurately prove the immutable hosted Atlas Generate → first Save → reopen journey without changing product or backend behavior.

**Architecture:** Keep all behavior in the existing verifier boundary. Browser helpers consume the real accessible/Ark anatomy contracts, pure assertion helpers validate first-save authority, and the orchestration script performs only read-only before/after/final proofs around the one-shot browser commands.

**Tech Stack:** Node.js ESM, Vitest/jsdom, React Testing Library, Chakra UI 3.37.0, Ark UI 5.39.0, Zag Date Picker 1.43.3, Supabase/PostgreSQL management reads.

**Spec:** `docs/implementation-tasks/TASK-PLANNING-HOSTED-CLOSEOUT.md`

## Global Constraints

- Start from `c3c5c79bac9a626e81e6b991d2ed63ab3d91fb6b` on `fix/planning-closeout-final-browser-hardening`.
- Pin the browser to `https://0d969e3b.thuonghao-ops-erp.pages.dev/`, proven for PR #286 head `dcf6be78cd71b4eca4565a5d014f7f4b86888103`.
- Add zero migrations, dependencies, React product changes, business-contract changes, workflow changes, hosted mutations, or protected runs.
- Generate and Save each remain one-shot with no retry or fallback click.
- Preserve the database `statement_timeout='8s'`; every protected generation must be strictly below `7000` ms.
- A fresh 248-line first Save creates 248 first decisions: one operational quantity adjustment and 247 proposal acceptances.
- Diagnostics must be read-only and must never print names, quantities, credentials, tokens, keys, or full workbench payloads.

## Review Focus

- A destination selector shared by Sources and Confirmed Need must not satisfy either initial entry or reopen.
- The real Ark day trigger is a role-button `div`; no helper may assume an HTML `button` for day cells.
- Calendar navigation must wait for visible day values to change and stop at a month-distance-derived bound.
- A transient diagnostic/readback failure must preserve the original browser failure and must never retry Generate or Save.
- First decision creation for all lines must not be misclassified as 248 business quantity adjustments.

---

### Task 1: Pin failing browser-contract regressions

**Files:**

- Modify: `scripts/staging-planning-closeout.test.mjs`
- Modify: `src/vnext/atlas/AtlasWeekRangeInput.test.tsx`

**Interfaces:**

- Consumes: `navigateUntil`, `ensurePlanningServiceDateAvailable`, `planningCloseoutProbeAccepted`, and `assertFirstSaveTransition`.
- Produces: RED evidence for the phase collision, Ark day-cell contract, month navigation, 7000-ms boundary, and first-save semantics.

- [ ] **Step 1: Replace the synthetic button calendar regression with real component cases**

```tsx
// Render AtlasWeekRangeInput with a controlled week and a derived
// select[aria-label="Ngày phục vụ"], then call the browser helper through
// evaluate(expression) => globalThis.eval(expression).
// Prove 14/09 no-op, 21/09 same-month selection, 05/10 previous-month
// selection, and that the target anatomy node is not an HTML button.
```

- [ ] **Step 2: Add phase-collision, performance-boundary, and first-save tests**

```js
assert.equal(sourceSelectStillMounted, true);
assert.equal(confirmedClicks > 0, true);
assert.equal(
  planningCloseoutProbeAccepted({ ...valid, generation_ms: 6999.999 }),
  true,
);
assert.equal(
  planningCloseoutProbeAccepted({ ...valid, generation_ms: 7000 }),
  false,
);
assert.doesNotThrow(() => assertFirstSaveTransition(firstSaveFixture));
```

- [ ] **Step 3: Run focused tests and record correct RED failures**

Run: `pnpm exec vitest run src/vnext/atlas/AtlasWeekRangeInput.test.tsx scripts/staging-planning-closeout.test.mjs --reporter=verbose`

Expected: tests load successfully and fail specifically because the current helper targets `button[data-view="day"]`, Confirmed navigation accepts the Sources select, the 7000-ms helper is absent/current 8000-ms behavior is wrong, and first-save semantics are absent.

### Task 2: Harden the browser journey with real contracts

**Files:**

- Modify: `scripts/staging-planning-browser.mjs`

**Interfaces:**

- Consumes: exact selectors recorded in the 26-stage audit and `readReview()` workbench shape.
- Produces: `ensurePlanningServiceDateAvailable`, `assertFirstSaveTransition`, and the one-shot `verifyPlanningBrowser` journey.

- [ ] **Step 1: Correct phase identity and DatePicker anatomy**

```js
const CONFIRMED_WORKBENCH = 'section[aria-label="Xác nhận nhu cầu"]';
const DAY = '[data-part="table-cell-trigger"][data-view="day"][data-value]';
const PREV = '[data-part="prev-trigger"]';
const NEXT = '[data-part="next-trigger"]';
```

- [ ] **Step 2: Add bounded state-driven calendar settling and the hard pre-Generate gate**

```js
// Wait for exact week value, enabled service select, exact seven options,
// selected 17/09, enabled Tạo nhu cầu, absent Cập nhật nhu cầu, and zero rows.
// Throw BROWSER_GATE_pre_generate before the one Generate click on mismatch.
```

- [ ] **Step 3: Add the hard pre-Save gate and authoritative first-save assertion**

```js
// Require one nonzero UI quantity delta, no aria-invalid controls, enabled Lưu,
// 248 null pre-save current_decision_id values, then one Save click.
// After readback require version +1, identical IDs/theoretical quantities,
// 248 decision #1 records, one exact adjusted line, and 247 accepted proposals.
```

- [ ] **Step 4: Harden reopen and safe diagnostics**

```js
// Re-enter only when section[aria-label="Xác nhận nhu cầu"] is mounted.
// Catch diagnostic read failures locally and log only stage, safe UI flags,
// row count, batch existence/version, line count, editing/blocker/pagination.
```

- [ ] **Step 5: Run focused tests to GREEN**

Run: `pnpm exec vitest run src/vnext/atlas/AtlasWeekRangeInput.test.tsx scripts/staging-planning-closeout.test.mjs --reporter=verbose`

Expected: all browser-contract tests pass with real Ark nodes and no synthetic button day fixture.

### Task 3: Enforce orchestration and final authoritative proof

**Files:**

- Modify: `scripts/verify-staging-planning-closeout.mjs`
- Modify: `scripts/staging-planning-closeout.test.mjs`

**Interfaces:**

- Consumes: management SQL executor, preflight selected source fingerprints, browser result batch ID, and authoritative review.
- Produces: `PLANNING_CLOSEOUT_GENERATION_MAX_MS`, `planningCloseoutProbeAccepted`, zero-state baseline/rollback proof, and retained final proof.

- [ ] **Step 1: Implement the strict performance predicate**

```js
export const PLANNING_CLOSEOUT_GENERATION_MAX_MS = 7000;
export function planningCloseoutProbeAccepted(row) {
  return (
    Boolean(/* existing safety predicates */) &&
    row.generation_ms < PLANNING_CLOSEOUT_GENERATION_MAX_MS
  );
}
```

- [ ] **Step 2: Expand read-only baseline and rollback assertions**

```sql
select
  (select count(*) from atlas_planning.need_generation_runs
   where period_start between '2026-09-14' and '2026-09-18')::int as runs,
  (select count(*) from atlas_planning.confirmed_need_batches
   where period_start between '2026-09-14' and '2026-09-18')::int as batches;
```

- [ ] **Step 3: Capture and compare existing source fingerprints**

```sql
select atlas_core.planning_contract_01_preflight_payload(
  '2026-09-17'::date, '2026-09-17'::date, null
)#>'{source_date_fingerprints,selected}' as fingerprints;
```

- [ ] **Step 4: Add final exact-day counts and zero-handoff proof**

```sql
select count(*)::int as handoffs
from atlas_planning.purchase_handoff_batches
where confirmed_need_batch_id = '<browser batch id>'::uuid;
```

- [ ] **Step 5: Run focused tests to GREEN**

Run: `pnpm exec vitest run scripts/staging-planning-closeout.test.mjs --reporter=verbose`

Expected: deterministic 6999.999/7000 boundary tests and all existing verifier tests pass.

### Task 4: Record the complete audit and certify the final tree

**Files:**

- Modify: `docs/implementation-tasks/TASK-PLANNING-HOSTED-CLOSEOUT.md`

**Interfaces:**

- Consumes: reconciled lead/reviewer evidence and the final selectors.
- Produces: the 26-stage audit matrix, dependency proof, first-save resolution, immutable deployment proof, and rollback statement.

- [ ] **Step 1: Add the complete selector/action audit table and decision semantics**

```markdown
| Action | Product source | Actual DOM/API contract | Final verifier selector | Status |
| ------ | -------------- | ----------------------- | ----------------------- | ------ |
```

- [ ] **Step 2: Run syntax, formatting, whitespace, and focused checks**

Run: `node --check scripts/staging-planning-browser.mjs`

Run: `node --check scripts/verify-staging-planning-closeout.mjs`

Run: `pnpm exec prettier --check <every touched file>`

Run: `git diff --check`

Expected: every command exits zero.

- [ ] **Step 3: Run frontend certification once on the final tree**

Run: `pnpm certify:frontend`

Expected: the complete frontend certification exits zero.

- [ ] **Step 4: Obtain the single authorized final reviewer pass**

Provide the existing Spark-role reviewer the final diff and reconciled selector matrix. Require no unresolved blocker, then resolve any verified blocker with one RED→GREEN fix pass.

- [ ] **Step 5: Commit, push, and open a Draft PR**

```text
Branch: fix/planning-closeout-final-browser-hardening
Title: fix(test): harden final Planning hosted closeout browser contract
```

Expected: Draft PR only; no merge, auto-merge, deploy, protected closeout, or hosted mutation.
