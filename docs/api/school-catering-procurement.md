# School-Catering Procurement API Contract

Status: PR A implements the Handoff and Allocation Family boundary. PR B is the next sequential slice for Purchase Orders. The approved connected design and implementation plan remain authoritative if this summary is incomplete.

## Contract and security boundary

All requests are one `jsonb` argument and all responses are safe `jsonb` envelopes. Commands require an authenticated Atlas Actor, the stated active capability and an authorized scope; they use receipts, idempotency, optimistic versions, domain events and audit events. Reads are shaped APIs only. Browser roles receive `EXECUTE` on public functions and no direct table privileges. Runtime owners have empty `search_path`; all authoritative tables use forced RLS.

| API                                                | PR                      | Kind    | Contract                         | Capability                          | Purpose                                                                                                      |
| -------------------------------------------------- | ----------------------- | ------- | -------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `release_school_catering_purchase_handoff`         | A, callable             | command | `SCHOOL-CATERING-HANDOFF.v1`     | `confirmed_need_release.release`    | Release one current NEED_GENERATION Confirmed Need snapshot to a versioned Purchase Handoff.                 |
| `save_school_catering_supplier_allocation`         | A, callable             | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Persist an exact balanced manual or rebalanced supplier split revision.                                      |
| `confirm_school_catering_supplier_recommendations` | A, callable             | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Confirm explicit untouched candidates only when one active eligible supplier has the unique lowest priority. |
| `get_school_catering_procurement_workbench`        | A, callable             | read    | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.read`  | Return authoritative families, trace, eligibility, recommendations, state and server-governed actions.       |
| `create_school_catering_purchase_order_drafts`     | B, not callable in PR A | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Create or supersede affected supplier/date PO drafts from accepted Allocation Family revisions.              |
| `release_school_catering_purchase_order`           | B, not callable in PR A | command | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.write` | Release exactly one current school-catering PO draft to its supplier.                                        |
| `get_school_catering_purchase_orders`              | B, not callable in PR A | read    | `SCHOOL-CATERING-PROCUREMENT.v1` | `procurement.school_catering.read`  | Read shaped school-catering PO roots, revisions, lines, lineage and actions.                                 |

## PR-A requests and responses

`release_school_catering_purchase_handoff` uses the normal command envelope, reason `SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED`, expected Confirmed Need version, and payload `{ confirmed_need_batch_id }`. It returns Handoff root/revision/line/reference IDs, new version, event/audit IDs and replay status. First release creates a BASE revision; a corrected release reuses the root and creates a SUPERSEDING revision. Only released NEED_GENERATION snapshots qualify.

`save_school_catering_supplier_allocation` uses reason `SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED`, the expected family version, and payload `{ family, splits }`. The family contains service date, delivery location, ingredient, unit and expected source fingerprint. Each split contains one supplier and positive allocated quantity. The server requires unique suppliers, exact total equality, active effective eligibility and a current fingerprint; it calculates ratios and persists immutable revision, contribution and split history.

`confirm_school_catering_supplier_recommendations` uses reason `SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED` and payload `{ candidates }`. Every candidate includes the family key, expected version `0`, and expected fingerprint. The response separates atomically confirmed candidates from safe skips such as stale/edited, changed source, missing eligibility or ambiguous priority.

`get_school_catering_procurement_workbench` accepts payload `{ date_start, date_end, school_ids, states, search }` for a bounded date range. Rows include display fields, authoritative quantity and contributions, current splits and ratios, ordered eligible suppliers, an uncommitted unique recommendation, state (`UNALLOCATED`, `BALANCED`, `STALE_REBALANCE_AVAILABLE`, `NEEDS_REALLOCATION`, or `BLOCKED`), an exact-residual prior-ratio rebalance proposal when safe, blockers/warnings, allowed actions and disabled reasons.

## Errors, correction and tests

Safe failures include malformed requests, authentication/authorization denial, not found, stale version/fingerprint, incomplete source snapshots, imbalance, duplicate/non-positive splits, inactive or ineligible suppliers, and retryable concurrency failure. Errors must not leak private data or partially write a command.

D-042 remains blocked for WHOLESALE Handoffs. Before supplier commitment, school-catering correction invalidates only the current Handoff revision/root state, retains all lineage and Allocation Family history, reopens Confirmed Need, and allows the next release to supersede the Handoff. PR B extends this classification for draft and released supplier POs.

Verification authority is `school_catering_handoff_allocation.sql`, `school_catering_planning_correction.sql`, the unchanged PA-05D/PA-05E and issue-222 regressions, the current platform security catalog, and the authenticated local journey verifier.
