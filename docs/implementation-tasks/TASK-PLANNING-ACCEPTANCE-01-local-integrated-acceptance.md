# TASK-PLANNING-ACCEPTANCE-01 — Local Integrated Planning Acceptance

**Status:** Accepted locally for Staging alignment

**Acceptance date:** 2026-08-18

**Authoritative baseline:** `f28603ee7c8cfdd995c3ef82bcc3e4f283991437`

**Primary disposition:** `PLANNING-ACCEPTANCE-01 — LOCAL PLANNING ACCEPTED FOR STAGING ALIGNMENT`

**Next task:** `ATLAS-STAGING-ALIGN-01`

## 1. Boundary and governance

This is a repository/local certification record, not a feature change. It certifies the merged Planning path from source authoring through Confirmed Need release. It does not certify hosted behavior, align Atlas Staging, authorize production, or start Purchase Handoff/Procurement.

The run started from zero in the user-authorized checkout `E:\Project\OPS ERP\thuonghao-ops-erp`. The top level, private GitHub repository, `origin`, current branch, clean status, and workspace guard were verified before acceptance. `origin/main` exactly matched the required SHA. No materially overlapping open Planning implementation or correction pull request existed. The forbidden `D:\Project\Repo\OPS\thuonghao-ops-erp` checkout was not used. Existing stashes were not applied, popped, dropped, cleared, rewritten, created, or used as acceptance input.

The accepted authority order was preserved:

```text
approved repository documentation
→ merged migrations and pgTAP
→ merged application code
→ retained OPS v1 / Retool evidence
→ acceptance tooling
```

No Product, contract, backend, security, persistence, certification-tool, or Application conflict was found.

## 2. Durable evidence key

The matrix uses these durable evidence labels:

- `PC01-SQL`: `supabase/tests/planning_contract_01_atomic_planning_boundaries.sql`, 137/137.
- `PC02B-SQL`: `supabase/tests/planning_contract_02b_selective_confirmation_continuity.sql`, 42/42.
- `RMVP03A-SQL`: `supabase/tests/rmvp_03a_connected_weekly_menu_attendance.sql`, 60/60.
- `PANTRY02-SQL`: `supabase/tests/pantry_02_connected_pantry_source.sql`, 46/46.
- `RMVP03B-SQL`: `supabase/tests/rmvp_03b_connected_planning_input_readiness.sql`, 84/84.
- `RMVP04-SQL`: `supabase/tests/rmvp_04_connected_need_generation.sql`, 86/86, including PLANNING-CONTRACT-02A replacement-lineage assertions.
- `RMVP05-SQL`: `supabase/tests/rmvp_05_connected_confirmed_need_review.sql`, 41/41.
- `RMVP06-SQL`: `supabase/tests/rmvp_06_connected_confirmed_need_validation.sql`, 65/65 with its declared fixture.
- `RMVP07-SQL`: `supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql`, 67/67 with its declared fixture.
- `D037-SQL`: `supabase/tests/d037_confirmed_need_save_release_boundary.sql`, 30/30 with its declared fixture.
- `H0C-SQL`: initial/corrected/error materialization suites, 80/80, 104/104, and 112/112.
- `H1B1-SQL`: decision structure/chain/policy suites, 64/64, 48/48, and 48/48.
- `RECIPE-SQL`: `rmvp_02a_connected_recipes_bom.sql`, 24/24, and `ui_quality_03a_recipe_workflow.sql`, 21/21.
- `CAT22-SQL`: `atlas_current_platform_security_catalog.sql`, 22/22 with exact counts and hashes.
- `APP-49`: four focused Planning workbench/model files, 49/49.
- `RPC-47`: eight connection, RPC, API, integration, and model files, 47/47.
- `APP-548`: full Vitest regression, 70 files and 548 tests.
- `RMVP02A-BROWSER`: `pnpm local:rmvp02a:verify`, successful browser-key Recipe certification.
- `VERIFIER-CHAIN`: the repository local connection, PA-06C, master-data, RMVP-01 through RMVP-07, D-037, Pantry, and PLANNING-CONTRACT-01 verifiers.

## 3. Acceptance matrix

| ID     | Product expectation                                                                                                | Authoritative contract/function                       | Persistence/read model                                                                           | Application behavior                                                              | Durable evidence                                   | Result | Notes                                                                              |
| ------ | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- | -------------------------------------------------- | ------ | ---------------------------------------------------------------------------------- |
| A01    | New Menu → Review → Save                                                                                           | D-036/PC01; `save_weekly_menu`                        | Versioned Weekly Menu aggregate and shaped Planning Inputs readback                              | `Xem thay đổi` precedes one consequential `Lưu`                                   | PC01-SQL; RMVP03A-SQL; APP-49                      | PASS   | Normal path has no draft/validate/approve ceremony.                                |
| A02    | Material Menu edit after Review invalidates Review                                                                 | D-036/PC01; reviewed request fingerprint              | Only the current reviewed payload can be saved                                                   | Dirty edit clears the reviewed state and disables stale Save                      | PC01-SQL; APP-49                                   | PASS   | Review is not an operator-owned lifecycle.                                         |
| A03    | Dish correction preserves stable logical Menu assignment identity                                                  | D-039/PC02A; Need materialization                     | Stable Menu assignment identity survives Dish/Recipe successor evidence                          | Reload keeps the assignment while showing current authoritative Dish/Recipe facts | RMVP04-SQL; PC01-SQL                               | PASS   | Recipe source lineage may change without fabricating a new Menu assignment.        |
| A04    | Menu coverage exposes Attendance defaults                                                                          | RMVP-03A/PC01; Planning Inputs read                   | Menu coverage and School defaults are shaped together by the backend                             | Attendance surface shows working default-derived values                           | RMVP03A-SQL; PC01-SQL; APP-49                      | PASS   | Coverage establishes context, not confirmation.                                    |
| A05    | Default-derived Attendance is not falsely confirmed                                                                | PC01; `save_attendance`                               | Derived value and persisted operator evidence remain distinct                                    | UI labels/Save state do not present defaults as confirmed                         | PC01-SQL; RMVP03A-SQL; APP-49                      | PASS   | No fake operator authorship.                                                       |
| A06    | Persisted Attendance zero wins over defaults                                                                       | PC01; `save_attendance`                               | Explicit numeric zero is persisted and wins read precedence                                      | Reload renders zero, not a fallback default                                       | PC01-SQL; VERIFIER-CHAIN; APP-49                   | PASS   | Zero is valid evidence, not blank.                                                 |
| A07    | Later School-default changes do not overwrite confirmed Attendance                                                 | PC01 Attendance precedence                            | Persisted operator value outranks later default revisions                                        | Authoritative reload preserves the confirmed value                                | PC01-SQL; RMVP03A-SQL                              | PASS   | Default changes remain separate source history.                                    |
| A08    | Attendance edit → Review → Save                                                                                    | D-036/PC01; `save_attendance`                         | Versioned Attendance evidence and shaped readback                                                | One reviewed `Lưu`; no “create from defaults” ceremony                            | PC01-SQL; RMVP03A-SQL; APP-49                      | PASS   | Explicit zero is included.                                                         |
| A09    | Pantry rows → Review → Save                                                                                        | PANTRY-02/PC01; `save_pantry`                         | Planning-owned Ingredient source aggregate                                                       | Rows are reviewed, then written by one Save                                       | PANTRY02-SQL; PC01-SQL; APP-49                     | PASS   | Not Procurement routing.                                                           |
| A10    | Explicit no-additions → Review → Save                                                                              | PANTRY-02/PC01; `save_pantry`                         | Zero-line confirmation is durable source evidence                                                | The checkbox/review path remains visible and consequential                        | PANTRY02-SQL; PC01-SQL; APP-49                     | PASS   | No synthetic Ingredient line is created.                                           |
| A11    | Incomplete inputs block generation                                                                                 | RMVP-03B/PC01 preflight                               | Backend readiness blockers and currentness projection                                            | Generation action is disabled with authoritative blocker text                     | RMVP03B-SQL; PC01-SQL; APP-49                      | PASS   | No operator readiness lifecycle.                                                   |
| A12    | Complete/current inputs permit generation                                                                          | RMVP-03B/PC01 preflight                               | Backend computes the complete/current result                                                     | One enabled `Tạo nhu cầu` action appears                                          | RMVP03B-SQL; PC01-SQL; VERIFIER-CHAIN              | PASS   | UI only narrows backend permission.                                                |
| A13    | `Tạo nhu cầu` atomically generates, validates, releases, and materializes                                          | PC01; `execute_need_generation`                       | One transaction creates the generation, released fact, and Confirmed Need materialization        | Browser invokes one command and consumes readback                                 | PC01-SQL; H0C-SQL; VERIFIER-CHAIN                  | PASS   | No partial successful lifecycle is exposed.                                        |
| A14    | Browser does not manually chain generation lifecycle                                                               | PC01; `execute_need_generation`                       | Backend owns internal transitions                                                                | Integration/API tests assert one RPC boundary                                     | APP-49; RPC-47; static authority review            | PASS   | No client call chain to create/validate/release/materialize.                       |
| A15    | Current generated Need resolves to the correct Confirmed Need                                                      | RMVP-04/H0C; `create_confirmed_needs_from_generation` | Typed batch/run/source lineage and current pointers                                              | Need Generation links to authoritative Confirmed Need readback                    | RMVP04-SQL; H0C-SQL; VERIFIER-CHAIN                | PASS   | Stable lineage is retained.                                                        |
| A16    | Initial Confirmed Need lines require review                                                                        | RMVP-05; `get_confirmed_need_review`                  | Current lines have backend `NEW`/`UNREVIEWED` state                                              | Review surface shows “Mới”/“Cần rà soát” and unsaved count                        | RMVP05-SQL; APP-49                                 | PASS   | No automatic human decision.                                                       |
| A17    | Confirmed quantity edit → `Lưu`                                                                                    | D-037; `save_confirmed_needs`                         | Append-only human decision and current pointer                                                   | Changed lines form one reviewed Save payload                                      | D037-SQL; H1B1-SQL; APP-49                         | PASS   | Reason rules remain backend-governed.                                              |
| A18    | Saved Confirmed Need → `Chuyển sang lên đơn`                                                                       | D-037; `release_confirmed_needs`                      | Immutable release evidence binds current authoritative facts                                     | Second and only other normal action releases the batch                            | D037-SQL; VERIFIER-CHAIN; APP-548                  | PASS   | Two-action normal workflow is preserved.                                           |
| A19    | Release creates no supplier assignment or PO                                                                       | D-037 boundary                                        | Release evidence only; no Procurement mutation                                                   | UI stops at release confirmation                                                  | D037-SQL; RMVP07-SQL; VERIFIER-CHAIN               | PASS   | Purchase Handoff/Procurement remains deferred.                                     |
| A20    | Source successor makes generated Need `OUTDATED`                                                                   | PC01/PC02B                                            | Currentness is computed from source version/signature lineage                                    | Workbench presents update action instead of treating old generation as current    | PC01-SQL; PC02B-SQL; VERIFIER-CHAIN                | PASS   | Backend owns currentness.                                                          |
| A21    | `Cập nhật nhu cầu` creates a direct successor with immutable history                                               | PC01/PC02B; `execute_need_generation`                 | Direct predecessor/successor links and historical generations are retained                       | UI sends the current expected version and consumes successor readback             | PC01-SQL; PC02B-SQL; APP-49                        | PASS   | No overwrite-in-place.                                                             |
| A22    | Same Recipe lineage plus quantity change retains governed source predecessor                                       | D-039/PC02A materialization                           | Typed direct predecessor remains on same governed Recipe lineage                                 | UI does no source matching                                                        | RMVP04-SQL                                         | PASS   | Quantity change does not erase lineage.                                            |
| A23    | Dish/Recipe replacement creates typed old removals and new lineage                                                 | D-039/PC02A materialization                           | Old contributions become typed `REMOVED`; replacement contributions are new `ACTIVE` lineage     | Application renders backend result                                                | RMVP04-SQL                                         | PASS   | Historical replacement evidence remains durable.                                   |
| A24    | Same Ingredient under a new Recipe does not fake Recipe-line predecessor                                           | D-039/PC02A integrity                                 | Recipe/source identity, not Ingredient/quantity similarity, governs predecessor links            | No React mapping logic exists                                                     | RMVP04-SQL; static authority review                | PASS   | `SILENT_PREDECESSOR_OMISSION` remains fail-closed.                                 |
| A25    | Different Recipe lineage plus identical final Ingredient Need carries confirmation                                 | D-040/PC02B continuity predicate                      | Recipe/source composition is lineage evidence, excluded from confirmation identity               | Backend returns `CARRIED_FORWARD`; UI presents it                                 | PC02B-SQL; APP-49                                  | PASS   | Separates source lineage from aggregate human authority.                           |
| A26    | Same identity, quantity, and effective policy carries                                                              | D-040; PC02B private predicate                        | Immutable `CARRIED_FORWARD` row binds exact direct successor                                     | UI shows `Giữ nguyên` without requiring Save                                      | PC02B-SQL; H1B1-SQL; APP-49                        | PASS   | Exact PostgreSQL numeric equality.                                                 |
| A27    | Manual 100 → 98 survives unchanged successor with original actor/reason/time                                       | D-040 carry semantics                                 | Original decision remains authoritative through continuity evidence                              | Carried row shows backend readback without manufacturing authorship               | PC02B-SQL; RMVP05-SQL                              | PASS   | Original human decision is preserved verbatim.                                     |
| A28    | Quantity change invalidates only affected authority                                                                | D-040; `INVALIDATED_PROPOSAL_CHANGE`                  | Affected pointer clears with exact immutable evidence; unrelated lines carry                     | Mixed rows display backend-specific states                                        | PC02B-SQL; H1B1-SQL                                | PASS   | No batch-wide confirmation invalidation.                                           |
| A29    | Same quantity plus changed effective policy invalidates authority                                                  | D-040; policy compatibility predicate                 | `INVALIDATED_POLICY_INCOMPATIBLE` clears the exact pointer                                       | UI receives `CHANGED`/needs-review state                                          | PC02B-SQL; H1B1-SQL                                | PASS   | Missing or ambiguous policy also fails closed.                                     |
| A30    | New Ingredient requires review                                                                                     | D-040/RMVP-05                                         | New current line has no decision/continuity row                                                  | Backend state is `NEW` and Save is required                                       | PC02B-SQL; RMVP05-SQL; APP-49                      | PASS   | Truly new decision later starts at #1.                                             |
| A31    | Removed reviewed line receives invalidation evidence                                                               | D-040; `INVALIDATED_LINE_REMOVED`                     | Historical line and decision remain; no current successor revision                               | Removed line is absent from current work rows                                     | PC02B-SQL                                          | PASS   | No fake zero current revision.                                                     |
| A32    | Removed unreviewed line receives no fake invalidation evidence                                                     | D-040 no-fake-decision rule                           | No prior human authority means no continuity row                                                 | No current row or false history is rendered                                       | PC02B-SQL                                          | PASS   | System action is not represented as human action.                                  |
| A33    | Removed count includes reviewed and unreviewed removed facts                                                       | PC02B private removed-business-fact helper            | Direct predecessor/current successor identities determine `removed_count`                        | UI consumes result count only                                                     | PC02B-SQL; CAT22-SQL                               | PASS   | Counting is independent of decision evidence.                                      |
| A34    | Mixed correction preserves unrelated confirmations                                                                 | D-040 line-level continuity                           | Per-line carry/invalidation rows coexist in one atomic successor                                 | Workbench shows mixed authoritative states                                        | PC02B-SQL; RMVP05-SQL                              | PASS   | Overall Need is still `OUTDATED` before correction.                                |
| A35    | All-unaffected correction requires zero unnecessary review                                                         | D-040 carry semantics                                 | Every eligible line keeps its current human authority                                            | Needs-review count is zero; carried rows require no Save                          | PC02B-SQL; APP-49                                  | PASS   | No empty human Save is manufactured.                                               |
| A36    | Prior-unreviewed remains unreviewed with no fake carry                                                             | D-040 direct-predecessor authority rule               | No valid prior pointer means no carry row                                                        | Backend returns `UNREVIEWED`                                                      | PC02B-SQL; RMVP05-SQL                              | PASS   | Unreviewed is not silently promoted.                                               |
| A37    | Multi-generation carry preserves the original human decision                                                       | D-040 direct-successor continuity chain               | Each successor has exact continuity while the same human decision remains current                | Reload shows the original decision metadata                                       | PC02B-SQL; H1B1-SQL                                | PASS   | No duplicate decision rows.                                                        |
| A38    | No resurrection after an invalidating generation                                                                   | D-040 direct-predecessor rule                         | Once pointer is cleared, a later coincident quantity has no current authority to carry           | Later line requires review                                                        | PC02B-SQL; H1B1-SQL                                | PASS   | Arbitrary historical matches are rejected.                                         |
| A39    | Reconfirmation continues decision numbering/history                                                                | H1B1/D-040; `save_confirmed_needs`                    | New decision points to latest historical decision and increments number                          | Ordinary Save handles reconfirmation                                              | PC02B-SQL; H1B1-SQL; D037-SQL                      | PASS   | History is append-only.                                                            |
| A40    | Truly new line begins decision #1                                                                                  | H1B1/D-040                                            | First human decision has number 1 and no predecessor                                             | Normal Save authors the first decision                                            | PC02B-SQL; H1B1-SQL                                | PASS   | No borrowed chain.                                                                 |
| A41    | Saving another line creates no decision for untouched carried lines                                                | D-040/D-037 payload rule                              | Only submitted changed lines append decisions                                                    | Workbench omits untouched carried rows from Save payload                          | PC02B-SQL; APP-49; RPC-47                          | PASS   | No unnecessary Save side effect.                                                   |
| A42    | Editing a carried line creates a normal human successor                                                            | D-040/D-037; `save_confirmed_needs`                   | Direct human successor binds current revision and historical predecessor                         | Edited carried row is included in reviewed Save                                   | PC02B-SQL; D037-SQL; APP-49                        | PASS   | Carry does not freeze legitimate human adjustment.                                 |
| A43    | RMVP-06 accepts exact carried authority                                                                            | RMVP-06 direct-or-carried predicate                   | Validation observations bind the current revision through exact continuity                       | Validation action/counts remain backend-derived                                   | RMVP06-SQL; PC02B-SQL                              | PASS   | Arbitrary old decisions remain invalid.                                            |
| A44    | RMVP-07 snapshots current successor revision and quantity                                                          | RMVP-07 direct-or-carried completeness                | Approval/release snapshot binds current successor source, revision, and confirmed quantity       | Release UI consumes authoritative eligibility/readback                            | RMVP07-SQL; PC02B-SQL                              | PASS   | Original human decision identity remains traceable.                                |
| A45    | Released downstream correction fails with zero mutation                                                            | D-037/PC02B; `DOWNSTREAM_CORRECTION_REQUIRED`         | No rematerialization, carry, pointer clear, release, or downstream mutation                      | UI shows authoritative blocker                                                    | D037-SQL; PC02B-SQL; VERIFIER-CHAIN                | PASS   | Released boundary is unchanged.                                                    |
| A46    | Exact replay is idempotent                                                                                         | Command receipt contracts                             | Completed receipt returns the original outcome without duplicate facts/events                    | UI safely consumes replay readback                                                | PC01-SQL; PC02B-SQL; D037-SQL; VERIFIER-CHAIN      | PASS   | Covered across source, generation, confirmation, and release.                      |
| A47    | Changed idempotency-key reuse is rejected                                                                          | Command receipt request-hash contract                 | Existing key plus different payload cannot write                                                 | Error is surfaced; no silent retry                                                | PC01-SQL; RMVP04-SQL; D037-SQL; VERIFIER-CHAIN     | PASS   | No second business outcome.                                                        |
| A48    | Stale expected version fails safely                                                                                | Aggregate optimistic-concurrency contracts            | No write, version, event, or audit mutation occurs                                               | UI requires refresh/review before retry                                           | RMVP03A-SQL; PC01-SQL; D037-SQL; APP-49            | PASS   | Stale writes are not merged client-side.                                           |
| A49    | Unknown write/network outcome is not automatically retried                                                         | Application recovery contract                         | Receipt/readback is authoritative recovery source                                                | `refreshRequired` disables writes; no automatic command replay                    | APP-49; RPC-47                                     | PASS   | Operator reload/recovery is explicit.                                              |
| A50    | Reload reconstructs backend authority                                                                              | Shaped read APIs for all five surfaces                | Current aggregate versions, states, counts, and actions come from backend reads                  | Browser cache is discarded in favor of fresh readback                             | APP-49; RPC-47; VERIFIER-CHAIN                     | PASS   | Review-only fixtures are visibly nonpersistent.                                    |
| A51    | Denied capability cannot become UI-enabled                                                                         | Backend `allowed_actions` and command authorization   | Capability/scope checks are enforced in RPCs and reflected in read models                        | React may narrow but never widen `allowed_actions`                                | RMVP05-SQL; RMVP06-SQL; RMVP07-SQL; APP-49         | PASS   | No UI privilege escalation.                                                        |
| A52    | Missing/inactive governed reference fails closed                                                                   | RMVP-03B/RMVP-04/H1B1 reference predicates            | Readiness/materialization/policy resolution reject missing or inactive facts                     | Authoritative blocker is presented                                                | RMVP03B-SQL; RMVP04-SQL; H1B1-SQL; VERIFIER-CHAIN  | PASS   | No fallback to browser-held reference data.                                        |
| A53    | Removed lines are absent from current validation/release totals                                                    | PC02B/RMVP-06/RMVP-07                                 | Current totals scan current successor revisions only                                             | Removed history is not shown as actionable current work                           | PC02B-SQL; RMVP06-SQL; RMVP07-SQL                  | PASS   | Historical evidence remains queryable.                                             |
| A54    | Need correction summary comes from backend `result_counts`                                                         | PC02B additive command result                         | Materializer returns carried/review/changed/new/removed counts                                   | Model parses and renders those counts without recomputation                       | PC02B-SQL; APP-49; RPC-47; static authority review | PASS   | No browser business-result comparison.                                             |
| A55    | Confirmed Need labels come from backend `confirmation_state`                                                       | RMVP-05/PC02B shaped read                             | Backend classifies `CARRIED_FORWARD`, `CHANGED`, `NEW`, `UNREVIEWED`, `CONFIRMED_CURRENT`        | UI maps authoritative values to quiet Vietnamese labels/filters                   | RMVP05-SQL; PC02B-SQL; APP-49                      | PASS   | State is not inferred from quantities.                                             |
| A56    | React owns none of identity matching, carry comparison, policy, continuity, removed counting, or result comparison | D-035/D-040 Application boundary                      | All consequential definitions live in private/backend functions and shaped reads                 | Static review found presentation, payload selection, and recovery only            | APP-49; RPC-47; CAT22-SQL; static authority review | PASS   | Operational browser data access is only through `atlas_api`.                       |
| SEC01  | Frozen CAT-22 security catalog passes exactly                                                                      | Platform security catalog                             | 219 private functions and 1,503 intended positive grants match exact catalog hashes              | No React/private-schema bypass                                                    | CAT22-SQL                                          | PASS   | Hashes: `e0b2372a32a8817afd1c78960eed732e` and `639a9a23e070ef2d1c1ae1949b7c0965`. |
| CERT01 | RMVP-02A verifier matches lifecycle/composition semantics                                                          | D-038/RMVP-02A                                        | Lifecycle administration advances version/event/audit while composition remains locked/unchanged | Browser-key verifier proves Save/Copy/Import denial and lifecycle success         | RMVP02A-BROWSER; RECIPE-SQL                        | PASS   | `set_recipe_lifecycle(... INACTIVE)` does not unlock editing.                      |

Matrix totals: **58 PASS, 0 FAIL, 0 NOT LOCALLY PROVABLE**.

## 4. Local database certification

The repository-pinned Supabase CLI was used against the disposable local stack only.

- Clean `supabase db reset --local --no-seed`: PASS; every repository migration applied from scratch.
- Applied migrations: **44**. Repository migration files: **44** `.sql` files with **44** unique versions.
- CAT-22: **22/22** with `private_function_count = 219`, private catalog MD5 `e0b2372a32a8817afd1c78960eed732e`, `positive_target_grant_count = 1503`, and positive-grant MD5 `639a9a23e070ef2d1c1ae1949b7c0965`.
- Repository Supabase Smoke: **PASS**. Pre-fixture catalog/Planning group: 5 files, 331 tests. Declared-fixture RMVP-06/RMVP-07/D-037 group: 3 files, 162 tests.
- Broad practical SQL gate: **PASS**, all 58 database suites and 3,385 assertions (55 self-contained files/3,223 assertions plus the three fixture-dependent files/162 assertions).
- Focused exact plans: RMVP-03A 60; RMVP-02A 24; UI-QUALITY-03A 21; Pantry-02 46; RMVP-03B 84; Pantry-NG-02 144; RMVP-04 86; PLANNING-CONTRACT-01 137; PLANNING-CONTRACT-02B 42; RMVP-05 41; RMVP-06 65; RMVP-07 67; D-037 30; H1B1 structure/chain/policy 64/48/48; H1A structure/lifecycle/effectivity 56/50/44; H0C initial/corrected/errors 80/104/112.
- RMVP-06/RMVP-07/D-037 fixture-valid rerun: **65/65, 67/67, 30/30**.
- Recipe durable SQL: `rmvp_02a_connected_recipes_bom.sql` **24/24** and `ui_quality_03a_recipe_workflow.sql` **21/21**.
- Deferred integrity: the repository contains 202 explicit `SET CONSTRAINTS ... IMMEDIATE` force points; the broad gate passed them.

## 5. Application and RPC certification

The full verifier chain passed after clean resets and declared fixture provisioning:

- local connection: sign-in, safe not-found result, and sign-out;
- PA-06C browser-key provisioning and verification;
- master-data fixture reconciliation and RMVP-01;
- RMVP-02A Recipe/BOM creation, approved-Menu composition lock, allowed lifecycle administration, authoritative readback, and continuing lock;
- RMVP-02B Recipe adjustment create/supersede/cancel/replay/stale/readback paths;
- RMVP-03A Google/shared parsing, Menu and Attendance Save, explicit zero, snapshots, replay, reauthentication, and readiness;
- Pantry-02;
- RMVP-04 request/generate/validate/release/CMD-15/readback;
- RMVP-05, RMVP-06, RMVP-07, and fresh D-037 v2 Save/replay/Release/replay/readback with zero downstream mutation;
- PLANNING-CONTRACT-01 source Saves, automatic preflight, `Tạo nhu cầu`, `OUTDATED` correction, and `Cập nhật nhu cầu`.

Frontend and build gates:

- full Vitest: **70 files, 548 tests, PASS**;
- focused Planning workbenches/model: **4 files, 49 tests, PASS**;
- focused connection/RPC/API/model: **8 files, 47 tests, PASS**;
- `pnpm typecheck`: **PASS**;
- `pnpm format`: **PASS**; direct Prettier check of all four acceptance-documentation files also passed after the status edits;
- `pnpm build`: **PASS**; only the existing non-blocking bundle-size advisory was emitted;
- `git diff --check`: **PASS**, including the final documentation diff.

## 6. Five-second operator review

The five surfaces were reviewed in the local Vite review mode. The review-only fixture is explicitly nonpersistent and is not an authority source. No browser console warning or error was observed.

| Surface            | Job/context                                                                      | Exceptions/preserved state/unsaved state                               | Next action                         | Classification |
| ------------------ | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------- | -------------- |
| `Thực đơn`         | Weekly Menu job and week are immediately visible                                 | Save status, filters, import, and reviewed-change state are visible    | `Xem thay đổi` then `Lưu`           | PASS           |
| `Sĩ số`            | Default/edit/review/Save job and week are obvious                                | Totals and save status make current work legible                       | `Xem thay đổi` then `Lưu`           | PASS           |
| `Nhu cầu bổ sung`  | Ingredient additions or explicit no-additions job is explicit                    | Derived location/unit and review state are visible                     | `Xem thay đổi` then `Lưu`           | PASS           |
| Need Generation    | Readiness, current week, blockers/history, and currentness are obvious           | Exceptions are grouped; correction summary is backend-shaped           | `Tạo nhu cầu` or `Cập nhật nhu cầu` | PASS           |
| `Xác nhận nhu cầu` | Period, line counts, review counts, filters, and two-action boundary are obvious | Backend states including `Giữ nguyên` and release blockers are visible | `Lưu`, then `Chuyển sang lên đơn`   | PASS           |

## 7. Authority and security review

Exactly one authority was found for each consequential definition:

| Definition                  | Sole authority                                              |
| --------------------------- | ----------------------------------------------------------- |
| Menu authored fact          | Weekly Menu backend aggregate                               |
| Attendance confirmation     | Attendance backend evidence                                 |
| Pantry                      | Pantry backend source                                       |
| Planning readiness          | RMVP-03B/PC01 backend preflight                             |
| Need currentness            | Need Generation backend                                     |
| Recipe replacement lineage  | PLANNING-CONTRACT-02A backend evidence                      |
| Confirmed Need continuity   | PLANNING-CONTRACT-02B backend evidence                      |
| Removed business-fact count | Private direct-predecessor/current-successor backend helper |
| Confirmation state          | RMVP-05/PC02B backend read model                            |
| Action eligibility          | Backend `allowed_actions` plus command authorization        |

React parses Need Generation `result_counts` and Confirmed Need `confirmation_state`; it does not reproduce stable identity matching, quantity equality, effective-policy resolution, continuity, removal counting, or business-result comparison. Untouched carried rows are omitted from Save. Edited carried rows are included in the normal human Save with expected decision identity. Unknown outcomes set recovery-required state and are not automatically retried. Reload invokes authoritative backend reads. Local logic only narrows backend `allowed_actions`.

Operational browser persistence goes through `atlas_api`; no direct private-table write was found. `atlas_planning.confirmed_need_line_decision_continuity` is private and forced-RLS. The removed-count helper is private. Browser roles and `anon`, `authenticated`, and `service_role` have no direct private-helper execution. PC02B creates no public continuity API. Pointer clearing requires exact immutable invalidation evidence and has no generic bypass. CAT-22 proves the intended runtime grants exactly.

## 8. PLANNING-CONTRACT integrity conclusions

- **02A integrity:** PASS. Governed replacement creates typed old `REMOVED` evidence and new `ACTIVE` Recipe lineage; it never maps old/new Recipe sources by Ingredient, quantity, or apparent similarity; silent omission remains fail-closed.
- **02B integrity:** PASS. Carry is line-level and requires exact stable identity, quantity, policy revision, and direct-predecessor current authority.
- **No fake human decision:** PASS. System carry/invalidation creates immutable continuity evidence, never a human decision row.
- **Removed-count independence:** PASS. Reviewed and unreviewed removed business facts both contribute to the backend count, while only reviewed removals have decision invalidation evidence.
- **Released-downstream blocker:** PASS. `RELEASED_FOR_PURCHASE_HANDOFF` plus upstream change returns `DOWNSTREAM_CORRECTION_REQUIRED` with zero correction, carry, pointer, release, or downstream mutation.
- **Recipe lifecycle versus composition lock:** PASS. Approved Menu use locks base composition; Save, Copy, and Import are denied with zero composition mutation. `set_recipe_lifecycle(... INACTIVE)` succeeds with exact version/event/audit/readback evidence and does not reopen Save.

## 9. Retained OPS v1 / Retool evidence

The authorized E: checkout exposed the retained read-only review record rather than the raw export files. That record was cross-checked before disposition:

- `OPS - Công thức.json`: retained evidence identifies the separate `SystemChangeOrder` Recipe-correction job, its affected-ingredient (`Nguyên liệu bị ảnh hưởng`) context, and the actions `Thay thế`, `Thay đổi định lượng`, `Thêm nguyên liệu`, and `Bỏ nguyên liệu`.
- `OPS - Lên đơn, Đặt hàng (1).json`, the retained filename corresponding to the requested Ordering export: retained evidence identifies `PurchasePlanner`, ingredient-level Actual Need/state rows, explicit export/edit/import, and normal Save.

The raw exports were not available to the acceptance runner in the authorized E: checkout, so this run did not claim a new raw-file checksum or parse. The repository-preserved findings support the operator/business context only. Retool SQL, JavaScript orchestration, state, and component structure do not define Atlas authority. Retool was not mutated.

## 10. Hosted environment boundary — read-only observation

No hosted migration, SQL write, Auth change, data change, configuration change, or Edge Function deployment was performed.

### Atlas Staging — `rnzxmxiiqgtdevzregff`

- Project: `Atlas Staging`, `ACTIVE_HEALTHY`, Singapore, PostgreSQL 17.6.1.155.
- Managed migrations: **33**, through `20260805202517_rmvp_07_connected_confirmed_need_approval_release`; the 11 later repository migrations from PLANNING-CONTRACT-01 through PLANNING-CONTRACT-02B are not deployed.
- Read-only catalog observation: **10** Atlas schemas, **100** base tables plus **2** views, **224** non-trigger functions (**262** total `pg_proc` entries including **38** trigger functions), **79** `atlas_api` functions, **583** Atlas policies, and **0** `public` base tables.
- Edge Functions: **0**.

### Live OPS — `qnthofvccilhnefdcxnz`

- Project: `OPS`, `ACTIVE_HEALTHY`, Singapore, PostgreSQL 17.6.1.005.
- Supabase managed migration list: **0** entries.
- Read-only catalog observation: **0** Atlas schemas, **0** Atlas tables, **0** Atlas functions, **0** `atlas_api` functions, **0** Atlas policies, and **46** `public` base tables.
- Existing legacy Edge Functions: **8**, all left unchanged.

This proves only the intended deployment separation. It does not certify either hosted workflow.

## 11. Hosted CI

Hosted GitHub Actions remain **BLOCKED BEFORE RUNNER — GitHub billing/spending limit**. The merged PR #202 records that exact condition, and the main merge commit exposes no passing workflow run or commit status. Actions were not rerun. Hosted CI is not represented as passing.

## 12. Disposition

All 58 required local/repository scenarios passed, the two mandatory early gates passed, no competing authority or blocking defect was found, and the hosted/live boundaries remain unchanged.

```text
PLANNING-ACCEPTANCE-01 — LOCAL PLANNING ACCEPTED FOR STAGING ALIGNMENT
```

The next task is `ATLAS-STAGING-ALIGN-01`. `HOSTED-PLANNING-REHEARSAL-01` remains subsequent and is not started by this acceptance.
