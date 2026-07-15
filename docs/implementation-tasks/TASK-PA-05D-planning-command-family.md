# TASK-PA-05D — Implement bounded Planning command family

## Recommended Codex execution

```text
Model: Sol
Reasoning: High
Agents: 1
Parallel/subagents: Off
Mode: coding agent in the repository checkout
```

Use one implementation run. Do not perform a separate broad reconnaissance run; the contract below is the approved scope. Stop and report rather than inventing behavior if the repository contradicts the contract materially.

## Repository and branch

Repository:

```text
https://github.com/longpsu-bot/thuonghao-ops-erp
```

Start from latest `main` after merged PR #84.

Create:

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
10. Issue #85

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

Do not add a read wrapper or any other public function.

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

Create only a Draft wholesale source root, stable lines, and current Draft line revisions. Require 1–100 lines, positive unique line numbers, positive quantities, active references, a location belonging to the customer, a wholesale customer, and no duplicate active customer-order reference.

For this create command, `expected_version` must be `1`.

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

Do not persist intermediate Validated/Approved states. Validation and approval occur inside this bounded command.

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

Require `expected_version` to match the Confirmed Need batch. Require a released batch, matching approval snapshot, current released line revisions, and complete source lineage.

Atomically create and release:

- one Purchase Handoff batch;
- one current Base revision;
- stable handoff lines;
- exact handoff line revisions;
- one purchase-demand reference per line.

Do not create supplier assignment, allocation, PO, or evidence.

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

Require `expected_version` to match the Purchase Handoff root. Require a current released revision, complete line and demand-reference lineage, one customer/location/date scope, and no existing current released requirement for the same handoff revision.

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
- auth-subject/actor resolution;
- safe command errors;
- capability and relational-scope authorization;
- request hashing;
- command receipts and replay/conflict behavior;
- command completion.

Add a private PA-05D request validator for `PA-05D.v1`.

Do not change the public behavior of PA-05B or PA-05C functions. Avoid broad helper renames or generic framework refactors.

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

Resolve capability and relational scope server-side. Reject delegation, management override, and approval shortcut payload fields.

## Runtime security

Create:

```text
atlas_planning_command_runtime
```

Requirements:

- `NOLOGIN`, `NOINHERIT`;
- owns only the four PA-05D API functions;
- empty fixed `search_path` on all entry functions;
- no dynamic SQL or caller-controlled object names;
- no Atlas schema `CREATE` after temporary ownership transfer;
- no sequence mutation privilege;
- no Procurement, Evidence, Dispatch, Warehouse, reporting-write, legacy, Storage, or external-service privilege;
- no membership in another command runtime;
- verb-specific grants and RLS policies only;
- reference-row `UPDATE` grants only where PostgreSQL needs them for row locks and with no matching update policy;
- public execute revoked first;
- `authenticated` receives execute only on the reviewed 13-function Atlas API surface;
- `anon` and `service_role` receive no Atlas API execute;
- API roles retain no direct private table/view/sequence access.

Existing Evidence, Dispatch, and Read runtime privileges must not broaden.

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

Re-read authoritative status/version/current-line state after locks.

Add only race-safety indexes/constraints approved by the PA-05D contract, with clear names and comments where useful:

- duplicate customer/order reference prevention;
- one Confirmed Need batch per wholesale order for this bounded slice;
- one current released Dispatch Requirement per handoff revision.

Do not introduce generic workflow, numbering, queue, or orchestration tables.

## Error and replay behavior

Preserve the established safe errors and prove at least:

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

Exact replay returns original IDs and creates no duplicate rows. Same key or command ID with different canonical payload fails. Deterministic post-receipt validation stores a failed non-retryable receipt without misleading domain/event/audit writes.

## Required files

Create a Supabase migration using the repository's current migration workflow. Do not invent a timestamp manually; use the installed Supabase CLI command after checking `--help`.

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
8. Source creation replay/conflict and duplicate business reference behavior are correct.
9. Wholesale release stale version/wrong lifecycle fail without mutation.
10. Wholesale release creates exact released Confirmed Need lines and approval snapshot.
11. Handoff release creates exact lines and source demand references without Procurement facts.
12. Requirement release creates exact snapshot/line lineage without allocation or Dispatch execution facts.
13. Each success adds exactly one receipt, one domain event, and one audit event.
14. Deterministic failure creates no misleading domain/event/audit mutation.
15. Evidence and Dispatch runtimes cannot write Planning facts.
16. PA-04, PA-05B, PA-05C, and PA-05B-H1 regressions remain green.

Keep all fixture data synthetic and rolled back.

## Explicit non-goals

Do not add:

- a React/Supabase connection or generated type;
- a new read API;
- generic Need Generation or school-catering persistence;
- confirmed-need adjustment/reopen/invalidation/revision/cancellation;
- Procurement allocation or PO commands;
- Dispatch plan/trip/stop setup;
- new Evidence, load, departure, or delivery behavior;
- Warehouse, Storage, Edge Functions, Production/QA, Finance, or workflow engine;
- seed/reference data;
- live Supabase deployment or hosted project command;
- production data, credentials, Retool changes, or OPS v1 mutation.

## Validation

Before using Supabase CLI commands:

```text
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Then run:

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

Run focused PA-05D tests during development. Run the full suite once near completion rather than after every small edit.

## Stop conditions

Stop and report without implementing speculative behavior if:

- the current schema cannot represent the approved final states without an additional authoritative business object;
- a command would need to write Procurement, Evidence, or Dispatch-owned facts;
- multiple customers, locations, or service dates appear in one handoff unexpectedly;
- the existing command helpers cannot support `PA-05D.v1` without changing PA-05B behavior;
- the required uniqueness rule would block an approved existing revision/correction contract;
- tests reveal a contradiction between PA-05D and merged PA-04/PA-05B behavior.

Report the exact contradiction and propose the smallest documentation amendment. Do not improvise a broader model.

## Git and publication

- Keep the working tree scoped and clean.
- One intentional implementation commit is preferred.
- Push the branch.
- Open a draft PR.
- Do not mark ready, merge, close Issue #85, or deploy.

Suggested PR title:

```text
PA-05D: Add bounded Planning command family
```

## Final report

Return:

1. Branch and commit hash.
2. Draft PR number.
3. Files changed.
4. Exact four-function API surface added.
5. Runtime privileges added/revoked/retained.
6. Input, output, and authoritative rows for each command.
7. Events/audit/receipt behavior.
8. Tests added and exact totals.
9. Full validation results.
10. Any contract deviation or none.
11. Confirmation that no UI, live deployment, production data, Retool, OPS v1, Warehouse, Storage, Edge Function, generated type, seed data, new read API, Procurement command, or Dispatch-setup command was added.