# Decision - PA-05C authorized read API boundary

**Status:** Proposed with PA-05C; pending review and merge

**Date:** 2026-07-15

**Related design:** `docs/architecture/pa-05c-authorized-read-api-wrappers.md`

## Context

PA-05B provides the first supplier-direct evidence-to-delivery write spine and a completed-path trace. Operators and future application screens need bounded readiness, blocker, and audit visibility without receiving direct access to private Atlas tables or reporting views. Issue #82 remains open and blocks broader write-command expansion.

## Decisions

1. PA-05C adds read-only API wrappers only.
2. `atlas_api` remains the only callable Atlas surface.
3. `atlas_read_runtime` owns PA-05C read functions.
4. `authenticated` can execute only reviewed Atlas API functions and has no direct domain-table access.
5. `anon` and `service_role` cannot execute Atlas API functions.
6. Read functions must reject empty, malformed, unsupported, unbounded, or ambiguous selectors.
7. Read functions are advisory and are not write safety gates.
8. Reads create no command receipts, domain events, audit events, tasks, workflow state, or domain mutations.
9. Issue #82 remains the gate before broader write-command expansion.
10. React remains disconnected.
11. A PA-05C selector must be authorized across every selected relational tuple before shaping; a mixed or unauthorized result set fails closed and must not be partially expanded from a sampled scope.

## Consequences

Operators and future React work receive stable, minimized JSON shapes for evidence readiness, bounded blockers, and command/audit timelines. Capability and relational-scope checks occur server-side before any result is shaped. Private tables and views remain inaccessible to API roles.

The read runtime receives minimum select-only privileges and policies. The command runtime receives no new privilege. PA-05C can therefore proceed before #82, while any broader write-command work remains blocked.

PA-06 may begin only as a separately reviewed read-only React connection after PA-05C review and explicit acceptance of the security posture. This decision does not authorize client integration or deployment.

## Rejected alternatives

- Direct table or view access from React.
- Exposing private reporting views directly.
- Unbounded list APIs.
- Using read models or readiness responses as command safety gates.
- Adding more write commands in PA-05C.
- Resolving runtime write-role hardening inside PA-05C.
- Connecting React before PA-05C review.
- Using Retool as hidden Atlas authority.

## Rollback effect

Before deployment, rollback is a Git revert of the PA-05C migration, tests, and documentation. This decision authorizes no hosted migration, production-data change, credential, or client deployment. A future deployed rollback would require a reviewed forward migration that removes only the callable read surface and its minimum read grants without deleting historical operational or audit data.
