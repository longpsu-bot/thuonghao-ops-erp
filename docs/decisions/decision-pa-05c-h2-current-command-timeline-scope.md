# Decision — PA-05C-H2 Current Command Timeline Scope

**Status:** Approved; documentation prerequisite pending review and merge

**Date:** 2026-07-17

**Issue:** #102

## Context

PA-05C implemented the bounded `get_command_audit_timeline` read before the current Planning, Procurement, Dispatch setup, and successful closure commands existed.

Its authorization design is correct: every selected aggregate must resolve to authoritative customer/location/trip scope; unresolved targets and correlations spanning multiple relational scopes fail closed.

The private resolver's aggregate vocabulary is stale. Current command events use CamelCase aggregate names and aggregate classes that the original helper does not support. Consequently an authorized operator cannot retrieve timelines produced by the current command surface, and PA-05G cannot verify a complete correlation without changing the read contract.

## Decision

Implement a narrow read-only compatibility amendment:

```text
PA-05C-H2
→ replace the private aggregate-to-scope resolver
→ support every aggregate type emitted by the current 18-function API
→ derive downstream trip scope for upstream aggregates when a trip exists
→ preserve strict unresolved/mixed-scope rejection
```

No public function is added. The API remains exactly 18 functions.

The existing `PA-05C.v1` request and response shape remains unchanged.

## Supported aggregate classes

The resolver will support the exact current names:

```text
WholesaleOrder
PurchaseHandoff
DispatchRequirement
FulfilmentAllocation
PurchaseOrder
SupplierReceivingEvidence
EvidenceApplication
DispatchPlan
DispatchTrip
DispatchLoad
DeliveryConfirmation
```

It will retain the originally supported uppercase aliases for backward-compatible tests and existing stored rows.

Unknown names remain unsupported. The implementation must not create a generic registry or automatically normalize arbitrary text.

## Canonical scope decision

An upstream aggregate's scope is not limited to the state that existed when its event was recorded. For read authorization, the resolver may follow current authoritative relationships to determine every destination and trip that now contains that aggregate's obligation.

This allows a completed one-trip correlation to resolve all Planning, Procurement, Evidence, and Dispatch event aggregates to the same customer/location/trip tuple.

When no trip exists, customer/location with a null trip remains valid.

When more than one tuple exists, the resolver returns all tuples and the existing timeline fails closed as ambiguous. It must not sample one relation.

## Security decision

Reuse `atlas_read_runtime` and forced RLS.

Only missing SELECT/USAGE and SELECT-only policies may be added. API roles receive no direct private access. No write, sequence, schema-CREATE, command-runtime membership, dynamic SQL, or new role is permitted.

## Why this is a prerequisite to PA-05G

PA-05G is an acceptance-only task. It must validate the existing command and read contracts, not patch them.

Without PA-05C-H2, actual current events such as `WholesaleOrder`, `FulfilmentAllocation`, `DispatchPlan`, and `DispatchTrip` fail the timeline resolver. Hiding that gap inside PA-05G would invalidate the acceptance result.

The sequence is therefore:

```text
PA-05C-H2 current command timeline scope
→ PA-05G command-authored backend acceptance
→ PA-06 React connection
```

## Rejected alternatives

### Weaken PA-05G by skipping the timeline

Rejected. Audit visibility is part of the approved backend boundary future operators and React must consume.

### Change event aggregate names

Rejected. The emitted names are current authoritative facts and changing historical writers would broaden the task.

### Add a generic aggregate registry

Rejected. The current bounded vocabulary is small and explicit. A registry adds persistence and administration without an operational invariant.

### Let the timeline authorize only one sampled event

Rejected. This recreates the PA-05C-H1 sampled-scope flaw.

### Permit multiple scopes when the actor is GLOBAL

Rejected for this amendment. The current public contract intentionally rejects correlations that are not one bounded relational context. Broader cross-scope reporting requires a separate decision.

## Consequences

Positive:

- current command events become readable through the existing authorized API;
- one complete same-trip correlation can be verified by PA-05G;
- trip-scoped operators can inspect the full history of that trip, including upstream aggregates currently admitted to it;
- unsupported and mixed-scope reads remain fail closed;
- no write-command or application complexity is introduced.

Limitations:

- timeline remains bounded to 100 shaped events;
- correlations spanning multiple customers, locations, or trips remain rejected;
- current relationships are used for scope resolution; the read is not an event-sourced historical authorization reconstruction;
- no new reporting search, pagination, export, or cross-trip analytics is added.

## Next gate

After PA-05C-H2 implementation is merged and verified, the PA-05G documentation prerequisite can be finalized and Codex can implement the command-authored acceptance suite.