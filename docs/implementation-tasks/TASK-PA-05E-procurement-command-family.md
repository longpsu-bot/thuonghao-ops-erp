# TASK-PA-05E — Bounded Procurement command family

## Recommended Codex settings

```text
Model: Sol
Reasoning: High
Agents: 1
Parallel agents: Off
Subagents: Off
```

Use one implementation run. The task is security-sensitive and transactional; Spark is not appropriate for the primary implementation.

## Objective

Implement the approved PA-05E Procurement contract for supplier-direct wholesale Slice 1 without expanding into Warehouse, pricing, mixed sourcing, UI, deployment, or OPS v1.

Authoritative sources:

1. `AGENTS.md`
2. `docs/architecture/arch-001-ops-erp-business-architecture.md`
3. `docs/architecture/arch-002-atlas-system-map.md`
4. `docs/architecture/pa-05e-procurement-command-family-contract.md`
5. `docs/decisions/decision-pa-05e-bounded-supplier-direct-procurement.md`
6. GitHub Issue #88
7. PA-04, PA-05B, PA-05C, PA-05B-H1, and PA-05D migrations/tests

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

## Branch and publication

Start from latest `main` after the PA-05E documentation contract is merged.

Create:

```text
task/pa-05e-procurement-command-family
```

Open one draft PR titled:

```text
PA-05E: Add bounded Procurement command family
```

Do not mark ready, merge, close Issue #88, or deploy.

## Exact public surface

Add exactly:

```sql
atlas_api.allocate_supplier_direct_fulfilment(request jsonb)
atlas_api.release_supplier_purchase_order(request jsonb)
```

Use contract version `PA-05E.v1`. The resulting reviewed `atlas_api` count must be exactly 15. Add no public read function.

## Command behavior

### allocate_supplier_direct_fulfilment

Payload:

```json
{
  "dispatch_requirement_revision_id": "uuid",
  "lines": [
    {
      "dispatch_requirement_line_revision_id": "uuid",
      "supplier_id": "uuid",
      "allocated_quantity": 10,
      "unit_id": "uuid"
    }
  ]
}
```

Required implementation:

- exact top-level and line allowlists;
- 1–100 line bound;
- exact coverage of every current requirement line once;
- no duplicate line revision;
- exact quantity and unit equality;
- active suppliers and references;
- full PA-05D source-lineage proof;
- one allocation root/revision per Dispatch Requirement;
- one allocation line/line revision per requirement line;
- `READY_FOR_DISPATCH` root/revision and `READY_FOR_EVIDENCE` lines;
- no PO, Evidence, Dispatch execution, Warehouse, or reporting write.

### release_supplier_purchase_order

Payload:

```json
{
  "fulfilment_allocation_revision_id": "uuid",
  "supplier_id": "uuid",
  "document_number": "text"
}
```

Required implementation:

- exact payload allowlist;
- active supplier represented in the allocation;
- current `READY_FOR_DISPATCH` allocation revision;
- all selected supplier lines remain `READY_FOR_EVIDENCE`;
- complete allocation → requirement → PA-05D lineage proof;
- one PO for every current allocation line of the selected supplier;
- no caller-selected line subset;
- one released PO per allocation revision and supplier;
- globally unique non-empty document number;
- active supplier/location snapshots;
- no Evidence, Dispatch execution, Warehouse, pricing, invoice, or Finance write.

## Security boundary

Create `atlas_procurement_command_runtime`:

- `NOLOGIN`, `NOINHERIT`;
- owns only the two PA-05E functions;
- fixed empty `search_path`;
- no dynamic SQL;
- no Atlas schema `CREATE` after owner transfer;
- no sequence mutation;
- minimum verb-specific grants and forced-RLS policies;
- read-only access to required Admin/Core/Planning lineage;
- write access only to approved Procurement, command receipt, domain event, and audit rows;
- no Planning mutation;
- no Evidence, Dispatch, Warehouse, Storage, reporting-write, legacy, or external-service authority.

Capabilities:

```text
supplier_direct_fulfilment.allocate
supplier_purchase_order.release
```

Both belong to `PROCUREMENT`.

Preserve existing Planning, Evidence, Dispatch, and Read runtime behavior. Do not broaden their privileges.

## Command safety

Reuse established safe patterns where applicable:

- request validation;
- JWT/auth subject resolution;
- active actor/subject checks;
- capability and relational scope;
- delegation rejection;
- command receipts;
- exact replay;
- idempotency conflict;
- expected version;
- deterministic locking;
- authoritative re-read after locks;
- safe allowlisted errors;
- one event and one audit event per success;
- safe failed receipt for deterministic post-receipt failures.

Do not refactor or generalize PA-05B or PA-05D helpers unless implementation is impossible; stop and report instead.

## Required indexes/constraints

Use existing PA-04 tables. Add only narrowly justified race-safety objects. Before adding an object, confirm an equivalent object does not already exist.

Candidate invariants, only if absent:

- one allocation root per Dispatch Requirement;
- one stable allocation line per allocation root, requirement line, and portion sequence;
- one current allocation revision per allocation root;
- one current PO revision per PO root;
- one stable PO line per PO root and allocation line;
- one released PO per allocation revision and supplier.

Do not duplicate existing global document-number uniqueness.

## Required pgTAP coverage

Add `supabase/tests/pa_05e_procurement_command_family.sql` proving at minimum:

### Surface/security

- exactly 15 reviewed API functions;
- both PA-05E functions are hardened definers owned by Procurement runtime;
- Procurement runtime owns only those functions;
- no dynamic SQL or mutable search path;
- no schema CREATE or sequence mutation;
- `authenticated` executes exactly 15 reviewed functions;
- `anon` and `service_role` execute none;
- API roles have no direct private access;
- Procurement runtime cannot mutate Planning/Evidence/Dispatch/Warehouse/legacy facts;
- other runtimes cannot mutate Procurement facts beyond existing approved dependencies.

### Authorization/input

- malformed/wrong contract request;
- missing or mismatched subject;
- inactive actor/subject;
- missing capability;
- wrong customer/location scope;
- unsupported delegation;
- unknown top-level and line fields;
- empty and oversized lines;
- duplicate and missing requirement-line coverage;
- inactive supplier/reference;
- non-positive, partial, excess, or wrong-unit allocation.

### Allocation

- multi-line, multi-supplier exact allocation succeeds atomically;
- exact replay returns original IDs;
- conflicting reuse fails;
- stale version and wrong lifecycle fail;
- duplicate allocation fails;
- concurrent duplicate allocation produces one valid result;
- cross-wired Planning lineage fails before Procurement/event/audit writes;
- exact root/revision/line counts and statuses;
- no PO, Evidence, or Dispatch execution rows are created.

### Supplier PO

- one supplier PO includes every and only current allocation line for that supplier;
- second supplier can receive a separate PO;
- caller cannot omit supplier lines because lines are not caller-selected;
- ordered quantities, units, ingredients, destination, date, and lineage match exactly;
- supplier/location snapshots are exact;
- replay and conflict behavior;
- stale version and wrong lifecycle;
- duplicate supplier/allocation PO;
- duplicate document number;
- concurrent duplicate safety;
- cross-wired allocation lineage fails before PO/event/audit writes;
- no Evidence or Dispatch execution rows are created.

### Receipt/event/audit

- each first successful command creates exactly one completed receipt, one domain event, and one audit event;
- replay adds no duplicates;
- deterministic failures create no misleading domain event or audit event.

Update cumulative PA-04/PA-05B/PA-05B-H1 tests only where the expected reviewed API count or runtime-owner inventory must become 15/include Procurement runtime.

## Complexity inventory

Before finalizing, list every new:

- database object;
- index or constraint;
- private helper;
- runtime grant;
- RLS policy;
- event.

For each, state:

1. command requiring it;
2. invariant/security boundary protected;
3. failure without it;
4. why an existing object/helper is insufficient.

Remove anything that cannot be justified.

## Explicit non-goals

Do not add:

- new authoritative tables;
- partial/split/mixed/Warehouse allocation;
- supplier auto-selection or ranking;
- conversion, rounding, substitution, or backorder;
- prices, tax, currency, payment terms, invoice, Finance;
- PO amendment/cancellation/acknowledgement;
- Dispatch plan/trip/stop setup;
- new Evidence/load/departure/delivery command;
- read API or reporting view;
- UI, generated types, seed data;
- Edge Function, Storage, queue, trigger, or background job;
- live deployment, hosted-project mutation, production data, credentials;
- Retool or OPS v1 changes;
- generic workflow/allocation/document/repository framework.

## Stop conditions

Stop and produce a contract-gap report rather than improvising if:

- existing PA-04 columns/statuses cannot represent the approved final states;
- a command must mutate Planning, Evidence, or Dispatch facts;
- supplier-specific PO lineage cannot be made unique without a new business decision;
- expected-version semantics conflict with multiple supplier PO release;
- current PA-05B evidence validation requires a materially different PO/allocation state;
- an approved uniqueness rule conflicts with an existing index/constraint;
- PA-05D lineage cannot be independently proven from existing relationships.

## Validation

Before using Supabase CLI commands, inspect:

```text
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Create the migration through the supported CLI workflow. Do not invent a timestamp manually.

During development, run focused PA-05E tests. Near completion run once:

- full local database reset;
- PA-04 pgTAP;
- PA-05B pgTAP;
- PA-05C pgTAP;
- PA-05B-H1 pgTAP;
- PA-05D pgTAP;
- PA-05E pgTAP;
- database lint;
- `pnpm ops:workspace`;
- `pnpm format`;
- `pnpm typecheck`;
- `pnpm test`;
- `pnpm build`;
- `git diff --check`.

## Final report

Return:

1. branch and commit hash;
2. draft PR number;
3. files changed;
4. exact two-function API surface and total API count;
5. inputs/outputs and authoritative rows written by each command;
6. lineage and quantity invariants;
7. runtime grants/revocations and RLS boundary;
8. every new object with complexity justification;
9. pgTAP counts and full validation results;
10. contract deviations, or `none`;
11. confirmation that no excluded work, live system, Retool, or OPS v1 state was changed.