# Purchase review, confirmation, and release

Status: Product design approved by PURCHASE-REVIEW-CONFIRM-RELEASE-01; implementation design recorded 2026-09-03.

Base: `93af319d3a9e133614e2221202c114c0d586018e`. Scope: connected school-catering Planning and Procurement only.

## Operator contract

1. Print generated Need with provisional supplier suggestions (`In bản dự kiến`).
2. Review/correct the paper manually.
3. Enter and Save Confirmed Need.
4. Enter and Save Confirmed Supplier Allocation.
5. Prepare official drafts and `Phát hành cho NCC`.

The worksheet prominently says `DỰ KIẾN — CHƯA XÁC NHẬN`. It has no official PO number and is not a Purchase Order. Supplier-oriented groups retain School, delivery location, Ingredient, Unit, exact generated quantity, unresolved recommendations, and manual correction space.

This approved task supersedes the Handoff-before-allocation ordering in the 2026-08-31 school-catering connected design and the normal next-navigation emphasis of D-037. It does not change domain ownership, the three-stage Atlas baseline, or wholesale PA-05E.

Generated recommendation is a read model, never an operator decision. There are no provisional Allocation Family revisions, assignments, Handoffs, POs, receipts, or acceptance events. Confirmed Need is a Planning decision; Confirmed Supplier Allocation is a Procurement decision; released PO is the supplier commitment.

## Audited reuse and boundaries

Reuse the four existing `school_catering_allocation_*` relations and their stable key `(service_date, delivery_location_id, ingredient_id, unit_id)`. Reuse supplier eligibility and unique-lowest-priority semantics, exact six-place quantity/twelve-place ratio calculations, advisory residual-closing rebalance, receipts, events, optimistic concurrency, and immutable revisions.

Retain `school_catering_family_projection` as the Handoff-only projection. Official PO readiness, creation, currentness, and release additionally require a `PURCHASE_HANDOFF` revision explicitly. Preserve released-only PDF/XLSX guards and immutable numbering/history.

Reuse `SupplierSplitPanel`, focus restoration, currentness/read-intent protection, and authoritative post-command reload. Do not reuse frontend Need totals typed as JavaScript numbers as export authority.

The user subsequently requested XLSX based on the v1 Retool JavaScript exporter. Read-only inspection found `E:/Project/OPS/Retool Version/Feb 27 - 26/OPS - Lên đơn, Đặt hàng.zip`, entry `lib/js_exportPOZip.js`, SHA256 `E7682B3D66FC445B5C06CF58FAB42FBB9D4D67CA0B05C733B663BF4B0385FA97`. This is the February snapshot, not the separately recorded July export. The preview reuses its `Tổng` and `Chi tiết` views, Times New Roman, A4 portrait, repeated rows1–9, supplier bands, school/location bands, borders and correction space. Adaptation: one selected-date XLSX with supplier sections instead of a ZIP of official supplier POs; preliminary titles replace official PO titles; quantities remain exact text rather than Retool rounding; no invented item codes, address or logo. Wider quantity/note columns accommodate exact values and handwritten corrections. Existing released-PO exporters are unchanged.

## Read contracts

Add separate `jsonb` shaped reads:

- `get_generated_purchase_review`, contract `PURCHASE-REVIEW.v1`, exact `service_date`.
- `get_confirmed_supplier_allocation_workbench`, contract `CONFIRMED-SUPPLIER-ALLOCATION.v1`, bounded date scope compatible with the current workbench filters.

Generated review uses current authoritative Need Generation release evidence only. It returns exact decimal strings and typed source IDs, School/delivery/Ingredient/Unit display facts, eligible suppliers, unique-best recommendation or unresolved warning. It is stable/read-only and independent of saved or unsaved confirmed quantities. Tied priorities and missing eligibility never select an arbitrary supplier or invent a split.

Confirmed projection uses current saved decisions only, including D-040 carried-forward authority through `planning_contract_02b_decision_authorizes_revision`. Canonical RMVP-06 evaluation governs completeness/currentness. Missing/unreviewed decisions yield `Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.` and no Save authority; never substitute generated/proposed quantities. Positive families aggregate exact confirmed quantities. Historical accepted splits remain visible when stale.

Source fingerprint is deterministic and lifecycle-neutral: exact batch identity, current line/revision/decision IDs, contribution membership and quantities. The source batch version is separately retained as acceptance evidence and checked on Save. Planning Release advances the batch version by three without changing its decision: this alone must not invalidate promotion. The release's immutable validation/approval evidence must match the previously accepted saved facts.

## Revision and contribution lineage

Existing family revisions are classified `PURCHASE_HANDOFF` by an additive non-null default; their existing Handoff IDs/history are not rewritten. Add `source_kind`, `source_confirmed_need_batch_id`, and `source_confirmed_need_batch_version`. Relax Handoff ID nullability only with an explicit CHECK:

- `CONFIRMED_NEED`: batch ID/version present and positive; Handoff ID absent.
- `PURCHASE_HANDOFF`: real Handoff revision present; confirmed-source header fields absent.

Add exact Confirmed Need line-revision and decision references to contributions. Their CHECK/XOR admits either a Handoff line reference or a confirmed line-revision/decision pair, never both/neither. Unique per-revision source membership and relational guards ensure the source kind, family key, Unit, lineage and exact contribution/split totals agree. Historical rows and predecessors remain immutable.

No new allocation tables, domain capabilities, public table privileges, lifecycle states, major dependencies, or frontend business-rule engines.

## Confirmed allocation command

Add `save_confirmed_supplier_allocation`, contract `CONFIRMED-SUPPLIER-ALLOCATION.v1`, reason `CONFIRMED_SUPPLIER_ALLOCATION_SAVED`. Payload contains the existing family identity/fingerprint, expected source batch/version, and complete positive exact supplier split set. Expected aggregate version is zero for creation, otherwise the authoritative family version.

The backend rechecks authenticated Actor, active Procurement write capability and relational scope; locks source and supplier evidence deterministically; rejects stale source/version, incomplete Need, duplicate/ineligible suppliers and imbalance. It appends an immutable confirmed-source revision, contributions and splits, advances the root once, records receipt/domain/audit events, and returns durable IDs/readback. Exact replay returns the same result. Recommendations/rebalance remain advisory until this explicit Save.

Keep existing Handoff-sourced public Save/recommendation command contracts intact. They cannot convert a confirmed-source revision to committed authority without the real Handoff promotion checks.

## Commitment and promotion

Planning's `Tiếp tục phân bổ NCC` is navigation only, carries the working date, and invokes no command. Procurement retains only allocation and order modes, without exposing an internal lifecycle wizard.

Before release, every positive confirmed family must have a current exact allocation whose fingerprint and source lineage match and whose suppliers remain eligible. Backend release readiness and a fail-closed transition guard cover existing v1/v2 Planning release paths. Vietnamese blocker: `Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.`

The real Handoff command repeats readiness against the released snapshot and atomically appends `PURCHASE_HANDOFF` successor family revisions with the same exact supplier quantities. It does not mutate predecessor decisions or silently rebalance. Promotion checks exact confirmed contribution membership against Handoff lines, not just total quantity. A stale, incomplete, changed or ineligible allocation aborts Handoff creation and promotion together.

Add `prepare_school_catering_purchase_orders`, contract `PURCHASE-COMMITMENT.v1`, for the operator's draft-preparation action. It coordinates existing authoritative Planning release, real Handoff/promotion, and PO draft commands inside one transaction for the selected date. Child requests are backend-derived with distinct command IDs and server time; each child reauthorizes the same Actor. The outer receipt makes replay exact. Any child failure rolls back the preparation transaction and returns natural blockers. Already completed authoritative stages are read and checked before continuing; no automatic network retry or inferred success. Existing historical Handoff-only dates remain readable and use their existing current allocation path.

Released PO amendment/correction remains excluded. Unrelated dates/Schools and all wholesale flows remain unchanged.

## B1 investigation

No raw Staging B1 failed request is retained in this checkout. The audited UI envelope matches Handoff v1, but its browser timestamp can be later than the server transaction timestamp, which Handoff v1 strictly rejects. The current local verifier subtracts one second and therefore cannot expose that mismatch. Reproduce with the real request shape and controlled positive clock skew before modifying validation. If reproduced, apply the established bounded 60-second Planning tolerance to this Handoff path only, preserving original-request receipt identity and server-owned timestamps. Do not claim this proves the historical Staging incident without its raw evidence; do not repair Staging.

## Security and migration operation

Retain private schemas, forced RLS, least-privilege runtime owners, explicit EXECUTE revocations, empty search paths, JWT-bound human Actor/scope checks and immutable audit. Reads use Planning/read runtimes and existing read permissions; allocation uses Procurement read/write; commitment requires existing Planning release and Procurement write. Private cross-domain helpers expose narrowly shaped evidence or bounded promotion, not generic table-write authority.

Apply version-controlled migrations only to disposable/local development for this task. No live OPS, Retool, hosted Staging, deployment or production writes. Rollback after confirmed-source rows exist is forward-only: do not restore NOT NULL Handoff references or delete new history. Revert application activation only with compatible reads retained; a later approved migration handles any schema reversal.

## Acceptance and verification

First-class synthetic cross-stage case: generated 100; preview writes nothing; Save confirmed 120; Save A72/B48 with no Handoff/PO; change to125 and retain stale72/48; commitment blocked; explicitly Save75/50; release/Handoff promotes exact75/50 and retains predecessor; drafts/released snapshots preserve supplier quantities, official numbers and immutability; unrelated School/date unchanged.

Also prove100 with60/40 becomes stale after120; advisory72/48 never mutates persisted splits. Cover no/tied eligibility, incomplete Need, duplicate suppliers, imbalance, source/version conflicts, replay, anonymous/scope denial, lineage XOR, promotion failure, and Handoff-only official PO gating.

UI tests preserve PR249/250 behavior, exact strings/two-decimal Confirmed Need editing, reasons/notes, hidden dirty rows, readback/unknown-outcome lock, participants-only editing and focus restoration. Browser QA uses synthetic/local populated data at1366×768,1920×1080,900×900,650×900,360×800 across generated review, confirmed Need/allocation, stale allocation, draft and released PO; no page overflow or product-console errors.

Run targeted pgTAP, existing affected Confirmed Need/Handoff/allocation/PO regressions, focused Vitest, typecheck, touched-file Prettier and diff whitespace checks. GitHub Actions owns broad validation. Deliver one unmerged Draft PR with exact SHAs, migration/API summary, test/QA evidence and explicit blockers.

## Design self-review

The two read-only audits were synthesized before implementation. This design distinguishes all four authority levels, preserves existing immutable rows and source-qualified official PO behavior, handles lifecycle-only version movement, and supplies recovery without extra operator steps. All 30 task sections map to the implementation plan and verification record; no hosted mutation is authorized.
