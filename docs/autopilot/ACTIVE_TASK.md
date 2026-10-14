# Atlas Autopilot — Active Task

Task: ATLAS-CUTOVER-READ-ACCEPTANCE-01
Status: IMPLEMENTED LOCALLY — fixed-head review and exact-head CI pending
Navigator: Terra/read-only role
Implementer: Sol 6.1
Starting main: 8e68c2ce2cf766279d020210e9b53b457048db22
Atlas Staging: rnzxmxiiqgtdevzregff — migration 109
OPS v1 / Retool / Production: no writes or commitments

## Previous task accepted

ATLAS-PXK-EXACT-SCHOOL-SCOPE-01 merged through [PR #382](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/382). Exact-main Frontend 38564165289 and Full Integration 38564165442 passed; guarded deployment 38565480612 passed. Native migration tip is `20261014120320`. Reviewed rollback acceptance at source `72c80979ac632351dd25f7197eabfad3bcecd5bc` passed 48 cases, with independent final 36 relation checks / zero probes and unchanged 17 real Draft POs/hash `cefbff23b30cbc15dac0b890a956d884`.

The other 467 function catalog rows, existing 12 PXK fact rows and 27 Actor configuration rows retained their exact before/after hashes; helper owner/SECURITY DEFINER/path/ACL and existing advisor entities were unchanged. See [109 evidence](../testing/atlas-pxk-exact-school-scope-109.md) and [parsed native reports](../testing/evidence/atlas-pxk-exact-school-scope-staging-109.json). The global mandate now records Product's one-staff-per-operational-task constraint without assigning users or waiving existing exception/approval gates.

## Approved read-only gate

Extend the existing School fulfilment verifier with an explicit opt-in released-allocation-read mode. Its default formal A/B/C behavior remains unchanged. Root's default formal [A/B/C run 38566354791](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38566354791) passed all three scenarios at business/verifier starting-main SHA on 14 October 2026, 12:46:40 UTC. That gate is closed; do not rerun it, repair fixtures or replay Identity/Foundation.

The opt-in mode must perform exactly one actual authenticated HTTP `get_confirmed_supplier_allocation_workbench` for `2026-10-12` with closed payload and no automatic retry. Require completed response in less than 8,000 ms, 236 distinct family rows, balanced/current Handoff/source lineage, exact quantities and Preparation ready/allowed version 5 for released batch `69661e86-abb3-4bf4-88a5-4717fe18c472`. PostgreSQL must hash the actual HTTP response's canonical assignment/quantity/lineage projection to `48e433c45fac665d873103542408a484`; a second SQL RPC or JavaScript serialization hash cannot substitute for that body.

Reuse only exported `snapshotSql` from the existing hosted-purchase acceptance script for read-only before/after source, lineage, split, Handoff, 17-PO, receipt/audit fact hashes. Execute under BEGIN READ ONLY, 8-second statement / 1-second lock caps. Never invoke that script's main, executeAcceptance, Preparation preflight or replay. Changed facts, missing prerequisite, transport limit, malformed evidence or timeout fail closed; attempt read-only postflight and sign-out on failure when possible. Never restore data, retry automatically or raise timeouts.

## Allowed files and validation

- `scripts/verify-atlas-staging-school-fulfilment.mjs` and its existing test file.
- `scripts/atlas-staging-contract.test.mjs`: necessary existing workflow-contract assertions for the typed opt-in/default commands. Preserve exact credential allowlist, target/dual-SHA/read-only guards; the mode flag is step-local, not a new protected credential.
- `.github/workflows/atlas-staging-school-fulfilment-verify.yml`: typed opt-in input/CLI flag using existing protected target and credential guards.
- This baton, mandate, 109 parsed evidence/validation doc, affected cutover-readiness runbook/evidence.
- No new runner, npm command, framework, dependency, schema/migration, business function, UI or unrelated workflow change.

Test-first focused coverage must reject wrong target/migration before client creation, preserve dry-run/default behavior, permit only the one GET RPC, reject duplicate identities/quantity/lineage/hash/released-state/prepare-version errors and elapsed time >=8s, compare complete before/after facts including receipts, encode SQL input safely for apostrophe/backslash/Unicode/dollar quotes, prove the digest consumes the actual HTTP body and guarantee failure-path postflight/sign-out. No rows, tokens or credentials may be logged.

## Delivery and hard stops

One fresh bounded branch and Draft PR, fixed-SHA Terra review and exact-head CI. Root runs the actual protected hosted mode after review/merge/CI; the implementer does not execute it. No staff grants, Production/OPS-v1/Retool write, real commitments, Preparation execution, new hosted fixtures or Warehouse implementation.

After verified read acceptance, proposed next work is a thin Warehouse receiving design packet READY FOR PRODUCT REVIEW. Final Warehouse business-design approval remains a hard stop before implementation; this task does not authorize that code.

## Local verification

The existing verifier now has an explicit opt-in flag and protected boolean workflow input defaulting false. The default A/B/C behavior is retained. PostgreSQL hashes the full actual HTTP rows sorted by nested family ID; no selected subset or second SQL RPC is used. Read-only snapshot preflight precedes client construction; response completion has an unchanged 8-second abort/check, and independent postflight plus sign-out run on failure when possible.

Test-first controls reproduced the previously absent mode, bad response envelope and missing Confirmed Need lineage. Focused verifier (51), staging-contract (116) and existing purchase acceptance (6) tests pass: 173 total. Generated snapshot SQL also parsed/executed against the disposable local 109 database as two READ ONLY queries; absent workload prerequisites stopped before client construction. Formatting and diff whitespace pass. These are local tooling checks, not hosted latency evidence. Actual opt-in hosted read and final gate result remain pending Root's reviewed merged-SHA workflow run.
