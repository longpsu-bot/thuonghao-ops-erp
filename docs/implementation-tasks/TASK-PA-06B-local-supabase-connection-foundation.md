# TASK-PA-06B — Local Supabase Application Connection Foundation

**Status:** Implementation and GitHub-hosted integration acceptance complete; draft PR pending product/architecture review
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
- clear the password immediately after successful sign-in while retaining the local email;
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

The runtime package remains `@supabase/supabase-js` `2.110.7`, pinned exactly. The corrective pass adds only the authorized development dependency `supabase` `2.109.1`, also pinned exactly, and invokes local stack commands through `pnpm exec supabase`.

For the pinned local CLI, `ANON_KEY` is the guaranteed browser-safe status field and its value is assigned to the existing `VITE_SUPABASE_PUBLISHABLE_KEY` variable. `PUBLISHABLE_KEY` is accepted only as a compatible browser-key alias. `SERVICE_ROLE_KEY` is returned only to the provisioning path; `SECRET_KEY` is not accepted as an Admin credential. No key value is printed, committed, copied into `.env.local` by a script, or included in an error.

## 5. Auth and session behavior

The session hook subscribes once per configured client, reads the initial session, and unsubscribes on cleanup. It represents configuration error, loading, unauthenticated, authenticated, and expired states explicitly.

`session.user.id` is the sole browser source for `requested_by_auth_subject`. Caller input with that name is overwritten immediately before each RPC. Tokens and raw Auth errors are never rendered or logged. A successful sign-in clears the password immediately and retains the email. Sign-out uses local scope. Sign-in failure, sign-out, expiry, a failed session read, and an unexpected `SIGNED_OUT` event also clear the password and any caller-owned connection state. Expiry does not replay a command: the operator must sign in, review, and create a new command intent.

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

The single browser client is initialized with `db: { retry: false }`. At runtime the call is `client.schema("atlas_api").rpc(functionName, { request }).retry(false)`, which also makes the reviewed transport boundary explicit with the installed client version. Arbitrary names are rejected before a session or network call. The adapter reads the current session for every invocation and rejects absent or expired sessions. There is no retry loop, custom retrying fetch, retry package, or separate read/write client.

Success envelopes are preserved. Backend-safe failure fields are copied from an explicit allowlist: `success`, `contract_version`, `error_code`, `safe_message`, `domain`, `command_name`, `read_name`, `retryable`, `field_errors`, `blocking_references`, `expected_version`, `actual_version`, `correlation_id`, and `command_id`. Unknown properties, raw SQL, tokens, keys, PostgREST diagnostics, and stack traces are discarded. Client/Auth/transport diagnostics remain distinct and safe.

Browser security tests prohibit service-role variables, hosted Supabase references, private-table `.from(...)` access, and non-registry RPC calls in the connection source.

## 7. Synthetic local identity

`pnpm local:auth:provision` creates or updates one deterministic local-only Auth user through the local Admin API, then applies and asserts the Atlas actor mapping with `pnpm exec supabase db query --local --file ...`. Each fixture file is one atomic `DO` statement because pinned CLI `2.109.1` sends a query file as one prepared statement. The path has no generated-container-name dependency, refuses a non-loopback API URL, does not log a key or token, and keeps `SERVICE_ROLE_KEY` in the Node provisioning process only.

Synthetic identity:

- email: `atlas.pa06b.operator@local.test`;
- Auth subject: `b6000000-0000-0000-0000-000000000101`;
- active Atlas actor: `PA-06B Synthetic Local Operator`;
- capability: `operator_blockers.read` only;
- scope: one synthetic customer only.

The SQL remains outside automatic global seed execution. Its fixed identifiers and upserts support repeatable clean-reset provisioning, and a separate SQL assertion checks the active Auth-subject mapping, actor, role, capability, role-capability grant, effective membership, and customer scope. GitHub-hosted acceptance run `29624145271` executed the identical provisioning command twice successfully, so provisioning idempotency and both assertion passes are observed.

`pnpm local:connection:verify` signs in with the deterministic identity, verifies the session subject, calls the non-mutating `atlas_api.get_operator_blockers` read with a valid `PA-05C.v1` envelope, accepts only success or the reviewed safe `NOT_FOUND` shape, signs out locally, and verifies that no session remains. The probe explicitly disables request retry and never issues a business write. GitHub-hosted acceptance observed subject `b6000000-0000-0000-0000-000000000101`, the safe `NOT_FOUND` category, and a cleared session after local sign-out.

## 8. Local runbook

From the repository root:

```powershell
pnpm exec supabase start --debug
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/pa_05g_backend_end_to_end_acceptance.sql --local
pnpm local:auth:provision
pnpm local:auth:provision
pnpm local:connection:verify
pnpm exec supabase status -o env
```

Copy only `API_URL` and the browser-safe `ANON_KEY` (or compatible `PUBLISHABLE_KEY` alias) from the final command into an ignored `.env.local` as `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Never copy `SERVICE_ROLE_KEY` or `SECRET_KEY`. Then run:

```powershell
pnpm dev
```

Open `http://127.0.0.1:3000`, use the synthetic credentials maintained in the local provisioning script, confirm the displayed subject, and sign out. Stop and remove the disposable local stack when finished:

```powershell
pnpm exec supabase stop --no-backup
```

## 9. Validation and integration acceptance evidence

Corrective evidence recorded on 2026-07-17:

- canonical checkout, remote, branch `task/pa-06b-local-supabase-connection-foundation`, starting head `3c3d0bcf264295817a4086d483705ff6e6862565`, clean starting tree, PR #108 base `main`, and zero commits behind `origin/main` were verified;
- `pnpm ops:workspace` passed;
- the repository CLI is exactly `supabase` `2.109.1`; runtime `@supabase/supabase-js` remains `2.110.7`;
- pinned CLI help confirmed structured `status -o json`, local file execution through `db query --local --file`, normal health checks, `db reset --local --no-seed`, and focused `test db --local` support;
- focused parser/client/transport/static-security tests and typechecking passed during correction;
- the final frontend validation passed: frozen install, formatting, typecheck, 38 test files/229 tests, application build, Storybook build, and `git diff --check`. The existing non-blocking chunk-size and Storybook plugin-timing advisories remain;
- Docker Desktop `4.62.0`, Engine `29.2.1`, Linux containers on `desktop-linux`, WSL2 kernel `6.6.87.2`, eight CPUs, and 3.719 GiB Docker memory were recorded; ports `3000`, `54321`, `54322`, `54323`, and `54324` were free;
- before the clean restart, only a disposable stopped Kong remnant existed, with no mounts or database volume. It had exit code 128 because its referenced Supabase network no longer existed;
- `pnpm exec supabase stop --no-backup` removed that remnant after disposability was confirmed;
- clean start attempt 1 downloaded the pinned service images, applied migrations, then exited unsuccessfully and cleaned its containers;
- clean start attempt 2 applied migrations and started PostgREST `14.14`; PostgREST connected to PostgreSQL `17.6` and loaded exactly 18 RPCs. Kong emitted no container log lines, remained unhealthy, never listened on loopback port `54321`, and every `/rest-admin/v1/ready` probe was refused. The CLI then pruned all nine containers, database/storage volumes, and the generated network;
- no `--ignore-health-check`, generated Compose edit, proxy replacement, direct PostgREST fallback, hosted project, Auth/JWT weakening, or third start attempt was used.

At the end of the Windows corrective pass, the two-attempt limit meant `db reset`, focused PA-05G pgTAP, two provisioning executions, the real Auth sign-in, authenticated Atlas read, sign-out/no-session assertion, and browser verification were not observed on that machine. The GitHub-hosted evidence below subsequently closed the reset, pgTAP, provisioning, Auth, read, and sign-out items without requiring personal-computer Docker. Browser visual review remains owned by component tests and UI Review Export. Earlier historical pgTAP count debt (15/17 versus the approved 18-function surface) remains out of scope and was not edited.

The Windows/Kong evidence above remains useful local-environment history. It is not the PA-06B acceptance environment and personal-computer Docker success is no longer required. GitHub-hosted workflow `.github/workflows/supabase-integration.yml`, workflow `Supabase Integration`, job `Local Auth and RPC acceptance`, is the authoritative integration acceptance path. It runs on `ubuntu-latest` with a 30-minute timeout and retains only PostgreSQL, Kong, PostgREST, and GoTrue/Auth. For pinned CLI `2.109.1`, the exact start command is:

```bash
pnpm exec supabase start --exclude analytics,edge-runtime,functions,imgproxy,inbucket,meta,realtime,storage,studio,vector
```

The workflow uses no repository Supabase secrets, hosted credentials, project reference, login, or link. Supabase start output is redirected to an ephemeral runner file and is never printed or uploaded raw. Failure output and relevant bounded container logs remove credential-labelled lines and redact legacy JWT values, `sb_publishable_...`, `sb_secret_...`, and bearer tokens. Cleanup always runs `supabase stop --no-backup`.

Observed GitHub evidence on 2026-07-18:

- initial run `29623955883` proved reduced-stack start, clean reset and all migrations, PA-05G, and the 18-function surface, then exposed one Linux-specific fixture-execution issue: multiple top-level SQL commands cannot be sent as one prepared statement by `db query --file`;
- correction cycle 1 changed only the two local fixture files to one atomic `DO` statement each; no migration, schema, API, Auth policy, or business behavior changed;
- run `29624145271` passed `Local Auth and RPC acceptance` in 3m05s and completed unconditional cleanup;
- database reset completed after applying every repository migration;
- focused `supabase/tests/pa_05g_backend_end_to_end_acceptance.sql` passed one file and all 82 tests;
- the passing PA-05G assertions proved `atlas_api` contains exactly 18 functions, `authenticated` executes exactly those 18, and `anon`/`service_role` execute none;
- first provisioning passed its Auth creation/update and Atlas mapping assertions;
- the identical second provisioning passed, proving repeatability;
- real email/password sign-in passed with Auth subject `b6000000-0000-0000-0000-000000000101`;
- the authenticated non-mutating `get_operator_blockers` probe returned the reviewed `SAFE_NOT_FOUND` category;
- local-scope sign-out passed and `getSession()` returned no remaining session;
- the Auth connection probe issued no business write; PA-05G command exercises remained inside its rolled-back test transaction, and cleanup retained no database volume or local credential.

Final frontend evidence for the same change set:

- the local full suite passed workspace validation, frozen installation, formatting, typecheck, 38 test files/230 tests, application build, Storybook build, and `git diff --check`;
- GitHub `Frontend CI / Format, typecheck, test, build`, `UI Review Export / Build UI review artifact`, and Qodana passed at head `dfeeb5b321bcf6db6830da73628d19da1172d896`;
- existing non-blocking chunk-size and Storybook plugin-timing advisories remain; GitHub also reports the non-blocking Node 20 action-runtime deprecation while the required v4 actions are forced onto Node 24.

## 10. Simplicity inventory

| Addition                                                   | Why needed                                                                                            | Why the platform primitive was insufficient                           | Why the scope is narrow                               | Removal trigger                                                       |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------------- |
| One pinned runtime dependency                              | Supported Supabase browser/Auth/RPC client                                                            | `fetch` would recreate token/session behavior                         | Existing React dependencies remain unchanged          | Replace only through an approved client decision                      |
| Environment validator                                      | Safe no-throw configuration state                                                                     | Vite exposes strings without local-host or secret-boundary validation | Two variables and loopback hosts only                 | Remove if the runtime supplies an equivalent typed validator          |
| Lazy client factory                                        | Prevent invalid initialization and duplicate clients                                                  | Direct module initialization cannot show a safe config state          | One browser client, no service credentials            | Remove if application boot owns an equivalent singleton               |
| Auth session hook                                          | Coordinate initial load, events, expiry, cleanup, and sign-out                                        | Component callbacks alone duplicate lifecycle logic                   | One hook; no Context/store/reducer                    | Replace when PA-06C establishes an approved app-wide session boundary |
| Connection panel                                           | Give operators a visible local sign-in/sign-out check                                                 | No existing shell surface represented Auth                            | One panel, no routing or workflow                     | Remove or absorb into the approved PA-06C shell                       |
| RPC adapter                                                | Enforce reviewed schema/function/session/error boundaries                                             | Raw client calls permit arbitrary function names and caller subjects  | Exact 18-name registry, one request shape, no retries | Regenerate only after an approved API-contract change                 |
| Shared status parser, two local scripts, and two SQL files | Deterministic safe key discovery, Auth identity, asserted Atlas mapping, and real read/sign-out check | pgTAP fixtures roll back and cannot authenticate                      | Loopback-only, one user, one capability, one customer | Remove when a reviewed local identity fixture replaces them           |
| Focused tests                                              | Prove security and lifecycle boundaries                                                               | Existing prototype tests do not cover Supabase                        | Tests live beside the new connection module           | Remove with the corresponding implementation                          |
| Vite/Auth/Analytics config changes                         | Align redirect/port and omit an unused optional service                                               | Existing redirect was HTTPS while Vite was unspecified HTTP           | Local config only; no hosted setting                  | Revisit when a deployed environment is approved                       |

No new route, React Context, external state store, reducer, cache, query library, error framework, test utility framework, migration, database API, or business concept was added.

## 11. Files and ownership

- Browser connection code and tests: `src/modules/atlas/connection/`.
- Shell integration: `src/modules/atlas/AtlasApp.tsx` and `src/styles.css`.
- Browser variable types: `src/vite-env.d.ts`.
- Package/tooling: `package.json`, `pnpm-lock.yaml`, `.env.example`, `.gitignore`, and `vite.config.ts`.
- Local Supabase config and fixture assertions: `supabase/config.toml`, `supabase/local/pa_06b_synthetic_identity.sql`, and `supabase/local/pa_06b_synthetic_identity_assertion.sql`.
- Local status/provisioning/verification: `scripts/local-supabase-status.mjs`, `scripts/provision-local-atlas-identity.mjs`, and `scripts/verify-local-supabase-connection.mjs`.
- Task evidence and decisions: this file.

No migration or production-data change exists, so there is no database rollback. Code rollback is the revert of the PA-06B commits. Local synthetic data is disposable and removed by `supabase stop --no-backup` or the next clean reset.

## 12. Security conclusion and PA-06C gate

The browser holds only the URL, local publishable key, and ordinary user session managed by Supabase. The service/Admin key is confined to a loopback-only provisioning process and never enters Vite source, browser configuration, checked-in env, UI, logs, or diagnostics. The backend remains authoritative for actor mapping, active status, capability, relational scope, concurrency, idempotency, and audit behavior.

GitHub-hosted acceptance now satisfies the PA-06B technical connection gate: healthy reduced stack, clean reset, focused PA-05G, exact 18-function surface, two identical provisioning passes, real synthetic Auth/session/`get_operator_blockers`/sign-out verification, and disposable cleanup. PA-06C must still not begin until PR #108 completes product/architecture review and a separate approved task identifies the first bounded operator workflow and its exact subset of the 18-function registry. PA-06B intentionally chooses none, creates no business workflow, and does not authorize merge or deployment.
