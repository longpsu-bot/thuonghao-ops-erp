# ATLAS-ACT-01 — Hosted Staging and UI Consolidation Contract

**Status:** Proposed architecture contract; documentation only

**Reviewed baseline:** `f3197bb5a7b571378a41ae5056a73a84ad57d583`

**Owning mission:** replace OPS v1 safely with a maintainable, transferable Atlas operating system without exposing unfinished workflows to production operations

**Business capabilities:** activate a controlled Atlas staging environment; standardize the current Atlas operator experience; certify the connected Admin and Planning path before further business-capability expansion

**Related authority:**

- [PA-06A Environment and Deployment Contract](pa-06a-environment-deployment-contract.md)
- [PA-06A Application Connection Contract](pa-06a-application-connection-contract.md)
- [TASK-PA-06B Local Supabase Application Connection Foundation](../implementation-tasks/TASK-PA-06B-local-supabase-connection-foundation.md)
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
→ continues serving OPS v1 / OPS v2 and Retool
→ receives no Atlas migration, Atlas Auth binding or Atlas frontend connection

new separate Atlas staging project
→ receives the complete reviewed Atlas migration history
→ contains staging-only identities, capabilities and synthetic or explicitly approved masked data
→ becomes the first shared hosted Atlas execution environment

future Atlas production project
→ remains a later separately approved target
```

A long-lived separate project is the bounded default for the first staging activation. Supabase preview branches are not required for this phase.

## 2. Evidence reviewed on 06/08/2026

### 2.1 Hosted OPS Supabase

The live project was inspected read-only immediately before this contract was finalized.

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
| Legacy application schemas | `public`, `ops_v2` |
| Legacy application tables | `55` total (`46` public, `9` ops_v2) |
| Legacy views/materialized views | `43` total (`29` public, `14` ops_v2) |
| Legacy functions | `105` total (`90` public, `15` ops_v2) |
| RLS-enabled legacy tables | `16` public, `0` ops_v2 |
| Forced-RLS legacy tables | `0` public, `0` ops_v2 |
| Active Edge Functions | `8` |

Observed active Edge Function slugs:

```text
upsert-daily-order
update-order-dishes
save-assignments
upsert_actual_need_overrides
delete-assignments
sync-dishes-to-gsheet
ops_dishes_sync_gsheet
qa-po-dispatch-email
```

These counts are time-stamped inventory evidence, not Atlas schema authority. They confirm that the project is an active legacy production boundary rather than an empty Atlas target.

### 2.2 Retool evidence

The retained production exports were inspected as operational and usability evidence:

| Export | SHA-256 |
| --- | --- |
| `OPS - Admin (in production).json` | `a6d74ca01f7942687e8639ffef73dba5a89c6bcbf653f9454011cec551549350` |
| `OPS - Công thức.json` | `b38c86ac3b1fed985f6bc07d91c0708cf5aacccc682434ba2498960d1da1b809` |
| `OPS - Nguyên liệu và Nhà cung ứng.json` | `2fb973cbd6a3900252aa9037a1d4d197551bccc93db60e36512d97f27d903648` |
| `OPS - Lên đơn, Đặt hàng (1).json` | `6f6ff8d025696d375f354a86126661d20c3e9908d6475d40ecb14ee006b4a371` |

The apps demonstrate the operational need for dense tables, date/period selectors, inline editing, clear save/refresh actions, fast exception access and Vietnamese task language. They also contain substantial direct SQL/RPC, `ops_v2` and component-state orchestration.

Retool therefore informs ergonomics and operator expectations. It is not Atlas persistence, authorization, transaction or component authority.

No Retool app is changed by this contract.

### 2.3 Repository evidence

The reviewed baseline contains:

- the complete local Atlas migration history and registered acceptance suites;
- a local-only browser-safe Supabase/Auth connection foundation;
- connected Admin and Planning workbenches through Confirmed Need release;
- Storybook and UI Review Export;
- an existing shared component module and broad common stylesheet;
- repeated state, evidence, action and responsive-table patterns across module workbenches;
- no approved hosted Atlas project, production binding or staging data package.

## 3. OPS_SYSTEM_MAP placement

| Layer | ATLAS-ACT-01 placement |
| --- | --- |
| Mission | Make the implemented Atlas path reviewable by real operators without risking OPS v1 continuity. |
| Business capability | Hosted staging activation; operator-experience standardization; staging rehearsal and certification. |
| Business domain | Cross-domain platform capability supporting Admin and Planning first. No business-domain ownership moves. |
| Business object | Environment identity, deployment release, staging Actor/capability assignment, rehearsal dataset, UI component contract and workbench acceptance record. |
| Business contract | This contract, PA-06A environment/connection authority, existing domain/API contracts and the UI quality standard. |
| Command/event | No new business command or event. Deployment and UI work preserve existing command contracts. |
| Read model | Existing read APIs only. UI consolidation may reshape presentation but not backend responses. |
| Application | Existing Atlas shell and connected workbenches, reviewed in staging. |
| Technology | Separate Supabase project, repository migrations, protected GitHub Environment, browser-safe configuration, React/TypeScript/CSS/Storybook and existing CI. |

## 4. Environment model

### 4.1 Local

Local remains the implementation and deterministic acceptance environment:

- repository-pinned Supabase CLI and migrations;
- disposable synthetic Auth users and data;
- all registered pgTAP suites;
- browser-key acceptance journeys;
- no hosted credential requirement;
- complete reset before and after fixture-driven verification.

### 4.2 Atlas staging

Atlas staging is one separate long-lived hosted Supabase project.

Purpose:

- shared authenticated review;
- migration rehearsal;
- RLS/Auth verification;
- operator acceptance of existing connected capabilities;
- no production operations.

Allowed content:

- exact repository migration history;
- staging-only Auth identities;
- reviewed Atlas Actor mappings, roles, capabilities and scopes;
- approved master/reference data;
- approved Planning policy revisions;
- deterministic synthetic or explicitly approved masked rehearsal records;
- no live OPS v1 operational records by default.

Project creation is a cost-incurring external action. Current cost and organization must be retrieved and explicitly confirmed immediately before creation.

### 4.3 Atlas production

Production remains unselected and unauthorized.

This phase does not create it, choose its region, assign production Actors, migrate legacy data or define cutover.

### 4.4 Live OPS v1

The existing OPS project and Retool applications continue unchanged.

Atlas staging tooling must not:

- use project reference `qnthofvccilhnefdcxnz`;
- apply Atlas migrations to that project;
- add Atlas schemas, roles, Auth identities, grants or policies there;
- redirect Retool queries;
- write `public` or `ops_v2` objects;
- introduce dual write or browser-side synchronization.

## 5. Environment identity and browser configuration

Future repository staging readiness uses exactly:

```text
VITE_ATLAS_ENVIRONMENT
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

Initially allowed environment values:

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
- browser code receives no service-role, secret, management, database or JWT credential;
- the active environment is visibly labeled in the Atlas shell;
- the Supabase Auth subject remains the only browser authority for `requested_by_auth_subject`.

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

Repositories contain names only, never values.

The deployment safety check must:

1. require the `atlas-staging` GitHub Environment;
2. require explicit manual dispatch initially;
3. require the target project reference to equal the approved Atlas staging reference;
4. explicitly reject `qnthofvccilhnefdcxnz`;
5. run complete local integration acceptance before hosted action;
6. stop if migration history, checkout or target identity is inconsistent;
7. redact tokens, passwords, connection strings, JWTs and keys.

## 7. Migration, Data API and rollback contract

Repository migrations remain the sole Atlas schema authority. Manual Dashboard DDL is prohibited.

Initial deployment sequence:

```text
reviewed repository main
→ complete local reset and acceptance
→ explicit staging target verification
→ repository migration deployment
→ read-only hosted catalog/security verification
→ authenticated staging acceptance
```

A failed deployed migration is corrected by a reviewed forward migration. Migration history and committed evidence are not deleted or rewritten as an ordinary rollback.

The new project must verify:

- `atlas_api` is the intended browser-callable schema;
- private Atlas schemas are unavailable to browser roles;
- function execute grants and revokes match repository authority;
- forced RLS and revoke-first private relations are preserved;
- direct browser table access is not added to close a missing read.

## 8. Staging data packages

Staging activation separates four governed packages:

1. **Identity package** — staging Auth users, Actor mappings, roles, capabilities and scopes.
2. **Reference package** — approved Units, Schools/customers, locations, Ingredients, suppliers, dishes and other required master data.
3. **Policy package** — approved Planning policy roots and revisions.
4. **Rehearsal package** — synthetic or explicitly approved masked transactional scenarios.

No package is hidden inside frontend code or automatic global local seeds.

Each package must be version-controlled or generated from a reviewed source, environment-qualified, safe to report and idempotent or explicitly single-use.

Production data migration is outside ATLAS-ACT-01.

## 9. Hosted acceptance gate

Atlas staging is accepted only when all required evidence passes.

### Platform and security

- project identity and region match the accepted staging record;
- database health is normal;
- every repository migration is applied exactly once;
- expected schemas, relations, functions, roles, policies and grants match repository authority;
- `atlas_api` is exposed as intended;
- private relations remain unavailable to `anon` and `authenticated`;
- management credentials are absent from browser bundles, logs and artifacts;
- the live OPS project has no Atlas object because of the activation.

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

The UI program improves existing capabilities; it does not redesign business ownership.

Atlas remains a compact daily operations workbench. OPS v1 is a workflow-density reference, not a visual template.

Rules:

- add no external UI framework or design-system dependency in the first pass;
- consolidate reusable local React components and CSS tokens;
- preserve API calls, backend authority and lifecycle behavior;
- show one authoritative current state with history separate;
- use backend-provided eligibility and safe messages;
- keep dense tables inside bounded responsive containers;
- improve keyboard, focus, semantics, contrast and narrow-screen behavior;
- use Vietnamese operator language consistently;
- certify through Storybook, component tests and UI Review Export.

The canonical details are in [Atlas UI Quality Standard](../ui/atlas-ui-quality-standard.md).

## 11. UI implementation sequence

1. **UI-QUALITY-01 — Shared shell and primitives**
   - tokens, workbench headers, panels, notices, action groups, status chips, form shells, dialogs, operational states, evidence summaries, timeline and responsive table wrapper;
   - shell plus one representative Planning wrapper prove the primitives;
   - no full module migration.
2. **UI-QUALITY-02 — Planning Inputs and Confirmed Need**
   - Weekly Menu, Attendance, Pantry, Readiness, Need Generation and Confirmed Need;
   - preserve connected backend behavior.
3. **UI-QUALITY-03 — Admin master data**
   - Schools, Ingredients/Suppliers and Dishes/Recipes.
4. **UI-QUALITY-04 — Other existing prototypes**
   - Procurement, Warehouse, Dispatch and Evidence presentation only.
5. **UI-QUALITY-05 — Cross-module certification**
   - accessibility, responsive review, language consistency and operator walkthrough.

Each slice uses an exact changed-path manifest and has zero business migration/API delta.

## 12. Phase gate before downstream expansion

CMD-03 architecture may resume only after:

- ATLAS-ACT-01B repository staging readiness is merged;
- the separate Atlas staging project exists and migration acceptance passes;
- approved staging identity/reference/policy/rehearsal packages are installed;
- UI-QUALITY-01 and UI-QUALITY-02 are merged;
- the Admin-to-Confirmed-Need-release rehearsal passes;
- material security and operator blockers are resolved or explicitly accepted.

The gate may be amended only by an explicit Product/Architecture decision.

## 13. Authorized follow-on packages

After this architecture is independently accepted and merged, separate authorization is required for:

- [ATLAS-ACT-01B — Hosted Staging Repository Readiness](../implementation-tasks/TASK-ATLAS-ACT-01B-hosted-staging-readiness.md);
- external Atlas staging project creation and activation after current-cost confirmation;
- [UI-QUALITY-01 — Shared Shell and Primitives](../implementation-tasks/TASK-UI-QUALITY-01-shared-shell-primitives.md);
- later UI-QUALITY-02/03/04/05 handoffs derived from the accepted standard and preceding implementation evidence.

ATLAS-ACT-01B and UI-QUALITY-01 may proceed in either order after acceptance, but remain separate PRs.

## 14. Explicit exclusions

ATLAS-ACT-01A creates no executable resource. It excludes:

- Supabase project or branch creation;
- cost confirmation;
- migration deployment or hosted linking;
- hosted Auth users or capability bindings;
- production or masked-data extraction;
- Retool, OPS v1 or OPS v2 changes;
- Edge Function deployment;
- production Atlas selection or cutover;
- React/CSS implementation;
- CMD-03 or Purchase Handoff creation;
- supplier allocation or purchase orders;
- Procurement, Warehouse or Dispatch business mutation;
- new business APIs, states, events or read models;
- a new UI framework;
- generic workflow, task, notification or case-management infrastructure.

## 15. Acceptance procedure

The documentation PR remains draft until independent Product/Architecture review confirms:

- the separate-project topology and live OPS denylist;
- the environment, protected-name and deployment boundaries;
- staging data-package ownership;
- UI standard and sequencing;
- measurable CMD-03 resume gate;
- internal document consistency and factual evidence.

After acceptance, the roadmap and decision register are synchronized on the accepted exact head before merge or in a bounded acceptance correction.