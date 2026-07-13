# Atlas Operations Workbench Requirements

**Status:** TASK-002G approved source-of-need prototype direction
**Scope:** React + TypeScript, static/local fixtures only

## Product model

Atlas is a compact daily operations workbench, not a presentation dashboard. Each daily page makes an operational decision, owns a work object, exposes state and exceptions, then hands a defined output to the next workspace.

## OPS v1 source-of-need model

Ingredient needs are generated from weekly menu, attendance / portions, direct ingredient requests, pantry / internal needs, recipe/BOM, and actual-need override / manual adjustment. The prototype exposes these sources before ingredient aggregation so each line can answer where it came from and what changed.

## Corrected daily workflow

0. **Bảng điều hành**
1. **Nguồn kế hoạch**
2. **Tổng hợp & xác nhận nhu cầu**
3. **Lập kế hoạch mua hàng**
4. **Phát hành chứng từ**
5. **Nhập kho & xử lý chênh lệch**

## Release workspace model

The release workspace has local-only tabs for **Đơn đặt NCC / PO**, **Phiếu xuất kho**, **Phiếu nhận hàng**, and **Đối chiếu chứng từ**. Phiếu nhận hàng is a pre-issued warehouse checklist/form, not an actual receiving result. Actual receiving remains in **Nhập kho & xử lý chênh lệch**.

## Traceability and table placement

Every line should help answer: where did this need come from; what changed; who confirmed it; what quantity became official; what document was generated; what was handed off; what exception happened; and who owns the next action. Trace/source fields stay left, operational quantities and statuses stay centre, and people, ownership, evidence, and confirmation metadata stay at the far right.

## Prototype import/export boundary

Atlas may display source, import, export, file, and document states. It must not perform real import/export, document generation, backend writes, or production-data updates.

OPS v1 is the business-behaviour reference, not the UI reference. Atlas preserves its operational patterns: actual-need review, supplier allocation, controlled document release, supplier-linked receiving, and visible exception handling. It consolidates Retool fragmentation into five workspaces rather than separate screens for customer, route, supplier coordination, documents, and discrepancy follow-up.

## Page responsibility map

| Page                        | Work object                                      | Required fields / states                                                                                                                                               | Handoff and exceptions                                                                                                                  |
| --------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Bảng điều hành              | Exception queue                                  | unentered/confirmed/adjusted need, supplier gap, release gap, PO-dispatch delta, late/short/wrong/damaged delivery                                                     | Routes each exception to its owner; surfaces affected recipient, kitchen, and route.                                                    |
| Lập nhu cầu                 | Requirement / actual-need line                   | service date; merged **Đơn vị nhận / Điểm giao** (recipient + destination context); dish, ingredient, unit, calculated, actual, variance, source, confirmation, reason | States: Chưa nhập thực tế, Chờ xác nhận, Đã xác nhận, Đã điều chỉnh, Cần rà soát. Confirmed actual need goes to allocation and release. |
| Lập kế hoạch mua hàng       | Supplier allocation                              | service date, affected recipient/destination, ingredient, confirmed need, allocated, remaining, supplier, role, allocation and delivery notes                          | States: Chưa phân công, Phân công một phần, Đã phân công đủ, Lệch số lượng, Cần NCC dự phòng. Produces PO-ready allocations.            |
| Phát hành đơn / phiếu       | Supplier PO, dispatch order, reconciliation line | supplier, date/time, ingredient, allocated/issue quantity, recipient, codes, print/export status, revision warning, confirmed need, PO, dispatch, delta                | Draft / Ready to release / Released / Needs revision / Mismatch / Reopened. Hands released documents and discrepancies to receiving.    |
| Nhập kho & xử lý chênh lệch | Receiving line / exception                       | supplier, PO/allocation reference, ingredient, affected destination, ordered/expected/actual quantity, exception, downstream impact, next action, evidence placeholder | Types: Thiếu hàng, Giao trễ, Sai hàng, Hàng hư hỏng, Thay thế ngoài kế hoạch, Nhận đủ. Routes escalations to Thu mua / BGĐ.             |

## Required actions

- Lập nhu cầu: enter, save, confirm, reopen, inspect adjustment history.
- Lập kế hoạch mua hàng: default allocation, split supplier, balance, remove allocation, save, prepare PO.
- Phát hành: release PO, release dispatch order, print/export placeholder, reopen, view delta, record re-release reason.
- Nhập kho: record actual receipt and discrepancy, mark supplement/replacement, notify purchasing/management, attach evidence placeholder.

These controls are local prototype feedback only; they do not create authoritative facts.

## Release gates

Before release, a draft may change allocation, quantity, delivery time, recipient/destination context, notes, and print/export preparation. A release gate requires the relevant allocation and reconciliation view to be visibly ready.

After release, the prototype presents the document as locked. A correction requires **Needs revision** or **Reopened**, a recorded reason, and re-release. In production this must become an immutable released snapshot with a revision/cancellation/compensating action, never a silent rewrite. This prototype has no real command, document generation, persistence, locking, or audit record.

## Traceability model

Atlas presents one visible operational trace chain: **Nguồn → Xác nhận nhu cầu → Phân bổ NCC → PO → Phiếu xuất → Nhập kho → Ngoại lệ**. A static Trace ID, for example `OPS-2026-0714-MA-GAO-001`, is repeated on related fixture lines so staff can follow the same requirement across workspaces.

| Page                        | Trace responsibility                                                                                                                                                |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bảng điều hành              | Makes exception source, Trace ID, affected object, owner, next step, and exception age visible.                                                                     |
| Lập nhu cầu                 | Records fixture-level source, actual-entry and confirmation roles, rationale, and procurement handoff; Hàng đặt riêng remains a queue/filter within this workspace. |
| Lập kế hoạch mua hàng       | Keeps the confirmed need and its Trace ID visible across split supplier allocations, including remaining quantity and delivery note.                                |
| Phát hành đơn / phiếu       | Reconciles the confirmed need, PO, and Phiếu xuất quantities, references, delta, release state, revision reason, and release version.                               |
| Nhập kho & xử lý chênh lệch | Connects expected versus actual receipt to PO/allocation references, evidence status, exception owner, affected destination, and next action.                       |

The compact Trace Drawer is static and local only. It demonstrates how the chain can be inspected, but it does not create audit records, documents, releases, commands, backend writes, or real event history. A future backend implementation must preserve the chain with immutable events and released snapshots; that is explicitly out of scope for this prototype.

Signature and accountability fields are placed at the far right of operational tables. Trace/source fields stay left; operational quantities and statuses stay center; people, ownership, evidence, and confirmation metadata stay rightmost.

## Supporting governance

Customers/schools, ingredients/units, and suppliers/conditions are supporting data. Recipe Governance is one governance workspace for dish/recipe selection, effective BOM, scope, active/locked status, proposed add/replace/adjust/remove/swap action, effective date, impact preview, and history. It is not a daily workflow page.

## Scope boundary

In scope: Vietnamese workbench UI, compact tables and queues, status chips, static fixtures, local interaction feedback, and prototype documentation/tests.

Deferred: backend or Supabase integration and writes; authoritative calculations; Retool integration; credentials or production data; real release/document generation; inventory accounting; recipe CRUD/change-order command; driver, school/kitchen confirmation, QA, payment, and invoice workflows.
