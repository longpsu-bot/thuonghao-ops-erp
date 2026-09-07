# School-Catering Procurement API Contract

Status: Implemented and merged through the connected school-catering Procurement changes and PURCHASE-REVIEW-CONFIRM-RELEASE-01. The approved connected design and implementation records remain authoritative if this summary is incomplete.

[ATLAS-MODEL-PRINCIPLE-01](../decisions/decision-atlas-model-convergence.md) and the [authority map through Procurement](../architecture/atlas-authority-map-through-procurement.md) clarify the current meaning without changing these APIs: generated review, recommendations, Handoff structures, Allocation Family identities, source promotion and PO drafts are supporting evidence beneath real commands; saved exact supplier splits are explicit human decisions; balance, freshness and eligibility are derived; released PO content and official number are explicit immutable supplier commitments. Existing source-specific Handoff allocation writers remain valid support/current-source routes and are not a second authority for the same source.

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

All precision-sensitive workbench response values are JSON strings at the public boundary: `family_quantity`, every `contribution_quantity`, every allocation/recommendation/rebalance `allocated_quantity`, and every `split_ratio`. Quantities use six fractional digits and ratios use twelve. Internal PostgreSQL calculations, equality checks and source fingerprints remain exact numeric operations.

`create_school_catering_purchase_order_drafts` uses reason `SCHOOL_CATERING_PO_DRAFTS_CREATED`, sentinel expected version `1`, and payload `{ date_start, date_end }` for an inclusive range of at most 31 days. A date is ready only when every current Handoff-derived Allocation Family is balanced, source-current, and assigned only to active/effective eligible suppliers. Ready dates create or regenerate one DRAFT lineage per supplier/date; blocked dates are skipped atomically by date with explicit blockers. Regeneration creates successor revisions and never rewrites history or released roots.

`release_school_catering_purchase_order` uses reason `SCHOOL_CATERING_PO_RELEASED` and payload `{ purchase_order_id, expected_purchase_order_revision_id }`; callers cannot provide the supplier, status, actor, or document number. Under deterministic locks, the server revalidates root/revision versions, current family/split evidence, supplier activity, and effective eligibility. Success creates an immutable `RELEASED_TO_SUPPLIER` successor and the server-only number `PO-<YYYYMMDD>-<first 16 uppercase PO UUID hex characters>`.

`get_school_catering_purchase_orders` accepts payload `{ date_start, date_end, supplier_ids, statuses, search }`. It returns supplier/date roots, the current revision/version, multi-destination lines and exact family/split sources, server-derived stale/release/export state, the official number only after release, blockers/warnings, and backend-owned allowed/disabled actions.

Every line `ordered_quantity` is serialized as a six-fractional-digit JSON string. Clients must parse or format that exact decimal text without first coercing it through an IEEE-754 number.

## Errors, correction and tests

Safe failures include malformed requests, authentication/authorization denial, not found, stale version/fingerprint, incomplete source snapshots, imbalance, duplicate/non-positive splits, inactive or ineligible suppliers, and retryable concurrency failure. Errors must not leak private data or partially write a command.

D-042 remains blocked for WHOLESALE Handoffs. A school-catering Allocation Family plus DRAFT PO is not a supplier commitment: correction invalidates only the current Handoff revision/root state, retains all lineage and PO history, reopens Confirmed Need, and leaves the DRAFT to become derived-stale. A `RELEASED_TO_SUPPLIER` school-catering PO is a later-domain commitment and returns `BLOCKED_BY_DOWNSTREAM_COMMITMENT`; neither the Handoff nor released PO is mutated.

Verification authority includes `purchase_review_confirm_release.sql`, `purchase_handoff_clock_skew.sql`, `school_catering_handoff_allocation.sql`, `school_catering_planning_correction.sql`, `school_catering_purchase_orders.sql`, the unchanged PA-05D/PA-05E/PA-05G and issue-222 regressions, the exact 107-table/29-capability/103-API platform security catalog, and the authenticated local journey verifier.

## PURCHASE-REVIEW-CONFIRM-RELEASE-01 amendment

Authority: the explicitly approved [bounded design](../superpowers/specs/2026-09-03-purchase-review-confirm-release-design.md). The normal operator path is generated paper review → saved Confirmed Need → saved supplier allocation → atomic commitment preparation → independent PO release. This changes no module boundary, lifecycle vocabulary, Warehouse behavior or released-PO amendment policy.

### Generated review — `PURCHASE-REVIEW.v1`

`atlas_api.get_generated_purchase_review(request jsonb)` is a read-only, authenticated, scope-filtered API. Its closed envelope is `{ contract_version, requested_by_auth_subject, correlation_id, payload: { service_date } }`. It requires the existing `procurement.school_catering.read` capability and reads current released Need Generation evidence, never saved allocation or PO quantities.

Response includes `success`, `contract_version`, `service_date`, `document_label: "DỰ KIẾN — CHƯA XÁC NHẬN"`, `rows`, `blockers` and `warnings`. Rows identify date, School, delivery location, Ingredient and Unit, exact `family_quantity`, eligible suppliers, nullable recommendation and warnings. Unique lowest non-null effective priority produces an uncommitted suggestion; absent eligibility, absent priority or a tie remains unresolved. Reads and XLSX export create zero allocation, Handoff, PO, receipt or acceptance-event facts.

The separate preliminary XLSX uses the inspected Retool v1 `lib/js_exportPOZip.js` print geometry, Times New Roman typography, supplier/School bands and two sheets (`Tổng`, `Chi tiết`). Its single-date workbook is deliberately not the official supplier ZIP. Quantities remain exact text, correction space remains blank, unresolved suppliers are explicit, and no official document number or invented item code appears. Existing released PO XLSX/PDF exporters and their source guards remain unchanged.

### Confirmed allocation — `CONFIRMED-SUPPLIER-ALLOCATION.v1`

`atlas_api.get_confirmed_supplier_allocation_workbench(request jsonb)` accepts the same closed read envelope with payload `{ date_start, date_end, school_ids?, states?, search? }`. Dates are inclusive and bounded to 31 days; normal UI uses one working date. Optional filters must have the declared array/string types, UUIDs and supported states; explicit null or unknown state is rejected safely. Read/write authority uses the existing Procurement capabilities and relational School/location scope rules.

Rows extend the existing allocation shape with `complete`, typed `family.source_kind`, source Confirmed Need batch/version, exact revision/decision contribution references and plural `schools`. Families shared by Schools remain searchable/filterable by any contributing School. Complete quantities derive solely from current saved Confirmed Need decisions that pass the canonical evaluator. Incomplete or ambiguous source returns `family_quantity: null` and `Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.`; generated quantities and zero are never fallback authority. Retired generation sources are excluded without deleting history. Current legacy Handoff rows remain available when no active Confirmed Need family supplies the same key.

The response also includes nullable `preparation: { service_date, confirmed_need_batch_id, expected_version, ready, allowed, blockers }`. Backend readiness requires complete current exact saved splits and eligibility. The normal preparation action additionally requires both existing release/write capabilities and active GLOBAL scope, consistent with the existing v2 Planning release command. Frontend dirty, busy and unknown-outcome conditions may only make this stricter.

`atlas_api.save_confirmed_supplier_allocation(request jsonb)` uses the normal closed command envelope, reason `CONFIRMED_SUPPLIER_ALLOCATION_SAVED`, expected Allocation Family version (`0` for a new family), and:

```json
{
  "family": {
    "service_date": "2026-09-03",
    "delivery_location_id": "<uuid>",
    "ingredient_id": "<uuid>",
    "unit_id": "<uuid>",
    "expected_source_fingerprint": "<authoritative fingerprint>",
    "expected_source_batch_id": "<uuid>",
    "expected_source_batch_version": 2
  },
  "splits": [
    { "supplier_id": "<uuid>", "allocated_quantity": "72.000000" },
    { "supplier_id": "<uuid>", "allocated_quantity": "48.000000" }
  ]
}
```

Save locks/rechecks the batch, current source, supplier evidence and family, and appends one immutable confirmed-source revision with exact contribution and split children. Positive quantities, at most six nonzero fractional places, numeric range, unique suppliers, exact total, active effective eligibility, source batch/version, fingerprint and expected family version are mandatory. It returns the family identity/revision/version and source kind plus receipt/event evidence. It creates neither Handoff nor PO. Exact replay returns the original result; conflicting replay, stale source or stale version cannot overwrite history.

Changing saved Need retains old splits as stale. A prior-ratio exact-residual proposal is advisory until explicit Apply and Save. A previously released Need without a real Handoff can receive an explicit recovery allocation without reopening the immutable Need; after a current Handoff exists, legacy Handoff allocation commands remain the source-authoritative writer.

### Atomic preparation — `PURCHASE-COMMITMENT.v1`

`atlas_api.prepare_school_catering_purchase_orders(request jsonb)` uses the normal closed command envelope, reason `PURCHASE_ORDERS_PREPARED`, expected saved batch version and payload `{ confirmed_need_batch_id, service_date }`. It requires both `confirmed_need_release.release` and `procurement.school_catering.write`, checks every source scope, and only accepts an exact single-date NEED_GENERATION batch.

One transactional backend command coordinates the existing authorized Planning release, real school-catering Handoff, allocation promotion and PO draft commands. Every child retains its own authorization and receipt checks. It can continue from already completed release/Handoff stages. A failed child, skipped date, incomplete/extra PO coverage or stale allocation aborts all newly performed child work. Retryable failures also roll back the outer receipt; unknown transport outcomes require authoritative refresh, not automatic replay. Explicit retry retains the complete original request and is discarded when date/stage intent changes.

Success returns `contract_version`, command/correlation IDs, date/batch/version, `planning_release`, `handoff`, `purchase_order_drafts`, empty blockers and warnings. It never issues official PO numbers: each supplier PO still requires its independent existing release command. PO readback failure after successful preparation locks further mutations until refresh succeeds.

### Typed lineage and compatibility

The existing four Allocation Family relations are reused. Revision source is exactly one of `CONFIRMED_NEED` (batch/version) or `PURCHASE_HANDOFF` (Handoff revision), with strict XOR. Each contribution has either exact Confirmed Need line-revision/decision IDs or an exact Handoff line-revision ID, also strict XOR. Deferred relational guards check source agreement, family identity, Unit and exact totals. Existing rows default to Handoff; historical aggregate families may legitimately contain multiple Handoff headers, while every contribution remains individually bound and the header uses the first ordered contributing Handoff revision.

Planning release and Handoff promotion recheck confirmed allocation readiness under locks. Promotion compares every-and-only actual Handoff membership, then appends a `PURCHASE_HANDOFF` successor preserving supplier IDs and quantities, with the confirmed revision as predecessor. It never recalculates or silently accepts advisory ratios. Official PO readiness, draft creation, release and defensive line guards explicitly require Handoff-source revisions. WHOLESALE remains unchanged.

All four new public functions revoke public/anon/service-role execution and grant only authenticated execution; runtime roles remain unprivileged, private tables retain forced RLS, and temporary migration SET/CREATE privileges are removed. There are no new tables, application roles, capabilities or browser table grants.

### B1 evidence boundary

The local Handoff request regression reproduces rejection of modest browser clock skew. Handoff v1 now accepts `requested_at` up to transaction time +60 seconds; malformed identity, extra payload and +61 seconds still fail. The two new commands use the same bounded tolerance; internal preparation children use backend timestamps. This is a controlled local regression, not proof of the historical Staging B1 incident's cause. No Staging or live repair was performed.

## D-044 released-PO replacement and removed-supplier currentness

`atlas_api.create_school_catering_purchase_order_replacement(jsonb)` creates or
regenerates one complete Draft replacement for one stale released supplier/date
root. The request consumes the replaced root's current released revision and
version. The Draft has direct `replaces_purchase_order_id`, no official number, and
contains every current positive split for that supplier/date, including exact School
delivery and Confirmed Need/allocation lineage. The old PO remains
`RELEASED_TO_SUPPLIER` while the Draft is reviewed.

The existing release command recognizes replacement roots. It locks and rechecks
both roots and current exact allocation, assigns a new official number, releases the
complete replacement, and atomically marks the predecessor `SUPERSEDED`. Old and new
numbers, content, revisions, and exports are preserved. Supplier-level total equality
does not imply currentness when School contribution membership changes.

The PO read derives `CURRENT | REPLACEMENT_REQUIRED | CANCELLATION_REQUIRED` plus
overall `procurement_current`. If a supplier has no positive current allocation,
replacement creation returns `CANCELLATION_REQUIRED`; the old PO stays released and
active, no zero-line document is created, and Procurement/PXK remain blocked. This
contract adds no cancellation API. After D-044, the exact platform catalog contains
112 private forced-RLS tables, 31 capabilities, 111 physical `atlas_api` functions,
and 110 authenticated browser-callable functions; the non-callable extra function
is the private predecessor PO-read implementation retained for compatibility.
