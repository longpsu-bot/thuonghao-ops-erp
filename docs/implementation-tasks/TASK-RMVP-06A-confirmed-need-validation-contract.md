# TASK-RMVP-06A — Confirmed Need Validation Contract

**Status:** Architecture task implemented in documentation; Product Owner approval and independent review pending

**Task type:** Architecture, decision and implementation handoff only

**Starting baseline:** `9ddc6030c85cc3c076ab74ee0bd1af4f123dcae7`

**Branch:** `docs/rmvp-06a-confirmed-need-validation-contract`

**Architecture contract:** [RMVP-06 Connected Confirmed Need Validation](../architecture/rmvp-06-confirmed-need-validation-contract.md)

**Decision registry:** [Decision RMVP-06 — Confirmed Need Validation](../decisions/decision-rmvp-06-confirmed-need-validation.md)

## 1. Objective

Close every material product, authorization, persistence, concurrency, issue and UI decision required before Codex implements complete-batch Confirmed Need validation.

RMVP-06A performs no executable implementation.

## 2. Authority reviewed

The task is governed by:

- OPS_SYSTEM_MAP v1.0;
- Planning Confirmed Need contract;
- PA-06E review/revision/source-correction contract;
- H0B1 school-catering identity and exact contribution membership;
- H1A Planning quantity policy;
- H1B1 immutable line-decision evidence;
- CMD-15 materialization;
- RMVP-04 connected Need Generation;
- RMVP-05 connected Confirmed Need review/preview/confirmation;
- merged migrations and registered pgTAP;
- the current Confirmed Need React workbench;
- retained Retool exports as legacy workflow evidence only.

Repository documentation and merged implementation take priority over chat context.

## 3. Deliverables

New canonical documents:

1. `docs/architecture/rmvp-06-confirmed-need-validation-contract.md`
2. `docs/decisions/decision-rmvp-06-confirmed-need-validation.md`
3. `docs/implementation-tasks/TASK-RMVP-06A-confirmed-need-validation-contract.md`

The task may add minimal navigation/registry references after review without duplicating the canonical decision registry.

## 4. Closed implementation decisions

RMVP-06B must implement exactly:

```text
API: atlas_api.validate_confirmed_needs(request jsonb) returns jsonb
contract: RMVP-06.v1
capability: confirmed_need_validation.validate
runtime: reuse atlas_confirmed_need_review_runtime
scope: active GLOBAL
source family: NEED_GENERATION only
```

Persistence delta:

```text
+ atlas_planning.confirmed_need_validation_attempts
+ atlas_planning.confirmed_need_validation_lines
+ atlas_planning.confirmed_need_validation_issues
+ confirmed_need_batches.current_confirmed_need_validation_attempt_id
```

No new role, schema, view, lifecycle state, source family, scope kind, queue, Edge Function or production seed is authorized.

## 5. RMVP-06B command semantics

### Validated

- exact current working batch version N;
- complete locked authoritative recheck;
- no blockers;
- append attempt, exact line membership and warnings;
- set current validation pointer;
- transition to `VALIDATED`;
- increment version once to N+1;
- emit `ConfirmedNeedsValidated`;
- return authoritative RMVP-05 workbench readback.

### Blocked

- exact current working batch version N;
- complete locked authoritative recheck;
- one or more blockers;
- append attempt, exact line membership, blockers and warnings;
- leave status and version unchanged;
- do not set current validated pointer;
- emit `ConfirmedNeedValidationFailed`;
- return `success: true`, `validation_status: BLOCKED`, issues and authoritative readback.

### Command failure

Malformed request, authorization failure, unsupported source, invalid status, stale expected version, idempotency conflict and internal failures return `success: false` and create no validation attempt.

## 6. Expected changed-path boundary for RMVP-06B

Expected new/modified paths are limited to:

```text
supabase/migrations/<generated>_rmvp_06_connected_confirmed_need_validation.sql
supabase/tests/rmvp_06_connected_confirmed_need_validation.sql
supabase/local/rmvp_06_browser_fixture.sql
scripts/verify-local-rmvp06-confirmed-need-validation.mjs
src/modules/atlas/planning-inputs/confirmed-needs/**
src/modules/atlas/connection/**
src/modules/atlas/AtlasApp*.tsx
.github/workflows/supabase-integration.yml
package.json
docs/api/api-contracts.md
docs/api/rmvp-06-connected-confirmed-need-validation.md
docs/architecture/roadmap.md
docs/decisions/decision-register.md
docs/implementation-tasks/TASK-RMVP-06B-connected-confirmed-need-validation.md
```

The implementation must not modify Procurement, Warehouse, Dispatch, Retool, hosted-project configuration, credentials, Edge Functions or production seed.

A changed path outside this boundary requires explicit justification and review before commit.

## 7. Backend handoff

RMVP-06B must:

1. create the migration using the installed Supabase CLI command discovered through `--help`;
2. add the one unbound capability;
3. create the three private evidence relations and one batch pointer;
4. add exact FKs, unique constraints, indexes, forced RLS, immutable/deferred guards and revoke-first grants;
5. reuse the RMVP-05 runtime with the minimum additional privileges;
6. add one fixed-search-path security-definer API;
7. reuse common actor, authorization, receipt, idempotency, event and audit helpers where contract-compatible;
8. use deterministic ordered row locks;
9. authoritatively reread after locking and before business writes;
10. persist both validated and blocked outcomes atomically;
11. extend the existing workbench readback;
12. preserve PA-05D direct-wholesale behavior and all existing security catalogs.

Supabase implementation constraints:

- explicit grants; no reliance on automatic Data API table exposure;
- browser roles receive no direct private relation access;
- no schema exposure configuration change;
- no `service_role` in browser code;
- fixed search paths;
- no caller-authored dynamic SQL;
- no generic retries for business outcomes.

## 8. Frontend handoff

Extend the current Confirmed Need tab rather than creating a new screen.

Required behavior:

- action `Kiểm tra toàn bộ`;
- exact disabled reason when validation is unavailable;
- display latest validation outcome, actor/time and counts;
- blockers before warnings;
- line-level issue markers;
- blocked result leaves editing available;
- validated result makes the tab read-only;
- successful banner `Đã kiểm tra; chờ phê duyệt`;
- no approval or release action;
- stale validation responses cannot overwrite newer data;
- quantities remain exact strings.

React must not recalculate validation, issue severity, policy eligibility, quantity representability, source currency or lifecycle authority.

## 9. Test blueprint

### Focused pgTAP

Cover:

- exact function, contract, owner, execute grants and no overload;
- exact capability and no production binding;
- no new role;
- exact relations, columns, ownership, RLS and policies;
- immutable evidence and exact attempt membership;
- successful N→N+1 transition;
- blocked no-transition/no-version-change;
- missing decision;
- revision/decision mismatch;
- stale source;
- invalid contribution membership/total;
- inactive Unit;
- missing/ambiguous/ineligible policy;
- invalid quantity/reason;
- warning-only success;
- success replay;
- blocked replay;
- idempotency conflict;
- stale expected version;
- concurrency recheck;
- no quantity/revision/decision mutation;
- no downstream write;
- direct-wholesale compatibility.

Derive the exact `plan(...)` from implemented assertions.

### Frontend tests

Cover:

- allowed/disabled action;
- validated success readback;
- blocked grouped issues;
- warning-only success;
- editing disabled only after validation;
- no approval/release action;
- stale async result invalidation;
- Vietnamese labels;
- exact string quantities.

### Browser acceptance

Short draft journey:

```text
identity
→ deterministic Draft Confirmed Need
→ complete line confirmation
→ validate
→ authoritative VALIDATED readback
```

Full Integration journey:

```text
RMVP-04
→ CMD-15
→ RMVP-05 review/preview/confirm/replay
→ RMVP-06 validate
→ authoritative readback
```

## 10. CI discipline

Draft smoke remains narrow:

```text
platform security catalog
+ RMVP-06 focused pgTAP
+ deterministic identity/fixture
+ short RMVP-06 browser journey
```

Full Integration remains the ready-for-review merge gate and must run all registered suites plus the complete upstream journey.

Do not weaken, skip or replace material gates.

## 11. RMVP-06B exclusions

Do not implement:

- approval;
- approval snapshot command;
- release;
- reopen;
- corrected rematerialization;
- CMD-03;
- Purchase Handoff;
- Procurement;
- Warehouse;
- Dispatch;
- production policy threshold;
- production capability binding;
- hosted Supabase mutation;
- Retool change;
- deployment.

## 12. RMVP-06A validation

Documentation-task checks:

```text
pnpm ops:workspace
Prettier for touched Markdown
documentation link/reference inspection
canonical decision duplication review
git diff --check
exact changed-path manifest
```

Do not start or reset Supabase and do not run pgTAP or browser journeys for RMVP-06A.

## 13. Approval gate

Codex must not implement RMVP-06B until:

1. the Product Owner approves the decision registry;
2. independent review finds no material contract conflict;
3. the RMVP-06A documentation PR is merged;
4. the exact new `main` baseline is recorded in the implementation prompt.
