# School-Catering Procurement API Contract

## PROCUREMENT-SUPPLIER-LINE-NOTE-01 amendment

Both existing supplier-allocation commands accept an optional `supplier_note` on each
`splits[]` member. The existing public contract versions and names remain valid:
omission is `null`. A supplied value must be a string or `null`, at most 500
characters. The backend trims surrounding whitespace, converts empty or
whitespace-only text to `null`, and rejects oversize or incorrectly typed values
atomically. The note is a supplier-facing instruction for that exact supplier,
Ingredient, Unit, destination, date and immutable Allocation Family revision. It
is separate from command and revision `reason_note`.

A note-only change is a material allocation decision: Save appends a successor
revision, retains its predecessor, and leaves exact quantities, ratios, balance,
eligibility, recommendations and source fingerprint unchanged. Generated
recommendations begin with a null note. Advisory rebalance and recommendation
Apply preserve a retained supplier's note; a newly added supplier begins blank.
Confirmed Need to Handoff promotion copies each saved note into its corresponding
immutable split. Allocation reads expose `splits[].supplier_note`.

Every backend-created PO line freezes `supplier_note_snapshot` from its exact
`school_catering_allocation_supplier_split_id`. PO reads expose it as
`lines[].supplier_note`. Draft creation, regeneration, release successors and
replacement Drafts use this same source; callers cannot supply a snapshot.
Existing exact split lineage makes a Draft stale after a note-only successor.
Released and superseded line snapshots remain historical facts, including when a
later allocation carries another note. The official supplier XLSX/PDF renders the
line snapshot under `Ghi chú`; a null value prints blank. Preliminary generated
purchase review remains unchanged because no allocation note exists there.

This is an additive migration with nullable columns; historical splits and PO
lines remain null and receive no invented backfill. A forward rollback may hide
note entry or document display while retaining already accepted split and issued
PO snapshots. Dropping either column after use would destroy decision or document
history and is not a safe rollback. Forced RLS, shaped APIs, existing privileges,
and empty runtime `search_path` remain the security boundary.

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

Its browser-facing command envelope accepts `requested_at` at most 60 seconds ahead of server transaction time; malformed timestamps and larger positive skew return `VALIDATION_FAILED`.

`get_school_catering_purchase_orders` accepts payload `{ date_start, date_end, supplier_ids, statuses, search }`. It returns supplier/date roots, the current revision/version, multi-destination lines and exact family/split sources, server-derived stale/release/export state, the official number only after release, blockers/warnings, and backend-owned allowed/disabled actions.

Each newly released school-catering PO line also freezes
`school_breakdown_snapshot`: the exact contribution/supplier interval overlap grouped
by immutable School ID/name/display order and delivery-location ID/name. Entries
also freeze nullable `cooking_group_id` and `cooking_group_name` from the single
Admin-owned membership. See [School cooking groups](school-cooking-groups.md) for
the Owner-authorized amendment; historical rows are never backfilled. The grouped
quantities must sum exactly to the line `ordered_quantity`; otherwise release fails
atomically. The shaped read exposes this as `line.school_breakdown`. Official export
is fail-closed when any released line lacks a complete snapshot, including legacy
released rows created before this amendment; clients must never reconstruct released
School identity from mutable master data or location text.

Every line `ordered_quantity` is serialized as a six-fractional-digit JSON string. Clients must parse or format that exact decimal text without first coercing it through an IEEE-754 number.

## Errors, correction and tests

Safe failures include malformed requests, authentication/authorization denial, not found, stale version/fingerprint, incomplete source snapshots, imbalance, duplicate/non-positive splits, inactive or ineligible suppliers, and retryable concurrency failure. Errors must not leak private data or partially write a command.

D-042 remains blocked for WHOLESALE Handoffs. A school-catering Allocation Family plus DRAFT PO is not a supplier commitment: correction invalidates only the current Handoff revision/root state, retains all lineage and PO history, reopens Confirmed Need, and leaves the DRAFT to become derived-stale. A `RELEASED_TO_SUPPLIER` school-catering PO is a later-domain commitment and returns `BLOCKED_BY_DOWNSTREAM_COMMITMENT`; neither the Handoff nor released PO is mutated.

Verification authority includes `purchase_review_confirm_release.sql`, `purchase_handoff_clock_skew.sql`, `school_catering_handoff_allocation.sql`, `school_catering_planning_correction.sql`, `school_catering_purchase_orders.sql`, the unchanged PA-05D/PA-05E/PA-05G and issue-222 regressions, the exact 107-table/29-capability/103-API platform security catalog, and the authenticated local journey verifier.

The document snapshot amendment is additive. Forward rollback may disable the new
export surface while retaining already frozen breakdowns; dropping snapshot data is
not a valid rollback because it would destroy released-document reproducibility.

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

One transactional backend command coordinates the existing authorized Planning release, real school-catering Handoff, allocation promotion and PO draft commands. Every child retains its own authorization and receipt checks. It can continue from already completed release/Handoff stages. Preparation evaluates each current supplier independently: exact current Draft/released coverage for one supplier may coexist with another supplier at the D-044 replacement frontier, where an active stale released PO derives `REPLACEMENT_REQUIRED`. At that frontier the corrected Planning release, Handoff successor and Handoff-source allocation promotion commit, while the old PO remains released and unchanged; creating or regenerating the complete replacement Draft remains the existing separate explicit operator command. A current or stale replacement Draft may coexist only when it links directly to that active same-supplier/date released predecessor. Ordinary preparation never regenerates such a replacement Draft, while a stale or unrelated ordinary Draft remains blocking. `CANCELLATION_REQUIRED`, missing coverage, a failed child, skipped date, other invalid PO state or stale allocation aborts all newly performed child work. Retryable failures also roll back the outer receipt; unknown transport outcomes require authoritative refresh, not automatic replay. Explicit retry retains the complete original request and is discarded when date/stage intent changes.

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
contract adds no cancellation API. After the 06D-E document-output amendment, the
exact platform catalog contains 112 private forced-RLS tables, 31 capabilities, 114
physical `atlas_api` functions, and 111 authenticated browser-callable functions.
The three non-browser-callable functions are predecessor PO/PXK read
implementations retained behind shaped public wrappers.

## Released document identity closeout — PR #360

The 9 October hidden-parsing follow-up stores technical Ingredient/Unit/document
identities and released source links in hidden row columns and a very-hidden
worksheet. Frozen business codes remain visible. See the
[operational XLSX metadata contract](operational-document-xlsx-metadata.md).

Authority: the Owner's final Document System closeout retains the accepted School
bands, cooking groups, supplier notes, replacement and commitment semantics. The
forward migration is `20261009105641_atlas_po_document_identity.sql`; earlier
migrations and previously released PO rows remain unchanged.

Admin Ingredient and Supplier each own nullable explicit `document_code`, governed
by the existing Master Data create/update/read APIs. Exact imported technical
codes `v1-ingredient-1082` and `v1-supplier-53` map to document codes `1082` and `53`
using the retained legacy ID provenance. Native technical codes and UUIDs are
never outward-code authority. See the
[Master Data amendment](../architecture/rmvp-01-independent-atlas-master-data.md#document-facing-code-amendment--pr-360).

Future official school-catering PO release requires every participating Supplier
and Ingredient to have a nonblank, trimmed, single-line printable document code
of at most 200 Unicode code points. Technical V1 prefixes, UUID substrings and control
characters are invalid, including Unicode boundary whitespace such as NBSP and BOM. `PO_DOCUMENT_CODE_REQUIRED` returns a safe blocker before
issuing a number or commitment. The existing command acquires Supplier, ordered
Ingredient and ordered Unit row locks before reading the display facts, retaining
those locks through validation and capture. Existing version, source-currentness,
eligibility, scope, receipt and retryable concurrency checks remain authoritative.

Each future released header freezes `supplier_document_code_snapshot` beside the
existing `supplier_name_snapshot`. Each released line freezes
`ingredient_document_code_snapshot`, `ingredient_name_snapshot` and
`unit_code_snapshot`, retaining the existing Ingredient and Unit identities, exact
quantity, source, predecessor, supplier note and School/cooking-group breakdown.
New snapshot fields are immutable, including a historical null. Releasing a
replacement freezes current facts in its own revision; supersession preserves the
predecessor's original facts and number.

The existing shaped read adds:

- `current_revision.supplier_document_code_snapshot`: nullable text.
- Line `ingredient_document_code_snapshot`, `ingredient_name_snapshot` and
  `unit_code_snapshot`: nullable text.
- Order `document_snapshot_complete`: derived boolean.
- `supplier.document_code` and `line.ingredient.document_code`: current Master Data
  for Drafts, frozen outward codes for released/superseded records.
- `document_export_blocker`: safe Vietnamese explanation when an official record
  lacks reproducible display evidence.

For `RELEASED_TO_SUPPLIER` and `SUPERSEDED`, existing display properties
`supplier.supplier_name`, `line.ingredient.ingredient_name` and `line.unit.unit_code`
use their frozen snapshots. Missing historical labels use explicitly missing
history placeholders, never current Master Data. Official exporters consume only
the explicit snapshots and require `document_snapshot_complete === true`.

The shaped line retains `supplier_note` from its frozen revision snapshot after current allocation notes change.

Completeness requires valid outward codes, the captured Supplier name, captured Ingredient/Unit labels and
the existing complete School breakdown on every line. Incomplete or malformed
historical evidence remains readable with `document_snapshot_complete: false`,
`export_ready: false`, `allowed_actions.export: false` and
`PO_DOCUMENT_SNAPSHOT_INCOMPLETE`. The safe reason is
`Không đủ dữ liệu chứng từ lịch sử để tái xuất chính thức.` Historical rows are not
fabricated or rewritten. A Draft may display current labels, but cannot release
while current required codes are absent or invalid.

This revision adds four private helpers, five triggers and seven reviewed positive
grants, without a new table, API, capability, policy, role or browser table grant.
The current catalogue is 115 private forced-RLS tables, 118 physical APIs, 115
authenticated APIs, 663 normal policies, 332 private functions, 120 triggers and
1797 reviewed positive grants. Forward rollback retains explicit codes and all
released snapshot columns; removing or reconstructing them destroys evidence.
Supplier address semantics remain open. PXK business authority and Shopping List
V2/A+ are unchanged.
