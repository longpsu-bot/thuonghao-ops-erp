# TASK-RMVP-05 — Connected Confirmed Need Review and Quantity Confirmation

## Status

Implemented on branch `codex/rmvp-05-connected-confirmed-need-review` from exact merged RMVP-04 baseline `d497c8921d64fb555baea8e207a27f63925934a7`. The change remains draft and unmerged until exact-head GitHub validation and product/architecture review complete.

## Outcome

This bounded Planning slice connects existing evidence:

```text
RMVP-04 released Need Generation
→ existing CMD-15 Draft Confirmed Need
→ shaped quantity review
→ authoritative write-free preview
→ explicit immutable confirmation
```

An authenticated Planning operator receives the sixth internal Planning Inputs tab, `Xác nhận nhu cầu`. It opens the CMD-15 batch automatically or by explicit UUID, separates theoretical, proposed, and authoritative confirmed quantities, retains exact decimal-string Drafts, shows Unit policy steps and blockers before warnings, previews selected decisions, explicitly confirms the exact preview, safely retries only an uncertain exact command, refreshes stale evidence while preserving compatible local Drafts, and shows immutable decision history.

## Database delta

One forward migration is added:

`supabase/migrations/20260803102941_rmvp_05_connected_confirmed_need_review.sql`

It adds exactly three `RMVP-05.v1` APIs, three capabilities, one `NOLOGIN NOINHERIT` runtime, private validation/authorization/canonical-preview/read-shaping/event helpers, and the minimum grants and forced-RLS policies needed over existing H0B1/H1A/H1B1 and common command infrastructure.

It adds no business table, view, lifecycle status, scope kind, sequence, trigger, production policy seed, approval snapshot, Purchase Handoff, Procurement, Warehouse, or Dispatch fact. Missing production policy data remains a safe blocker.

## API and decision behavior

The sole exact registry is [RMVP-05 Connected Confirmed Need Review API Contract](../api/rmvp-05-connected-confirmed-need-review.md).

The read requires `confirmed_need_review.read`; preview requires `confirmed_need_quantities.preview`; confirmation requires `confirmed_need_quantities.confirm`. All calls require an exact JWT-bound active human Actor and active `GLOBAL` scope. The three security definers are owned by `atlas_confirmed_need_review_runtime`; only `authenticated` can execute them.

The backend resolves exactly one effective H1A policy for each exact Unit/service date and proves whole Planning ticks with PostgreSQL numeric arithmetic. First unchanged acceptance appends an H1B1 decision on the existing revision. An adjusted quantity creates exactly one direct successor revision, copies its exact contribution memberships, and appends its decision. Replacement decisions retain a direct predecessor and require a correction note. The batch remains reviewable and increments once per command.

The browser sends only stable/current bindings, exact decimal-string quantity, governed reason/note, expected batch version, and the backend preview hash. Policy, tick, decision kind, predecessor, generated IDs, next version, and audit evidence remain backend-derived.

## Application delta

The bounded submodule is `src/modules/atlas/planning-inputs/confirmed-needs/`:

- `confirmedNeedApi.ts` defines the three RMVP-05 transports and exact requests;
- `confirmedNeedModel.ts` parses the shaped workbench, preview and safe outcomes without binary-float conversion;
- `ConfirmedNeedReviewWorkbench.tsx` implements the Vietnamese review journey;
- `reviewConfirmedNeedApi.ts` provides deterministic review mode;
- focused tests cover API, workbench, handoff, sixth-tab integration and review behavior.

`PlanningInputsWorkbench.tsx` adds only the sixth internal tab. `NeedGenerationWorkbench.tsx` hands off the batch returned by CMD-15. `AtlasApp.tsx` injects the connected/review adapter. `atlasRpc.ts` registers exactly the three new public functions; no top-level navigation item is added.

## Verification

The focused pgTAP suite has actual `plan(37)` and begins with one real RMVP-04-generated, validated and released multi-line run followed by actual CMD-15 materialization. It proves exact shaped proposals, policy fail-closed behavior, exact-step/precision preview, preview non-mutation, mixed unchanged/adjusted confirmation, successor and membership integrity, append-only decisions and pointers, one version increment, receipt/event/audit evidence, replay/conflict, stale no-write failure, four authorization denials, and normal predecessor-linked replacement history.

Focused Vitest covers sixth-tab/handoff integration, theoretical/proposed/confirmed distinction, decimal strings, local edits, reason/note rules, preview and edit invalidation, mixed confirmation, blockers-first rendering, stale refresh, exact retry and review mode.

GitHub's draft smoke remains intentionally bounded: fresh seedless reset, platform catalog, all three H1A suites, all three H1B1 suites, RMVP-04, RMVP-05, then the disposable browser-key prerequisite and connected RMVP-04 → CMD-15 → RMVP-05 journey. Full integration retains every registered pgTAP and browser-key journey.

Local development does not start/reset Supabase or run pgTAP. Local checks are workspace verification, formatting, typecheck, focused frontend tests, static SQL/security inspection, `git diff --check`, and manifest review.

## Security and external boundary

The runtime receives only shaped-read and confirmation rights on existing Planning/Admin/Core/Audit evidence. It has no login, inheritance, superuser, RLS bypass, final schema creation, or downstream-domain mutation. React uses only authenticated reviewed RPCs and no service credential.

RMVP-05 does not migrate or mutate hosted project `qnthofvccilhnefdcxnz`, production data, Retool, OPS v1/v2, Edge Functions, credentials, or deployed applications. Retool ordering export evidence remains unchanged.

## Remaining boundary

The slice stops after quantity confirmation. Complete-batch validation, approval, snapshots, release, CMD-03, Purchase Handoff, supplier assignment, purchase rounding, Procurement, Warehouse, Dispatch, policy administration, and post-downstream correction remain separately authorized work.
