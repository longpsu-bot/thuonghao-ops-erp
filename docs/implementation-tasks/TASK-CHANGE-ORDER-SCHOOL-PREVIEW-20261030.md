# Change Order School preview repair — 30 October 2026

## Authorization and scope

The Owner approved repairing the failed Change Order preview and rerunning
historical step 4 on hosted Atlas Staging using Google Chrome. The operating
scope remains THUẬN GIAO and TRỊNH HOÀI ĐỨC on 20 October 2026. The proposed
one-day School-Dish adjustment applies only to THUẬN GIAO: Đậu đũa in
Đậu đũa xào thịt, 3.5 → 3.6 kg per 100 portions, effective 20 October until
before 21 October. OPS v1, Retool, Production and Warehouse remain outside scope.

Canonical checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`, clean on main
`39cb8c40055fb9b3d9194bfc76e5aa9aeaa41157`, matching fetched `origin/main`.
The workspace check's historical D-drive warning is superseded by the
Owner-authorized E-drive checkout. Branch: `codex/change-order-school-preview`.

Allowed files are one forward migration, the existing Recipe contract test,
this record and the affected API documentation. No frontend guard relaxation,
new dependency, role/grant/RLS change, calculation change, source import or
rewriting of released operational documents is permitted.

## Diagnosis and repair

The hosted School preview consistently failed before Save. Its API calls the
compatibility composition resolver, whose JSON omits `school_type_id`. The
connected parser requires that field in both compositions and verifies it
against the selected School's authoritative type. The same-context read-only
Staging probe returned READY but no type field; the canonical resolver did
include it. Normal input already accepts comma decimals.

Migration `20261030040840_recipe_school_preview_context.sql` adds the derived
School Type once in the shared compatibility wrapper. It leaves its original
selector, arguments and complete result otherwise intact. This preserves
legacy/noncanonical compatibility and also repairs the same context in shared
read/command consumers. `CREATE OR REPLACE` retains the existing owner and
execution ACL; volatility, security-invoker posture and empty search path remain.

## Acceptance and validation

- Authenticated School-Dish Preview returns the same School Type in before and
  after; the outer context remains School-only and exact proposal guards remain.
- All legacy composition evidence is identical after removing the additive field.
- Existing system/School rules, historical resolution and security tests pass.
- Review and exact-head Frontend CI plus executed Supabase Full Integration pass
  before merge and guarded Staging migration deployment.
- Chrome Preview and explicit issuance succeed for the bounded one-day change;
  effective BOM shows 3.6 only for THUẬN GIAO on 20 October, with 3.5 before/after
  and for TRỊNH HOÀI ĐỨC. Released PO/PXK contents remain frozen.

The new two assertions failed as expected before the migration: 2 failures of
61 assertions in `recipe_effective_contract_01.sql`. After the migration, all
62 assertions pass, including the added complete compatibility comparison.
Related RMVP-02B, product-model and operator-workbench suites pass 70, 15 and 27
assertions respectively (174 total). Focused documentation formatting and
`git diff --check` pass. Independent read-only product/architecture/security
review reports PASS with no actionable findings. Exact-head CI, hosted migration
and Chrome acceptance remain pending; this record does not claim completion.

## Rollback and security

No data migration, table or policy change. A reviewed forward migration can
restore the wrapper body from `20260905161348`; that reinstates the preview
failure but does not alter business facts. Any issued test adjustment remains
immutable evidence with a finite historical effective period; it is not deleted
as part of code rollback. Hosted deployment uses the existing protected exact-main
workflow and targets only Atlas Staging `rnzxmxiiqgtdevzregff`.
