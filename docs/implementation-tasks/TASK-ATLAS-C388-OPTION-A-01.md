# Issue 395 — bounded Option A execution ledger

Authority: [Issue 395](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/395), Owner approval of 17 October 2026 and [review 394](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/394#issuecomment-6230584611). This dedicated authorization is independent of the design-only Autopilot task. No merge or deployment is authorized.

## Verified pickup and integration

- Authorized managed checkout: `C:/Users/hp/.codex/worktrees/52fb/thuonghao-ops-erp`; clean detached HEAD at main `3667966a3f6703a6585f07ba619969ec851ca7b8`; origin verified; fetch and `pnpm ops:workspace` passed. Its legacy D: path warning does not override the explicit task checkout authorization.
- Task branch: `codex/issue-395-option-a`, created from that main. Pinned #388 `a443daf15dd9891611b387349268795efbce7d5c` merged only into this branch. The only conflicts were the two Autopilot documents, resolved to main's existing contents. Neither existing PR branch is updated. #388 remains Draft/release-blocked; #392 remains frozen at `6f9f288c76cfa48691fca2f4968ce03185502bb2`.
- The dirty source checkout and its six document/export modifications are outside this task and are untouched.
- C `20261015065552` is absent from the local migration registry and the read-only Staging registry (latest Staging entry `20261014120320`). No hosted SQL or data write. Original C SHA-256: `7d5a0a96f141c23adad51781827051df04a1a545fc513617abf9eccd7f6302c3`.

## Exact body allowlist, before SQL edits

Only `atlas_core.purchase_review_continuity_context(uuid)` may change. Its signature, owner, ACL, STABLE volatility, SECURITY DEFINER and empty search path must remain identical. No other stored body, trigger, grant, lock, receipt, authorization, timeout or contract may change. Amend only C's final, unapplied definition; preserve the original Git bytes and candidate diff.

Selected single strategy: assemble all discovered Handoff bindings in one materialized relational set, resolve each distinct `(confirmed_need_batch_id, validation_attempt_id)` once per invocation, join exact projected members, and aggregate results per Handoff revision/family. Copy the incumbent membership predicates exactly; preserve raw multiplicity and missing/NULL failure. Reuse the existing historical-evidence function unchanged. Preserve every historical revision and adjacent edge, including invalid/reverted histories. Current sources continue through the existing complete correction context.

The sharing seam is one read-only STABLE SQL statement. It has one MVCC snapshot and no lock acquisition or write. It is rebuilt on every invocation. Nothing survives a command phase, lock wait, source/allocation/Handoff write, or constraint-trigger invocation. Existing callers and their pre/post-lock reads are untouched. This strategy deliberately leaves the known per-row retained-release amplification intact; meeting Tier 2 remains an empirical gate, not a promise.

## Execution and stop protocol

1. Bootstrap the exact 109 main migrations and pinned C in a network-isolated task-owned disposable PostgreSQL container. Do not reset, stop, clone with connection inhibition, or mutate either existing local stack.
2. Preserve source hashes and exact metadata/row snapshots. Capture a same-host complete-command baseline once. Run targeted context parity against the incumbent per-revision helper, including missing/corrupt/multiplicity cases already in the focused suites.
3. Apply the single body change. Retain all seven suites / 588 assertions; document additions separately. Verify exact 497-function metadata and protected row/role/schema parity, with only the named body delta.
4. Run first and second consecutive complete 250-family operational journeys at quantities 101 then 102, all ten public operations each, unchanged budgets and timed flushes. Keep per-depth assertion results and immutable/unaffected identities explicit.
5. Require real two-session waits/retry/rejection and retained-request UNKNOWN recovery. Only if focused and both operational journeys pass, run the original eight-cycle/20-assertion oracle once. Never retry a failed operational strategy or run a stress loop.
6. Publish measured PASS/FAIL/BLOCKED and the remaining Owner decision. Disclose Full Integration and combined #392 limits. No merge, hosted writes, Warehouse or #385–#387 work.

Progress: pickup and dependency merge complete; SQL implementation and fresh certification pending.
