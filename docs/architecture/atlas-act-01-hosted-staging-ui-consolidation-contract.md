# ATLAS-ACT-01 — Hosted Staging and UI Consolidation Contract

**Status:** Proposed architecture contract; documentation only

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Owning mission:** replace OPS v1 safely with a transferable Atlas operating system without exposing unfinished workflows to production operations

**Business capabilities:** activate a controlled Atlas staging environment; standardize the current Atlas operator experience; certify the connected Admin and Planning path before further capability expansion

**Related authority:**

- [PA-06A Environment and Deployment Contract](pa-06a-environment-deployment-contract.md)
- [PA-06A Application Connection Contract](pa-06a-application-connection-contract.md)
- [TASK-PA-06B Local Supabase Application Connection Foundation](../implementation-tasks/TASK-PA-06B-local-supabase-connection-foundation.md)
- [Atlas Operations Workbench Requirements](../ui/atlas-workbench-requirements.md)
- [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md)
- [Atlas Current UI Inventory](../ui/atlas-current-ui-inventory.md)
- [ATLAS-ACT-01 decision registry](../decisions/decision-atlas-act-01-hosted-staging-ui-consolidation.md)

## 1. Executive decision

Atlas pauses downstream business-capability expansion after merged RMVP-07B.

The next delivery gate is:

```text
connected local Atlas through Confirmed Need release
→ separate hosted Atlas staging environment
→ current-workbench UI consolidation
→ authenticated staging rehearsal through Confirmed Need release
→ operator and security acceptance
→ later CMD-03 / Purchase Handoff architecture and implementation
```

CMD-03, supplier allocation and purchase-order work do not begin during ATLAS-ACT-01.

The hosted topology is fixed as:

```text
existing OPS project qnthofvccilhnefdcxnz
→ continues to serve OPS v1 / OPS v2 and Retool
→ receives no Atlas migration, Atlas Auth binding or Atlas frontend connection

new separate Atlas staging project
→ receives the complete reviewed Atlas migration history
→ contains staging-only identities, capabilities and synthetic or explicitly approved masked data
→ becomes the first shared hosted Atlas execution environment

future Atlas production project
→ remains a later separately approved target
```

Supabase Branching is not required for the first staging activation. A long-lived separate staging project is the bounded default. Preview branches may be considered later only after cost, lifecycle and cleanup ownership are approved.

## 2. Evidence reviewed on 06/08/2026

### 2.1 Hosted OPS Supabase

The live project was inspected read-only:

| Evidence | Observed value |
| --- | --- |
| Project | `OPS` |
| Project reference | `qnthofvccilhnefdcxnz` |
| Region | `ap-southeast-1` |
| Health | `ACTIVE_HEALTHY` |
| PostgreSQL | `17.6.1.005` |
| Atlas API schema | absent |
| `atlas_confirmed_need_review_runtime` | absent |
| Atlas API function count | `0` |
| Tracked application schemas | `public`, `ops_v2` |
| Application tables | `47` |
| Application functions | `108` |
| Deployed Edge Functions | `0` |

Schema evidence:

| Schema | Tables | Views | RLS-enabled tables | Forced-RLS tables |
| --- | ---: | ---: | ---: | ---: |
| `public` | 15 | 4 | 10 | 0 |
| `ops_v2` | 28 | 5 | 23 | 0 |

This evidence confirms that the project is a legacy production boundary, not an empty Atlas target.

### 2.2 Retool evidence

The retained production exports were inspected as operational evidence:

| Export | SHA-256 |
| --- | --- |
| `OPS - Admin (in production).json` | `2387036816926e7a41003ab6f93b41ed5db6baf1c5a29bb4cf3f830e75625487` |
| `OPS - Công thức.json` | `3576f3b4d4e4b1565440502438999de1407bb76469ea1954e6d59b6b0170ba08` |
| `OPS - Nguyên liệu và Nhà cung ứng.json` | `32e390ff73c7b43a4053aa933e58871b966d7f8baa2db9ad10ac9d4a1122a10c` |
| `OPS - Lên đơn, Đặt hàng (1).json` | `6f6ff8d025696d375f354a86126661d20c3e9908d6475d40ecb14ee006b4a371` |

The apps contain substantial component state, direct SQL/RPC orchestration and `ops_v2` dependencies. They are business-behaviour and operator-density evidence. They are not Atlas UI, authorization or persistence authority.

No Retool app is changed by this contract.

### 2.3 Repository evidence

The reviewed baseline contains:

- complete local Atlas migrations and registered acceptance suites;
- a local-only browser-safe Supabase connection foundation;
- connected Admin and Planning workbenches through Confirmed Need release;
- Storybook and UI Review Export;
- one broad shared component module and a large common stylesheet;
- multiple substantial module-specific workbenches with repeated state and presentation patterns;
- no approved hosted Atlas project, production bindings or staging data package.

## 3. OPS_SYSTEM_MAP placement

| Layer | ATLAS-ACT-01 placement |
| --- | --- |
| Mission | Make the implemented Atlas path reviewable by real operators without risking OPS v1 production continuity. |
| Business capability | Hosted staging activation; operator-experience standardization; staging rehearsal and certification. |
| Business domain | Cross-domain platform capability supporting Admin and Planning first. No business-domain ownership moves. |
| Business object | Environment identity, deployment release, staging Actor/capability assignment, rehearsal dataset, UI component contract and workbench acceptance record. |
| Business contract | This contract, PA-06A environment/connection authority, existing domain/API contracts and the UI quality standard. |
| Command/event | No new business command or event. Deployment and UI work must preserve existing command contracts. |
| Read model | Existing read APIs only. UI consolidation may reshape presentation but not backend responses. |
| Application | Existing Atlas shell and connected workbenches, reviewed in staging. |
| Technology | Separate Supabase project, pinned repository migrations, protected GitHub Environment, browser-safe configuration, React/TypeScript/CSS/Storybook and existing CI. |

## 4. Environment model

### 4.1 Local

Local remains the implementation and deterministic acceptance environment.

- repository-pinned Supabase CLI and migrations;
- disposable synthetic Auth users and data;
- all registered pgTAP suites;
- browser-key acceptance journeys;
- no production or staging credential required;
- complete reset before and after fixture-driven verification.

### 4.2 Atlas staging

Atlas staging is one separate long-lived hosted Supabase project.

Its purpose is shared authenticated review and rehearsal, not production operations.

Allowed content:

- the exact repository migration history;
- staging-only Auth identities;
- Atlas Actor mappings, roles, capabilities and scopes approved for rehearsal;
- approved master/reference data;
- approved Planning policy revisions;
- deterministic synthetic or explicitly approved masked rehearsal records;
- no live OPS v1 operational records by default.

The project must use an approved region and project name. Project creation is a cost-incurring external action and requires an explicit cost confirmation immediately before creation.

### 4.3 Atlas production

Production remains unselected and unauthorized.

ATLAS-ACT-01 does not create it, select a region, define cutover data, assign production Actors or migrate legacy operational facts.

### 4.4 Live OPS v1

The existing OPS project and Retool applications continue unchanged.

Atlas staging must not:

- use project reference `qnthofvccilhnefdcxnz`;
- apply Atlas migrations to that project;
- add Atlas schemas, roles, Auth identities, grants or policies there;
- redirect Retool queries;
- write `public` or `ops_v2` objects;
- introduce dual write or browser-side synchronization.

## 5. Environment identity and browser configuration

The application environment is explicit and visible.

Future ATLAS-ACT-01B repository readiness uses exactly:

```text
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

Allowed environment values are initially:

```text
local
staging
```

`production` is rejected until a production activation contract is accepted.

Rules:

- `local` requires a loopback Supabase URL;
- `staging` requires HTTPS and a non-loopback host;
- embedded URL credentials are rejected;
- missing or malformed values prevent client initialization;
- rejected values are not echoed;
- service-role, secret, management, database and JWT credentials are prohibited from browser variables;
- the active environment is visibly labeled in the Atlas shell;
- the existing Supabase Auth subject remains the only browser authority for `requested_by_auth_subject`.

## 6. Protected GitHub environment contract

The initial protected GitHub Environment is:

```text
atlas-staging
```

Environment variables:

```text
ATLAS_STAGING_PROJECT_REF
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
ATLAS_STAGING_TEST_EMAIL
```

Environment secrets:

```text
ATLAS_STAGING_SUPABASE_ACCESS_TOKEN
ATLAS_STAGING_DB_PASSWORD
ATLAS_STAGING_TEST_PASSWORD
```

Repository workflows may map these protected names to the exact environment variables expected by the pinned Supabase CLI. No value is committed, printed or uploaded as an artifact.

The deployment safety check must:

1. require the `atlas-staging` GitHub Environment;
2. require explicit manual dispatch initially;
3. require the target project reference to equal the approved Atlas staging reference;
4. explicitly reject `qnthofvccilhnefdcxnz`;
5. run complete local integration acceptance before a hosted action;
6. stop before deployment if migration history, worktree or target identity is inconsistent;
7. redact access tokens, passwords, connection strings, JWTs and keys from diagnostics.

## 7. Migration and Data API contract

Repository migrations remain the sole schema authority.

The initial staging project is created empty enough for the complete Atlas migration chain to be applied in order. Manual Dashboard DDL is prohibited.

Deployment is forward-only:

```text
reviewed repository main
→ complete local reset and acceptance
→ explicit staging target verification
→ repository migration deployment
→ read-only hosted catalog/security verification
→ authenticated staging acceptance
```

A failed deployed migration is corrected by a reviewed forward migration. Deleting migration history or manually rewriting committed evidence is not an ordinary rollback.

For new Supabase projects, Data API exposure and grants must be verified explicitly. Atlas keeps:

- `atlas_api` as the reviewed browser-callable schema;
- private domain schemas inaccessible to browser roles;
- explicit function execute grants and revokes;
- forced RLS and revoke-first private relations;
- no browser table access as a substitute for missing APIs.

## 8. Staging seed packages

Staging activation separates four governed packages:

1. **Identity package** — staging Auth users, Actor mappings, roles, capabilities and scopes.
2. **Reference package** — approved units, customers/schools, locations, ingredients, suppliers, dishes and other required master data.
3. **Policy package** — approved Planning policy roots and revisions required for connected journeys.
4. **Rehearsal package** — synthetic or approved masked transactional scenarios used for operator acceptance.

No package is hidden inside frontend code or automatic global local seed behavior.

Every package must be:

- version-controlled or generated from a reviewed source;
- idempotent or explicitly single-use;
- environment-qualified;
- safe to report without exposing credentials or personal data;
- independently removable or replaceable in staging where history permits.

Production data migration is outside ATLAS-ACT-01.

## 9. Hosted acceptance gate

Atlas staging is accepted only when all of the following pass:

### Platform and security

- project identity and region match the accepted staging record;
- database health is normal;
- every repository migration is applied exactly once;
- expected schemas, relations, functions, roles, policies and grants match repository authority;
- `atlas_api` is exposed as intended;
- private relations remain unavailable to `anon` and `authenticated`;
- management credentials are absent from browser bundles and logs;
- no object exists in the live OPS project because of this activation.

### Auth and authorization

- staging-only sign-in succeeds;
- Auth subject resolves to the expected active Atlas Actor;
- capability and scope denial paths work;
- session expiry and sign-out disable commands;
- production role bindings do not exist.

### Operator journey

The staging rehearsal must complete:

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

It must also demonstrate blockers, stale versions, inactive references, denied capabilities, unknown mutation outcomes, refresh-before-retry and audit/lifecycle evidence.

## 10. UI consolidation decision

The UI work is a quality program over existing capabilities, not a redesign of business ownership.

The target remains a compact daily operations workbench. OPS v1 is a behavioural reference, not a visual template.

The first UI architecture rules are:

- no new external UI framework or design-system dependency in the first pass;
- consolidate reusable local React components and CSS tokens;
- preserve existing API calls, backend authority and lifecycle behavior;
- represent one authoritative current state, with history separately visible;
- use backend-provided eligibility and safe messages;
- keep dense operational tables inside bounded responsive containers;
- improve keyboard, focus, semantics, contrast and narrow-screen behavior;
- use Vietnamese operator language consistently;
- certify work through Storybook, component tests and UI Review Export.

The canonical details are in [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md).

## 11. UI implementation sequence

UI changes are divided into small implementation slices:

1. **UI-QUALITY-01 — Shared shell and primitives**
   - tokens, page/workbench header, panels, notices, action groups, status chips, forms, dialogs, empty/loading/error/read-only states, evidence summary, timeline and responsive table wrapper;
   - Atlas shell and one representative Planning wrapper prove the primitives;
   - no full module migration.
2. **UI-QUALITY-02 — Planning Inputs and Confirmed Need**
   - Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need;
   - preserve connected backend behavior.
3. **UI-QUALITY-03 — Admin master data**
   - Schools, Ingredients/Suppliers and Dishes/Recipes.
4. **UI-QUALITY-04 — Other existing operational prototypes**
   - Procurement, Warehouse, Dispatch and Evidence presentation only.
5. **UI-QUALITY-05 — Cross-module certification**
   - accessibility, responsive behavior, operator rehearsal, copy consistency and remaining visual debt.

Each slice must have an exact changed-path manifest and no business migration/API delta.

## 12. Phase gate before downstream expansion

CMD-03 architecture may resume only after:

- ATLAS-ACT-01B repository staging readiness is merged;
- the separate Atlas staging project is created and migration acceptance passes;
- approved staging identities and data packages are installed;
- UI-QUALITY-01 and UI-QUALITY-02 are merged;
- the Admin-to-Confirmed-Need-release staging rehearsal passes;
- open security or operator blockers are classified and accepted.

This gate may be amended by an explicit Product/Architecture decision, not by implementation convenience.

## 13. Explicit exclusions

ATLAS-ACT-01A creates no executable resource. It excludes:

- Supabase project or branch creation;
- migration deployment;
- hosted project linking;
- hosted Auth users or capability bindings;
- production data or masked-data extraction;
- Retool changes;
- OPS v1 or OPS v2 changes;
- Edge Function deployment;
- production Atlas selection or cutover;
- CMD-03 or Purchase Handoff creation;
- supplier allocation or purchase orders;
- Procurement, Warehouse or Dispatch business mutation;
- new business APIs, states, events or read models;
- a new UI framework;
- generic workflow, task, notification or case-management infrastructure.

## 14. Authorized follow-on packages

After this architecture is accepted and merged, separate authorization is required for:

- [ATLAS-ACT-01B — Hosted Staging Repository Readiness](../implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness.md);
- external Atlas staging project creation and migration activation after cost confirmation;
- [UI-QUALITY-01 — Shared Shell and Primitives](../implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md);
- later UI-QUALITY module slices;
- staging identity, reference, policy and rehearsal-data packages.