# MASTER-DATA-CREATION-UX-02 — business-facing creation

## Authority and scope

Task-authorized correction under ARCH-002 / OPS_SYSTEM_MAP v1.0, starting from
`fda7091106bf80fb6f4930f89e4c2587a19f8114` (merged #255). The user approved the
task branch and explicitly permitted subagents, superseding the attachment's
single-agent preference. All implementation agents verified the authorized
`E:/Project/OPS ERP/thuonghao-ops-erp` checkout before editing.

Allowed changes are one forward migration for the RMVP-01/RMVP-02A validators
and Ingredient/Supplier creation, focused SQL regressions, the three existing
Admin workbenches and their tests, the browser-only review adapter where needed,
small contract amendments, and registration of the new suite in Full Integration.

The accepted implementation sequence is:

1. Reproduce the timestamp boundaries and code-free creation failures locally.
2. Amend the existing command bodies without changing request bytes or replay.
3. Remove Ingredient/Supplier code inputs and normal Unit support labels; retain
   required business fields and existing guarded Save behavior.
4. Make Dish notes explicitly optional and every Change Order Dish control
   searchable through the existing Mantine component.
5. Run affected Vitest/pgTAP, typecheck, touched-file formatting and whitespace
   checks; independently review the diff; publish a new Draft PR, then mark Ready
   only after targeted GREEN. GitHub Actions owns broad validation.

There is no change to module boundaries, status lifecycles, calculation precedence,
Recipe locks, roles/scopes/capabilities/RLS, importer semantics, Unit contents,
Planning, Procurement, Warehouse, Dispatch, OPS or Retool. No hosted writes,
deployment, or automatic merge are authorized.

## Command and presentation contract

Both corrected command validators use the inclusive policy
`requested_at <= transaction_timestamp() + interval '60 seconds'`.
The required boundary cases are −1s, +1s and exactly +60s accepted; +60.000001s,
+61s and invalid timestamps rejected. RMVP-02B remains unchanged.

Normal Ingredient/Supplier creation omits technical code keys. Their existing
commands generate `ingredient-<full-random-uuid>` and
`supplier-<full-random-uuid>` after authorization and replay resolution. Explicit
normalized unique codes remain supported for controlled callers. Generation never
derives from an editable name. Persisted identities/codes and one completed
receipt remain stable on exact replay; conflicting payload reuse remains denied.

Dish creation retains the #254 business-only payload and required active Dish
Type. `Ghi chú vận hành (không bắt buộc)` makes blank-note validity visible.
Ingredient creation keeps name, purchase Unit, Ingredient Type, Order Group and
rounding increment. Supplier creation keeps name and optional contact fields.
Purchase Units display only `unit_name`, sort by Vietnamese name, and retain
separate source names such as `Hũ` and `Hủ`. Backend `unit_code` remains available.

Change Order Dish options show `dish_name` and retain `dish_id` as their value.
Typing filters by name in the main Dish control and preview-context controls.
Existing eligible references, editing selection, preview-before-save, unknown
write locking, stale-version handling and backend lifecycle authority remain.

## Verification and delivery gates

Required local checks are the affected Dish/Recipe, Ingredient/Supplier,
Change Order, review-adapter and integration-runner Vitest files; focused RMVP-01
and RMVP-02A pgTAP plus `master_data_creation_ux_02.sql`; TypeScript; Prettier on
supported touched files; and `git diff --check`.

### RED evidence

- Before the migration, the initial SQL suite failed 34 of 90 assertions. All
  three command names accepted −1s but rejected +1s and exactly +60s with
  `VALIDATION_FAILED` / `field_errors[0].field = requested_at`. Rejected Dish
  attempts created no receipt. Omitted Ingredient/Supplier codes also failed at
  −1s, separating that requirement from clock skew. Explicit-code creation and
  the existing −1s Dish replay passed.
- Ingredient/Supplier UI regressions failed 5 of 22 tests: normal code inputs,
  leaked `v1-unit-*` labels, and code-free creation unable to reach Review.
  The review adapter separately returned `backend_error` for code-free creation.
- Dish/Change Order regressions failed six tests: missing optional notes label
  and non-searchable Dish controls in four scope/preview contexts.
- The CI contract regression first failed with 81 commands instead of 82.

### GREEN evidence and review

- Required focused pgTAP: 196 assertions across the new suite (111), RMVP-01,
  and RMVP-02A. All pass. Coverage includes exact boundary rejection,
  original-request receipt hashes, unique full UUID codes, exact replay and
  capability revocation before replay, normalized explicit codes, optional
  contacts/notes, and unchanged hardened function attributes/grants.
- Focused Vitest: 176 tests across eight files pass (three workbenches, three
  command adapters, review adapter, and the 85-test CI contract suite).
- Dish search tests use 301 choices, exclude unrelated names, select the correct
  human label, and verify `dish_id` and `preview_dish_id` through Preview → Save.
  Existing adjustment correction retains the selected Dish and its lock.
- Typecheck initially caught two unsupported test-only `exact` role-query
  options. Removing them preserves the default exact string-name matching;
  typecheck then passes. Touched-file Prettier and `git diff --check` pass.
- Cross-review of files each reviewer did not implement found no actionable
  product, architecture, security, or code-quality issues.

The first Frontend CI run found one additional AtlasApp integration test still
trying to fill the removed Ingredient code input. Its setup now asserts that the
input is absent and completes the same business-field creation, reviewed Save,
internal-code search, and Supplier-priority validation journey. No assertion of
those existing safeguards was removed.

An additional historical Ingredient catalog suite has an unrelated capability
count failure (expects 27, current main has 29). Restoring the four original
function definitions inside a rolled-back local transaction reproduces the same
failure. That historical test is unchanged; the required focused suites pass.

Linux GitHub Actions Full Integration remains the broad authority. PR checks
record the exact branch validation state; no local full-suite rerun substitutes
for that gate. The PR is created as Draft, then marked Ready after the targeted
checks above; merge remains a separate human decision.

## Migration, rollback and remaining risk

The forward migration replaces existing function bodies only. It creates no
business table, backfills no code, and rewrites no existing master data. A rollback
must be another reviewed forward migration restoring prior function definitions;
it would reintroduce zero clock tolerance and require explicit codes again.
Already generated codes are ordinary unique persisted codes and need no rewrite.
Existing receipts, event/audit evidence and downstream references remain intact.

Clocks more than 60 seconds ahead remain deliberately rejected. The hosted Dish
Save symptom will remain until a separately authorized deployment applies this
migration; local reproduction does not retroactively capture the historical
operator request. This task performs zero hosted writes.
