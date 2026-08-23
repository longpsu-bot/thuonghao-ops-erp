# RMVP-04 Connected Need Generation API Contract

**Status:** Implemented on a draft branch; exact-head GitHub validation and merge pending

**Contract version:** `RMVP-04.v1`

**Owning domain:** Planning

**Capability:** `planning.need_generation.write` for writes; existing `planning.inputs.read` for the read
**Runtime:** `atlas_need_generation_runtime` (`NOLOGIN NOINHERIT`)

## 1. Boundary

RMVP-04 converts one exact current `NEED_GENERATION_REQUESTED` Planning Input Set into immutable atomic theoretical Ingredient contributions, validates them, releases them, and exposes the existing CMD-15 materialization boundary.

```text
approved Weekly Menu
+ approved Attendance
+ approved Pantry evidence
→ READY Planning Input Evaluation
→ NEED_GENERATION_REQUESTED
→ generated atomic Recipe and Pantry contributions
→ validated run
→ immutable release snapshot
→ existing CMD-15 Confirmed Need materialization
```

The backend chooses source evidence, Recipe/version/line revisions, the fixed calculation-contract revision, identifiers, quantities, predecessor lineage, issues, and release membership. The browser cannot author or edit those facts.

This contract adds no table, view, lifecycle state, source trigger, sequence, generic registry, formula engine, Procurement record, Purchase Handoff, Warehouse record, or Dispatch record. It does not change `PA-06E-H0C.v1` or CMD-15 semantics.

## 2. Public surface

Exactly five functions use `jsonb → jsonb`:

1. `atlas_api.get_need_generation_workbench(request jsonb)`
2. `atlas_api.create_need_generation_run(request jsonb)`
3. `atlas_api.validate_need_generation_run(request jsonb)`
4. `atlas_api.release_need_generation_run(request jsonb)`
5. `atlas_api.invalidate_need_generation_run(request jsonb)`

All are fixed-search-path security definers owned by `atlas_need_generation_runtime`. Execute is revoked from `PUBLIC`, `anon`, and `service_role`, then granted only to `authenticated`.

## 3. Common authorization

Every call requires:

- an authenticated human Actor mapped from the JWT subject;
- exact equality between the JWT subject and `requested_by_auth_subject`;
- an active role membership and active capability;
- active `GLOBAL` scope for v1.

The read requires `planning.inputs.read`. The four RMVP-04 writes require `planning.need_generation.write`. UI visibility is not authorization.

## 4. Read envelope

```json
{
  "contract_version": "RMVP-04.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {
    "period_start": "YYYY-MM-DD",
    "period_end": "YYYY-MM-DD",
    "need_generation_run_id": "uuid or null",
    "filters": {
      "service_date": "YYYY-MM-DD or null",
      "school_id": "uuid or null",
      "ingredient_id": "uuid or null",
      "contribution_family": "RECIPE_DERIVED|PANTRY_DIRECT|null"
    },
    "group_offset": 0,
    "group_limit": 100,
    "detail_group": {
      "service_date": "YYYY-MM-DD",
      "school_id": "uuid",
      "delivery_location_id": "uuid",
      "ingredient_id": "uuid",
      "unit_id": "uuid"
    }
  }
}
```

`filters` and `detail_group` are optional. Offset defaults to `0`; limit defaults to `100` and must be `1..250`. A supplied run must belong to the exact period and Planning Input Set. The read creates no state.

### 4.1 Workbench response

On success the response contains `success`, `contract_version`, `correlation_id`, and one `workbench` object with:

- exact period;
- Planning Input Set identity/status;
- current evaluation identity/version/result;
- exact Menu, Attendance, and Pantry source summaries;
- terminal run and selected historical run;
- run status/version/counts/timestamps;
- blocking issues before warnings;
- grouped requirements;
- optional atomic detail;
- run history;
- Confirmed Need materialization state;
- backend-derived allowed actions and disabled reasons;
- pagination metadata.

Grouped rows use the complete identity:

```text
service_date
customer_id
school_id
delivery_location_id
ingredient_id
unit_id
```

They return names plus `total_theoretical_quantity`, `recipe_derived_quantity`, `pantry_direct_quantity`, active/removed contribution counts, and warning count. Recipe contributions use the School default location for a newly generated run and retained immutable destination evidence where historical materialization provides it. Pantry contributions always use the exact Pantry Delivery Location. Different Delivery Locations or Units never merge.

Atomic detail exposes only safe contribution family, theoretical quantity, Unit, disposition, Dish/Recipe display evidence or Pantry Purpose/source reference, and warning references.

Materialization returns `confirmed_need_batch_id`, `confirmed_need_batch_version`, `confirmed_need_status`, and `materialization_mode` (`INITIAL`, `CORRECTION`, or `NONE`).

## 5. Write envelope

```json
{
  "contract_version": "RMVP-04.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "nonblank text",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601 timestamp",
  "reason_code": "closed command-specific code",
  "reason_note": "text or null",
  "payload": {}
}
```

For create, `expected_version` is the exact current Planning Input Evaluation version. For validate, release, and invalidate, it is the exact current Need Generation run version.

Every successful write creates one command receipt, one domain event, and one audit event. Exact replay returns the stored response without another side effect. Reusing a command identity with changed intent returns `IDEMPOTENCY_CONFLICT`. Writes are never automatically retried by the application.

## 6. Create run

### Request

```json
{
  "reason_code": "NEED_GENERATION_CREATED",
  "reason_note": null,
  "payload": {
    "planning_input_set_id": "uuid",
    "planning_input_evaluation_id": "uuid",
    "period_start": "YYYY-MM-DD",
    "period_end": "YYYY-MM-DD"
  }
}
```

The root must be exactly `NEED_GENERATION_REQUESTED`; the supplied evaluation must be the current `READY` evaluation with zero blockers and the exact expected evaluation version. Its Menu, Attendance, and Pantry approval triples must still be current and cover the requested period. The backend locks those roots deterministically and selects the current approved calculation contract.

Initial creation is attempt `1`, has no predecessor, and starts `GENERATED` version `1`. Creation after an invalidated terminal run uses the next ordinal and direct predecessor. One noninvalidated terminal run blocks another create.

The transaction writes the existing run, input snapshot, Recipe selections, Recipe-line uses, atomic Recipe contributions, atomic Pantry contributions, predecessor/removal evidence, every-and-only issue rows, and exact counts. It commits all evidence or none. Recipe quantity remains:

```text
(student_portions + teacher_portions)
× quantity_per_basis
÷ basis_portions
→ fixed PostgreSQL numeric coercion from the bound calculation revision
```

Pantry quantity is the exact approved `requested_quantity`; it is never Recipe-exploded. Event: `NeedGenerationCreated`.

## 7. Validate run

Payload is `{ "need_generation_run_id": "uuid" }`; reason is `NEED_GENERATION_VALIDATED` with null note.

Only the exact terminal `GENERATED` run at the expected version can validate. Blocking issue count must be zero; warnings are allowed. Existing H0A5 integrity must still prove exact counts and typed lineage. The command changes only the run to `VALIDATED`, increments its version once, and records Actor/time. Event: `NeedGenerationValidated`.

## 8. Release run

Payload is `{ "need_generation_run_id": "uuid" }`; reason is `NEED_GENERATION_RELEASED` with null note.

Only the exact terminal `VALIDATED` run at the expected version and with zero blockers can release. The command creates one existing immutable release snapshot with every-and-only theoretical-line membership and complete issue membership, changes the run to `RELEASED_FOR_CONFIRMATION`, increments its version once, and records Actor/time. Event: `NeedGenerationReleased`.

The sole warning, `ZERO_ACTIVE_THEORETICAL_QUANTITY`, does not block validation or release. Existing CMD-15 still rejects an active zero-quantity contribution under its approved v1 contract, so the workbench returns `allowed_actions.materialize = false` with a correction reason for such a released run. The operator must correct approved source evidence, invalidate the run, and generate a successor before materialization.

## 9. Invalidate run

Payload is `{ "need_generation_run_id": "uuid" }`. Allowed reasons are `UPSTREAM_SOURCE_CHANGED` and `PLANNING_CORRECTION`; a nonblank note is mandatory.

Only the exact terminal run at the expected version can invalidate. `GENERATED` and `VALIDATED` are allowed. `RELEASED_FOR_CONFIRMATION` is allowed only while downstream remains safely correctable: no released Purchase Handoff or later commitment exists, and any linked Confirmed Need remains correction-permitted (`DRAFT_REVIEW` or `REOPENED`). Otherwise the command returns `DOWNSTREAM_CORRECTION_REQUIRED`.

Invalidation preserves every line, issue, release membership, event, audit, and Confirmed Need history. It changes only the run to `INVALIDATED`, increments its version once, and records Actor/time/reason. Event: `NeedGenerationInvalidated`.

## 10. CMD-15 connection

RMVP-04 does not add a materialization command. The application invokes existing `atlas_api.create_confirmed_needs_from_generation(jsonb)` with `PA-06E-H0C.v1`.

Initial payload:

```json
{
  "need_generation_run_id": "uuid",
  "need_generation_run_version": 3,
  "confirmed_need_batch_id": null
}
```

Correction supplies the exact existing batch ID returned by the workbench. CMD-15 retains its capability, runtime, receipts, events, audit, safe errors, operational grouping, and immutable contribution membership. The workbench is refreshed after it returns.

## 11. Success and failure behavior

Write success follows the Atlas command envelope and includes affected aggregate IDs, new run version, event/audit IDs, safe operator message, and authoritative workbench readback. Release additionally returns the release snapshot ID.

RMVP-04 uses common Atlas validation, authentication, authorization, stale-version, idempotency, and concurrency errors. Its narrow domain failures are:

- `READINESS_NOT_REQUESTED`
- `CURRENT_EVALUATION_NOT_READY`
- `STALE_SOURCE_BINDING`
- `NEED_GENERATION_RUN_ALREADY_ACTIVE`
- `NEED_GENERATION_RUN_NOT_FOUND`
- `NEED_GENERATION_RUN_NOT_TERMINAL`
- `NEED_GENERATION_RUN_NOT_GENERATED`
- `NEED_GENERATION_RUN_NOT_VALIDATED`
- `NEED_GENERATION_HAS_BLOCKERS`
- `DOWNSTREAM_CORRECTION_REQUIRED`

Failures contain safe operator messages and no SQL, policy, role, private payload, or credential detail.

## 12. Verification

`supabase/tests/rmvp_04_connected_need_generation.sql` executes one real mixed journey from approved Menu/Attendance/Pantry through readiness, request, creation, grouped Recipe/Pantry evidence, warning completeness, validation, release, CMD-15 quantities/destinations/membership, replay/conflict, authorization failures, invalidation, and direct successor lineage.

`scripts/verify-local-rmvp04-need-generation.mjs` is registered only in GitHub's disposable local-Supabase workflow. It uses a signed-in synthetic human and the browser key for every API call through authoritative readback. Local development does not start/reset Supabase or run pgTAP.

## 13. Additive atomic execution (`RMVP-04.v2`)

PLANNING-CONTRACT-01 adds one public command:

```text
atlas_api.execute_need_generation(request jsonb)
```

It reuses `planning.need_generation.write`, `atlas_need_generation_runtime`, existing source/readiness/Need Generation persistence, and the existing H0C grouping and correction algorithm. Its `RMVP-04.v2` payload contains only `period_start`, `period_end`, and `expected_current_need_generation_run_id`; the command envelope carries the expected current run version (`1` with a null run for initial generation).

One transaction locks and rereads completed sources, derives preflight, automatically records/reuses the exact readiness evaluation and handoff facts, creates the run, validates deterministic integrity, releases immutable theoretical membership, and internally materializes or corrects Confirmed Need. There is one top-level command receipt and one authoritative response. The browser must not chain v1 readiness, create, validate, release, or CMD-15 writes.

When current immutable source triples already match the current Need input snapshot, exact execution returns `NO_CHANGE`. A source successor makes the prior Need `OUTDATED`. A reviewed update invalidates the safely correctable terminal run, creates its direct successor, preserves all source/run/release history, and rematerializes only an H0C-permitted `DRAFT_REVIEW`/`REOPENED` Confirmed Need. Approved, released, or downstream-committed facts retain the established safe correction blocker.

The private materialization helper is shared by this command and the unchanged public `PA-06E-H0C.v1` wrapper; the algorithm is not duplicated. All five `RMVP-04.v1` functions and the public CMD-15 wrapper remain callable during coexistence. See [PLANNING-CONTRACT-01](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md).

The public v2 `requested_at` records client intent and permits no more than 60
seconds of positive clock skew. After it passes the top-level boundary, every
server-derived readiness, generation lifecycle, and Confirmed Need
materialization request uses PostgreSQL transaction time. RMVP-03B.v1,
RMVP-04.v1, PA-06E-H0C.v1, and D-037 timestamp semantics remain unchanged for
independent public calls.

## 14. Daily connected execution (`RMVP-04.v3`)

Issue #223 makes `service_date` the authoritative grain for new connected school-catering Need. The canonical public command name remains `atlas_api.execute_need_generation(jsonb)`, but the React workflow now sends the strict v3 payload:

```json
{
  "service_date": "2026-08-17",
  "expected_current_need_generation_run_id": null
}
```

`period_start` and `period_end` are not accepted in a v3 payload. The backend adapts the intent to the approved atomic implementation with `period_start = period_end = service_date`; therefore one successful command creates or advances only that date's Planning Input evaluation, Need run/release, and Confirmed Need batch. The v2 range contract remains callable for historical compatibility but is no longer used by the connected React flow.

Source parents may still cover a week or period. Each daily evaluation binds the exact current Weekly Menu, Attendance, and Pantry approval snapshot headers, while generation selects only snapshot lines whose `service_date` equals the commanded date. Recipe arithmetic and PostgreSQL numeric coercion are unchanged.

The weekly UI is a projection over seven independent calls to the existing backend preflight read with `D..D`. Date-level currentness compares stable facts from the selected date inside the current run's bound snapshots with the same date inside the newest approved parent snapshots. An unrelated-day parent successor therefore does not make every day outdated, while exact parent snapshot IDs remain preserved on each run for immutable lineage. These fingerprints are read evidence only and are never client authority.

Same-date unchanged execution returns the established replay or `NO_CHANGE` result. A safely correctable changed date uses the established invalidation/direct-successor and Confirmed Need correction model; other service dates are not locked or mutated. The full reverse-correction workflow after downstream commitment remains owned by Issue #222.

## 14. Selective confirmation continuity

PLANNING-CONTRACT-02B keeps the `RMVP-04.v2` request and public function unchanged. On correction, the existing private materializer compares direct predecessor/successor Confirmed Need facts and returns additive backend-owned `result_counts`: `carried_forward_count`, `needs_review_count`, `changed_count`, `new_count`, and `removed_count` alongside the established materialization counts. `removed_count` is the number of distinct predecessor Confirmed Need business identities absent from the exact direct successor current set; it does not depend on whether a removed identity had a human decision or therefore produced invalidation evidence.

Carry requires exact stable identity, exact PostgreSQL generated quantity equality, the same sole effective H1A policy revision, and valid current authority in the direct predecessor. Source/Dish/Recipe membership is deliberately not an equality predicate. System carry creates no human decision; proposal/policy/removal invalidation is immutable private evidence. `RELEASED_FOR_PURCHASE_HANDOFF` and other established correction blockers still return `DOWNSTREAM_CORRECTION_REQUIRED` before any continuity or rematerialization write.
