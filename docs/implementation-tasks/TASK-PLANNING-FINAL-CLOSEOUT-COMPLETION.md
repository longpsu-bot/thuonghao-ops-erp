# Planning final closeout completion

Authority: the owner's 26 September 2026 final-closeout instruction; D-046/D-047, PA-03, H0C and RMVP-03B/04/05 remain authoritative. Starting main: `13299ef99f7c863f16f57eaab390ae4ffa6907c9`. Branch: `fix/planning-final-closeout-completion`.

## Root causes and bounded changes

1. Correction supersedes 248 immutable Confirmed Need revisions. The historical fallback in the membership trigger discarded the affected revision ID, repeatedly rechecking the entire batch. Pure retirement now checks the unchanged revision locally **and still proves the complete current release partition**. Any change beyond `is_current` and `revision_status` retains the broad historical validation. No integrity trigger is disabled.
2. The exact D047 Unit-transition proof has 16 joined relations. EXPLAIN measured 1,047.557 ms planning versus 0.596 ms execution. Function-local `join_collapse_limit=1` retains every joined provenance condition and bounds join-order search. No Unit conversion or generic exemption is introduced.
3. A nested retryable result entered the `PC104` deterministic-failure handler and persisted `FAILED_NON_RETRYABLE`. It now raises into the enclosing concurrency handler, rolling back the receipt and all nested writes before returning `retryable=true`. Deterministic failures still finalize immutable failed receipts. There is no automatic retry.
4. The existing historical bad receipt remains immutable. The verifier accepts at most one exact `legacy_retryable_failure` semantic role: synthetic actor, command `execute_need_generation`, expected version 3, correction key prefix, failed outcome, false success, true retryable, `RETRYABLE_CONCURRENCY_FAILURE`, null idempotency status and absent/null affected aggregates and versions. It never counts as correction success. All eight valid role subsets and all their orders are tested; unknowns and duplicates reject.
5. Run [35809727799](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/35809727799) reached 248 rows but the old PR #286 controller used a two-decimal restriction. Thirty-nine retained kg proposals have additional precision. Every undecided row participates in the first Save, so those untouched rows kept Save disabled. Current main already has the effective-Planning-step validation fix; the candidate must include it. Native value setter plus React `input`/select `change` events work with the current Chakra controls, as both the controller test and Chrome/backend rehearsal demonstrate.
6. Run [35942764307](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/35942764307) used a verifier expecting `data-field`/`data-role` attributes absent from the old immutable deployment. Literal `kg`, display names and row position were unnecessary heuristics. The verifier now binds a real editable DOM row to the authoritative `confirmed_need_line_id`, adds exactly one effective Planning step using decimal integers, and waits for the rendered nonzero delta, reason, note and unchanged strict pre-Save gate.
7. The complete disposable correction exposed an additional count defect: Unit is part of immutable stable line identity. The one governed transition retires an old identity and creates a new one. There are **248 current rows and 249 retained stable identities**, with 248 historical predecessor null proposal pairs. Snapshot `line_count` now counts current revisions; `stable_line_count` separately requires 248 before correction and 249 afterward. Deleting or mutating the historical identity would violate H0C. The browser still must display exactly 248 current rows.

## Measured backend profile

Local PostgreSQL, real 304-contribution / 248-current-group fixture, authenticated public `atlas_api.execute_need_generation(jsonb)`. Timings are milliseconds. Instrumentation and command effects are rollback-only. Parent stage times include their nested calls; the diagnostic helper rows below must not be added again.

| Sequential stage                                         |                                    Before |             After |
| -------------------------------------------------------- | ----------------------------------------: | ----------------: |
| Preflight and D047 regeneration predicate                |                                   296.986 |           229.397 |
| Need predecessor invalidation                            |                                   227.038 |           179.167 |
| Planning Input invalidation, reread and READY evaluation |                                    54.021 |            45.012 |
| Successor creation and theoretical generation            |                                  1695.279 |          1195.988 |
| Successor validation                                     |                                    20.654 |            14.643 |
| Successor release                                        |                                   233.350 |           221.850 |
| Confirmed Need rematerialization                         |                                  1289.973 |           161.891 |
| Deferred guards                                          | Timed out after roughly 4183 remaining ms |          2269.490 |
| Final authoritative readback                             |                               Not reached |            10.194 |
| Public command total                                     |               8000.547, retryable failure | 4330.599, success |

| Nested diagnostic                             |                            Before |                        After |
| --------------------------------------------- | --------------------------------: | ---------------------------: |
| D047 regeneration predicate                   |                           271.466 |                      208.379 |
| D047 transition proof, measured optimized run |                          1144.485 |                        6.683 |
| Membership guard self time                    | 4038.569, aborted after 180 calls | 2033.384, complete 800 calls |

The READY-evaluation path accounts for about 45 ms after optimization. It was deliberately preserved: measured costs did not justify changing its invalidation/evaluation semantics. The D047 predicate was not the primary bottleneck.

## Rollback certification contract and evidence

**Policy amendment (26 September 2026):** The historical 8s/75% correction certification described below is superseded by the owner-approved [protected maintenance policy](TASK-PLANNING-MAINTENANCE-TIMEOUT-UX.md). D046 rollback and persistence now use a transaction-local 60s envelope with separate RPC/constraint-flush measurements and no percentage gate. The following measurements remain historical evidence.

Both D046 workflow modes first require protected preflight, `D046_CORRECTION_ELIGIBLE`, and `D046_CORRECTION_ROLLBACK_PASS`. Three fresh command identities execute the complete public correction in transactions that always roll back. Every corrected in-transaction checkpoint is classified, including D046/D047 evidence, receipt attribution, source fingerprints, zero Saves and zero Handoffs. An independent snapshot after **every** attempt must equal the original snapshot, including on transport/command failure.

The authenticated timeout is resolved from PostgreSQL database/role configuration and captured **before** the command. Existing nested `SET LOCAL` calls can leave a later `pg_settings` read showing 120 seconds; this does not replace the running statement's original timer. Certification must never mistake that post-command value for the initial authenticated policy. It restores the captured policy before explicitly flushing deferred guards. No timeout is increased by this change. Missing, disabled, inconsistent or function-local ambiguous timeout policy rejects.

Three uninstrumented local correction samples from a freshly reset, seeded and analyzed fixture: **3891.100, 4084.594, 3977.302 ms**. Effective timeout: **8000 ms**. Maximum utilization: **51.057%**, below the **75%** ceiling. Derived ceiling: **6000 ms**. P50: **3977.302 ms**. Minimum headroom at the slowest sample: **3915.406 ms / 48.943%**. The 4000 ms operator target is **not met**. Separate local transport/proof/rollback durations were 4542.885, 4730.225 and 4621.888 ms. Hosted timings must be recertified after deployment; these are local measurements, not a promise about hosted latency.

An earlier clean integration attempt correctly rejected **7496.168, 7531.426, 4556.715 ms**. Newly bulk-loaded tables had no planner statistics until auto-analyze ran. A separate immediate profile reproduced 7121.358 ms; nested statement statistics attributed 2210.52 ms to membership completeness, 867.45 ms to live ownership and 782.19 ms to predecessor coverage. Planning those statements took only 2.38, 0.36 and 1.14 ms respectively. The disposable fixture now analyzes its populated Atlas relations once after migration and before its **first** correction probe. It executes no warm-up correction, discards no sample and changes no statistics targets or performance gates. This follows PostgreSQL's [bulk-loading guidance](https://www.postgresql.org/docs/17/populate.html). Read-only Staging inspection confirmed ordinary statistics already exist: the five relevant membership/generation tables last auto-analyzed on 21 September, with estimated counts matching live counts (262/309/316/316/322). The hosted verifier performs no ANALYZE or tuning; its actual measured samples remain authoritative.

The existing hosted normal-generation evidence on the starting main was 3979.896, 2928.917, 2780.688, 3522.204 and 2720.361 ms (P50 2928.917, P95 3979.896; operator target met). The normal verifier's 231/225/213/210 geometry and 24/8/3 adoption workload remain unchanged. New local regression samples with 304 contributions / 248 groups were **2097.097, 2143.181, 2133.814, 2224.559, 2389.322 ms**; P50 **2143.181**, P95 **2389.322**; existing correctness/performance gate and 4000 ms operator target both pass.

## Browser evidence and candidate authority

PR [#286](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/286) remains the approved production-entrypoint candidate, OPEN/Draft/unmerged at the inspected head `dcf6be78cd71b4eca4565a5d014f7f4b86888103`. Main still mounts the legacy Mantine entrypoint. The old immutable `0d969e3b` deployment cannot certify these fixes and is no longer hardcoded by the verifier.

After this PR merges, the owner must refresh/rebase PR #286 onto that exact main commit while preserving its `AtlasVNextConnectedApp` production entrypoint, resolve any conflicts, and build a new immutable Cloudflare deployment. Do not merge #286 as part of this task. The build emits `_atlas-build.json` with source SHA, tracked-worktree cleanliness, entrypoint and Supabase origin. Set protected `atlas-staging` variables `ATLAS_PLANNING_PREVIEW_URL` (immutable eight-hex deployment host, trailing slash) and `ATLAS_PLANNING_PREVIEW_SHA` (full candidate SHA). Browser preflight requires all of: exact protected URL/SHA, manifest agreement, clean build, connected Chakra entrypoint, Staging Supabase origin, current PR #286 head agreement and GitHub ancestry containing the exact certified main SHA. Redirects, old manifests, wrong hosts, wrong SHA, wrong backend and missing configuration reject before sign-in. No arbitrary branch preview is accepted.

Executed before PR: real current React/Chakra controller with 248 undecided rows, including 39 precision proposals, plus headless Chrome against the disposable PostgreSQL backend. Chrome loaded 248 real corrected rows, located the stable identity, changed one quantity by one effective step, settled reason/note, passed the strict pre-Save gate, clicked Save once, obtained 248 actual first decisions (1 adjustment / 247 acceptances), navigated away/reloaded and read the same authoritative lines. Database proof: one Save receipt, zero Handoffs. The test transport permits only preflight, review and one Save against the fixed local fixture; generation and downstream actions are unavailable to the page.

The local browser uses a production build of the current workbench with a loopback authenticated-role SQL transport. It does **not** claim hosted sign-in, gateway/network behavior, the future Cloudflare deployment or PR #286's full entrypoint were executed. Actual Chakra week/date and tab navigation, corrected-resume, one-shot actions and provenance rejection are separately covered by deterministic DOM/controller tests. The immutable candidate cannot be rebuilt/deployed during this task because deployment is explicitly prohibited; the enforced refresh/provenance sequence is the deterministic substitute for that external stage.

## Migration and security

One CLI-generated migration: `20260926071101_planning_final_closeout_completion.sql`.

- `atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()` — narrow pure-retirement proof while retaining global current partition validation.
- `atlas_core.planning_legacy_adoption_unit_transition_allowed(uuid,uuid)` — join planning bound only; all provenance facts retained.
- `atlas_core.issue_223_execute_need_generation_v2(jsonb)` — whole-transaction transient rollback and safe retryable envelope.

Function owners, ACLs, SECURITY DEFINER and fixed search paths are preserved and checked during migration. Temporary migration ownership grants are revoked. No public helper exposure, RLS weakening, frontend service credential, historical receipt rewrite, data migration or new lifecycle machinery. Forward rollback, if ever required, is a reviewed migration restoring the prior function definitions/configuration; it must not rewrite receipts or business history and would reintroduce the known timeout/retry defects.

Product frontend change: only the nonvisual `data-confirmed-need-line-id` attribute on `ConfirmedNeedTable.tsx`. The quantity-policy fix already exists on main and must be included in the refreshed candidate. Vite's build-provenance asset is technical certification metadata, not an operator flow.

## Pre-PR remaining-path audit

These answers concern expected behavior supported by executable repository evidence. The future hosted mutation and deployment remain explicitly unexecuted.

| Required question                                                | Answer and evidence                                                                                                                                                                                                          |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Will eligibility accept the actual receipt history?              | Yes. The new classifier consumed a fresh read-only Staging snapshot and returned `D046_CORRECTION_ELIGIBLE` with all three historical receipts.                                                                              |
| Will full rollback correction pass repeatedly with headroom?     | Yes locally: three first-attempt public corrections pass the unchanged 75% policy, including deferred checks and exact checkpoint restoration. Hosted recertification is mandatory.                                          |
| Will normal Planning Performance remain healthy?                 | Yes in the unchanged verifier contracts and five actual local public-command probes; hosted post-deploy performance must pass before owner authorization.                                                                    |
| Will one real correction create `D046_CORRECTED_RESUME`?         | Yes. The disposable public correction produces the required lineage, counts and receipt; separate production-classifier tests accept corrected checkpoints with the complete historical roles and reject malformed evidence. |
| Will corrected classification preserve every historical receipt? | Yes. Original, benign NO_CHANGE, legacy retryable failure and successful correction roles remain; subset/order permutations pass and unknown/duplicate roles reject.                                                         |
| Will Browser Closeout target the exact approved candidate?       | Yes by enforced PR #286 head, certified-main ancestry and protected immutable URL/SHA/manifest checks. A stale or unrelated candidate fails before sign-in. Owner must rebuild #286 after merge.                             |
| Will it find a stable editable row?                              | Yes in controller and production-build Chrome tests; selection binds DOM identity to an authoritative current line ID.                                                                                                       |
| Will the edit enter real React state?                            | Yes. Native value setter/input/change/blur events settle the visible delta, reason and note in the actual Chakra controller.                                                                                                 |
| Will Save become enabled?                                        | Yes. Strict pre-Save evidence: 248 rows, one quantity adjustment/reason/note, zero invalid controls, Save present and enabled.                                                                                               |
| Will exactly one Save create 248 first decisions?                | Yes in real local PostgreSQL: one click and one receipt, 1 operational adjustment and 247 proposal acceptances.                                                                                                              |
| Will reopen return byte-equivalent authoritative lines?          | Yes. Navigation/reload obtains deeply identical saved authoritative line objects, with no further Save action available.                                                                                                     |
| Will no Handoff / Procurement release occur?                     | Yes. The allowed browser transport exposes no downstream command; database Handoffs remain zero and the verifier rejects any Handoff.                                                                                        |

The production-build local rehearsal and all 17 new retry/correction pgTAP assertions passed. Focused JavaScript/controller validation passed 280 tests across seven suites; typecheck passed. Independent read-only whole-change and follow-up reviews found no actionable blockers. The final full Supabase certification passed all 98 commands, including the production-build browser rehearsal. Changed-file formatting and whitespace checks passed. GitHub check results are recorded in the PR and completion report.

## Owner sequence — documented, not executed

1. Review and merge this final PR; obtain exact new main SHA; deploy its migration.
2. Refresh/rebase/rebuild the approved PR #286 candidate as above and pin its exact immutable URL/SHA in the protected environment.
3. Read-only verify retained run RELEASED_FOR_CONFIRMATION v3 / 304, same batch DRAFT_REVIEW v1 / 248, zero decisions/Saves/Handoffs, CURRENT fingerprints and all immutable historical receipts.
4. Run **Atlas Staging Planning D046 Correction**, `persist_correction=false`. Require `D046_CORRECTION_ELIGIBLE` and `D046_CORRECTION_ROLLBACK_PASS`.
5. Run **Atlas Staging Planning Performance**. Require `GENERATION_PERFORMANCE_PASS`. **STOP for the owner's explicit authorization of one fresh one-shot correction.**
6. Run D046 Correction with `persist_correction=true`. It repeats every non-mutating guard before one fresh command, without automatic retry. Never reuse historical command `429e1178-9b47-4f68-87b8-f9209e86bf18`.
7. Require `D046_CORRECTED_RESUME`. Immediately verify predecessor INVALIDATED v4, one direct successor RELEASED_FOR_CONFIRMATION v3, 304/304 release contributions, same batch v2, 248 current rows / 249 retained identities, zero decisions/Saves/Handoffs, unchanged fingerprints, 248 exact proposals, zero invalid proposals, 248 old null pairs, one allowed Unit transition, zero invalid transitions and intact manifest.
8. Run **Atlas Staging Planning Closeout**, `persist_rehearsal=true`, against the proven candidate. Require `browser-review-save-reopen-pass` plus its final backend proof (the established successful result token).
9. Read-only final proof: same corrected Need lineage; batch advanced exactly once; 248 first decisions; one operational adjustment; 247 proposal acceptances; zero Handoffs/Procurement release; reopened authoritative lines identical to saved lines.

Hosted actions during implementation: Staging deployment **NO**; real D046 correction **NO**; retained Confirmed Need Save **NO**; Handoff **NO**; hosted Browser Closeout **NO**; Retool mutation **NO**; OPS v1 mutation **NO**.
