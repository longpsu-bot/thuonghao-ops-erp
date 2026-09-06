# ATLAS-MODEL-CONVERGENCE-01 — Acceptance and regression matrix

**Status:** Final integration result: **56 / 56 PASS**, with exact-head CI links retained in Draft PR #258 so the certified commit does not move after validation.

**Spec:** [bounded convergence design](../superpowers/specs/2026-09-06-atlas-model-convergence-design.md).

**Evidence rule:** Every required row must name an actual test/artifact and outcome in the final implementation report. Existing sufficient tests may be reused; do not duplicate them for a new assertion count.

## 1. Required fixture set

Use synthetic disposable data, never imported live operational records. The set needs two canonical School Types; two same-type Schools where only one has a School exception; an unlocked root-only Dish; unlocked DRAFT, VALIDATED and released states; a locked released Dish; a legacy GENERAL-only Dish; and a target/source copy pair with differing system and School-effective contents.

Include an Ingredient replaced by a SYSTEM_INGREDIENT rule, a SYSTEM_DISH ADD, a later change to that added line, a School-specific exception, a prior SCHOOL_DISH ADD, a finite interval, scheduled correction, scheduled cancellation, materially unrelated rules, and unattributed legacy issuance. Existing fixtures should be extended only where they cannot express the named case.

Frontend authority tests must intentionally make raw/base Recipe composition differ from the shaped effective BOM. Do not let identical fixtures mask selection bugs.

## 2. Recipe and connected UI acceptance

| ID  | Setup / action                                               | Required outcome                                                                                                                                 | Verification layer                                | Outcome |
| --- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------- | ------- |
| R01 | New Dish creation through normal UI                          | Returned ACTIVE Dish and two canonical roots; zero RecipeVersions at creation; typed context opens without activation or root-creation calls.    | Connected UI spy + existing SQL creation contract | PASS    |
| R02 | Root-only context, effective readiness BLOCKED, Save allowed | Empty base editor remains usable; Save uses backend authoring identity/version; no fabricated effective readiness.                               | Component + parser                                | PASS    |
| R03 | Unlocked DRAFT, VALIDATED and released-unused contexts       | Base authoring is available only as backend permits; no extra lifecycle ceremony.                                                                | Component parameterized test + SQL contract       | PASS    |
| R04 | Approved Menu evidence locks Dish                            | Effective BOM read-only; permitted Change Order action; no base Save/copy; read-only type/date navigation still works.                           | Component + existing lock SQL                     | PASS    |
| R05 | Canonical labels change case/name                            | Stable code/ID selection still works; no hardcoded UUID, numeric type ID or name matching.                                                       | API/model/component                               | PASS    |
| R06 | GENERAL-only or missing typed release                        | Explicit unavailable/blocker state; no nullable fallback, proxy School, synthetic Recipe or zero composition presented as READY.                 | Component + SQL selector                          | PASS    |
| R07 | Raw base contains A; shaped effective BOM contains B         | “Effective/current” surface displays B and never reconstructs A; base-authoring surface is distinctly labelled.                                  | Deliberately conflicting component fixture        | PASS    |
| R08 | Same Dish/date system view vs School with exception          | System excludes School changes; School includes them; another same-type School remains unaffected; no mixed-context late read.                   | Component + resolver SQL                          | PASS    |
| R09 | Switch Dish/type/School/date with request in flight          | Superseded response cannot replace current data or enable an action; loading/blocked states are safe.                                            | Deferred-promise component test                   | PASS    |
| R10 | Dirty editor, failed refresh or context change               | Draft preserved on failure; explicit discard/return decision; no silent replacement.                                                             | Component interaction                             | PASS    |
| R11 | Backend action false but all local input valid               | Write remains disabled and handler cannot issue command.                                                                                         | Component action spy                              | PASS    |
| R12 | Missing capability or expired session                        | Safe denial/session handling; no fallback escalation or widened role binding.                                                                    | Component + browser-key auth test                 | PASS    |
| R13 | Malformed/mismatched context response                        | Parser/context check fails closed; no mutation authorization from partial data.                                                                  | Parser + component                                | PASS    |
| R14 | Search and catalog rendering                                 | Search scope truthfully labelled; useful search retained; no base-as-effective claim; no unbounded per-Dish history fanout or silent truncation. | Component + request-count inspection              | PASS    |
| R15 | Successful normal Recipe Save                                | Refreshes correct authoring/effective context; no explicit Activate/Validate/Release calls or Dish version bump for activation.                  | Component + existing lifecycle SQL                | PASS    |

## 3. Copy acceptance

| ID  | Setup / action                                                                 | Required outcome                                                                                                                 | Verification layer              | Outcome |
| --- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | ------- |
| C01 | Copy source/target/date/reason selected                                        | Exactly one `copy_dish_recipes` request with target Dish version; no client clone Save and no two scope-copy commands.           | Connected component request spy | PASS    |
| C02 | Source has system and School-specific changes                                  | Both system-effective scope snapshots copied; School layers excluded; source and adjustment records unchanged.                   | SQL + browser-key journey       | PASS    |
| C03 | Copy succeeds                                                                  | Exactly two distinct canonical scope results, both persisted DRAFT outputs; both target contexts reloaded; no auto-release.      | Parser + component + SQL        | PASS    |
| C04 | Missing source/target scope, unfinished conflicting target, inactive reference | Existing safe backend failure; no fabricated roots/scopes or partial copy; target prior history retained.                        | SQL contract                    | PASS    |
| C05 | Second-scope write fails after first-scope work                                | Both target scopes roll back atomically; no partial successful UI result.                                                        | SQL transaction regression      | PASS    |
| C06 | Approved Menu lock or concurrent target-version change                         | Backend denies safely before conflicting mutation; UI refreshes and does not retry stale intent.                                 | SQL + component                 | PASS    |
| C07 | Exact replay / changed idempotency content                                     | Exact replay retains original IDs and effect; changed reuse conflicts; no duplicate versions/events.                             | SQL / authenticated journey     | PASS    |
| C08 | Transport timeout after submission                                             | No automatic resend/new key; mutation blocked pending authoritative reconciliation.                                              | Component fault injection       | PASS    |
| C09 | Known server success, then one readback fails or response cannot be parsed     | Treated as potentially committed, not rolled back; no retry-as-new, no fabricated second scope, no normal writes until recovery. | Component deferred/fault test   | PASS    |
| C10 | Source rule changes after successful copy                                      | Copied target content remains the snapshot; later source changes do not mutate it.                                               | SQL contract                    | PASS    |
| C11 | Change source, target or date; dirty target composition exists                 | Prior review/retry intent invalidated; explicit dirty-work handling; complete new reviewed intent required.                      | Component interaction           | PASS    |

## 4. Change Order / history acceptance

| ID  | Setup / action                                                                 | Required outcome                                                                                                                          | Verification layer                  | Outcome |
| --- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ------- |
| A01 | Non-ADD target picker opens                                                    | Uses effective-target context, not raw Recipe-line filtering; names/quantity/Unit from shaped result.                                     | Component API spy                   | PASS    |
| A02 | Select base-origin line                                                        | Exactly `target_recipe_line_id`; no adjustment-origin ID.                                                                                 | Payload test + SQL                  | PASS    |
| A03 | Select prior SYSTEM_DISH ADD in system or School-Dish context                  | Exactly `adjustment_line_id`; stable origin preserved through Preview and Create.                                                         | Component + SQL                     | PASS    |
| A04 | Select earlier SCHOOL_DISH ADD                                                 | Stable adjustment-origin target preserved through applicable later modification and correction.                                           | Component + SQL                     | PASS    |
| A05 | Both/neither target IDs; expired/removed/cancelled/inapplicable origin         | Existing fail-closed validation; no name/Ingredient-based reconstruction.                                                                 | Payload + SQL                       | PASS    |
| A06 | Change target/context/action/date/quantity after Preview                       | Review invalidated; late old Preview cannot authorize new intent.                                                                         | Component interaction               | PASS    |
| A07 | System-context preview/create                                                  | Exact Dish + canonical School-Type context; no representative School or School-layer contamination in Preview/Create/Supersede.           | API trace + SQL/backend review      | PASS    |
| A08 | Ingredient-wide and ADD operations                                             | Preserve existing scope/action semantics and active-Ingredient Unit rules; no forced Dish-line targeting for Ingredient-level operations. | Existing + targeted component/SQL   | PASS    |
| A09 | Server temporal fields deliberately differ from naive root/date interpretation | Render server `is_effective_now` and temporal meaning, do not infer locally.                                                              | Component fixture                   | PASS    |
| A10 | Full history with equal boundaries, finite end, correction/cancellation        | Backend periods shown with full BOM, unambiguous half-open dates and reachable immutable evidence.                                        | Component + history SQL             | PASS    |
| A11 | Unrelated system/same-type School rules exist                                  | Display backend material history/exception count, not local counts or rule replay.                                                        | Component conflicting fixture + SQL | PASS    |
| A12 | Legacy issuance has null original issuer/time                                  | Unattributed display; no importer identity/time substituted.                                                                              | Parser + component                  | PASS    |

## 5. Cross-domain safeguards and regression evidence

These rows preserve existing behavior. Add tests only when current coverage is insufficient for the change; no domain rewrite is authorized.

| ID  | Case                                                   | Required outcome                                                                                                            | Outcome |
| --- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- | ------- |
| P01 | Default Attendance plus persisted explicit zero        | Persisted value wins; absent covered pairs remain unconfirmed proposals; blank is invalid, not zero.                        | PASS    |
| P02 | Source Review then edit or Google/workbook preparation | Old review invalidated; consequential Save submits reviewed canonical rows.                                                 | PASS    |
| P03 | Pantry missing vs explicit no additions                | Distinct facts/readiness; no automatic zero confirmation.                                                                   | PASS    |
| P04 | Atomic generation for service date D                   | Only D's bound run/release/Confirmed Need changes; accepted formula and rounding unchanged.                                 | PASS    |
| P05 | Unrelated date changes under same source parent        | Existing semantic day-level currentness preserved.                                                                          | PASS    |
| P06 | Changed vs unchanged successor Need                    | Existing exact continuity predicates preserved; no fake new human decision for carry, no silent acceptance of changed rows. | PASS    |
| P07 | Existing downstream released commitment                | Existing correction/reopen blocker remains before historical mutation.                                                      | PASS    |
| Q01 | Read preliminary recommendation or export review       | No accepted allocation, Handoff, PO, receipt or acceptance event created by the read.                                       | PASS    |
| Q02 | Save exact supplier splits                             | Source-kind writer routing preserved; exact sum, eligibility and immutable decision lineage enforced.                       | PASS    |
| Q03 | Upstream quantity changes                              | Prior accepted splits become stale as defined; rebalance remains advisory until explicit Apply and Save.                    | PASS    |
| Q04 | Prepare orders, including a failing child stage        | One backend transaction; all newly performed child work rolls back on failure; no official number generated by preparation. | PASS    |
| Q05 | Confirmed-source promotion                             | Exact accepted suppliers/quantities preserved, typed source XOR and predecessor lineage maintained.                         | PASS    |
| Q06 | Draft becomes stale / order already released           | Stale draft cannot release; issued snapshot and official number remain immutable.                                           | PASS    |
| Q07 | Exact six-decimal quantity text in Procurement/export  | No IEEE-754 coercion or new rounding changes.                                                                               | PASS    |
| S01 | Anonymous, wrong Actor/scope/capability                | Existing denial behavior, no new table grants or bypass credentials.                                                        | PASS    |
| S02 | Concurrent Save/copy/menu lock and repeated commands   | Optimistic concurrency, deterministic locks, idempotency and current-head uniqueness preserved.                             | PASS    |
| S03 | UI success before authoritative readback               | Unknown/malformed/readback failure cannot enable a subsequent unsafe mutation.                                              | PASS    |
| S04 | Documentation and evidence                             | Current/support/generated/derived distinctions accurate; no fabricated test passes, review approvals or deployment parity.  | PASS    |

## 6. Evidence map and gates

The approved 6 September reference-date UX amendment adds focused evidence under A09/S04 without changing the existing 56 acceptance IDs. The normal Lệnh điều chỉnh ledger has no routine `Ngày tham chiếu` input or reference-date explanatory text. Its read request carries the automatically derived current Vietnam-local ISO date; labels continue to follow backend temporal fields. Effective start/end, issuance and other business dates remain visible. Explicit historical date navigation is confined to the secondary read-only effective-inspection surface (`Xem tại ngày`), with no effect on the normal ledger date. R04's inspection navigation and Dish-copy's explicit snapshot date remain intact.

Required focused component evidence: absence of the normal reference-date control, the explicit current Vietnam date in read calls (including a UTC/Vietnam date boundary), backend-provided temporal labels, visible business effective dates, and isolation of any retained historical inspection date from current operation.

Reuse current suites for `recipe_effective_contract_01`, product-model correction, active-on-create lifecycle correction, RMVP-02A/RMVP-02B, adjustment operator, Issue #213, atomic Planning, daily Need, confirmation continuity, purchase review/preparation, Handoff/allocation, PO and platform-security catalog. Verify actual file names and registration from `supabase/tests` and the existing integration workflow; historical suite counts are not acceptance targets.

**G0 — contract mapping:** Every required UI behavior is mapped to an existing field/command. SYSTEM_DISH uses the certified Dish + School-Type command context; no proxy School is inferred.

**G1 — targeted development:** RED evidence for new behavior and GREEN focused Vitest/parser/component tests. Changed files format cleanly; TypeScript and `git diff --check` pass.

**G2 — integrated review:** Independent reviewer checks specification and code quality on the integrated diff, including failure states, permissions, source divergence and request identity. Targeted browser interaction/visual artifacts use the real connected components and disclose whether data is synthetic.

**G3 — exact-head CI:** Frontend CI plus the existing disposable-Supabase Full Integration run on the reviewed task commit. Required suites are actually executed, not silently skipped. Capture run URL, SHA, job conclusion and relevant suite result.

**G4 — hosted readiness:** Separate read-only result; NOT READY, READY FOR AUTHORIZED REHEARSAL, or NOT VERIFIED. Never claim DEPLOYED/OPERABLE merely from G3. No hosted write is authorized.

The final report names each acceptance ID, test/artifact, result and remaining gap. A single existing test can satisfy multiple IDs when its assertions genuinely do so. P0/P1 failures or required contract gaps block acceptance; unrelated failures are recorded without silently broadening scope.
