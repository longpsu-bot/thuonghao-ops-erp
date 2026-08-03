# TASK-RMVP-04 — Connected Need Generation

## Status

Merged through PR #168 at exact squash commit `d497c8921d64fb555baea8e207a27f63925934a7`. The implementation originated on branch `codex/rmvp-04-connected-need-generation` from PANTRY-NG-02 baseline `4cc9bddb8f77c962d2c557affee5a7d3f58e75e2`.

## Outcome

The bounded slice connects:

```text
approved Menu + Attendance + Pantry
→ exact Planning Input Readiness
→ Need Generation create / validate / release
→ existing CMD-15 materialization
```

An authenticated Planning operator receives one fifth Vietnamese internal tab, `Tạo nhu cầu`, inside Planning Inputs. The operator selects an exact inclusive period, sees readiness and source evidence, creates a backend-authoritative run, reviews grouped and atomic Recipe/Pantry contributions, sees blockers before warnings, validates, releases, invokes existing CMD-15, reads the Confirmed Need state, and can invalidate a safely correctable terminal run without deleting history.

## Database delta

One forward-only migration is added:

`supabase/migrations/20260802164523_rmvp_04_connected_need_generation.sql`

It adds exactly:

- five `RMVP-04.v1` public functions;
- capability `planning.need_generation.write`;
- dedicated `NOLOGIN NOINHERIT` role `atlas_need_generation_runtime`;
- private request, authorization, receipt, event/audit, read-shaping, and response helpers needed by this workflow;
- minimum grants and forced-RLS policies over existing authoritative evidence.

It adds zero business tables, views, lifecycle states, source/upstream triggers, sequences, source registries, formula engines, downstream operational records, or production seeds. Existing H0A5/PANTRY-NG-02 relations, triggers, and release membership are reused. The forward migration narrowly corrects the existing Confirmed Need membership guard so an initial Recipe contribution matches only its immutable captured Delivery Location instead of every destination-specific revision, while later School-default changes remain non-recalculating history. The CMD-15 calculation, request/response contract, and `PA-06E-H0C.v1` semantics are unchanged.

The same forward migration hardens the existing RMVP-03B and CMD-15 success boundaries by forcing their deferred H0A4B Planning Input and H0B1 Confirmed Need integrity checks to run before each security-definer command returns, then restoring deferred mode. This preserves the private-schema boundary for `authenticated`, keeps the guards invoker-security and `atlas_owner` owned, and changes no API envelope, calculation, lifecycle, relation, trigger, role, capability, permanent grant, or policy.

## API and security

The exact public API is documented in [RMVP-04 Connected Need Generation](../api/rmvp-04-connected-need-generation.md). The read reuses `planning.inputs.read`; writes require `planning.need_generation.write`. All five functions require authenticated human Actors, exact JWT-subject equality, active `GLOBAL` scope, revoke-first execute, fixed search paths, and backend authorization.

The dedicated runtime owns only the new API/helpers and has bounded access to readiness/source/Admin/Recipe evidence, existing H0A5 write relations, Confirmed Need/Purchase Handoff correction facts, and common receipt/event/audit relations. It has no login, inheritance, schema create, RLS bypass, public/legacy mutation, or Procurement/Warehouse/Dispatch mutation authority.

## Calculation and lineage

Creation accepts only Planning Input Set/evaluation/period identifiers. The browser cannot supply source triples, Recipe choices, quantities, line IDs, or formula inputs. The transaction locks source roots in deterministic order, rechecks current exact bindings and period coverage, selects the backend calculation contract, and creates all immutable evidence atomically.

Recipe contributions use exact approved Menu and Attendance snapshot rows, eligible released Recipe evidence, stable RecipeLine revisions, and the fixed proportional formula. Pantry contributions copy the approved direct Ingredient quantity, Unit, School, date, Delivery Location, Purpose/source lineage, and stable Pantry line. Both remain atomic. Read-model aggregation groups only by date, Customer, School, Delivery Location, Ingredient, and Unit.

Recipe selection is cardinality-exact within the approved precedence tiers. One eligible School-Type Recipe is selected even when a general Recipe exists. More than one eligible School-Type Recipe produces one `AMBIGUOUS_ELIGIBLE_RECIPE` blocker and does not evaluate the general tier for selection. When the typed tier is empty, exactly one eligible general Recipe is selected; more than one produces the same blocker. When both tiers are empty, the existing `MISSING_ELIGIBLE_RECIPE` blocker remains authoritative. An ambiguous Menu snapshot line creates no Recipe selection, Recipe-line use, or `RECIPE_DERIVED` theoretical line, while unrelated valid Recipe and Pantry lines in the same run continue to generate.

## Lifecycle and correction

Initial creation starts attempt `1`, `GENERATED`, version `1`. Validate and release each increment exactly once. Release creates immutable line and issue membership. Invalidation preserves all evidence and is allowed after release only while no released Purchase Handoff/later commitment exists and linked Confirmed Need remains `DRAFT_REVIEW` or `REOPENED`. A later create binds the direct invalidated predecessor and advances the attempt ordinal.

## Application delta

The bounded submodule is `src/modules/atlas/planning-inputs/need-generation/`:

- `needGenerationApi.ts`: five RMVP-04 calls and existing CMD-15 transport;
- `needGenerationModel.ts`: strict workbench parsing and display helpers;
- `NeedGenerationWorkbench.tsx`: Vietnamese operator journey;
- `reviewNeedGenerationApi.ts`: deterministic review-mode adapter;
- focused model, transport, workbench, and fifth-tab tests.

`PlanningInputsWorkbench.tsx` adds the fifth internal tab. `AtlasApp.tsx` injects the connected or review adapter. `atlasRpc.ts` adds only the five new APIs and existing CMD-15 to the reviewed browser registry. React displays backend quantities and action decisions; it does not calculate or edit authoritative demand.

Writes retain the exact immutable request for an explicit retry after retryable or transport-uncertain outcomes, never auto-retry, and treat an operator edit as a new intent. Stale responses clear action eligibility and trigger authoritative refresh.

## Tests

The focused pgTAP suite uses its actual assertion count and executes real approved source evidence through:

1. readiness evaluation and Need Generation request;
2. mixed Recipe/Pantry atomic generation;
3. grouped separation by date, Delivery Location, Ingredient, and Unit;
4. exact blocker/warning counts;
5. validate and release membership;
6. existing CMD-15 quantities, destinations, and memberships;
7. exact replay and changed-intent conflict;
8. capability, scope, anonymous, and service-role denial;
9. released-run invalidation and a direct successor with preserved history.
10. in-runtime H0A4B deferred-integrity flushing before PostgREST commit.
11. in-runtime CMD-15/H0B1 deferred-integrity flushing before PostgREST commit.
12. exact typed-tier ambiguity with a general candidate ignored, one typed blocker, no ambiguous Recipe lineage, unaffected Recipe/Pantry generation, and blocked validation.
13. exact general-tier ambiguity when no typed candidate exists, with the same blocker, lineage, unaffected-generation, and validation guarantees.

Focused frontend tests cover fifth-tab integration, exact period, readiness-not-requested state, happy-path actions, issue ordering, grouped quantities and destination separation, filters/pagination, atomic detail, disabled reasons, exact retry, stale refresh, and review mode.

The GitHub-only browser-key script uses the disposable local synthetic identity and performs readiness → request → create → validate → release → CMD-15 → authoritative readback. A local-only calculation-contract fixture is installed for that disposable acceptance database; it is not a production seed.

## Validation ownership

Local validation is limited to workspace verification, formatting, TypeScript, focused frontend tests, static SQL/surface inspection, `git diff --check`, and exact manifest review. No local Supabase start/reset, pgTAP, full frontend suite, hosted deployment, or hosted mutation is authorized.

GitHub owns Supabase integration. Draft pull-request opens, synchronizations, and reopens run the bounded `Supabase Smoke`: fresh seedless reset, the platform security catalog, the current focused task's pgTAP, deterministic current-task browser fixture, and short current-task browser journey. For PR #169 the focused task is RMVP-05; draft smoke does not execute standalone H1A, H1B1, RMVP-04, or the complete upstream browser journey. `ready_for_review`, later non-draft synchronizations, manual dispatches, and pushes to `main` run `Supabase Full Integration`: fresh seedless reset, every registered pgTAP suite, all required browser journeys, and the complete RMVP-04 readiness/generation/release → CMD-15 materialization → RMVP-05 review/preview/confirmation/readback chain. Frontend CI, UI Review Export, and Qodana remain independently required.

## Deferred boundary

RMVP-04 stops at released Need Generation and existing CMD-15 Draft Review materialization. The separately authorized [RMVP-05](TASK-RMVP-05-connected-confirmed-need-review.md) draft implements Planning quantity confirmation without changing RMVP-04. Supplier assignment, Purchase Handoff release, Procurement, Warehouse, Dispatch, hosted Supabase, Retool, production data, credentials, and deployment remain unchanged and separately authorized.
