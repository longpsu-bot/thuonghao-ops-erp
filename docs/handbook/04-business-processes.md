# OPS ERP Handbook
## 04 — Business Processes

**Document ID:** OPS-HANDBOOK-004  
**Status:** Baseline draft  
**Authority:** Business operating model  
**Review required:** Yes — product owner review required before implementation  

---

## 1. Purpose

This document defines the core business processes OPS ERP must support. It describes how work should flow through the company before translating those workflows into screens, database tables, or code.

The goal is to prevent the software from merely copying OPS v1 or Retool behavior. OPS ERP should encode the desired operating model.

---

## 2. Process principles

1. Business events must be traceable from source demand to fulfilment.
2. Catering and wholesale demand should converge where operationally useful.
3. Manual adjustments must be explicit and auditable.
4. Released operational documents must be protected from silent recalculation.
5. Operational staff should work from clear exception lists rather than hidden spreadsheet logic.
6. Each process must have an accountable owner.

---

## 3. Core process map

```text
Customer / School Need
        ↓
Demand Capture
        ↓
Requirement Generation
        ↓
Requirement Review and Adjustment
        ↓
Procurement Planning
        ↓
Purchase Release
        ↓
Receiving / Preparation
        ↓
Dispatch
        ↓
Delivery / Completion
        ↓
Reconciliation and Reporting
```

---

## 4. Catering process

### 4.1 Business trigger

A school or customer requires meals for a service date based on a planned menu and expected or confirmed attendance.

### 4.2 Inputs

- service date;
- school or customer;
- menu plan;
- dish selection;
- attendance or portion count;
- school type or applicable recipe basis;
- recurring school-specific recipe policy;
- one-time adjustments or substitutions.

### 4.3 Process steps

1. Plan weekly menu.
2. Confirm school and service date.
3. Capture expected attendance or quantity basis.
4. Resolve dishes to applicable recipe versions.
5. Generate ingredient requirements.
6. Apply substitutions, additions, removals, and quantity overrides.
7. Review exceptions and warnings.
8. Approve effective requirements for procurement.
9. Include approved requirements in procurement planning.
10. Dispatch and reconcile.

### 4.4 Control points

- menu completeness;
- missing recipe;
- inactive dish or ingredient;
- school-specific recipe variation;
- unusual attendance change;
- substitution without reason;
- override without audit note;
- requirement not approved before procurement release.

---

## 5. Wholesale ingredient process

### 5.1 Business trigger

A customer or school orders ingredients directly rather than receiving meals based on a menu.

### 5.2 Inputs

- customer or school;
- delivery date;
- ingredient;
- requested quantity;
- sales or issue unit;
- delivery location;
- customer note;
- internal fulfilment note.

### 5.3 Process steps

1. Capture wholesale order.
2. Validate customer, delivery date, ingredient, and unit.
3. Convert to canonical ingredient demand.
4. Review requested quantities.
5. Consolidate with other demand where appropriate.
6. Procure or allocate supply.
7. Dispatch and deliver.
8. Reconcile fulfilment and exceptions.

### 5.4 Control points

- invalid ingredient;
- unavailable supplier;
- unit mismatch;
- unusual quantity;
- late order after procurement cut-off;
- wholesale demand that must remain separate from catering demand.

---

## 6. Requirement review process

### 6.1 Purpose

The requirement review process is the operational checkpoint between demand generation and procurement commitment.

### 6.2 Steps

1. Load all effective requirements for a date or planning period.
2. Group requirements by service date, customer, ingredient, and source.
3. Display warnings and exceptions.
4. Allow authorized adjustments.
5. Validate changes through backend rules.
6. Mark requirements ready for procurement.

### 6.3 Required visibility

The reviewer must be able to see:

- source demand;
- recipe line or direct order line;
- theoretical quantity;
- adjusted quantity;
- override reason;
- substitution reason;
- final orderable quantity;
- warnings;
- release status.

---

## 7. Procurement process

### 7.1 Purpose

Procurement converts approved effective requirements into supplier commitments.

### 7.2 Steps

1. Load approved requirements.
2. Apply procurement rounding, packaging, and minimum order rules.
3. Identify eligible suppliers.
4. Assign supplier or supplier split.
5. Review purchase plan.
6. Release purchase orders.
7. Freeze released PO quantities and calculation context.
8. Track supplier confirmation.

### 7.3 Control points

- requirement not approved;
- missing supplier;
- supplier not active;
- ingredient has no supplier relationship;
- order below minimum quantity;
- rounding creates excessive quantity;
- supplier assignment changed after release.

---

## 8. Fulfilment and dispatch process

### 8.1 Purpose

Fulfilment converts procured or prepared quantities into customer-facing dispatch and delivery records.

### 8.2 Steps

1. Generate dispatch plan from approved requirements or released procurement.
2. Group by service date, customer, location, and delivery route if applicable.
3. Prepare goods.
4. Confirm quantities to dispatch.
5. Release dispatch document.
6. Deliver goods.
7. Record delivery exceptions.
8. Reconcile with procurement and demand.

### 8.3 Control points

- dispatch before procurement is ready;
- dispatch quantity differs from requirement;
- shortage;
- replacement item;
- customer-specific delivery note;
- late correction after dispatch release.

---

## 9. Correction process

Corrections must be explicit. A correction must not silently rewrite a released document.

Correction types may include:

- pre-release edit;
- post-release cancellation;
- post-release correction document;
- supplemental purchase;
- shortage record;
- substitution after procurement release;
- return or rejected item.

The exact correction model must be finalized before procurement and dispatch modules enter implementation.

---

## 10. Review questions for product owner

1. Who is allowed to approve effective requirements for procurement?
2. Can purchasing change quantities after requirement approval?
3. When exactly is a purchase order considered released?
4. Can dispatch be generated before supplier confirmation?
5. Should wholesale and catering demand always combine in procurement, or only when operationally useful?
6. What corrections are common in daily operations today?

---

## 11. Implementation note

This document defines process intent. It does not authorize database schema or UI implementation by itself. System architecture documents and module specifications must translate these processes into implementation boundaries.
