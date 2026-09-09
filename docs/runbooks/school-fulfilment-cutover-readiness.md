# School fulfilment cutover-readiness runbook

## 01A preparation

This repository prepares a read-only reconciliation surface and verifier; it does not mutate hosted Staging. Install `atlas-staging-identity@1.2.0` only through the protected package workflow. Identity contains exactly 21 capabilities: the prior 19 plus `dispatch.school_release.read` and `dispatch.school_release.release`. Foundation remains 1.1.0 and unchanged.

Before hosted action, require a clean exact commit, successful certifications, the approved Staging target guard, and a reviewed rollback plan. Never target Live OPS, Retool, Warehouse, supplier communication, or cancellation execution.

## 01B activation sequence

1. Confirm the exact deployed business SHA, the current merged-`main` verifier implementation SHA, Draft PR product/architecture approval, and green GitHub validation. These two SHA authorities may differ.
2. Confirm migration authority for the exact deployed business SHA on protected Staging.
3. Install/replay Identity 1.2.0; verify the exact 21 grants and conflict rejection.
4. Manually dispatch `Atlas Staging Foundation Install` with the exact merged-main SHA. Require its Foundation 1.1.0 dry-run, replay, and normal read-only `pnpm atlas:staging:verify` steps to pass in order.
5. Rehearse Scenario A on `2046-09-17`: Recipe-derived plus Pantry-direct membership through Need, allocation, released PO, released PXK, and reconciliation `OK`.
6. Rehearse Scenario B on `2046-09-18`: complete Pantry-direct authority without fabricated Menu, Attendance, or Recipe bindings.
7. Rehearse Scenario C on `2046-09-19`: retain old Need/PO/PXK evidence; release explicit PO and PXK successors; verify predecessors are superseded and successors current.
8. From `main`, manually dispatch `Atlas Staging School Fulfilment Verify` with deployed business SHA `147648712ce57355d66773edd45a5e3ecd6458c9`. The workflow runs the verifier implementation at its current workflow-execution SHA rather than checking out the deployed business SHA. This formal certification is read-only: it must not replay Identity or Foundation, deploy migrations, retry, or write business data. Require `School fulfilment verifier passed (3 scenarios).`
9. Record both the deployed business SHA and verifier implementation SHA, plus the workflow run URL/ID, verifier output, and timestamp, then proceed only to the Product/Architecture cutover decision. No production activation follows automatically.

The Foundation workflow is manual-only and must be dispatched after merge from the exact merged-main SHA. Use `--dry-run` to validate guards and the read plan without constructing a client. On any missing scenario, mismatch, blocker, stale state, authorization failure, or unclear history, stop and preserve evidence. If a replay outcome is unknown, read current state before any retry; never add or perform an automatic retry.

Application rollback redeploys the last approved commit. Identity rollback reinstalls the prior manifest only after reviewing live client needs. Database rollback drops only reconciliation functions/grants and never deletes immutable PO/PXK predecessors or edits production data. For unknown outcomes, read current state before any manual retry.
