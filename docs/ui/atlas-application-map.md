# Atlas Application Map and Page Responsibilities

**Status:** TASK-002D static prototype map
**Authority:** UI information architecture for the active Atlas prototype
**Backend authorization:** None; this document does not authorize schema, RPC, or integration work.

## Active daily workflow

Atlas has exactly three active daily workflow stages:

1. **Lập nhu cầu** — review what is needed, who needs it, the service date, and the school, kitchen, or destination context together.
2. **Lập kế hoạch mua hàng** — assign suppliers and prepare supplier orders. A supplier-coordination note or status is optional only; it is not a required confirmation workflow.
3. **Nhập kho** — compare ordered and received quantities, and make shortages or discrepancies visible.

The intended handoff is **Lập nhu cầu → Lập kế hoạch mua hàng → Nhập kho**.

## Navigation model

### Tổng quan

- Bảng điều hành

### Quy trình hằng ngày

- Lập nhu cầu
- Lập kế hoạch mua hàng
- Nhập kho

### Dữ liệu hỗ trợ

- Khách hàng & Trường học
- Nguyên liệu & Đơn vị
- Nhà cung cấp & Điều kiện cung ứng
- Món ăn & Công thức
- Kiểm soát thay đổi công thức

## Supporting recipe governance

**Món ăn & Công thức** and **Kiểm soát thay đổi công thức** are supporting-data/governance areas, not active daily workflow stages. Recipe governance is upstream of **Lập nhu cầu**: recipe and BOM references can feed requirement planning but do not add another operational handoff.

The current pages are static prototypes only. Full recipe editing, recipe CRUD, change-order submission, and authoritative change-order processing are explicitly deferred. A locked recipe must be changed through a future change-order process rather than a direct base-BOM edit.

## Page responsibilities

| Page | Owner | Completion output | Explicitly does not own |
| --- | --- | --- | --- |
| Lập nhu cầu | Planning | Destination-linked requirements ready for purchase planning | supplier coordination, receiving, delivery handoff |
| Lập kế hoạch mua hàng | Purchasing | Prepared supplier order list with optional coordination note | required supplier confirmation, receipt recording |
| Nhập kho | Warehouse | Receiving comparison and discrepancy view | driver handoff, kitchen/school handoff, QA, inventory accounting |
| Món ăn & Công thức | Recipe governance | Static recipe/BOM reference | active daily workflow, CRUD, backend calls |
| Kiểm soát thay đổi công thức | Recipe governance | Static change-order concepts | change-order submission or backend command |

## Prototype fixtures and boundaries

The receiving fixture compares a Jasmine rice order of **250 kg** with a receipt of **240 kg**, exposing a **10 kg shortage**. Fixture values are illustrative only; React does not calculate authoritative results.

The UI is static prototype only. It creates no backend records, authoritative calculations, inventory accounting movements, released purchase documents, confirmations, or integrations.

Dispatch planning, driver handoff, kitchen/school handoff, QA, payment, invoice, and document generation are not active stages. Accounting remains a future reconciliation/bookkeeping consumer of source-of-truth requirement, purchase, and receiving data, not an active workflow stage.
