# Decision — PA-05A supplier-direct command/RPC boundary

**Status:** Proposed with PA-05A  
**Date:** 2026-07-15  
**Related design:** `docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md`

## Context

PA-04 supplies the private supplier-direct schema foundation but no callable command or read API. Atlas needs a reviewed contract before SQL functions, grants, and client integration can be implemented.

## Decisions

1. PA-05A is contract design only; it implements no SQL, migration, policy, grant, or client connection.
2. `atlas_api` is the only future callable Atlas surface; domain schemas stay private.
3. Explicit business commands are preferred to CRUD functions.
4. Every authoritative write uses standard command, idempotency, result, and safe-error envelopes.
5. Server-side actor, capability, scope, delegation, and explicit management-override resolution are mandatory.
6. Read models are authorized and shaped for decisions; they are never write safety gates.
7. PA-05B is limited to the bounded evidence-to-delivery command subset and its helper/read contract.
8. React remains disconnected until command behavior and security/concurrency tests are implemented and reviewed.
9. Retool remains OPS v1/diagnostic support, not Atlas write authority.
10. Warehouse and school catering remain deferred; supplier-direct Slice 1 must not introduce their objects or behavior.

## Consequences

Future SQL functions have stable business names, shared replay/concurrency behavior, safe errors, and a clear source-owner boundary. The first implementation can prove the highest-risk evidence/load/departure/delivery invariants without silently expanding into Planning authoring, Procurement lifecycle breadth, Warehouse, or UI work.

## Rejected alternatives

- Direct domain-table CRUD from React.
- A broad admin or service-role API.
- A generic mutation function.
- Exposing all Atlas schemas to PostgREST.
- Implementing SQL before its behavior contract is approved.
- Treating reporting views as write safety gates.
- Combining Warehouse stock with supplier-direct Slice 1.

## Rollback effect

This decision and its related contract are documentation only. They create no database object, data, credential, deployment, or runtime behavior; rollback is a Git revert.

