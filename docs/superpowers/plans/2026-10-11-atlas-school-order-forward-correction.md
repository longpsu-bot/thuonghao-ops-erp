# Atlas School order forward correction

Owner decision: REVIEWED_FORWARD_CORRECTION. Dense global renumbering rejected.

## Global constraints

- Staging only: rnzxmxiiqgtdevzregff, 97 migrations, tip 20261010034834 before correction.
- Immutable baseline: completed receipt ops-v1-school-reconciliation-38071834975-1, result_payload.current_schools. Keep the original receipt and checksum unchanged.
- Resolve identities through exact OPS_V1/SCHOOL mappings. No name identity resolution, mapping mutation, source writes, applied migration edits, UI PR #364 changes, or new persistent lifecycle.
- Preserve existing numbers and valid ties. Only approved Bình Quới 52,10 and Hùng Vương 47,48,49,50,53 blocks become adjacent. Hùng Vương has consecutive numeric positions. Preserve every unrelated relative order and Vĩnh Tân branch-before-main.
- Authoritative tie comparator: PostgreSQL school_name, school_id. Uniqueness is ACTIVE School order per Customer.
- Unexpected hosted facts, mappings, receipt, orders or migration drift: SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW. No writes after drift.
- Full fifty-row report and authenticated get_school_master_data readback. All non-order facts, operational facts, mappings and historical receipt unchanged.
- Reviewed exact-head CI before merge/apply. Only after correction PASS deploy repository migration 20261010102603 to reach 98, then existing approved authenticated configuration path.

## Algorithm

Retain the receipt's canonical approved target sequence, independently checking it only moves the two blocks. Start unrelated rows at their exact old receipt order. For each block's first member, use the smallest feasible number after the preceding target row under PostgreSQL secondary ordering and ACTIVE Customer uniqueness. New Schools have no pre-reconciliation Atlas numeric value: source/projected orders do not establish a numeric floor. Within Bình Quới, use the smallest feasible number that preserves PostgreSQL secondary ordering; a tie is allowed. Within Hùng Vương, increment exactly one. For unrelated rows, retain their old number unless the preceding target row would sort after it; raise only to the smallest feasible number, considering all ACTIVE Customer collisions in a tied segment. Never globally require an increment or global uniqueness. Validate the entire resulting sort and scoped uniqueness. Reject dense 0..N in this correction.

The actual receipt predicts Bình Quới 14,14; Hùng Vương 18,19,20,21,22. Its first member may tie the preceding Bình Mỹ School at 18 because the authoritative secondary order keeps that School first. Only five pre-existing rows differ from the pre-reconciliation baseline: School 10 and four rows displaced by Hùng Vương. Thirty-nine retain exact old numbers. Six new canonical rows receive block positions. Forty-nine actual current dense rows require forward writes; this count is distinct from changes relative to the old baseline.

## Task 1: Protected backend

Create a separate session-local SQL package and regression tests. Preview from the immutable receipt; enforce migration/receipt/all-School fingerprint/current dense/mapping guards. Generate deterministic complete report and plan checksum. Apply transaction with locks and protected whole-platform fingerprints. Use a separate technical import receipt; replay must verify exact corrected facts safely. Never change old reconciliation code or receipt. Cover ties, blocks, minimal displacement, all relative order, scoped uniqueness, replay, drift and prohibited global renumber. Register the SQL test in full integration certification.

## Task 2: Protected runner

Create a dedicated Node runner/tests, integrate manual correct-order choice with protected workflow. Verify exact main, target and migration gates before package, report preview, bind checksum and exact complete report on apply, inspect uncertain results without blind retry, authenticated full fifty-row API readback. Reuse existing transport and authorization architecture. No source extraction.

## Task 3: Review and hosted rollout

Document task/runbook and deterministic full report. Focused local checks, independent product/security review, draft PR attached, exact-head frontend/full integration validation; merge after review. Apply protected correction with replay and complete authenticated readback. Deploy migration 98 only after current-main certification, configure independent Cooking Locations and Dispatch Groups using existing protected runner. Verify parity, Admin reads, security, document eligibility, no Live OPS/Retool changes.
