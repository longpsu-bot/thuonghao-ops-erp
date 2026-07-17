# Decision — PA-05G Command-Authored Backend Acceptance

**Status:** Implemented; 82-assertion focused local acceptance passes; pending review and merge
**Date:** 2026-07-17  
**Issue:** #100  
**Prerequisite:** PA-05C-H2 merged in PR #104 at `649cb953218bfaea401309c0520c49bbce1ced3b`

## Context

The merged backend contains the complete supplier-direct source-to-successful-trip-closure write path and four authorized reads.

Individual suites prove bounded contracts. Before React connects, Atlas needs one independent result showing that those contracts compose into a complete operating journey without direct operational fixtures.

Preparation found one read-only prerequisite: PA-05C’s private audit-timeline scope resolver predated current aggregate types. PA-05C-H2 resolved that gap without changing the public timeline contract, and Issue #102 is closed.

## Decision

PA-05G will be acceptance-only:

```text
one rolled-back two-line/two-supplier pgTAP journey
→ all 14 command types
→ all four authorized reads
→ exact authoritative reconciliation
```

It will not add or change business behavior, migrations, functions, security, dependencies, or application code. The API remains exactly 18 functions.

Required sequence:

```text
PA-05C-H2 merged
→ PA-05G documentation merged
→ PA-05G acceptance implemented and reviewed
→ PA-06 React connection planning
```

## Scenario choice

Use two ingredients and two suppliers, producing two POs and two Evidence/application pairs before one atomic multi-line load and delivery.

This is stronger than a one-line smoke test but avoids unrelated multi-customer, multi-date, Warehouse, mixed-source, exception, and return complexity.

Core/Admin fixture setup is allowed because those administration commands are outside Slice 1. All operational facts must be command-authored.

## Acceptance threshold

PA-05G passes only when it proves:

- every command type participates in a 17-execution journey under one correlation;
- exact identity, quantity, unit, supplier, destination, date, revision, version, and status lineage;
- successful delivery and trip closure;
- exactly 17 completed receipts, events, and audits;
- both traces, readiness, blockers, and the complete safe timeline work without side effects;
- the 18-function execute/direct-access boundary remains intact.

## Stop rule

A failing acceptance path is evidence of a predecessor defect. PA-05G must stop, document it, and create a separate bounded issue rather than patching the backend.

## Rejected alternatives

- Add a source-to-closure mega-command — violates domain and transaction boundaries.
- Let React discover integration gaps — PA-06 should consume a proven backend.
- Use direct operational fixtures — proves insertability, not command usability.
- Repeat every predecessor negative test — duplicates contract suites.
- Add a generic acceptance framework — not justified by one bounded scenario.
- Skip the timeline — audit visibility is part of the approved backend boundary.

## Consequences and limits

A passing PA-05G unblocks PA-06 planning and provides a durable example of the IDs and versions a client must carry.

It does not prove hosted deployment, Auth provisioning, production reference data, operator usability, React/Vercel integration, performance, observability, backup/rollback, Warehouse, mixed fulfilment, exception/return, Finance, or Production/QA.

## Observed outcome

The rolled-back suite at `supabase/tests/pa_05g_backend_end_to_end_acceptance.sql` passes 82 focused assertions after a clean local reset. All 17 command executions succeed under one correlation and reconcile to 17 completed receipts, 17 domain events, and 17 audit events. The four authorized read function types return the complete safe terminal path without domain mutation, and the API remains exactly 18 functions with no direct private access for API roles.

No predecessor defect or contract deviation was found. PA-06 is unblocked for planning only after this acceptance change is reviewed and merged.
