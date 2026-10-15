# Operator bulk Allocation B — local validation, 15 October 2026

Status: IMPLEMENTED — Draft review and exact-head CI pending. No merge, deployment or hosted write is authorized.

This optional review-and-save action orchestrates the existing Confirmed Need and Purchase Handoff allocation writers. It does not make bulk confirmation a prerequisite for normal purchase preparation. Existing manual choices remain excluded unless the server offers an explicit stale rebalance. The browser selects complete server proposals; quantity arithmetic and persistence remain authoritative in the backend.

## Source and isolation

The authority-only commit is `5e891db431fdc683a5674ecfdf45cb2777df7b93`, based on accepted main `d102b2f1b083005d6553867fa5ccdf8c988a0316`. The migration is [20261015042701_operator_bulk_supplier_allocation.sql](../../supabase/migrations/20261015042701_operator_bulk_supplier_allocation.sql). Its committed LF Git blob has SHA256 `718d274c0ba0616c4381ccc9ae4e47248adc4c9457bc58ccde69093216ac3ca2`; the actual CRLF bytes applied locally have SHA256 `59361dd32f08916813ecb5f0219a272fe60d79a35298ee2efe9c99b16e3754c0`. The working image has 420 CRLF pairs and the Git blob has 0; replacing CRLF with LF produces the committed blob byte-for-byte. There is zero semantic delta. SQL and lock-wait evidence refer to the actual applied CRLF image, and their original hashes remain unchanged. Its generated version identifies this independent Draft; no globally fixed next migration ordinal is claimed.

All SQL work used explicit task-owned databases on the verified local `supabase_db_thuonghao-ops-erp` PostgreSQL17 container. `atlas_bulk_b_01` started absent and received schema-only Auth support and all 109 accepted migration files. This is a schema-applied baseline, **not** a fabricated migration ledger. The pre-existing default `postgres` database contains unledgered A2 development changes and was preserved, as were all existing volumes. B has no PO `unit_name_snapshot` column.

For the final forward proof, `atlas_bulk_b_forward_02` was cloned from empty task-owned schema, restored to the original main 109 public read/Save definitions, and had only B's three new functions removed. Original main 109 catalog 30/30 passed before the full migration committed. A CRLF source-body amendment failure was retained as RED; the transaction rolled back DDL and transient authoring privileges. Normalizing definition line endings made the same bounded amendment portable. Exact-head clean CLI integration remains a required GitHub gate.

[Sanitized results and source/log hashes](artifacts/atlas-operator-bulk-allocation-b-01/summary.json) retain the evidence boundaries. Raw development logs remain outside the repository under `%TEMP%/atlas-b-*`.

## Database behavior and security

The final migration passed 119 assertions: bulk matrix51, mixed-source/PO matrix23, scale15 and exact catalog30. A further 895 connected regression assertions passed at backend checkpoint `4f9af12e759624a23a7451f7ebcf4748434696fe5f1bc2e610911737082459ba`: allocation convergence417, purchase review193, Handoff88, purchase orders155, notes13, source ambiguity9, release projection7 and released allocation read13. Later changes were limited to current-revision/frozen Supplier PO-impact projection and CRLF-safe migration amendment; the final 119 assertions cover those changes. The shared command, locks and source-binding path stayed identical.

The matrix proves:

- Omitted/false preview preserves ordinary response behavior; true/false flags are removed before closed Handoff forwarding; null and wrong-type flags fail safely. Bulk scope ignores table search/state and includes complete zero sources omitted from ordinary rows.
- Unique defaults, retained priority ties, absent priority, no eligible Supplier, eligibility/priority/source/version races, and whole-family School deduplication behave explicitly. Shared-location School selection includes every contributor and full exact quantity. Ambiguous overlapping source batches are excluded.
- Both real source-specific writers run in one transaction. A late Confirmed child rejection after real Handoff children rolls back all new child facts, receipts and success events. Exact replay does not create new child identities; conflicting replay is rejected.
- Rebalance preserves Supplier notes and exact six-place quantities, including deterministic residual `72.006001 / 48.003999`. Missing historical School lineage keeps retained contributions/full quantity visible but excludes the optional bulk candidate.
- Existing write capability/location-family scope suffices for Apply without adding read capability or GLOBAL. Denied scope/capability writes nothing. PO visibility never becomes an extra allocation Save condition.
- Visible PO impacts always disclose `AUTHORIZED_DOCUMENTS_ONLY`. An inaccessible PO changes neither disclosed impact nor Apply behavior. The current revision must actually contain the family; retained historical stable lines do not qualify. A released PO's frozen Supplier name survives a current Master Data rename.

The exact catalog changes are one authenticated public API and two private helpers: APIs 121→122, private 349→351, target grants 1855→1860. Tables 117, catalog policies 674, triggers 126, capabilities 31, application/database roles and unrelated table/policy/view digests remain unchanged. The existing separate Unit lock policy is not part of the CAT-22 policy slice. Precise owner, INVOKER/DEFINER, empty search path, browser/service/PUBLIC denial and intended runtime EXECUTE assertions supplement CAT-22, whose grant slice does not include PUBLIC. Authoring memberships finish with SET=false; no broad runtime table privileges were added.

### Actual lock wait and scale

The [two-session report](artifacts/atlas-operator-bulk-allocation-b-01/lock-wait.json) records the actual applied CRLF migration hash `59361dd32f08916813ecb5f0219a272fe60d79a35298ee2efe9c99b16e3754c0` in separate owned database `atlas_bulk_b_wait_03`. Authenticated source Save advanced the source from version 2 to 3 while holding its CN batch lock. Apply was observed waiting on `Lock/transactionid`; only then did the source transaction commit. Apply rebuilt evidence and returned `STALE_BULK_PROPOSAL`, with zero allocation revisions, child receipts or allocation events before and after. Its 750 ms includes coordination and monitoring, not a pure RPC benchmark. Earlier wait databases remain preserved.

The genuine current Confirmed Need sample contains **50 Schools ×5 Ingredients =250 whole families on one date**. Separate start/end statements measured authenticated preview **4086.131ms** and Apply **1826.887ms**, each under `statement_timeout=8s`. The initial unoptimized Apply timed out at 8 s and remains recorded; reusing complete backend-resolved evidence after canonical whole-set locks removed repeated child source resolution. No browser evidence is trusted and no timeout increased.

Mixed-source atomic correctness is measured separately in the small fixture. This is a local bounded sample, not hosted-scale or multi-day certification. The UI retains its 1–7-day range; backend 31-day validation is unchanged. Final postflight found zero receipts/allocation revisions and confirmed the A2 PO column absent.

## Frontend and browser proof

Tracked-source focused verification passed **282 assertions in 7 files**, excluding ignored `.superpowers` reference copies via CLI only. It covers the API envelope/transport allowlist, controller, active workbench, synthetic journey, incumbent legacy workbench and integration registration/catalog contract. Typecheck and `ui:vnext:check` passed. The final Impeccable mechanical scan returned [no findings](artifacts/atlas-operator-bulk-allocation-b-01/impeccable.json).

Feature RED logs recorded missing API/toolbar/controller behavior, discarded per-family conflict feedback and fabricated null-as-zero display before their corrections. A missing accessible-name separator and exact registry ordering were caught by focused tests. These failures were corrected without changing quantities, source identity, lock behavior or global gates.

Root's [browser manifest](artifacts/atlas-operator-bulk-allocation-b-01/browser-manifest.json) records nine checks at 1280×720,1440×900 and 1920×1080 using only the existing in-memory review entry. It covers explicit DEFAULT saving, initially unchecked REBALANCE, manual exclusion, controlled unknown quantities, dirty selection/detail guards, locked date/School/context controls, UNKNOWN/readback recovery and exact retry availability. Successful readback restores focus to the bulk action once it is enabled. Document widths equalled viewport widths; no overlap or clipping was observed. Exact retry identity and failed-readback lock are automated controller evidence, not browser hidden-state inspection.

Only three selected captures are retained; other captures listed in the original manifest remain TEMP-only:

- [DEFAULT at 1280](artifacts/atlas-operator-bulk-allocation-b-01/default-1280.jpg)
- [Explicit REBALANCE at1440](artifacts/atlas-operator-bulk-allocation-b-01/rebalance-1440.jpg)
- [Incomplete/blocked at1920](artifacts/atlas-operator-bulk-allocation-b-01/blocked-1920.jpg)

Harness: `/atlas-vnext-review.html?scenario=ready&bulk=normal`; substitute `rebalance`, `blocked`, `unknown` or `retryable_failure`. Omit `bulk` with `scenario=ready` for a preserved manual split. The fixture uses selected dates and whole-family ANY-School filtering. It is never imported by the production entry. Native document producers were not changed, so no export recertification is claimed.

## Reproduce and release boundary

The three new SQL suites are registered in the existing local Full Integration runner and its purchase-review include-expansion group. Their transactions end in ROLLBACK. To run against an already verified owned B schema, use an explicit database, for example:

```powershell
docker exec supabase_db_thuonghao-ops-erp psql -U postgres -d atlas_bulk_b_forward_02 -v ON_ERROR_STOP=1 -f /tmp/atlas-b/tests/operator_bulk_allocation.sql
```

Check TAP `not ok` and exact plan/count, not only process exit. The test sources live under `supabase/tests/operator_bulk_allocation*.sql`; copy their existing local includes with the same relative structure. Do not run these fixtures against hosted data or reset an unproven database.

The migration adds functions and replaces bounded read/command definitions; rollback requires a reviewed function-definition restoration or a forward correction. Do not drop historical business rows, reset a shared database or deploy a migration rollback automatically. Local fixtures roll back themselves, and all owned validation databases/volumes remain available for review.

Keep the PR Draft pending independent fixed-SHA review and exact-head Frontend/Full Integration results. Atlas Staging remains109. PR385/386, historical108/109 proof, Shopping List import semantics and pending Warehouse choices are separate. No hosted acceptance, merge, deployment, real Supplier/PO commitment or staff assignment follows this local proof.
