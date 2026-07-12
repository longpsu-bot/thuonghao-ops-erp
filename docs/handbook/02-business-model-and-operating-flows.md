# OPS ERP Handbook
## 02 — Business Model and Operating Flows

**Document ID:** OPS-FOUNDATION-002  
**Version:** 0.1  
**Status:** Draft for review  
**Product:** OPS ERP / Project Atlas  
**Owner:** Long Lai  
**Source of truth:** GitHub repository  
**Depends on:** `01-vision-product-charter.md`

---

## 1. Purpose of this document

This document defines the business model and operating flows that OPS ERP must support.

It intentionally describes the company operation before describing software screens, database tables, or implementation details.

The objective is to ensure that the future system is built around the real business workflow rather than around legacy Retool pages, temporary database structures, or UI convenience.

---

## 2. Business identity

OPS ERP supports a school catering and ingredient distribution business.

The company operates across two related but distinct business lines:

1. **Catering by school menu**  
   The company serves meals based on school menus, recipes, attendance, portion rules, and school-specific operational needs.

2. **Ingredient wholesale**  
   The company supplies ingredients directly to schools or other customers as ordered items, independent of meal recipes.

These two business lines share ingredients, suppliers, purchasing, preparation, dispatch, and management reporting.

---

## 3. Operating thesis

The company does not simply sell meals or ingredients.

It converts customer demand into controlled ingredient requirements, supplier commitments, preparation tasks, and delivery execution.

The operating thesis is:

> All customer demand, whether created from a school menu or a direct ingredient order, must become traceable operational demand before it can drive purchasing and fulfilment.

This is the basis for the unified demand model.

---

## 4. Core business objects

### 4.1 Customer

A customer is an organization that receives catering services, ingredient wholesale delivery, or both.

In the current business, most customers are schools.

A customer may have:

- one or more delivery locations;
- one or more service types;
- different pricing or contract terms;
- different operational rules;
- different menu or ingredient requirements.

### 4.2 School

A school is a customer or delivery location with school-specific operating attributes.

Examples of school-specific attributes include:

- student count;
- teacher count;
- school type;
- meal service schedule;
- menu applicability;
- delivery requirements;
- recurring recipe preferences.

### 4.3 Ingredient

An ingredient is a purchasable, preparable, or deliverable food item used by the operation.

Ingredients may be required by:

- recipe explosion from catering menus;
- direct wholesale orders;
- pantry additions;
- substitutions;
- manual operational adjustments.

### 4.4 Dish

A dish is a menu item offered through the catering workflow.

A dish is not directly purchased. It must be resolved through an applicable recipe before becoming ingredient demand.

### 4.5 Recipe

A recipe defines the ingredient composition of a dish for a specific applicability context.

Applicability may depend on:

- dish;
- school type;
- customer;
- service period;
- recipe version;
- operational approval status.

### 4.6 Demand document

A demand document records a customer requirement before it becomes procurement or dispatch.

Demand documents are the conceptual bridge between customer-facing operations and internal fulfilment.

Initial demand document types include:

- catering menu demand;
- wholesale ingredient order;
- pantry addition;
- substitution or adjustment;
- manual demand.

### 4.7 Requirement

A requirement is the calculated or direct ingredient need produced from demand.

A requirement may originate from:

- a menu dish and recipe line;
- a direct wholesale ingredient order;
- an operational addition;
- a substitution;
- a quantity override.

Every requirement must remain traceable to its source.

### 4.8 Purchase commitment

A purchase commitment is a supplier-facing commitment to supply ingredients.

It begins as a supplier assignment and becomes a purchase order after release.

### 4.9 Fulfilment document

A fulfilment document records preparation, picking, dispatch, delivery, shortage, return, or confirmation activity.

Dispatch documents must preserve released operational quantities and must not be silently rewritten by later recalculation.

---

## 5. Business lines

## 5.1 Catering business

The catering business begins with menus and attendance.

The company needs to know:

- which school is served;
- which date is served;
- which dishes are served;
- how many portions are required;
- which recipe applies;
- whether any school-specific or date-specific adjustments apply;
- which ingredients must be purchased and delivered.

Catering demand is dish-based at the customer-facing layer and ingredient-based at the internal fulfilment layer.

### 5.1.1 Catering input examples

Catering demand may be created from:

- weekly menu planning;
- Google Sheets import;
- internal menu-entry screen;
- legacy OPS v1 adapter;
- future customer-facing menu approval workflow.

### 5.1.2 Catering output

The catering workflow produces ingredient requirements after:

1. school/date/menu identification;
2. attendance or portion confirmation;
3. applicable recipe selection;
4. recipe explosion;
5. adjustment application;
6. unit normalization;
7. aggregation;
8. rounding and procurement preparation.

---

## 5.2 Ingredient wholesale business

The wholesale business begins with direct ingredient orders.

A school or customer requests ingredients directly, without selecting dishes.

Wholesale demand is already ingredient-based and therefore bypasses recipe explosion.

### 5.2.1 Wholesale input examples

Wholesale demand may be created from:

- internal order-entry screen;
- school request form;
- customer message manually entered by staff;
- future customer portal;
- recurring standing order.

### 5.2.2 Wholesale output

The wholesale workflow produces direct ingredient requirements after:

1. customer/date/order identification;
2. ingredient and unit confirmation;
3. requested quantity entry;
4. validation against ingredient master data;
5. operational adjustment if needed;
6. aggregation with other demand when allowed;
7. procurement preparation.

---

## 6. Unified demand model

Catering and wholesale are different at the customer-facing layer but should converge before procurement.

The system must therefore separate:

- demand source;
- requirement calculation;
- procurement;
- fulfilment.

The unified model is:

```text
Customer Demand
    ├── Catering menu demand
    ├── Wholesale ingredient demand
    ├── Pantry additions
    ├── Substitutions
    └── Manual adjustments
        ↓
Canonical demand documents
        ↓
Ingredient requirements
        ↓
Requirement review
        ↓
Supplier assignment
        ↓
Purchase orders
        ↓
Preparation / dispatch / delivery
```

This model allows new demand sources to be added later without rewriting procurement and fulfilment.

---

## 7. Operating cycle

The daily or weekly operating cycle has eight major stages.

### Stage 1 — Demand capture

The company records what customers require.

Inputs may include:

- weekly school menus;
- attendance or portion quantities;
- direct ingredient orders;
- pantry additions;
- substitution requests;
- manual corrections.

Primary responsibility:

- Planning staff;
- Management when exceptional approval is required.

### Stage 2 — Demand validation

The company validates that the demand is usable.

Validation includes:

- school exists;
- service date is valid;
- dish exists;
- recipe exists if catering;
- ingredient exists if wholesale;
- unit is valid;
- quantity is reasonable;
- duplicate demand is detected;
- missing attendance or portion data is flagged.

### Stage 3 — Requirement generation

The company converts demand into ingredient requirements.

Catering demand is resolved through recipes.

Wholesale demand directly creates ingredient requirement lines.

Adjustments may add, remove, replace, or override requirement quantities.

### Stage 4 — Requirement review

Planning or operations review the generated requirements.

The purpose is to identify:

- missing recipes;
- abnormal quantities;
- unassigned ingredients;
- substitutions;
- pantry additions;
- duplicate lines;
- warnings;
- procurement readiness.

### Stage 5 — Procurement planning

Purchasing staff assign suppliers and prepare purchase quantities.

This stage may include:

- supplier selection;
- supplier split;
- procurement rounding;
- minimum-order quantity handling;
- package-size handling;
- purchase grouping;
- purchase-order preview.

### Stage 6 — Purchase release

The company releases supplier-facing purchase orders.

A released purchase order becomes an operational commitment.

After release, it must not be silently recalculated.

Changes require correction, cancellation, or revision.

### Stage 7 — Preparation and dispatch

Warehouse, kitchen, or dispatch staff prepare goods for delivery.

This may include:

- receiving supplier goods;
- checking quantities;
- preparing school-specific goods;
- picking and packing;
- dispatch document generation;
- driver assignment;
- delivery confirmation.

### Stage 8 — Reconciliation and control

The company reviews whether operations matched commitments.

Reconciliation includes:

- demand vs requirement;
- requirement vs purchase;
- purchase vs receipt;
- dispatch vs planned delivery;
- shortage and return tracking;
- supplier performance;
- exception reporting.

---

## 8. Demand-source behavior

### 8.1 Catering menu demand

Catering menu demand is dish-based.

It must have:

- customer or school;
- service date;
- meal period or dish category when applicable;
- dish;
- portion basis;
- attendance or quantity basis;
- applicable recipe version.

It produces ingredient requirements through recipe explosion.

### 8.2 Wholesale ingredient demand

Wholesale ingredient demand is ingredient-based.

It must have:

- customer or school;
- requested delivery date;
- ingredient;
- requested quantity;
- unit;
- order note when needed.

It bypasses recipe explosion.

### 8.3 Pantry addition

A pantry addition is an operational direct ingredient need that is not generated from the planned menu recipe.

It may be used for:

- supplemental ingredient needs;
- small manual additions;
- urgent operational adjustments;
- temporary replacement support.

Pantry additions must be traceable and should not become an unstructured workaround.

### 8.4 Substitution

A substitution replaces one ingredient requirement with another for a specific operational context.

A substitution may be:

- order-specific;
- school-specific;
- date-specific;
- dish-specific;
- temporary;
- recurring if later promoted to a recipe or policy rule.

An order-specific substitution must not modify the permanent recipe.

### 8.5 Quantity override

A quantity override changes the effective quantity of a requirement without redefining the recipe.

A quantity override must record:

- original calculated quantity;
- overridden quantity;
- reason;
- responsible user;
- timestamp;
- applicable demand or requirement reference.

---

## 9. Status concepts

Status lifecycles will be formally defined in a later document.

This document establishes only the conceptual states.

### 9.1 Demand status

Potential demand statuses:

- draft;
- submitted;
- validated;
- blocked;
- approved;
- cancelled.

### 9.2 Requirement status

Potential requirement statuses:

- generated;
- warning;
- reviewed;
- ready for procurement;
- locked;
- superseded.

### 9.3 Purchase status

Potential purchase statuses:

- planned;
- assigned;
- purchase-order draft;
- released;
- confirmed;
- corrected;
- cancelled.

### 9.4 Fulfilment status

Potential fulfilment statuses:

- planned;
- prepared;
- dispatched;
- partially delivered;
- delivered;
- returned;
- cancelled.

---

## 10. Operating roles

### 10.1 Management

Management owns business policy, approval thresholds, exception decisions, and strategic operating rules.

### 10.2 Planning

Planning owns menu processing, attendance coordination, requirement review, and operational readiness.

### 10.3 Purchasing

Purchasing owns supplier coordination, supplier assignment, purchase-order release, and supplier follow-up.

### 10.4 Warehouse

Warehouse owns receipt, storage where applicable, picking, packing, handover, and inventory-control execution.

### 10.5 Kitchen or production team

Kitchen or production teams own meal preparation, food-quality control, portion preparation, and operational feedback.

### 10.6 Dispatch

Dispatch owns route preparation, delivery documents, driver handover, delivery confirmation, and exception reporting.

### 10.7 Administrator

The administrator owns master-data maintenance, user access, configuration, diagnostics, and emergency correction.

---

## 11. Control points

The system must preserve control at several points.

### CP-001 — Demand completeness

No operational demand should proceed to procurement if required customer, date, item, quantity, or unit information is missing.

### CP-002 — Recipe availability

Catering demand should not produce final requirements unless an applicable recipe exists.

### CP-003 — Adjustment traceability

Every substitution, addition, removal, or quantity override must retain reason and source context.

### CP-004 — Requirement review

Requirements should be reviewed before procurement release when warnings or exceptions exist.

### CP-005 — Supplier assignment

Purchase orders should not be released for ingredients without valid supplier assignment.

### CP-006 — Release immutability

Released purchase orders and dispatch documents must not be silently recalculated.

### CP-007 — Exception reconciliation

Shortages, returns, cancellations, and corrections must be visible for management review.

---

## 12. Relationship with OPS v1

OPS v1 remains operational during the build and rollout of OPS ERP.

OPS ERP must not assume that all legacy structures are permanent business concepts.

Legacy data should be classified as:

- migrate;
- reference;
- transform;
- rebuild;
- archive;
- discard.

Initial likely treatment:

- schools, ingredients, suppliers, and dishes may be referenced or migrated as master data;
- recipes and BOM data may be transformed into versioned recipe structures;
- daily orders may be transformed into catering demand;
- pantry needs may be transformed into direct demand or adjustment records;
- actual-need overrides may be transformed into quantity overrides;
- purchase and dispatch history may be archived or transformed as released snapshots;
- Retool temporary state and UI-specific helper logic should not be migrated.

---

## 13. First operating vertical

The first complete vertical should prove that OPS ERP can convert demand into fulfilment-ready ingredient requirements.

Recommended first vertical:

```text
Catering demand + wholesale demand
        ↓
Unified requirement review
        ↓
Adjustments and overrides
        ↓
Orderable ingredient quantities
        ↓
Supplier assignment
        ↓
Purchase-order draft
        ↓
Dispatch draft
```

This vertical is valuable because it tests the central business model without requiring advanced inventory, accounting, mobile apps, or customer portals.

---

## 14. Explicit non-goals for the operating model

The initial operating model does not require:

- full accounting;
- payroll;
- CRM;
- supplier portal;
- customer portal;
- barcode scanning;
- advanced inventory valuation;
- AI-based automatic operational approval;
- route optimization;
- multi-company financial consolidation.

These capabilities may be considered later, but they should not shape the first architecture.

---

## 15. Open business questions

The following questions remain open and must be resolved before implementation of the relevant module.

### OQ-009 — Demand approval boundary

Which demand documents require explicit approval before requirement generation?

### OQ-010 — Requirement lock boundary

At what point does a requirement become locked against recalculation?

### OQ-011 — Wholesale and catering aggregation

Should wholesale and catering always aggregate before supplier assignment, or should some contracts require separation?

### OQ-012 — Procurement grouping

Should purchase orders be grouped primarily by supplier, date, delivery batch, ingredient category, or operating shift?

### OQ-013 — Dispatch grouping

Should dispatch documents be grouped by school/date, route/date, supplier/date, or delivery batch?

### OQ-014 — Inventory scope

Does the first release need receiving-only inventory, or can it operate as cross-docking with later inventory enhancement?

---

## 16. Document implications

This document establishes the business operating foundation for later documents:

- Business Glossary;
- System Map;
- Domain Model;
- Module Specifications;
- Calculation Specification;
- Status Lifecycle Specification;
- Security Model;
- API Contracts;
- Rollout Plan.

No implementation should contradict this operating model unless a later architectural decision explicitly supersedes it.
