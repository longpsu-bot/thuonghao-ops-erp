# Decision PA-06E-H0A1 — School and Delivery-Location Ownership

**Status:** Accepted for the bounded H0A1 model by Issue #117; implementation pending review

**Issue:** [#117](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/117)

**Implementation task:** [TASK-PA-06E-H0A1](../implementation-tasks/TASK-PA-06E-H0A1-school-customer-location-foundation.md)

**Parent architecture:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

## Context

PA-06E-H0 identified school/customer ownership, delivery-location ownership, customer classification, and relational school authorization as prerequisites, but did not authorize a physical model. The merged backend currently supports only `WHOLESALE` customers and has no school reference.

## Decision

1. `Customer` remains the commercial/legal relationship root. Its closed classification expands to exactly `WHOLESALE` and `SCHOOL_CATERING`.
2. `School` is a child reference of one `SCHOOL_CATERING` customer. A composite foreign key makes that classification relationally enforceable.
3. `DeliveryLocation` remains independently customer-owned. Every school has one required default delivery location, and a composite foreign key proves that the location belongs to the same customer.
4. `SchoolType` is optional private reference data. No type or school row is seeded by this task.
5. School and school-type codes are lowercase stable codes. Both references use `ACTIVE`/`INACTIVE` lifecycle states, positive versions, and retained history. Active school display order is unique within a customer.
6. `actor_scopes` gains the relational `SCHOOL` target. `GLOBAL` retains no target; every targeted scope kind retains exactly its one matching target and cannot mix targets. Active uniqueness includes school while revoked/expired history remains retainable.
7. All new foreign keys use `ON DELETE RESTRICT`. The new tables are owned by `atlas_owner`, private, forced-RLS, and expose no direct browser/API role privileges or policies.

## Consequences

- Existing Wholesale rows, UUIDs, delivery-location structure, timezone default, functions, receipts, events, and command behavior remain unchanged.
- A later Planning task can reference a typed school and same-customer destination without inventing ownership in application code.
- This decision adds no Planning source lineage, service-date scope, recipe/menu/attendance model, public function, runtime command permission, capability, role, or seed data.

## Rollback boundary

Before operational use, the additive migration can be reverted as an unshipped change. After school data or scopes exist, rollback is forward-only: preserve retained references and scope history, remove unsafe access if necessary, and correct the model through another reviewed migration.
