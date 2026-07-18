# TASK-PA-05C-H3 — Evidence Readiness Current Command Context

## Objective

Close Issue #110 by extending the existing READ-02 response with the current Fulfilment Allocation and Purchase Order lineage required to review new Evidence command intents after `STALE_VERSION`.

Do not implement Issue #109's React workbench. Do not add an RPC, capability, table, column, dependency, or write behavior. The `atlas_api` surface must remain exactly 18 functions.

## Baseline and branch

```text
Starting main: 2e55477a7dd21e89cb7b5feeded4d202fe8fb776
Branch: task/pa-05c-h3-evidence-readiness-command-context
Issue: #110
Blocked consumer: #109
```

## OPS_SYSTEM_MAP

```text
Mission
→ safe and transferable Atlas operations

Business Capability
→ refresh Supplier Evidence command context after stale rejection

Business Domain
→ Reporting / Read

Business Object
→ current Allocation and Purchase Order roots, revisions, and lines

Business Contract
→ bounded authorized current snapshot; contradictions fail closed

Command / Event
→ none

Read Model
→ READ-02 get_dispatch_evidence_readiness

Application
→ deferred PA-06C Supplier Evidence & Readiness workbench

Technology
→ PostgreSQL migration, pgTAP, GitHub Actions integration
```

## Required implementation

Create through the supported Supabase CLI workflow:

```text
supabase/migrations/20260718084742_pa_05c_h3_evidence_readiness_current_command_context.sql
```

Replace only:

```sql
atlas_api.get_dispatch_evidence_readiness(request jsonb)
```

Retain its signature, `PA-05C.v1`, three selectors, capability, `STABLE` and `SECURITY DEFINER` modes, `atlas_read_runtime` ownership, empty fixed `search_path`, existing shaped fields, and `advisory_only = true`.

Add `command_context.fulfilment_allocation` and `command_context.purchase_commitments` exactly as documented in `docs/architecture/pa-05c-h3-evidence-readiness-current-command-context.md`.

Use the root's direct `version`, the single non-cancellation current revision, the stable line, and the line revision belonging to that revision. PO rows must be active current commitments pointing to the exact current allocation-line revision and matching supplier, ingredient, unit, service date, and destination.

Return zero commitments as `[]`; preserve every legitimate commitment across split stable allocation portions in deterministic readiness-item/commitment order; exclude cancelled/superseded context; fail closed with `CURRENT_LINEAGE_CONFLICT` for unresolved or contradictory current lineage. PA-05E's one-PO-per-stable-allocation-line invariant remains unchanged, so an individual item's array is currently zero-or-one. Preserve historical Evidence references through the existing readiness rows.

## Security boundary

Inspect effective privileges before adding grants. Existing grants are sufficient, so this task adds no grant or RLS policy.

Retain:

- SELECT-only relation access for `atlas_read_runtime`;
- no sequence, write, schema-CREATE, or command-runtime authority;
- no private relation access for API roles;
- READ-02 execution for `authenticated` only;
- static qualified SQL and an empty `search_path`.

## Focused verification

Add:

```text
supabase/tests/pa_05c_h3_evidence_readiness_current_command_context.sql
```

The rolled-back suite must prove:

1. exactly 18 API functions;
2. all three selectors and existing response fields;
3. authenticated success plus anon, service-role, capability, and scope denial;
4. exact current Allocation root/version/revision/stable line/line revision lineage;
5. exact current PO root/version/revision/stable line/line revision lineage;
6. supplier, ingredient, unit, quantity, date, and destination matching;
7. deterministic zero, one, and multiple commitment results;
8. Allocation and PO supersession excludes old command context;
9. historical Evidence references remain visible;
10. contradictory active lineage returns `CURRENT_LINEAGE_CONFLICT` without partial results;
11. advisory and least-privilege hardening remains unchanged;
12. stale PO and Allocation commands fail with retained versions, refresh through the wholesale source selector, and succeed only as new intents using versions read from READ-02.

Keep PA-05G green. Update Supabase Integration to run one clean reset, PA-05G, this focused suite, existing PA-06B Auth/session verification, and unconditional cleanup.

## Validation

Run focused checks during implementation. Before push, run once:

```bash
pnpm ops:workspace
pnpm install --frozen-lockfile
pnpm format
pnpm typecheck
pnpm test
pnpm build
pnpm build-storybook
git diff --check
```

If personal Docker is unavailable, report that result and use GitHub Actions as the authoritative Supabase integration environment. Never connect, link, or deploy to hosted Supabase.

## Simplicity and stop gate

Expected bounded diff:

```text
one existing public read body replacement
+ one focused pgTAP suite
+ two new documents
+ two narrow cross-references
+ one CI test command
```

Stop if prior READ-02 fields/selectors cannot be preserved, a new RPC/capability/table/column/helper/runtime role is required, either command must change, current contradictions cannot fail closed, direct browser table access is needed, or work drifts into PA-06C UI.

## Publication

Open a draft PR titled:

```text
PA-05C-H3: Add current Evidence command context to readiness read
```

The body must include:

```text
Closes #110
Blocks #109 until merged
```

Do not mark ready, merge, deploy, close #109, or start PA-06C. Issue #109 is unblocked only after this task merges with authoritative validation passing.
