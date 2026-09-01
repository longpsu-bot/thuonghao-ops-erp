# School-Catering Procurement API Contract

Status: PR A implements the Handoff and Allocation Family boundary. PR B implements supplier/date Purchase Order drafts, successor regeneration, release, numbering, and shaped reads. The approved connected design and implementation plan remain authoritative if this summary is incomplete.

## Contract and security boundary

All requests are one `jsonb` argument and all responses are safe `jsonb` envelopes. Commands require an authenticated Atlas Actor, the stated active capability and an authorized scope; they use receipts, idempotency, optimistic versions, domain events and audit events. Reads are shaped APIs only. Browser roles receive `EXECUTE` on public functions and no direct table privileges. Runtime owners have empty `search_path`; all authoritative tables use forced RLS.

| API                                                | PR          | Kind    | Contract                         | Capability                          | Purpose                                                                                                      |
| -------------------------------------------------- | ----------- | ------- | -------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `release_school_catering_purchase_handoff`         | A, callable | command | `SCHOOL-CATERING-HANDOFF.v1`     | `confirmed_need_release.release`    | Release one current NEED_GENERATION Confirmed Need snapshot to a versioned Purchase Handoff.                 |
| `save_school_catering_supplier_allocation`         | A, callable | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Persist an exact balanced manual or rebalanced supplier split revision.                                      |
| `confirm_school_catering_supplier_recommendations` | A, callable | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Confirm explicit untouched candidates only when one active eligible supplier has the unique lowest priority. |
| `get_school_catering_procurement_workbench`        | A, callable | read    | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.read`  | Return authoritative families, trace, eligibility, recommendations, state and server-governed actions.       |
| `create_school_catering_purchase_order_drafts`     | B, callable | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Create or supersede affected supplier/date PO drafts from accepted Allocation Family revisions.              |
| `release_school_catering_purchase_order`           | B, callable | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Release exactly one current school-catering PO draft to its supplier.                                        |
| `get_school_catering_purchase_orders`              | B, callable | read    | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.read`  | Read shaped school-catering PO roots, revisions, lines, lineage and actions.                                 |

## Implemented requests and responses

`release_school_catering_purchase_handoff` uses the normal command envelope, reason `SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED`, expected Confirmed Need version, and payload `{ confirmed_need_batch_id }`. It returns Handoff root/revision/line/reference IDs, new version, event/audit IDs and replay status. First release creates a BASE revision; a corrected release reuses the root and creates a SUPERSEDING revision. Only released NEED_GENERATION snapshots qualify.

`save_school_catering_supplier_allocation` uses reason `SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED`, the expected family version, and payload `{ family, splits }`. The family contains service date, delivery location, ingredient, unit and expected source fingerprint. Each split contains one supplier and positive allocated quantity. The server requires unique suppliers, exact total equality, active effective eligibility and a current fingerprint; it calculates ratios and persists immutable revision, contribution and split history.

`confirm_school_catering_supplier_recommendations` uses reason `SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED` and payload `{ candidates }`. Every candidate includes the family key, expected version `0`, and expected fingerprint. The response separates atomically confirmed candidates from safe skips such as stale/edited, changed source, missing eligibility or ambiguous priority.

`get_school_catering_procurement_workbench` accepts payload `{ date_start, date_end, school_ids, states, search }` for a bounded date range. Rows include display fields, authoritative quantity and contributions, current splits and ratios, ordered eligible suppliers, an uncommitted unique recommendation, state (`UNALLOCATED`, `BALANCED`, `STALE_REBALANCE_AVAILABLE`, `NEEDS_REALLOCATION`, or `BLOCKED`), an exact-residual prior-ratio rebalance proposal when safe, blockers/warnings, allowed actions and disabled reasons.

`create_school_catering_purchase_order_drafts` uses reason `SCHOOL_CATERING_PO_DRAFTS_CREATED`, sentinel expected version `1`, and payload `{ date_start, date_end }` for an inclusive range of at most 31 days. A date is ready only when every current Handoff-derived Allocation Family is balanced, source-current, and assigned only to active/effective eligible suppliers. Ready dates create or regenerate one DRAFT lineage per supplier/date; blocked dates are skipped atomically by date with explicit blockers. Regeneration creates successor revisions and never rewrites history or released roots.

`release_school_catering_purchase_order` uses reason `SCHOOL_CATERING_PO_RELEASED` and payload `{ purchase_order_id, expected_purchase_order_revision_id }`; callers cannot provide the supplier, status, actor, or document number. Under deterministic locks, the server revalidates root/revision versions, current family/split evidence, supplier activity, and effective eligibility. Success creates an immutable `RELEASED_TO_SUPPLIER` successor and the server-only number `PO-<YYYYMMDD>-<first 16 uppercase PO UUID hex characters>`.

`get_school_catering_purchase_orders` accepts payload `{ date_start, date_end, supplier_ids, statuses, search }`. It returns supplier/date roots, the current revision/version, multi-destination lines and exact family/split sources, server-derived stale/release/export state, the official number only after release, blockers/warnings, and backend-owned allowed/disabled actions.

## Errors, correction and tests

Safe failures include malformed requests, authentication/authorization denial, not found, stale version/fingerprint, incomplete source snapshots, imbalance, duplicate/non-positive splits, inactive or ineligible suppliers, and retryable concurrency failure. Errors must not leak private data or partially write a command.

D-042 remains blocked for WHOLESALE Handoffs. A school-catering Allocation Family plus DRAFT PO is not a supplier commitment: correction invalidates only the current Handoff revision/root state, retains all lineage and PO history, reopens Confirmed Need, and leaves the DRAFT to become derived-stale. A `RELEASED_TO_SUPPLIER` school-catering PO is a later-domain commitment and returns `BLOCKED_BY_DOWNSTREAM_COMMITMENT`; neither the Handoff nor released PO is mutated.

Verification authority is `school_catering_handoff_allocation.sql`, `school_catering_planning_correction.sql`, `school_catering_purchase_orders.sql`, the unchanged PA-05D/PA-05E/PA-05G and issue-222 regressions, the exact 107-table/29-capability/99-API platform security catalog, and the authenticated local journey verifier.
