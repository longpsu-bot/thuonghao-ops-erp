# Final Planning Closeout Completion

**Goal:** Certify the entire retained-checkpoint → D046 correction → first Save → reopen path before opening one Draft PR.

**Authority:** Owner's 26/09/2026 final-closeout task, D-046/D-047, PA-03, H0C, RMVP-03B/04/05. The owner confirmed the E: checkout. Starting SHA: `13299ef99f7c863f16f57eaab390ae4ffa6907c9`.

**Execution:** One lead implementation agent; systematic debugging, profiling and RED before GREEN. Inline execution. No merge, deployment, retained Staging mutation, Handoff, Procurement release, Retool or OPS v1 changes.

## Audit and implementation sequence

- [x] Trace deploy/preflight, D046 eligibility, public correction orchestration, nested failure/receipt behavior, classifier, normal performance, candidate provenance, browser navigation/edit/Save/reopen and final proof.
- [x] Build a disposable correction fixture with 304 contributions / 248 groups and governed adoption evidence. Profile the public command before changing production SQL; distinguish inclusive stage timings from function self time.
- [x] Reproduce retryable nested failure as RED. Preserve exact request retry, rollback, deterministic failure receipts and no dangling receipt.
- [x] Create one CLI-generated migration. Optimize only measured correction costs; preserve every invariant, immutable history, fixed search paths, privileges and timeout.
- [x] Extend receipt classification with at most one exact `legacy_retryable_failure`; test all checkpoint-valid role subsets/permutations and malformed/duplicate rejection.
- [x] Add rollback certification using the actual public command, effective runtime timeout, three checkpoint-preserving probes and a 75% utilization ceiling. Bind successful correction to the submitted command. Require certification for both D046 workflow modes.
- [x] Reproduce browser failures using historical candidate source and current authoritative facts. Use stable line ID and an exact policy-valid quantity delta; test actual React state settlement, reason, note, Save and reopen.
- [x] Bind browser certification to approved immutable candidate SHA/deployment and required fixed source. Document candidate refresh from PR #286 without changing or merging that PR.
- [x] Exercise the complete corrected fixture, three rollback probes, normal generation, candidate checks, 248-row browser Save/reopen, 248 first decisions, one adjustment/247 acceptances, no second Save or downstream write.
- [x] Run focused JS/SQL/browser tests, security catalog, typecheck, changed-file formatting, whitespace and one final full Supabase integration certification. Complete whole-change review and only then create the Draft PR.

## Bounded files and acceptance

SQL lives in one new migration plus local fixtures/pgTAP. Verifier changes are bounded to `correct-staging-planning-d046.mjs`, `verify-staging-planning-closeout.mjs`, correction performance certification, `staging-planning-browser.mjs`, associated tests and guarded workflows. Product changes are limited to stable Confirmed Need row identity or a reproduced closeout defect. Documentation records measured evidence and the owner's unexecuted post-merge sequence.

The existing classifier and public backend commands remain authoritative. Unknown receipts reject. No helper-only performance proof, arbitrary sleeps, weakened gates, timeout increases, automatic retries, generic Unit exception, persisted lifecycle machinery or historical rewrites are allowed.

## Evidence ledger

- Workspace: clean verified E: checkout, correct remote, latest main unchanged; requested branch created from main after owner confirmation.
- PR #286: read-only GitHub query confirms OPEN / Draft at `dcf6be78cd71b4eca4565a5d014f7f4b86888103`.
- Historical workflow logs independently confirm `BROWSER_GATE_pre_save` (35809727799) and `BROWSER_GATE_editable_kg_row` (35942764307), both after 248 rows loaded.
- Initial audit: no rollback correction certification exists; classifier currently supports only original/benign/correction; PC104 handler persists nested retryable failure via `finish_receipt(..., false)`; correction always invalidates/re-evaluates readiness; UPDATE/historical source guards retain broad checks.
- Initial browser audit: candidate #286 uses the old two-decimal historical-input rule; current main uses effective Planning-step validation. Browser selects literal `kg`, matches display names/position and adds a fixed cent. Root causes and exact reproduced tests remain to be completed.
- Backend RED: original full correction timed out at 8000.547 ms; nested retryable fault persisted a failed receipt. GREEN: pure-retirement membership scope plus bounded D047 join planning complete the public command; retryable nested result and four transient SQLSTATEs roll back the receipt; frozen retry/replay remains exact; deterministic failure still persists.
- Ruling: retain READY invalidation/evaluation. Its measured post-fix cost is about 45 ms; changing lifecycle semantics is unnecessary for the measured bottleneck.
- Browser RED: missing stable row attribute and fixed-cent selection tests failed. GREEN: stable ID, effective Planning step, actual controlled input events and strict pre-Save settlement. A 248-row controller test includes 39 precision proposals and proves one Save plus reopen.
- Additional direct blocker: actual Unit correction produces 248 current rows and 249 immutable stable identities. The old verifier counted all identities as current. Count current revisions and separately prove retained identity count; never delete or rewrite the retired line.
- Rollback SQL execution found two harness defects before certification: a nested read-only transaction wrapper in the snapshot SQL, and a post-command timeout read observing an existing component's 120-second setting. Strip only the snapshot wrapper; capture authenticated policy before execution and restore it before deferred checks. Actual measured policy is 8000 ms.
- Three final local correction samples before full integration: 4131.016, 4176.453, 4552.451 ms; 43.094% minimum headroom. Operator target 4000 ms not met. All checkpoint and correction facts preserved/proven.
- Headless Chrome + real local PostgreSQL Save/reopen passed: 248 current rows, one Save receipt, 248 first decisions, one adjustment, 247 acceptances, zero Handoffs. Current React/Chakra workbench, loopback authenticated-role transport; hosted sign-in and future candidate deployment explicitly unexecuted.
- Focused validation: 280 tests passed across seven suites; typecheck and whitespace passed. Full integration first found the expected private-function catalog hash change from join_collapse_limit. Updated only that hash and added an exact fixed-search-path/planner-setting assertion; full integration rerun underway.
- Independent read-only whole-change review: no actionable findings. Reviewer used no database or hosted commands.
- Fresh hosted READ ONLY checkpoint fed to the actual new classifier: D046_CORRECTION_ELIGIBLE with original, benign NO_CHANGE and historical retryable artifact; run v3/304, batch v1/248, zero decisions/Saves/Handoffs and exact unchanged source fingerprints.

- Final integration: all 98 commands passed, including the new production-build Chrome/backend rehearsal. Final first-attempt correction samples: 3891.100, 4084.594, 3977.302 ms (48.943% minimum headroom); normal samples: 2097.097, 2143.181, 2133.814, 2224.559, 2389.322 ms. All 17 new pgTAP checks passed.
- Preserve the earlier missing-statistics failure (7496.168, 7531.426, 4556.715 ms). Newly bulk-loaded fixture relations now receive ordinary ANALYZE once before the first measured probe; no warm-up correction or discarded sample. Hosted read-only statistics already exist; hosted certification remains unchanged and performs no tuning.
- Final follow-up review covered fixture setup, production-build transport, logging, current/stable counts and receipt binding: no actionable findings.
