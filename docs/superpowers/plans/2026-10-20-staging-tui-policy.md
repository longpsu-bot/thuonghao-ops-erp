# Staging Túi policy repair implementation plan

> Execute inline with `superpowers:executing-plans`; one independent whole-branch review before integration.

**Goal:** Restore Need Generation for the approved Túi Unit by installing its missing exact-Unit policy through the protected Staging runner.

**Architecture:** Reuse the unchanged fifteen-Unit DML package and the existing Foundation workflow. PostgreSQL retains quantity, authorization, receipt and historical-document authority. No schema migration or new rounding semantics.

**Tech stack:** Node.js, Vitest, GitHub Actions, Supabase/PostgreSQL, React/TypeScript.

**Spec:** `docs/implementation-tasks/TASK-ATLAS-PLANNING-TUI-UNIT.md`.

## Evidence and scope

- On 20 October 2026 the latest two `execute_need_generation` receipts fail with `MISSING_PLANNING_QUANTITY_POLICY` and `NO_COMMITTED_CHANGE`.
- For 13 October 2026, Túi is the sole active Unit with no eligible policy. Ingredient `v1-ingredient-1215` uses Túi with order step 1.
- The approved package contains fifteen COUNT Units, step 1, effective 14 September 2026; the installer incorrectly expects/reports fourteen.
- Preserve existing policy identities, source data, issued PO/PXK snapshots, the eight-second command budget and all live OPS/Retool boundaries.

## Task 1: Regression-first repair

- [x] Add installer tests accepting a fifteen-policy readback, rejecting fourteen and retaining rollback behavior and forbidden-target denial.
- [x] Add a Need Generation message test for `MISSING_PLANNING_QUANTITY_POLICY`: name the missing configuration and direct the operator to administration, without instructing a retry.
- [x] Run those tests and retain the expected failures before implementation.
- [x] Update `scripts/install-staging-count-unit-policies.mjs` to accept/report fifteen and map the backend error in `needGenerationModel.ts`.
- [x] Add optional `install_count_unit_policies: false` to the existing Foundation workflow. When explicitly selected, run the existing package with rollback first, then install, then perform normal hosted verification. Default Foundation behavior remains unchanged.
- [x] Run focused installer/package/model tests and changed-file formatting; obtain one independent source/security review.

## Task 2: Protected installation and readback

- [ ] Integrate the reviewed repair under the current Owner-authorized Staging installation scope after normal GitHub certification.
- [ ] Dispatch Foundation installation at the exact merged SHA with `install_count_unit_policies=true`.
- [ ] Verify one eligible Túi policy for every date in 12–17 October, the existing fourteen COUNT policies and kg policy unchanged, and historical data fingerprints preserved.
- [ ] Leave real Need Generation to the operator's deliberate fresh action; do not replay failed commands or issue purchasing commitments.

## Progress ledger

- Task 1: started from clean `main` 16877d1ea7fa6905a0600d37178c4085f9d6dba5 on `fix/atlas-staging-tui-policy`.
- RED: installer regression 3 failures / 3 passes; missing-policy operator message 1 failure / 7 passes, reproducing the outdated fourteen-policy check and generic refresh message before their fixes.
- GREEN: 25 installer/package tests and 8 Need Generation model tests pass; changed-file formatting and diff whitespace pass. Existing nine SQL package assertions already include Túi and exact replay; the package SQL remains unchanged. Independent whole-branch source/security review found no issues and independently confirmed all 33 focused tests.
