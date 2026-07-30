# Decision PANTRY-RDY-01 — Pantry Binding for Planning Input Readiness

- **Status:** Accepted
- **Decision date:** 2026-07-29
- **Owner:** Product Owner
- **Scope:** Documentation and product-decision amendment only
- **Detailed amendment:** [PANTRY-RDY-01 Planning Input Readiness Amendment](../architecture/pantry-rdy-01-planning-input-readiness-amendment.md)
- **Parent architecture:** [PD-01.4 Planning Domain Input Readiness Contract](../architecture/planning-domain-input-readiness-contract.md)
- **Parent decision:** [Decision PA-06E-H0A4 — Planning Input Readiness](decision-pa-06e-h0a4-planning-input-readiness.md)

## Context

The accepted H0A4 readiness model and its H0A4b persistence bind one exact
approved Weekly Menu snapshot and one exact approved Attendance snapshot.
PANTRY-02 now provides a third Planning-owned source with stable weekly batches,
immutable exact approval snapshots, and explicit controlled zero-line evidence.

Planning Input Readiness must admit that source without treating a missing
Pantry approval as no additions, weakening typed lineage, rewriting historical
evaluations, changing the stable exact-period root, or authorizing downstream
calculation.

On 2026-07-29, the Product Owner explicitly approved the complete registry
below: “I approve PRDY-P01 through PRDY-P10 exactly as proposed.”

## Canonical accepted decision registry

This is the sole complete canonical registry for PRDY-P01 through PRDY-P10.

### PRDY-P01 — Three mandatory readiness sources

Every new `READY` evaluation and every new Need Generation request requires:

- one exact approved Weekly Menu snapshot;
- one exact approved Attendance snapshot;
- one exact approved Pantry snapshot;
- period containment for all three sources; and
- zero blocking issues.

Missing Pantry is not interpreted as no additions.

### PRDY-P02 — Direct typed Pantry binding

The direct typed Pantry binding is exactly:

- `pantry_need_batch_id`;
- `pantry_need_approval_snapshot_id`; and
- `approved_batch_version`.

The fields are all absent or all present.

Generic, polymorphic, JSON-only, hash-only, or untyped source authority is
rejected.

### PRDY-P03 — Pantry period containment

The Pantry batch week must wholly contain the evaluated period.

Multiple Pantry snapshots must not be combined to manufacture coverage.

### PRDY-P04 — Positive and explicit zero-line evidence

Both are valid Pantry evidence:

- an approved positive-line snapshot; and
- an approved explicit zero-line snapshot with:
  - `no_additions_confirmed = true`;
  - `line_count = 0`; and
  - zero snapshot-line rows.

A zero-line snapshot is not missing evidence and creates no zero-quantity line.

### PRDY-P05 — Current approved Pantry eligibility

A Pantry snapshot can support a new `READY` evaluation only when:

- the batch is `APPROVED`;
- the current batch version equals the snapshot approved version;
- the latest-approval pointer equals the selected snapshot; and
- typed ownership and period containment pass.

Draft, Validated, Reopened, and superseded Pantry evidence is ineligible for a
new evaluation.

### PRDY-P06 — Immutable historical evaluations

Prior evaluations, bindings, issues, results, and versions remain immutable.

A corrected Pantry approval requires a successor readiness evaluation on the
same exact-period root.

### PRDY-P07 — Explicit invalidation and fail-closed request

No automatic Pantry-to-readiness trigger is authorized.

Invalidation remains an explicit later authorized operation.

A Need Generation request must fail closed when the Pantry binding is no longer
the exact current approved Pantry snapshot.

### PRDY-P08 — Pantry issue classifications

Add only these Pantry-specific blocker codes:

- `MISSING_PANTRY_APPROVAL_SNAPSHOT`;
- `PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD`.

Reuse:

- `SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH`;
- `STALE_OR_MISMATCHED_SNAPSHOT_BINDING`;
- `REQUEST_WITHOUT_CURRENT_READY_EVALUATION`.

Permit `input_type = 'PANTRY'`.

### PRDY-P09 — Warning boundary

Keep the current three Menu/Attendance warnings unchanged.

Add no Pantry cross-source warning in this slice.

### PRDY-P10 — No downstream calculation

The amendment creates no calculation or downstream operational fact.

Pantry Need Generation remains a separate later amendment.

## Historical compatibility

Historical readiness evaluations created before PANTRY-RDY-02 remain immutable
and may retain null Pantry binding fields.

Once PANTRY-RDY-02 becomes executable database authority, those evaluations
remain valid historical evidence but cannot authorize a new Need Generation
request.

For a current root:

- `READY` or `NEED_GENERATION_REQUESTED` must be explicitly invalidated before
  a successor evaluation can bind Pantry;
- `NOT_READY` may be re-evaluated directly to its next evaluation version with
  Pantry evidence; and
- `INVALIDATED` may be re-evaluated directly with Pantry evidence.

No Pantry binding may be fabricated, backfilled, or written into a historical
evaluation.

## Supersession and preserved authority

PANTRY-RDY-01 amends only source binding and the related readiness, containment,
issue, and request-eligibility rules in the parent H0A4 architecture contract
and decision. It preserves:

- one stable Planning Input Set root per exact inclusive period;
- immutable sequential evaluations and evaluation-owned issues;
- the closed `NOT_READY`, `READY`, `NEED_GENERATION_REQUESTED`, `INVALIDATED`
  lifecycle;
- explicit invalidation and successor re-evaluation;
- warning acknowledgement deferral; and
- evidence-only handoff semantics.

The existing H0A4b persistence migration, tests, and implementation record are
not modified by this decision.

## Future PANTRY-RDY-02 maximum boundary

PANTRY-RDY-01 is accepted target business and architecture authority. Its
Pantry binding and request requirements become executable database authority
only after the separately reviewed PANTRY-RDY-02 persistence amendment is
merged.

The currently merged H0A4b schema and guards physically support only Weekly
Menu and Attendance. PANTRY-RDY-02 is required before PostgreSQL enforces
Pantry for new `READY` evaluations and Need Generation requests. Merging
PANTRY-RDY-01 does not claim that runtime enforcement already exists.

PANTRY-RDY-02 may implement at most:

- one migration;
- zero new relations;
- zero public APIs;
- zero capabilities;
- zero roles or runtime roles;
- zero scope kinds;
- zero policies; and
- zero automatic source triggers.

Expected physical changes are limited to:

- three nullable Pantry binding columns on
  `atlas_planning.planning_input_evaluations`;
- one all-null-or-all-present constraint;
- one direct composite ownership foreign key;
- one supporting Pantry snapshot unique constraint when required;
- one leading binding index;
- issue-code and `input_type` extensions;
- amendments to the existing readiness guards; and
- in-place updates to the three existing canonical readiness pgTAP suites.

PANTRY-RDY-02 must not create a fourth readiness relation or a fourth
overlapping readiness test suite.

## Excluded authority

This decision creates no SQL, migration, database change, command, RPC, public
API, event, capability, role, runtime role, scope kind, policy, grant, generated
type, React behavior, package, hosted resource, production-data action, source
trigger, Pantry Purpose seed, Need Generation contribution, Confirmed Need,
Purchase Handoff, Procurement, Warehouse, Dispatch, Wholesale, OPS v1/v2, or
Retool mutation.
