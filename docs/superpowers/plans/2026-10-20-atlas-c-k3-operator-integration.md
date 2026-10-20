# Atlas K3 operator integration implementation plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation. Steps use checkbox syntax for tracking.

**Goal:** Run the authenticated 100 → 110 → PO-002 → 90 → PO-003 staff journey with truthful source, history and PXK evidence.

**Architecture:** Extend the existing private review projection with advisory correction permission under the existing runtime. React consumes this distinct action and the existing v3 bindings; transactional writers retain all authority. Reuse existing Allocation, Preparation, replacement, Release and PXK APIs.

**Tech stack:** PostgreSQL/Supabase, React/TypeScript, existing Atlas Chakra v3, pgTAP and Vitest.

**Spec:** [Task and acceptance contract](../../implementation-tasks/TASK-ATLAS-C-K3-OPERATOR-INTEGRATION-01.md), the linked Owner decision and original K3 brief.

## Global constraints

- Base is exact #409 `8adc0803a450192931ece3192642051ca05cc5e2`.
- No new privileges, public RPC, domain authority, writer/receipt/lock change or historical mutation.
- Preserve v2 semantics; v3 is explicit, never a Save fallback.
- No new dependency; use the existing Chakra system and semantic tokens.
- Preserve 8-second statement and 20-second Preparation limits; no weakened tests.
- Use disposable local databases; no hosted write, Supplier commitment, merge or deployment.

## Review focus

- Arbitrary REOPENED state must not masquerade as an authentic post-release chain.
- Absent/ambiguous source or authorization data must not enable a correction.
- Source change after advisory read must still fail at the unchanged writer.
- UNKNOWN/Actor/context changes must not retry or reveal another Actor's draft.
- Whole-document PO and exact School PXK scope must survive multi-Supplier/shared-location continuation.

### Task 1: Authoritative review amendment

Files: one generated migration; `supabase/tests/atlas_c_need_correction_authority.sql` and focused read tests; existing API contract and task report.
Consumes: existing K1 projections/preflight and immutable K2 decision ancestry under the existing review runtime.
Produces: `allowed_actions.correct_released_confirmed_needs` and matching disabled reason code/message; unchanged five bindings and consistent derived availability.

- [ ] Add authenticated released/reopened positive, capability/source/history negative, race and v2 assertions; run against the pinned database and observe expected failure.
- [ ] Patch only `atlas_core.d037_extend_workbench(jsonb,uuid)`; preserve definition owner/ACL/attributes, derive action and availability fail-closed.
- [ ] Run focused SQL plus retained K1/K2/security/receipt regressions and obtain independent read/security review.

### Owner-authorized Procurement read continuation

- [x] Reproduce the exact authenticated read/Preparation mismatch with unchanged upstream facts under decision `6279713889`.
- [x] Implement the bounded two-read amendment and obtain independent static review without writer or privilege changes.
- [ ] Pass final focused positive/negative, ordinary/K1/K2/security/B1/PXK and concurrency execution under unchanged budgets. Current host paging/timeouts block this gate; retained diagnostic runs are not acceptance.
- [ ] Resume the connected operator journey only after that execution gate passes.

### Task 2: Explicit operator correction

Files: Confirmed Need API/model, vNext controller/workbench and tests; existing Procurement/navigation adapters only where necessary.
Consumes: Task 1 action/reasons, authoritative five bindings, exact current line IDs and decimal strings.
Produces: explicit reasoned v3 Save with fixed replay identity and canonical correction/history/obligation display.

- [ ] Add failing API/controller/UI tests for exact v3 payload, absent/false action, reason, repeated correction, dirty/Actor/context and UNKNOWN behavior.
- [ ] Implement the separate correction mode and fresh canonical readback; retain ordinary v2 path and existing navigation ownership.
- [ ] Verify focused API/UI/type checks and current Procurement continuation without new client rules.

### Task 3: Connected journey and history

Files: bounded disposable browser fixture/protocol and task report; minimal existing orchestration adjustments if authenticated evidence identifies a defect.
Consumes: Tasks 1–2 and unchanged Allocation/Preparation/PO/PXK commands.
Produces: authenticated recordings/screenshots/step logs and A1–A9 status with exact IDs, quantities, numbers, history and recovery.

- [ ] Execute desktop/mobile 100 → 110 → PO-002 → 90 → PO-003 and verify original exports and PXK effects.
- [ ] Exercise multi-Supplier/School/source cases, stale authorization, dirty navigation, Actor isolation and UNKNOWN/reload; preserve failures honestly.
- [ ] Address bounded proven defects through failing focused tests before fixes; stop for any authority expansion.

### Task 4: Review, CI and Draft delivery

Consumes: preceding code and evidence. Produces: one K3 Draft stacked on #409 and exact-head CI links.

- [ ] Independent whole-diff security/UI review; resolve material findings and run affected focused checks.
- [ ] Commit and push the coherent K3 branch, create and attach one Draft PR targeting #409's branch.
- [ ] Obtain normal exact-head Frontend, Supabase Smoke and actually executed Full Integration; investigate failures without weakened assertions/timeouts.
- [ ] Record SHA, file manifest, migration/rollback, A1–A10 results, prior failures and remaining blockers. Stop after K3.
