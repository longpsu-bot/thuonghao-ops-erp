# Hosted Purchase Preparation acceptance: migration 105

The protected `Atlas Staging Planning Performance` workflow has an opt-in
`purchase_acceptance` mode. Its default remains rollback-only Planning profiling.
Acceptance runs the certified `commit_sha` checkout's existing non-mutating
Staging preflight, then loads only the acceptance harness and its tests from the
workflow revision. It does not deploy migrations or change application code.

The harness hard-targets `rnzxmxiiqgtdevzregff` through the existing Staging
credential and target guards, which reject OPS v1. It authenticates the established
synthetic subject, reads the actual public allocation API, and requires migration
105, the 20-second function setting, `2026-10-12`, batch
`69661e86-abb3-4bf4-88a5-4717fe18c472` at `DRAFT_REVIEW / 2`, 236 complete positive
families, 17 preferred Suppliers, preparation permission and zero downstream facts.

One frontend-shaped request is recorded before its authenticated REST invocation.
Elapsed time includes response-body completion; transport permits 45 seconds.
Confirmed success is checked against exact preflight quantities and Suppliers,
allocation/Handoff/PO counts, current split and contribution sums, predecessor
and PO-line lineage, and the accepted receipt. The exact request is then replayed.
Response equality and a deterministic digest of downstream facts, receipts and
events must remain unchanged. The first REST elapsed time must be below 20 seconds.
This one-target acceptance does not claim the separate three-sample performance
certification documented in the API contract.

Evidence is uploaded even on failure, with a 14-day artifact retention. It contains
no credentials or access tokens. If transport or response completion is unknown,
the harness performs authoritative readback and sends no further request. Never
rerun this mode after an attempted command without inspecting its recorded command
identity, receipt and final state. A changed preflight fails closed.

No schema migration or rollback is introduced. A successful run persistently
releases the Confirmed Need/Handoff and creates Draft POs in Staging; deleting
those facts is not a rollback. Remove the optional harness mode to retire the tool.

If the first public command succeeded but the verifier stopped before replay,
set `purchase_acceptance=true` and `replay_evidence_run_id` to the original run.
The protected workflow downloads that run's evidence artifact. Recovery requires
the original HTTP success, exact request/receipt-response identity and unchanged
fact digest before sending only the recorded exact replay. It never generates a
new preparation request in this mode.

## Accepted hosted result — 2026-10-13

The first authenticated REST command completed successfully in 18,925.761 ms.
Exact replay completed in 2,006.145 ms with equal responses and zero fact,
receipt or event deltas. Final state is `RELEASED_FOR_PURCHASE_HANDOFF / 5`,
236 allocations, 236 generated priority defaults, no manual defaults, 236 promoted
families, one released Handoff, 17 Draft POs and 236 PO lines. Exact preflight
quantities/Suppliers and current lineage checks passed. See the
[durable acceptance summary](../testing/artifacts/hosted-purchase-acceptance-105/summary.json)
for command identity, response hashes, fact digests and protected workflow runs.

The result meets the requested 20-second threshold, with approximately one second
of headroom; it misses the preferred 15–18-second result. No migration 106 or
performance correction was made. A separate post-release allocation-workbench
read timed out under its 8-second read budget; that issue remains outside this
acceptance and was not changed. Recovery used recorded preflight and authoritative
receipt/readback rather than repeating that unnecessary read.
