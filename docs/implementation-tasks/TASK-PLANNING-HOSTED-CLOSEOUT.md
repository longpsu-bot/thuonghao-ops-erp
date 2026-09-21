# Planning hosted closeout

Authority: OPS_SYSTEM_MAP v1.0 / ARCH-002, D-036, D-041 and H1A. Owner approved the remaining performance correction, explicit Staging count-unit policies, merge/deployment and real generation -> edit -> Save -> reopen acceptance. Baseline `f75abebbb0b7d924a4a89e6872beeda6a0a3b7c5`.

## Evidence and correction

The real 17/09/2026 source has 304 atomic contributions and 248 grouped Confirmed Need rows. EXPLAIN found repeated filtering of 303 unrelated contribution members and repeated current-revision scans. A single partition query took 33.218 ms; row events repeat it hundreds of times. The expanded regression keeps the existing 32 assertions and adds a late-current-ownership-hole assertion, now with 480 atomic and 480 grouped rows. The unchanged baseline timed out at 8,000.689 ms.

Three non-unique indexes support exact release-member and stable-line lookups. Indexes alone and a full-set materialization experiment did not resolve the grouped-row cost. The selected correction keeps complete partition validation at batch creation/source-advance events and bounds child checks to release members affected by their immutable stable-line/revision history. Each affected member is still counted against ALL current owners, so cross-line duplicates and missing current owners remain invalid. Historical changes retain the full-batch path. No client flag, queue, cache, disabled trigger or timeout increase is introduced.

Profiling after that correction moved the cost to immutable contribution facts. Their heavy revision/source/quantity/predecessor join now follows the same current-revision scope, while a separate GLOBAL School/customer ownership query preserves the mutable-reference check. Historical changes still force full facts. The original full predicate, including School ownership, remains inside the scoped check as well. Immediate composite foreign keys and immutable guards preserve the dependencies used in this proof.

## Exact Staging policies

The independent DML package installs step 1 for exactly Quả, Bó, Gói, Cốc, Miếng, Cái, Hũ, Chai, Cây, Lon, Ổ, Bịch, Hộp and Trái, effective 14/09/2026. Every imported code must match its approved UTF-8 name, active status and COUNT dimension. There is no new Unit or generic dimension fallback. Existing kg=0.01 is unchanged.

Database-generated policy IDs, typed existing Staging operator identity and current activation timestamps record administration. Exact replay changes no record. Conflicting identity, step, effectivity, lifecycle or revision rejects the transaction. Eight rolled-back SQL tests cover installation, exact replay, unsupported units, kg preservation and conflicts. Normal database migration/CI never installs these hosted policies.

## Hosted acceptance

After exact-head frontend and full database certification, deploy only to Atlas Staging using the existing protected workflow. The separate closeout workflow reuses those protected target settings and main-only preflight, tests the policy package with rollback, installs and replays it, and makes seven rollback-only daily probes: three for 17/09 and one for each other populated weekday. All commands retain the eight-second authenticated budget, complete editable review, no hidden pagination and no policy blockers. The unchanged 17/09 source must reconcile exactly 248 rows.

Only the explicit persist_rehearsal=true option performs one retained browser journey in the unchanged Chakra preview. It uses normal sign-in, selects 17/09, clicks Generate once, checks all rendered rows and authoritative readback, makes one noted next-cent kg edit, clicks Save once, leaves/reopens the tab and verifies the same values. Unedited decisions and theoretical quantities must remain unchanged. No unknown write is blindly retried, and no Procurement release is permitted.

No live OPS v1, Retool, Google Sheet, Apps Script, PR #286 or production-cutover change. Retool comparison uses retained exported workflow evidence, not fresh live UI certification. Existing source headers and lines must preserve their pre-task fingerprints. Final CI, deployment and operator results are recorded on the PR.

Rollback: a forward migration restores the two previous guard bodies and removes only these three indexes. Policy correction requires controlled retirement with retained history, never deletion after use. A retained Staging verification edit is explicitly identified in the final evidence.

## Closeout verifier statement-snapshot correction

After PR #305 deployed, the policy package installed and replayed successfully.
The first hosted 17/09 generation succeeded in 4,723.197 ms, but the automated
review in the same SQL statement could not observe the new batch. The review
RPC is STABLE. A fresh rollback-only probe using separate generation and review
statements succeeded in 5,782.007 ms and returned all 248 editable rows with no
blockers and no pagination remainder. No operational record was retained.

The verifier now materializes the generation response into a transaction-local
temporary table and performs the authoritative read in a subsequent statement,
mirroring the browser's separate calls. The transaction still always rolls back,
the eight-second role limit stays unchanged, and there is no retry or schema,
policy, frontend, PR #286 or live v1 change. A regression asserts the separate
statement boundary and safe review error category in failed probe diagnostics.

## Browser navigation closeout correction

Protected run `35332222044` completed all seven rollback generation/read probes,
then stopped before Generate at `BROWSER_GATE_button_Xác nhận nhu cầu`. The
application starts on the School capability, whose exit guard intentionally
ignores navigation while its initial authoritative read is loading. The browser
verifier clicked `Lập nhu cầu` only once as soon as the shell appeared, so that
guard could reject the click and the Planning phase tablist never mounted.

The verifier now treats primary and phase changes as safe navigation rather than
consequential writes: it scopes `Lập nhu cầu` to the Atlas navigation buttons,
scopes `Xác nhận nhu cầu` to the `Giai đoạn lập nhu cầu` tablist, and retries only
until the exact destination surface is rendered. Generate and Save remain
one-shot actions and retain the unknown-outcome rule. Safe diagnostics record the
URL, rendered roles, labels, and disabled states after sign-in, authentication,
Planning mount, and Confirmed Need mount. No application, backend, policy,
quantity, authentication, PR #286, or production-cutover behavior changes.

## Need Generation tail-latency stabilization

Rollback-only 17/09 profiling at the unchanged authenticated eight-second limit
reproduced 304 atomic contributions and 248 current Confirmed Need groups. Normal
executions ranged from 5,470.127 ms to 6,341.340 ms. The stable high-fanout paths
were 1,013 Need Generation integrity calls and 552 Confirmed Need membership
calls; current-source consistency remained secondary. No lock waiter or deadlock
was present. Recent autovacuum activity, low persistent live/dead row counts, and
stable call geometry gave no evidence that vacuum or statistics caused the
variance. Every diagnostic preserved all six approved source fingerprints.

The controlled plan comparison isolated repeated custom planning as the tail
amplifier. `force_custom_plan` reached 8,007.970 ms and returned the existing
retryable timeout classification, while the same workload under
`force_generic_plan` completed in 4,594.096 ms. The bounded correction sets
`plan_cache_mode=force_generic_plan` only on
`atlas_api.execute_need_generation(jsonb)`. It does not change a role setting,
the eight-second timeout, any query or trigger body, privileges, lifecycle,
calculation, source selection, response contract, or integrity predicate.

The scale regression now matches the real grouping geometry and performs fresh
sequential daily commands and authoritative reviews. Existing adversarial checks
continue to reject forged quantity, omitted Recipe composition, incomplete
release membership, forged Confirmed Need contribution quantity, missing
Confirmed Need membership, immutable-evidence mutation, duplicate release
membership, and loss of current ownership. Because only planner selection
changes, every invariant executes through the same functions and predicates.

Three rollback-applied correction probes completed in 4,829.181 ms,
3,899.521 ms, and 3,888.307 ms. Both complete review probes returned exactly 248
rows, `CURRENT`, editable state, zero blockers, and no pagination remainder.
Each probe rolled back the temporary function setting and all generated facts;
fresh checks found zero retained rehearsal-week runs/batches and exact source
fingerprints. These are diagnostic results, not the post-merge protected closeout.

Rollback is a forward migration that runs
`alter function atlas_api.execute_need_generation(jsonb) reset plan_cache_mode`.
No data rollback, policy rollback, or recalculation is required.

## Protected Staging catalog verifier correction

The protected deployment of `90aa9c1c04a910c13166a12ef9c023646313badf`
applied migration `20260920154302` successfully, then failed during the
read-only platform catalog verification. The verifier still required every
`atlas_api` function to have exactly `search_path=""`, so it rejected the
approved function-local `plan_cache_mode=force_generic_plan` setting on
`atlas_api.execute_need_generation(request jsonb)`.

The catalog verifier now keeps the default exact `search_path=""` rule for
every other `atlas_api` function and models one explicit governed exception by
function name and identity arguments. That command must remain `SECURITY
DEFINER` and its configuration must be exactly the order-independent set
`search_path=""` plus `plan_cache_mode=force_generic_plan`. Missing, wrong,
duplicate, or additional settings fail closed. Signature, ownership, execute
grant, schema grant, private-relation exposure, policy-catalog, and application
role checks remain unchanged.

This correction changes repository verification logic only. It adds no
migration, does not modify the deployed function, and performs no Staging or
OPS v1 mutation. The protected deployment must be rerun only after this change
is approved and merged; its prior failed run is not deployment-pass evidence.

## Final hosted browser-contract hardening

The final verifier-only audit reconciled the lead review with one independent
read-only reviewer. It found three deterministic harness defects beyond the
reported calendar mismatch: the Sources workbench could satisfy the old
Confirmed Need destination selector, reopen had the same collision, and the
protected performance predicate still allowed generation below 8,000 ms rather
than the approved strict 7,000-ms engineering margin. No product, backend,
workflow or migration defect was found.

The exact candidate is the immutable Cloudflare deployment
`https://0d969e3b.thuonghao-ops-erp.pages.dev/`. Cloudflare Check Run
`105147561944` records that URL for PR #286 head
`dcf6be78cd71b4eca4565a5d014f7f4b86888103`. The moving branch alias is no
longer used by this closeout verifier, and PR #286 remains unchanged.

Installed package authority is `@ark-ui/react` 5.39.0 with
`@zag-js/date-picker` 1.43.3. In that exact implementation, DatePicker Content
is an Ark `div` with `role="application"`; PrevTrigger, NextTrigger and Trigger
are Ark `button` elements; and TableCellTrigger is an Ark `div` carrying
`role="button"`, `data-part="table-cell-trigger"`, `data-view="day"` and an ISO
`data-value`. The browser therefore uses anatomy and accessible-state selectors,
never an HTML-tag assumption for day cells.

### Complete selector and action audit

|   # | Browser action             | Product / library authority                              | Actual DOM or API contract                                                        | Final verifier selector / action                                                                                   | Status             |
| --: | -------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------ |
|   1 | Sign-in email              | `AtlasSessionGate.tsx`                                   | Native input, `id="atlas-signin-email"`                                           | `#atlas-signin-email`                                                                                              | Retained, valid    |
|   2 | Sign-in password           | `AtlasSessionGate.tsx`                                   | Native password input, `id="atlas-signin-password"`                               | `#atlas-signin-password`                                                                                           | Retained, valid    |
|   3 | Đăng nhập                  | `AtlasSessionGate.tsx`                                   | Enabled Chakra button with exact text                                             | Exact enabled button text `Đăng nhập`                                                                              | Retained, valid    |
|   4 | Authenticated Atlas nav    | `AtlasVNextShell.tsx`                                    | `nav[aria-label="Điều hướng Atlas"]`                                              | Exact nav landmark                                                                                                 | Retained, valid    |
|   5 | Lập nhu cầu navigation     | `AtlasVNextShell.tsx`                                    | Chakra button inside the Atlas nav                                                | Scoped exact-text button; retry only until Planning tablist mounts                                                 | Retained, valid    |
|   6 | Planning phase tablist     | `PlanningCapability.tsx`                                 | `role="tablist"`, label `Giai đoạn lập nhu cầu`                                   | `[role="tablist"][aria-label="Giai đoạn lập nhu cầu"]`                                                             | Retained, valid    |
|   7 | Xác nhận nhu cầu tab       | `PlanningCapability.tsx` / Ark Tabs                      | `role="tab"`, exact text and `aria-selected`                                      | Scoped exact-text tab plus selected-state assertion                                                                | Corrected          |
|   8 | Tuần phục vụ field         | `AtlasWeekRangeInput.tsx`                                | Read-only input labeled `Tuần phục vụ`                                            | `input[aria-label="Tuần phục vụ"]`                                                                                 | Retained, valid    |
|   9 | DatePicker open trigger    | `AtlasWeekRangeInput.tsx`; Ark Trigger                   | `button[data-part="trigger"]`, label `Mở lịch — Tuần phục vụ`                     | Exact data-part and accessible name                                                                                | Corrected          |
|  10 | DatePicker content         | Ark Content / Zag content props                          | `div[role="application"][aria-label="Lịch — Tuần phục vụ"]`                       | Exact role and accessible label                                                                                    | Corrected          |
|  11 | Previous month             | Ark PrevTrigger / Zag anatomy                            | Enabled `button[data-part="prev-trigger"]`                                        | Scoped `[data-part="prev-trigger"]`                                                                                | Corrected          |
|  12 | Next month                 | Ark NextTrigger / Zag anatomy                            | Enabled `button[data-part="next-trigger"]`                                        | Scoped `[data-part="next-trigger"]`                                                                                | Corrected          |
|  13 | Day/date trigger           | Ark TableCellTrigger / Zag anatomy                       | `div[role="button"][data-part="table-cell-trigger"][data-view="day"][data-value]` | Anatomy attributes plus exact ISO `data-value`; no tag assumption                                                  | Corrected blocker  |
|  14 | Ngày phục vụ               | `ConfirmedNeedWorkbench.tsx`                             | Native select labeled `Ngày phục vụ` inside Confirmed workbench                   | Confirmed-section-scoped select; exact seven options                                                               | Corrected scope    |
|  15 | Tạo nhu cầu                | `ConfirmedNeedWorkbench.tsx`                             | Enabled Chakra button only when no workbench and generation is allowed            | Confirmed-section-scoped exact text; hard pre-generate gate; one click                                             | Hardened           |
|  16 | Nhu cầu xác nhận table     | `ConfirmedNeedTable.tsx`                                 | Native table labeled `Nhu cầu xác nhận`                                           | `table[aria-label="Nhu cầu xác nhận"]`                                                                             | Retained, valid    |
|  17 | Table row identity         | `ConfirmedNeedTable.tsx`                                 | First cell: ingredient, then `school · delivery location`, then state             | Audited first-cell text mapped to authoritative names; safe because staging has no relevant active-name duplicates | Retained, verified |
|  18 | kg unit cell               | `ConfirmedNeedTable.tsx`                                 | Second table cell contains controlled-unit code                                   | Second cell exact text `kg`, within authoritative row                                                              | Retained, verified |
|  19 | Confirmed quantity         | `ConfirmedNeedTable.tsx`                                 | Native input labeled `Số lượng xác nhận <ingredient>`                             | Row-scoped `input[aria-label^="Số lượng xác nhận"]`                                                                | Hardened scope     |
|  20 | Reason                     | `ConfirmedNeedTable.tsx`                                 | Native select labeled `Lý do <ingredient>`                                        | Row-scoped `select[aria-label^="Lý do"]`                                                                           | Hardened scope     |
|  21 | Note                       | `ConfirmedNeedTable.tsx`                                 | Conditional native input labeled `Ghi chú <ingredient>`                           | Row-scoped `input[aria-label^="Ghi chú"]` after it mounts                                                          | Retained, valid    |
|  22 | Lưu                        | `ConfirmedNeedWorkbench.tsx`                             | Enabled Chakra button only while the draft is dirty and valid                     | Confirmed-section-scoped exact text; hard pre-save gate; one click                                                 | Hardened           |
|  23 | Navigate to Sources        | `PlanningCapability.tsx`; `PlanningSourcesWorkbench.tsx` | Sources tab plus `section[aria-label="Nguồn lập nhu cầu"]`                        | Scoped tab; retry only until exact Sources section mounts                                                          | Corrected          |
|  24 | Navigate back to Confirmed | `PlanningCapability.tsx`; `ConfirmedNeedWorkbench.tsx`   | Confirmed tab plus `section[aria-label="Xác nhận nhu cầu"]`, selected tab         | Exact section and `aria-selected=true`; shared service select cannot satisfy it                                    | Corrected blocker  |
|  25 | Reopened table             | `ConfirmedNeedTable.tsx`                                 | Same labeled table with 248 rows                                                  | Exact table selector, row count, then identical authoritative readback                                             | Hardened           |
|  26 | Screenshot capture         | Chrome DevTools Protocol                                 | `Page.captureScreenshot` PNG                                                      | Runner-local file under `RUNNER_TEMP`; no artifact upload                                                          | Retained, safe     |

### Protected gates and first-Save authority

Calendar navigation is bounded by the month distance between the rendered
calendar midpoint and 14/09/2026 plus a two-step safety margin. Each month action
is a non-consequential previous/next anatomy click, followed by a wait for the
rendered ISO day-value signature to change. The already-correct week returns
without opening the calendar. Selection must settle to the exact week field,
enabled service selector and the exact seven 14–20/09 options.

Before Generate, the verifier logs and requires the exact week, selected
17/09 date, exact options, enabled service select, enabled `Tạo nhu cầu`, absent
`Cập nhật nhu cầu`, and zero rendered rows. A mismatch stops with
`BROWSER_GATE_pre_generate`; Generate remains exactly one click with no retry.
Before Save, it requires 248 rows, exactly one nonzero business-quantity delta,
exactly one operational-adjustment reason, exactly one nonblank note, zero
invalid controls, and an enabled Save button. Fresh undecided lines legitimately
render 247 zero deltas because their first decisions are pending; those zeroes
are not business adjustments. Save remains exactly one click with no retry.

The owner-resolved initial-decision contract is explicit. Before Save, all 248
stable lines must have null `current_decision_id`. After the normal single Save
version transition, all 248 must have a first decision with no predecessor. The
intended line alone differs from its generated proposal and carries the exact
next-cent quantity, `OPERATIONAL_QUANTITY_ADJUSTMENT` reason and approved note.
The other 247 quantities equal their generated proposals and their first reasons
are `PROPOSAL_ACCEPTED`. Stable IDs and all theoretical/generated proposal
quantities remain identical. Reopen repeats the same authority assertion and
requires byte-equivalent authoritative line readback, so navigation creates no
additional decision.

The formal authenticated database statement timeout remains eight seconds.
Protected acceptance is now separately and strictly `generation_ms < 7000`:
6,999.999 ms is eligible, 7,000.000 ms and above fail. Deterministic unit tests
cover that boundary; no local wall-clock test substitutes for hosted evidence.

Failure diagnostics are read-only and preserve the original error even if a
diagnostic read fails. They contain only browser stage, week/date/options,
Generate/Save presence and enabled state, rendered row count, batch existence,
batch version, authoritative line count, editing flag, blocker count and
pagination remainder. A regression proves that names, quantities and full row
payloads are discarded. Credentials, tokens and keys are never included.

The final post-browser read-only proof requires exactly one retained 17/09 Need
Generation run, one Confirmed Need batch, 248 current editable review lines, no
blockers or pagination remainder, zero Purchase Handoff rows, and equality of
the existing preflight Menu/Attendance/Pantry selected-source fingerprints from
before the rollback probes through final readback. Baseline and rollback checks
now require both rehearsal-week Need runs and Confirmed Need batches to remain
zero.

Rollback and boundaries: this change adds no migration and has no data rollback.
Reverting the verifier/doc commit restores the previous harness only. It changes
no React product behavior, Planning lifecycle, Supabase API, quantity policy,
timeout, workflow, Retool, live OPS v1, Google Sheet, Apps Script or PR #286.
