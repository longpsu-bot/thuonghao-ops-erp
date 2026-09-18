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
