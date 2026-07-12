# Atlas Application Map and Page Responsibilities

**Status:** Baseline for Phase 3 prototype  
**Authority:** UI information architecture derived from approved business processes and module ownership  
**Backend authorization:** None; this document does not authorize schema or RPC work.

## 1. Purpose

Translate Atlas domains and operating stages into a staff-facing application structure. This preserves the workflow clarity learned from OPS v1 while avoiding direct replication of Retool pages, temporary state, and hidden JavaScript.

## 2. Navigation model

### Overview

- Operations Home
- Work queue and exceptions
- Upcoming service periods
- Cross-workflow status only; no authoritative editing

### Planning

- Demand Overview
- Attendance and Portions
- Menu Planning
- Additional Demand
- Requirement Review

### Procurement

- Supplier Allocation
- Purchase Orders

### Fulfilment

- Dispatch Planning
- Operational QA

### Master Data

- Customers and Schools
- Ingredients and Units
- Dishes and Recipes
- Suppliers and Ingredient Eligibility
- Operational Rule Configuration

### Administration

- Users and Access
- Audit and Diagnostics
- Integration Status

## 3. Workflow pages

| Page | Owner | Reads | User creates/changes | Completion output | Explicitly does not own |
|---|---|---|---|---|---|
| Demand Overview | Planning | menu, attendance, wholesale, pantry and correction status | opens the correct source workflow | complete and validated source set | recipe math, supplier assignment |
| Attendance and Portions | Planning | schools, service dates, defaults | student/teacher portions and imports | confirmed quantity basis | menus, recipes, procurement |
| Menu Planning | Planning | schools, dates, dishes and menu status | catering menu assignments/import review | catering demand | attendance values, BOM logic |
| Additional Demand | Planning | customers, ingredients and dates | wholesale lines, pantry additions and manual corrections | direct ingredient demand | recipe explosion, supplier commitment |
| Requirement Review | Planning | generated requirements, traces, adjustments and warnings | adjustment/substitution requests and review notes | requirements ready for procurement validation | supplier commitment, PO release |
| Supplier Allocation | Purchasing | validated orderable requirements and supplier eligibility | supplier assignment and quantity splits | balanced purchase plan | source demand and recipe changes |
| Purchase Orders | Purchasing | balanced allocation and document history | review, release and correction request | released supplier commitments | silent requirement recalculation |
| Dispatch Planning | Warehouse/Dispatch | released requirements/PO context and customer delivery data | dispatch preparation and release | immutable dispatch documents | supplier master data |
| Operational QA | Operations/Management | demand, requirement, PO and dispatch snapshots | resolution routing and controlled correction initiation | reconciled exceptions | direct hidden repair writes |

## 4. Interface hierarchy

- **Page:** one operational responsibility and one accountable owner.
- **Tab:** lifecycle state or stable perspective within the page.
- **View mode:** grouping of the same records; it does not change ownership or lifecycle.
- **Filter:** narrows records without changing meaning.
- **Drawer:** inspect or draft changes for one entity.
- **Modal:** confirm a bounded consequential action.
- **Bulk toolbar:** act on explicit selected records.
- **Status chip:** display an explicit contract state.
- **Summary card:** attention/navigation signal with defined source semantics.

## 5. Page-level tabs and major components

### Demand Overview

Tabs: All sources, Missing input, Blocked, Ready.  
Components: period selector, source-completeness matrix, school/date status grid, next-action links.

### Attendance and Portions

Tabs: Daily entry, Import, Conflicts.  
Components: editable school table, import preview, unsaved-change bar, validation summary.

### Menu Planning

Tabs: Weekly menu, Import status, Exceptions.  
Components: week selector, school/menu grid, dish picker, completeness summary.

### Additional Demand

Tabs: Wholesale, Pantry additions, Corrections.  
Components: document list, line-entry form, customer/date context, validation summary.

### Requirement Review

Tabs: All requirements, Exceptions, Pending adjustments, Ready.  
View modes: By date, by school/customer, by demand source.  
Components: summary cards, requirement table, trace drawer, adjustment/substitution draft forms, pending-change review.

### Supplier Allocation

Tabs: Unallocated, Partially allocated, Balanced, Exceptions.  
View modes: By ingredient, supplier, school/customer, service date.  
Components: allocation workbench, eligible-supplier list, split editor, balance indicator, bulk defaults, release preview.

### Purchase Orders

Tabs: Draft, Released, Corrected/Cancelled.  
Components: supplier-grouped list, PO preview, release confirmation, export actions, immutable history.

### Dispatch Planning

Tabs: To prepare, Prepared, Released, Exceptions.  
Components: school/date dispatch grid, document preview, release confirmation, export actions.

### Operational QA

Tabs: Missing PO, Missing dispatch, Quantity mismatch, Resolved.  
Components: exception queue, comparison table, lineage links, resolution routing.

## 6. End-to-end prototype journeys

### Catering

Menu assignment + portions → catering demand → generated requirement → adjustment review → supplier allocation → PO preview → dispatch preview → QA result.

### Wholesale

Direct ingredient order → validated direct requirement → supplier allocation → PO preview → dispatch preview → QA result.

Each journey uses explicit fixture values. React does not calculate authoritative results.

## 7. Relationship to OPS v1

Preserve workflow evidence:

- attendance entry and conflict preview;
- weekly menu assignment;
- separate/direct ordered goods;
- quantity confirmation before purchasing;
- supplier split and balance behavior;
- PO views by supplier, school and ingredient;
- dispatch generation;
- PO/dispatch reconciliation.

Do not preserve:

- Retool component hierarchy;
- temporary browser state as business authority;
- chained query/event behavior;
- export scripts as domain logic;
- duplicate RPC naming or deprecated save paths.

## 8. Phase 3 acceptance boundary

The application map is validated when a product owner can navigate both prototype journeys and identify:

- where each input enters;
- which role owns each page;
- what each page produces;
- where exceptions are resolved;
- when responsibility passes to the next role;
- which states will later require backend commands.
