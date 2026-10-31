# OPS v1 menu reset hotfix — 31 October 2026

Status: prepared for review; **not applied to hosted OPS v1**.

Changing one menu Dish currently deletes every Dish for its school/day, then
reinserts the desired menu. The existing reset trigger sees an empty menu in
between and deletes unrelated saved actual-Need overrides. The local baseline
reproduces this loss.

The patch repairs the existing shared sync helper and reuses it from the three
menu writers. It retains unchanged Dish rows, inserts missing Dishes first,
then deletes only obsolete Dishes. Order-row locks serialize these writes.
The weekly writer locks payload orders before reading their current Dish sets.

The four changed functions are `sync_daily_order_dishes(bigint,jsonb,text)`,
`fn_save_daily_menus(jsonb)`, `fn_update_order_dishes(jsonb)`, and
`fn_upsert_weekly_menu(date,text,text,jsonb)`. Their existing signatures,
security modes, search paths, owner/ACLs, return shapes and rebalance boundaries
are preserved. These SQL files include complete retained/replacement definitions
so the legacy patch and rollback can be reviewed without a production connection.

“Unaffected” retains the existing trigger's Ingredient scope: Ingredients of
inserted/removed Dishes are reset; other Ingredient overrides retain their entire
stored row. Pantry protection and explicit clear-day behavior are unchanged.
Recipe Change Order behavior, PO/Dispatch confirmation, calculation policy and
Atlas are outside this patch. The Owner clarified that this incident concerns
changing menu Dishes, superseding the initial Recipe Change Order attribution.

## Verification

```powershell
node integrations/ops-v1/hotfix-20261031-menu-reset/regression.mjs
```

The regression uses temporary objects in the existing local PostgreSQL container
`supabase_db_thuonghao-ops-erp` and rolls back both test transactions. It does not
reset Atlas, read a credential or access a hosted project.

The retained baseline failed at “saved override changed: school 1, Ingredient
102”; the patch passes eight behavioral scenarios and the source-guard probe.
It checks unrelated full override rows and stable Dish row IDs, unchanged
replay, both manual writers, duplicate input, a single-Dish replacement,
clear-day Pantry protection and atomic invalid-Dish failure. Apply/rollback
guards accept the expected source and reject unknown source.

The existing production reset trigger is exercised against synthetic tables.
Rebalance and Auth identity are test stubs: this does not certify allocation
math, RLS, hosted concurrency/load or Retool browser acceptance.

## Apply and rollback

Target only live OPS v1 `qnthofvccilhnefdcxnz`; never Atlas Staging or Production.
These files intentionally live outside `supabase/migrations` and are not picked
up by Atlas deployment. The approved review/CI and a separate hosted-application
decision precede execution of `apply.sql` through the Supabase migration tool
against that exact project. No hosted write is part of the local verification.

`apply.sql` and `rollback.sql` are atomic and compare all four normalized
function-body hashes and their retained security attributes before changing
anything. A mismatch raises `OPS_V1_MENU_HOTFIX_SOURCE_MISMATCH`; inspect the
current source instead of bypassing the guard. Recheck the attached reset trigger
against `fixture.sql` before hosted application.

`rollback.sql` restores the retained four function definitions only when the
patched source is still present. It restores the old behavior, including its
known menu-reset defect. Neither direction repairs previously deleted overrides;
historical recovery requires separately verified evidence. No business rows,
trigger definitions, tables, policies, grants or dependencies are changed.
