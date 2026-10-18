# Atlas B1 — Product model closeout

Status: implementation/validation in progress on existing Draft #402.
Start: `7f1343a570a0e4630faada9a2e4aaf7b5a700444`.
Authority: [Owner approval, 18 October 2026](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6249057414)
and the explicit closeout work order. This supersedes earlier operator-facing
COMPLETE and `Đặt theo yêu cầu nhà trường` instructions, preserving historical
facts and compatibility. No merge, deployment, hosted mutation, B2/C or Warehouse.

## Current versus approved contract delta

| Boundary               | Current                                                                         | Approved bounded change                                                                                                                                                |
| ---------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pantry authoring       | Two persisted Purpose identities; single creation selector; new scopes ADDITIVE | Keep mechanisms; labels `Bổ sung` and `Hàng đặt riêng`. COMPLETE is historical support only.                                                                           |
| Need shaped read       | Numeric Recipe/Pantry totals; Pantry combines both purposes                     | Append exact decimal-string `source_breakdown`: R, B, R+B, H, unclassified historical direct, total. Preserve numeric compatibility fields.                            |
| Classification         | Atomic snapshot already retains Purpose evidence                                | Classify by immutable `purpose_code_snapshot` using the exact snapshot + stable Pantry-line composite key. Never classify Vietnamese text or relabel neutral evidence. |
| Need/Confirmed support | Labels all Pantry-direct as Bổ sung                                             | Render original R, B, recipe-associated R+B, separate H and theoretical total. Keep operational rounding, final confirmation and explicit human reason separate.       |
| Atomic detail          | Family, numeric quantity, selected descriptive metadata                         | Append exact quantity and actual typed Recipe/Pantry snapshot/source IDs. Preserve RECIPE_DERIVED/PANTRY_DIRECT families and immutable history.                        |
| PO/PXK                 | Existing confirmed-source allocation → Handoff → PO → School PXK                | Prove final confirmed 28/30 and Pantry-only8 coverage; change no consumer arithmetic absent a focused failing test.                                                    |
| Historical COMPLETE    | Preserved School/date composition authority                                     | Read-only impact audit and scope-specific historical-reconciliation blocker. No automatic flip or released-document reinterpretation.                                  |

For compatible date × Customer × School × captured location × Ingredient × Unit,
R20+B5 yields recipe-associated25; H3 remains separate; theoretical28. A valid
human confirmation30 retains R20/B5/H3 and a reasoned +2 decision. Backend sums
are PostgreSQL numeric, emitted as strings. React formats shaped quantities and
does not sum source authority. A legacy neutral/unknown Purpose is explicitly
unclassified, included in total and old Pantry totals, never fabricated as B/H.
No persisted subtotal, Recipe/BOM mutation, new domain object, endpoint, lifecycle,
capability, relation privilege, currentness rule or command limit is introduced.

## Affected implementation and interfaces

- One new forward migration changes only the existing private
  `atlas_core.rmvp_04_workbench_payload(date,date,uuid,jsonb,integer,integer,jsonb)`
  body, retaining owner/ACL/search path. Existing runtime already reads exact
  Pantry snapshot evidence. RMVP-05 privileges and entry points stay untouched.
- `NeedGenerationGroup.source_breakdown` is optional for old read compatibility;
  all six members are exact decimal strings. A missing/malformed breakdown shows
  unavailable, never a frontend-derived substitute. Atomic detail gains exact
  quantity, stable Purpose code and actual upstream UUIDs.
- Need model/workbench, Confirmed Need support, connected Pantry labels and their
  typed review fixtures/tests. Preserve exact identity matching and UI guards.
- Extend registered B1 SQL evidence for source-aware reads, 28/30/8 downstream
  coverage and no read multiplication after a human-adjustment successor.
- Amend RMVP-04, Confirmed Need and Pantry documentation in the same change.

## Bounded implementation plan

1. Add focused failing SQL assertions against real B1 generation for exact shaped
   R20/B5/25/H3/28, atomic source IDs and post-adjustment readback. Retain the existing
   B1 suites and test budgets. Prove any suspected revision-join fan-out before repair.
2. Add the smallest guarded in-place read-function amendment. No applied migration
   edit. If fan-out is proven, select one exact captured contribution/revision per
   theoretical line instead of multiplying all historical revision memberships.
3. Exercise real unchanged28 and explicit reasoned30 confirmation/allocation/PO/PXK
   paths, plus Pantry-only Ingredient8, shared-location Schools, exact supplier
   splits and original lineage. Cases roll back; no real commitments.
4. Add focused UI/model regressions, render shaped decomposition and renamed source,
   retain rounding/final decision/reason and historical-unclassified disclosure.
5. Review source/security, run focused SQL/frontend checks, then connected browser
   acceptance at actual 1366×768,1440×900,390×844. Preserve prior failures explicitly.
6. Commit/push existing branch and certify exact-head Frontend, Smoke and Full
   Integration once coherent. Update existing Draft #402 and detailed external
   handoff with independent gate verdicts; stop for Owner review.

Review focus: neutral historical purposes; exact six-place quantities; copied
memberships after human adjustment; historical captured locations; missing read
extensions and cross-School/supplier/date/Unit isolation. Preserve security,
optimistic versions/fingerprints, receipt/UNKNOWN and rollback regressions.

## Read-only Staging COMPLETE impact

Project `rnzxmxiiqgtdevzregff`, synthetic School
`a1020000-0000-4000-8000-000000000204`, Pantry batch
`1aa51287-0e95-451b-8a49-a83b974d08bc`, current approved version23, latest snapshot
`cc199f2f-c498-4a95-8349-65dc252da00f` retains COMPLETE on 2046-09-18 and 2046-09-19.
Actual date preflight reports READY and downstream CURRENT for both, with exact
selected/current date and direct-mode fingerprints equal. The different older
Pantry header for the18th does not make that date stale.

| Date       | Current generation                   | Confirmed batch                      | Handoff                              |
| ---------- | ------------------------------------ | ------------------------------------ | ------------------------------------ |
| 2046-09-18 | 843ac312-4539-418d-8e0e-80247fd8a828 | 4500810a-6917-46de-8830-bec328a552ff | 346efa0e-ea30-43f2-9a05-3cf9716fbc9c |
| 2046-09-19 | 51ab1e86-9579-42d9-b860-594100ae0d69 | db8bd338-a923-4acd-ab8d-ac59b09816b6 | e9ac8c9b-4fef-42ab-aca9-fdda33bc1048 |

Both Confirmed batches are RELEASED_FOR_PURCHASE_HANDOFF and both Handoffs have
released supplier POs. Verdict for transitioning these two scopes:
**BLOCKED — HISTORICAL RECONCILIATION**. Recipe demand is excluded by genuine
current COMPLETE authority. A controlled, separately authorized correction must
identify intended additive Menu/Attendance/Recipe evidence and assess the entire
existing PO/PXK chain before any successor documents. This closeout does not
authorize C, supplier cancellation or hosted writes. No historical/current fact
was deleted, converted, backfilled or silently interpreted as ADDITIVE.

## Evidence ledger

- Canonical checkout/origin/branch/start SHA verified; clean start; six stashes and
  unrelated worktrees preserved. Latest Owner amendment and existing Draft read.
- Read-only independent Need and PO/PXK source investigations completed. PO/PXK
  already follow final confirmed quantities; no concrete H-drop defect found.
- Read-only hosted audit used existing date preflight and chain helpers inside
  read-only transactions. No hosted writes were made.
- PASS: clean disposable database replay and the forward migration; 51 Product
  composition assertions including actual immutable released PO/PXK readback,
  60/40 supplier splits, unchanged28, reasoned30, Pantry-only8, exact decimals,
  same-total changed lineage and neutral historical COMPLETE. Original Recipe
  evidence remains20/5/3 when final confirmation is30.
- PASS: existing B1 39 assertions and Need Generation 87 assertions, retaining
  authorization, scope, fingerprint/version, retry/conflict and rollback guards.
- A pre-fix failing read proved that copied Confirmed revision memberships could
  display theory56 with six atomic contributions after a28-to30 decision. The
  bounded lateral membership selection now retains theory28 and three sources;
  no downstream PO/PXK consumer calculation was changed.
- PASS: exact-breakdown model checks (7), focused Confirmed UI cases (3),
  TypeScript, vNext UI boundary and whitespace checks. Remaining focused UI,
  connected browser and fresh exact-head CI certification are still pending.
- Historical failures are retained outside the repository: initial dirty-fixture
  calculation-contract collision; disposable base-schema bootstrap corrections;
  expected red SQL/UI assertions; fixture-only service-date/version corrections;
  stale detached test-table reference; SQL passed to Prettier without a parser.
  No timeout, assertion, security boundary or CI check was weakened. A subsequent
  focused UI run encountered renewed host memory exhaustion (about92 MB free);
  that incomplete run is not certification.
- First exact-head Frontend run39126617019 failed1 of3064 tests (3061 passed,
  2 pre-existing skips): an old progressive-detail test changed Confirmed theory
  to0.0255 but retained the new shaped read's default10.25 source breakdown. The
  fixture now supplies matching exact source fields; original raw/proposal/step
  assertions remain, with explicit Recipe0.0255/B0 assertions added. No production
  fallback arithmetic was introduced. The focused rerun also stalled under host
  memory pressure; remote recertification is required on the corrected head.
