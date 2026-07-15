# TASK-PA-05D — Implement bounded Planning command family

## Recommended Codex execution

```text
Model: Sol
Reasoning: High
Agents: 1
Parallel/subagents: Off
Mode: coding agent in the repository checkout
```

Use one implementation run. Do not perform a separate broad reconnaissance run; the approved contract is the scope. Stop and report rather than inventing behavior if the repository materially contradicts the contract.

## Repository and branch

Repository:

```text
https://github.com/longpsu-bot/thuonghao-ops-erp
```

Start from the latest `main` after the PA-05D documentation contract PR is merged.

Create and work on:

```text
task/pa-05d-planning-command-family
```

Do not work on or amend the documentation-contract branch.

## Authority and required reading

Read before editing:

1. `AGENTS.md`
2. `docs/architecture/arch-001-ops-erp-business-architecture.md`
3. `docs/architecture/arch-002-atlas-system-map.md`
4. `docs/architecture/pa-05d-planning-command-family-contract.md`
5. `docs/decisions/decision-pa-05d-bounded-wholesale-planning-release.md`
6. `docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md`
7. `docs/architecture/pa-05b-supplier-direct-command-implementation.md`
8. `docs/architecture/pa-05b-h1-runtime-role-hardening.md`
9. PA-04, PA-05B, PA-05C, and PA-05B-H1 migrations and pgTAP tests
10. GitHub Issue #85

Use OPS_SYSTEM_MAP v1.0:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

Do not reinterpret domain ownership from table convenience.

## Task

Implement PA-05D exactly as approved: four Planning-owned write commands for supplier-direct wholesale Slice 1.

Add exactly:

1. `atlas_api.record_wholesale_source(request jsonb) returns jsonb`
2. `atlas_api.release_wholesale_order(request jsonb) returns jsonb`
3. `atlas_api.release_purchase_handoff(request jsonb) returns jsonb`
4. `atlas_api.release_dispatch_requirement(request jsonb) returns jsonb`

Contract version:

```text
PA-05D.v1
```

Do not add a read wrapper or any other public function. The reviewed Atlas API surface must contain exactly 13 functions after implementation.

## Required business behavior

### `record_wholesale_source`

Input payload:

```json
{
  "customer_id": "<uuid>",
  "delivery_location_id": "<uuid>",
  "customer_order_reference": "<required text>",
  "service_date": "YYYY-MM-DD",
  "lines": [
    {
      "source_line_number": 1,
      "ingredient_id": "<uuid>",
      "requested_quantity": 10,
      "unit_id": "<uuid>"
    }
  ]
}
```

Create only a Draft wholesale source root, stable lines, and current Draft line revisions. Require:

- `expected_version = 1`;
- 1–100 lines;
- positive and unique source-line numbers;
- positive quantities;
- active wholesale customer;
- active location belonging to that customer;
- active ingredients and units;
- no duplicate non-cancelled customer/order reference.

Event:

```text
WholesaleOrderRecorded
```

### `release_wholesale_order`

Input payload:

```json
{
  "wholesale_order_id": "<uuid>"
}
```

Require the current wholesale-order version to equal `expected_version` and the order to be Draft with complete current Draft line revisions.

Atomically:

- mark the wholesale order and current line revisions Released;
- record approval and release actor/time;
- increment the wholesale-order root version once;
- create one Confirmed Need batch in `RELEASED_FOR_PURCHASE_HANDOFF`;
- create stable Confirmed Need lines and released line revisions;
- set theoretical and confirmed quantity equal to the released wholesale quantity;
- create one approval snapshot and exact snapshot lines.

Do not persist intermediate Validated or Approved states. Validation and approval occur inside this bounded direct-wholesale command.

Event:

```text
WholesaleOrderReleased
```

### `release_purchase_handoff`

Input payload:

```json
{
  "confirmed_need_batch_id": "<uuid>"
}
```

Require `expected_version` to match the Confirmed Need batch. Require a released batch, matching approval snapshot, current released line revisions, positive quantities, and complete source lineage.

Atomically create and release:

- one Purchase Handoff batch;
- one current Base revision;
- stable handoff lines;
- exact handoff line revisions;
- one immutable purchase-demand reference per line.

Do not create supplier assignment, allocation, PO, supplier confirmation, or evidence.

Event:

```text
PurchaseHandoffReleased
```

### `release_dispatch_requirement`

Input payload:

```json
{
  "purchase_handoff_revision_id": "<uuid>"
}
```

Require `expected_version` to match the Purchase Handoff root. Require a current released revision, complete line and demand-reference lineage, one customer/location/date scope, active customer/location references, and no existing current released requirement for the same handoff revision.

Atomically create:

- one released wholesale Dispatch Requirement root;
- one released current Base requirement revision;
- customer/location/address/timezone snapshots;
- stable requirement lines;
- exact requirement line revisions.

Do not create fulfilment allocation, plan, trip, stop, load, or delivery rows.

Event:

```text
DispatchRequirementReleased
```

## Command infrastructure

Reuse the existing tested private infrastructure where appropriate:

- safe parsers;
- authenticated subject and actor resolution;
- safe command errors;
- capability and relational-scope authorization;
- canonical request hashing;
- command receipt begin/replay/conflict behavior;
- command completion.

Add a private PA-05D request validator for `PA-05D.v1`.

Do not change the public behavior of PA-05B or PA-05C functions. Avoid broad helper renames, shared-framework extraction, or unrelated refactors.

Every successful command must create exactly:

- one completed command receipt;
- one domain event;
- one audit event;
- one safe response.

All domain, event, audit, and receipt changes are atomic.

## Capability codes

Use exactly:

```text
wholesale_source.record
wholesale_order.release
purchase_handoff.release
dispatch_requirement.release
```

All belong to `PLANNING`.

Resolve authentication, actor, capability, and relational customer/location scope server-side. Reject delegation, management override, approval shortcuts, caller actor IDs, table names, status names, and generated aggregate IDs in payloads.

## Runtime security

Create:

```text
atlas_planning_command_runtime
```

Requirements:

- `NOLOGIN`, `NOINHERIT`;
- owns only the four PA-05D API functions;
- all entry functions are hardened `SECURITY DEFINER` functions with empty fixed `search_path`;
- no dynamic SQL or caller-controlled object names;
- no Atlas schema `CREATE` after temporary ownership transfer;
- no sequence mutation privilege;
- no Procurement, Evidence, Dispatch, Warehouse, reporting-write, legacy, Storage, or external-service privilege;
- no membership in another command runtime;
- verb-specific grants and RLS policies only;
- reference-row `UPDATE` grants only where PostgreSQL needs them for row locks, with no matching update policy;
- public execute revoked first;
- `authenticated` receives execute only on the reviewed 13-function Atlas API surface;
- `anon` and `service_role` receive no Atlas API execute;
- API roles retain no direct private table, view, or sequence access.

Existing Evidence, Dispatch, and Read runtime privileges must not broaden. Evidence and Dispatch runtimes must not gain Planning-write access.

## Concurrency and uniqueness

Use short `read committed` statement transactions and deterministic lock ordering:

```text
receipt
→ Admin references
→ Planning parent roots
→ Planning lines/revisions in UUID order
→ snapshots/new downstream Planning roots
→ event/audit
```

Re-read authoritative status, version, current-line state, active references, and lineage after locks.

Add only narrow race-safety indexes or constraints approved by the PA-05D decision:

- duplicate customer/order reference prevention;
- one Confirmed Need batch per wholesale order for this bounded slice;
- one current released Dispatch Requirement per handoff revision.

Use customer-level locking or an equivalent reviewed database constraint so duplicate customer/order references cannot race. Do not introduce generic workflow, numbering, queue, orchestration, or advisory-lock frameworks.

## Error and replay behavior

Preserve the established safe error shape and prove at least:

```text
VALIDATION_FAILED
AUTHENTICATION_REQUIRED
AUTH_SUBJECT_MISMATCH
ACTOR_NOT_FOUND
AUTH_SUBJECT_INACTIVE
ACTOR_INACTIVE
CAPABILITY_DENIED
SCOPE_DENIED
DELEGATION_NOT_SUPPORTED
STALE_VERSION
IDEMPOTENCY_CONFLICT
INVARIANT_VIOLATION
RETRYABLE_CONCURRENCY_FAILURE
INTERNAL_COMMAND_FAILURE
```

Exact replay returns the original IDs and creates no duplicate rows. Reusing a scoped key or command ID with a different canonical payload fails. Deterministic post-receipt validation stores a failed non-retryable receipt without misleading domain, event, or audit writes.

## Required files

Create the migration through the repository's installed Supabase CLI workflow. Do not invent a timestamp manually; inspect CLI help first.

Expected file families:

```text
supabase/migrations/<generated>_pa_05d_planning_command_family.sql
supabase/tests/pa_05d_planning_command_family.sql
```

Update only as needed:

```text
supabase/tests/pa_04_supplier_direct_slice_1_foundation.sql
supabase/tests/pa_05b_supplier_direct_command_subset.sql
supabase/tests/pa_05c_authorized_read_api_wrappers.sql
supabase/tests/pa_05b_h1_runtime_role_hardening_test.sql
README.md
docs/architecture/roadmap.md
docs/architecture/pa-05d-planning-command-family-contract.md
docs/decisions/decision-pa-05d-bounded-wholesale-planning-release.md
```

Do not edit unrelated application modules or UI tests.

## pgTAP acceptance

Add focused rolled-back fixtures and assertions proving:

1. The Atlas API surface contains exactly 13 reviewed functions.
2. All four PA-05D functions are hardened definers owned by Planning runtime.
3. Runtime privileges and RLS match the contract.
4. API roles retain no direct private relation access.
5. Auth subject, actor status, capability, and relational scope fail closed.
6. Malformed payload, zero lines, more than 100 lines, duplicate line numbers, inactive references, wrong customer/location relation, and non-positive quantity fail safely.
7. Multi-line source creation is atomic.
8. Source creation replay/conflict and duplicate business-reference behavior are correct, including concurrent duplicate prevention.
9. Wholesale release stale version or wrong lifecycle fails without mutation.
10. Wholesale release creates exact released Confirmed Need lines and approval snapshot.
11. Handoff release creates exact lines and source-demand references without Procurement facts.
12. Requirement release creates exact snapshot and line lineage without allocation or Dispatch-execution facts.
13. Each success adds exactly one receipt, one domain event, and one audit event.
14. Deterministic failure creates no misleading domain, event, or audit mutation.
15. Planning runtime cannot write outside Planning/Core/Audit requirements.
16. Evidence and Dispatch runtimes cannot write Planning facts.
17. PA-04, PA-05B, PA-05C, and PA-05B-H1 regressions remain green.

Keep all fixture data synthetic and rolled back.

## Explicit non-goals

Do not add:

- React/Supabase connection or generated types;
- a new read API;
- generic Need Generation or school-catering persistence;
- confirmed-need adjustment, reopen, invalidation, revision, or cancellation;
- Procurement allocation or PO commands;
- Dispatch plan/trip/stop setup;
- new Evidence, load, departure, or delivery behavior;
- Warehouse, Storage, Edge Functions, Production/QA, Finance, or a workflow engine;
- seed/reference data;
- live Supabase deployment or hosted-project command;
- production data, credentials, Retool changes, or OPS v1 mutation.

## Validation

Before using Supabase CLI commands, run:

```bash
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

During development, run the focused PA-05D pgTAP test as needed. Near completion, run the complete validation set once:

```text
full local database reset
PA-04 pgTAP
PA-05B pgTAP
PA-05C pgTAP
PA-05B-H1 pgTAP
PA-05D pgTAP
database lint
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
git diff --check
```

Do not claim a check passed unless its command completed successfully.

## Stop conditions

Stop and produce a contract-gap report instead of improvising if:

- the current schema cannot represent the approved final states;
- a command would need to write Procurement, Evidence, Dispatch, Warehouse, or OPS v1 facts;
- the existing private helpers cannot support `PA-05D.v1` without changing PA-05B behavior;
- an approved uniqueness rule conflicts with an existing revision contract;
- a test exposes a material contradiction in the approved contract;
- safe concurrency would require a generic framework or broader privileges.

A contract-gap report must identify the exact rule, conflicting schema/helper/test, relevant files, smallest documentation amendment, migration impact, and confirmation that no implementation or external mutation occurred.

## Publication

When implementation and validation are complete:

1. Create one intentional implementation commit where practical.
2. Push `task/pa-05d-planning-command-family`.
3. Open a draft PR titled `PA-05D: Add bounded Planning command family`.
4. Do not mark the PR ready.
5. Do not merge it.
6. Do not close Issue #85.
7. Do not deploy or connect a hosted Supabase project.

## Final report

Return:

1. Branch name and commit hash.
2. Draft PR number and URL.
3. Files changed.
4. Exact four-function API surface.
5. Input and output of each command.
6. Authoritative rows written by each command.
7. Runtime grants and revocations.
8. Receipt, idempotency, event, and audit behavior.
9. pgTAP assertion counts for PA-04, PA-05B, PA-05C, PA-05B-H1, and PA-05D.
10. Results of every validation command.
11. Any contract deviation, or explicitly `none`.
12. Confirmation that no UI, live deployment, production data, credentials, Retool, OPS v1, Warehouse, Storage, Edge Function, generated type, seed data, read API, Procurement command, or Dispatch-setup command was added.
