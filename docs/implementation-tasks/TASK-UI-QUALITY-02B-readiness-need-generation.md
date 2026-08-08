# TASK-UI-QUALITY-02B — Planning Input Readiness + Need Generation

## Delivery identity

- Status: implementation and review in progress; draft PR only
- Exact baseline: `4a585f980464e4367a0b23ea6184ecf10fd70003` (PR #180)
- Branch: `codex/ui-quality-02b-readiness-need-generation`
- Head: recorded in the completion report and draft PR after the delivery commit
- Scope: Planning Input Readiness, Need Generation, and minimum outer Planning navigation safety only
- UI-QUALITY-02C Confirmed Need consolidation: not started

## Exact changed paths

1. `src/modules/atlas/planning-inputs/readiness/PlanningInputReadinessWorkbench.tsx`
2. `src/modules/atlas/planning-inputs/readiness/PlanningInputReadinessWorkbench.test.tsx`
3. `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.tsx`
4. `src/modules/atlas/planning-inputs/need-generation/NeedGenerationWorkbench.test.tsx`
5. `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
6. `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx`
7. `src/modules/atlas/AtlasApp.stories.tsx`
8. `src/styles.css`
9. `docs/architecture/roadmap.md`
10. `docs/implementation-tasks/TASK-UI-QUALITY-02B-readiness-need-generation.md`

No API, model, review-adapter, Supabase, script, dependency, or Confirmed Need path is changed.

## Readiness hierarchy

Before:

```text
period controls
→ status and dominant UUID
→ three evidence cards
→ issues
→ equal forward actions and correction controls
→ always-expanded history
```

After:

```text
exact inclusive period
→ canonical operator question
→ authoritative answer and disabled reasons
→ exact three-source evidence
→ blockers
→ warnings
→ one backend-allowed forward action
→ subordinate correction disclosure
→ subordinate immutable history
```

The three cards remain because they are the exact Menu, Attendance, and Pantry evidence set for one readiness decision. No KPI or metric card was added. Each card keeps backend-shaped selection, source period, approved version and snapshot identity, approval actor/time, currentness, coverage, and the distinct Pantry positive/explicit-zero/missing evidence.

The primary action is selected only from `allowed_actions`: Evaluate when `can_evaluate`, then Request Need Generation when `can_request_need_generation`. Disabled backend reasons remain visible. Invalidation retains the backend reason vocabulary and note requirements but is presented as a corrective disclosure.

An unevaluated ambiguous-candidate selection now reports meaningful local dirty state to the existing Planning parent. Rejected tab/week discard keeps the candidate and current tab, and `beforeunload` is protected. A confirmed discard clears browser-local selection only; it causes no backend mutation and introduces no global state.

## Need Generation hierarchy

Before:

```text
period
→ readiness values as dashboard tiles
→ run values as dashboard tiles
→ issues
→ five equal action peers including invalidation
→ materialization ID
→ filters and grouped table
→ atomic detail and history
```

After, before a run:

```text
exact period
→ compact readiness and lineage evidence
→ blockers and warnings
→ backend-allowed Create action
```

After a run:

```text
exact period
→ compact readiness lineage
→ compact run identity/status/evidence
→ blockers
→ warnings
→ filters attached to the dominant grouped-requirements table
→ atomic detail
→ one backend-allowed next lifecycle action
→ subordinate invalidation
→ explicit Confirmed Need materialization boundary
→ run history
```

The action sequence remains Create → Validate → Release → Materialize and is emphasized solely from backend `allowed_actions`. Disabled reasons are visible text and accessible descriptions. Invalidation is separated as a correction path with the existing reasons and mandatory note.

The grouped table retains the exact backend grain and Recipe/Pantry/Total quantities. It adds no client aggregation or calculation, keeps local horizontal scrolling, uses tabular numeric alignment, and keeps date plus School visible during narrow horizontal review. Atomic contribution detail remains the existing bounded disclosure.

The materialization consequence states that the command creates or updates the Confirmed Need review object and does not create Purchase Handoff, select suppliers, create purchase orders, or mutate Warehouse/Dispatch. The existing materialization API and callback are unchanged.

## Authority, retry, and stale behavior

- Backend `allowed_actions` and disabled reasons remain the sole lifecycle eligibility authority.
- React does not calculate readiness, candidate ranking, source currentness, grouping, quantities, Recipe selection, or materialization behavior.
- Retryable and transport-uncertain writes retain the exact immutable request and never retry automatically.
- Stale write outcomes clear eligibility and perform the existing authoritative reread.
- Late-read protection and opaque history pagination remain unchanged.

## Cards and icons

- Cards added: zero.
- Cards removed: dashboard-like Need Generation readiness/run tiles were replaced by compact evidence strips.
- Cards retained: exactly the three contract-required Readiness source-evidence cards.
- Phosphor icons: a small set for refresh, evaluate, generate, validate, release, materialize, detail, history, and correction. Every business command retains explicit Vietnamese text.

## Responsive and accessibility review

Actual Storybook workflows were rendered in headless Chrome for Readiness ready, blocked, ambiguous, stale; Need Generation handoff-not-requested, generated, generated-with-blockers, and released/materialization-ready states.

- 360 px: the canonical Readiness question and answer occur before technical IDs; period controls and forward actions become full-width; evidence cards stack without becoming KPI cards; ambiguity selection remains usable; blockers precede progression; correction and history stay subordinate. Need Generation keeps a real table inside local horizontal scrolling rather than converting rows to cards. The page itself does not widen, the active action remains explicit below table review, and materialization consequences wrap as readable Vietnamese text.
- 768 px: the three Readiness evidence cards scan as one compact evidence set, including stale/missing distinction; blocker and warning order remains clear. Need Generation keeps compact lineage/run strips, attached filters, dominant table, one active lifecycle command, and a separated invalidation path without page-wide overflow.
- 1280 px: D-034 shell/header/workspace/workbench layering remains intact. Readiness exposes the answer immediately with three balanced source cards. Need Generation makes the grouped table the largest operational surface; run evidence is a strip rather than metric cards; lifecycle progression and the Confirmed Need boundary are visually distinct.

Accessibility/usability findings: semantic headings, named regions, definition lists, table semantics, row headers, explicit business-command text, `aria-live`/status behavior, non-color status labels, visible backend disabled reasons, focus-visible styling, and 44 px mobile action targets are retained or improved. Phosphor icons are decorative and `aria-hidden`; no business command is icon-only.

## Validation

- Focused Readiness + Need Generation + outer Planning and adjacent Atlas tests: 37 passed
- `pnpm ops:workspace`: passed on the exact branch and canonical checkout
- `pnpm format`: passed
- `pnpm typecheck`: passed
- `pnpm test`: 70 files and 453 tests passed
- `pnpm build`: passed
- `pnpm build:review`: passed
- `pnpm build-storybook`: passed
- `git diff --check`: passed
- UI Review Export: local review build passed; GitHub workflow pending draft PR
- GitHub CI: pending draft PR

## Product/UI verdicts

- ARCHITECTURE / AUTHORITY: PASS
- PRODUCT / WORKFLOW: PASS
- LAYOUT: PASS
- VISUAL DESIGN: PASS
- ACCESSIBILITY / USABILITY: PASS
- IMPLEMENTATION: PASS WITH DEBT — the existing application and Storybook bundles still emit the pre-existing greater-than-500-kB chunk warning. It does not block this bounded presentation task because no dependency or application-loading boundary changed; a later cross-application performance/bundle task should own code splitting.

## Delta and deferred scope

- Dependency delta: zero
- Business/API/model/read-model/calculation delta: zero
- Lifecycle/permission delta: zero
- Supabase/hosted-data delta: zero
- Retool delta: zero
- Migration/rollback effect: none; rollback is a normal Git revert of these presentation/documentation changes
- Accepted deferred debt: existing bundle-size warning described in the IMPLEMENTATION verdict; no UI-QUALITY-02B behavior or safety debt accepted
- UI-QUALITY-02C: not started
- UI-QUALITY-03: not started
- Hosted operator/security rehearsal: not started
- CMD-03: deferred
