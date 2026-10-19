# ATLAS-C-K2-RECEIPT-INTEGRITY-01

Status: focused development verification complete; exact-head certification is recorded on the stacked Draft. No operational enablement.

Authority: [Issue #400 Owner receipt-integrity decision](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6262218817), the explicit task brief, and Draft #407 at exact base `c4778298da8ec96ebd6e72a7bf25bec423c95a8c`. This narrowly supersedes the earlier gate's receipt-helper exclusion for this infrastructure checkpoint only.

## Scope and plan

1. Reproduce the prior three receipt mutation/replay failures in a disposable database; retain their original evidence.
2. Inspect only receipt creation/completion writers, including nested Planning calls and representative Procurement/Dispatch commands.
3. Add one forward migration enforcing immutable identity, fresh IN_PROGRESS creation, one terminal transition and immutable terminal evidence. Amend existing receipt completion helpers only if required by demonstrated legitimate shared-receipt behavior. Retain RLS, runtime ownership and the public API model.
4. Add focused lifecycle/private-runtime/public-command tests; register them in existing certification. Run relevant SQL regressions, replay the forward migration from the exact base and obtain independent security/source review.
5. Publish one Draft stacked on #407 after focused checks pass. Run exact-head Frontend, Supabase Smoke and actually executed Full Integration. Stop for review.

Expected files: one forward migration, `supabase/tests/atlas_k2_receipt_integrity.sql`, narrowly necessary shared test-fixture lifecycle updates, the existing Full Integration registry, and this task record. No UI, business source selector, PO release, quantity writer, new table/role/API, certificate, hosted write, merge or deployment.

## Acceptance boundary

Identity cannot change after INSERT. New receipts start IN_PROGRESS without completion evidence. A receipt completes or fails non-retryably once; later terminal changes and deletion fail. Legitimate success/error/replay/UNKNOWN/rollback and immutable document snapshots remain intact. Concurrent completers cannot overwrite terminal evidence.

Private runtime INSERT/UPDATE permissions must also be tested for creating unsupported completed transfer-shaped evidence. Receipt immutability alone never confers official PO authority. Exact current Need decisions, original released Handoff, accepted supplier splits and complete supplier/date source membership remain a separate K2 gate. If existing facts cannot prove Preparation provenance, report DECISION REQUIRED and leave official guards unchanged.

## Evidence

Red reproduction at the exact base: 18 assertions PASS and the same three required receipt-immutability/replay assertions FAIL. Both UPDATE probes verify the actual existing runtime role, no superuser/BYPASSRLS, forced RLS and `row_security=on`. The authenticated initial Save/Preparation/PO/PXK release and correction/explicit allocation Save execute in a rolled-back synthetic fixture. Original released snapshots remain equal. Prior evidence remains unchanged in the earlier K2 evidence directory.

The identical reproduction on the amended schema passes **21/21**, including the three earlier failures. The focused receipt suite passes **50/50**. Three real concurrent-session cases pass: a committed first completion rejects a direct second mutation; the existing finish helper cannot overwrite that winner; rollback of the first writer lets the waiting finisher complete. Both existing Planning constraint flushes remain, including the zero-to-new-source bridge.

## Implementation manifest

| File                                                                            | Change                                                                                                                                                                                |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `supabase/migrations/20261019074646_atlas_k2_receipt_integrity.sql`             | One database-owned invoker guard and receipt trigger; two existing completion helpers; narrowly reordered final completion/constraint flush in `issue_223_execute_need_generation_v2` |
| `supabase/tests/atlas_k2_receipt_integrity.sql`                                 | Lifecycle, private-runtime mutation, authenticated Planning/Procurement/Dispatch replay, historical snapshot, rollback, catalog and unsupported-evidence checks                       |
| `supabase/tests/atlas_current_platform_security_catalog.sql`                    | Exact new private-function/trigger counts and corresponding catalog digests; all previous security assertions retained                                                                |
| `supabase/tests/pantry_ng_02_direct_ingredient_persistence_materialization.sql` | Exact ordinary-trigger count 77 to 78 for the new receipt guard; all 144 assertions retained                                                                                          |
| `supabase/tests/atlas_c_need_correction_authority.sql`                          | Existing corrupt-receipt attempt now proves the receipt guard blocks its fault injection before correction; no K1 runtime change                                                      |
| `supabase/tests/pa_05c_authorized_read_api_wrappers.sql`                        | Synthetic timeline receipt uses creation then completion                                                                                                                              |
| `supabase/tests/pa_06e_h1b1_line_decision_chain_pointer.sql`                    | Synthetic receipts use creation then completion; the deliberately IN_PROGRESS receipt stays IN_PROGRESS                                                                               |
| `supabase/tests/pa_06e_h1b1_line_decision_policy_quantity_integrity.sql`        | Synthetic receipts use creation then completion                                                                                                                                       |
| `supabase/tests/rmvp_04_connected_need_generation.sql`                          | Directly orchestrated synthetic parent completes before its existing continuity constraint flush                                                                                      |
| `scripts/certify-supabase-full-integration.mjs`                                 | Registers the new suite through the existing shared-fixture runner                                                                                                                    |
| `scripts/atlas-staging-contract.test.mjs`                                       | Retains all registry checks; adds the exact new fixture-aware invocation                                                                                                              |
| This task record                                                                | Authority, scope, verification, rollback and unresolved K2 boundary                                                                                                                   |

The guard protects every existing identity column, including nullable expected version and start time. INSERT must start IN_PROGRESS with no response/error/completion. The only material UPDATE is one IN_PROGRESS-to-terminal completion with response and completion time. Terminal changes and all deletion are rejected. An identical no-change UPDATE remains harmless. Historical terminal rows are neither revalidated nor rewritten.

Nested Planning commands previously completed the shared receipt early, and the outer finalizer replaced its result. The common helper now defers the four shared atomic Planning command names to the existing dedicated finalizer. Normal Need Generation constructs its final response, completes it once, then flushes unchanged continuity/corruption guards inside the original rollback subtransaction. The zero-bridge's prior completion/flush remains intact. No quantity, source-authority, continuity predicate or public API changed.

## Verification

| Check                                                               | Result                                                                                         |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Original mutation/result/replay prerequisite                        | RED: 18 PASS / 3 FAIL; GREEN: 21 PASS / 0 FAIL                                                 |
| New receipt integrity suite                                         | 50 PASS                                                                                        |
| Atomic Planning / zero-demand / selective continuity                | 258 / 72 / 42 PASS                                                                             |
| K1 / RMVP-04 / H1B1 chain / H1B1 policy                             | 81 / 87 / 48 / 48 PASS                                                                         |
| PA-05C / Planning / Procurement / Dispatch setup                    | 36 / 69 / 74 / 47 PASS                                                                         |
| School PXK / supplier PO / Purchase Review                          | 134 / 161 / 193 PASS                                                                           |
| Pantry direct-ingredient persistence/materialization                | 144 PASS                                                                                       |
| Current platform security / runtime hardening                       | 30 / 1 PASS                                                                                    |
| RMVP-03A / RMVP-05 / RMVP-06 / RMVP-07                              | 77 / 41 / 65 / 67 PASS                                                                         |
| Concurrent receipt completion                                       | 3 PASS, actual waiting sessions, unchanged eight-second timeout                                |
| Certification registry tests                                        | 116 PASS                                                                                       |
| Migration replay from exact base                                    | PASS; second application fails atomically without altering the installed catalog               |
| Existing RLS, policies, table ACLs and function security properties | Unchanged                                                                                      |
| Cluster-global role memberships before/after fresh final migration  | Exact temporal equality; original Need ownership inheritance retained and runtime SET disabled |
| Exact-head Frontend, Smoke and executed Full Integration            | Required final gate; run URLs and actual outcomes are recorded in the Draft PR                 |

The 22 relevant SQL suites total **1,825 passing assertions**. Browser transport/UNKNOWN and full integration remain part of the final CI gate; SQL in-flight replay also retains the exact retryable concurrency response. The extra local command-suite checks supplement the connected browser verification.

The security catalog changes only from 351 to 352 private functions and 126 to 127 triggers, with their two exact updated digests. Relation count, policies, grants, public API count, runtime roles, all other catalog digests and existing function security attributes are unchanged. Temporary migration authoring access closes by restoring the original SET-disabled Need inheritance edge, rather than deleting that edge.

The original failed K2 evidence remains untouched. New red/green SQL, complete logs, mutation role diagnostics, initial compatibility failures, concurrency transcripts and temporal catalog proof are retained in this task's local evidence bundle. Initial missing-fixture invocations are not counted as passing RMVP-06/07; the passing checks use the established fixture injection. An unintentionally started broad local UI run was stopped; its timing failure is not a certification result. The targeted registry check passes, and required frontend certification runs independently on the exact pushed head.

Independent security/source review found and verified fixes for the bridge-flush targeting and fixture-aware registry routing. It reviewed the guard, helper sequence, original rollback boundary, fixture changes, runtime probes, catalog delta and remaining authority limitation. Exact-head CI is a separate gate, not inferred from source review.

## Remaining K2 authority limitation — DECISION REQUIRED

An existing private runtime can still INSERT a fresh IN_PROGRESS receipt with the unsupported name `prepare_corrected_need_transfer`, then complete it through the existing helper **without invoking Preparation**. Direct terminal INSERT is blocked, but valid receipt lifecycle is not command provenance. The focused test proves this produces no authorized allocation-family binding and rolls all test evidence back.

Do not interpret this checkpoint as K2 transfer authorization. The Preparation provenance boundary remains DECISION REQUIRED; any future source guard must independently prove the exact current Need revision/decision and contributors, original released Need/Handoff, prepared family revision and accepted supplier splits, plus complete supplier/date membership. No new certificate, typed source successor, official PO eligibility, PO-002/PO-003 or PXK authority change is installed here. Staff activation remains prohibited.

## Migration and rollback constraints

The forward migration is transactional and performs no business-data backfill. Failure rolls back the guard, helper changes and temporary authoring privileges together. Existing immutable snapshots and historical receipt contents remain unchanged. PostgreSQL rollback removes aborted receipts without DELETE or a trigger bypass.

After commit, do not downgrade just one helper or drop just the guard: the shared Planning completion order and terminal protection are one compatible amendment. Any later rollback requires a reviewed coordinated forward migration; removing terminal protection would reopen the demonstrated failure. Hosted installation, merge and deployment remain outside this checkpoint.
