# Atlas v1 parity closeout implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development or
> superpowers:executing-plans task by task; retain a durable progress ledger.

**Goal:** Complete the Owner-authorized v1 parity work except supplier cancellation.

**Architecture:** Extend existing governed commands and operator workbenches.
Reuse archive extraction/import, Staging target/transport/certification guards,
existing Attendance parser/Preview/Save and exact-day Planning authority.

**Tech stack:** React, TypeScript, Chakra v3, PostgreSQL/Supabase, Node scripts.

**Spec:** `docs/superpowers/specs/2026-11-05-atlas-v1-parity-closeout.md`.

## Global constraints

No supplier cancellation, Warehouse, OPS v1 write, Production cutover, new
dependency, automatic operative Change Order activation or historical rewrite.
No fabricated Recipe3529 answer, supplier address, group membership or staff
acceptance. Execute independent implementation tasks sequentially in the
authorized checkout; read-only reviews may run alongside independent work.

## Task 1: Weekday attendance defaults

Files: governed School model/API/workbench and fixtures/tests; new generated
migration and focused pgTAP; relevant School/Attendance contracts. Shared
whole-platform catalog/certifier changes stay with the coordinator.

- [ ] Trace current School-default writers, shaped readers and all Attendance
      default-generation callers. Reuse the current aggregate/version/capabilities.
- [ ] Write and observe failing focused tests for closed weekdays 1-5, missing
      fallback, explicit zero, invalid values/keys, stale version, access denial,
      menu-aware dates and preservation of saved/approved attendance.
- [ ] Implement additive weekday defaults with the smallest existing-aggregate
      representation; keep old callers valid when the optional data is absent.
- [ ] Test backend and operator editing/readback, document the additive contract
      and forward-only rollback, commit owned files and request independent review.

## Task 2: Guarded Staging history and effective BOM comparison

Files: `scripts/import-atlas-staging-recipe-history.mjs`, focused script tests,
manual protected workflow, archive contract, comparison script/report.

- [x] Merge independently reviewed PR452 at its exact certified head.
- [ ] Add tests before a new runner: exact current-main/target/migration guard,
      read-only preview, explicit reviewed checksum/Actor apply, safe artifacts,
      immutable snapshot, replay and unchanged native/operational fingerprints.
- [ ] Reuse extractor, checksum and private importer without relaxing local-only
      runner guards; use existing verified TLS PostgreSQL transport for hosted.
- [ ] Review, certify and merge, deploy exact source, then preview and apply only
      that reviewed immutable plan and prove readback/replay/preservation.
- [ ] Capture source-qualified effective-BOM comparisons with explicit dates;
      report every selected context and blocker without activating archive rules.

## Task 3: Existing factual correction

Files: existing PR445 package/scripts/workflow; no unrelated UI integration.

- [ ] Compare PR445 against latest main, retain only compatible bounded changes,
      run its focused tests and independent review, then normal exact-head CI.
- [ ] Run protected preview; inspect the exact eight mappings/old/new names and
      immutable plan before apply. Apply with exact reviewed checksum and prove
      readback/replay and unchanged released facts.
- [ ] Record unresolved kitchen/address/group facts explicitly; request evidence
      once and continue independent work without guessed corrections.

## Task 4: Attendance XLSX and daily Shopping List access

Files: existing PlanningAttendanceStage/usePlanningSources/parsers and tests;
existing Confirmed Need daily workbench/export surfaces and tests/contracts.

- [ ] Trace installed workbook reader, Attendance matrix parser/preview and
      Shopping List daily authority before selecting the smallest UI change.
- [ ] Write failing file-import tests for supported workbook, malformed/empty,
      unknown School, zero and unsaved-state handling; wire parser to existing
      canonical Preview and explicit Save with no new persistence command.
- [ ] Add multi-day access as an operator projection of exact daily contexts;
      test separate dates/drafts, stale/dirty/UNKNOWN handling and preserved XLSX
      import fingerprints. No ranged Need root or bulk commitment is permitted.
- [ ] Run focused tests/typecheck and rendered verification, document the actual
      supported flow, independent review and exact-head CI before merge/release.

## Task 5: Staff pilot readiness and closeout

Files: bounded pilot runbook and evidence/status record; no staff communication.

- [ ] Prepare staff prerequisites, School/week selection, real data reconciliation,
      Menu/Attendance/Need/PO/PXK test steps, document checks and rollback ownership.
- [ ] Verify release/migration/data parity and rehearse permitted paths without
      real supplier communication or physical operations; distinguish rehearsal
      from actual staff acceptance and preserve unresolved factual blockers.
- [ ] Update roadmap/Autopilot with source-qualified state for every task and
      independently review the complete change set. Finish only verified work;
      list user/external prerequisites for remaining pilot acceptance.
