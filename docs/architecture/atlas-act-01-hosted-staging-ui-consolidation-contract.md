# ATLAS-ACT-01 — Hosted Staging and Connected-UI Consolidation Contract

**Status:** Accepted architecture contract; documentation only

**Accepted on:** 06/08/2026

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Mission:** make the connected Atlas Admin and Planning path usable by real operators without risking OPS v1 continuity or delaying delivery with speculative platform work.

**Related authority:**

- [ARCH-002 Atlas System Map](arch-002-atlas-system-map.md)
- [PA-06A Environment and Deployment Contract](pa-06a-environment-deployment-contract.md)
- [PA-06A Application Connection Contract](pa-06a-application-connection-contract.md)
- [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md)
- [Atlas Current UI Inventory](../ui/atlas-current-ui-inventory.md)
- [ATLAS-ACT-01 Decision](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md)

## 1. Executive decision

Atlas pauses CMD-03 and downstream purchasing expansion after merged RMVP-07B.

The next delivery sequence is:

```text
connected local Atlas through Confirmed Need release
→ repository staging readiness
→ separate hosted Atlas staging project
→ connected Admin and Planning UI consolidation
→ authenticated staging rehearsal
→ operator and security acceptance
→ later decision on CMD-03 / Purchase Handoff
```

The topology is:

```text
existing OPS project qnthofvccilhnefdcxnz
→ remains the live OPS v1/v2 and Retool boundary
→ receives no Atlas migration, Auth binding or frontend connection

separate Atlas staging project
→ receives reviewed Atlas migrations and staging-only data
→ is the first shared hosted Atlas environment

future Atlas production project
→ remains a later separately approved decision
```

One long-lived staging project is the simplest first hosted environment. Preview branches and per-PR databases are not required for this phase.

## 2. Evidence and legacy boundary

Read-only review on 06/08/2026 confirmed that hosted project `qnthofvccilhnefdcxnz` is `ACTIVE_HEALTHY` in `ap-southeast-1`, runs PostgreSQL `17.6.1.005`, has no `atlas_api` schema, no Atlas Confirmed Need runtime and zero Atlas API functions.

It contains active legacy `public` and `ops_v2` objects, including 55 tables, 43 views/materialized views, 105 functions, 16 RLS-enabled public tables, no forced-RLS legacy tables and eight active Edge Functions. These numbers are time-stamped inventory evidence, not Atlas schema authority.

The retained Retool exports have the following reviewed SHA-256 values:

| Export                                   | SHA-256                                                            |
| ---------------------------------------- | ------------------------------------------------------------------ |
| `OPS - Admin (in production).json`       | `a6d74ca01f7942687e8639ffef73dba5a89c6bcbf653f9454011cec551549350` |
| `OPS - Công thức.json`                   | `b38c86ac3b1fed985f6bc07d91c0708cf5aacccc682434ba2498960d1da1b809` |
| `OPS - Nguyên liệu và Nhà cung ứng.json` | `2fb973cbd6a3900252aa9037a1d4d197551bccc93db60e36512d97f27d903648` |
| `OPS - Lên đơn, Đặt hàng (1).json`       | `6f6ff8d025696d375f354a86126661d20c3e9908d6475d40ecb14ee006b4a371` |

Retool demonstrates the need for dense tables, fast filtering, inline editing, visible exceptions, explicit save/refresh actions and concise Vietnamese task language. It also demonstrates why Atlas must not copy direct browser SQL, UI-owned calculations, hidden state orchestration or legacy page structure.

## 3. OPS_SYSTEM_MAP placement

| Layer               | ATLAS-ACT-01 placement                                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Replace OPS v1 safely with a maintainable and transferable Atlas system.                                                        |
| Business capability | Hosted staging activation and operator-experience stabilization.                                                                |
| Business domain     | Cross-domain platform support for the already connected Admin and Planning domains.                                             |
| Business object     | Environment identity, deployment release, staging identity/data package and UI acceptance record.                               |
| Business contract   | This contract plus existing environment, API, domain and UI contracts.                                                          |
| Command/event       | No new business command or event.                                                                                               |
| Read model          | Existing backend read models remain authoritative.                                                                              |
| Application         | Existing Atlas shell and connected workbenches.                                                                                 |
| Technology          | Separate Supabase project, repository migrations, protected GitHub Environment, React/TypeScript/CSS/Storybook and existing CI. |

## 4. Environment boundaries

### 4.1 Local

Local remains the development and deterministic certification environment:

- pinned Supabase CLI and repository migrations;
- synthetic Auth users and fixtures;
- all registered pgTAP suites;
- current browser-key journeys;
- disposable resettable data.

### 4.2 Atlas staging

Staging is one separate hosted Supabase project used for:

- shared authenticated review;
- migration and Data API verification;
- real Auth, RLS, scope and capability checks;
- operator rehearsal of existing connected capabilities;
- no production operations.

Project creation is a cost-incurring action. The Supabase organization and current price must be retrieved and explicitly confirmed immediately before creation.

### 4.3 Atlas production

Production is not selected, created or configured in this phase. Production data migration, support ownership, cutover and rollback need a later contract.

### 4.4 Live OPS

The live OPS project and Retool applications continue unchanged. Atlas tooling must explicitly reject project reference `qnthofvccilhnefdcxnz` and must never add Atlas schemas, roles, policies, Auth identities or migrations there.

## 5. Minimal environment and credential contract

Browser-safe configuration uses exactly:

```text
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

Initially supported environments:

```text
local
staging
```

`production` fails closed until a production activation contract is accepted.

Rules:

- `local` requires a loopback Supabase URL;
- `staging` requires HTTPS and a non-loopback host;
- embedded URL credentials are rejected;
- missing or malformed configuration prevents client initialization;
- rejected values are not echoed;
- service-role, management, database and Auth test secrets never enter frontend bundles;
- the shell visibly identifies local versus staging;
- the authenticated Supabase subject remains the browser identity source.

The initial protected GitHub Environment is:

```text
atlas-staging
```

Protected variables:

```text
ATLAS_STAGING_PROJECT_REF
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
ATLAS_STAGING_TEST_EMAIL
```

Protected secrets:

```text
ATLAS_STAGING_SUPABASE_ACCESS_TOKEN
ATLAS_STAGING_DB_PASSWORD
ATLAS_STAGING_TEST_PASSWORD
```

The repository stores names and placeholders only.

## 6. Migration and deployment contract

Repository migrations are the sole Atlas schema authority. Manual Dashboard DDL is prohibited.

Initial staging deployment is manual and protected. It must:

1. accept only an exact `main` commit;
2. verify that the same commit already passed Frontend CI and Supabase Full Integration;
3. avoid rerunning the complete local integration suite inside the deployment job;
4. verify the target project reference and reject the live OPS reference;
5. apply repository migrations in order using the pinned CLI;
6. verify hosted migration history and Atlas catalog/security fingerprints;
7. verify browser-safe Auth/read access;
8. stop on the first mismatch and redact secrets.

This reuses exact-head certification instead of paying the time cost of a second identical Full Integration run.

After a hosted migration is applied, correction is forward-only through a reviewed migration. Migration history and committed evidence are not rewritten or deleted as an ordinary rollback.

The new project must expose `atlas_api` as intended while keeping private Atlas schemas unavailable to browser roles. Missing reads must be solved through reviewed APIs, not direct browser table grants.

## 7. Staging data packages

Initial staging activation uses three explicit packages:

1. **Identity package** — staging Auth users, Actor mappings, roles, scopes and current approved capabilities.
2. **Foundation package** — only reference data and Planning policy needed by connected Admin and Planning workbenches.
3. **Rehearsal package** — deterministic synthetic transactional scenarios through Confirmed Need release.

The foundation package may include small synthetic supplier/reference examples needed to review the existing Admin UI, but it includes no supplier allocation, Purchase Handoff, purchase order or downstream operational fact.

Synthetic data is the default. Masked OPS data requires a separate approval, source record and privacy review. Production data migration is outside this phase.

Each package is reviewed, environment-qualified and idempotent where practical. No package is hidden in frontend code or an all-purpose seed.

## 8. UI consolidation contract

The UI program improves existing connected capabilities; it does not redesign business ownership.

Scope before CMD-03:

- Atlas shell and navigation;
- connected Planning Inputs through Confirmed Need release;
- connected Admin workbenches for Schools, Ingredients/Suppliers and Dishes/Recipes.

Unconnected Procurement, Warehouse, Dispatch and other prototypes are not polish targets in this gate. Their UI should be revised with their future connected backend slices rather than polished speculatively.

Rules:

- no external UI framework, table library, global state library or CSS runtime in the first pass;
- preserve APIs, request shapes, backend eligibility and lifecycle behavior;
- show one authoritative current state and separate immutable history;
- keep dense tables inside bounded responsive containers;
- use concise Vietnamese operator language and `dd/mm/yyyy` dates;
- support keyboard, focus, semantic labels, contrast and narrow screens;
- unknown write outcomes require authoritative refresh and are never auto-retried;
- create a shared abstraction only after at least two real current surfaces need it, unless it is a shell-level primitive.

The canonical detail is in [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md).

## 9. UI delivery sequence

1. **UI-QUALITY-01 — Shared shell and proven primitives**
   - semantic tokens;
   - shell hierarchy;
   - a small set of primitives already repeated in at least two connected surfaces;
   - proof in the shell and one Planning wrapper.
2. **UI-QUALITY-02 — Connected Planning**
   - Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need.
3. **UI-QUALITY-03 — Connected Admin**
   - Schools, Ingredients/Suppliers and Dishes/Recipes.
4. **Staging operator rehearsal**
   - cross-module usability, security and recovery acceptance; no separate design-system program.

Each implementation slice has an exact changed-path manifest and zero business migration/API/contract delta.

## 10. Hosted acceptance gate

Atlas staging is accepted only when:

### Platform and security

- project identity and region match the approved staging record;
- every reviewed migration is applied exactly once;
- Atlas schemas, APIs, roles, policies, grants and revokes match repository authority;
- private relations remain unavailable to `anon` and `authenticated`;
- no management credential appears in browser bundles, logs or artifacts;
- the live OPS project remains Atlas-free.

### Auth and authorization

- staging sign-in succeeds;
- Auth subject maps to the expected active Atlas Actor;
- allowed and denied capability/scope paths behave correctly;
- session expiry and sign-out disable commands;
- no production role binding exists.

### Operator journey

The rehearsal completes:

```text
Admin reference preparation
→ Weekly Menu
→ Attendance
→ Pantry
→ Planning Input Readiness
→ Need Generation
→ Confirmed Need review and quantity confirmation
→ validation
→ approval
→ release for Purchase Handoff
```

It also demonstrates a blocker, stale version, inactive reference, denied capability, unknown mutation outcome, refresh-before-retry and lifecycle/audit evidence.

## 11. Gate before CMD-03

CMD-03 may resume only after:

- ATLAS-ACT-01B repository staging readiness is merged;
- the separate staging project is cost-confirmed, created and accepted;
- UI-QUALITY-01, UI-QUALITY-02 and UI-QUALITY-03 are merged;
- the connected Admin-to-Confirmed-Need-release rehearsal passes;
- material security and operator blockers are resolved or explicitly accepted.

The gate may be changed only through an explicit Product/Architecture decision.

## 12. Authorized follow-on packages

After this contract is merged:

- [ATLAS-ACT-01B — Hosted Staging Repository Readiness](../implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness.md) may prepare repository configuration and guarded workflows without hosted mutation;
- external staging creation remains subject to current-cost confirmation;
- [UI-QUALITY-01 — Shared Shell and Proven Primitives](../implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md) may begin as a separate PR;
- UI-QUALITY-02 and UI-QUALITY-03 are derived only after the shared foundation is proven.

ATLAS-ACT-01B and UI-QUALITY-01 may proceed in either order, but must remain separate review units.

## 13. Explicit exclusions

ATLAS-ACT-01A creates no executable resource. It excludes:

- Supabase project or branch creation;
- cost confirmation;
- migration deployment or hosted linking;
- hosted Auth users, capability bindings or seed installation;
- Retool, OPS v1 or OPS v2 changes;
- production or masked-data extraction;
- Edge Function deployment;
- production Atlas selection or cutover;
- React/CSS implementation;
- CMD-03 or Purchase Handoff creation;
- supplier allocation or purchase orders;
- Procurement, Warehouse or Dispatch business mutation;
- new business APIs, states, events or read models;
- generic workflow, task, case or notification infrastructure.
