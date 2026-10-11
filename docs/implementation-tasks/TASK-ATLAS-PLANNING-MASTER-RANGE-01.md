# Atlas Planning master convergence and weekly operator range

Owner instruction: 11 October 2026; recovery authorization creates a separate clean worktree.
Starting main: `fa5cef6e16be725467f8533032971a38e11e5757`.
Branch: `fix/atlas-planning-master-range-01`. Status: Draft implementation; hosted apply requires explicit Owner approval after review/merge.

## Scope and authority

Bounded capabilities: dependency-closed Planning master catch-up; canonical operational School order; Confirmed Need/Shopping List and Supplier Allocation 1–7 day composition. Approved daily Confirmed Need and Allocation family identity remain backend-authoritative. No Warehouse work, parser matching changes, new aggregate/RPC, Cooking Location/Dispatch Group changes, Retool change or Live OPS writes.

Original checkout `D:/Project/Repo/OPS/thuonghao-ops-erp` is read-only, including its six unrelated dirty files. Work occurs in `C:/Users/hp/.codex/worktrees/atlas-planning-master-range-01/thuonghao-ops-erp`.

## Fresh source evidence and bounded correction

Read-only Live observation found 709 Dishes, 1,418 Recipes, 4,317 BoM rows and 49 Schools. Staging typed mappings have 659 Dishes, 1,318 Recipes and 4,044 Recipe lines. The raw missing-root closure remains 50 active Dishes, 100 Recipes, 273 BoM rows, 75 Ingredients with 18 missing Ingredient mappings.

The established, Owner-approved rehearsal normalizer excludes the guarded `Deact Test` cluster: Dish 1983, Recipes 3361/3362, Ingredient 1170 and its invalid test BoM 13637. This task retains that exclusion. Canonical operational catch-up therefore contains 49 Dishes, 98 Recipes, 272 BoM rows and 17 missing Ingredients. Those missing Ingredient IDs are 1194,1195,1198,1199,1200,1201,1202,1203,1208,1209,1210,1212,1214,1215,1217,1218,1222. These are observations, never hardcoded apply rows. Protected extraction revalidates immutable source evidence before preview.

Protected read-only extraction/preview at review head found seven genuine scoped source blockers: Dish 2034 `Cá basa phi lê sốt me + thịt heo kho tiêu` has empty source Recipes 3456/3457; Dish 2041 `Bánh bông lan kem Thiên Ân 40g` has empty source Recipes 3468/3469; Ingredient 1215 `Thạch rau câu Zòn Zòn` and its two Dish 2062 BoM lines use unsupported Unit `Túi`. The approved normalizer is unchanged. These facts require source correction or a separately explicit reviewed source-policy instruction; an apply-ready plan cannot be produced while they remain. The blocked nine-column report contains exact issue values, withheld target identities and closure counts, never a fabricated approved plan checksum.

The authenticated real Google shadow preview for 12–18 October returned HTTP 200, 158 source rows, 546 assignments, 17 UNKNOWN_SCHOOL cells, 40 UNKNOWN_DISH cells and zero AMBIGUOUS_DISH cells against unchanged Staging masters; Menu unchanged, Save/Approve calls zero. A zero-reference local visual fixture demonstrates corrected data flow only and is labeled `LOCAL_FIXTURE`; it is not hosted post-fix acceptance.

`scripts/planning-master-catchup.mjs`, `scripts/run-planning-master-catchup.mjs` and `supabase/packages/atlas-planning-master-catchup.sql` use existing typed identity/import helpers. Missing active Dish roots mechanically close over complete Recipes/BoM, Ingredients, purchase/BoM Units, reference catalogues, Suppliers and eligibility facts. Existing dependencies are read-only references; they must have exact typed ownership and valid downstream facts. Missing catalogue references fail closed. Existing Recipes cannot be overwritten. School 33 retains its mapped UUID and changes only its canonical name to `THUẬN AN - PHÂN HIỆU`; every V1 School retains other facts while source ranks converge.

Preview emits the nine requested report columns plus object counts, source/plan checksums, scoped actions and protected fingerprints. No receipt/master/business writes occur in preview. Source checksum, typed identity, target facts, unrelated tables and mappings are guarded. Apply requires exact Staging, current-main clean checkout, immutable reviewed snapshot, exact plan checksum and existing active Actor. Apply is transactional; readback and identical replay are mandatory. A drifted plan fails closed. Session-local tooling creates no persistent RPC or grant.

## School ordering

The explicit Owner amendment supersedes stale Atlas rank preservation. Current V1 ranks govern; NULL-order Schools 11/20/21 map to tail 49/50/51 by source name. Vĩnh Tân 40/38 retain 4/5; Bình Quới 52/10 retain adjacent 14/15; Hùng Vương 47/48/49/50/53 retain adjacent 19/20/21/22/23. Phú Hoà Đông 1 follows source ranks.

The observation fixture `scripts/fixtures/atlas-planning-school-order-2026-10-11.json` tests the complete 49-School sequence. One appended migration `20261011151311_atlas_planning_canonical_school_order.sql` changes only School ORDER BY clauses in three existing Planning read functions. Its length reflects full function definitions, not new authority.

The shared frontend comparator is configured rank, Vietnamese School name, stable School ID. Planning Menu/Attendance/Pantry and School catalogues use it. Confirmed Need/Allocation reuse it where fields are available; current row APIs expose ID/name but no rank, so those rows use the shared name/ID fallback without inventing rank or changing API. PO/PXK immutable document grouping remains based on authorized stored display order; accepted Shopping List retains source first-occurrence School order and A+ geometry.

**STAGING_SYNTHETIC_VISIBILITY_DEFERRED**: Foundation's managed School UUID `a1020000-0000-4000-8000-000000000204` is required ACTIVE/order 1 by the installer and replay verification. Local Foundation certification builds Menu/Attendance/Pantry references to it and checks preservation across replays. No supported fixture-isolation field exists. Deletion/deactivation/moving its order would break that separate fixture contract; no name-based production exclusion is introduced.

## Range behavior

One shared `Khoảng ngày` field/calendar accepts 1–7 consecutive calendar days, including cross-week intervals. Invalid copy is `Chọn tối đa 7 ngày.` Invalid range sends no read or command; obsolete responses cannot replace current authority.

Confirmed Need loads bounded parallel exact-day authorities and a derived day/status navigator. Drafts stay per date. Save targets one active batch; Generate/Update targets one active date. There is no weekly Save or hidden write loop. Dirty transitions and exit recovery remain explicit.

Shopping List export uses complete daily pagination and fresh preflight before/after each review. All demand dates must be current/editable/saved; no-demand dates may be omitted with a visible summary. One workbook contains one sheet per eligible date. Import validates all workbook dates against the selected range and fresh daily authorities, then validates the entire existing V2/A+ envelope before local draft mutation. One stale day means zero draft changes. `partialImport=false`; import makes zero business writes. Every dirty day still requires explicit Save.

Allocation sends exact start/end to the existing read RPC. Rows sort by date then established family ordering and display `Ngày dùng` for multi-day scope. Same Ingredient on different dates stays distinct. Save uses each row's date. Multi-day preparation has no authority; UI explains `Chọn 1 ngày để chuẩn bị đơn mua.` One-day preparation remains unchanged. New-workbench navigation carries range Confirmed Need → Allocation → Orders; retained workbenches preserve drafts/context and explain the retained range.

## Acceptance, validation and release gate

Focused tests cover source/target drift, closure, stable IDs, replay and unrelated preservation; complete School sequence/name ties; 1/2/7-day and invalid 8-day range; active daily Save/Generate and draft retention; atomic multi-date Shopping import/currentness; exact Allocation read/family Save/no preparation; workspace continuity. Added pgTAP suites contain 6 School-order assertions and 63 synthetic catch-up assertions, including direct planner execution, immutable Recipe Unit adoption evidence, scoped exact blockers/no writes and missing/empty Recipe rejection. Full Integration registers both and runs chronological replay, Planning/Confirmed Need/Procurement and security catalogues.

Local Docker engine was unavailable. Database assertions must be executed by exact-head GitHub Smoke and manually dispatched Full Integration; do not report local DB success. Required frontend checks: format, typecheck, focused/full tests, build, UI boundary and whitespace. Full routine CI remains required and cannot be weakened.

Frontend certification retains all redacted failure headers and test summaries before its bounded diagnostic tail. Its subprocess capture limit is 32 MiB, with explicit error/signal reporting if capture fails; staging commands retain their existing default. Commands, assertions and timeouts are unchanged. A regression exercises output above the previous default buffer and verifies failures separated by long DOM dumps remain visible.

Protected `Atlas Staging Master Data Load` workflow adds a separate **preview-only** job selectable with `planning_preview=true`, `apply=false` at exact review head. The existing full-load/apply job keeps its current-main gate. Only explicit report filenames are uploaded for seven days; raw snapshot and credentials are never uploaded. `verify-planning-weekly-menu.mjs` performs authenticated real Google fetch → unchanged strict parser → Preview for 12–18 October 2026, preserves Menu/Attendance snapshots and records exact issue values/rows. It never calls Save/Approve.

After Owner approval: merge, deploy the ordering migration, verify full migration parity, regenerate/review a current immutable catch-up preview, apply that exact plan, authenticated master readback, read-only real Google acceptance (UNKNOWN_SCHOOL/UNKNOWN_DISH/AMBIGUOUS_DISH zero unless genuine source ambiguity), then hosted range UI smoke. Real Menu Save remains an explicit operator action. This task does not authorize that hosted sequence automatically.

For that approved sequence, run the preview at a clean exact current-main checkout with `--snapshot-output <private-path>` and `--report-dir <existing-private-directory>`. The snapshot is created exclusively (`wx`, owner read/write mode), is never uploaded as a workflow artifact, and is the immutable input to the reviewed plan. After reviewing its source checksum, plan checksum, row report and protected fingerprints, apply with `--snapshot-file <same-private-path> --plan-checksum <reviewed-checksum> --actor-id <existing-active-actor> --apply --target-project-ref rnzxmxiiqgtdevzregff --commit-sha <exact-main-sha>`. Full migration parity is mandatory for apply. The runner automatically checks identical replay. A new source extract requires a new preview and review; never substitute a fresh snapshot into an approved plan.

The pure `confirmedNeedReadAuthority.ts` helper is the narrow vNext business-module boundary for complete daily reads. Workbook/DOM code remains outside the bridge. Invalid range retains the picker, authority and local drafts while blocking edits, commands, refresh and Shopping List actions; correcting the range restores daily eligibility.

## Rollback and risks

Frontend rollback is a code revert. Read-order migration rollback restores prior function definitions via a new forward migration; never edit the applied migration. Master correction has no deletion rollback: retain receipts/UUIDs/history and use a separately approved forward correction if needed. Operational documents are not recalculated. Hosted master apply and zero-blocker acceptance remain pending approval. Synthetic fixture visibility and absent rank fields in some row projections are documented limitations.
