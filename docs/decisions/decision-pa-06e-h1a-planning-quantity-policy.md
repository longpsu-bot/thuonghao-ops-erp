# Decision PA-06E-H1A - Planning Quantity Policy

**Status:** Product-decision preparation; every H1A-P01 through H1A-P10 recommendation is `PENDING_PRODUCT_OWNER_APPROVAL`

**Issue:** [#145](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/145)

**Exact preparation baseline:** `5987f1fc9711b7bde094a610e598ff92d71e850d`

**Future implementation task:** [TASK-PA-06E-H1A - Planning Quantity Policy Persistence](../implementation-tasks/TASK-PA-06E-H1A-planning-quantity-policy-persistence.md)

**Parent contract:** [PA-06E - Confirmed Need Review, Adjustment, Revision, and Source Correction](../architecture/pa-06e-confirmed-need-review-adjustment-revision-contract.md)

**Quantity authority:** [PA-06D - Quantity Truth, Precision, Rounding, Rebalancing, and Write Fidelity](../architecture/pa-06d-quantity-truth-rounding-rebalancing-contract.md)

## 1. Decision outcome and approval gate

The recommended first school-catering slice uses one Planning-owned `PlanningQuantityPolicy` root for one exact controlled Unit and immutable-after-activation `PlanningQuantityPolicyRevision` records. It has no Unit-dimension default, contextual override, conversion, or guessed fallback.

The business path is:

```text
Raw Calculated Requirement
-> H0C non-authoritative Draft proposal
-> effective Planning Quantity Policy Revision
-> future H1B2 authoritative preview
-> explicit Planning confirmation
```

Planning owns the operational confirmation meaning and approves policy revisions. Admin / Master Data may record and administer an approved revision. Engineering is not the business policy owner. The first slice recommends one accountable Planning approval authority; it does not require two distinct approvers or invent production role assignments.

All ten product decisions below remain pending. In particular, the following candidate values are not production policy and must not be seeded:

```text
0.01 kg for the exact controlled kilogram Unit
1 for each explicitly governed indivisible/count Unit
no fallback for another Unit without an explicit policy
```

The future H1A SQL task, H1B1, and H1B2 remain unapproved until the product owner explicitly accepts the required decisions in Issue #145 or its draft pull request.

## 2. OPS_SYSTEM_MAP placement

| Layer               | H1A placement                                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Mission             | Preserve explainable operational quantities without hidden precision changes.                                          |
| Business Capability | Govern the smallest meaningful increment that Planning may explicitly confirm for one controlled Unit.                 |
| Business Domain     | Planning owns policy meaning and revision approval; Admin / Master Data may administer an approved record.             |
| Business Object     | Stable `PlanningQuantityPolicy` and versioned `PlanningQuantityPolicyRevision`.                                        |
| Business Contract   | This decision, PA-06E, PA-06D, the controlled Unit contract, and PA-03 security conventions.                           |
| Command / Event     | None in H1A. Future administration and H1B2 commands require separate approval.                                        |
| Read Model          | None in H1A. Future H1B2 resolves an exact revision inside its authoritative preview/commit path.                      |
| Application         | None in H1A.                                                                                                           |
| Technology          | Two private `atlas_planning` relations, bounded guards, forced RLS, no browser access, and rolled-back pgTAP fixtures. |

H1A is not a generic policy engine, rule engine, or table-driven workflow framework.

## 3. Canonical H1A product-decision registry

This is the sole complete H1A-P01 through H1A-P10 registry. Other documents may summarize or link to this table but must not reproduce it.

| Decision ID | Question                                                                                | Relevant evidence                                                                                                                                                                               | Alternatives                                                                                                                                      | Recommendation                                                                                                                                                                                                                                                                                                                                                                                       | Accepted consequence if approved                                                                                                                                                                   | Excluded behavior                                                                                                                                  | Approval status                  | Implementation impact                                                                                                              |
| ----------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| H1A-P01     | Who owns and administers Planning quantity policy, and are two approval roles required? | ARCH-002 assigns Confirmed Need to Planning; PA-06D separates Planning steps from Procurement steps; repository master-data foundations use typed private references.                           | Planning ownership; Admin ownership; Engineering ownership; one Planning approval authority; mandatory two-person approval.                       | Planning owns meaning and approves each revision. Admin / Master Data may record and administer approved facts. Use one accountable Planning approval authority in the first slice; do not require two distinct approvers and do not assign production roles here.                                                                                                                                   | Business accountability stays with Planning while record administration may be delegated without transferring ownership. Approval actor/time and administration actor/time remain distinguishable. | Engineering-owned policy; inferred approval; invented production roles; mandatory separation of duties without a business requirement.             | `PENDING_PRODUCT_OWNER_APPROVAL` | Persist typed actor references on revisions. Add no role, capability, membership, runtime, command, or API in H1A.                 |
| H1A-P02     | What is the minimum typed policy scope?                                                 | H0B1b stable identity contains exact controlled `unit_id`; H0A5b/H0C require source Unit = controlled Unit; Issue #145 requires the smallest deterministic model.                               | A. Exact Unit only. B. Unit-dimension default with exact-Unit override. C. Customer, School, Ingredient, supplier, or other contextual overrides. | Select A: exactly one stable policy root per exact controlled Unit.                                                                                                                                                                                                                                                                                                                                  | Every eligible quantity has one typed Unit key and no contextual precedence graph. Additional Units require explicit policy roots.                                                                 | Dimension/global default; Customer, School, Ingredient, supplier, destination, actor-scope, or UI-context override; polymorphic scope identifiers. | `PENDING_PRODUCT_OWNER_APPROVAL` | Create one root relation with a unique typed `unit_id`; do not add scope-kind or scope-ID columns.                                 |
| H1A-P03     | What is the exact precedence?                                                           | PA-06D prohibits technical ordering and implicit fallback; PA-06E requires missing/ambiguous policy to fail closed.                                                                             | Exact-Unit match only; dimension then Unit override; contextual priority; technical latest/ID order.                                              | The only precedence is one eligible revision on the one exact-Unit root. More than one eligible revision is an invariant violation; zero eligible revisions blocks.                                                                                                                                                                                                                                  | Resolution is deterministic without priority numbers or tie-breakers.                                                                                                                              | `coalesce` fallback; latest-created ordering; highest UUID/revision guess; dimension fallback; global fallback; technical tie-breaking.            | `PENDING_PRODUCT_OWNER_APPROVAL` | Enforce one root per Unit and non-overlapping eligible revision intervals. H1B2 must require exactly one result.                   |
| H1A-P04     | How does Unit taxonomy affect policy and representability?                              | `atlas_admin.units` is the controlled Unit catalog; H0A5b outputs the exact Recipe Unit; H0B1b/H0C prohibit conversion.                                                                         | Free-text dimension; dimension policy; exact controlled Unit; conversion family.                                                                  | Bind policy to the exact controlled Unit row. `kg` means that exact Unit, not any mass dimension. Each count/indivisible Unit needs its own explicit policy. Volume and every other Unit need an explicit policy before confirmation. No conversion is permitted.                                                                                                                                    | Unit meaning stays typed and corrections cannot cross Units silently. Unit dimension may inform product review but never selects policy.                                                           | Free-text Unit/dimension; mass or count fallback; Unit conversion; cross-Unit aggregation; treating `decimal_scale` as the business step.          | `PENDING_PRODUCT_OWNER_APPROVAL` | Typed restrictive FK to `atlas_admin.units`; duplicate exact Unit identity on the revision for future composite ownership checks.  |
| H1A-P05     | Which first-slice Planning steps should be governed?                                    | PA-06D and PA-06E use `0.01 kg` and `1` only as recommendations/fixtures; Issue #145 states they are unapproved.                                                                                | `0.01 kg`; `0.1 kg`; six decimals; exact unrestricted quantities; `1` for explicitly governed count Units; another product-selected value.        | Prepare `0.01 kg` for the exact kilogram Unit and `1` for each explicitly governed indivisible/count Unit; provide no policy for another Unit until explicitly approved.                                                                                                                                                                                                                             | The first slice has understandable increments while unsupported Units block rather than inherit a guess.                                                                                           | Production seed from a fixture; legacy purchase step `0.1 kg`; threshold-at-2 behavior; six-decimal operational policy; unrestricted override.     | `PENDING_PRODUCT_OWNER_APPROVAL` | H1A migration creates no policy rows. Rolled-back tests may use these values only after labeling them synthetic.                   |
| H1A-P06     | What happens to excess or nonrepresentable precision?                                   | PA-06E requires fail-closed precision handling; PA-06D separates storage precision from operational precision; H0C proposals may contain six-decimal calculation output.                        | Reject; round to nearest; ceil; truncate/trim; accept exact unrestricted override.                                                                | A proposed quantity is valid only when `quantity / planning_step` is an exact whole tick count. Reject incompatible precision with a safe field-level error; return no replacement quantity.                                                                                                                                                                                                         | Confirmation never changes the operator's value invisibly, and the persisted result can be represented exactly by ticks plus its policy revision.                                                  | Silent rounding, ceiling, truncation, trimming, epsilon comparison, `round6`, `toFixed(6)`, or client-authored normalization.                      | `PENDING_PRODUCT_OWNER_APPROVAL` | Store step as positive `numeric(20,6)`. H1B2 later performs exact PostgreSQL numeric divisibility and owns the safe error.         |
| H1A-P07     | What are the effective-time and correction semantics?                                   | PA-02 selects date-based half-open periods; Confirmed Need has an exact `service_date`; Atlas uses Asia/Bangkok business dates and preserves history.                                           | Transaction timestamp; confirmation timestamp; service date; closed intervals; half-open intervals; overlapping rules; retroactive replacement.   | Resolve policy by Confirmed Need `service_date` as an Asia/Bangkok operating date. Use `[effective_from, effective_to)` with inclusive start, exclusive optional end, `effective_to > effective_from`, and no overlap for one Unit. Approved changes take effect on a service-date boundary; do not retroactively rewrite a bound revision.                                                          | Policy resolution follows the business fact, scheduled changes are deterministic, and historical confirmations retain the revision actually used.                                                  | UTC-date truncation; transaction-time selection; inclusive end; overlap; retroactive rewrite; silent correction of historical decisions.           | `PENDING_PRODUCT_OWNER_APPROVAL` | Date columns, lifecycle guard, deferred non-overlap integrity, and H1B2 re-resolution by service date.                             |
| H1A-P08     | How are root identity, revision version, and stale binding handled?                     | H0 relations use database UUIDs and root-local revision numbers; PA-06E preview/commit requires an exact policy revision and stale rejection.                                                   | Mutable current row; stable root plus revisions; latest-revision lookup at commit; exact preview binding.                                         | Use one database-generated stable root UUID and one database-generated revision UUID with a positive root-local `revision_number` and typed predecessor. Preview binds the exact revision ID and number; commit re-resolves and rejects any different eligible revision.                                                                                                                             | Replay and audit can identify one exact policy fact, and a stale preview cannot be authorized by a newer policy.                                                                                   | Caller-generated authority; "latest" at commit; revision-number-only binding; technical ID ordering; rebinding a stale preview.                    | `PENDING_PRODUCT_OWNER_APPROVAL` | Unique root-local revision number, same-root predecessor FK, non-forking predecessor, and future `STALE_PLANNING_POLICY` behavior. |
| H1A-P09     | What is the smallest lifecycle and what may change?                                     | Atlas preserves released history and commonly freezes revision payload while allowing controlled lifecycle metadata; Issue #145 asks to compare explicit lifecycle with statusless effectivity. | `DRAFT -> ACTIVE -> RETIRED`; immutable statusless revisions; generic approval workflow.                                                          | Use the bounded lifecycle `DRAFT -> ACTIVE -> RETIRED`. Draft business fields may be corrected only before activation. Activation freezes Unit, step, start, revision identity, predecessor, and approval evidence. Retirement may set an open `effective_to` once and record retirement evidence; retired rows are fully immutable and remain historically resolvable within their closed interval. | Administration can prepare and schedule a revision while activated business meaning and history remain protected.                                                                                  | Generic workflow engine; reactivation; Active payload edit; Retired edit/delete; status inferred from row order; silent in-place step correction.  | `PENDING_PRODUCT_OWNER_APPROVAL` | One local status check plus ordinary immutability/lifecycle guard and deferred effectivity integrity trigger.                      |
| H1A-P10     | What happens when policy resolution is missing or unsafe?                               | PA-06E already requires missing/inactive/ambiguous policy failure; Issue #145 prohibits all legacy and guessed fallbacks.                                                                       | Guess default; use Unit dimension; use purchase step; use legacy precision; block.                                                                | H1B2 preview and commit block for missing root, Draft-only/inactive policy, future-only policy, expired policy, overlapping/ambiguous/tied policy, inactive Unit, nonrepresentable quantity, or stale revision binding. No guessed fallback exists.                                                                                                                                                  | Operators receive a safe, actionable blocker and no authoritative quantity or decision evidence is written.                                                                                        | `0.01`, `0.1`, `1`, six decimals, Unit dimension, purchase-step, existing-row, `coalesce`, or client fallback.                                     | `PENDING_PRODUCT_OWNER_APPROVAL` | H1A prevents overlap and exposes no resolver. H1B2 later maps exact safe errors and guarantees zero decision writes on failure.    |

The issue-directed safety boundaries already govern this preparation work, but they do not constitute product-owner approval of the ten production decisions. Approval must be explicit.

## 4. Recommended business contract

### 4.1 Business objects and responsibilities

`PlanningQuantityPolicy` is the stable Planning-owned identity for one exact controlled Unit. It owns:

- one database-generated stable identity;
- one exact `atlas_admin.units.unit_id`;
- creation actor and time; and
- the ordered family of revisions.

`PlanningQuantityPolicyRevision` is the versioned operational-step fact. It owns:

- one database-generated revision identity;
- one positive root-local revision number;
- an optional exact same-root predecessor;
- the repeated exact Unit identity;
- one positive Planning step;
- one effective service-date interval;
- bounded lifecycle and approval/activation/retirement evidence; and
- the immutable-after-activation fact that future H1B2 preview and confirmation bind.

The policy does not own purchase-order steps, supplier packs, allocation quanta, residual ordering, PO correction, or Dispatch commitment.

### 4.2 Deterministic resolution

For a Confirmed Need line with controlled Unit `u` and service date `d`, the future resolver must:

1. identify the one policy root whose `unit_id = u`;
2. consider only `ACTIVE` or historically `RETIRED` revisions whose interval contains `d`;
3. require exactly one eligible revision;
4. reject an inactive controlled Unit for a new preview;
5. bind that exact revision ID and revision number; and
6. calculate exact ticks only after the revision has been selected.

The interval predicate is:

```text
effective_from <= service_date
and (effective_to is null or service_date < effective_to)
```

There is no second scope and therefore no fallback or priority order. A database state that produces more than one eligible revision is invalid even if one revision has a larger number or later creation time.

### 4.3 Exact representability

For a proposed quantity `q` and positive step `s` in the same exact Unit:

```text
planning_ticks = q / s
valid only when planning_ticks is an exact whole number
persisted confirmed quantity = planning_ticks * s = q
```

Examples are illustrative only:

| Exact Unit                     | Candidate step | Proposed quantity | Result                                                                 |
| ------------------------------ | -------------: | ----------------: | ---------------------------------------------------------------------- |
| kilogram                       |         `0.01` |           `10.23` | Representable as `1023` ticks; candidate value still pending approval. |
| kilogram                       |         `0.01` |          `10.234` | Reject; do not round to `10.23` or `10.24`.                            |
| explicitly governed count Unit |            `1` |              `12` | Representable as `12` ticks; candidate value still pending approval.   |
| explicitly governed count Unit |            `1` |            `12.5` | Reject; do not round or trim.                                          |
| Unit without a policy          |           none |               any | Reject because policy is missing.                                      |

The later error must identify the affected field, exact Unit, effective policy revision when one exists, required step, and attempted value without exposing SQL, table, role, policy, or stack details. This document does not define an API payload.

### 4.4 Effective time, activation, and correction

- `service_date` is a `date` interpreted as the Asia/Bangkok operating date.
- `effective_from` is inclusive.
- `effective_to` is optional and exclusive.
- Activation may schedule a future revision.
- A future-only revision does not authorize an earlier service date.
- A revision whose interval ended does not authorize a later service date.
- An activated revision cannot be backdated to replace a revision already available to a prior preview or confirmation.
- A successor activation and predecessor retirement occur in one controlled future administration transaction.
- Closing an open interval is the only allowed post-activation interval mutation: set `effective_to` once on the predecessor to the successor's `effective_from`, transition it to `RETIRED`, and record retirement actor/time.
- Historical decisions retain their exact bound revision even after that revision is retired.
- A correction never edits a confirmed quantity, policy step, or historical binding in place.

The recommended first-slice activation rule is that a newly activated `effective_from`, and a retirement boundary applied to an already active revision, cannot precede the current Asia/Bangkok service date. Exact production scheduling remains pending with H1A-P07.

### 4.5 Lifecycle mutability

| State     | Eligible for resolution?                                                                 | Allowed mutation                                                                                       | Prohibited mutation                                                                           |
| --------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `DRAFT`   | No                                                                                       | Future approved administration may correct step, dates, and draft approval metadata before activation. | Root/Unit/revision identity, revision number, predecessor, creator, or creation time; delete. |
| `ACTIVE`  | Yes when the service date is inside its interval, including a scheduled future interval. | One controlled retirement may set a previously null `effective_to`, status, and retirement evidence.   | Step, Unit, start, predecessor, approval/activation evidence, creator, delete, reopen.        |
| `RETIRED` | Yes only for historical service dates inside its closed interval.                        | None.                                                                                                  | Any update, delete, reactivation, interval extension, or payload rewrite.                     |

Activation requires complete Planning approval and administration evidence. The approving and activating actors may be the same; H1A does not require or seed a two-person workflow.

## 5. Minimum future physical direction

This section fixes an implementation direction only. It creates no SQL authority in this documentation task.

### 5.1 Exact relation catalog

The future H1A migration should add exactly two relations in private `atlas_planning`.

#### `atlas_planning.planning_quantity_policies`

| Column                        | Direction                                                                            |
| ----------------------------- | ------------------------------------------------------------------------------------ |
| `planning_quantity_policy_id` | `uuid` primary key, database-generated.                                              |
| `unit_id`                     | Required exact FK to `atlas_admin.units`; unique policy scope.                       |
| `created_by_actor_id`         | Required FK to `atlas_core.actors`; attribution only, not caller-supplied authority. |
| `created_at`                  | Required database acceptance timestamp.                                              |

The root Unit and creation fields are immutable. The root cannot be deleted.

#### `atlas_planning.planning_quantity_policy_revisions`

| Column                                  | Direction                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------- |
| `planning_quantity_policy_revision_id`  | `uuid` primary key, database-generated.                                                |
| `planning_quantity_policy_id`           | Required FK to the exact policy root.                                                  |
| `unit_id`                               | Required repeated exact Unit, bound to the root by a composite FK.                     |
| `revision_number`                       | Positive integer, unique and contiguous within the root.                               |
| `predecessor_policy_revision_id`        | Nullable same-root typed predecessor; null only for revision 1; one successor maximum. |
| `planning_step`                         | `numeric(20,6)`, strictly positive.                                                    |
| `effective_from`                        | Required Asia/Bangkok service date, inclusive.                                         |
| `effective_to`                          | Optional Asia/Bangkok service date, exclusive and greater than `effective_from`.       |
| `policy_revision_status`                | Exactly `DRAFT`, `ACTIVE`, or `RETIRED`.                                               |
| `created_by_actor_id`, `created_at`     | Required creation evidence.                                                            |
| `approved_by_actor_id`, `approved_at`   | Null only while unapproved Draft; required before activation.                          |
| `activated_by_actor_id`, `activated_at` | Required when Active or Retired.                                                       |
| `retired_by_actor_id`, `retired_at`     | Required only when Retired.                                                            |

The revision contains no JSON rule payload, dimension scope, polymorphic scope identifier, priority number, fallback flag, purchase step, conversion factor, supplier, Ingredient, Customer, School, destination, or UI state.

### 5.2 Exact constraints and indexes

The future migration should provide:

- primary keys on both database-generated identities;
- unique root `unit_id`;
- unique root ownership key `(planning_quantity_policy_id, unit_id)`;
- unique revision version `(planning_quantity_policy_id, revision_number)`;
- unique revision ownership key `(planning_quantity_policy_id, planning_quantity_policy_revision_id, unit_id)`;
- unique non-null predecessor within a root to prevent revision forks;
- restrictive typed FKs for Unit, actor, root, and same-root predecessor ownership;
- `ON DELETE RESTRICT` for every FK;
- positive step, positive revision number, interval, status/evidence-shape, and lifecycle checks;
- a resolution index with equality columns first and the date range last, covering exact Unit plus eligible status/effective dates;
- leading indexes for every operational FK not already covered by a unique key; and
- actor-reference indexes required for restrictive FK enforcement and governance review.

Non-overlap must be enforced by bounded deferred integrity logic rather than adding a generic rule engine or a new extension. DRAFT intervals do not authorize resolution, but activation must fail if its interval overlaps any Active/Retired interval on the same exact Unit.

### 5.3 Exact future function and trigger catalog

The proposed H1A catalog is exactly three private, `atlas_owner`-owned, security-invoker trigger functions with empty search paths:

1. `atlas_planning.pa_06e_h1a_planning_quantity_policy_guard()`
2. `atlas_planning.pa_06e_h1a_planning_quantity_policy_revision_guard()`
3. `atlas_planning.pa_06e_h1a_planning_quantity_policy_effectivity_integrity()`

The proposed trigger catalog is exactly:

1. one ordinary root immutability/delete guard on `planning_quantity_policies`;
2. one ordinary revision lifecycle/immutability/delete guard on `planning_quantity_policy_revisions`; and
3. one `DEFERRABLE INITIALLY DEFERRED` revision integrity trigger for contiguous predecessor ownership, activation evidence, half-open non-overlap, and deterministic eligible resolution.

The future implementation issue must stop if executable design proves another function, trigger, relation, or extension is necessary.

### 5.4 Security and exposure

- Both relations and all functions are owned by `atlas_owner`.
- Both relations have RLS enabled and forced.
- H1A creates zero RLS policies.
- Revoke all relation, sequence, and function privileges from `PUBLIC`, `anon`, `authenticated`, and `service_role`.
- Existing command/read runtimes receive zero H1A relation or function privilege.
- H1A creates no role, capability, membership, command runtime, read runtime, API function, view, RPC, event, command receipt, audit event, generated type, or PA-06A registry entry.
- Synthetic pgTAP fixtures run in a transaction and roll back. No production policy row is seeded.

The absence of an H1A runtime is intentional. A later separately approved administration contract may define how an approved revision is created or activated; H1B2 only consumes the persisted effective revision through its own authoritative backend path.

## 6. Future H1B1/H1B2 binding contract

H1B1 may reference one exact `planning_quantity_policy_revision_id` from line-decision evidence only after H1A exists. It must use typed ownership so the decision Unit and policy Unit cannot disagree.

H1B2 preview must return and bind:

- policy root ID;
- policy revision ID and revision number;
- exact Unit;
- Planning step;
- service date and effective interval;
- exact whole tick count; and
- the current Confirmed Need batch/line/revision and source versions already required by PA-06E.

H1B2 commit must re-resolve under lock using the same Unit and service date. It writes no line decision or successor quantity revision when:

- no root exists;
- only Draft/inactive policy exists;
- the first eligible policy is future;
- all eligible policies are expired;
- Unit is inactive for a new decision;
- overlap, ambiguity, or a tie is detected;
- the proposed quantity is not an exact whole tick count; or
- the eligible revision differs from the preview-bound revision.

The later safe-error vocabulary should distinguish at least `PLANNING_POLICY_MISSING`, `PLANNING_POLICY_NOT_EFFECTIVE`, `PLANNING_POLICY_AMBIGUOUS`, `PLANNING_QUANTITY_NOT_REPRESENTABLE`, and `STALE_PLANNING_POLICY`. Exact API names remain H1B2 work.

## 7. Explicit exclusions

This decision does not approve or define:

- Procurement purchase-order steps or supplier pack/minimum rules;
- supplier-specific precedence;
- supplier allocation, residual distribution, fixed portions, or rebalancing;
- PO or Dispatch correction;
- Unit conversion;
- a generic policy/rule/workflow engine;
- JSON rules or polymorphic scopes;
- Customer, School, Ingredient, supplier, destination, actor-scope, or dimension overrides;
- H1B1 decision persistence;
- H1B2 read, preview, or confirmation APIs;
- validation, approval, release, reopen, or CMD-03 changes;
- React, Retool, hosted Supabase, production data, seed values, credentials, or deployment.

## 8. Approval and implementation gate

Before the future H1A implementation issue is published, the product owner must explicitly accept or amend:

1. H1A-P01 ownership and one-approval-authority model;
2. H1A-P02 exact-Unit-only scope;
3. H1A-P03 no-fallback precedence;
4. H1A-P04 exact Unit/no-conversion taxonomy;
5. H1A-P05 exact first-slice step values;
6. H1A-P06 exact-tick rejection;
7. H1A-P07 service-date/effectivity semantics;
8. H1A-P08 revision and stale binding;
9. H1A-P09 lifecycle/mutability; and
10. H1A-P10 fail-closed blocker behavior.

Recommendation is not approval. Until explicit acceptance, the draft PR must remain draft, `atlas:merge-ready` must not be applied, H1A SQL must not start, and fixture examples must not become production policy.

## 9. Migration and rollback effect

This decision changes documentation only. It creates no migration, PostgreSQL object, role, grant, RLS policy, function, API entry, test, generated type, application code, hosted action, or production data.

The future H1A migration is additive and seedless. Before operational use, it may be reverted as an unshipped migration. After an activated policy revision or downstream decision binds a revision, destructive rollback is prohibited. A separately reviewed forward migration must preserve root/revision identities, effective history, and all downstream bindings.
