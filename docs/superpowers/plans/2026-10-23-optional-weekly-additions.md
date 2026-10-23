# Optional weekly additions implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this bounded plan and requesting-code-review for independent review.

**Goal:** Remove the recurring no-additions confirmation from the desktop Planning workbench without treating existing unfinished additions as zero.

**Architecture:** Daily Need may omit Pantry only when the backend proves that no Pantry batch overlaps the service date. An immutable `pantry_absent` evaluation fact distinguishes this new evidence from historical null bindings. Existing Pantry batches retain exact approval, correction, signature and version checks.

**Tech stack:** Existing PostgreSQL/Supabase commands, React/TypeScript and Atlas Chakra components; no new dependency.

**Spec:** Owner's 23 October instruction to merge sufficient desktop polish and implement removal of the weekly no-additions step; the contract amendment below records that decision.

## Constraints and acceptance

- Desktop scope; no new module, lifecycle or business action.
- Untouched empty weeks require no Pantry Save, approval snapshot or placeholder line.
- Only daily execution gains optional absence; historical multi-day contracts remain unchanged.
- Any overlapping Pantry batch, including an unfinished draft, prevents absence inference.
- Menu and Attendance remain exact/current and mandatory for Recipe-derived Need.
- Old null bindings remain non-authorizing; released documents and approvals are never rewritten.
- A new Pantry source makes an absence-based generation outdated and uses existing correction guards.
- Serialize first Pantry creation and Need generation before their authoritative checks.
- Deleting the last saved addition remains an explicit reviewed Save, with the existing backend zero-source representation. No weekly confirmation control is needed.
- Keep authentication, capability checks, RLS, idempotency and rollback intact; no hosted writes.

## Task 1 — Backend policy and regression coverage

- [x] Add a focused rolled-back SQL test using existing real-command fixtures: absent source generates Recipe Need, no fake Pantry is created, replay is unchanged, new additions invalidate currentness, draft sources block, old null evidence does not authorize, and existing positive/zero-source paths survive.
- [x] Generate one forward migration with the installed CLI. Add the immutable absence fact, private absence predicate and narrowly anchored changes to existing readiness/currentness/generation guards and source locks. Preserve existing warning rows, receipts and audits by reusing the evaluator.
- [x] Run the new SQL test and affected Pantry, readiness, generation, security and correction suites against a disposable local database; add the test to Full Integration's explicit test list.

## Task 2 — Remove the recurring UI step

- [x] Remove the checkbox and its destructive whole-week transition. Keep row removal and the existing review/Save boundary; derive the zero payload when all rows have been removed.
- [x] Permit adding rows to previously saved empty weeks. Keep filtered-out rows intact and untouched empty drafts clean.
- [x] Update controller/UI tests, review fixtures and empty-state copy. Show absence as optional evidence, rather than unfinished confirmation.
- [x] Check focused frontend tests, formatting and typecheck; inspect desktop fixture behavior.

## Task 3 — Review and delivery

- [x] Update Pantry, readiness and Need contracts, business rules and UI inventory with this forward amendment.
- [x] Obtain independent review, address findings, commit and push a bounded PR. Let GitHub run full Frontend and Supabase Integration validation.

## Rollback

Revert the frontend and apply a reviewed forward backend rollback only after checking absence-based generations. Do not delete or backfill their immutable evidence. No hosted migration or deployment is part of this change.
