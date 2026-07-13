# Atlas Operations Workbench Requirements

**Status:** TASK-002G approved source-of-need prototype direction
**Scope:** React + TypeScript, static/local fixtures only

## Product model

Atlas is a compact daily operations workbench, not a presentation dashboard. It makes source, quantity, confirmation, document, exception, and ownership visible before handoff. OPS v1 is the business-behaviour reference, not the UI reference.

## Corrected daily workflow

0. **Bảng điều hành**
1. **Nguồn kế hoạch**
2. **Tổng hợp & xác nhận nhu cầu**
3. **Lập kế hoạch mua hàng**
4. **Phát hành chứng từ**
5. **Nhập kho & xử lý chênh lệch**

## OPS v1 source-of-need model

Ingredient needs may originate from weekly menu, attendance / portions, direct ingredient requests, pantry / internal needs, recipe/BOM, and actual-need override / manual adjustment. The prototype exposes the upstream source before aggregation.

## Page responsibility map

| Page                        | Work object                                                     | Required fields / states                                                                       | Handoff and exceptions                                 |
| --------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| Bảng điều hành              | Exception queue                                                 | upstream source blockers, supplier/release gaps, receiving discrepancies, owner and next step  | Routes an exception to its responsible workspace.      |
| Nguồn kế hoạch              | Weekly-menu, attendance, direct-request, and pantry source line | source status, valid/issue line, requester, purpose, confirmation                              | Supplies source facts to requirement aggregation.      |
| Tổng hợp & xác nhận nhu cầu | Requirement / actual-need line                                  | source, calculated, actual, variance, confirmation, reason, final quantity, purchasing handoff | Confirmed final need goes to supplier allocation.      |
| Lập kế hoạch mua hàng       | Supplier allocation                                             | confirmed need, allocated, remaining, supplier, role, delivery note                            | Produces PO-ready allocations.                         |
| Phát hành chứng từ          | PO, dispatch, pre-issued receiving form, reconciliation line    | PO, Phiếu xuất kho, Phiếu nhận hàng, Đối chiếu chứng từ, issue/revision state                  | Hands pre-issued forms and discrepancies to receiving. |
| Nhập kho & xử lý chênh lệch | Actual receiving line / exception                               | expected, actual, exception, evidence, downstream impact, next action, owner                   | Routes follow-up to purchasing or management.          |

## Release workspace model

The release workspace uses local-only tabs for **Đơn đặt NCC / PO**, **Phiếu xuất kho**, **Phiếu nhận hàng**, and **Đối chiếu chứng từ**. Phiếu nhận hàng is a pre-issued warehouse checklist/form, not an actual receiving result. Actual receiving remains in **Nhập kho & xử lý chênh lệch**.

## Traceability model

Atlas presents the following visible chain:

**Thực đơn tuần / Sĩ số / Hàng đặt riêng / Pantry**<br />
→ **Công thức / định lượng**<br />
→ **Nhu cầu tính toán**<br />
→ **Nhu cầu thực tế xác nhận**<br />
→ **Phân bổ NCC**<br />
→ **PO**<br />
→ **Phiếu xuất kho**<br />
→ **Phiếu nhận hàng**<br />
→ **Nhập kho**<br />
→ **Chênh lệch / xử lý**

Trace IDs identify one source-to-downstream lineage. The menu/attendance bí đỏ example, direct-request gạo Jasmine example, and pantry dầu ăn example use separate IDs; a trace ID is not reused as an unrelated source type.

Every line should help answer: where did this need come from; what changed; who confirmed it; what quantity became official; what document was generated; what was handed off; what exception happened; and who owns the next action. Trace/source fields stay left, operational quantities and statuses stay centre, and people, ownership, evidence, and confirmation metadata stay at the far right.

## Scope boundary

In scope: Vietnamese workbench UI, compact tables and queues, status chips, static fixtures, local interaction feedback, and prototype documentation/tests.

Atlas may display source, import, export, file, and document states. It must not perform real import/export, document generation, backend writes, or production-data updates. It has no Supabase, Retool, production-data, inventory-accounting, QA, payment, or invoice behaviour.
