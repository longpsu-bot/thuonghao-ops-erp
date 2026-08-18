# HOSTED-PLANNING-REHEARSAL-01A — Atlas Staging Identity and Foundation packages

**Status:** Implementation pending root review; packages are not installed

**Baseline:** `b16689ade8f6a4b3b2e16e4910ed10c34b57fb6d`

**Approved hosted target:** Atlas Staging `rnzxmxiiqgtdevzregff`

## 1. Ownership and boundary

This task implements two explicit, repository-owned, separately invokable packages:

1. `atlas-staging-identity@1.0.0`
2. `atlas-staging-foundation@1.0.0`

They establish only the identity and prerequisite reference state needed for a later connected Admin-to-Confirmed-Need rehearsal. They are not migrations, seeds, React fixtures, Retool imports, or a synthetic rehearsal package. Repository migrations remain schema authority; the package manifests own only their named deterministic staging records.

## 2. Identity package

The Identity package manages:

- one protected synthetic Supabase Auth user whose email and password come from `ATLAS_STAGING_TEST_EMAIL` and `ATLAS_STAGING_TEST_PASSWORD`;
- one active HUMAN Actor and one active Supabase Auth-subject mapping;
- one active `atlas_staging_admin_planning_operator` role and one active membership;
- one active `GLOBAL` scope; and
- exactly these 15 existing active capabilities:

  - `master_data.read`
  - `master_data.schools.write`
  - `master_data.ingredients.write`
  - `master_data.suppliers.write`
  - `master_data.priorities.write`
  - `master_data.recipes.read`
  - `master_data.recipes.write`
  - `planning.inputs.read`
  - `planning.weekly_menu.write`
  - `planning.attendance.write`
  - `planning.pantry.write`
  - `planning.need_generation.write`
  - `confirmed_need_review.read`
  - `confirmed_need_quantities.confirm`
  - `confirmed_need_release.release`

The current connected Admin and Planning APIs authorize these workflows through an existing `GLOBAL` scope. One global row is therefore the smallest contract-compatible scope bundle; duplicating Customer, School, or Delivery Location scopes would not reduce the authority used by those APIs. Capabilities for imports, adjustment governance, legacy lifecycle operations, Confirmed Need approval, and downstream materialization are deliberately omitted. Later security rehearsal can prove denial by using one of those omitted capabilities or by separately changing the synthetic scope under an approved bounded procedure; this package itself does not invent a denial-only identity.

The server-only `ATLAS_STAGING_SUPABASE_SECRET_KEY` is used only by the package runner's Auth Admin client. It is never returned to browser code, stored in a manifest, placed in a command argument, or printed.

## 3. Foundation reference package

The Foundation package manages these exact synthetic prerequisites:

| Record            | Deterministic identity                                         | Reason                                                                                               |
| ----------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Customer          | `atlas-staging-school-customer`                                | Owns the synthetic School and Delivery Location under the accepted School-catering model.            |
| Delivery Location | `atlas-staging-kitchen`                                        | Required default location for the School and scoped Planning context.                                |
| School Type       | `atlas_staging_school`                                         | Supplies the accepted School classification relationship.                                            |
| School            | `atlas_staging_school`                                         | Provides the one Planning context; both portion defaults remain zero for later operator preparation. |
| Unit              | `kg` / MASS / scale 6                                          | Required authoritative quantity unit for Ingredients, recipes, Planning, and policy resolution.      |
| Pantry Purpose    | `school_requested_supplement`                                  | Accepted required-note Pantry classification.                                                        |
| Pantry Purpose    | `planning_identified_supplement`                               | Accepted required-note Pantry classification.                                                        |
| Planning policy   | revision 1, step `0.010000` kg, effective `2026-01-01`, ACTIVE | Minimum accepted H1A quantity policy for Need Generation and Confirmed Need calculations.            |

The package also verifies, but does not own or duplicate, the migration-owned active catalog codes `khac`, `daily_other`, and `savory`.

## 4. Foundation reference versus rehearsal-authored facts

**Foundation reference:** the Customer/School/default-location backbone, School Type, `kg` Unit, two accepted Pantry purposes, and active H1A Planning policy above.

**Rehearsal-authored business facts:** Ingredient, Supplier, ingredient-supplier priority, Dish, Recipe/BOM, non-zero School portion defaults, Weekly Menu, Attendance, Pantry batch, Planning Input evaluation, Need Generation run, and Confirmed Need decisions/release. These remain absent so HOSTED-PLANNING-REHEARSAL-01B can prove the connected operator workflows instead of consuming a pre-baked success path.

Purchase Handoff, supplier allocation, CMD-03, purchase orders, Warehouse, Dispatch, Production, and Finance facts are outside both packages and outside the later rehearsal boundary.

## 5. Replay and conflict behavior

Both manifests use deterministic UUIDs, version `1.0.0`, `environment: staging`, and the exact approved project reference. Reconciliation is insert-if-absent and exact-match-if-present:

- an identical package replay is accepted;
- an identifier or natural-key collision fails closed;
- a managed-row content, status, membership, capability, or scope mismatch fails closed;
- the Identity runner updates only its one matching deterministic Auth user so the protected password can be rotated;
- capabilities must already exist and be active; the package does not create capability catalog rows; and
- no package path deletes, truncates, resets, or broadly updates Atlas history.

## 6. Target and checkout guards

The runner reuses the accepted staging environment reader and live-target denylist, then adds an exact approved-project qualification. Actual hosted installation requires:

- explicit `staging` mode;
- protected project reference and matching HTTPS URL;
- exact project `rnzxmxiiqgtdevzregff` and rejection of live OPS `qnthofvccilhnefdcxnz`;
- required protected browser, management, database, test, and Identity server credentials;
- a full requested commit SHA equal to `HEAD`;
- that commit contained in `origin/main`; and
- a clean worktree.

Failures pass through the shared redactor for supplied protected values, JWT-like values, Supabase secret/publishable keys, bearer tokens, and PostgreSQL URLs. Dry-run validates the qualified package and performs no process, Auth, or network action.

## 7. Local certification contract

`pnpm local:staging-packages:certify` is the deterministic local-only certification command. It requires an `@local.test` email and local-only password through the same two protected variable names. It:

1. resets all repository migrations locally with no seed;
2. proves the identity/foundation baseline is empty;
3. reconciles Identity, verifies exact state, and replays it;
4. reconciles Foundation, verifies exact state, and replays it;
5. proves omitted capability bindings and absence of operator-authored/downstream facts;
6. proves anonymous `atlas_api` denial; and
7. signs in through the browser key and requires a successful `get_school_master_data` response containing exactly the managed School.

Focused unit tests additionally cover manifest authority, target drift, live-target rejection through the shared guard, credential absence, insert-only SQL shape, Auth first-run/replay/conflict behavior, exact merged-main checkout, and process/network-free dry-run.

Repository-only evidence on 2026-08-18: the focused package and staging-contract suites passed 45/45; TypeScript and the production build passed; formatting and `git diff --check` passed. The complete Vitest run passed 556/558 but two unrelated Admin UI tests failed under the long concurrent run; each exact failing test passed immediately when rerun alone. Clean database certification could not start because Docker Desktop failed before exposing its Linux engine (`initializing Inference manager` against its local `dockerInference` socket). This task did not delete that host runtime socket, reset Docker, or weaken certification. The local package command remains mandatory before root acceptance or hosted installation.

A final connected read-only hosted recheck on 2026-08-18 found Atlas Staging unchanged at 44 migrations (newest `20260817045218`), 10 Atlas schemas, 105 Atlas relations, 90 `atlas_api` functions, 27 capabilities, zero Auth users, zero Actors/roles/memberships/scopes, zero named Admin business rows, and zero Edge Functions. Live OPS remained at zero Atlas schemas/relations/functions and 46 public base tables. No hosted package command was executed. Full routine frontend validation remains owned by GitHub Actions; the private-repository billing constraint must not be used to weaken either required workflow.

## 8. Future hosted installation

No hosted package command is executed by this task. After root acceptance, merge, exact-head CI certification, and separate hosted-mutation authorization, install Identity before Foundation from a clean exact merged-main checkout:

```text
pnpm atlas:staging:identity:install -- --commit-sha <exact-merged-main-sha>
pnpm atlas:staging:foundation:install -- --commit-sha <exact-merged-main-sha>
pnpm atlas:staging:verify
```

The default verifier is read-only and then requires the exact managed package state plus authenticated School read. Before package installation, `pnpm atlas:staging:verify -- --platform-only` preserves the aligned zero-role platform check.

## 9. Incident and rollback approach

Any unexpected hosted identity, natural-key collision, managed-row mismatch, target mismatch, migration/catalog drift, or credential diagnostic is a stop condition. Do not retry an unknown write, delete Auth users, truncate data, edit hosted rows manually, or repair migration history. Preserve sanitized evidence and escalate to root review. A database correction requires a separately reviewed forward corrective change; an Auth correction requires explicit bounded operator authorization. Project pause/deletion remains Product Owner and Supabase organization-owner responsibility.

## 10. Explicit exclusions

This change includes no business migration, React authority, API/Product contract, capability, lifecycle, Edge Function, hosted deployment, hosted package installation, hosted rehearsal, live OPS mutation, Retool mutation, or repository visibility change. It does not mark HOSTED-PLANNING-REHEARSAL-01 complete.
