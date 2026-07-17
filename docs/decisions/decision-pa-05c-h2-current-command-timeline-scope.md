# Decision — PA-05C-H2 Current Command Timeline Scope

**Status:** Approved; documentation prerequisite pending review and merge  
**Date:** 2026-07-17  
**Issue:** #102

## Context

PA-05C’s public audit-timeline design is fail-closed and remains valid. Its private aggregate-to-scope helper was written before PA-05D, PA-05E, PA-05F, and PA-05B-H3.

Merged commands now emit aggregate types the helper does not recognize. A full source-to-closure correlation therefore fails as unsupported, and upstream aggregates cannot yet resolve to the trip that currently contains their obligation.

PA-05G is acceptance-only and must not hide this read-contract gap.

## Decision

Implement PA-05C-H2 before PA-05G:

```text
replace the private aggregate-scope resolver
→ support the current explicit aggregate vocabulary
→ follow exact existing lineage to every current trip scope
→ retain unresolved and mixed-scope failure
```

No public function is added or changed. The API remains exactly 18 functions and the public read remains `PA-05C.v1`.

## Scope semantics

An upstream aggregate may use current authoritative relationships to resolve the destination and trip that now contains it.

- Before trip admission: customer/location with null trip is valid.
- After trip admission: return the linked trip tuple.
- Multiple linked tuples: return all and let the existing timeline reject ambiguity.
- Unknown aggregate type: remain unsupported.

Do not reconstruct historical authorization from event payloads, sample one tuple, or permit a mixed correlation merely because the caller has GLOBAL scope.

## Security

Reuse `atlas_read_runtime` with only required SELECT/USAGE and SELECT-only RLS additions. The private helper remains owner-hardened, static, fixed-search-path, and inaccessible to API roles.

No write, sequence, schema-CREATE, command-runtime, or direct API-role private access is allowed.

## Why this is separate

A passing PA-05G must prove existing commands and reads compose correctly. Fixing the resolver inside PA-05G would turn acceptance into implementation and make the result misleading.

Required order:

```text
PA-05C-H2
→ PA-05G
→ PA-06
```

## Rejected alternatives

- Skip the audit timeline in PA-05G — rejected because audit visibility is part of the approved backend boundary.
- Rename historical/current event aggregates — rejected as an unnecessary write-side change.
- Add a registry or generic graph engine — rejected as speculative persistence/abstraction.
- Authorize a sampled event — rejected because it recreates the PA-05C-H1 flaw.
- Broaden the public response — rejected; the current shape is sufficient.

## Consequences and limits

The complete current command path becomes readable through the existing API, including by matching trip-scoped actors when all aggregates belong to that trip.

The timeline remains capped at 100 events and still rejects correlations spanning multiple relational scopes. This is current-state relational authorization, not event-sourced historical authorization reconstruction.

No reporting search, export, pagination, UI, deployment, or production-readiness claim is added.