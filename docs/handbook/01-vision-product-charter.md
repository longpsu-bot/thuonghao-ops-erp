# OPS ERP Vision and Product Charter

**Document ID:** OPS-FOUNDATION-001  
**Architecture version:** 0.1  
**Status:** Approved baseline  
**Product owner:** Long Lai  
**Project codename:** Atlas

## 1. Purpose

OPS ERP is the operational management platform for a school catering and ingredient distribution business.

It must support two primary demand models:

1. Catering driven by weekly menus, attendance, recipes, and operational adjustments.
2. Wholesale ingredient sales driven by direct customer orders.

These demand sources converge into a shared process for requirement calculation, review, supplier assignment, purchasing, preparation, dispatch, delivery, reporting, and audit.

## 2. Mission

Build the simplest ERP capable of reliably operating the company while remaining understandable, maintainable, and transferable to future internal developers or an external software company.

## 3. North Star

> OPS ERP is a domain-driven ERP for school catering and ingredient distribution, designed to be understandable, maintainable, and transferable to another engineering team without relying on its original creator.

## 4. Product principles

### Business before technology
Technology implements the business model; it does not define it.

### Architecture before implementation
Significant features require a documented business purpose, domain owner, rules, contracts, and acceptance criteria before coding.

### Every quantity must be explainable
Operational quantities must retain lineage to source demand, recipes, adjustments, rounding, packaging, supplier allocation, and released snapshots.

### One concept, one owner
Each business concept belongs to one domain and has one authoritative source of truth.

### Facts are stored; derivations are reproducible
Store customer requests, attendance, recipe versions, substitutions, overrides, assignments, released orders, and dispatch confirmations. Recalculate derived values from recorded facts and applicable rule versions.

### Released operations are protected
Released purchase, dispatch, and delivery documents must not be silently rewritten by later rule or data changes.

### Frontend coordinates; backend decides
React handles presentation and draft interaction. Supabase/PostgreSQL enforce authoritative business validation, calculation, transaction integrity, and audit.

### One business action, one command
Multi-record business actions should be executed atomically through a backend command or RPC.

### Modular monolith
Use one React application and one Supabase/PostgreSQL platform with clearly separated modules. Do not introduce microservices without an operational requirement.

### AI implements but does not govern
Codex implements bounded specifications. It must not invent architecture, business rules, status lifecycles, or security policy.

## 5. Initial business scope

### Catering
- Weekly menu demand
- School/customer assignment
- Attendance and portions
- Recipe and recipe-version resolution
- School-specific recurring variations
- Order-specific substitutions
- Pantry additions
- Quantity overrides
- Requirement review
- Procurement and supplier assignment
- Dispatch and delivery

### Wholesale
- Direct ingredient orders
- Order revisions and delivery dates
- Ingredient quantities and units
- Consolidation into procurement and fulfilment

Wholesale demand bypasses recipe explosion because it already represents direct ingredient demand.

### Shared capabilities
- Customers, schools, and delivery locations
- Ingredients, units, dishes, and suppliers
- Unified requirement calculation
- Procurement
- Fulfilment
- Audit and reporting

## 6. Initial modules

1. Identity and Access
2. Core Master Data
3. Demand
4. Recipes
5. Adjustments
6. Requirement Calculation
7. Procurement
8. Inventory
9. Fulfilment
10. Reporting and Control

Inventory may initially be limited or deferred if operations remain primarily cross-docking.

## 7. Technology direction

- React and TypeScript for the primary application
- Supabase and PostgreSQL for backend services and authoritative business logic
- Supabase Auth and Row Level Security
- Database functions/RPCs for transactional business commands
- Managed hosting, initially Vercel and Supabase
- Retool retained only for selected administrative, support, and diagnostic use
- Codex as the primary bounded implementation assistant

## 8. Legacy coexistence

OPS v1 remains operational while OPS ERP is built in parallel.

The new system will initially reuse selected legacy data through controlled adapters. Target architecture and data models must be designed before migration decisions are made.

Legacy objects will be classified as:

- Migrate
- Reference
- Transform
- Rebuild
- Archive
- Discard

Only one system version may own writes for a workflow at a given point in rollout.

## 9. Initial release direction

The first operational release should deliver the shortest complete flow from demand to dispatch, including:

- Authentication and role-based access
- Existing master-data reuse through adapters
- Catering demand
- Wholesale demand
- Attendance and portions
- Recipe calculation
- Pantry additions
- Order-specific substitutions
- Quantity overrides
- Unified requirement review
- Procurement rounding
- Supplier assignment
- Purchase-order generation
- Dispatch generation
- Traceability and audit

## 10. Non-goals for the initial architecture

- Generic ERP for every industry
- Full accounting, payroll, CRM, or HR
- Advanced inventory valuation
- Runtime AI decision-making
- Microservices without need
- Migrating every legacy object
- Preserving legacy technical debt

## 11. Governance roles

### Product Owner and Domain Expert
Defines business intent, priorities, process decisions, and acceptance.

### Architecture Function
Owns domain boundaries, system structure, technical governance, and long-term maintainability.

### Codex
Implements bounded tasks, tests, refactoring, and implementation documentation.

### Future Software Company
Must be able to assume development and operations using the repository and formal specifications.

## 12. Authoritative artifacts

1. OPS ERP Handbook
2. Decision Register and ADRs
3. Business Rule Register
4. Open Questions Register
5. Module Specifications
6. API Contracts
7. Database Migration History
8. Test Suite
9. Rollout and Migration Plan
10. Operations Runbook
11. Changelog

Important decisions must not exist only in chat history.

## 13. Architectural readiness

A capability is ready for implementation only when its objective, owning module, entities, rules, lifecycle, permissions, contracts, acceptance criteria, and blocking questions are resolved.
