# Atlas Application Map and Page Responsibilities

**Status:** TASK-002C prototype workflow map  
**Authority:** UI information architecture for the active Atlas prototype  
**Backend authorization:** None; this document does not authorize schema or RPC work.

## 1. Active workflow

Atlas has exactly three active operational stages:

1. **Requirement Planning** — review what is needed, who needs it, and the outbound destination. A school, kitchen, route, or other outbound target stays linked to the demand and requirement.
2. **Purchase Planning** — assign suppliers and prepare the supplier order list. Supplier coordination may be an optional lightweight status or note; it is not a separate stage and is not required for a 24-hour catering cycle.
3. **Warehouse Receiving** — compare ordered and received quantities and make discrepancies visible.

## 2. Navigation model

### Overview

- Operations Home

### Active Workflow

- Requirement Planning
- Purchase Planning
- Warehouse Receiving

### Supporting Data

- Customers and Schools
- Ingredients and Units
- Suppliers and Eligibility

### Administration

- Prototype Boundary

## 3. Page responsibilities

| Page                 | Owner      | Reads                                                    | Completion output                                               | Explicitly does not own                                          |
| -------------------- | ---------- | -------------------------------------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------- |
| Requirement Planning | Planning   | demand, destination, requirement fixtures and warnings   | destination-linked requirements ready for purchase planning     | supplier coordination, receiving, delivery handoff               |
| Purchase Planning    | Purchasing | destination-linked requirements and supplier eligibility | prepared supplier order list with an optional coordination note | required supplier-confirmation workflow, receipt recording       |
| Warehouse Receiving  | Warehouse  | prepared order list and received-quantity fixture        | receiving result and discrepancy record                         | driver handoff, kitchen/school handoff, QA, inventory accounting |

## 4. Prototype journeys

### Catering

Demand and destination → Requirement Planning → Purchase Planning → Warehouse Receiving.

### Wholesale

Direct ingredient order and destination → Requirement Planning → Purchase Planning → Warehouse Receiving.

The receiving fixture compares a Jasmine rice order of 250 kg with a receipt of 240 kg and exposes a 10 kg shortage. Fixture values are illustrative only; React does not calculate authoritative results.

## 5. Explicitly inactive areas

Driver handoff, kitchen/school handoff, QA, payment, invoice, document generation, and accounting are not active stages in this prototype.

Accounting is a future read and reconciliation/bookkeeping consumer of the same source-of-truth requirement, purchase, and receiving data. It does not own or recalculate the operational facts.

## 6. Prototype boundary

The interface uses static fixtures only. It creates no backend records, authoritative calculations, inventory accounting movements, purchase documents, confirmations, or integrations.
