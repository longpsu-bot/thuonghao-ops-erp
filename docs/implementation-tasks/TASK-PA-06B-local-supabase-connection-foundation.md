# TASK-PA-06B — Local Supabase Application Connection Foundation

**Status:** Implemented; local browser integration blocked by the machine's restarting Kong container  
**Starting `main` SHA:** `c3ed56bb34e10f6d24cab0c77211905c35a0b6f2`  
**Branch:** `task/pa-06b-local-supabase-connection-foundation`

## 1. Starting inspection and work log

- Frontend dependency baseline: React `19.2.7` and React DOM `19.2.7` are the only runtime dependencies. The toolchain is Node 24, pnpm 11.7.0, Vite 8.1.4, TypeScript 7.0.2, Vitest 4.1.10, Testing Library 16.3.2, and Storybook 10.5.0.
- Local Supabase ports: API `54321`, PostgreSQL `54322`, Studio `54323`, Inbucket `54324`, pooler `54329` (disabled), and PostgreSQL major 17.
- Local Data API schemas: `atlas_api` is the configured exposed schema; `public` and `extensions` are only on the extra search path.
- Local Auth URL configuration: `site_url` is `http://127.0.0.1:3000`; the current additional redirect is incorrectly HTTPS at `https://127.0.0.1:3000`; Vite has no explicit port before PA-06B.
- Actor/Auth mapping: `atlas_core.actor_auth_subjects` maps one active Supabase Auth subject UUID to an active Atlas actor. Backend helpers resolve the JWT subject, require it to match `requested_by_auth_subject`, then enforce actor status, capability, and relational scope.
- Existing synthetic fixtures: pgTAP suites insert deterministic Atlas actors, subject mappings, capabilities, roles, and scopes inside rolled-back database tests. They do not provision a login-capable local `auth.users` identity.
- Expected changes: `package.json`, `pnpm-lock.yaml`, `.gitignore`, `.env.example`, `vite.config.ts`, `supabase/config.toml`, narrowly scoped connection modules and tests under `src/modules/atlas/connection/`, the Atlas shell and styles, one deterministic local-only identity provisioning file or script, and this implementation record.
- Starting evidence: canonical checkout and remote verified; working tree was clean; the task branch was created directly from fetched `origin/main`; `pnpm ops:workspace` passed; Supabase CLI 2.75.0 and Docker CLI 29.2.1 are installed.
- Contradictions/stop conditions: the HTTP/HTTPS Vite/Auth redirect mismatch was corrected. No architecture contradiction, missing PA-06A document, missing reviewed function, private-table frontend requirement, hosted dependency, or unapproved business concept was found.

## 2. Implementation plan

1. Pin the current supported `@supabase/supabase-js` package and align Vite/Auth local URLs on HTTP port 3000.
2. Add central browser-safe environment validation and a single guarded Supabase browser client.
3. Add one local Auth session hook and a minimal local connection panel. The hook is required because initial session loading, Auth events, expiry, sign-out cleanup, and subscription cleanup are unsafe to duplicate in component callbacks. React state/effects already solve the need, so no Context or external state container is justified.
4. Add one typed `atlas_api` RPC adapter with the exact 18-function compile-time allowlist and distinct configuration, Auth, transport, and safe backend outcome categories.
5. Add deterministic synthetic local identity provisioning without enabling broad automatic seed execution, plus a separately runnable sign-in/sign-out verification.
6. Add focused environment, Auth, UI, transport, and static security tests; run focused checks, then applicable local Supabase reset/pgTAP/Auth integration checks.
7. Complete this record with the security review, simplicity inventory, rollback, evidence, limitations, and the exact PA-06C gate.

## 3. Delivered operator capability

PA-06B delivers one bounded, non-production connection path:

- load a local browser-safe Supabase configuration;
- initialize one guarded browser client;
- sign in with a synthetic local email/password identity;
- derive the authoritative Auth subject from `session.user.id`;
- display only the local email and Auth subject;
- track initial session load, Auth events, expiry, and local sign-out;
- clear connection state on sign-out or expiry;
- expose a reviewed transport for the 18 PA-06A `atlas_api` functions.

No business workflow, command form, automatic RPC call, hosted environment, production identity, or production data path is connected. The panel says this explicitly.

## 4. Browser environment and local URL contract

Only these variables are accepted by browser code:

```dotenv
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_PUBLISHABLE_KEY=<local publishable key>
```

The checked-in `.env.example` contains only a placeholder key. `.env`, `.env.local`, and mode-specific local env files are ignored. The validator rejects missing values, malformed URLs, embedded URL credentials, and non-local hosts without echoing the supplied value. A client is not initialized after validation failure.

Vite, Supabase Auth `site_url`, and the allowed redirect now agree on `http://127.0.0.1:3000`. Vite uses a strict port so a silent port change cannot invalidate the Auth redirect contract. Existing local service ports remain API `54321`, database `54322`, Studio `54323`, Inbucket `54324`, and disabled pooler `54329`. Optional Analytics is disabled because it is not part of this foundation.

The only new runtime package is `@supabase/supabase-js` `2.110.7`, pinned exactly. It supplies the supported browser client and Auth lifecycle instead of recreating token storage, refresh, or event behavior.

## 5. Auth and session behavior

The session hook subscribes once per configured client, reads the initial session, and unsubscribes on cleanup. It represents configuration error, loading, unauthenticated, authenticated, and expired states explicitly.

`session.user.id` is the sole browser source for `requested_by_auth_subject`. Caller input with that name is overwritten immediately before each RPC. Tokens and raw Auth errors are never rendered or logged. Sign-out uses local scope. Sign-out, expiry, a failed session read, and an unexpected `SIGNED_OUT` event clear the password and any caller-owned connection state. Expiry does not replay a command: the operator must sign in, review, and create a new command intent.

## 6. Reviewed RPC transport boundary

The adapter accepts exactly these fully qualified names and maps them to Supabase's separate schema/function call convention:

1. `atlas_api.record_wholesale_source`
2. `atlas_api.release_wholesale_order`
3. `atlas_api.release_purchase_handoff`
4. `atlas_api.release_dispatch_requirement`
5. `atlas_api.allocate_supplier_direct_fulfilment`
6. `atlas_api.release_supplier_purchase_order`
7. `atlas_api.record_supplier_receiving_evidence`
8. `atlas_api.apply_supplier_evidence_to_allocation`
9. `atlas_api.create_dispatch_plan`
10. `atlas_api.create_or_assign_dispatch_trip`
11. `atlas_api.confirm_dispatch_load`
12. `atlas_api.record_dispatch_departure`
13. `atlas_api.confirm_successful_delivery`
14. `atlas_api.close_successful_trip`
15. `atlas_api.get_supplier_direct_trace`
16. `atlas_api.get_dispatch_evidence_readiness`
17. `atlas_api.get_operator_blockers`
18. `atlas_api.get_command_audit_timeline`

At runtime the call is `client.schema("atlas_api").rpc(functionName, { request })`. Arbitrary names are rejected before a session or network call. The adapter reads the current session for every invocation and rejects absent or expired sessions.

Success envelopes are preserved. Backend-safe failure fields are copied from an allowlist, including error code, safe message, correlation/command identifiers, retryability, field errors, blocking references, and expected/actual versions. Client/Auth/transport diagnostics are distinct and safe. Transport calls are never retried automatically, so an ambiguous command outcome cannot be duplicated.

Browser security tests prohibit service-role variables, hosted Supabase references, private-table `.from(...)` access, and non-registry RPC calls in the connection source.

## 7. Synthetic local identity

`pnpm local:auth:provision` creates or updates one deterministic local-only Auth user through the local Admin API, then applies the Atlas actor mapping through the local database container. It refuses a non-loopback API URL, does not log a secret or token, and keeps the local Admin key in process memory only.

Synthetic identity:

- email: `atlas.pa06b.operator@local.test`;
- Auth subject: `b6000000-0000-0000-0000-000000000101`;
- active Atlas actor: `PA-06B Synthetic Local Operator`;
- capability: `operator_blockers.read` only;
- scope: one synthetic customer only.

The SQL is intentionally outside automatic global seed execution. It is idempotent and was applied twice successfully against the local database. Provision it only after database tests, because the pgTAP fixtures intentionally create some of the same synthetic authorization concepts inside transactions.

`pnpm local:connection:verify` signs in with the deterministic identity, verifies the subject, signs out locally, and verifies that no session remains. It does not issue any business RPC or write.

## 8. Local runbook

From the repository root:

```powershell
supabase start
supabase db reset --local --no-seed
supabase test db supabase/tests/pa_05g_backend_end_to_end_acceptance.sql
pnpm local:auth:provision
supabase status -o env
```

Copy only the local API URL and local publishable key from the final command into an ignored `.env.local`; do not copy a secret/service-role key. Then run:

```powershell
pnpm dev
pnpm local:connection:verify
```

Open `http://127.0.0.1:3000`, use the synthetic credentials maintained in the local provisioning script, confirm the displayed subject, and sign out. Stop and remove the disposable local stack when finished:

```powershell
supabase stop --no-backup
```

## 9. Validation evidence and machine limitation

Verified during implementation:

- `pnpm ops:workspace` passed on the required task branch and canonical remote;
- `pnpm install --frozen-lockfile` passed with the lockfile unchanged;
- `pnpm format` passed for all repository targets plus every new PA-06B source, script, and task-record file;
- `pnpm typecheck` passed;
- `pnpm test` passed 37 files and 218 tests;
- `pnpm build` passed; Vite reported the existing advisory for a chunk over 500 kB after adding the Supabase client;
- `pnpm build-storybook` passed, with the same non-failing chunk-size advisory;
- `git diff --check` passed;
- clean `supabase db reset --local --no-seed` applied all 10 migrations through PA-05C-H2;
- focused `supabase test db supabase/tests/pa_05g_backend_end_to_end_acceptance.sql` passed 82 tests, including the 18-function boundary and all 17 command executions;
- PostgREST loaded exactly 18 functions from the exposed schema;
- the synthetic Atlas mapping SQL succeeded twice unchanged;
- static inspection found no service-role browser variable, hosted Supabase project URL, or private-table `.from(...)` access in the connection implementation.

The full historical pgTAP directory does not currently pass as one batch on `main`: earlier PA-04 tests expect 15 API functions and PA-05D/PA-05E tests expect 17, while the approved PA-06A surface has 18. Running the synthetic mapping before the full historical suite also collides with fixture capability codes. PA-06B does not weaken or rewrite those earlier backend acceptance expectations; the current PA-05G end-to-end suite was reset and rerun successfully before provisioning.

On this Windows/Docker installation, a fresh local start applied migrations and left database, Auth, Inbucket, and PostgREST running, but `supabase_kong_thuonghao-ops-erp` repeatedly exited with status 0 and restarted. Port `54321` therefore refused connections. The real browser sign-in/sign-out verification and UI-to-Auth check could not complete on this machine. `pnpm local:auth:provision` also stopped safely because CLI status was unhealthy; no hosted fallback was attempted. This is an external local-stack limitation, not a passed acceptance result.

## 10. Simplicity inventory

| Addition                            | Why needed                                                         | Why the platform primitive was insufficient                           | Why the scope is narrow                               | Removal trigger                                                       |
| ----------------------------------- | ------------------------------------------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------------- |
| One pinned runtime dependency       | Supported Supabase browser/Auth/RPC client                         | `fetch` would recreate token/session behavior                         | Existing React dependencies remain unchanged          | Replace only through an approved client decision                      |
| Environment validator               | Safe no-throw configuration state                                  | Vite exposes strings without local-host or secret-boundary validation | Two variables and loopback hosts only                 | Remove if the runtime supplies an equivalent typed validator          |
| Lazy client factory                 | Prevent invalid initialization and duplicate clients               | Direct module initialization cannot show a safe config state          | One browser client, no service credentials            | Remove if application boot owns an equivalent singleton               |
| Auth session hook                   | Coordinate initial load, events, expiry, cleanup, and sign-out     | Component callbacks alone duplicate lifecycle logic                   | One hook; no Context/store/reducer                    | Replace when PA-06C establishes an approved app-wide session boundary |
| Connection panel                    | Give operators a visible local sign-in/sign-out check              | No existing shell surface represented Auth                            | One panel, no routing or workflow                     | Remove or absorb into the approved PA-06C shell                       |
| RPC adapter                         | Enforce reviewed schema/function/session/error boundaries          | Raw client calls permit arbitrary function names and caller subjects  | Exact 18-name registry, one request shape, no retries | Regenerate only after an approved API-contract change                 |
| Two local scripts plus one SQL file | Deterministic Auth identity, Atlas mapping, and real sign-in check | pgTAP fixtures roll back and cannot authenticate                      | Loopback-only, one user, one capability, one customer | Remove when a reviewed local identity fixture replaces them           |
| Focused tests                       | Prove security and lifecycle boundaries                            | Existing prototype tests do not cover Supabase                        | Tests live beside the new connection module           | Remove with the corresponding implementation                          |
| Vite/Auth/Analytics config changes  | Align redirect/port and omit an unused optional service            | Existing redirect was HTTPS while Vite was unspecified HTTP           | Local config only; no hosted setting                  | Revisit when a deployed environment is approved                       |

No new route, React Context, external state store, reducer, cache, query library, error framework, test utility framework, migration, database API, or business concept was added.

## 11. Files and ownership

- Browser connection code and tests: `src/modules/atlas/connection/`.
- Shell integration: `src/modules/atlas/AtlasApp.tsx` and `src/styles.css`.
- Browser variable types: `src/vite-env.d.ts`.
- Package/tooling: `package.json`, `pnpm-lock.yaml`, `.env.example`, `.gitignore`, and `vite.config.ts`.
- Local Supabase config and fixture: `supabase/config.toml` and `supabase/local/pa_06b_synthetic_identity.sql`.
- Local provisioning/verification: `scripts/provision-local-atlas-identity.mjs` and `scripts/verify-local-supabase-connection.mjs`.
- Task evidence and decisions: this file.

No migration or production-data change exists, so there is no database rollback. Code rollback is the revert of the PA-06B commits. Local synthetic data is disposable and removed by `supabase stop --no-backup` or the next clean reset.

## 12. Security conclusion and PA-06C gate

The browser holds only the URL, local publishable key, and ordinary user session managed by Supabase. The service/Admin key is confined to a loopback-only provisioning process and never enters Vite source, browser configuration, checked-in env, UI, logs, or diagnostics. The backend remains authoritative for actor mapping, active status, capability, relational scope, concurrency, idempotency, and audit behavior.

PA-06C must not begin until the local Kong/API gateway starts reliably and the real synthetic sign-in, session restoration, subject display, expiry/sign-out cleanup, and verification script pass through `http://127.0.0.1:54321`. The next approved decision must also identify the first bounded operator workflow and its exact subset of the 18-function registry; PA-06B intentionally chooses none.
