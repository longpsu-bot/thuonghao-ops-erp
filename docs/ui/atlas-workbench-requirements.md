# Atlas Operations Workbench Requirements

**Status:** TASK-002F approved prototype direction  
**Scope:** React + TypeScript static/local fixtures only

## Model

Atlas is a compact daily operations workbench, not a presentation dashboard. OPS v1 is a business-behaviour reference only; its Retool screens must not be copied. Related Retool concepts are consolidated into coherent React workspaces.

Each daily page makes a decision, handles a defined work object, shows the relevant state and exceptions, and hands work to the next page.

## Daily workbench

| Page | Decision / work object | State and handoff |
| --- | --- | --- |
| Bảng điều hành | Prioritise operational exceptions | Routes unentered/uncertain needs, allocation gaps, release gaps, PO-dispatch mismatches, and supplier receiving failures to the responsible workspace. |
| Lập nhu cầu | Confirm actual need on a requirement line | Calculated demand → actual need → variance → confirmation; a reopened adjustment is traceable. Confirmed quantity is handed to purchase planning and release. Recipient and destination are one two-line field. |
| Lập kế hoạch mua hàng | Allocate confirmed need to suppliers | A line may be split, partially allocated, or use a fallback supplier. Allocation status leads to PO preparation. |
| Phát hành đơn / phiếu | Freeze and release controlled documents | PO release, dispatch-order release, and PO-versus-dispatch reconciliation are separate panels. Draft, ready, released, needs revision, mismatch, and reopened are visible states. |
| Nhập kho & xử lý chênh lệch | Record supplier-linked receiving result | Actual received quantity, exception, downstream impact, and next action are recorded as fixtures. Exceptions route to purchasing or management. |

## Supporting governance

Customers/schools, ingredients/units, and suppliers/conditions are supporting data. Recipe Governance is one supporting workspace for recipe selection, effective BOM, scope, locked status, proposal, impact preview, and history. It is not a daily operations stage.

## Deliberate prototype boundary

In scope: Vietnamese workbench UI, fixture data, local interaction feedback, status chips, tables, queues, and supporting-page placeholders.

Deferred: backend and Supabase integration; calculations and authoritative commands; real document generation/release; inventory accounting; Retool integration; credentials or production data; recipe CRUD/change-order command; driver, school/kitchen, QA, payment, and invoice workflows.
