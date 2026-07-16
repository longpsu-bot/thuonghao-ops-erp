# Decision — PA-05B-H2 atomic multi-line Dispatch execution

**Status:** Proposed  
**Issue:** #91

## Decision

Before implementing PA-05F Dispatch plan/trip/stop setup, Atlas will correct the existing PA-05B Dispatch execution commands so one normal multi-line requirement can be loaded, departed, and successfully delivered without fixture-only assumptions.

PA-05B-H2 changes the request behavior of the existing functions only:

1. `confirm_dispatch_load`
2. `record_dispatch_departure`
3. `confirm_successful_delivery`

No public function, authoritative table, runtime role, or business domain is added. The reviewed Atlas API remains exactly 15 functions.

The revised Dispatch requests use `PA-05B-H2.v1`. The two Evidence commands continue to use `PA-05B.v1`.

## Why this correction is required

PA-05D and PA-05E now create multi-line authoritative records:

```text
Wholesale source lines
→ Dispatch Requirement lines
→ Fulfilment Allocation lines
→ supplier PO lines
→ Evidence applications
```

The current PA-05B execution path is one-line-shaped:

- load confirmation creates one load root with one line and then rejects another current load for the same trip/requirement/allocation;
- departure proves only that a stop has a confirmed load, not that every allocation line is fully loaded;
- successful delivery rejects a stop containing more than one confirmed load line.

Continuing to PA-05F without correcting this would create plan/trip/stop records for a backend that still could not execute the approved multi-line business contract.

## Atomic load decision

One `confirm_dispatch_load` command will create:

- one confirmed load root for one trip, stop, requirement revision, and allocation revision;
- every exact load line for that allocation;
- every exact load-to-evidence-application bridge;
- one receipt, one domain event, and one audit event.

The command must cover every current allocation line exactly once. Each loaded quantity must equal the authoritative allocated and required quantity. One load line may be supported by multiple valid evidence applications, but their submitted bridge quantities must reconcile exactly to the loaded quantity.

Partial, split, extra, missing, cross-wired, converted, rounded, or substituted loads remain excluded.

## Departure decision

Departure is a trip-wide command. It must independently prove:

- every stop is loaded;
- every selected requirement/allocation membership has one current confirmed load at its trip stop;
- every current allocation line has one exact load line;
- every load line remains fully supported by valid evidence and applications;
- no extra or cross-wired line exists;
- the actor is authorized for every stop scope, not only the first stop.

This closes the sampled-scope risk in the current departure implementation while preserving the existing trip command and capability.

## Atomic successful-delivery decision

One `confirm_successful_delivery` command will create:

- one valid delivery confirmation for one stop;
- one confirmation line for every current confirmed load line at that stop;
- one receipt, one domain event, and one audit event.

For the successful-only path, each delivered quantity and unit must exactly equal its load line. Return and exception quantities remain zero.

Partial delivery, failed delivery, returns, and delivery exceptions remain separate future work.

## Runtime decision

Retain `atlas_dispatch_command_runtime` as the `NOLOGIN`, `NOINHERIT` owner of the same three Dispatch execution functions.

The correction may add one private version-specific request validator and narrowly necessary read/lock privileges. It must add no Planning, Procurement, or Evidence mutation authority and no new runtime role.

## Simplicity decision

Use the existing PA-04 tables as designed:

```text
dispatch_loads
→ dispatch_load_lines
→ dispatch_load_line_applications

delivery_confirmations
→ delivery_confirmation_lines
```

Do not introduce a generic batch-command engine, workflow engine, load framework, delivery framework, repository abstraction, trigger, queue, job, or event-sourcing layer.

The complexity is justified by one immediate operational invariant:

> Every released and allocated line must be physically evidenced, loaded, transported, and successfully reconciled at destination.

## Rejected alternatives

### Continue to PA-05F first

Rejected because plan/trip/stop setup would not make the existing execution commands capable of processing a normal multi-line requirement.

### One command call per load line

Rejected because the existing unique load-root scope and trip/stop version transitions would make partial command completion ambiguous. A stop load is one atomic operational acceptance decision.

### One delivery confirmation per load line

Rejected because destination outcome is a stop-level business fact. A successful stop confirmation must reconcile all current load lines atomically.

### Keep both old and new payload shapes

Rejected because Atlas has no connected write client or live deployment depending on the old one-line shape. Two execution paths would increase security, testing, and maintenance complexity without preserving an actual operational dependency.

### Generic partial-load or partial-delivery support

Rejected because the first supplier-direct slice requires exact full-line loading and successful delivery. Exception and return handling need separate approved contracts.

## Consequences

Positive:

- PA-05D and PA-05E multi-line outputs can reach delivery through authoritative commands;
- load and delivery are atomic at their real operational boundaries;
- departure proves full coverage rather than mere load existence;
- multi-stop authorization fails closed;
- PA-05F and PA-05G can proceed against a coherent execution contract.

Trade-offs:

- old single-line Dispatch request payloads are no longer accepted;
- partial loading and delivery remain unavailable;
- the H2 migration and tests are substantial despite adding no public surface;
- structural concurrency proof remains based on locks and uniqueness rather than a new two-session test harness.

These trade-offs are accepted for the bounded supplier-direct backend slice.
