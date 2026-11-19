# V1 authoritative catalog sync

Owner instruction, 19 November 2026, establishes OPS V1 as the final authority
for the master data covered by the Staging sync. This supersedes the earlier
recommendations to retain differing Atlas master values pending per-row choice.

## Scope and acceptance

The existing exact-main, certified, reviewed-checksum workflow synchronizes typed
OPS V1 master identities. Current source names, School/customer/location status,
School display order, issuer configuration, catalogue display names and Ingredient
facts take precedence over current Atlas values. The pinned activation of
Ingredient903 is removed. The source normalizer retains its documented null
School-order representation of zero and reviewed test-artifact exclusions.
Snapshot diagnostics remain visible and invalid facts stay blocked.

Supplier IDs retain their source identity. Literal source names, including the
retirement wording on Supplier74, are retained. Supplier55 receives its source
name without merging55/74. Mapped supplier-priority updates and absent-membership
inactivation run in one transaction. Priority slots are cleared only for exact
reviewed update targets and then assigned to source values. Missing source
membership inactivates the mapped relationship and retains its row and receipt.
Unmapped/native identity collisions remain blocking differences.

V1's live `v_effective_bom_dish_v2` returns `ingredients.purchase_unit`.
Recipe comparison recognizes only exact current D-047 evidence linking the raw
source Unit, Ingredient purchase Unit, numeric quantity and current released
line. It reports other composition differences. It never rewrites immutable
Recipe versions or adopts effective-view rows as authored Change Orders.

The bounded files are the existing snapshot normalizer, catalog/catch-up SQL,
runner, focused tests and sync runbook. No public API, schema, privilege, module,
business lifecycle or calculation formula changes are introduced.

Acceptance requires source/target Preview, atomic Apply and exact readback,
same-snapshot replay and a fresh post-apply comparison. All operational tables,
native adjustment authority, other masters and prior receipts retain their
protected fingerprints. Source and Production access stays read-only. School
Order, Dish Order and daily operational imports remain excluded.

## Verification and recovery

Focused JS checks cover source lifecycle fidelity and the reviewed runner scope.
Rolled-back pgTAP checks cover name collision convergence, literal source
names, source membership, priority slot swaps, immutable receipts, readback,
replay and existing protection/rollback behavior. GitHub owns full validation.
No migration is required for this change. After Apply, retain receipts and use
a reviewed forward correction for recovery.

Hosted Apply44496831224 rolled back with `UNRELATED_FACTS_CHANGED` because the
protection classifier did not recognize planned Customer and Delivery Location
updates. The follow-up adds their typed keys to the existing exact-target
exclusion predicate. Every other row remains fingerprinted. A rolled-back
regression reproduces the failure and verifies exact source readback after the
fix. The failed hosted run created no receipt or partial master updates.
