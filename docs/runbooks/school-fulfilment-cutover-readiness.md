# School fulfilment cutover-readiness runbook

## Current read-only gate — 14 October 2026

Atlas Staging is at migration 109/business SHA `8e68c2ce2cf766279d020210e9b53b457048db22`. Exact-main Frontend/Full Integration and guarded deployment 38565480612 passed; reviewed rollback acceptance passed 48 cases with zero probes and unchanged operational/Actor facts. See [109 evidence and parsed reports](../testing/atlas-pxk-exact-school-scope-109.md).

The default formal [A/B/C workflow run 38566354791](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38566354791) passed all three scenarios at that exact business/verifier SHA on 14 October, 12:46:40 UTC. This gate is complete. Historical Identity/Foundation installation and Scenario rehearsal steps below are retained history, not instructions to replay them against current migration 109.

The remaining gate is an explicitly opted-in actual HTTP released-allocation read. After this tooling's independent review, merge and exact-head CI, Root may dispatch the existing `Atlas Staging School Fulfilment Verify` workflow from merged main with `deployed_commit_sha=8e68c2ce2cf766279d020210e9b53b457048db22` and `released_allocation_read=true`. Record that business SHA separately from the workflow's actual merged verifier SHA. Default `released_allocation_read=false` retains formal A/B/C behavior; do not rerun its completed gate merely for this evidence.

The opt-in mode validates the protected project and read-only source/migration prerequisite before creating a client. It signs in, performs exactly one `get_confirmed_supplier_allocation_workbench` for `2026-10-12` with empty School/state filters and null search, disables retry and requires completion below 8,000 ms. It requires 236 distinct family IDs, complete balanced Handoff authority, correct quantities/lineage and Preparation ready/allowed/version 5 for released batch `69661e86-abb3-4bf4-88a5-4717fe18c472`.

PostgreSQL hashes the full actual HTTP `rows` array sorted by nested `family.family_id`; required MD5 remains `48e433c45fac665d873103542408a484`, as documented by the [post-release allocation task](../implementation-tasks/TASK-PROCUREMENT-POST-RELEASE-ALLOCATION-READ-01.md). The digest query safely hex-encodes the actual JSON response and performs no second SQL RPC. It does not compute a JavaScript hash or select a new field subset. Before/after hashes reuse only exported `snapshotSql` from the existing purchase acceptance script, with original Preparation command `c51a2f96-54ab-400d-94fb-910544949f37`. That script's main, command acceptance, Preparation preflight and replay are never invoked.

All management SQL is BEGIN READ ONLY with unchanged 8-second statement / 1-second lock caps. Source/236-lineage/split/Handoff/17-PO/receipt/audit evidence must be identical before and after. A failure still attempts independent read-only postflight and local sign-out when possible. Changed baseline, missing prerequisite, malformed/truncated response, transport limit, timing or digest mismatch stops the gate; preserve the failure, never adjust the expected digest, retry automatically, repair facts or raise timeouts. Output contains only summary counts, elapsed time and digests, never raw rows or credentials. Actual hosted execution is pending Root's protected run; local harness tests are not hosted performance evidence.

One authorized staff Actor per ordinary operational task remains the mandate; capability, scope, audit and existing exception/override/staff-grant approvals stay mandatory. No Preparation command, Identity/Foundation replay, staff grant, real commitment, Production/OPS-v1/Retool write or Warehouse implementation is part of this read-only gate.

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
8. From `main`, manually dispatch `Atlas Staging School Fulfilment Verify` with deployed business SHA `147648712ce57355d66773edd45a5e3ecd6458c9`. The workflow runs the verifier implementation at its current workflow-execution SHA rather than checking out the deployed business SHA. Need certification reads `2046-09-17`, `2046-09-18`, and `2046-09-19` as three independent exact-day workbenches, then reads atomic detail at each required grouped identity; it does not issue one ranged Need workbench read. This formal certification is read-only: it must not replay Identity or Foundation, deploy migrations, retry, or write business data. Require `School fulfilment verifier passed (3 scenarios).`
9. Record both the deployed business SHA and verifier implementation SHA, plus the workflow run URL/ID, verifier output, and timestamp, then proceed only to the Product/Architecture cutover decision. No production activation follows automatically.

The Foundation workflow is manual-only and must be dispatched after merge from the exact merged-main SHA. Use `--dry-run` to validate guards and the read plan without constructing a client. On any missing scenario, mismatch, blocker, stale state, authorization failure, or unclear history, stop and preserve evidence. If a replay outcome is unknown, read current state before any retry; never add or perform an automatic retry.

Application rollback redeploys the last approved commit. Identity rollback reinstalls the prior manifest only after reviewing live client needs. Database rollback drops only reconciliation functions/grants and never deletes immutable PO/PXK predecessors or edits production data. For unknown outcomes, read current state before any manual retry.
