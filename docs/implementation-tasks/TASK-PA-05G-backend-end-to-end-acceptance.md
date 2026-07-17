# TASK-PA-05G — Backend End-to-End Acceptance

## Codex settings

```text
Model: Sol
Reasoning: Medium
Agents: 1
Parallel agents: Off
Subagents: Off
```

PA-05G adds no business implementation. Medium reasoning is sufficient for exact command orchestration, ID/version propagation, authoritative assertions, and read verification.

## Gate

PA-05C-H2 Issue #102 is implemented, reviewed, and merged in PR #104 at:

```text
649cb953218bfaea401309c0520c49bbce1ced3b
```

Do not start PA-05G until this PA-05G documentation PR is reviewed and merged.

If the timeline still cannot represent the full correlation after H2, stop and report rather than patching it here.

## Objective

Add one rolled-back pgTAP suite proving that the existing 18-function API can author and safely read one complete supplier-direct wholesale journey from source recording through successful Trip closure.

## Start

From the approved latest `main` containing the merged PA-05G documentation, create:

```text
task/pa-05g-backend-end-to-end-acceptance
```

Read:

1. `AGENTS.md` and its mandatory handbook/register files;
2. `docs/architecture/arch-001-ops-erp-business-architecture.md`;
3. `docs/architecture/arch-002-atlas-system-map.md`;
4. the PA-05G contract and decision;
5. Issue #100 and all comments;
6. the PA-05C-H2 contract, migration, and focused test;
7. relevant PA-05D, PA-05E, PA-05B, PA-05F, PA-05B-H2, and PA-05B-H3 migrations and tests;
8. current read response shapes for trace, readiness, blockers, and timeline.

## Allowed files

Expected changes:

```text
supabase/tests/pa_05g_backend_end_to_end_acceptance.sql
docs/architecture/pa-05g-backend-end-to-end-acceptance-contract.md
docs/decisions/decision-pa-05g-command-authored-backend-acceptance.md
README.md
docs/architecture/roadmap.md
```

Do not modify migrations, predecessor tests, application code, package/config files, workflows, or generated files.

## Hard boundary

The API remains exactly 18 functions.

Do not add or modify a function, helper, role, capability, grant, RLS policy, schema object, dependency, application/UI code, generated type, CI workflow, or persistent seed row.

PA-05G is not a defect-fix branch.

## Acceptance suite

Add:

```text
supabase/tests/pa_05g_backend_end_to_end_acceptance.sql
```

Use a transaction, pgTAP `no_plan()`, `finish()`, and rollback.

Direct rolled-back DML is allowed only for Core authorization/identity and Admin reference prerequisites plus temporary test-local helpers/tables.

After setup, all Planning, Procurement, Evidence, Dispatch, Audit, and receipt writes must occur through `atlas_api` as `authenticated` with the matching JWT subject.

Direct private `SELECT` assertions are allowed after commands.

## Scenario

Use:

- one operator with all required command/read capabilities and GLOBAL scope;
- one active permitted driver;
- one customer/location;
- two ingredients;
- two eligible suppliers;
- one service date;
- one shared correlation ID.

Command-author:

```text
one two-line Wholesale Order
→ released Confirmed Need
→ released Purchase Handoff
→ released Dispatch Requirement
→ one two-line allocation split across two suppliers
→ two released supplier POs
→ two Evidence roots and two Evidence Applications
→ one Dispatch Plan and membership
→ one assigned Trip and one derived Stop
→ one atomic two-line Load
→ Departure
→ one atomic two-line successful Delivery
→ successful Trip Closure
```

Invoke all 14 write-command types. PO release, Evidence recording, and Evidence application run twice, so assert exactly 17 first-successful executions, receipts, events, and audits.

Use unique command IDs and idempotency keys. Derive operational IDs and versions from safe responses or authoritative post-command reads rather than hard-coding generated IDs.

Temporary request-builder, result, and ID helpers are allowed only inside the rolled-back test and only when they materially clarify the sequence.

## Required assertions

### Command responses

For every first execution assert:

- `success = true`;
- shared correlation ID;
- required affected IDs and new versions;
- completed idempotency state;
- safe message, warnings, and blockers shape;
- no error code or unsafe field.

### Authoritative chain

Assert exact root/child identity, status, quantity, unit, supplier, destination, service date, snapshot, revision, version, and timestamp continuity across:

```text
Planning
→ allocation and two POs
→ two Evidence/application pairs
→ Plan/Trip/Stop
→ two-line Load
→ Departure
→ two-line Delivery
→ Closure
```

Assert final Trip is `DELIVERED`, has exact `completed_at`, and expected final version. Assert no extra, missing, voided, superseding, return, exception, or unresolved fact.

Assert exactly 17 completed receipts, 17 domain events, and 17 audit events under the shared correlation, including one `SuccessfulDispatchTripClosed`.

### Reads

Call as the same authenticated actor:

1. `get_supplier_direct_trace` for each wholesale line revision;
2. `get_dispatch_evidence_readiness` for the completed trip;
3. `get_operator_blockers` for the completed trip;
4. `get_command_audit_timeline` for the shared correlation.

Inspect current response shapes before writing JSON assertions.

Prove:

- both traces report exact delivered quantity and `DELIVERED` Trip status;
- readiness contains both lines in its existing delivered state;
- blockers contains no unresolved actionable work using current vocabulary;
- timeline represents all 17 commands and includes closure;
- prohibited internal fields are absent;
- reads create no receipt, event, audit, or domain mutation.

### Surface/security

Assert only the integration essentials:

- exactly 18 API functions;
- authenticated executes exactly 18;
- anon and service_role execute none;
- API roles have no direct private relation or sequence access.

Do not duplicate predecessor negative or concurrency matrices.

## Stop conditions

Stop and produce a contract-gap report when:

- a command cannot consume prior authoritative output;
- operational fixture DML appears necessary;
- the two-supplier path cannot progress through PO, Evidence, Dispatch, delivery, or closure;
- a read cannot represent the completed journey;
- exact identity, quantity, unit, status, version, or security does not reconcile;
- any migration, function, privilege, RLS, dependency, or API change appears necessary.

Do not fix the backend in this task.

## Simplicity gate

Expected implementation:

```text
one acceptance SQL file
+ narrow result/status docs
```

No generic fixture/scenario framework, persistent test schema, orchestration service, shared production helper, or new dependency.

Inventory every temporary helper/table and remove it unless it materially clarifies request building or ID propagation.

## Validation economy

Near completion run locally:

1. one clean Supabase reset;
2. PA-05G pgTAP;
3. `git diff --check`.

Do not rerun every predecessor suite or routine frontend checks. GitHub Actions owns frozen install, workspace, formatting, typecheck, full tests, build, Storybook, artifacts, diff validation, and Qodana. Do not wait for Actions after opening the draft PR.

## Publication and report

Open draft PR:

```text
PA-05G: Prove command-authored backend acceptance
```

Do not mark ready, merge, close Issue #100, or deploy.

Report:

- branch and commit SHA;
- draft PR number;
- files changed;
- assertion count;
- complete command sequence;
- authoritative row, status, and version results;
- 17 receipt/event/audit counts;
- four read results;
- exact fixture boundary;
- focused local validation;
- checks delegated to GitHub Actions;
- contract deviations or explicitly none;
- limitations;
- whether PA-06 is unblocked for planning only.
