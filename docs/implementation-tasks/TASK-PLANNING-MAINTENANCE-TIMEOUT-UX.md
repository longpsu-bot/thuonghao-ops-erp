# Planning protected maintenance and operation feedback

Authority: owner-approved task, 26 September 2026. Starting main: `1afda8735b5cd5bdf948a7d53225449a565f6b95`. This amends only the D046 execution/certification policy from [the final closeout implementation](TASK-PLANNING-FINAL-CLOSEOUT-COMPLETION.md); D046/D047 business proof and the #326 corrections remain unchanged.

## Protected execution policy

Normal authenticated application traffic retains `statement_timeout = 8s`. The manual **Atlas Staging Planning D046 Correction** workflow uses `SET LOCAL statement_timeout = '60s'` within each rollback probe and the separately owner-authorized one-shot persistence transaction. There is no migration, global role/configuration write, API/privilege/RLS change, or frontend management credential.

`staging-planning-correction-performance.mjs` shares the command envelope between rollback and persistence. It reads the effective database/role timeout policy and rejects anything other than the expected 8000 ms normal policy. It establishes the protected 60000 ms policy, enables row security, sets the existing synthetic JWT subject (`a1010000-0000-4000-8000-000000000101`) and switches to `authenticated` before calling the unchanged `atlas_api.execute_need_generation(jsonb)`. Persistence retains the existing synthetic-user sign-in identity check. Management transport supplies transaction policy; the public function still resolves the Actor, capabilities and authorization.

Nested command-local settings can affect subsequent statements, so the runner restores the maintenance policy before deferred constraints and proof reads. The persistence path replaces the former Supabase JS business RPC with one management transaction. Only a successful, non-retryable, error-free `COMPLETED` response can reach COMMIT; deferred constraints must also pass. No direct business table mutation occurs. A transport/unknown outcome leads to one authoritative checkpoint read; only a corrected checkpoint attributed to the submitted command can resolve it. Otherwise the runner fails, without a second invocation. Historical original, NO_CHANGE and retryable-failure receipts remain untouched.

Both workflow modes require deploy preflight, `D046_CORRECTION_ELIGIBLE`, then three rollback probes and `D046_CORRECTION_ROLLBACK_PASS`. Each probe verifies public response success, completed receipt attribution, corrected business proof, unchanged source fingerprints and independent checkpoint equality after rollback. Persistence then performs exactly one fresh correction and requires `D046_CORRECTED_RESUME` from authoritative readback.

## Measurement semantics

The former 75% timeout-utilization gate is retired. Each SQL statement has its own timeout, as specified by [PostgreSQL statement_timeout](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-STATEMENT-TIMEOUT). The command is timed from just before the public function call through its returned response. The separate constraint-flush DO statement measures only its explicit `SET CONSTRAINTS ALL IMMEDIATE` work. PostgreSQL enforces the limit on the complete SQL statement, including work outside those diagnostic timing brackets.

Certification reports RPC and constraint-flush sample arrays, min/p50/max for each, end-to-end samples, protected policy 60000 ms and normal policy 8000 ms. End-to-end includes management transport, proof, rollback and independent readback; it is not compared with one statement timeout. No additional percentage threshold or 4-second D046 gate exists. The separate normal Planning Performance workflow and its normal authenticated workload remain unchanged. The disposable normal-generation regression explicitly retains 8s.

## Long-running synchronous operation UX

`AtlasOperationStatus` is reusable Chakra presentation driven by the caller's ephemeral `AtlasOperation` union: IDLE, RUNNING, SUCCEEDED, FAILED or UNKNOWN_OUTCOME. It adds no database table, lifecycle, queue, API or persisted timer. Its local timer is isolated from the business controller and cleaned up when running ends or the component unmounts.

The first integration is Create/Update Need in the active Chakra Confirmed Need workbench. The existing controller continues to own command identity, a synchronous in-flight guard, safe navigation and recovery locks. The initiating button stays present, disabled and loading immediately. At 2 seconds the status area shows the real action and elapsed seconds. At 15 seconds it adds “Tác vụ này có thể mất một chút thời gian. Vui lòng không gửi lại yêu cầu.” There is no fake percentage or timer-driven business stage.

Success appears only after the command's authoritative preflight/Need readback is validated and the corresponding Confirmed Need batch has been read successfully. The result includes its authoritative line count. Known retryable and deterministic failures are classified separately; neither causes an automatic retry. Unknown results retain the existing write lock and explicit “Tải lại để xác nhận” recovery action. Recovery validates authoritative state before another submission is enabled. The existing module exit guard remains, and the unload guard covers a running generation; the application shell is not globally locked.

The live region uses `role="status"`, `aria-live="polite"` and atomic announcements. The visual elapsed timer is outside that live region, so each elapsed second is not announced. Save/reopen, stable row identities, React edit settlement and candidate provenance are unchanged.

Later rollout candidates: bulk imports, Attendance import/upsert, Weekly Menu processing, Purchase generation, exports, reconciliation and operator maintenance commands. Each integration must reuse its own authoritative command/readback contract; presentation alone must never unlock an unknown command or infer success from HTTP 200.

## Validation and delivery

RED/GREEN covered policy acceptance, separate timing, shared SQL envelope, operation timing, state transitions and controller guards. Focused suites include D046 correction, rollback certification, closeout classification, browser helpers, Planning controller/workbench, operation feedback, RPC security and normal performance. The disposable full integration additionally executes three real rollback corrections, verifies global role settings unchanged, rejects a mismatched authenticated subject, commits one real local protected correction, preserves historical receipts and runs the existing local browser proof. This is local synthetic data only; hosted certification samples are intentionally not claimed.

Focused validation passed 394 tests across 15 suites; the subsequent continuity and deterministic-failure additions passed their targeted tests. Typecheck and whitespace checks passed. One independent read-only final review found no actionable issues.

Three local protected rollback probes passed with RPC samples **4689.008, 4628.469, 4759.481 ms** (min **4628.469**, p50 **4689.008**, max **4759.481**). Separate constraint-flush samples were **0.125, 0.203, 0.297 ms**. All business and checkpoint proofs passed; effective protected timeout was **60000 ms**, normal authenticated policy **8000 ms**. These are disposable local measurements, not hosted certification.

The full local integration was attempted once and stopped in the unchanged legacy-adoption upgrade test: the Supabase CLI `db query --local` could not connect to `127.0.0.1` PostgreSQL (`LegacyDbConnectError`, connection timeout). The direct Docker/psql local closeout harness passed the changed path: three protected rollback probes, five normal 8s probes (p50 2972.170 ms, max 3674.887 ms), 17 existing correction/security pgTAP assertions, mismatched-subject rejection, one protected committed correction with unchanged global policy/historical receipts, and the existing production-build browser Save/reopen proof (248 decisions, one adjustment, 247 acceptances, one Save, zero Handoffs). The final affected controller/workbench rerun passed all 77 tests. GitHub Actions remains the final full integration and frontend CI authority. Migration and rollback effects: no database migration; reverting the PR restores runner/UI behavior without changing database facts.

## Post-merge owner sequence — document only

1. Obtain the exact new main SHA. Deploy only if a migration exists; this change creates none.
2. Refresh/rebuild PR #286 and pin the exact approved immutable preview URL/SHA/provenance. Do not merge #286 or silently switch candidates.
3. Verify the retained staging checkpoint is unchanged: original run RELEASED_FOR_CONFIRMATION v3 / 304 contributions; same batch DRAFT_REVIEW v1 / 248 current lines; zero decisions, Save receipts and Handoffs; unchanged fingerprints and historical receipts.
4. Run **Atlas Staging Planning D046 Correction**, `persist_correction=false`. Require `D046_CORRECTION_ELIGIBLE` and `D046_CORRECTION_ROLLBACK_PASS` under the protected 60-second policy.
5. Run **Atlas Staging Planning Performance**. Require `GENERATION_PERFORMANCE_PASS` under normal application policy.
6. **Stop for explicit owner authorization of exactly one fresh D046 correction.**
7. Run **Atlas Staging Planning D046 Correction**, `persist_correction=true`. Require `D046_CORRECTED_RESUME` and perform immediate read-only proof: predecessor INVALIDATED v4 / 304 retained contributions; one direct successor RELEASED_FOR_CONFIRMATION v3 / 304 contributions / zero blockers and warnings; same batch DRAFT_REVIEW v2 / 248 current lines / 249 retained identities / zero decisions, adjustments and acceptances; 248 exact proposals / zero invalid / 248 predecessor null pairs; one allowed Unit transition / zero invalid; zero Saves and Handoffs; unchanged source fingerprints.
8. Run **Atlas Staging Planning Closeout**, `persist_rehearsal=true`, using the proven candidate. Require final Planning Closeout PASS.
9. Verify exactly one retained Browser Save, 248 first decisions, one adjustment, 247 proposal acceptances, identical authoritative reopen, zero Purchase Handoffs and zero Procurement release.

Hosted actions during this implementation: deployment **NO**, D046 mutation **NO**, Confirmed Need Save **NO**, Handoff **NO**, Browser Closeout **NO**, Retool write **NO**, OPS v1 write **NO**. No merge or deployment is authorized by delivery of this Draft PR.
