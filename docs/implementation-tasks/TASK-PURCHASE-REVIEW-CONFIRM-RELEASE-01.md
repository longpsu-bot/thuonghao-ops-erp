# PURCHASE-REVIEW-CONFIRM-RELEASE-01 implementation evidence

## Delivery scope

Branch: `feat/purchase-review-confirm-release-v1`.

Base: `93af319d3a9e133614e2221202c114c0d586018e` (`origin/main` verified at task start). The explicitly authorized checkout is `E:/Project/OPS ERP/thuonghao-ops-erp`. Implementation stays in Planning, school-catering Procurement, their private source adapters, tests, documentation and CI registration. One implementation agent and exactly two read-only auditors were used. Both final audits report no remaining actionable blocker.

The [approved design](../superpowers/specs/2026-09-03-purchase-review-confirm-release-design.md), [execution plan](../superpowers/plans/2026-09-03-purchase-review-confirm-release.md), [Procurement API amendment](../api/school-catering-procurement.md#purchase-review-confirm-release-01-amendment) and [Confirmed Need amendment](../api/confirmed-need-save-release-v2.md#purchase-review-and-confirmed-allocation-amendment) describe the implemented boundary. No hosted, Atlas Staging, Retool or live OPS write was performed. Warehouse and released-PO amendments remain out of scope.

## Implemented decisions

- Generated review and XLSX use current generated quantities only and create zero operational or acceptance facts.
- Saved confirmed quantities, never generated fallback, drive explicit pre-Handoff supplier allocation in the existing four Allocation Family relations.
- Typed revision/contribution XOR preserves exact confirmed revision/decision or Handoff line evidence. No table, capability or application role was added.
- Need correction retains saved splits as stale; rebalance remains advisory until Apply and Save.
- Planning continuation is navigation-only and carries the exact working date.
- One transactional backend preparation command guards release, creates real Handoff evidence, appends allocation successors without recomputing splits, and prepares official drafts. Existing independent PO release owns official numbering and immutable supplier commitment.
- Superseded reads cannot update a new scope. Unknown outcome/readback failure locks mutations; pending exact retry blocks fresh writes and is discarded on scope/stage change or explicit refresh.

## Database verification

All suites below ran against local PostgreSQL with rollback-isolated fixtures on 2026-09-03. No reset of the user's local database was used. The harness expands repository-local SQL includes because the standard pgTAP container does not mount `supabase/local`.

| Suite                                                   | Passing assertions |
| ------------------------------------------------------- | -----------------: |
| `purchase_review_confirm_release.sql`                   |                 76 |
| `purchase_handoff_clock_skew.sql`                       |                  6 |
| `rmvp_05_connected_confirmed_need_review.sql`           |                 41 |
| `rmvp_06_connected_confirmed_need_validation.sql`       |                 65 |
| `rmvp_07_connected_confirmed_need_approval_release.sql` |                 67 |
| `d037_confirmed_need_save_release_boundary.sql`         |                 33 |
| `school_catering_handoff_allocation.sql`                |                 88 |
| `school_catering_planning_correction.sql`               |                 18 |
| `school_catering_purchase_orders.sql`                   |                 67 |
| `atlas_current_platform_security_catalog.sql`           |                 22 |
| **Total**                                               |            **483** |

The first-class public-command scenario proves generated100 → saved120 → saved72/48 → saved125 → stale retained72/48 → explicit75/50 → Handoff successor → PO quantities75/50 → independent release and backend numbering. It also proves incomplete-source refusal, no eligible supplier, historical tied priority, scope denial, exact replay/conflict, stale batch/family/fingerprint, precision rejection, released-before-Handoff recovery, plural Handoff lineage, exact PO coverage, legacy Handoff read compatibility and released snapshot immutability. Existing PO regressions independently retain unaffected supplier/date roots. Historical ambiguity/multi-Handoff fixtures use isolated, rolled-back seed contexts; real allocation and preparation commands run with normal guards.

`pnpm exec supabase db diff --local --schema atlas_core,atlas_planning,atlas_procurement,atlas_api` successfully applied every migration, including the new one, to a fresh separate shadow database and reported **No schema changes found**. This verifies fresh migration application without resetting the working database.

## Frontend and workbook verification

Focused Vitest: **310 tests in 16 files passed**, covering the changed Atlas shell/RPC registry, Procurement directory, Confirmed Need directory, Planning Inputs workbench, certification contract and local allocation helper. Typecheck and diff whitespace check passed. Touched supported files were formatted with Prettier.

The full-shell regression proves Save120 → Procurement120 (not generated100) → return to the same Planning date. Deferred-read tests reproduce the superseded-readback race; retry tests prove only the retained recovery action remains enabled. Existing released PO XLSX/PDF tests pass unchanged.

The v1 reference is the read-only 2026-02-27 Retool snapshot's `lib/js_exportPOZip.js`, not an invented workbook template. The new preliminary export preserves its two-sheet summary/detail arrangement, A4 portrait fit-to-width, repeated rows1–9, Times New Roman, table borders and supplier/School bands. Documented adaptations are one selected-date workbook instead of official per-supplier ZIP, preliminary headings, exact text quantities, wider correction/quantity columns, and blank unavailable business codes. No logo/address was fabricated. Both sheets were imported and visually rendered with the bundled spreadsheet renderer; labels, warning rows and correction space are legible. The renderer trims trailing decimal zeroes visually, while workbook readback tests verify the exact stored decimal text, including values beyond JavaScript's safe integer range.

To reproduce an inspection workbook, set `PURCHASE_REVIEW_QA_XLSX` to a temporary absolute output path and run the `GeneratedPurchaseReview.test.tsx` suite. This opt-in test artifact is synthetic and not an operational document.

## Browser QA

Synthetic Storybook stories share one in-memory Planning/Procurement state machine and call its public-shaped APIs to seed six states. All six states were inspected at **1366×768, 1920×1080, 900×900, 650×900 and 360×800**. All **30 measurements** had document scroll width equal to client width. Dense tables retain their own bounded horizontal scroll, not page overflow.

| State           | Observed result                                                                                                |
| --------------- | -------------------------------------------------------------------------------------------------------------- |
| Generated100    | Preliminary banner, supplier suggestion and XLSX action; open focuses heading, close returns focus to trigger. |
| Confirmed120    | Saved quantity and reason remain editable; one navigation-only continuation action.                            |
| Allocated72/48  | Confirmed120, allocated120, remaining0; participants-only editor; panel close returns focus to its row action. |
| Stale after125  | Retains72/48; remaining5; separate75/50 proposal; Save/preparation blocked until explicit acceptance.          |
| Official drafts | Two supplier drafts; selected detail shows75; one independent release action; no official number/export yet.   |
| Released POs    | Official number, immutable75 detail, XLSX/PDF outputs; no release action.                                      |

Keyboard Enter on preparation reaches official drafts and focuses the `Đơn mua` heading. Mobile screenshots confirmed readable supplier inputs, exact balances, proposal text and full-width action controls. Browser inspection caught and fixed new preview/preparation button contrast. Recovery regressions separately protect one primary action when retry is pending.

Additional full-Atlas-shell browser checks at1366×768 and360×800 verified Save120 → same-date Procurement120 → return to Planning with saved120 and the original date. Planning continuation now focuses the destination allocation heading; a red-first full-shell regression protects this without changing mobile sidebar focus return. Settled document widths match client widths in both layouts (1366 and345 respectively).

Console caveat: Storybook's internal documentation type-converter logs `Cannot read properties of undefined (reading 'filter')` from `storybook_internal_docs-tools.js`. No inspected diagnostic originated in the product component code and the stories rendered/operated. This tooling diagnostic is disclosed rather than reported as a clean console or a proven baseline defect.

## Migration, security and rollback

Migration: `20260903072648_purchase_review_confirm_release.sql`. It extends existing revisions/contributions, adds four shaped APIs and private adapters, guards release/promotion/PO consumers, and makes the bounded Handoff clock tolerance explicit. Existing Handoff rows retain their source and evidence. The exact security catalog remains 107 forced-RLS tables, 29 capabilities and 11 application roles; public API count becomes103. Runtime SET/CREATE grants used during migration are explicitly removed. React receives no service-role credentials or table access.

Before any confirmed-source allocation exists, reversal still requires a reviewed compensating migration restoring affected function/trigger definitions and grants. Once typed confirmed or promoted history exists, **do not drop source columns or rewrite/delete history**; use a forward fix. Reverting only the frontend is not a complete rollback because backend release now requires saved allocation. No production migration/rollback was executed.

B1: controlled local requests show browser timestamps at server−1second, +1second and +60seconds reach source validation; +61seconds, malformed identity and extra payload remain rejected. This does **not** establish the historical Staging incident's cause. Internal preparation children use backend timestamps. Historical incident diagnosis remains unproven, not silently declared solved.

## CI and review boundary

The Draft PR must remain unmerged. Frontend CI owns the broad suite; Draft Supabase Smoke now includes the new regression suites and include-aware existing release tests. Full Supabase Integration keeps its normal ready-for-review/main trigger policy. CI status and exact delivered head belong to the PR/check runs, not a self-referential hash inside this document. Passing local checks are not a claim that hosted CI passed or that this branch is ready to merge.

The first CI run passed Frontend CI and its bounded pgTAP step, then exposed a local verifier transport defect: the pinned Supabase CLI prepares one statement and rejects the helper's three top-level fixture inserts. A follow-up wraps those same local-only inserts in one atomic `DO` block, flattens newlines for the Windows pnpm shim and preserves stderr diagnostics. The helper regressions failed before this fix and passed afterward (80 focused helper/certification assertions). The exact generated fixture SQL also passed the pinned CLI inside an outer rollback-isolated subtransaction. No production migration or business command changed.

## PR #251 closeout — 2026-09-03

This section supersedes the earlier validation boundary for the closeout. Starting head: `e8c32c653dd339441c2631c587b5df5aac685634`. The user confirmed `D:/Project/Repo/OPS/thuonghao-ops-erp` as this task's canonical checkout. Remote, clean initial worktree, base and PR head were verified; the existing PR was restored to Draft. This closeout uses one agent and no delegated or parallel agent work.

### H0Cb fixture and production guard

[Full Integration run 33757882135](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/33757882135) exposed a synthetic lifecycle setup in `pa_06e_h0cb_errors_authorization_concurrency.sql`. Its direct `RELEASED_FOR_PURCHASE_HANDOFF` update has no Procurement allocation evidence. The production release guard correctly aborts it after 46 of 112 planned assertions. The fixture is testing CMD-15 materialization/error semantics, not release readiness.

Only that one fixture update now runs between transaction-local `session_replication_role=replica` and immediate restoration to `origin`, following the existing fixture convention in the same suite. Subsequent authenticated commands and assertions run with normal triggers. No production function, migration, trigger definition, privilege, RLS policy or cross-stage purchase-review test changed.

Clean local RED reproduced 46 successful assertions followed by the guard exception; GREEN passed **112/112**. The unchanged `purchase_review_confirm_release.sql` passed **76/76** using the repository's include-aware harness. It still asserts `CONFIRMED_ALLOCATION_NOT_READY`, retained `DRAFT_REVIEW` editability, immutable stale split history, exact promotion and independent supplier PO release.

The required full local run then passed H0Cb and exposed stale current-platform expectations in Pantry assertions PNG02-049/050: **142/144**, with ordinary triggers **54 vs 53** and constraint triggers **49 vs 46**. The exact delta is the existing PR migration's `purchase_review_confirmed_need_release_readiness` plus `purchase_review_revision_integrity`, `purchase_review_contribution_integrity` and `purchase_review_split_integrity`. The catalog test now expects 54/49 and additionally checks those exact relation/name bindings, normal enabled state, and deferred constraint properties. It retains all previous RMVP-06/07 arrays and the full 144-test plan; no Pantry behavior or production trigger changed. A second full run is required after this PR-caused catalog correction because the first did not certify the repository.

The second full run passed every SQL suite, then exposed a PR-caused ordering error in the full upstream v1 verifier: RMVP-07 attempted its confirmed-allocation prerequisite after RMVP-06 had already made Need `VALIDATED` and non-editable, correctly receiving `SOURCE_NOT_EDITABLE`. When `RMVP07_CONTRACT=v1`, the RMVP-06 local verifier now saves allocations through the existing public-command helper before validation. RMVP-07 retains its approval/release/replay assertions and skips already balanced rows through the unchanged helper. No production editing boundary is relaxed. Full certification must complete after this fixture-order correction.

Final local full-integration attempt: **blocked, not certified**. The first **79/80 commands passed**, including every top-level SQL suite, the corrected full upstream RMVP-06/07 v1 chain, D-037, and Planning Contract 01. The final `local:school-catering-procurement:verify` passed its 18/18 correction and 67/67 PO SQL assertions, then failed while reinstalling `rmvp_05_browser_fixture.sql`.

The Windows run exposed a separate local infrastructure concern: `releaseConfirmedNeed()` in `scripts/verify-local-school-catering-procurement.mjs` passes a multiline count query through the Windows pnpm/Supabase `.cmd` shim. A local argument-only probe of that exact shim showed only `select count(*)::integer ready_count from atlas_planning.confirmed_need_batches` reached the executable; both batch/status predicates were dropped. A single-line control retained both predicates. The unchanged multiline query is also present at base `93af319d3a9e133614e2221202c114c0d586018e`. With several upstream batches, the verifier incorrectly attempts to reinstall the existing deterministic RMVP-05 fixture. The earlier conclusion that this was the sole remaining blocker was incorrect: Linux Full Integration run 33772677328 subsequently failed installing the canonical Procurement fixture because the PR-added helper had seeded its role/capability pairs under non-canonical identities. See the corrective record below.

Windows reserved the default local Supabase ports in `54243–54442`. Local validation temporarily used `5532x` ports in `supabase/config.toml`; the original configuration was restored byte-for-byte. A clean local reset removed old synthetic fixture data before RED/GREEN; the full script also performed its prescribed local resets and cleanup. Docker Desktop was stopped after local testing. Hosted Staging, live OPS and Retool received zero writes.

### Operator continuation

The action is `Tiếp tục lên đơn`. Supporting copy explains that Atlas checks confirmed Need/allocation and prepares orders for review before release. It still invokes `PURCHASE-COMMITMENT.v1` through the unchanged `prepare_school_catering_purchase_orders` command. Successful authoritative readback opens `Đơn mua`; `Phát hành cho NCC` remains a separate supplier commitment. No backend lifecycle, request envelope, automatic release or retry behavior is added.

### Qodana disposition

Exact evidence: [Qodana check 100609951437](https://github.com/longpsu-bot/thuonghao-ops-erp/runs/100609951437), [report 4kBZ8o](https://qodana.cloud/projects/dX46Q/reports/4kBZ8o), at starting head. The High finding (GitHub annotation level `warning`) was `Redundant character escape` at `PlanningInputsWorkbench.test.tsx:162`: `\]` outside a character class. Removing that single backslash preserves the regular expression's matching behavior.

All eight Moderate findings (GitHub annotation level `notice`) were inspected at their starting-head locations and retained as non-blocking notices:

| File / starting line                              | Disposition                                                                                 |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `PlanningInputsWorkbench.test.tsx:957`            | Similar Attendance setups assert different persisted/default behavior; keep explicit tests. |
| `reviewMasterDataApi.ts:548`                      | Ingredient creation reference resolution; unrelated to this closeout.                       |
| `reviewMasterDataApi.ts:590`                      | Ingredient update reference resolution; extraction would broaden scope into master data.    |
| `PlanningInputsWorkbench.tsx:697`                 | Bounded service-date enumeration; no date behavior change needed.                           |
| `verify-local-planning-contract-01.mjs:1`         | Existing local verifier request/fixture helpers; no infrastructure refactor needed.         |
| `dishRecipeAdminDomain.ts:906`                    | Recipe line validation/update; outside Procurement closeout.                                |
| `reviewConfirmedNeedApi.ts:394`                   | Review adapter decision/count projection; avoid changing authority simulation.              |
| `SchoolCateringProcurementWorkbench.test.tsx:872` | Stale-version recovery setup; explicit outcome assertions remain useful.                    |

No duplication suppression, broad extraction, test disabling or production guard weakening was used. There is no new migration or rollback operation; reverting the closeout changes only fixture setup, operator copy, tests/stories and this evidence record. The existing migration's forward-fix/history preservation guidance above still applies.

### Closeout validation and browser evidence

- Focused Vitest: **171/171 tests in 7 files passed** (`GeneratedPurchaseReview`, `ConfirmedNeedReviewWorkbench`, `ConfirmedSupplierAllocationWorkbench`, `SchoolCateringProcurementWorkbench`, `AtlasApp`, `purchaseReviewApi`, and the Qodana-touched `PlanningInputsWorkbench`). The renamed-action regression first failed against the old button copy, then passed after the copy-only implementation. Coverage includes disabled incomplete/stale/unbalanced allocation, the exact existing preparation envelope, authoritative PO readback, preserved service date, no automatic release, explicit supplier release, unknown outcomes and retained exact retry.
- `pnpm typecheck`, Prettier on touched supported files, and `git diff --check`: passed. SQL files use the existing SQL style and whitespace check; no SQL formatter or dependency was added.
- Historical targeted database results: H0Cb **112/112**, unchanged purchase-review regression **76/76**, corrected Pantry catalog **144/144**. That Windows full-integration attempt was **blocked at its final command**, not passed or skipped; the later Linux failure and corrective validation are recorded below.
- Browser: repeated the complete populated, in-memory Atlas-shell journey at **1366×768, 1920×1080, 650×900 and 360×800**: preview100 → save120 → allocation72/48 → `Tiếp tục lên đơn` → two draft POs → review72 → explicit `Phát hành cho NCC`. The other supplier remains a draft. **36 journey measurements plus 3 stale/unknown/retry measurements had zero page-level horizontal overflow**; dense tables keep their own horizontal scroll. Each full-shell state had one operative service-date control, preserving `2026-08-31` across Planning/Procurement. Export/line dates repeat the same context rather than adding another date selector.
- Focus: preview heading on open and trigger on close; saved Need continuation; allocation heading; row action after closing allocation; `Đơn mua` heading after Enter on continuation; supplier heading on opening PO detail. Existing limitation observed: after explicit release removes its button, focus falls back to the document body. Closeout does not change that release handler or claim flawless focus for this transition.
- Visual inspection confirmed readable 120/120/0 balances, 72/48 supplier inputs, the new supporting copy, one enabled continuation action after closing the allocation editor, and a separate final release action. Stale125 retains72/48, shows remaining5 and a separate75/50 proposal; continuation and Save remain blocked until explicit acceptance. Unknown outcome requires refresh; retryable outcome retains only the recovery write action.
- Console: **8 errors**, all from `storybook_internal_docs-tools.js` with the disclosed `filter` diagnostic; **zero product-code errors or other warnings** in the collected log.

Local evidence is retained under `%TEMP%/atlas-pr251-closeout/`: `h0cb-clean-red.log`, `h0cb-green.log`, `purchase-review-green.log`, `pantry-catalog-green.log`, the three full-run logs, `windows-shim-probe.log`, `ui-copy-red.log`, `vitest-focused.log`, `typecheck.log`, `browser-qa.json`, `browser-console.json`, and viewport screenshots. Final full-run log: `full-integration-complete.log`, SHA-256 `9290855936ac19ed10ddf059ac93ef45227d07b607016a369c22165c412fc7b8`. GitHub checks on the pushed head and the immutable preview URL are recorded in the PR body; this local evidence does not substitute for a passing full certification.

## PR #251 canonical capability-binding correction — 2026-09-03

Ready-state Linux [Full Integration run 33772677328](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/33772677328) disproved the preceding Windows-only blocker diagnosis. Its Procurement planning-correction and purchase-order suites passed, then `school_catering_procurement_verifier_fixture.sql` failed with the natural-key uniqueness error on `(role_id, capability_id)`. The PR-added `local-confirmed-supplier-allocation.mjs` had inserted the Procurement read/write bindings without explicit `role_capability_id` values. The canonical fixture later tried to install those same logical bindings under its established deterministic identities and collided.

The helper now reuses canonical read identity `b6000000-0000-4000-8000-000000000035`, write identity `b6000000-0000-4000-8000-000000000036`, synthetic role `b6000000-0000-0000-0000-000000000003`, and grant Actor `b6000000-0000-0000-0000-000000000001`. Its single prepared `DO` statement remains flattened for the Windows shim and uses `on conflict do nothing` for replay. The pre-existing canonical Procurement fixture, production migration, constraints, capabilities, RLS and runtime roles remain unchanged.

Starting head was `31eed4ec2614fca9fe364e14152c48f44e0a0e27`; PR #251 was restored to Draft before editing. The user confirmed the canonical checkout. Only the helper, its focused test and this record changed in this correction.

The focused regression failed against the anonymous binding insert (**1 failed, 4 passed**) and passed **5/5** after the helper change. On a fresh disposable local stack, the smallest targeted sequence was `pnpm local:auth:provision`, then `pnpm local:rmvp06:verify` with `RMVP07_CONTRACT=v1` and the default short fixture source, then `pnpm exec supabase db query --local --file supabase/local/school_catering_procurement_verifier_fixture.sql` twice. RMVP-06 used the same pre-validation helper path as the full-upstream v1 verifier and passed validation/replay/readback. Database reads before and after both canonical installs returned exactly `0035`/`0036` with the canonical role and grant Actor, without a natural-key collision. Full-upstream execution remains part of the complete certification sequence.

After a clean local reset, `node scripts/test-local-purchase-review.mjs purchase_review_confirm_release.sql` passed **76/76**; `pnpm exec supabase test db supabase/tests/school_catering_planning_correction.sql --local` passed **18/18**; and `pnpm exec supabase test db supabase/tests/school_catering_purchase_orders.sql --local` passed **67/67**. Full Integration and exact-head CI results are recorded in the PR body after completion.

Security review is limited to the fixture correction: grants now target only the existing canonical synthetic role; authoritative business commands, RLS, production capabilities and runtime roles have no delta. No migration or rollback was executed against a hosted database. Reverting this correction affects only local fixture seeding and regression evidence; disposable local resets remove test state. No UI changed, so browser QA was not rerun. Staging, live OPS and Retool received zero writes.

The required single Windows `pnpm certify:supabase:full-integration` attempt passed its first **79/80 commands**, including the full-upstream RMVP-06/07 allocation/release path and both applications of the corrected helper. At command 80, the final verifier again passed planning correction **18/18** and purchase orders **67/67**, then failed before its allocation helper while reinstalling `rmvp_05_browser_fixture.sql`. Inspection matched the separate, pre-existing Windows multiline-shim behavior documented above: the `ready_count` SQL argument in `releaseConfirmedNeed()` loses its batch/status predicates and incorrectly selects the fixture-install path, as recorded in the argument-only probe. No new failure was stacked onto the capability fix and no unrelated verifier change was made. The exact log is `%TEMP%/atlas-pr251-canonical-bindings/full-integration.log`, SHA-256 `5C054188EB9CD98F64E26B6902144A02404F6505D077A29DA9EC6A7532EED6DE`. This Windows attempt failed and is not certified. PR #251 remains Draft pending a completely passing standard Linux Full Integration run and exact-head checks, whose final results are recorded in the PR body.

Final local helper Vitest **5/5**, `pnpm typecheck`, touched-file Prettier, and `git diff --check` passed. The local certification script cleaned up its disposable stack. No production configuration was changed.
