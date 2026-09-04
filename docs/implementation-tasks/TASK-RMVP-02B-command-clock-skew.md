# RMVP-02B Change Order Save — command clock skew

## Authority and scope

Task-authorized correction under ARCH-002 / OPS System Map v1.0.
Starting main: `4031d2daa484c8b917f9a92efbff1f0d4c225c95`, after PR #254.
One agent; no delegation. Allowed changes are the RMVP-02B envelope validator,
focused SQL and frontend regressions, the API amendment, this record, and inclusion
of the new regression in the existing Linux Full Integration runner.

No client timestamp rewriting, new permissions, API shape changes, business rules,
module changes, hosted deployment, Staging/OPS/Retool writes, or automatic merge.

## Diagnosis and RED evidence

The original validator rejects every positive timestamp offset. Create,
Supersede, and Cancel call it at entry; `rmvp_02b_prepare_command` calls it again
before authorization and receipt creation. The browser generates `requested_at`
with `new Date().toISOString()` when Save is clicked.

Before changing production code:

- The envelope suite passed −1s and failed +1s and exactly +60s for all three
  command names: 6 failures out of 25 assertions. Each failure returned
  `VALIDATION_FAILED`, `field_errors[0].field = requested_at`.
- The authenticated SYSTEM_DISH / ADJUST_QUANTITY Create at +1s failed on that
  exact field. Its existing preview remained saveable. The workflow suite had
  17 failures out of 67, including downstream assertions dependent on Create.
- A temporary control using −1s for the same workflow passed all 67 assertions
  against unchanged production code. The control file was removed.
- The connected Workbench/adapter test reached Create with a current saveable
  preview. A non-saveable preview blocked Save; existing edit/invalidation tests
  continued to pass. No independent fingerprint or disabled-button defect was
  found in this path.

The clock-skew Save defect is proven locally and matches the reported Staging
symptoms. The original operator request timestamp was not captured, so attribution
of that historical attempt remains unconfirmed. No hosted probe or write was used.

## Implementation and protections

`20260904071803_fix_rmvp_02b_command_clock_skew.sql` replaces only
`atlas_core.rmvp_02b_validate_command_request(jsonb, text)` under its existing owner.
Only the timestamp comparison and its field error message change. The inclusive
upper bound is server transaction time plus 60 seconds.

Existing ownership, function attributes, execution grants, RLS, authentication,
capabilities, reasons, optimistic versions, predecessor checks, and receipt
handling are preserved. The original request is passed through unchanged. The
established hash excludes timestamp/correlation; changed business payloads still
produce an idempotency conflict. Cancel still requires the separate cancel
capability, even for an Actor holding read/write.

## Targeted validation

- RMVP-02B envelope pgTAP: 29 passing assertions.
- RMVP-02B effective BOM / command pgTAP: 70 passing assertions.
- Workbench and recipeAdjustmentApi: 34 passing tests across two files.
- Integration-runner contract: 85 passing tests. The first frontend CI run exposed
  its old 80-command count; registering this additional suite requires 81. The
  count and an explicit assertion for the new suite were updated together.
- Typecheck, Prettier for supported touched files, and `git diff --check` pass.
- +1s accepted; exactly +60s accepted; +61s and +60.000001s rejected; invalid
  timestamps rejected. Create at +1s, Supersede at +60s, Cancel at +1s, and normal
  past-timestamp Create succeed.
- Exact replay retains one receipt. Changed payloads conflict. Supersede retains
  version and predecessor checks. Read/write alone cannot Cancel. Preview leaves
  root, revision, receipt, event, and audit counts unchanged.

The separate PR starts as Draft and becomes Ready only after targeted GREEN.
Linux Full Integration is the broad validation authority; its result is recorded
in the PR checks and task handoff. No local rerun of that full suite is required.

## Rollback and remaining risk

No table or stored business data changes. A forward rollback can restore the
previous function body under `atlas_owner`; this would restore zero tolerance and
the reproduced Save defect. Existing receipts and immutable adjustment history
require no conversion or rollback. Clocks more than 60 seconds ahead remain
deliberately rejected. Staging receives no fix until a separately authorized
deployment; this task performs zero hosted writes.
