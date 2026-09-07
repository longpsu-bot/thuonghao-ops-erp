# School fulfilment cutover-readiness runbook

## 01A preparation

This repository prepares a read-only reconciliation surface and verifier; it does not mutate hosted Staging. Install `atlas-staging-identity@1.2.0` only through the protected package workflow. Identity contains exactly 21 capabilities: the prior 19 plus `dispatch.school_release.read` and `dispatch.school_release.release`. Foundation remains 1.1.0 and unchanged.

Before hosted action, require a clean exact commit, successful certifications, the approved Staging target guard, and a reviewed rollback plan. Never target Live OPS, Retool, Warehouse, supplier communication, or cancellation execution.

## 01B activation sequence

1. Confirm the exact merged `main` SHA, Draft PR product/architecture approval, and green GitHub validation.
2. Confirm migration authority for that exact commit on protected Staging.
3. Install/replay Identity 1.2.0; verify the exact 21 grants and conflict rejection.
4. Manually dispatch `Atlas Staging Foundation Install` with the exact merged-main SHA. Require its Foundation 1.1.0 dry-run, replay, and normal read-only `pnpm atlas:staging:verify` steps to pass in order.
5. Rehearse Scenario A on `2046-09-17`: Recipe-derived plus Pantry-direct membership through Need, allocation, released PO, released PXK, and reconciliation `OK`.
6. Rehearse Scenario B on `2046-09-18`: complete Pantry-direct authority without fabricated Menu, Attendance, or Recipe bindings.
7. Rehearse Scenario C on `2046-09-19`: retain old Need/PO/PXK evidence; release explicit PO and PXK successors; verify predecessors are superseded and successors current.
8. Run `pnpm atlas:staging:school-fulfilment:verify`. It performs authenticated Data API reads only, without retry or writes.
9. Record the exact commit, workflow results, operator, timestamps, and verifier output for the Product/Architecture cutover decision. Stop for review; do not activate production or cancel supplier commitments.

The Foundation workflow is manual-only and must be dispatched after merge from the exact merged-main SHA. Use `--dry-run` to validate guards and the read plan without constructing a client. On any missing scenario, mismatch, blocker, stale state, authorization failure, or unclear history, stop and preserve evidence. If a replay outcome is unknown, read current state before any retry; never add or perform an automatic retry.

Application rollback redeploys the last approved commit. Identity rollback reinstalls the prior manifest only after reviewing live client needs. Database rollback drops only reconciliation functions/grants and never deletes immutable PO/PXK predecessors or edits production data. For unknown outcomes, read current state before any manual retry.
