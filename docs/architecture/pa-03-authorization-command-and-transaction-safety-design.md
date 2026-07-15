# PA-03 - Authorization, Command, and Transaction Safety Design

**Status:** Proposed architecture design; documentation only

**Scope:** Authorization, database access, RLS, grants, command execution, idempotency, concurrency, locking, isolation, safe errors, reporting, evidence-file access, integration, migration access, emergency access, and future security tests for the approved Atlas MVP

**Authority:** AGENTS.md, ARCH-001, ARCH-002, PA-01, PA-02, approved domain contracts and decisions, current in-memory command/read-model implementations, and operator reviews

**Companion decision:** `docs/decisions/decision-pa-03-security-and-command-boundaries.md`

**Next gate:** PA-04 first migration foundation only after the open gates in section 20 are approved

## 1. Executive summary

Atlas uses a private-domain, command-only write model. The browser authenticates with Supabase Auth and may call only reviewed functions in a dedicated `atlas_api` schema. It receives no table, sequence, domain-schema, audit-table, or storage-locator write privilege. Every authoritative command resolves the actor server-side, checks a server-owned capability and scope, validates expected versions and idempotency, re-reads safety-critical facts while holding deterministic locks, changes only the owning domain, and appends its audit/event evidence in the same transaction.

The trusted execution surfaces are narrowly owned database command functions, reviewed migration/reconciliation tooling, and separately approved server-side integration components. Browser payloads, JWT user metadata, delegated-actor claims, Retool parameters, uploaded files, integration payloads, and migration source rows remain untrusted until checked by the authoritative command.

Direct table writes are prohibited because grants and RLS alone cannot express Atlas's multi-row release, evidence, stock, departure, and reconciliation invariants. One command must either commit the entire business action and its audit evidence or expose no result. React remains an interaction coordinator and read-model consumer; it does not become an alternative state machine.

Final PA-03 decisions are:

- expose only a new interface schema, `atlas_api`, to the Supabase Data API; keep all ten PA-02 schemas unexposed;
- expose reviewed RPC-shaped command and read functions, not domain tables or writable views;
- use revoke-first privileges, separate no-login object-owner/runtime roles, and explicit function grants;
- resolve authorization from server-owned actor, membership, capability, scope, delegation, and approval records rather than user-editable JWT metadata;
- require idempotency and optimistic concurrency on every authoritative write command;
- use PostgreSQL `read committed` plus an explicit lock-first protocol as the default, with `serializable` only for a bounded command whose predicate cannot be protected by stable parent-row locks;
- use one global lock order across domains and retry the complete transaction only for classified transient concurrency failures;
- revalidate evidence, stock, allocation, departure, delivery, and closure gates in the write transaction;
- return a stable safe error envelope and retain SQL/internal diagnostics server-side;
- make Retool and management read-only by default; overrides are separate capabilities and commands;
- keep service-role/secret keys out of React and outside routine Atlas command execution.

Remaining pre-migration gates include the exact first-slice organization/site records, driver/offline delegation mechanism, evidence-file retention and scanning service, audit retention approval, exact command response schemas, the target Supabase project settings/runtime verification, and the executable first-slice acceptance fixture. These are listed in section 20.

PA-03 adds no SQL because privileges, policies, functions, and lock behavior must be reviewed as one security boundary before they enter irreversible migration history.

## 2. Trust-boundary model

| Surface / actor                  | Authentication source                                            | Authorization source                                                                  | Trusted input                                            | Untrusted input                                                                           | Allowed operation                                                           | Prohibited operation                                                                               | Audit requirement                                                   |
| -------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Browser / React                  | Supabase Auth session                                            | Advisory UI permissions only; database remains authoritative                          | Server response IDs, versions, capability summary        | Every form field, actor ID, scope ID, status, quantity, file reference, and retry request | Call allowlisted `atlas_api` functions; render returned read models         | Direct domain-table write, authoritative calculation, service/secret key, forged actor or owner ID | Source interface, correlation ID, client request ID on commands     |
| Authenticated human              | Supabase Auth subject                                            | Active application actor, membership, capability, scope, approval, and session checks | `auth.uid()` as authentication subject                   | JWT `user_metadata`, UI role labels, client-supplied capability/scope                     | Commands within active capability and scope                                 | Assume broad access from `authenticated` alone                                                     | Initiating actor, effective actor, capability, scope, command       |
| Delegated driver actor           | Valid assignment plus approved delegation mechanism              | Server-resolved trip/route delegation and narrow delegated capability                 | Server-issued assignment/delegation reference            | Client-selected driver ID, trip ID, or destination                                        | Submit assigned-trip departure/delivery/exception/return facts when enabled | Reassign trip, close unrelated exception, allocate, release stock                                  | Initiating human/system actor and delegated actor both retained     |
| Management approver              | Supabase Auth plus management membership                         | Separate approval/override capability and scoped approval record                      | Server-created approval request                          | UI claim that approval occurred                                                           | Approve explicitly eligible sensitive commands                              | Routine operational writes or invariant bypass                                                     | Approval request, approver, reason, expiry, command link            |
| System/integration actor         | Dedicated secret/OAuth/JWT identity in controlled server context | Narrow server-owned integration capability and source-system scope                    | Verified integration identity and registered source      | Payload, external IDs, timestamps, replayed request                                       | Allowlisted idempotent import/evidence commands                             | Shared service-role identity or broad table write                                                  | Source system, credential identity, request hash, rate-limit result |
| Supabase Auth                    | Supabase platform                                                | Authentication only                                                                   | Verified subject/session/MFA claims                      | User-editable profile metadata                                                            | Issue/validate sessions                                                     | Decide Atlas business capability by itself                                                         | Auth/security logs retained outside domain audit                    |
| PostgREST / Data API             | API key plus JWT mapping                                         | PostgreSQL schema/object grants and function checks                                   | Mapped `anon`/`authenticated` role                       | Route, body, headers                                                                      | Route to explicitly granted `atlas_api` functions                           | Reach unexposed domain schemas                                                                     | Gateway/request correlation where available                         |
| Database command function        | Function owner plus caller context                               | Server-side actor/capability/scope/approval checks                                    | Fully qualified internal objects, locked committed facts | All function arguments and JWT claims except authenticated subject                        | One reviewed command transaction                                            | Dynamic object selection, cross-domain ownership breach, partial success                           | Command receipt, event, audit in same transaction                   |
| Database tables                  | PostgreSQL roles, grants, RLS                                    | Domain ownership and restricted runtime roles                                         | Constraint-valid writes from reviewed commands           | Any direct API/client write                                                               | Persist owned facts and immutable history                                   | Become a public CRUD API                                                                           | DML attributable to command/actor where sensitive                   |
| Reporting views/functions        | Caller identity plus read runtime                                | Scope-filtered read contract                                                          | Committed authoritative facts                            | Caller filters, grouping, export request                                                  | Return shaped, column-minimized read models                                 | Bypass base RLS/scope or expose hidden commercial/contact data                                     | Sensitive export/read where policy requires                         |
| Storage                          | Supabase Storage/Auth when implemented                           | Attachment reservation and evidence ownership checks                                  | Server-issued upload intent and server-selected owner    | Filename, MIME claim, bytes, client-selected owner ID                                     | Private upload/read through short-lived signed access                       | Treat file presence as quantity evidence                                                           | Upload, checksum, scan, link, supersession, read/export             |
| Edge Function, if later used     | Supabase/server secret management                                | Same Atlas actor/capability command boundary                                          | Verified server environment and registered integration   | HTTP payload and headers                                                                  | Rate limit, validate transport, call narrow Atlas command                   | Reimplement domain transaction or hold service role in browser                                     | External request/response correlation and downstream command ID     |
| Retool diagnostic/support client | Dedicated human/integration identity                             | Read-only reporting capability                                                        | Reviewed reporting response                              | Component state, transformers, UI actor/scope                                             | Read allowlisted diagnostic/reporting functions                             | Domain-table write, broad service role, command execution by default                               | User, report, filters, export where sensitive                       |
| Migration/reconciliation tooling | Separate time-bounded database or server identity                | Approved batch, migration capability, environment, and command allowlist              | Reviewed extraction batch/checksum/mapping               | Legacy rows and inferred mappings                                                         | Stage, reconcile, call migration commands                                   | Direct production domain inserts or dual write                                                     | Batch, counts, checksums, rejects, actor, expiry                    |
| Service-role/secret credentials  | Supabase platform/server secret store                            | Platform-level privileged credential                                                  | Controlled backend process only                          | Any browser, repository, Retool page, log, or operator workstation                        | Exceptional separately approved platform task                               | Routine Atlas command execution or React exposure                                                  | Secret use and rotation outside ordinary domain audit               |

## 3. Actor and identity model

### 3.1 Server-owned identity records

PA-04 should add authorization infrastructure under `atlas_core` before business commands:

- `actors`: stable application actor identity and type (`HUMAN`, `DELEGATED_DRIVER`, `INTEGRATION`, `MIGRATION`, `EMERGENCY`);
- `actor_auth_subjects`: optional one-to-one active link from a human/integration actor to `auth.users.id` or another registered authentication subject;
- `roles` and `capabilities`: controlled authorization vocabulary, not a generic workflow engine;
- `actor_role_memberships` and optional direct `actor_capability_grants`;
- `actor_scopes`: organization, site, warehouse, or trip/route scope with effective period;
- `delegations`: initiating actor, delegated actor, allowed capability, trip/route scope, issuer, expiry, and revocation;
- `approval_authorizations`: command/request-specific approval, approver, reason, scope, expiry, and consumed command;
- `emergency_access_grants`: time-bounded exceptional capability and approval evidence.

Historical actors are deactivated, never deleted when referenced. `auth.users` is an authentication directory, not the audit identity record. The application actor remains stable when an account is deactivated, replaced, or no longer login-capable.

### 3.2 Resolution rules

1. A human command starts from `auth.uid()` and resolves one active application actor server-side.
2. Authorization never depends on `raw_user_meta_data`, a UI role, or an actor ID supplied by the caller. JWT application metadata may be a UI hint only because claims can be stale; sensitive commands use current database membership/scope state.
3. A delegated action resolves both `initiating_actor_id` and `delegated_actor_id`; audit/events retain both. The delegated actor must be currently assigned to the exact trip/route and capability.
4. A driver without a full authenticated account is a non-login actor. Submission occurs through an approved initiating actor or later server-validated one-time/offline delegation credential. The precise offline credential is a migration gate.
5. Integration and migration actors each have their own narrowly scoped identity. Shared `system` or service-role attribution is prohibited.
6. Management override is not a role flag on an ordinary command. It is a separate approval or override command whose authorization is linked to the resulting command.
7. Emergency access is time-bounded and deactivates automatically. It never changes the original source actor or business owner.
8. For high-risk commands, the function may require a current Supabase session and approved MFA assurance level after the first-slice authentication policy is confirmed.

## 4. Role and capability catalog

Roles are assignable bundles; capabilities remain the authoritative check. No role, including Admin, means "everything."

| Role                           | Readable domains / sensitive data                                                                | Executable capability families                                                              | Explicitly prohibited                                      | Override / correction authority                                            | Audit visibility                           | Assignment scope                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------ | --------------------------------- |
| Master-data administrator      | Admin references and downstream usage impact; supplier contact only if granted                   | School/location, ingredient/unit, supplier/eligibility, dish profile                        | Daily Planning, PO, evidence, stock, Dispatch              | Admin evidence correction; no operational invariant override               | Admin audit, cross-domain impact summaries | Organization or site              |
| Recipe administrator           | Dish/recipe/BOM and usage trace                                                                  | Recipe draft/version/line/change/release                                                    | Planning recalculation, QA/Production approval             | Recipe successor/change-set only                                           | Recipe audit and usage trace               | Organization                      |
| Planning operator              | Planning sources, readiness, generation, draft confirmation/handoff; downstream status read-only | Import/edit/validate, generate, draft adjustment/preparation                                | Supplier, PO, physical evidence, stock, trip/outcome       | Pre-release correction only                                                | Planning audit                             | Organization/site                 |
| Planning lead                  | Planning plus cross-domain impact summaries                                                      | Approve/release/reopen/revise Planning work                                                 | Procurement or physical fact mutation                      | Reasoned Planning post-release revision/destination override request       | Full Planning audit                        | Organization/site                 |
| Procurement operator           | Released Planning, suppliers/eligibility, Procurement; physical evidence read-only               | Assign, validate, draft PO, supplier response, allocate                                     | Planning quantity, physical evidence, stock, Dispatch      | Pre-release Procurement correction                                         | Procurement audit and relevant trace       | Organization/site                 |
| Procurement lead               | Procurement plus commitment/evidence impact                                                      | Approve/release/revise/cancel PO and allocation                                             | Source evidence manufacture or upstream mutation           | Released commitment revision/cancel                                        | Full Procurement audit                     | Organization/site                 |
| Warehouse receiving operator   | Released/confirmed PO snapshot, receiving scope                                                  | Session, observed line/discrepancy, receipt preparation                                     | PO change, Planning, Dispatch outcome                      | No released evidence void by default                                       | Receiving/evidence audit                   | Site/warehouse                    |
| Warehouse supervisor           | Warehouse receipt, stock, release, relevant upstream/downstream                                  | Release/correct receipt, reserve/pick/release, holds                                        | Supplier commercial or destination delivery decision       | Warehouse evidence correction, reversal/adjustment when separately granted | Full Warehouse audit                       | Warehouse                         |
| Dispatch operator              | Released requirement/allocation/evidence/location snapshots and Dispatch                         | Plan, assign, load, depart, stop outcome, exception/return, close                           | Allocation, source evidence, stock, PO, Planning           | Pre-departure Dispatch correction                                          | Dispatch audit and relevant trace          | Site/dispatch wave                |
| Dispatch supervisor            | Dispatch plus correction/override context                                                        | Correct/void eligible Dispatch evidence, approve exceptional closure where contract permits | Upstream or stock mutation                                 | Destination override approval and Dispatch-owned correction                | Full Dispatch audit                        | Site/dispatch wave                |
| Driver / delegated actor       | Assigned trip/stops; minimal contacts/instructions/evidence                                      | Delegated departure, delivery, exception, return submissions only when enabled              | Reassign, plan, close unrelated trip, any upstream command | None                                                                       | Own/assigned trip submissions              | Trip/route and time bounded       |
| Management read-only           | Broad operational summaries; commercial/contact columns only by separate capability              | None                                                                                        | All routine writes                                         | None                                                                       | Cross-domain summary/audit as granted      | Organization                      |
| Management override approver   | Same as management read plus approval context                                                    | Approve eligible override/correction request                                                | Direct source-owner edit or invariant bypass               | Approval only; source owner executes correction                            | Overrides/cancellations and linked audit   | Organization/site                 |
| Audit/security reviewer        | Audit, actor/grant history, integrity diagnostics; sensitive values minimized                    | Read/export audit; revoke access through separate security admin process                    | Domain mutation                                            | None                                                                       | Cross-domain security/audit                | Organization/environment          |
| Integration actor              | Declared source and command response only                                                        | Named idempotent import/evidence commands                                                   | Interactive UI/admin, broad reads/writes                   | Same supersession command as source owner                                  | Own command/event history                  | Source system + organization/site |
| Migration/reconciliation actor | Staging/mapping/reconciliation and approved target summaries                                     | Batch/stage/reconcile and named migration commands                                          | Normal runtime writes, post-expiry access                  | Batch rollback/correction through approved migration flow                  | Complete batch and command audit           | Environment + batch + time        |

## 5. Capability-to-command matrix

`Version` lists the authoritative concurrency token. `Idem` is mandatory for every row below. Every row forbids direct table writes.

| Command                         | Owner                                                                  | Required capability / optional approval                                                         | Scope and delegation                                           | Version / additional recheck                                  | Reason / audit                                      | Override                                         |
| ------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------ |
| Master-data activate/deactivate | Admin                                                                  | `admin.reference.status`; management approval only for protected high-impact override           | Organization/site; no delegation                               | Root expected version; downstream usage recheck               | Reason for deactivate/reactivate; before/after      | Future-use override only; no historical rewrite  |
| Recipe release/change           | Admin/Recipe                                                           | `admin.recipe.release`; optional recipe lead approval                                           | Organization; no driver delegation                             | Recipe/root and version; usage snapshot                       | Change set, actor, release audit                    | New version only                                 |
| ApproveConfirmedNeeds           | Planning                                                               | `planning.confirmed_need.approve`                                                               | Organization/site; human only                                  | Batch version, source generation revision                     | Adjustment reasons and approval snapshot            | No invariant bypass                              |
| Release Planning requirement    | Planning                                                               | `planning.requirement.release`; `planning.destination.override.approve` if inactive destination | Site/destination; human only                                   | Source batch/release versions and location state              | Override reason where used; full release audit      | Destination override only; immutable release     |
| Release Purchase Handoff        | Planning                                                               | `planning.handoff.release`                                                                      | Organization/site; human only                                  | Handoff and Confirmed Need versions                           | Release event/audit                                 | Forbidden                                        |
| Create/release PO               | Procurement                                                            | `procurement.po.draft` / `procurement.po.release`; optional lead approval                       | Organization/site; no driver delegation                        | Allocation, PO, eligibility, number-series state              | Release audit; reason for policy exception          | No demand/evidence override                      |
| Revise/cancel PO                | Procurement                                                            | `procurement.po.revise`; lead or management approval per commitment policy                      | Organization/site                                              | PO/root revision plus evidence/receiving impact               | Mandatory reason and impact acknowledgement         | Cannot rewrite prior release                     |
| Record supplier confirmation    | Procurement                                                            | `procurement.supplier_confirmation.record`                                                      | Organization/site or registered integration                    | PO version/revision                                           | Supplier reference, actor/source audit              | No physical evidence effect                      |
| Allocate fulfilment             | Procurement                                                            | `procurement.fulfilment.allocate`                                                               | Organization/site                                              | Requirement and allocation versions                           | Allocation event/audit                              | Cannot change Planning quantity                  |
| Revise fulfilment allocation    | Procurement                                                            | `procurement.fulfilment.revise`; lead approval after evidence exists                            | Organization/site                                              | Current allocation, evidence/load/departure validity          | Mandatory reason and affected owners                | Forbidden after unsafe execution; successor only |
| Record supplier evidence        | Evidence source                                                        | `evidence.supplier.record`                                                                      | Site/source process; integration allowed; no Procurement actor | Exact PO/allocation revisions and evidence/application locks  | Occurrence/source metadata; audit/event             | Source-owner supersession only                   |
| Confirm Warehouse receipt       | Warehouse                                                              | `warehouse.receipt.release`; supervisor for correction                                          | Warehouse/site                                                 | Session, PO revision, receipt, stock creation state           | Discrepancy/correction reason; audit/event          | No PO change                                     |
| Reserve/release Warehouse stock | Warehouse                                                              | `warehouse.stock.reserve` / `warehouse.stock.release`                                           | Warehouse                                                      | Allocation, stock position, reservation/pick/release versions | Handoff/release audit                               | No negative stock or held-stock bypass           |
| Evidence supersede/void         | Evidence source                                                        | `evidence.correct`; management co-approval after load confirmation                              | Source site/warehouse                                          | Evidence, applications, affected loads/trips                  | Mandatory reason, predecessor/successor, full audit | Cannot silently invalidate departed evidence     |
| Stock reversal/adjustment       | Warehouse                                                              | `warehouse.stock.adjust`; supervisor plus management approval for configured threshold          | Warehouse                                                      | Position/ledger/count/adjustment versions                     | Mandatory reason and approval                       | Compensating movement only; non-negativity holds |
| Create Dispatch plan            | Dispatch                                                               | `dispatch.plan.create`                                                                          | Site/wave                                                      | Exact requirement/allocation revisions                        | Plan snapshot audit                                 | Destination override must already exist          |
| Assign Dispatch trip            | Dispatch                                                               | `dispatch.trip.assign`                                                                          | Site/wave; driver is target, not caller authority              | Plan/trip versions and conflicting assignment check           | Assignment audit                                    | Forbidden for driver                             |
| Confirm load                    | Dispatch                                                               | `dispatch.load.confirm`                                                                         | Site/trip; no driver delegation by default                     | Trip, allocation, evidence/application, load versions         | Exact evidence application trace                    | Evidence sufficiency never overridden            |
| Record departure                | Dispatch or delegated driver                                           | `dispatch.trip.depart`; delegation allowed for exact assigned trip                              | Trip/time bounded                                              | Trip, stop, load, allocation, all current evidence            | Departure event/audit                               | Readiness never overridden                       |
| Confirm delivery                | Dispatch, destination actor, or delegated driver                       | `dispatch.delivery.confirm`                                                                     | Exact assigned stop/trip                                       | Trip/stop/load/outcome versions                               | Receiver/evidence and reconciliation audit          | Quantity reconciliation never overridden         |
| Record exception                | Dispatch or delegated driver                                           | `dispatch.exception.record`                                                                     | Exact assigned stop/trip                                       | Stop/load/outcome and existing exception versions             | Type/reason/evidence audit                          | No upstream mutation                             |
| Record return evidence          | Dispatch/return actor or delegated driver                              | `dispatch.return.record`                                                                        | Exact exception/trip                                           | Exception/load/outcome versions                               | Handoff metadata and audit                          | Never creates Warehouse stock                    |
| Close trip                      | Dispatch; supervisor approval for contract-allowed exceptional closure | `dispatch.trip.close`                                                                           | Site/trip; driver not eligible                                 | Trip/stops/outcomes/exceptions/evidence                       | Closure reason and audit                            | Unresolved outcome cannot be overridden          |
| Management override             | Management approval + owning-domain execution capability               | `management.override.approve` plus named domain capability                                      | Exact organization/site/object and expiry                      | Target versions and every normal invariant                    | Approval request, reason, approver, executor        | Only explicitly declared policy exceptions       |

## 6. Schema exposure and grants design

### 6.1 Data API exposure classification

| Schema                                | Data API classification                                     | Runtime direction                                                                                |
| ------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `atlas_api` (new interface namespace) | Exposed, functions only                                     | Reviewed command and read functions; no tables, views, sequences, or generic execute grant       |
| `atlas_core`                          | Never exposed; internal only                                | Authorization records, command receipts, numbering, attachment metadata                          |
| `atlas_admin`                         | Never exposed; command/write and reporting-read only        | Admin command runtime; shaped reference reads through `atlas_api`                                |
| `atlas_planning`                      | Never exposed; internal only                                | Planning commands and read models                                                                |
| `atlas_procurement`                   | Never exposed; internal only                                | Procurement commands and read models                                                             |
| `atlas_evidence`                      | Never exposed; internal only                                | Source-owner evidence commands and read models                                                   |
| `atlas_warehouse`                     | Never exposed; internal only                                | Warehouse commands and read models                                                               |
| `atlas_dispatch`                      | Never exposed; internal only                                | Dispatch commands and read models                                                                |
| `atlas_audit`                         | Never exposed; internal only                                | Append by commands; filtered audit read functions                                                |
| `atlas_reporting`                     | Never exposed initially; read-only internal views/functions | Security-invoker views and composed reporting logic consumed by scope-checking `atlas_api` reads |
| `atlas_legacy`                        | Never exposed; migration/admin only                         | Staging, mapping, reconciliation under time-bounded identities                                   |

This is stricter than exposing `atlas_reporting` directly. It keeps one auditable API namespace and allows later exposure only through a PA-03 amendment.

### 6.2 Role and ownership direction

- `atlas_object_owner`: no-login owner of Atlas schemas/tables/views; not used by runtime functions or clients.
- `atlas_command_runtime`: no-login owner of reviewed command entry functions; receives only exact table verbs needed by those functions, no `BYPASSRLS`, no role creation, no schema creation.
- `atlas_read_runtime`: no-login owner of scope-filtering read functions; receives only required `SELECT` privileges, no writes.
- `atlas_migration_role`: non-runtime role used only by reviewed migrations; creates/changes objects and sets ownership to the no-login owner.
- `atlas_reconciliation_role`: time-bounded migration tooling identity with staging and named migration-command access, not object ownership.
- Supabase `anon`: no Atlas schema usage, table, sequence, view, or function privilege.
- Supabase `authenticated`: `USAGE` on `atlas_api` and `EXECUTE` only on an explicit allowlist of functions. Capability checks still occur inside every call.
- `service_role`/secret key: no routine Atlas-specific grant and no use by React or Retool. Separately approved platform operations may use it outside the ordinary command path.

### 6.3 Revoke-first posture

Every migration must revoke `PUBLIC`, `anon`, `authenticated`, and `service_role` privileges on new Atlas schemas, tables, routines, and sequences before adding allowlisted grants. Default privileges must be set per object-creating role, not assumed from project defaults. `authenticated` receives no domain-table DML, no sequence access, no `CREATE`, and no domain-schema `USAGE`. Function creation and selective grants occur in one migration transaction so there is no public-execute window.

React therefore receives no direct read or write grant to authoritative tables. Read access is a function contract; write access is a command contract.

## 7. RLS policy design

RLS is defense in depth, not the primary write API. Enable and force RLS on every exposed or actor/scope-sensitive table and on private domain tables where command-runtime policies are practical. No permissive catch-all policy is allowed.

| Table family       | Select policy concept                                                                                                   | Insert/update/delete policy concept                                                                                      | Scope                                 |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------- |
| Authorization/core | Actor may read its own non-sensitive capability summary only through function; security reviewers read filtered records | Command/migration runtime only; membership/grant changes through security-admin commands; no delete of referenced actors | Organization and effective period     |
| Master data        | Active safe columns through shaped reads; sensitive supplier/contact fields require capability                          | Admin command runtime only; inactivate/successor instead of referenced-row delete                                        | Organization/site                     |
| Planning           | Planning scope plus downstream read of immutable release snapshots through shaped functions                             | Planning command runtime only; immutable revisions/snapshots not updated/deleted                                         | Organization/site/service scope       |
| Procurement        | Procurement scope; other domains receive only relevant snapshots/status                                                 | Procurement command runtime only                                                                                         | Organization/site/supplier visibility |
| Evidence           | Source owner and relevant downstream roles read minimal evidence/application state                                      | Exact source-owner command runtime only; append/supersede/void, never delete                                             | Organization/site/source/allocation   |
| Warehouse          | Warehouse scope; downstream sees released evidence only                                                                 | Warehouse command runtime only; ledger/released evidence append-only                                                     | Organization/warehouse                |
| Dispatch           | Dispatch site/wave; driver only assigned trip/stops; management filtered read                                           | Dispatch command runtime only; historical outcome rows never delete                                                      | Organization/site/trip                |
| Audit              | Source-domain actor may see relevant trace; audit reviewer broader filtered scope                                       | Audit append runtime only; no client insert/update/delete                                                                | Organization/domain/classification    |
| Reporting          | No authoritative table; caller receives scope/column-filtered results                                                   | No writes                                                                                                                | Derived from caller scope             |
| Legacy             | Migration/reconciliation reviewers only                                                                                 | Approved batch commands/tooling only; no runtime client                                                                  | Environment/batch/source system       |

Default rules:

- no policy based only on `TO authenticated`, a UI role, or a user-supplied actor/scope;
- no delete of released, evidence, audit, event, application, snapshot, or ledger records;
- no update of immutable revision/snapshot rows;
- no client insert into command receipt, event, or audit tables;
- write access remains denied even when read access exists;
- policy predicates use indexed actor/scope/assignment keys and server-owned membership records;
- authorization helpers live in an unexposed schema, use a fixed search path, and cannot be executed directly by public API roles.

## 8. Security-definer command design

Future entry functions use stable names in `atlas_api`, return one structured result, and may be `SECURITY DEFINER` only because callers have no domain-table privileges. The following requirements are mandatory:

1. Function owner is `atlas_command_runtime`, never a superuser, table owner, service role, or role with `BYPASSRLS`.
2. `search_path` is empty. Every table, view, function, type, operator-sensitive expression, and extension reference is schema-qualified. If implementation cannot use an empty path, the approved trusted schemas precede `pg_temp`, with no user-writable schema present.
3. Revoke `EXECUTE` from `PUBLIC`, `anon`, `authenticated`, and `service_role`, then grant only the allowlisted signature to `authenticated` or a named integration role.
4. Resolve the initiating actor from the authenticated subject. Validate actor active state, capability, scope, delegation, required approval, and sensitive-session requirements before data mutation.
5. Accept explicit business IDs, expected versions, idempotency key, client correlation ID, payload, and reason where required. Never accept a trusted actor ID, role, capability, schema, table, column, or function name from the caller.
6. Register/check idempotency and request hash before domain mutation.
7. Acquire locks in section 11 order, re-read authoritative state, validate lifecycle and cross-domain invariants, then write only the owning-domain records.
8. Append command receipt, domain event, and audit event in the same transaction. No asynchronous safety gate or best-effort audit append.
9. Return one structured success or safe failure. Never silently commit some lines and report partial success unless a separately approved batch contract explicitly defines per-line transactions.
10. Avoid dynamic SQL. Any future justified use must be limited to constant allowlisted identifiers, separately reviewed, and never use caller-controlled object names.

Threat controls:

| Threat                              | Required control                                                                                |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| Privilege escalation / forged actor | Server-side subject-to-actor resolution and capability/scope lookup; no trusted caller actor ID |
| Search-path hijack                  | Empty/fixed search path, fully qualified references, no untrusted schema in path                |
| SQL injection                       | Typed parameters, static SQL, no caller object names                                            |
| Stale write                         | Expected version and exact upstream revision checks under lock                                  |
| Duplicate/replay                    | Scoped idempotency key, canonical request hash, stored safe result                              |
| Cross-domain mutation               | Separate function ownership/grants and command review against ownership matrix                  |
| Forged source evidence              | Source-process capability, exact PO/allocation revision, occurrence/source checks               |
| Evidence over-application           | Lock evidence and allocation revision; transactional normalized sums                            |
| Concurrent stock allocation         | Lock allocation then stock positions/reservations in deterministic order                        |
| Stale departure readiness           | Re-read current valid evidence/applications while locks are held                                |

## 9. Idempotency design

All authoritative write commands require a UUID-like idempotency key. This uniform rule is simpler to audit than a mixed optional policy and protects browser double-clicks, network retries, offline submissions, integrations, releases, evidence, movements, and overrides.

### 9.1 Scope and state

The uniqueness scope is:

```text
environment
+ initiating_actor_id or integration_actor_id
+ command_name
+ aggregate_scope_id
+ idempotency_key
```

The command stores a canonical request hash over the command contract version and normalized payload, excluding volatile transport fields. The same key and hash returns the stored safe response and command ID. The same key with a different hash returns `IDEMPOTENCY_CONFLICT`.

- `IN_PROGRESS`: inserted and locked at transaction start but not committed as a durable partial state. A concurrent duplicate waits briefly; after the first commit it replays, and after rollback it may retry.
- `COMPLETED`: committed domain result and minimized response are replayable.
- `FAILED_NON_RETRYABLE`: deterministic authentication-after-subject, capability, validation, invariant, or stale-source failure may be committed as a safe error receipt when the function returns rather than raises. A corrected attempt uses a new key.
- transient database failure: no completed receipt is committed. The entire transaction is retried with the same key.

Failed validation is stored for 30 days to make duplicate user/integration behavior deterministic. SQLSTATE `40001` and `40P01`, connection loss before a known commit, and a narrowly classified concurrency-related unique/exclusion race are not stored as replayable failures; they are retried or reconciled by key.

### 9.2 Retention and clients

- Retain completed operational command receipts for 400 days by default; retain audit/events under the separately approved audit policy.
- Retain only response fields required for replay: command ID, affected IDs/versions, status, safe warnings/error, and correlation ID. Do not retain contacts, signed URLs, credentials, or full sensitive read models.
- After cleanup, retain a non-sensitive command/audit reference and key/hash tombstone when required to prevent unsafe reuse; exact retention needs product/legal approval.
- Browser: generate one key per intended action and reuse it only for retries of that exact payload. A changed form submission gets a new key.
- Integration: persist outbound key until a terminal response; retry with exponential backoff and the same payload/hash.
- Offline/delegated: key and payload are created together; server validates current delegation and occurrence policy at acceptance. Offline capture does not freeze authorization or evidence validity.

## 10. Optimistic concurrency design

Every mutable aggregate root has `version bigint`. A successful command that changes the root increments it once and returns the new version. A caller supplies `expected_version`; mismatch returns `STALE_VERSION` with current version when safe. Atlas never uses last-write-wins for operational aggregates.

Immutable revision creation checks the root/current revision version and creates a new revision; it never updates the released row. Child changes use the owning root version plus the child's exact stable/revision ID. Multi-root commands accept an explicit version set and fail atomically if any member is stale.

| Check class                            | Commands                                                                                                                            |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| One root                               | Master-data profile/status, Planning draft validation/approval, supplier confirmation, receiving-session edits, exception update    |
| Root plus exact upstream revision      | Planning requirement/handoff release, PO draft/release, Dispatch plan                                                               |
| Multiple roots                         | PO release from allocation, allocation revision with dependencies, Warehouse receipt plus stock creation, trip assignment with plan |
| Evidence validity/application revision | Supplier/Warehouse evidence, load, departure, evidence void/supersession                                                            |
| Stock position/reservation set         | Reserve, pick, release, movement, reversal/adjustment                                                                               |
| Trip/stop/load/outcome set             | Load, departure, delivery, exception/return, close trip                                                                             |

React handles `STALE_VERSION` by discarding authoritative cached action flags, refetching the read model, preserving unsent operator input separately, and requiring a new review/submit. It must not automatically overwrite or silently resubmit a changed operational aggregate.

## 11. Locking and transaction isolation

### 11.1 Baseline choice

Use PostgreSQL `read committed` plus explicit row locks and the parent-lock convention for the first migration. This is sufficient when every writer of a quantity or child collection locks the same stable parent row before reading sums or inserting children. Use `serializable` only for a bounded command that protects a business predicate with no stable lockable parent or whose complete conflict set cannot be known before writes. Such a function must document and test complete-transaction retry.

Transactions stay short: authentication/capability lookup, locks, validation, writes, audit, and result only. File upload, malware scanning, external supplier communication, notification, and user input occur outside the locked transaction.

### 11.2 Global lock order

Every command first determines the target IDs without trusting their state, then locks existing rows in this order; within one class, UUIDs are ascending:

1. command receipt and document-number series;
2. Admin reference rows required to prevent release against a concurrent deactivation;
3. Planning roots and exact released revisions;
4. Procurement allocation, PO, and exact line revisions;
5. Warehouse receipt, stock position/lot, reservation, pick, and release rows;
6. supplier/source evidence and evidence-application rows;
7. Dispatch plan, trip, stop, load, confirmation, exception, and return rows;
8. append audit/events after business validation.

No command may invent a local reverse order. Parent root is locked before its stable children. The first acquired lock uses the strongest row-lock mode the command will need.

### 11.3 Command-specific protocol

| Operation                        | Lock/revalidation protocol                                                                                                           | Isolation direction                                                          |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| Document number                  | Lock one series row, issue immutable number, retain gaps/voids                                                                       | Read committed                                                               |
| Planning release/handoff         | Lock source root/current revision, destination/reference rows, exact lines; recheck blockers/current version                         | Read committed                                                               |
| PO revision/release              | Lock allocation then PO root/current revision, eligibility and number series; recheck evidence/receiving impact                      | Read committed                                                               |
| Fulfilment allocation revision   | Lock requirement, current allocation/root/lines, then affected evidence/load rows; prior evidence never moves                        | Read committed; serializable only if unanchored allocation predicate remains |
| Evidence application             | Lock allocation line revision, then evidence source and existing valid applications; sum normalized quantities                       | Read committed with parent-lock convention                                   |
| Warehouse receipt/stock creation | Lock PO revision then session/receipt; create receipt, lot, position, and initial movement atomically                                | Read committed                                                               |
| Stock reservation                | Lock allocation, then stock positions in UUID order and active reservations; recompute available                                     | Read committed with stock-parent convention                                  |
| Pick/release/movement            | Lock allocation, reservations, stock positions, pick/release; recheck holds/expiry/quantity; append evidence/application/movement    | Read committed                                                               |
| Dispatch load                    | Lock allocation, Warehouse source rows where applicable, evidence/applications, then trip/load; recheck consumption                  | Read committed                                                               |
| Departure                        | Lock allocation, Warehouse evidence sources where applicable, evidence/applications, then trip/stops/loads; re-read current validity | Read committed                                                               |
| Delivery confirmation            | Lock trip, stop, load lines, current outcomes/exceptions in global class order; reconcile exact quantities                           | Read committed                                                               |
| Exception/return resolution      | Lock trip/stop/load, exception and current return/outcome rows; recheck unresolved quantity                                          | Read committed                                                               |
| Trip closure                     | Lock trip then all stops, loads, confirmations, exceptions, returns in sorted order; revalidate every outcome                        | Read committed                                                               |

Evidence void/supersession and departure use the same order. If void commits first, departure sees invalid evidence and blocks. If departure commits first, a void that would create a historical departure gap is rejected and must use the explicit post-departure correction/incident path. Exactly one safe outcome commits.

PostgreSQL concurrency failures map as follows:

- `40001` serialization failure: retryable, retry complete command with same idempotency key;
- `40P01` deadlock: retryable after logging the lock-order defect; maximum three total attempts with jitter;
- `23505`/`23P01`: retryable only when the violated constraint is explicitly classified as a concurrency race; otherwise deterministic conflict;
- lock/statement timeout: retryable only for an allowlisted command and before an unknown commit; otherwise safe failure/reconciliation.

Stale versions, insufficient stock/evidence, and invariant failures are never auto-retried as concurrency errors. No transaction exposes a released header without its lines, evidence without applications, receipt without approved stock effect, Warehouse release without movement, or command result without audit.

## 12. Structured error contract

Every function returns or maps to this stable envelope:

```text
error_code
message
domain
command_name
aggregate_id
current_version
expected_version
retryable
field_errors[]
blocker_references[]
correlation_id
command_id
safe_details
```

Operator-safe error families:

- `AUTHENTICATION_REQUIRED`, `CAPABILITY_DENIED`, `SCOPE_DENIED`;
- `STALE_VERSION`, `IDEMPOTENCY_CONFLICT`;
- `VALIDATION_FAILED`, `INVARIANT_VIOLATION`, `SOURCE_REVISION_STALE`;
- `EVIDENCE_INSUFFICIENT`, `EVIDENCE_VOIDED`, `EVIDENCE_OVER_APPLIED`;
- `STOCK_INSUFFICIENT`, `STOCK_CONFLICT`;
- `TRIP_NOT_READY`, `DEPARTURE_BLOCKED`;
- `DELIVERY_RECONCILIATION_FAILED`, `EXCEPTION_UNRESOLVED`;
- `DOCUMENT_NUMBER_CONFLICT`, `RETRYABLE_CONCURRENCY_FAILURE`, `INTERNAL_COMMAND_FAILURE`.

Messages explain the operator action without disclosing object internals. `field_errors` use public contract field names. `blocker_references` contain safe business references or opaque IDs the caller is already allowed to see. `safe_details` is an allowlisted object, not arbitrary exception text.

Server-only diagnostics retain SQLSTATE, constraint/function identifiers, stack trace, lock wait context, policy details, and internal object names correlated by command/correlation ID. Never return SQL text, table/policy names, credentials, signed URLs, raw JWTs, secret configuration, or stack traces.

## 13. Reporting-view security

`atlas_reporting` remains unexposed. Ordinary views should use `security_invoker = true` so they do not silently inherit creator privileges. Scope-checking `atlas_api` read functions may be `SECURITY DEFINER` under `atlas_read_runtime`, with empty search path, explicit actor/scope checks, minimal `SELECT`, and shaped return types. They must not rely on a definer view that bypasses base-table RLS.

| Read model                          | Required filtering / sensitive columns                                                          |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| Control Board / owner queue         | Organization/site and capability; derived owner is not editable; hide commercial/contact detail |
| Planning workbench                  | Planning scope; downstream status only; no supplier contact/price unless separately granted     |
| Procurement attention               | Procurement scope; supplier/contact/commercial columns capability-filtered; evidence read-only  |
| Warehouse receiving / Stock Release | Warehouse scope; exact PO/evidence trace; supplier commercial terms minimized                   |
| Dispatch morning control            | Site/trip; driver sees only assigned trips and minimum destination contact/instructions         |
| Operating-day trace                 | Scope intersection across all referenced facts; no unrestricted cross-tenant trace              |
| Audit timeline                      | Domain/organization scope and event classification; before/after sensitive values redacted      |
| Integrity diagnostics               | Audit/security or migration capability only; no public operator exposure                        |

Management read is broad only inside its organization and approved sensitivity class. Audit reviewers may see actor and privilege history but not automatically supplier commercial/contact details. Retool receives only explicitly approved diagnostic result sets. Aggregates must enforce a minimum cohort or suppress dimensions where a small group would reveal a sensitive supplier, actor, customer, or route fact. Export permission is separate from screen read permission.

## 14. Storage and evidence-file access design

No Storage object is implemented by PA-03. Direction for a later task:

- use private, environment-separated buckets; never public evidence buckets;
- create logical attachment metadata and an upload reservation before upload; the server selects the authoritative evidence owner ID and permitted purpose;
- issue short-lived, single-purpose signed upload/read access (target: 10 minutes, configurable) and never store a signed URL as durable metadata;
- allowlist content types, verify magic bytes, default maximum 10 MB per image and 25 MB per document unless an evidence contract approves otherwise;
- calculate server-verified checksum and byte size; quarantine until a future malware/security scan succeeds;
- link an attachment to immutable evidence only through the evidence-owner command after checksum/scan validation;
- correction creates new metadata/link and supersedes the prior link; do not overwrite the original object;
- offline capture records occurrence context locally but gains no authority until authenticated upload and command acceptance;
- prevent callers from selecting arbitrary evidence owner, actor, organization, trip, PO, or allocation IDs;
- retain under the evidence/audit retention policy, support legal hold, and physically delete only after retention, no references, no hold, and an audited deletion process.

File existence, a photo, or an upload receipt never proves an operational quantity. Quantity authority comes only from a valid source-owned evidence record and its transactionally constrained applications.

## 15. Integration and Retool access

Retool remains diagnostic/support tooling. Its default identity executes only allowlisted reporting functions and cannot execute business commands, use domain-table grants, or hold a service-role/secret key. A separately approved operational Retool use would still call the same Atlas command functions under the human actor's identity; it would not create another write path.

Each integration has one registered identity, source system, environment, capability allowlist, scope, rate limit, secret owner, rotation date, and revocation state. Imports are idempotent, carry explicit source-system and source-object references, and use the same validation/audit/supersession rules as human commands. Production and non-production identities/secrets are separate and cannot cross environments.

Edge Functions may later provide transport authentication, rate limiting, webhook verification, or offline upload coordination. They may not reimplement domain transactions. No integration uses the service role unless a separate security decision proves a platform operation cannot be performed with a narrower identity.

## 16. Migration and reconciliation access

- Extraction uses a read-only source identity and immutable batch metadata.
- Staging and mapping live in `atlas_legacy` under environment/batch scope.
- Mapping acceptance does not write domain tables. Approved migration commands create authoritative Atlas records with batch IDs, source references, idempotency, actor, snapshots, events, and audit.
- Direct production-domain insert is prohibited except a separately reviewed bootstrap operation in the migration itself; ordinary data import uses domain-owned migration commands.
- Every batch records counts, quantity totals where meaningful, source/target checksums, duplicates, rejected rows, mapping decisions, sample trace, and rollback criteria.
- Duplicate source rows are quarantined or explicitly resolved; they are not silently merged.
- Temporary privileges have start/expiry, approver, batch, environment, and automatic revocation. Post-migration verification confirms revocation.
- Only one system owns writes for a workflow at a time. Dual write is prohibited. Cutover, rollback window, and write-owner transfer require separate approval.

## 17. Emergency access and overrides

Emergency access is a distinct, time-bounded grant, not Admin. Default maximum duration is 60 minutes. It requires a named incident, reason, exact capability/scope, approving management/security actor, and automatic expiry. High-impact evidence void, stock adjustment, or destination override should require two-person approval when staffing permits; the executor cannot approve their own grant.

Emergency actions use the normal command and audit path and are reviewed after the incident. They may accelerate authorization but cannot bypass:

- evidence sufficiency or source ownership;
- stock non-negativity, holds, or quantity reconciliation;
- immutable released/evidence/ledger/audit history;
- Planning/Procurement/Warehouse/Dispatch ownership;
- delivery and trip outcome reconciliation;
- required audit/event creation.

If an operational invariant prevents the desired action, emergency handling creates an explicit correction, reversal, cancellation, exception, or compensating record. It never edits history in place.

## 18. Security and concurrency test plan

Future migrations/functions require database-level tests plus API integration tests. Minimum suite:

### Authentication, grants, and scope

- unauthenticated calls/read access denied; `anon` has no Atlas privileges;
- read-only and management read-only actors cannot execute routine writes;
- direct insert/update/delete/select against unexposed authoritative tables denied to API roles;
- Planning cannot mutate Procurement; Procurement cannot create source evidence; Warehouse cannot change PO; Dispatch cannot change allocation, evidence source, stock, or Planning;
- driver sees and acts only on the assigned active trip/stops;
- management override requires exact approval, reason, scope, and expiry;
- deactivated actor/membership/delegation is rejected immediately by server lookup;
- Retool diagnostic identity is read-only; migration privileges expire/revoke;
- frontend build contains no service-role or secret key.

### Domain/evidence invariants

- source owner can record evidence; unauthorized owner cannot;
- evidence cannot be over-applied or double-consumed;
- evidence supersession/void updates validity without deleting history;
- supplier-direct allocation requires no Warehouse release;
- warehouse allocation requires valid Warehouse evidence;
- Return Evidence creates no stock or movement;
- delivery quantities reconcile and unresolved exception blocks closure;
- direct writes to audit/event tables denied and command audit/event append is atomic.

### Idempotency/concurrency

- stale version fails with `STALE_VERSION` and no partial write;
- exact duplicate replays the original result/command ID;
- same key with different payload fails `IDEMPOTENCY_CONFLICT`;
- concurrent stock reservations cannot oversubscribe;
- concurrent evidence applications cannot exceed evidence or allocation quantity;
- concurrent document-number issuance is unique and retains gaps safely;
- concurrent departure versus evidence void permits one safe outcome only;
- concurrent trip closure versus exception/return update cannot close unresolved work;
- retryable serialization/deadlock failure retries the complete transaction at most three attempts.

### Function, RLS, and reporting hardening

- every definer function has empty/fixed safe `search_path`, fully qualified objects, non-owner/non-bypass runtime role, and no public execute;
- allowlisted `authenticated` function signatures only; overloads do not accidentally inherit grants;
- RLS policies use server-owned actor/scope and are tested for cross-organization/site/warehouse/trip access;
- reporting views/functions do not bypass RLS/scope or leak sensitive columns through aggregation/filtering;
- command failure does not expose SQL, constraint, policy, stack, or credential details.

## 19. First connected slice security subset

The supplier-direct wholesale Slice 1 proves the command boundary without Warehouse writes.

### Actors and capabilities

- Planning operator and lead: wholesale source review, Confirmed Need approval, Purchase Handoff and requirement release;
- Procurement operator and lead: fulfilment allocation, PO draft/release, supplier confirmation;
- supplier receiving/cross-dock actor: supplier evidence and application;
- Dispatch operator and optional delegated driver: plan, trip, load, departure, delivery;
- management read-only and audit/security reviewer;
- one migration/reconciliation actor for seed/reference setup only.

### Minimal API and reads

Expose `atlas_api` only. Allowlisted commands are the exact Slice 1 steps: approve Confirmed Need; release Purchase Handoff/Planning requirement; allocate fulfilment; create/release PO; record confirmation; record supplier evidence/application; create plan; assign trip; confirm load; depart; confirm delivery; record exception/return if the acceptance scenario includes them; close trip. Read functions cover Planning workbench, Procurement attention, Dispatch morning control, operating-day trace, audit timeline, and integrity diagnostics.

All domain schemas remain unexposed. `anon` receives nothing. `authenticated` receives explicit execute only. Supplier evidence capability is separate from Procurement. Warehouse tables/functions receive no Slice 1 write grant.

### Slice rules and tests

- every command uses an idempotency key and required root/upstream versions;
- lock order follows Procurement -> Evidence -> Dispatch for evidence/load/departure;
- supplier evidence/application sums are locked and rechecked;
- load and departure re-read current valid evidence; no Warehouse evidence is required;
- delivery reconciles to load and closure revalidates all outcomes;
- audit/events and command receipt commit atomically;
- tests prove cross-role denial, stale/idempotent behavior, evidence over-application prevention, evidence-void/departure race safety, supplier-direct path, no Warehouse writes, and no direct table access.

## 20. Open decisions before the first migration

| Topic                            | PA-03 position                                                                | Gate before PA-04 migration                                                                         |
| -------------------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Supabase schema exposure         | Resolve: expose `atlas_api` only; keep ten PA-02 schemas unexposed            | Verify target project Data API settings and PostgreSQL version; encode exposure/grants in migration |
| Function schema/grants           | Resolve: explicit allowlisted functions in `atlas_api`; revoke-first          | Approve exact function signatures/response types                                                    |
| Reporting view direction         | Resolve: internal `security_invoker` views; scope-checking API read functions | Verify target view/function behavior with executable tests                                          |
| Role/capability storage          | Resolve: relational server-owned actors/roles/capabilities/memberships/scopes | Approve initial seed vocabulary and security-admin ownership                                        |
| Organization/site scope          | Resolve model: organization baseline with optional site/warehouse/trip scope  | Supply exact first-slice organization, site, destination, and warehouse records                     |
| Driver identity                  | Resolve non-login actor plus dual attribution                                 | Choose online/offline delegation credential and session/MFA policy                                  |
| System/integration identity      | Resolve dedicated actor per integration/environment                           | Approve first integration, credential custody, rate limit, and revocation owner                     |
| Idempotency retention            | Recommend 400 days completed, 30 days deterministic failure                   | Product/legal/operations approval and cleanup/tombstone job design                                  |
| Locking/isolation                | Resolve read committed + global lock-first protocol; serializable exception   | Executable concurrency tests against exact SQL/query plans                                          |
| Evidence-file access             | Resolve private bucket/signed access/server-owned links                       | Choose bucket/path, scanner, MIME/size policy, retention/legal hold                                 |
| Audit retention                  | Append-only and access-filtered                                               | Approve duration, archive, legal hold, and sensitive redaction policy                               |
| Emergency access                 | Resolve time-bounded, approved, normal command path, no invariant bypass      | Name approvers, thresholds, MFA/dual-approval, alert/review procedure                               |
| First-slice actors/tests         | Resolve role families and mandatory scenarios in section 19                   | Approve named fixture actors, exact command sequence, quantities, and acceptance data               |
| Document numbering/time/rounding | Inherited PA-02 direction                                                     | Resolve exact PO/trip formats, service cutoff, unit rounding before affected commands migrate       |

Any unresolved row that affects Slice 1 becomes a blocking PA-03.x amendment; it is not left to implementation discretion.

## 21. Recommended next phase

If every Slice 1 gate in section 20 is approved, proceed to:

**PA-04 - First migration foundation for supplier-direct Slice 1.**

PA-04 should create only authorization/core infrastructure and the minimal supplier-direct wholesale tables, grants/RLS, reporting/read functions, command functions, database tests, seed vocabulary, and rollback/rehearsal notes required by section 19. It must not become a full-system migration.

If any material actor, scope, storage, retention, function-contract, or concurrency question remains, create a bounded **PA-03.x decision amendment** and approve it before migration.

## Security implications, migration, and rollback

This design reduces the intended attack surface but creates no executable security control. Security is unchanged until a separately approved migration implements and tests it.

PA-03 adds no migration, SQL file, PostgreSQL object, RLS policy, RPC, Edge Function, generated database type, Supabase client, backend code, credential, production-data operation, Retool change, React behavior, fixture, or domain command. Documentation rollback is a normal Git revert.

## Implementation-reference notes

Business authority remains the approved repository documents. Current platform direction was checked against official guidance:

- [Supabase - Securing your API](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase - Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase - Database Functions](https://supabase.com/docs/guides/database/functions)
- [Supabase - Using Custom Schemas](https://supabase.com/docs/guides/api/using-custom-schemas)
- [Supabase 2026 Data API exposure change](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically)
- [PostgreSQL - Transaction Isolation](https://www.postgresql.org/docs/17/transaction-iso.html)
- [PostgreSQL - Explicit Locking](https://www.postgresql.org/docs/17/explicit-locking.html)
- [PostgreSQL - Serialization Failure Handling](https://www.postgresql.org/docs/16/mvcc-serialization-failure-handling.html)
- [PostgreSQL - Writing `SECURITY DEFINER` functions safely](https://www.postgresql.org/docs/16/sql-createfunction.html)

These references do not override Atlas contracts and must be rechecked when PA-04 is authorized.
