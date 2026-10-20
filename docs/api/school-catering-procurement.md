# School-Catering Procurement API Contract

## K3 Allocation read reconciliation — 20 October 2026

The continuation's forward migration
`20261020022939_atlas_k3_ordinary_allocation_blocker.sql` preserves the ordinary
incomplete-Need instruction while retaining K3's corrected-source blocker. It
changes only the existing shaped-read message branch, with no writer, privilege,
history or timeout change. The connected single-School 100 → 110 → 90 path passes;
the shared-School/two-Supplier PO/PXK read timeout remains a separate blocked
acceptance gate recorded in the [K3 task](../implementation-tasks/TASK-ATLAS-C-K3-OPERATOR-INTEGRATION-01.md).

Authority: [Owner decision #400](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6279713889). The existing `get_confirmed_supplier_allocation_workbench` uses K2's per-family source proof after a genuine post-release correction. Changed families expose the authentic current `CONFIRMED_NEED` proposal for explicit acceptance; untouched families retain applicable original `PURCHASE_HANDOFF` identities and contributors. Handoff rows in this correction branch do not expose CN command bindings. Ordinary released rows retain their existing CN lineage metadata. Actual contributing Schools remain associated with the family independently of current default-location metadata.

`BALANCED` requires compatible typed source identity/version, exact contributor revision/decision or Handoff line membership, controlled Unit, canonical fingerprint and quantity, and eligible balanced Supplier splits. A later valid correction remains editable while the previously accepted allocation is stale. Missing or invalid correction evidence blocks actions; equal totals cannot establish currentness. Post-release Preparation advisory uses the canonical whole-date allocation frontier, independent of UI filters, and cannot use raw CN/default readiness to override `SOURCE_CHANGED` or an existing cancellation obligation. Ordinary pre-release Preparation/default behavior remains unchanged. These are advisory reads: unchanged transactional writers recheck source, authorization, locking, coverage and receipts.

Migration `20261020004031_atlas_k3_allocation_source_read_parity.sql` amends only the existing Allocation read and Preparation advisory. No new function, privilege, persistence, status, writer, receipt, lock, historical source identity or PO snapshot is introduced. A reviewed forward rollback may restore the prior read definitions without changing operational history; it must keep correction entry fail-closed until a coherent read is restored.

## K2 corrected Need source amendment — 19 October 2026

Authority: [Issue #400 Owner K2 decision](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6263269007), implemented in the bounded [K2 task record](../implementation-tasks/TASK-ATLAS-C-K2-CORRECTED-NEED-PO-01.md). This supersedes #406's proposed receipt certificate for the closed corrected-Need branch. Command receipts retain idempotency, recovery and audit meaning; a command name, completed outcome or response never supplies missing source authority.

An authentic `RMVP-05.v3` post-release correction retains the immutable original Need release and Handoff. The existing explicit Supplier Allocation Save accepts exact current Need contributions, quantities, Suppliers and notes. Corrected Preparation verifies that source and the complete supplier/date frontier without another Planning release or a fabricated Handoff successor. Unchanged families retain applicable original Handoff identities. Affected families use existing typed `CONFIRMED_NEED` contributions; each contribution retains the existing source XOR.

The existing complete replacement command creates or regenerates the whole Supplier/date Draft. The existing explicit `release_school_catering_purchase_order` remains the final commitment boundary. It independently rederives original validated release/Handoff ancestry, immutable human revision/decision chains, exact current theoretical membership, Unit/policy/quantity evidence, accepted allocation membership and the complete date document frontier. Live upstream preflight is required even when captured facts and RMVP-06 evaluation still match. Equal quantities alone confer no authority. Invalid corrected evidence fails closed and cannot restore the old Handoff as current authority.

Release locks the corrected source before supplier/date uniqueness and allocation locks, rechecks the current Actor and whole represented School/location scope, and serializes Supplier status and relevant authorization changes. The releaser needs existing Procurement write authority; the previous authentic K1 Save already established Planning authority, which is not reauthorized against the historical Actor's current roles. Existing predecessor/version checks and atomic new-number release/old-root supersession remain. Original numbers, quantities, frozen School/item/note snapshots and exports are retained through repeated replacements. Historical typed-source validation uses immutable ancestry and the accepted source version, independently of later working currentness.

A later Need or allocation change invalidates an old Draft. Missing Supplier coverage blocks release even when the target Supplier's own Draft remains current. A removed Supplier retains `CANCELLATION_REQUIRED`; no zero PO or implicit cancellation is introduced. Ordinary initial Handoff release behavior remains. K1 writer/readback activation, staff enablement, PXK issuance, Warehouse and document styling are not expanded by this backend checkpoint.

Verification uses real authenticated commands in disposable databases, including 100 → 110 → 90, multiple Suppliers and shared Schools, R/B/H evidence, scope/permission denial, forged receipt alone, missing Supplier coverage, replay, UNKNOWN recovery, rollback and actual competing transactions. No hosted install, merge or deployment is authorized.

## B2 optional Ingredient code amendment — 19 October 2026

Authority: [Owner decision](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389#issuecomment-6236671930)
and [bounded contract delta](../implementation-tasks/TASK-ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01.md).
Ingredient `document_code` is optional internal metadata. Normal and complete
replacement PO release/read/export permit a null code. Supplier outward code
remains required. `PO_DOCUMENT_CODE_REQUIRED` identifies missing/invalid Supplier
code; `PO_INGREDIENT_DOCUMENT_CODE_INVALID` identifies corrupt nonnull internal
metadata and permits correcting it or clearing it through normal Master Data.
Master-data nonnull-code validation is unchanged.

Migration `20261019014456_atlas_b2_po_ingredient_code_optional.sql` amends only
`release_school_catering_purchase_order`, `freeze_school_catering_po_line_output`
and `get_school_catering_purchase_orders`. It retains their owners, ACLs, search
paths, all required descriptive evidence, exact quantities, source guards,
whole-PO authorization, locking, numbering, receipts and replacement semantics.
`document_snapshot_complete`/`export_ready` no longer treat null Ingredient code
as missing outward evidence. Other incomplete/corrupt snapshots fail closed.

Official XLSX already hides the item-code compatibility column; official PDF
already omits it. Preserve those historical layouts, hidden code snapshots and
`DOCUMENT`/`ROW_SOURCE` metadata unchanged. New null code cells stay blank, with
no UUID or technical-code fallback. Preliminary summary removes the visible
`Mã hàng` column and gives its width to names; preliminary detail already omits
codes. Both retain preliminary labeling and no fabricated official number.
No historical rows are rewritten, no rendering-version authority is introduced,
and PXK/Dispatch/Shopping List remain outside B2.

Rollback must preserve nullable read/export compatibility for already issued
null-code POs. Reinstating the old requirement would strand valid commitments;
disable release/presentation through a reviewed forward change if needed.

## B1 three-source coverage clarification — 18 October 2026

The [approved B1 model](../implementation-tasks/TASK-ATLAS-B1-PRODUCT-MODEL-CLOSEOUT.md)
does not change Procurement arithmetic or commitment semantics. Confirmed-source
allocations consume final authorized Confirmed Need, then promote through the
real Handoff into exact Supplier splits and released PO lines. R20+B5+H3 yields28
when accepted unchanged; an explicit reasoned confirmation30 yields30, retaining
the original three contributions and separate human +2 decision. A Pantry-only
Ingredient B5+H3 yields8 without a fabricated Recipe contribution. Shared-location
School and supplier coverage reconcile independently; R+B is never a new source.

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

### Purchase Preparation release performance — 2026-10-13

Migration 105 preserves the 20-second Purchase Preparation timeout and the
existing role and transport budgets. Confirmed-source grouping carries the
canonical evaluation outcome rather than duplicating the entire evaluation in
each sort tuple. Allocation locking gathers persisted batch supplier splits in
one grouped query, retaining supplier-evidence locks before family-root locks
and the existing deterministic ordering. The following fresh readiness check
still proves exact current source, quantity, fingerprint, balance and eligibility.

Default materialization shares backend-resolved source evidence with private
readiness overloads only within that command. Supplier priority evidence remains
locked before defaults are generated, and the full current source universe is
refreshed after writes or waits. Cross-batch ambiguity checks and final strict
persisted readiness remain mandatory. Neither overload is callable by browser
roles; no browser payload becomes authoritative source evidence. Release,
validation, approval, membership guards, Handoff promotion, PO immutability,
replay and atomic rollback retain their contracts.

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

## Cutover authorization amendment — 14 October 2026

ATLAS-AUTH-SCOPE-ALIGNMENT-01 corrects authorization plumbing without changing Procurement business grouping or commitment semantics.

- `get_generated_purchase_review` requires the documented `procurement.school_catering.read` capability. `confirmed_need_review.read` alone grants no access. Rows remain filtered by the existing relational School/customer/delivery-location predicate.
- A Supplier/date School-catering PO is one authorization object. A non-`GLOBAL` actor may read or release it only when the Actor's active relational scopes cover **every** School/delivery-location contribution represented by that whole PO. If any constituent scope is missing, the PO is hidden from the shaped read and release returns `SCOPE_DENIED`; no partial/redacted PO and no partial commitment is produced.
- `GLOBAL` remains valid. `procurement.school_catering.read` / `write`, existing PO currentness, idempotency, supplier eligibility, numbering, immutable snapshots and replacement rules are unchanged.
- `prepare_school_catering_purchase_orders` remains a complete single-date batch command and retains its existing `GLOBAL` requirement. This amendment does not make Preparation relationally scoped.

The whole-PO predicate is private backend support derived from the PO's exact current revision → canonical positive supplier/contribution overlap → captured Confirmed Need customer/School/location lineage. It uses the official document breakdown, requires complete quantity coverage on every line, and excludes zero-overlap Schools from that supplier's document scope. `SCHOOL` authority matches the represented School ID exactly, including when Schools share a default location; explicit Customer or delivery-location scope retains its corresponding coverage. It adds no authored authority, role, capability, scope kind or browser table access.

## Implemented requests and responses

`release_school_catering_purchase_handoff` uses the normal command envelope, reason `SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED`, expected Confirmed Need version, and payload `{ confirmed_need_batch_id }`. It returns Handoff root/revision/line/reference IDs, new version, event/audit IDs and replay status. First release creates a BASE revision; a corrected release reuses the root and creates a SUPERSEDING revision. Only released NEED_GENERATION snapshots qualify.

`save_school_catering_supplier_allocation` uses reason `SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED`, the expected family version, and payload `{ family, splits }`. The family contains service date, delivery location, ingredient, unit and expected source fingerprint. Each split contains one supplier and positive allocated quantity. The server requires unique suppliers, exact total equality, active effective eligibility and a current fingerprint; it calculates ratios and persists immutable revision, contribution and split history.

`confirm_school_catering_supplier_recommendations` uses reason `SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED` and payload `{ candidates }`. Every candidate includes the family key, expected version `0`, and expected fingerprint. The response separates atomically confirmed candidates from safe skips such as stale/edited, changed source, missing eligibility or ambiguous priority.

`get_school_catering_procurement_workbench` accepts payload `{ date_start, date_end, school_ids, states, search }` for a bounded date range. Rows include display fields, authoritative quantity and contributions, current splits and ratios, ordered eligible suppliers, an uncommitted unique recommendation, state (`UNALLOCATED`, `BALANCED`, `STALE_REBALANCE_AVAILABLE`, `NEEDS_REALLOCATION`, or `BLOCKED`), an exact-residual prior-ratio rebalance proposal when safe, blockers/warnings, allowed actions and disabled reasons.

All precision-sensitive workbench response values are JSON strings at the public boundary: `family_quantity`, every `contribution_quantity`, every allocation/recommendation/rebalance `allocated_quantity`, and every `split_ratio`. Quantities use six fractional digits and ratios use twelve. Internal PostgreSQL calculations, equality checks and source fingerprints remain exact numeric operations.

`create_school_catering_purchase_order_drafts` uses reason `SCHOOL_CATERING_PO_DRAFTS_CREATED`, sentinel expected version `1`, and payload `{ date_start, date_end }` for an inclusive range of at most 31 days. A date is ready only when every current Handoff-derived Allocation Family is balanced, source-current, and assigned only to active/effective eligible suppliers. Ready dates create or regenerate one DRAFT lineage per supplier/date; blocked dates are skipped atomically by date with explicit blockers. Regeneration creates successor revisions and never rewrites history or released roots.

**20 October functional stabilization:** Draft creation/regeneration accepts the same maximum +60-second browser `requested_at` skew as PO release; +61 seconds and malformed envelopes still fail. Request identifiers, receipt semantics, source checks, authorization and command budgets are unchanged.

`release_school_catering_purchase_order` uses reason `SCHOOL_CATERING_PO_RELEASED` and payload `{ purchase_order_id, expected_purchase_order_revision_id }`; callers cannot provide the supplier, status, actor, or document number. Under deterministic locks, the server revalidates root/revision versions, current family/split evidence, supplier activity, and effective eligibility. Success creates an immutable `RELEASED_TO_SUPPLIER` successor and the server-only number `PO-<YYYYMMDD>-<first 16 uppercase PO UUID hex characters>`.

Its browser-facing command envelope accepts `requested_at` at most 60 seconds ahead of server transaction time; malformed timestamps and larger positive skew return `VALIDATION_FAILED`.

`get_school_catering_purchase_orders` accepts payload `{ date_start, date_end, supplier_ids, statuses, search }`. It returns supplier/date roots, the current revision/version, multi-destination lines and exact family/split sources, server-derived stale/release/export state, the official number only after release, blockers/warnings, and backend-owned allowed/disabled actions.

The 20 October read amendment adds optional `line.unit.unit_name`: the authoritative current name on Drafts and null on released/superseded documents. The operator UI uses this name for technical imported Draft Unit codes. Future releases also capture optional `line.unit_name_snapshot` through the existing backend freeze trigger under the existing Unit locks. This nullable field is immutable, including historical nulls. A missing/blank optional name stays null and introduces no release prerequisite. UI and official XLSX/PDF use the frozen name for a technical Unit code; normal Unit codes remain unchanged. Controlled Unit identity, exact quantities and `unit_code_snapshot` remain unchanged. Existing released documents receive no backfill and never fall back to a mutable name; legacy technical codes without a captured name retain their original evidence.

The operator's **Phát hành tất cả PO** action sequences the existing single-PO release command across eligible loaded Drafts, independently of search. Each selected ID/version/revision remains fixed, is checked against fresh readback before its send, and retains its own request/receipt. Each success requires authoritative readback. Failure, changed next authority or UNKNOWN stops the batch with partial-progress guidance; no automatic retry, replacement creation or allocation acceptance occurs. An explicit retryable failure retains only the original failed request under the existing retry control.

Rollback: the clock and Draft-read migrations replace existing function definitions only. The subsequent Unit-name migration adds one nullable snapshot column, amends existing capture/read/guard functions and extends the existing line snapshot trigger. A reviewed forward rollback may restore the strict Draft timestamp predicate or remove new presentation; it must retain the Unit-name column and all captured history, owners, ACLs, security modes/search paths and receipts. The UI tolerates absent Draft `unit_name` with missing Unit guidance and absent official `unit_name_snapshot` with the original frozen code. No released-document rewrite is needed. Reapplying the clock amendment outside the migration ledger fails closed instead of widening the skew window again.

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

Authority: the explicitly approved [bounded design](../superpowers/specs/2026-09-03-purchase-review-confirm-release-design.md), amended by the product-approved preferred-Supplier default correction on 2026-10-12. The normal operator path is generated paper review → saved Confirmed Need → derived preferred allocation or explicit allocation override → atomic commitment preparation → independent PO release. This changes no module boundary, lifecycle vocabulary, Warehouse behavior or released-PO amendment policy.

### Generated review — `PURCHASE-REVIEW.v1`

`atlas_api.get_generated_purchase_review(request jsonb)` is a read-only, authenticated, scope-filtered API. Its closed envelope is `{ contract_version, requested_by_auth_subject, correlation_id, payload: { service_date } }`. It requires the existing `procurement.school_catering.read` capability and reads current released Need Generation evidence, never saved allocation or PO quantities.

Response includes `success`, `contract_version`, `service_date`, `document_label: "DỰ KIẾN — CHƯA XÁC NHẬN"`, `rows`, `blockers` and `warnings`. Rows identify date, School, delivery location, Ingredient and Unit, exact `family_quantity`, eligible suppliers, nullable recommendation and warnings. Unique lowest non-null effective priority produces an uncommitted suggestion; absent eligibility, absent priority or a tie remains unresolved. Reads and XLSX export create zero allocation, Handoff, PO, receipt or acceptance-event facts.

The separate preliminary XLSX uses the inspected Retool v1 `lib/js_exportPOZip.js` print geometry, Times New Roman typography, supplier/School bands and two sheets (`Tổng`, `Chi tiết`). Its single-date workbook is deliberately not the official supplier ZIP. Quantities remain exact text, correction space remains blank, unresolved suppliers are explicit, and no official document number or invented item code appears. Existing released PO XLSX/PDF exporters and their source guards remain unchanged.

### Confirmed allocation — `CONFIRMED-SUPPLIER-ALLOCATION.v1`

`atlas_api.get_confirmed_supplier_allocation_workbench(request jsonb)` accepts the same closed read envelope with payload `{ date_start, date_end, school_ids?, states?, search? }`. Dates are inclusive and bounded to 31 days in the backend; the shared operator picker permits 1–7 consecutive days. Reads send the exact selected range. Rows retain their own service date and family identity; Save uses the row's date. A multi-day read exposes no purchase-preparation authority and the UI explains “Chọn 1 ngày để chuẩn bị đơn mua.” Direct navigation carries the range into a newly opened Purchase Orders workbench; an already-open workbench retains its drafts/context with a visible notice. Optional filters must have the declared array/string types, UUIDs and supported states; explicit null or unknown state is rejected safely. Read/write authority uses the existing Procurement capabilities and relational School/location scope rules.

Rows extend the existing allocation shape with `complete`, typed `family.source_kind`, source Confirmed Need batch/version, exact revision/decision contribution references and plural `schools`. Families shared by Schools remain searchable/filterable by any contributing School. Complete quantities derive solely from current saved Confirmed Need decisions that pass the canonical evaluator. Incomplete or ambiguous source returns `family_quantity: null` and `Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.`; generated quantities and zero are never fallback authority. Retired generation sources are excluded without deleting history. Current legacy Handoff rows remain available when no active Confirmed Need family supplies the same key.

The response also includes nullable `preparation: { service_date, confirmed_need_batch_id, expected_version, ready, allowed, blockers }`. Backend preparation readiness requires every positive authoritative family to have current exact eligible saved splits or a safe deterministic preferred-Supplier default. The normal preparation action additionally requires both existing release/write capabilities and active GLOBAL scope, consistent with the existing v2 Planning release command. Frontend dirty, busy and unknown-outcome conditions may only make this stricter.

#### Product-approved preferred-Supplier default — 2026-10-12

Supplier priority is an explicit Master Data fact. A complete, current positive
Confirmed Need family with no persisted allocation revision and no blocker uses
100% of its exact quantity as a derived default only when exactly one ACTIVE
Supplier has the unique lowest non-null priority among ACTIVE eligibilities
effective on that service date. No eligible Supplier blocks; no effective
priority or a best-priority tie remains unresolved. UUID, name and row order are
never business tie-breaks. Defaults follow current master data until materialized.

`splits` remains persisted allocation evidence; `recommendation` remains separate
derived evidence. Effective presentation uses persisted splits first, otherwise
the safe recommendation, otherwise unresolved. No new persisted lifecycle state
is introduced. The workbench read creates zero allocation, Handoff, PO, receipt
or acceptance-event facts. Reading never confirms recommendations.

Normal default rows show the preferred Supplier directly, a default-priority
label, `Đủ`, and an exception action (`Thay đổi`). They require no separate
confirmation or per-row Save. Authorized operators can choose another eligible
Supplier or an exact multi-Supplier split through the existing Save command.
Persisted allocations, including supplier notes and manual splits, remain
authoritative and obey the existing stale/reallocation rules; later priority
changes never silently replace them or rewrite released PO commitments.

The 1–7 day operator range presents defaults independently for every represented
date and retains no multi-day preparation authority. The allocation table starts
with sticky sortable `Trường / điểm giao`, then `Nguyên liệu`, and defaults to
School → Ingredient order. Identical School/location names appear once; a distinct
destination is secondary text. Search, exact quantities, selection and keyboard
focus retain their existing behavior.

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

Preparation rechecks current Confirmed Need authority and Supplier eligibility
and priority under backend locks. Inside its protected transaction, it
materializes only missing safe defaults through the existing allocation writer,
then continues through strict Planning release, Handoff promotion and PO draft
boundaries. A failed child or stale source rolls back newly generated supporting
allocations together with the rest of the preparation. Browser recommendations
are never accepted as command authority. Materialization creates no separate
operator action or confirmation step. The standalone Planning release remains
write-free for Procurement and retains its persisted-allocation prerequisite.

Supplier detail Save requires a semantic difference from its derived default or
persisted manual baseline, alongside existing balance and eligibility checks.
Unchanged Open/Close writes nothing; restoring exact Supplier, quantities/splits
and normalized notes disables Save again. Recommendation/rebalance actions are
shown only when their Supplier/quantity values change the current draft.

Migration `20261012101517_atlas_preferred_supplier_default_preparation.sql` adds
five private coverage/materialization/locking/source-resolution helpers and updates the existing
preparation status, allocation persistence, allocation read and preparation
command functions. It adds no table, enum, public API, capability or browser
table privilege, and retains existing owners, RLS and hardened search paths.
A forward rollback restores those four prior function definitions before removing
the five private helpers. Accepted allocation/Handoff/PO history must be retained;
rollback must never delete materialized facts or rewrite a released commitment.

Preparation resolves the full current Confirmed Need universe after Supplier
evidence locks and reuses it for missing defaults. Each family must still have
exactly one matching source across all current batches, including incomplete
sources; batch filtering never decides a winner. One final full-universe refresh
rechecks only generated families for unique source identity, batch/version,
fingerprint and exact quantity after waits and writes. Source changes reject the
outer transaction. This is fixed work per preparation rather than one whole-date
reconstruction per family. The compatibility allocation writer delegates to the
same persistence body with normal source resolution after its existing locks.
Explicit Saves, notes, Supplier checks, revision/contribution/split lineage,
promotion and released commitments retain their contracts. The new resolved
writer is a private Procurement-owned invoker; the full-source bridge is owned
by the existing Confirmed Need runtime and grants only Procurement execution.

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
worksheet. Supplier code remains visible; the official Ingredient-code column
is hidden compatibility evidence. See the
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

Official school-catering PO release requires the participating Supplier
to have a nonblank, trimmed, single-line printable document code
of at most 200 Unicode code points. Technical V1 prefixes, UUID substrings and control
characters are invalid, including Unicode boundary whitespace such as NBSP and BOM.
Ingredient code may be null; nonnull internal metadata retains the same validity
rules. `PO_DOCUMENT_CODE_REQUIRED` is now Supplier-specific and returns a safe blocker before
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
- Line `unit_name_snapshot`: optional nullable text added on 20 October; captured only on future releases, used for technical Unit codes without changing their frozen code.
- Order `document_snapshot_complete`: derived boolean.
- `supplier.document_code` and `line.ingredient.document_code`: current Master Data
  for Drafts, frozen Supplier code/optional Ingredient metadata for released/superseded records.
- `document_export_blocker`: safe Vietnamese explanation when an official record
  lacks reproducible display evidence.

For `RELEASED_TO_SUPPLIER` and `SUPERSEDED`, existing display properties
`supplier.supplier_name`, `line.ingredient.ingredient_name` and `line.unit.unit_code`
use their frozen snapshots. Missing historical labels use explicitly missing
history placeholders, never current Master Data. Official exporters consume only
the explicit snapshots and require `document_snapshot_complete === true`.

The shaped line retains `supplier_note` from its frozen revision snapshot after current allocation notes change.

Completeness requires valid Supplier outward code, valid nonnull internal code
metadata when present, the captured Supplier name, captured Ingredient/Unit labels and
the existing complete School breakdown on every line. Incomplete or malformed
historical evidence remains readable with `document_snapshot_complete: false`,
`export_ready: false`, `allowed_actions.export: false` and
`PO_DOCUMENT_SNAPSHOT_INCOMPLETE`. The safe reason is
`Không đủ dữ liệu chứng từ lịch sử để tái xuất chính thức.` Historical rows are not
fabricated or rewritten. A Draft may display current labels, but cannot release
while current required codes are absent or invalid.

This revision adds four private helpers, five triggers and seven reviewed positive
grants, without a new table, API, capability, policy, role or browser table grant.
The current catalogue is 117 private forced-RLS tables, 121 physical APIs, 118
authenticated APIs, 672 normal policies, 336 private functions, 124 triggers and
1825 reviewed positive grants. Forward rollback retains explicit codes and all
released snapshot columns; removing or reconstructing them destroys evidence.
Supplier address semantics remain open. PXK business authority and Shopping List
V2/A+ are unchanged.

## Independent location and Dispatch snapshots

Owner task `TASK-ATLAS-DOCUMENT-SCHOOL-GROUPING-02.md` adds future-release
`cooking_location_id`, `cooking_location_name`, `cooking_location_kind`,
`cooking_location_host_school_id`, `dispatch_group_id` and `dispatch_group_name`.
Cooking compatibility aliases remain. Admin facts are locked during capture;
renaming or moving a current relationship never changes released evidence.
Historical absent/null fields are retained without backfill. PO School sections
stay separate; Dispatch packaging uses only captured membership and retains all
School/source lineage. See [explicit independent facts](school-cooking-groups.md).

### Purchase Preparation execution budget (Product decision 2026-10-13)

The authenticated role retains its 8-second infrastructure default. Only
`atlas_api.prepare_school_catering_purchase_orders(jsonb)` receives a function
`statement_timeout = '20s'`, applied by PostgREST before the RPC statement. The
operator target is a complete preparation below 15 seconds for the certified
236-family workload. Three independent fresh authenticated public-command samples
are required: all below 15s permits certification; 15–20s requires UX/performance
review; 20s or cancellation requires another bounded performance decision.
The frontend transport remains 45s and the existing lock policy remains unchanged.
Other Atlas RPCs and Need Generation's separate performance requirement are unchanged.
This budget does not relax atomicity, current Supplier authority, exact replay or
source lineage. No production function body or public payload changes.

See [Supabase timeout guidance](https://supabase.com/docs/guides/database/postgres/timeouts)
and [PostgREST timeout hoisting](https://docs.postgrest.org/en/stable/references/transactions.html#hoisted-function-settings).

### Post-release allocation read performance (migration 106)

The Supplier Allocation workbench retains its normal authenticated 8-second
budget and the existing `CONFIRMED-SUPPLIER-ALLOCATION.v1` payload. Each read
resolves its full current Confirmed Need source set once for presentation and
reuses that set when excluding duplicate historical Handoff families. Released
rows still project current Handoff facts; source precedence, canonical
currentness, scope, filters and preparation readiness are unchanged. No source
cache persists between requests, and reads create no supporting business facts.

The hosted migration-105 baseline and local migration-106 regression are recorded
in [the bounded read-performance task](../implementation-tasks/TASK-PROCUREMENT-POST-RELEASE-ALLOCATION-READ-01.md).
Hosted post-fix acceptance remains subject to Product-approved deployment.

### K3 PO/PXK statement-local read evidence

The bounded K3 recovery reuses selected PO Draft-currentness, per-document
commitment state, distinct procurement dates and per-School PXK previews within
their existing read statements. The explicitly approved shared Draft-currentness
helper resolves each exact family once across the union of expected Supplier/date
families and actual revision-line families, including historical or foreign-date
actual memberships. All original source-kind, current-revision, fingerprint,
quantity and symmetric split-membership predicates remain authoritative.

No evidence persists between statements. Public request/response contracts,
roles, grants, RLS, transactional writer bodies, immutable history and eight-second
read budgets remain unchanged.

The subsequent explicitly approved PXK amendment admits exact K2-authorized CN
contributions alongside unchanged PH families and preserves typed historical
contribution, School, location, Unit, split and released-PO coverage. A first-ever
CN-only School scope is discoverable by the existing authorized workbench read.
Missing or stale relevant CN membership blocks partial release; unrelated School
membership does not erase the requested School's Need. Whole Supplier/date PO
currentness and historical cancellation obligations still apply independently.

The Owner also approved two existing lock-helper bodies after an executed
post-preview concurrency failure. PXK locks Need sources before allocation/PO
roots. The shared source locker takes run SHARE then Need batch UPDATE, derives
corrected status under those locks, and returns the existing retryable concurrency
failure if the run identity changed while waiting. It retains existing source,
policy and line locks. The unchanged official PXK writer validates a fresh preview
under these retained locks before persisting its immutable snapshot. No new
privilege, lock framework, public API or source authority is introduced.
See the [K3 recovery ledger](../implementation-tasks/TASK-ATLAS-C-K3-OPERATOR-INTEGRATION-01.md).
