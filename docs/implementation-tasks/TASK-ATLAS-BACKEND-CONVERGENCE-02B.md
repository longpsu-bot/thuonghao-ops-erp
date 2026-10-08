# ATLAS-BACKEND-CONVERGENCE-02B

**Status:** Implementation complete; one Draft PR for Owner review. Required CI must pass on its final head. No deployment or automatic merge.

## Baseline and authority

- STARTING_MAIN_SHA: `0be0c37eba4d96e0c321e2770a0c2ec814fa65f0`, latest fetched `origin/main`, exactly the handoff SHA.
- Branch: `refactor/atlas-backend-convergence-02b`, created from clean `origin/main` in the Owner-authorized `E:/Project/OPS ERP/thuonghao-ops-erp`.
- Freeze: merged PR #356; [accepted contract](../architecture/planning-procurement-business-freeze.md), Class B implementation convergence.
- Atlas Staging: `rnzxmxiiqgtdevzregff`, read-only ledger verified 8 October 2026: **92** migrations, tip `20261006112515_atlas_recipe_purchase_unit_read`.
- Existing local database remains untouched. A separate Supabase CLI database `supabase_db_atlas-backend-convergence-02b` replays canonical migrations using a temporary configuration and directory junction; no copied implementation checkout.
- ARCH-002 and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED** remain authority. Frozen source-specific commands, exact quantities, immutable evidence, errors and security are acceptance obligations.

## Execution plan and acceptance

Allowed files: tightly bounded forward migrations for D01/D02 and a proven D07 correction; focused existing pgTAP infrastructure; this task record and catalog evidence; concise current-context/roadmap closeout. No application code, applied migration edits, dependencies, frameworks, security normalization, performance optimization, domain expansion, Retool, Staging writes or Live OPS changes.

- [x] Verify workspace/main, freeze authority and Staging ledger.
- [x] Inspect eight effective helper definitions, owners/config/ACLs and current callers.
- [x] Capture disposable baseline catalog and compare affected definitions with Staging.
- [x] Run D01–D03 exact-output matrices before and after D01/D02 body reuse, including runtime roles.
- [x] Reproduce complete authenticated allocation commands for both source kinds; cover precision/range, positive/unique/eligible splits, exact balance, notes, source/version, replay and rollback certainty.
- [x] Correct only a demonstrated frozen-contract violation; preserve separate source writers and locks.
- [x] Review exact retirement identities under A–F; retain all unproven candidates.
- [x] Run affected Planning/Procurement suites, catalog/security verifier, migration/workspace/diff checks and requested frontend validation.
- [x] Prepare one meaningful branch and single Draft PR submission. Final-head GitHub CI is recorded on that PR; Owner review remains required. No automatic merge.

## 02B-A decisions and effective manifest

D01 and D02 have equivalent computation. `rmvp_03a_*` and `pantry_02_*` execute roles are owner/read/Planning; `rmvp_03b_*` grants only owner/Planning. Reuse the existing `rmvp_03a_*` implementations behind the other names: every original caller role already has canonical-helper execution. Preserve all individual ACLs, owners, languages, volatility, parallel posture, strictness and empty search paths. No new callable identity.

D03: `CONVERGENCE_NOT_SAFE_WITHOUT_PRIVILEGE_CHANGE`. `rmvp_03b_safe_date(text)` is owned by `atlas_owner` and callable by read/Planning; `rmvp_04_safe_date(text)` is owned by `atlas_need_generation_runtime` and callable by Need Generation/Confirmed Need review. Neither runtime set can execute the other helper. The identical strict parser bodies remain unchanged, including catch-and-return-NULL behavior. Permissive Recipe and PA-05D parsers are excluded.

All eight identities are immutable, parallel-unsafe, non-strict SECURITY INVOKER functions with empty `search_path` and no other `proconfig`. All return `text` except the two date parsers, which return `date`. PUBLIC, anon, authenticated and service_role cannot execute any of them. Superuser execution is catalog observation, not an application grant. Exact prior definitions, owner/language/configuration/ACL and all effective EXECUTE roles are retained in [Staging pre-change catalog](../testing/artifacts/atlas-backend-convergence-02b/catalog-staging-before.json). Disposable chronological replay matched all ten inspected identities, including both writers, on every recorded attribute and full effective definition.

| Exact Core identity                    | Owner / language                         | Runtime EXECUTE                        | Decision / current contract use                                                                                   |
| -------------------------------------- | ---------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `rmvp_03a_normalize_text(value text)`  | atlas_owner / SQL                        | read, Planning                         | Retain canonical implementation; Menu/Attendance canonicalization, preview, reopen and consequential source Save. |
| `rmvp_03b_normalize_text(value text)`  | atlas_owner / SQL                        | Planning                               | Forward to 03A without granting read execution on this identity; readiness invalidation and audit reason text.    |
| `pantry_02_normalize_text(value text)` | atlas_owner / SQL                        | read, Planning                         | Forward to 03A; Pantry canonical rows, quantity parsing, source Save/validation/approval/reopen.                  |
| `rmvp_03a_sha256(value jsonb)`         | atlas_owner / SQL                        | read, Planning                         | Retain canonical implementation; Menu/Attendance canonical signatures.                                            |
| `rmvp_03b_sha256(value jsonb)`         | atlas_owner / PL/pgSQL                   | Planning                               | Forward to 03A, retain PL/pgSQL; readiness receipt request hash.                                                  |
| `pantry_02_sha256(value jsonb)`        | atlas_owner / SQL                        | read, Planning                         | Forward to 03A; Pantry canonical signature.                                                                       |
| `rmvp_03b_safe_date(value text)`       | atlas_owner / PL/pgSQL                   | read, Planning                         | Retain; readiness reads, history, source selection, command validation, automatic preflight.                      |
| `rmvp_04_safe_date(value text)`        | atlas_need_generation_runtime / PL/pgSQL | Need Generation, Confirmed Need review | Retain; generation/read/validation/release and Confirmed Need review dates.                                       |

The [catalog comparison](../testing/artifacts/atlas-backend-convergence-02b/catalog-comparison.json) records the complete direct textual caller list for each identity before/after, including source-specific writer callers. Text edges were checked against the current bodies and repository references; they are not absence proof. Material indirect paths remain Menu/Attendance Save → source enforcement/canonical signatures; Pantry Save/preview → canonical rows/safe quantity/signature; readiness commands → preparation/receipt and record-change helpers; generation/read/Confirmed Need → domain validators. Current API contract use is [Planning inputs](../api/rmvp-03a-planning-inputs.md), [Pantry](../api/pantry-02-source.md), [readiness](../api/rmvp-03b-planning-input-readiness.md), [generation](../api/rmvp-04-connected-need-generation.md) and [Confirmed Need](../api/confirmed-need-save-release-v2.md). No caller is renamed.

The 124-assertion helper suite passes with exact prior and converged bodies. D01 covers NULL/empty/spaces/ASCII/trim/Vietnamese NFC/decomposition/already-normalized/blank-after-trim, retaining the existing space-only `btrim` behavior for tabs. D02 covers SQL NULL, JSON null, empty object/array, nesting, array, number, boolean, Vietnamese UTF-8 and equivalent JSONB key order, including the literal lowercase JSON-null digest. D03 covers NULL/blank, valid date/leap date, invalid leap/month/day, missing padding, reversed date, timestamp, arbitrary text and surrounding spaces. Runtime-role invocations and negative browser/anon/service-role execution assertions pass.

## 02B-B complete-command evidence and correction

**DEFECT_PROVEN = YES.** Before correction, `purchase_review_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text,text)` rejects non-positive/malformed split input, invalid notes, over-precision/magnitude and duplicate suppliers before source locks. `school_catering_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text)` had the same note/non-positive/duplicate checks but lacked the precision/magnitude guard. Its `numeric(20,6)` sum and inserted split values silently coerced operator input. The public Handoff wrapper contained no earlier precision guard. Direct callers remain the confirmed allocation command and promotion helper for the first writer, and Handoff Save/recommendation commands for the second.

Fixture: reuse `purchase_review_confirm_release_fixture.sql`: one School/date/location, two Ingredients, two eligible Suppliers and the existing guarded generation/Confirmed Need lineage. A complete authenticated Planning Save accepts the 100/3 proposed quantities. Confirmed-source probes run before any Handoff; complete allocation Saves and real atomic purchase preparation then release Planning, create real Handoff, promote accepted splits and prepare Draft POs. The same probes run through the public Handoff Save after that transition. Command calls execute as `authenticated` with the synthetic Actor's JWT subject, not as owner. Deferred guards run immediately before evidence capture; every probe and the overall fixture transaction roll back. No fixture bypass is added.

| Supplied split quantities on exact 100 family         | Prior CONFIRMED_NEED command | Prior PURCHASE_HANDOFF command                                                                 | Both after correction                                                 |
| ----------------------------------------------------- | ---------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `1.000000` + `99.000000`                              | Accept, exact storage        | Accept, exact storage                                                                          | Accept, exact storage                                                 |
| `1.0000004` + `98.9999996`                            | INVALID_SPLIT_PRECISION      | Accept; stores `1.000000` + `99.000000`; one receipt/event/audit                               | INVALID_SPLIT_PRECISION before persistence                            |
| `1.0000004` + `99.000000` (exact total unequal)       | INVALID_SPLIT_PRECISION      | Accept after coerced total comparison; stores `1.000000` + `99.000000`                         | INVALID_SPLIT_PRECISION before persistence                            |
| `0.0000004` + `99.9999996`                            | INVALID_SPLIT_PRECISION      | INTERNAL_COMMAND_FAILURE; rounded zero violates split constraint; no facts/event/audit/receipt | INVALID_SPLIT_PRECISION; ordinary failed receipt, no business changes |
| `72.1234567` + `27.8765433`                           | INVALID_SPLIT_PRECISION      | Accept; stores `72.123457` + `27.876543`; one receipt/event/audit                              | INVALID_SPLIT_PRECISION before persistence                            |
| `100000000000000`                                     | INVALID_SPLIT_PRECISION      | INTERNAL_COMMAND_FAILURE on numeric range coercion; no business changes/receipt                | INVALID_SPLIT_PRECISION                                               |
| `99999999999999.999999` (largest representable value) | ALLOCATION_IMBALANCED        | ALLOCATION_IMBALANCED                                                                          | ALLOCATION_IMBALANCED; range valid, unequal to fixture quantity       |

Normal positive/unique/active/eligible checks remain: zero/negative → NON_POSITIVE_SPLIT; duplicate → DUPLICATE_SUPPLIER; inactive → SUPPLIER_INACTIVE; ineligible → SUPPLIER_INELIGIBLE; exact `1` + `98.999999` → ALLOCATION_IMBALANCED; exact residual `1.123456` + `98.876544` succeeds unchanged.

Correction: the forward allocation migration inserts the existing confirmed-source six-decimal/range predicate into the Handoff writer at the corresponding pre-lock validation point. No new helper identity is needed for this six-line predicate. Existing `pa_05b_safe_numeric` remains the parsing primitive. Writers, locks, source projections/currentness, contribution XOR/lineage, provenance and error envelopes remain separate. The reviewed change corrects the Handoff implementation to the frozen saved-exact-split rule; it creates no rounding policy or business contract.

The 417-assertion complete-command suite passes after correction. Temporarily restoring all five prior bodies inside a disposable rolled-back session produces **18 expected D07 failures** on the final matrix: silent acceptance/rounded storage, false success evidence and internal-error receipt behavior. The helper matrix remains 124/124. Repeating the final allocation matrix after automatic transaction restoration passes 417/417.

Supplier notes: both routes retain quantity/ratio/source identity on note-only successors, exact predecessor split content, trimmed `Giao trước 5h`, blank→NULL, 500 accepted characters and 501 rejected characters. Exact residual storage and source-kind classification pass. Current source fingerprints and family versions reject stale requests; Confirmed Need batch-version mismatch returns SOURCE_CHANGED. Exact replay returns the entire original authoritative response; changed replay returns IDEMPOTENCY_CONFLICT without overwriting facts. Success emits exactly one event/audit and retains one original receipt; validation failures leave all family/revision/contribution/split facts unchanged and emit neither event nor audit. An injected local SQLSTATE 40001 at split insertion proves both wrappers return RETRYABLE_CONCURRENCY_FAILURE with `retryable=true`, roll back the receipt and all predecessor/head changes, and retain their existing explicit-retry certainty. The injection trigger rolls back with its probe. No transaction/error framework changes.

## 02B-C exact retirement review

**PROVEN_RETIREMENTS = 0; OBJECTS_REMOVED = 0.** The 02A family findings remain valid; no new deployed Retool absence or restoration evidence was supplied. This review considers the following exact identities, not a deletion hunt. A static `src` search contains none of these names; positive backend/contract/import/history use prevents retirement independently of C/F.

| Exact candidate                                                          | A    | B    | C        | D    | E    | F        | Evidence / disposition                                                                            |
| ------------------------------------------------------------------------ | ---- | ---- | -------- | ---- | ---- | -------- | ------------------------------------------------------------------------------------------------- |
| `atlas_api.get_school_catering_purchase_orders_v1_base(request jsonb)`   | PASS | FAIL | UNPROVEN | FAIL | FAIL | UNPROVEN | Private predecessor remains on current PO shaped-read chain; historical released content. Retain. |
| `atlas_api.get_school_catering_purchase_orders_v2_base(request jsonb)`   | PASS | FAIL | UNPROVEN | FAIL | FAIL | UNPROVEN | Current shaped PO wrapper composes the retained base; output/replacement history. Retain.         |
| `atlas_api.get_school_dispatch_release_workbench_v1_base(request jsonb)` | PASS | FAIL | UNPROVEN | FAIL | FAIL | UNPROVEN | Current PXK wrapper composes the retained base; issued School evidence. Retain.                   |
| `atlas_legacy.import_batches`                                            | PASS | FAIL | UNPROVEN | FAIL | FAIL | UNPROVEN | Governed import/checksum/reconciliation provenance, current extract/import tooling. Retain.       |
| `atlas_legacy.master_data_mappings`                                      | PASS | FAIL | UNPROVEN | FAIL | FAIL | UNPROVEN | Typed source/target mapping and D-047 source proof dependencies. Retain.                          |
| `atlas_legacy.recipe_unit_adoption_evidence`                             | PASS | FAIL | UNPROVEN | FAIL | FAIL | UNPROVEN | Immutable D-047 adoption/currentness evidence; equality cannot replace provenance. Retain.        |

C is unproven because offline exports do not prove current deployed Retool absence. F is unproven because no physical retirement/restoration was proposed or executed; function-body convergence restoration is not proof of safe object removal. Absence from React proves only A. All other 02A low-level Recipe/readiness/generation/Confirmed Need/wholesale/Dispatch/Trip/Core-compatibility/import candidates remain retained under their recorded proof gaps. No schema, table, index, trigger, function or accepted historical evidence was removed.

## Validation and catalog result

The catalog comparison inspects all **440** Atlas effective functions. Identity/return type/owner/language/volatility/parallel/security/strictness/config/ACL/effective execution roles are identical before/after for every function. Exactly four helper bodies and the Handoff writer body change. Direct call edges change only through the reviewed forwarding bodies; no caller names or command contracts change. Both migrations additionally compare complete `pg_proc` rows excluding `prosrc` and abort on any unexpected catalog drift. The original date parser pair and the confirmed writer are byte-for-byte unchanged.

The existing catalog-only verifier (`readCatalogAuthority` + `catalogVerificationSql`) passes inside a read-only local transaction. `atlas_current_platform_security_catalog.sql` passes 28/28, preserving exact API owners/exposure, runtime posture, private grants, RLS and policy digest. Supabase CLI chronological replay of the 92 baseline migrations and both new forward migrations succeeds; the disposable ledger matches all 94 canonical versions/names. Applied migrations remain unchanged.

45 affected pgTAP suites (3,249 assertions) pass; the per-suite plans/results are recorded in [SQL regression summary](../testing/artifacts/atlas-backend-convergence-02b/sql-regressions.json). Coverage includes Weekly Menu scale, Attendance, Pantry/direct Need, readiness, generation, Confirmed Need Save/validation/release, allocation, notes, purchase preparation/PO release, correction, continuity/currentness/Unit adoption, PXK/reconciliation consumers, PA-05D/05E and catalog security. The new tests are wired into the existing Draft Supabase Smoke and full-integration runner; no framework is added. `ATLAS_LOCAL_DB_CONTAINER` only selects a local Docker database for the existing rolled-back test runner; its normal default remains unchanged.

Local format, typecheck and build pass. Unit tests pass **185 files / 2,521 tests**, using `pnpm test --exclude '**/.superpowers/**' --maxWorkers=2`: only an existing ignored historical checkout is excluded from local discovery. The initial unscoped run discovered that stale copy and was interrupted; no tracked test or CI definition is skipped or weakened. The existing integration registry test additionally passes 111/111, including both new suite registrations. Workspace and whitespace checks pass; the workspace checker retains its pre-existing obsolete D-drive warning, with this E-drive checkout explicitly authorized by the Owner.

Required final-head GitHub checks are recorded on the Draft PR. Pending or failed checks do not make this task READY. Owner product/architecture review remains required; this PR stays Draft and must not merge automatically.

## Change/effect summary

- Forward migrations: `20261008015308_atlas_backend_convergence_02b_helpers.sql`, `20261008015340_atlas_backend_convergence_02b_allocation.sql`.
- Focused tests: `atlas_backend_convergence_02b_helpers.sql`, `atlas_backend_convergence_02b_allocation.sql`.
- Test integration: existing local purchase-review runner, full-integration runner/its registry test, Draft Supabase Smoke workflow.
- Evidence: this canonical task record, Staging pre-change definitions, pre/post catalog comparison, SQL regression summary; concise current-context/roadmap closeout.
- Business model/contract changes: **0**. Only the proven Handoff implementation violation is corrected to the frozen contract.
- Product application/UI changes: **0**; security boundary/ACL/owner/role changes: **0**.
- Staging writes/deployments: **0**; connected business-data writes: **0**; Retool changes: **0**; Live OPS reads/writes/changes: **0**. Synthetic business command writes exist only inside rolled-back disposable fixture sessions.
- Remaining candidate: D03 retained for disjoint privileges. Unproven retirement candidates stay retained. Security/performance observations remain 02C; replay/bootstrap certification remains 02D; Warehouse remains not started.
- Next separately authorized task: `ATLAS-BACKEND-CONVERGENCE-02C`. Do not begin it automatically.

## Rollback boundary

No destructive rollback. Any later reversal uses a reviewed forward restoration migration with exact pre-change definitions/configuration from the catalog evidence. Retain business facts, immutable revisions, receipts, events/audits, issued documents, D-047 evidence and the migration ledger. Disposable fixture sessions roll back.
