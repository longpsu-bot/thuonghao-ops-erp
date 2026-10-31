# OPS v1 menu reset hotfix

**Goal:** Preserve saved actual-Need overrides for Ingredients outside a changed
menu Dish set. The Owner clarified that the incident concerns changing menu
Dishes; PO/Dispatch confirmation needs no change.

**Scope:** Four existing public menu functions in live OPS v1
`qnthofvccilhnefdcxnz`: `sync_daily_order_dishes`,
`fn_save_daily_menus`, `fn_update_order_dishes`, and
`fn_upsert_weekly_menu`. Keep signatures, permissions, quantity calculations,
pantry protection, explicit clear-day behavior and existing rebalance boundaries.
Do not change Recipe Change Orders, PO/Dispatch confirmation, Atlas migrations,
production data, dependencies or deployment configuration.

**Files:** A manual versioned SQL migration, guarded rollback, isolated SQL
regression and local runner under
`integrations/ops-v1/hotfix-20261031-menu-reset/`, plus this task record.

**Evidence:** The retained live reset trigger deletes every non-pantry override
when an order temporarily has zero Dishes. Menu writers delete all existing
Dishes before reinserting the desired set. An isolated local reproduction loses
an unrelated saved override; a targeted delete retains it. The existing shared
sync helper also refers to a CTE outside its statement scope. Change Order
tables have no mutation triggers; recent system Change Order creation windows
show no mass actual-Need override deletion. PO/Dispatch confirmation separately
rebuilds document lines over the selected date range; that behavior is outside
this menu patch.

**Architecture:** Repair the existing shared sync helper to insert missing
Dishes before deleting obsolete ones. Reuse it from every retained menu writer.
Lock the order before comparing/changing its Dish set. Keep the weekly
signature/drift reporting and rebalance flow intact.

## Implementation and acceptance

- [x] Add a regression that loses an unrelated saved override under the retained
      weekly-menu writer, and observe its failure.
- [x] Repair the shared helper and route all three menu writers through it.
- [x] Verify unchanged replay, partial replacement, single-Dish replacement,
      explicit clear-day pantry protection, duplicate input, manual-save paths and
      atomic failure on invalid Dish identity.
- [x] Preserve unaffected Dish row identities and every field of unrelated
      saved override rows, including note and actor metadata.
- [x] Review the SQL migration/rollback guards and unchanged security attributes.
- [x] Reproduce and fix fractional Dish-ID rounding and a mixed-writer parent-lock
      deadlock; pass a real two-session local concurrency regression and focused
      independent re-review.
- [ ] Publish a Draft PR and observe its required Frontend CI. Keep production
      application separate from this source/test delivery.

**Validation:** Run only the isolated PostgreSQL regression and scoped formatting
and whitespace checks locally. The first regression uses temporary objects in
rolled-back local transactions. The concurrency runner uses two real sessions
in a uniquely named disposable database and drops it in `finally`. Neither
resets a local Atlas database or calls a hosted project.

**Rollback:** Restore exact retained function definitions atomically, guarded
against unknown deployed source. Function rollback does not recover previously
deleted overrides or documents. Historical data repair requires independently
verified evidence and a separate bounded action.
