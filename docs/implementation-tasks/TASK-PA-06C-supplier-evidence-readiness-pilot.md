# TASK-PA-06C — Supplier Evidence & Readiness Fixture-Context Pilot

**Status:** Implemented on the bounded task branch; draft PR #112 is open, unmerged, undeployed, and in a product/architecture correction cycle
**Starting `main` SHA:** `625deb6f3677092356202ab5337705c47e441373`
**Branch:** `task/pa-06c-supplier-evidence-readiness-pilot`
**Issue:** `#109`
**Draft PR:** `#112`
**Reviewed head:** `5c6c29e37bfe35c110d352668900373f7119a1ae`
**Correction head:** the commit containing this task-record update; its exact SHA and final workflow URLs are recorded in draft PR #112 after push because a commit cannot contain its own SHA

## Objective and authority

Deliver the first authenticated Atlas operator command pilot against one deterministic local supplier-direct lineage. The workbench lets the local synthetic operator inspect approved readiness/blocker reads, separately review and submit Record Evidence and Apply Evidence commands, refresh current context, and inspect receipt/domain/audit evidence.

The implementation follows PA-06A's browser connection contract, PA-05B's command envelopes, PA-05C's authorized reads, and PA-05C-H3's current command context. It adds no API function, migration, table, column, status, calculation, capability concept, runtime role, dependency, or production data path. The `atlas_api` registry remains exactly 18 functions.

## Bounded API subset

The feature adapter exposes exactly five reviewed functions:

1. `atlas_api.record_supplier_receiving_evidence`
2. `atlas_api.apply_supplier_evidence_to_allocation`
3. `atlas_api.get_dispatch_evidence_readiness`
4. `atlas_api.get_operator_blockers`
5. `atlas_api.get_command_audit_timeline`

Record Evidence receives the PA-05B command envelope and the exact PO-line, supplier, ingredient, unit, quantity, reference, and occurrence payload. Apply Evidence is a separate PA-05B command with the returned Evidence identity, exact allocation-line revision, unit, applied quantity, and occurrence time. Both take optimistic versions only from READ-02's authoritative `command_context`.

READ-02 is fixed to the fixture's `wholesale_order_line_revision_id`; READ-03 is fixed to its service date and delivery location; READ-04 takes only a command identity already produced by the reviewed interaction. The UI offers no arbitrary supplier, PO, allocation, customer, or source-line lookup.

## Deterministic local fixture

The fixture is deliberately outside migrations and automatic seed execution. It extends the PA-06B local subject with exactly the five required read/write capabilities and one delivery-location scope, then inserts a predetermined 10 kg lineage:

```text
wholesale source line
→ confirmed need and approval snapshot
→ purchase handoff
→ dispatch requirement
→ fulfilment allocation
→ released supplier Purchase Order
```

Every upsert uses a fixed ID and `ON CONFLICT (id) DO NOTHING`. A separate assertion validates identity, effective role/capabilities/scope, direct traceability, statuses, current revisions, versions, quantity/unit consistency, and the absence of Evidence before command acceptance. Applying the provisioning command twice must pass unchanged.

The UI always displays:

> Local only · synthetic fixture · non-production

It also states that no work queue, supplier/PO discovery, production connection, or automatic progression exists.

## Operator and command lifecycle

Atlas now owns one Auth-session hook and passes the same session controller to the connection panel and workbench. This preserves PA-06B sign-in/sign-out behavior while allowing one narrow `clearAuthorizedWorkbenchState()` helper to clear READ-02 readiness data/status, READ-03 blocker data/status, READ-04 timeline data/status, authoritative Evidence identity, both reviewed command identities, and both command outcomes on sign-out, expiry, authenticated-subject change, or an RPC Auth error. Non-secret Record and Apply draft fields remain for operator recovery. The workbench never mutates the parent Supabase Auth session.

Each command uses an explicit two-step interaction:

1. Review creates a complete command envelope, deep-copies it, serializes it, and deep-freezes it.
2. Submit invokes exactly one backend command with that frozen identity.

Editing any draft field invalidates the review, command ID, idempotency key, expected version, timestamp, and frozen payload. Record success exposes only the returned Evidence identity and enables the separate Apply review; it never submits Apply automatically. Every success refreshes READ-02 and READ-03 and loads READ-04 for the command.

There is no automatic command retry. `RETRYABLE_CONCURRENCY_FAILURE` and ambiguous transport results retain the frozen request and expose an explicit “Retry exact frozen request” action. A successful browser retry is represented neutrally as `exact_retry_result`: “An authoritative result was returned for the exact frozen request. No duplicate was created.” The UI does not claim whether that invocation was the first successful server execution or a stored replay because the current success envelope exposes no authoritative replay discriminant. The frozen retry still reuses the byte-equivalent serialized envelope, including the same command ID, correlation ID, idempotency key, expected version, requested time, reason fields, and payload. An ambiguous intent locks editing; an explicit successful approved-read refresh abandons that uncertain identity before a new review can be created. `STALE_VERSION` refreshes READ-02, clears the stale intent, preserves the draft and expected/actual diagnostic, and requires a new review with new command/idempotency identities and the refreshed root version. `CAPABILITY_DENIED`, `SCOPE_DENIED`, validation failures, invariant failures, session expiry, and internal failures remain distinct safe states.

## Readiness and audit presentation

READ-02 remains advisory. The workbench shows readiness quantity/status and its authoritative current Allocation and Purchase Order context without treating readiness or blockers as command permission. READ-03 observations are shown as derived blockers with safe public references only.

READ-04 is presented as three distinct record groups:

- command receipt summary;
- domain events;
- audit events.

The UI does not infer an authoritative outcome from a transport failure and does not render raw provider, SQL, token, key, stack, or private-table detail.

Every READ-02, READ-03, and READ-04 invocation captures an Auth identity containing the Auth status and authenticated subject ID. A result is ignored if that identity changes before completion. Independent readiness, blocker, and timeline request generations also prevent an older invocation from overwriting a newer authoritative refresh. Reauthentication keeps only the drafts, leaves reviewed identities/outcomes cleared, reloads fresh approved reads, and keeps review disabled until READ-02/READ-03 succeed. No cleared command is replayed automatically.

## Focused verification

Frontend verification covers:

- the exact five-function adapter and fixed selectors;
- deep immutability and serialized exact-retry identity;
- review invalidation on edit;
- one Record call, post-success reads, returned Evidence identity, and timeline;
- Apply gating and separate review/submit;
- stale refresh, draft preservation, and new identity/version;
- explicit-only concurrency and ambiguous transport retry;
- capability denial, complete authorization-state clearing, Auth-error clearing, and session-loss behavior;
- subject A-to-B clearing followed by fresh subject-B reads;
- late READ-02/READ-03/READ-04 suppression after Auth identity loss;
- browser-source prohibition of private `.from(...)` access and non-registry RPC calls;
- controlled Storybook states for initial, Record review/success, Apply review/completed, stale, denial, ambiguous transport, session expiry, and receipt/domain/audit timeline.

The local integration verifier performs a real PA-06B email/password sign-in, checks subject/session, executes the fixed initial reads, records 4 kg of Evidence, performs a backend-proven exact replay, applies 4 kg, performs a backend-proven exact replay, bumps only the local PO/Allocation roots to version 2, proves stale failures at retained version 1, refreshes through READ-02, submits new 6 kg Record/Apply intents at version 2, verifies 10 kg total applied with two traced Evidence rows, asserts command/event/audit records, signs out locally, and verifies no remaining session. Its replay wording remains valid because the verifier completes a known command, submits the same request again, and proves the same result with no duplicate authoritative record; those assertions were not weakened or changed by the browser correction.

The authoritative GitHub `Supabase Integration / Local Auth and RPC acceptance` job runs:

```text
clean local reset
→ PA-05G
→ PA-05C-H3
→ PA-06B identity twice and connection verification
→ PA-06C fixture twice
→ PA-06C command/read/stale/timeline/sign-out acceptance
→ unconditional disposable-stack cleanup
```

No hosted Supabase project, link, credential, merge, or deployment is part of this task.

## Local runbook

From the repository root, with the disposable local stack running:

```powershell
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/pa_05g_backend_end_to_end_acceptance.sql --local
pnpm exec supabase test db supabase/tests/pa_05c_h3_evidence_readiness_current_command_context.sql --local
pnpm local:auth:provision
pnpm local:pa06c:provision
pnpm local:pa06c:provision
pnpm local:pa06c:verify
```

For browser review, configure only the loopback API URL and browser-safe local publishable key described by PA-06B, run `pnpm dev`, sign in with the synthetic local credentials maintained by the provisioning script, and open **Supplier Evidence & Readiness**. Never copy a service-role or secret key into Vite configuration.

## Security review

- Browser code uses the existing publishable-key client and ordinary authenticated session only.
- `requested_by_auth_subject` is overwritten from `session.user.id` by the shared transport before every RPC.
- The feature adapter cannot name a private relation or any API outside its five-function subset.
- Backend capability, scope, optimistic version, idempotency, invariant, and audit controls remain authoritative.
- The local Admin key remains confined to PA-06B's loopback-only Auth provisioning process; PA-06C fixture provisioning uses the pinned local CLI and never prints a key.
- Both client and request calls disable built-in PostgREST retries. No retry wrapper, background retry, queue, cache, or auto-progression path exists.
- Session loss, subject change, and RPC Auth errors clear readiness, blockers, timeline, reviewed identities, responses, and Evidence identity. Late authorized reads cannot repopulate cleared state. Drafts contain no credential or token.

## Simplicity inventory

| Addition                                      | Why needed                                                               | Narrow boundary                                      | Removal trigger                                                                |
| --------------------------------------------- | ------------------------------------------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------ |
| One fixture manifest and four local SQL files | Deterministic local lineage, stale mutation, and assertions              | Local-only; no migration/seed/production path        | Replace when an approved reusable non-production fixture owns this lineage     |
| One five-function feature adapter             | Prevent arbitrary use of the broader 18-function transport               | Two commands and three reads only                    | Replace if an approved generated feature client enforces the same subset       |
| One command-intent reducer                    | Make review/freeze/retry/stale/session transitions explicit and testable | Two commands share one small state machine           | Remove when a platform command-intent primitive provides equivalent guarantees |
| One workbench and route entry                 | First bounded operator pilot                                             | One predetermined source lineage; no discovery/queue | Remove or expand only through an approved operator-workflow task               |
| Focused tests and controlled stories          | Prove safety states without a hosted backend                             | Co-located with the feature                          | Remove with the corresponding behavior                                         |
| Two local Node scripts and CI steps           | Repeatable provisioning and real Auth/RPC acceptance                     | Loopback/pinned CLI/disposable stack only            | Replace when repository acceptance tooling supplies an equivalent flow         |

No Context provider, router, query/cache library, form framework, retry library, dependency, database helper, migration, or new backend behavior was added.

## Files, rollback, and limitations

- Feature code/tests/stories: `src/modules/atlas/evidence/`.
- Shared session/shell integration: `src/modules/atlas/AtlasApp.tsx`, `src/modules/atlas/atlasConfig.ts`, `src/modules/atlas/connection/`, and `src/styles.css`.
- Local fixture/assertions: `supabase/local/pa_06c_*.sql`.
- Local commands: `scripts/provision-local-pa06c-fixture.mjs` and `scripts/verify-local-pa06c-supplier-evidence.mjs`.
- Tooling/acceptance: `package.json` and `.github/workflows/supabase-integration.yml`.
- Evidence and runbook: this document.

There is no migration or production-data rollback. Code rollback is a revert of the PA-06C commit. Local data is disposable and removed by the next clean reset or `supabase stop --no-backup`.

The pilot supports only one fixture lineage and direct supplier Evidence/application. It does not discover work, select another supplier/PO, create planning/procurement/dispatch objects, progress status automatically, receive warehouse stock, release documents, or operate against a hosted/production environment. A discovery queue is explicitly deferred to a separate approved task; PA-06C creates neither hidden discovery nor queue state. Product/architecture review requested the bounded authorization-state and exact-retry corrections recorded above. Passing post-correction GitHub Actions and product/architecture acceptance remain required before the draft PR can be considered ready; merge and deployment are explicitly excluded.

## Validation evidence

Local frontend evidence on 2026-07-18:

- canonical workspace, origin, task branch, and starting `origin/main` were verified before editing;
- `pnpm ops:workspace` passed on the bounded task branch;
- `pnpm install --frozen-lockfile` was already current;
- formatting and typecheck passed;
- the original focused Evidence/security/session pass completed 5 files and 47 tests; the product/architecture correction pass completes 5 files and 51 tests;
- the correction's one-time full Vitest run completed 41 files and 265 tests;
- the application build and Storybook build passed, including the controlled PA-06C story bundle;
- `git diff --check` passed;
- the existing non-blocking Vite/Storybook chunk-size and Storybook plugin-timing advisories remain unchanged.

The Windows disposable-stack attempt applied every migration and started PostgREST 14.14 against PostgreSQL 17.6. PostgREST loaded exactly 18 RPCs. The already-documented local Kong failure then recurred: Kong became unhealthy and loopback port 54321 refused the readiness probe, after which the CLI stopped the containers. No health-check bypass, direct PostgREST fallback, generated-container edit, hosted project, or additional database behavior was used. Consequently the PA-06C fixture/RPC verifier was not run on that Windows stack; the draft PR's disposable Linux `Supabase Integration` job is the authoritative reset, pgTAP, fixture, Auth, command, stale-recovery, timeline, and sign-out environment.

Draft PR #112 was published at reviewed head `5c6c29e37bfe35c110d352668900373f7119a1ae`. Its authoritative reviewed-head workflows all passed:

- `Frontend CI / Format, typecheck, test, build`: run `29648507130`, job `88090713973`;
- `UI Review Export / Build UI review artifact`: run `29648507142`, job `88090713993`;
- `Qodana`: run `29648507154`, job `88090713778`;
- `Supabase Integration / Local Auth and RPC acceptance`: run `29648507171`, job `88090713903`.

The Qodana reviewed-head report contained two PA-06C `Unused local symbol` warnings. Both were unused local `api` bindings in `SupplierEvidenceReadinessWorkbench.test.tsx`; they are removed in this correction. A strict TypeScript unused-symbol inspection now reports no PA-06C finding. Unrelated pre-existing Admin and Warehouse unused-symbol findings were not changed.

The correction commit SHA, corrected final branch head, and authoritative post-correction workflow URLs/states are recorded in the final draft PR #112 body after the correction push. Local frozen installation, workspace verification, formatting, typecheck, 41-file/265-test Vitest run, application build, Storybook build, and `git diff --check` all passed. PR #112 remains draft, unmerged, and undeployed. Merge and deployment remain excluded.
