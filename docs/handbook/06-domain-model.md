# OPS ERP Handbook
## 06 — Domain Model

**Document ID:** OPS-HANDBOOK-006  
**Status:** Baseline draft  
**Authority:** Domain concepts and relationships  
**Review required:** Yes — architecture and business review required before schema design  

---

## 1. Purpose

This document defines the conceptual business objects of OPS ERP. It is not a physical database schema.

The domain model exists so that business concepts are named consistently before Codex or developers implement tables, APIs, or UI.

---

## 2. Core domain groups

1. Identity and access
2. Core master data
3. Demand
4. Recipes
5. Adjustments
6. Requirements
7. Procurement
8. Fulfilment
9. Audit and reporting
10. Legacy adapters

---

## 3. Core master data concepts

### Customer

A party receiving meals, ingredients, or services. A school may be a customer, but the system should not assume all customers are schools forever.

### School

A specific educational institution or operating location. In early OPS ERP, schools may remain a major customer subtype.

### Delivery Location

A destination where goods are delivered. A customer may have one or more delivery locations.

### Ingredient

A raw material or item used in recipes, wholesale orders, procurement, and dispatch.

### Unit

A measurement or business unit used for recipe, purchase, dispatch, or sales quantities.

### Dish

A menu item offered in catering service. Dishes become ingredient demand only through recipes.

### Supplier

A vendor that can provide ingredients.

### Supplier Ingredient Relationship

Defines whether a supplier can provide a specific ingredient and the associated purchasing details.

---

## 4. Demand concepts

### Demand Document

A business document representing a customer need for a service date or delivery date.

Candidate demand document types:

- CATERING_MENU
- WHOLESALE_ORDER
- PANTRY_ADD
- MANUAL_DEMAND
- CORRECTION

### Demand Line

A line inside a demand document.

For catering, a demand line may reference a dish and portion basis.  
For wholesale, a demand line references an ingredient directly.

### Demand Source

The origin of a requirement, such as menu, wholesale order, pantry addition, or manual adjustment.

---

## 5. Recipe concepts

### Recipe

A definition describing how a dish is converted into ingredient requirements.

### Recipe Version

A versioned recipe definition applicable during a time period or operational condition.

For the connected RMVP-02A boundary, a Recipe Version is first an editable `DRAFT`. Validation materializes its immutable BOM facts; Planning release makes those facts eligible for downstream use. A later correction is a successor version and never overwrites the validated, released, or locked predecessor.

### Recipe Line

An ingredient and quantity rule inside a recipe version.

Recipe Line is the stable identity across versions. Each validated version owns an immutable Recipe Line Revision. A removed contribution is an explicit revision linked to its exact predecessor, not an omitted row.

### Recipe Applicability

Rules describing when a recipe version applies, such as school type, customer, service date, or menu condition.

---

## 6. Adjustment concepts

### Adjustment

An explicit business change applied to demand or requirements.

Adjustment types may include:

- ADD
- REMOVE
- SUBSTITUTE
- QUANTITY_OVERRIDE
- FACTOR_ADJUSTMENT

### Substitution

A structural adjustment replacing one ingredient or effective requirement with another for a specific business context.

### Quantity Override

A direct change to an effective requirement quantity without changing the permanent recipe.

### Pantry Addition

A direct operational addition that creates ingredient demand outside normal recipe explosion.

---

## 7. Requirement concepts

### Raw Requirement

The initial ingredient requirement generated from a source before adjustments and rounding.

### Effective Requirement

The working requirement after applicable adjustments are applied.

### Orderable Requirement

The procurement-facing quantity after rounding, package, minimum order, or procurement rules are applied.

### Requirement Trace

The lineage explaining how a requirement was produced, including demand source, recipe line, adjustment, calculation rule, and warning state.

### Calculation Run

A versioned execution of the requirement calculation process.

---

## 8. Procurement concepts

### Purchase Assignment

A decision assigning an orderable requirement or group of requirements to a supplier.

### Purchase Plan

A draft grouping of supplier commitments before release.

### Purchase Order

A released supplier-facing document that freezes quantities and relevant calculation context.

### Purchase Order Line

An ingredient quantity committed to a supplier.

---

## 9. Fulfilment concepts

### Dispatch Header

A released or draft customer-facing delivery document for a service date and location.

### Dispatch Line

An ingredient or item quantity included in a dispatch document.

### Delivery Confirmation

A record of completed delivery, shortage, rejection, or other fulfilment outcome.

### Shortage

A recorded gap between required or dispatched quantity and available or delivered quantity.

---

## 10. Audit concepts

### Audit Event

A record of who changed what, when, why, and through which operation.

### Release Snapshot

A frozen representation of a released business document and its calculation context.

### Correction

An explicit record that changes the business outcome after release without silently rewriting released history.

---

## 11. Relationship overview

```text
Customer / School
    → Demand Document
        → Demand Line
            → Recipe Version / Direct Ingredient
                → Raw Requirement
                    → Adjustment
                        → Effective Requirement
                            → Orderable Requirement
                                → Purchase Assignment
                                    → Purchase Order
                                        → Dispatch
                                            → Delivery Confirmation
```

---

## 12. Concepts not yet finalized

The following concepts require later review:

- inventory lot;
- stock reservation;
- production batch;
- kitchen work order;
- supplier confirmation lifecycle;
- customer-facing invoice or billing document;
- customer portal order submission.

---

## 13. Design rule

Physical table names may differ from domain names, but every physical table must map clearly to a documented domain concept.
