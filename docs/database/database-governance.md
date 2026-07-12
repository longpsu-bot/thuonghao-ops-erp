# Database Governance

**Status:** Baseline draft  
**Authority:** Database design and migration rules  
**Review required:** Technical review before schema work begins  

---

## 1. Purpose

This document defines how OPS ERP database objects should be designed, migrated, and governed.

---

## 2. Platform direction

OPS ERP initially uses Supabase PostgreSQL as the backend platform.

---

## 3. Database principle

The database is the authoritative system for business validation, calculation, status integrity, and audit for operational workflows.

---

## 4. Schema strategy

Proposed future schema groups:

- `ops3_identity`
- `ops3_core`
- `ops3_demand`
- `ops3_recipe`
- `ops3_adjustment`
- `ops3_requirement`
- `ops3_procurement`
- `ops3_fulfilment`
- `ops3_reporting`
- `ops3_audit`
- `ops3_legacy`
- `ops3_api`

Names are provisional and must be reviewed before migration creation.

---

## 5. Migration rules

1. Every schema change must be represented as a migration.
2. Migrations must be reviewed before production execution.
3. Destructive migrations require rollback or recovery notes.
4. Business-critical changes require tests or validation queries.
5. Migration files should be small and understandable.

---

## 6. API boundary

Frontend clients should not freely write internal domain tables.

Preferred pattern:

```text
frontend → typed client → RPC/view → internal tables
```

---

## 7. RLS and permissions

Tables exposed to authenticated users must be protected through RLS or accessed only through safe functions/views.

Service-role credentials must never be used in frontend code.

---

## 8. Legacy adapter rule

OPS v3 should not directly depend on Retool state or UI-specific v1 logic.

Legacy access must go through adapter views or migration scripts.

---

## 9. Audit rule

Business-write functions that affect operational truth should record audit events in the same transaction where practical.

---

## 10. Open database questions

1. Final schema naming convention.
2. Whether to keep v3 in same Supabase project as v1 during early rollout.
3. How much historical v1 data to migrate versus reference.
4. How to version calculation rules.
5. Which views are safe for frontend direct reads.
