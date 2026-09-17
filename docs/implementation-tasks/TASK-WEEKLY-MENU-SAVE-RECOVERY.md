# Weekly Menu Save: snapshot validation at operational scale

Baseline: `e3e45dbf23f56b847d837c5f8a1955992a0933f9`.
Authority: OPS_SYSTEM_MAP v1.0 / ARCH-002; backend facts and immutable approval evidence remain authoritative.
Scope: one private trigger-function performance correction, a scale regression, CI coverage and this record. No public API or frontend changes.

## Diagnosis

An explicitly rolled-back 471-assignment probe over existing Staging references, using the authenticated role and the existing eight-second statement budget, failed with SQLSTATE `57014`. The stack identifies the full-set anti-join in `pa_06e_h0a3a_weekly_menu_snapshot_integrity_guard`, flushed by `approve_weekly_menu` during `save_weekly_menu`. A one-assignment equivalent passed. No problem-week Menu or probe receipt remained after rollback.

This proves a backend scale defect, not the exact original browser request/response. An absent receipt does not prove that a command never entered the backend: rollback can remove both business changes and its receipt.

## Correction and integrity argument

The immutable snapshot-line deferred event still verifies current parent/approval binding, version, active stable-line identity, School, service date, slot, Dish and source-row reference. It no longer repeats both complete-set scans for every child. Snapshot-header and Weekly Menu approval events retain the original whole-set completeness/exclusivity scans. Existing unique/FK constraints and immutable-line guards are unchanged.

Every new approval schedules header and parent checks. Adding to an established snapshot remains subject to exact membership, immutability and uniqueness. No client-supplied cache or transaction marker can skip validation. No timeout is increased and no trigger is disabled.

## Data destination

The connected Chakra candidate uses the real non-production Atlas Staging project `rnzxmxiiqgtdevzregff`. Google Sync fetches source rows into a browser-local React draft. Preview and correction-impact calls are read-only. The single consequential Save invokes `atlas_api.save_weekly_menu`, which atomically saves, validates, approves and returns authoritative readback.

Persisted Menu data belongs to `atlas_planning.weekly_menus`, `weekly_menu_lines`, approval snapshot tables, and existing audit/command evidence. Migration files define database changes; they do not receive operator Menu data. Live OPS v1 `qnthofvccilhnefdcxnz`, Retool and the source Google Sheet are not write targets of this fix.

## Recovery boundary

Do not infer safe retry merely from an absent Menu/receipt or a read that still shows the old version. The original request may be pending, rolled back or unobserved. This correction fixes the reproduced cause while preserving the existing unknown-outcome lock and no-automatic-write-retry transport. Automatic readback is not used to conceal a deterministic Save timeout.

## Verification and deployment

The new local/CI scale test uses 20 fixture Schools and five menu slots across five dates, retaining exactly 471 assignments. It exercises the authenticated v2 Save under eight seconds, completed readback, explicit identical idempotent replay, exact 471-line approval evidence and snapshot immutability. CI also runs the existing snapshot-foundation integrity suite and atomic Planning suite.

Repository acceptance is not hosted deployment. Keep the fix PR Draft/unmerged until review; this task does not apply a hosted migration, change PR #286 or perform production cutover. Deploy through the protected Staging path after merge authorization, then rerun the operator Save and authoritative readback. A rollback is a forward migration restoring the previous function body; it affects performance rather than existing Menu data.

Validation results will be recorded after the exact-head CI completes.
