# HOSTED-PLANNING-REHEARSAL-01A — Atlas Staging Identity and Foundation packages

**Status:** Implementation pending root review; packages are not installed

**Baseline:** `d57fdc01adf5afe89a1e57527db399c93cb37aa2`

**Approved hosted target:** Atlas Staging `rnzxmxiiqgtdevzregff`

## 1. Ownership and boundary

This task implements two explicit, repository-owned, separately invokable packages:

1. `atlas-staging-identity@1.0.0`
2. `atlas-staging-foundation@1.1.0`

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

| Record                               | Deterministic identity                                                                   | Reason                                                                                                           |
| ------------------------------------ | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| Customer                             | `atlas-staging-school-customer`                                                          | Owns the synthetic School and Delivery Location under the accepted School-catering model.                        |
| Delivery Location                    | `atlas-staging-kitchen`                                                                  | Required default location for the School and scoped Planning context.                                            |
| School Type                          | `atlas_staging_school`                                                                   | Supplies the accepted School classification relationship.                                                        |
| School                               | `atlas_staging_school`                                                                   | Provides the one Planning context; both portion defaults are initialized to zero for later operator preparation. |
| Unit                                 | `kg` / MASS / scale 6                                                                    | Required authoritative quantity unit for Ingredients, recipes, Planning, and policy resolution.                  |
| Pantry Purpose                       | `school_requested_supplement`                                                            | Accepted optional-note Pantry classification.                                                                    |
| Pantry Purpose                       | `planning_identified_supplement`                                                         | Accepted optional-note Pantry classification.                                                                    |
| Planning policy                      | revision 1, step `0.010000` kg, effective `2026-01-01`, ACTIVE                           | Minimum accepted H1A quantity policy for Need Generation and Confirmed Need calculations.                        |
| Need Generation calculation contract | `a1020000-0000-4000-8000-000000000230` / revision `a1020000-0000-4000-8000-000000000231` | Fixed approved H0A5b proportional calculation prerequisite required by normal Need Generation execution.         |

The package also verifies, but does not own or duplicate, the migration-owned active catalog codes `khac`, `daily_other`, and `savory`.

The H1A policy revision follows the approved lifecycle even during reconciliation: a missing deterministic revision is inserted as `DRAFT` and then activated with complete approval and activation evidence in the same transaction. Replay accepts the exact resulting `ACTIVE` row; any conflicting identity, payload, lifecycle, or evidence fails closed.

The Need Generation calculation root and immutable revision are Foundation-managed reference authority, not migration seed data. Revision 1 binds the exact accepted formula, precision, scales, and PostgreSQL coercion to the protected synthetic staging Actor. The root and revision use deterministic Foundation identities, exact deterministic approval evidence, insert-if-absent reconciliation, and exact-match replay. A conflicting root identity/natural key or revision identity/payload/approval binding fails closed; unrelated hosted state remains untouched.

## 4. Foundation reference versus rehearsal-authored facts

**Foundation reference:** the Customer/School/default-location backbone, School Type, `kg` Unit, two accepted Pantry purposes, active H1A Planning policy, and the fixed H0A5b Need Generation calculation-contract root/revision above. For a missing School, Foundation supplies the initial `0` Student / `0` Teacher portion defaults. After creation, those two fields are operator-owned School business state through `RMVP-01.v1`/`RMVP-01.v2`; Foundation replay neither verifies them against the initial values nor updates them, advances the School version, or creates School change evidence.

**Rehearsal-authored business facts:** Ingredient, Supplier, ingredient-supplier priority, Dish, Recipe/BOM, non-zero School portion defaults, Weekly Menu, Attendance, Pantry batch, Planning Input evaluation, Need Generation run, and Confirmed Need decisions/release. These remain absent so, after package installation and hosted verification establish the prerequisite state and ATLAS-STAGING-UI-ACCESS-01 publishes the controlled connected frontend, HOSTED-PLANNING-REHEARSAL-01B can prove the connected operator workflows instead of consuming a pre-baked success path.

Purchase Handoff, supplier allocation, CMD-03, purchase orders, Warehouse, Dispatch, Production, and Finance facts are outside both packages and outside the later rehearsal boundary.

## 5. Replay and conflict behavior

Both manifests use deterministic UUIDs, `environment: staging`, and the exact approved project reference. Identity remains version `1.0.0`; Foundation is version `1.1.0` because its managed calculation contract, School replay ownership, and Pantry note policy materially changed. Reconciliation is insert-if-absent and exact-match-if-present:

- an identical package replay is accepted;
- an identifier or natural-key collision fails closed;
- a managed Foundation-owned row content, status, membership, capability, or scope mismatch fails closed; an existing School's operator-owned Student/Teacher portion defaults are deliberately excluded from Foundation exact-match checks;
- the Identity runner updates only its one matching deterministic Auth user so the protected password can be rotated;
- capabilities must already exist and be active; the package does not create capability catalog rows; and
- no package path deletes, truncates, resets, or broadly updates Atlas history.

Foundation `1.1.0` creates both managed Pantry purposes as `OPTIONAL`. It may update only the exact legacy Foundation `REQUIRED` version-1 rows, and only while neither live Pantry lines nor approval-snapshot lines reference them. The existing guard advances each row to version 2 and preserves its identity, code, creation evidence, and history. Current OPTIONAL rows replay without another update; any unexpected content, note rule, lineage, or reference state fails closed. Purpose row version is lineage evidence, not package identity.

The read-only verifiers mirror reconciliation ownership. Identity verification proves deterministic Actor/Auth mapping/Role/membership/GLOBAL-scope identities, grant/reason evidence, all deterministic bindings, and exactly the reviewed 15 active capability codes. Foundation verification proves every managed Customer, Location, School Type, School, Unit, Pantry Purpose, H1A policy, and H0A5b calculation-contract field while deliberately excluding operator-owned School portions and transaction-generated School version/timestamps.

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
4. proves a fresh Foundation install creates OPTIONAL Pantry purposes at version 1, rolls that probe back, installs exact legacy REQUIRED version-1 purposes, proves conflicting calculation-contract state fails closed, then proves Foundation transitions those purposes once to OPTIONAL version 2 and creates the School at `0` Student / `0` Teacher, version `1`;
5. uses the authoritative `RMVP-01.v2` bulk School-default workflow to change the managed School to `100` Student / `10` Teacher, version `2`, with its one legitimate domain/audit evidence pair;
6. installs isolated local-only Weekly Menu, Attendance, and Pantry root fixtures solely to model the already-authorized hosted fact-preservation boundary, snapshots their complete rows, then replays Foundation twice;
7. proves both replays preserve the complete School and source rows, School version `2`, and the existing School evidence count; preserve exactly one calculation-contract root/revision with exact deterministic binding; and create no Planning Input, Need Generation, Confirmed Need decision/release, Purchase Handoff, Procurement, Warehouse, or Dispatch fact;
8. proves omitted capability bindings and anonymous `atlas_api` denial; and
9. signs in through the browser key and requires a successful `get_school_master_data` response containing exactly the managed School.

Focused unit tests additionally cover manifest authority, verifier parity, the exact H0A5b calculation contract and deterministic identities, Pantry transition guards, target drift, live-target rejection through the shared guard, credential absence, insert-only Identity SQL, bounded Foundation SQL with the required H1A `DRAFT`-to-`ACTIVE` transition, calculation-contract root/revision conflict checks, Auth first-run/replay/conflict behavior, exact merged-main checkout, and process/network-free dry-run. The React Pantry write adapter maps blank or whitespace-only notes to `null` and trims meaningful notes for both Preview and Save; backend REQUIRED and PROHIBITED validation remains unchanged.

`pnpm local:planning-assembly:verify` is the one-reset assembled acceptance. Its only fixtures are synthetic operator input values and the temporary JSON baseline used to compare replay state; migrations and the Identity/Foundation packages create platform/reference prerequisites, and public APIs create School configuration, Admin facts, Recipe/BOM, completed Planning sources, Need Generation, and Confirmed Need decisions/release. It proves the #213 initial Recipe Save activation, #215 +30-second Attendance completion plus beyond-tolerance rejection, positive OPTIONAL Pantry null-note behavior, exact PostgreSQL calculation output, downstream exclusion, and a final Foundation replay that leaves all business and audit/history rows byte-for-byte unchanged.

Repository-only evidence on 2026-08-18: clean local certification passed all 44 migrations plus Identity and Foundation first-install/replay, exact-state verification, anonymous denial, authenticated School read, and rehearsal-fact exclusion. The H1A lifecycle (50), H1A effectivity (44), platform security catalog (22), and School/Customer/Location foundation (56) pgTAP suites passed all 172 assertions on a separate fresh reset. The complete Vitest run passed 71/71 files and 561/561 tests, followed by a final 13/13 focused package pass including the split-query regression case. TypeScript, formatting, production build, and `git diff --check` passed. No hosted package command was executed.

A final connected read-only hosted recheck on 2026-08-18 found Atlas Staging unchanged at 44 migrations (newest `20260817045218`), 10 Atlas schemas, 105 Atlas relations, 90 `atlas_api` functions, 27 capabilities, zero Auth users, zero Actors/roles/memberships/scopes, zero named Admin business rows, and zero Edge Functions. Live OPS remained at zero Atlas schemas/relations/functions and 46 public base tables. No hosted package command was executed. Full routine frontend validation remains owned by GitHub Actions; the private-repository billing constraint must not be used to weaken either required workflow.

## 8. Future hosted installation

No hosted package command is executed by this task. After root acceptance, merge, successful mandatory local certification, and separate hosted-mutation authorization, install Identity before Foundation from a clean exact merged-main checkout:

```text
pnpm atlas:staging:identity:install -- --commit-sha <exact-merged-main-sha>
pnpm atlas:staging:foundation:install -- --commit-sha <exact-merged-main-sha>
pnpm atlas:staging:verify
```

The default verifier is read-only and then requires the exact managed package state plus authenticated School read. Before package installation, `pnpm atlas:staging:verify -- --platform-only` preserves the aligned zero-role platform check.

The authoritative post-merge sequence is:

```text
protected Identity installation
→ protected Foundation installation
→ read-only atlas:staging:verify
→ ATLAS-STAGING-UI-ACCESS-01
→ HOSTED-PLANNING-REHEARSAL-01B
→ explicit Product/Architecture decision on CMD-03
```

GitHub Actions exact-head certification is not an unconditional 01A installation prerequisite. It may be required later only by a separate explicit root instruction. The private-repository billing constraint therefore does not block the authorized package-installation sequence once mandatory local certification, merge, and hosted-mutation authorization are complete.

## 9. Incident and rollback approach

Any unexpected hosted identity, natural-key collision, managed-row mismatch, target mismatch, migration/catalog drift, or credential diagnostic is a stop condition. Do not retry an unknown write, delete Auth users, truncate data, edit hosted rows manually, or repair migration history. Preserve sanitized evidence and escalate to root review. A database correction requires a separately reviewed forward corrective change; an Auth correction requires explicit bounded operator authorization. Project pause/deletion remains Product Owner and Supabase organization-owner responsibility.

## 10. Explicit exclusions

This change includes no business migration, React authority, API/Product contract, capability, lifecycle, Edge Function, hosted deployment, hosted package installation, hosted rehearsal, live OPS mutation, Retool mutation, or repository visibility change. It does not mark HOSTED-PLANNING-REHEARSAL-01 complete.
