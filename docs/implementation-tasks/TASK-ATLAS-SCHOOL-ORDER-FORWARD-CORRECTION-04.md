# Atlas School order forward correction 04

Status: Owner-authorized implementation and reviewed hosted rollout gates.

## Owner decision and scope

`ORDERING_DECISION = REVIEWED_FORWARD_CORRECTION`. `DENSE_GLOBAL_RENUMBERING = REJECTED`. The completed reconciliation is historical evidence, not an ordering amendment. Keep its receipt and checksum immutable. This task corrects only `display_order` through a separate protected, session-local transactional path and technical receipt.

The authoritative pre-reconciliation baseline is `result_payload.current_schools` in receipt snapshot `ops-v1-school-reconciliation-38071834975-1`, snapshot checksum `fe88da258a81e890f3a521de4334062e29080309ccd032189b0e1c5176959945`, plan checksum `56565d5c34312f10f54fb3a4861cc16410f885a19bb2563c6decdcd3a21a1518`. OPS V1 is read-only evidence. Do not replace existing Atlas numeric values with source values.

Allowed: separate SQL package, protected runner/workflow choice, focused regression coverage, affected runbooks and the [complete fifty-School review report](../testing/atlas-school-order-forward-correction-04.md). After reviewed exact-head validation and correction PASS, deploy the already-approved repository migration 98 and use existing authenticated Admin configuration commands.

Prohibited: old receipt or checksum edits, mapping identity changes, reset or blind reconciliation replay, already-applied migration edits, new business lifecycle, PO/PXK fact mutation, Live OPS writes, Retool changes, UI PR #364 edits, reopening Cooking/Dispatch semantics, snapshot or row-height contracts.

## Acceptance criteria

- Before correction: exact Staging `rnzxmxiiqgtdevzregff`, 97 migrations, tip `20261010034834`; receipt hash/checksums, all canonical mappings, School facts and current dense receipt outcome match. Drift stops with `SCHOOL_ORDER_FORWARD_CORRECTION_REQUIRED_REVIEW` before writes.
- Resolve block members through typed canonical mappings. Bình Quới 52 then 10 are adjacent; Hùng Vương 47,48,49,50,53 are adjacent with consecutive numbers. Preserve unrelated School relative order, including Vĩnh Tân 38 before 40.
- Preserve old numeric values and valid ties wherever possible; raise unrelated rows only by the smallest amount needed for block collisions, using actual PostgreSQL `school_name, school_id` secondary order and ACTIVE Customer-scoped uniqueness. No aesthetic dense renumber.
- Report every School ID/code/name, old baseline, current dense order, corrected order, forward-change flag and reason. The reviewed receipt predicts 39 of 44 old numeric values retained, five old values changed and six new canonical values assigned. Forty-nine current dense rows need forward order writes.
- Correction is atomic and replay is safe; full non-order School facts, operational facts, all mappings and old receipt stay unchanged. Full authenticated `get_school_master_data` readback matches all fifty rows and their complete ordered sequence.
- Only after correction passes: deploy `20261010102603_atlas_document_school_grouping_02`, confirm 98 parity, then configure Cooking PVC 17/14, Vĩnh Tân 40/38, company 53, independently of Dispatch Vĩnh Tân 40/38, Hùng Vương 47/48/49/50/53, Phú Hoà Đông 1 19/46/27. PH3/28 is excluded.
- Verify authenticated Admin relationship IDs, independence, security/RLS, separate PO Schools and explicit Dispatch grouping. Rehearse using eligible existing hosted documents only; record absence without fabricating documents.

## Required verification

Regression cases: valid 0/1 ties, unchanged unrelated prefix, both exact blocks, minimum displacement, all unrelated relative order, Customer-scoped collisions, safe replay, unexpected hosted drift, rejection of global 0..N. Focused runner/SQL tests precede independent review and exact-head GitHub frontend/full integration validation. Migration deployment uses the existing protected workflow and exact repository history; configuration uses the existing shaped Admin commands.

## Migration and rollback

The correction adds no persistent schema. School order updates retain normal version/timestamp evidence; its separate technical receipt records the forward operation. Rollback would require another explicitly reviewed correction and current-fact guard, never receipt deletion or version reset. Migration 98 has its existing separately reviewed compatibility/rollback requirements and does not rewrite historical documents.
