# Atlas Operations Workbench Requirements

**Status:** TASK-002F approved prototype direction
**Scope:** React + TypeScript, static/local fixtures only

## Product model

Atlas is a compact daily operations workbench, not a presentation dashboard. Each daily page makes an operational decision, owns a work object, exposes state and exceptions, then hands a defined output to the next workspace.

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

## Supporting governance

Customers/schools, ingredients/units, and suppliers/conditions are supporting data. Recipe Governance is one governance workspace for dish/recipe selection, effective BOM, scope, active/locked status, proposed add/replace/adjust/remove/swap action, effective date, impact preview, and history. It is not a daily workflow page.

## Scope boundary

In scope: Vietnamese workbench UI, compact tables and queues, status chips, static fixtures, local interaction feedback, and prototype documentation/tests.

Deferred: backend or Supabase integration and writes; authoritative calculations; Retool integration; credentials or production data; real release/document generation; inventory accounting; recipe CRUD/change-order command; driver, school/kitchen confirmation, QA, payment, and invoice workflows.
