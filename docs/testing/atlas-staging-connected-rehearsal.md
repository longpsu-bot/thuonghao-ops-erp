# Atlas Staging parity and connected rehearsal

**Task:** ATLAS-STAGING-PARITY-REHEARSAL-01  
**Observation date:** 5 October 2026 (UTC; operator timezone Asia/Bangkok)  
**Verdict:** Staging parity verified; hosted operator rehearsal blocked on approved operator sign-in. **PLANNING-PROCUREMENT-FREEZE-01 is NOT READY.**

## 1. Repository and authority

- Authorized checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`.
- Origin: `https://github.com/longpsu-bot/thuonghao-ops-erp.git`.
- Refreshed `origin/main` and starting HEAD: `e533f4c0c174389d209fbe361b725e12adaeeb4b` (PR #351 merged).
- Task branch: `ops/atlas-staging-parity-rehearsal-01`, created from clean `origin/main`.
- `pnpm ops:workspace` passed. Its historical D-drive path warning does not supersede the owner's explicit checkout selection.
- Scope of repository changes: this evidence document and the concise roadmap update only. No application, migration, contract or dependency edits.
- Authority: [ARCH-002](../architecture/arch-002-atlas-system-map.md), [model convergence](../decisions/decision-atlas-model-convergence.md), [authority map through Procurement](../architecture/atlas-authority-map-through-procurement.md), D-048 and the merged production implementation. **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.**
- Live OPS `qnthofvccilhnefdcxnz` and Retool were neither inspected nor changed by this task.

## 2. Hosted baseline before action

Supabase MCP identified `rnzxmxiiqgtdevzregff` as **Atlas Staging**, `ACTIVE_HEALTHY`, region `ap-southeast-1`, PostgreSQL `17.6.1.155`.

| Check                                 | Before action                                                                                                                                  |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Complete repository migration lineage | 91 migration files                                                                                                                             |
| Complete hosted migration lineage     | 90 entries; versions and names compared                                                                                                        |
| Hosted tip                            | `20261001094403_procurement_supplier_line_note`                                                                                                |
| Missing migration                     | Only `20261005032608_atlas_shopping_list_export_read.sql`                                                                                      |
| Hosted-only / other missing migration | None                                                                                                                                           |
| Shopping List export RPC              | Absent                                                                                                                                         |
| Existing Atlas API identities         | 114                                                                                                                                            |
| Atlas relations                       | 113 tables, 2 views; all 113 tables have enabled and forced RLS                                                                                |
| Catalog/security verification         | PASS using repository `readCatalogAuthority` / `catalogVerificationSql`, with only the absent export identity removed from expected API arrays |

The read-only catalog transaction verified schema identities, runtime role posture, absence of runtime schema CREATE, API signatures/owners, security-definer configuration, exact authenticated access, anon/service-role exclusion, private-table privilege boundaries, normal RLS policy count/digest and the isolated Unit-lock policy. The existing managed application role was included in the verifier contract.

Supplemental comparison against the existing local migrated database found identical relation/column/constraint/index/trigger/view fingerprints. Of 439 existing Atlas functions, 438 normalized-line-ending body hashes matched directly. The remaining `atlas_core.planning_contract_01_validate_command(jsonb,text,text)` differed only in whitespace around calls/operators: removing whitespace produced identical text, and all SQL string literals matched exactly. Its latest repository definition is in `20260822060130_fix_planning_command_clock_skew.sql`; this is formatting evidence, not a changed contract. Source declarations alone were not used to judge functions patched dynamically by later migrations. The local comparison is supplemental evidence, not a substitute for the repository catalog contract.

**Preflight result:** exact authorized migration gap; no structural, API, grant or runtime-role contract drift detected.

## 3. Exact migration action

Used the established protected [`Atlas Staging Deploy` workflow](../../.github/workflows/atlas-staging-deploy.yml), dispatched on `main` with `commit_sha=e533f4c0c174389d209fbe361b725e12adaeeb4b`.

- [Deployment run 37314103549](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/37314103549): **SUCCESS**, completed `2026-10-05T13:06:11Z`.
- Existing exact-head certification consumed successful [Frontend CI](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/37312035038) and [Supabase Full Integration](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/37312647816).
- The workflow's non-mutating preflight passed before its migration step.
- Applied only the unchanged repository migration `20261005032608_atlas_shopping_list_export_read.sql` through the existing guarded CLI migration push. No manual SQL reproduction or migration-history repair.
- The normal platform-only verification passed after application. No identity/foundation installer, reference importer or rehearsal fixture package ran.
- This migration creates one read function and restores its temporary schema CREATE / maintenance SET permissions. Its maintenance role-membership statements are part of the reviewed migration; no separate grant or role repair was made.

Rollback remains a separately reviewed forward corrective migration under the [Staging deployment runbook](../runbooks/atlas-staging-deployment.md). No migration deletion or business rollback was performed.

## 4. Hosted baseline after action

Supabase MCP confirmed **91/91** hosted entries, tip `20261005032608_atlas_shopping_list_export_read`. Read-only repository catalog verification passed with the unmodified current authority: **115 API identities**, including **112 authenticated-executable identities**.

| Structural fingerprint     | Before and after                   |
| -------------------------- | ---------------------------------- |
| Relations / owners / RLS   | `0d489ffbaef4a1491d94dfa6e71c9c13` |
| Columns / types / defaults | `49067c8f1a96722eeeafc64f430f2e2d` |
| Constraints                | `1266a28a05114f311911c9939e4425de` |
| Index definitions          | `c01dac6dad547559a864a7f3beb3601c` |
| User trigger definitions   | `03b5720e8392f06205aa1faf81652de8` |
| View definitions           | `85a2f8e6ceb1693f34eaeac9d9026de1` |

All **439 existing function bodies** retained their observed pre-action hashes. The new function body matched the repository migration exactly after line-ending normalization. No unrelated relation, constraint, index, trigger or view changed.

All **113 Atlas tables**, containing **32,070 rows**, retained both row counts and content digests. This includes command receipts, domain events, audit events, allocations, PO and PXK evidence. The ordered `{relation,row_count,digest}` snapshot SHA-256 was identical before and after:

`1a6594ed836ff91ba5d923c404622b149ac779e94958eeb923dab403c0f404c9`

The read-only snapshot iterated catalog-listed ordinary Atlas tables, counted rows and hashed sorted per-row `md5(to_jsonb(row)::text)` values. Only counts and digests were retained; no business payload was exported. **Hosted business writes: 0.** These observations prove no net business-row changes during the migration verification window, alongside the reviewed migration's absence of a business writer.

## 5. API, grants and Auth

| Contract check                                      | Observed result                                                                      |
| --------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Function                                            | `atlas_api.get_confirmed_need_shopping_list_export(request jsonb) RETURNS jsonb`     |
| Owner                                               | `atlas_confirmed_need_review_runtime`                                                |
| Runtime posture                                     | STABLE, SECURITY DEFINER, fixed empty `search_path`                                  |
| ACL                                                 | Owner execute and `authenticated` execute only                                       |
| PUBLIC / anon / service_role execute                | false / false / false                                                                |
| Runtime schema CREATE after migration               | false                                                                                |
| PostgreSQL maintenance SET for owner/review runtime | false after the migration                                                            |
| Delegated authorization/currentness                 | Existing `get_confirmed_need_review`; unchanged body and owner/grants                |
| Supplier advice helper                              | Exists; review runtime has required execute access                                   |
| Managed identity mapping                            | Exactly one active managed Actor/Auth-subject mapping                                |
| Required read capability                            | Managed role has `confirmed_need_review.read`                                        |
| Auth endpoint                                       | Settings reachable; email/password enabled, phone disabled; signup currently enabled |

Actual anonymous HTTP probes of both Confirmed Need review and Shopping List export returned **HTTP 401 / PostgreSQL 42501**, `permission denied for schema atlas_api`. The successful platform verifier separately established configured Data API exposure and its required anonymous denial. An authenticated successful export has **not** been claimed.

Security advisor output contained the expected authenticated SECURITY DEFINER warnings for Atlas's deliberately authorized RPC surface, including the new function. The new RPC delegates the existing Actor/JWT/capability/GLOBAL authorization and has the prescribed fixed search path. The advisor also reports disabled leaked-password protection, an existing Auth configuration observation outside this migration; no Auth settings were changed. See [advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). This task does not certify overall Auth hardening or operator sign-in.

## 6. Existing connected deployment

- Stable hosted URL: <https://thuonghao-ops-erp.pages.dev/>.
- Immutable reviewed URL: <https://fe48c00a.thuonghao-ops-erp.pages.dev/>.
- Both `_atlas-build.json` manifests report the requested SHA, `dirty=false`, `entrypoint=AtlasVNextConnectedApp`, and `supabaseOrigin=https://rnzxmxiiqgtdevzregff.supabase.co`.
- GitHub's successful Cloudflare Pages check on this exact main SHA identifies the immutable deployment. Existing Git integration already published main; no new hosting mechanism or frontend redeploy was required.
- Protected `atlas-staging` variables confirm `VITE_ATLAS_ENVIRONMENT=staging`, the same Staging URL and project reference.
- The immutable app rendered its normal Email / Mật khẩu / Đăng nhập screen. An approved operator sign-in was requested; the available browser remained signed out at the last observation. Credentials were not copied, reset or manufactured.

## 7. Existing review facts and bounded rehearsal matrix

No seeding or business-data creation was necessary to establish that existing review candidates are present. Read-only inventory found:

| Existing facts                                |               Count |
| --------------------------------------------- | ------------------: |
| Schools / Ingredients / Suppliers / Dishes    | 44 / 377 / 37 / 662 |
| Recipe roots / versions                       |       1,323 / 1,397 |
| Menu / Attendance / Pantry source aggregates  |           5 / 5 / 5 |
| Need Generation runs / Confirmed Need batches |              12 / 8 |
| PO / School PXK roots                         |               7 / 4 |

Candidate review scopes include the approved Menu/Attendance/Pantry week starting `2026-09-14`, exact-day `2026-09-17` Draft Review Need (batch version 3), and retained synthetic Scenarios A/B/C on `2046-09-17`–`2046-09-19`. These are candidates only: connected authoritative currentness, editability, Recipe eligibility and downstream coverage must be read after sign-in. Presence of rows does not establish rehearsal readiness. Released documents must remain unchanged; no source reopen or new operational fact was forced.

All rows below are **NOT RUN — OPERATOR AUTH REQUIRED**. Database inventory and local tests are not recorded as operator success.

| Exact step                                | Expected connected behavior / authority                                                                           |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Master Data                               | Read existing governed identities and controlled Unit display; RMVP-01                                            |
| Recipe                                    | Resolve effective typed context at explicit date, retain editing/lock boundaries; RMVP-02A/B, D-038               |
| Menu                                      | Inspect existing accepted source and Google Sheet provenance; RMVP-03A                                            |
| Attendance                                | Inspect accepted exact quantities, retain explicit zero semantics; RMVP-03A                                       |
| Pantry                                    | Inspect approved additions or explicit no-additions; PANTRY-02 / direct Need contract                             |
| Planning readiness/currentness            | Backend derives source readiness/currentness; RMVP-03B, D-047                                                     |
| Need Generation                           | Normal transactional command only when existing prerequisites allow it; RMVP-04                                   |
| Confirmed Need                            | Read authoritative quantities and source/version lineage; RMVP-05 / D-037                                         |
| Shopping List export                      | Fresh complete exact-day authority, advisory Supplier names, controlled Unit, hidden lineage; Shopping List V1    |
| Shopping List import                      | Whole-workbook quantity-only local proposal, no partial apply or DB write; Shopping List V1                       |
| Need Save / Release / Continue            | Explicit Save business command and authoritative release eligibility; D-037 / Procurement contract                |
| Supplier Allocation / Apply + Save        | Exact human split, Apply remains local until explicit Save; purchase review contract                              |
| Purchase preparation / PO draft / release | Backend-generated support and explicit immutable supplier commitment; school-catering Procurement contract        |
| School PXK                                | Current Need/allocation/released-PO coverage, explicit immutable release; school-dispatch contract                |
| PO / PXK reconciliation                   | Read authoritative source comparison without inventing Warehouse facts; school-fulfilment reconciliation contract |

No missing business fact was established as a blocker: **MISSING_REVIEW_DATA = NOT YET ASSESSED THROUGH CONNECTED APIS**. If a prerequisite is absent after sign-in, record DATA_GAP with classification MISSING_REVIEW_DATA and stop that dependent step; do not seed it automatically.

## 8. Persistent Workspace and performance

The following hosted checks remain **NOT RUN — OPERATOR AUTH REQUIRED**:

- Open Planning, Procurement, Recipes and PXK; switch repeatedly with no activation reads or remount.
- Retain independent dates, dirty Need, Procurement search/detail/stage, Recipe edits and PXK note/selection.
- Guard active and inactive dirty close; block dirty voluntary sign-out.
- Need → unopened Procurement seeds exact date + Allocation; already-open Procurement retains context and shows a discrepancy notice when required.
- Observe switching responsiveness and blocking renders separately from real authenticated API latency.

Focused existing local tests passed: **35/35 across four files** (`shoppingListService`, Shopping List precision, `AtlasPersistentWorkspace`, `AtlasWorkspaceHandoff`). These support the retained contracts but do not replace connected hosted evidence. No hosted switching benchmark was collected. Anonymous probe wall times were 993 ms for review and 299 ms for export; they are gateway/denial timings, **not** business-read or UI-switch timings. The prior local 181 ms desktop / 126 ms narrow medians remain historical fixture measurements only.

No caching, polling, Redux/Zustand, virtualization, background sync or unmount-on-switch change was made.

## 9. Shopping List safety review

Source review of `shoppingListService.ts` and the connected Need import bridge confirms the retained operator safety property: export uses the dedicated read projection and exact-day preflight before/after coherent pagination; import rereads ordinary Confirmed Need authority, validates the whole workbook and returns drafts only. The bridge checks captured date/workbench/draft/Auth context before updating local drafts. Supplier advice neither creates allocation nor stales imported quantities. Explicit Save remains the business command.

This matches the supplied OPS v1 Retool workflow evidence that XLSX import changes local state and requires explicit Save. Retool was not modified or re-inspected. Hosted workbook download/upload, edited quantity proposal, no-partial-import rejection, stale rejection and explicit Save remain pending authenticated rehearsal.

## 10. Findings and bounded ownership

| ID / classification    | Exact step                            | Expected / actual                                                                                                               | Authority                                     | Severity / reproducibility                       | Recommended bounded owner                                                                           |
| ---------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| F-01 WORKFLOW_FRICTION | Hosted operator sign-in before Step 7 | Approved authenticated session available / available tab remains at sign-in; no protected test credential is accessible locally | Task Steps 5–8; PA-06A Auth boundary          | Rehearsal blocker; repeated browser observations | Staging operator/access owner: sign in using existing approved account, then resume this matrix     |
| F-02 NOT_A_DEFECT      | Preflight function-body comparison    | Same repository command semantics / validator differs only in formatting; identical non-whitespace text and literals            | Reviewed clock-skew migration                 | Informational; deterministic comparison          | No correction                                                                                       |
| F-03 NOT_A_DEFECT      | Post-migration security advisor       | Authenticated SECURITY DEFINER export with delegated authorization / generic warning flags that intended posture                | Shopping List V1; PA-03; exact catalog/grants | Informational; reproducible advisor result       | No RPC/grant correction; Auth configuration observations remain with the environment security owner |

No APPLICATION_DEFECT, BACKEND_CONTRACT_DEFECT, STAGING_PARITY_DEFECT, VISUAL_POLISH or PERFORMANCE defect was demonstrated. This is a limited result because the operator journey did not execute. Data absence was not mislabeled as an application defect.

## 11. Freeze readiness and next gate

**NOT READY:** technical parity and current connected deployment are verified, but successful authenticated Shopping List execution, the operational Save/release path, workspace retention/guards/handoff and hosted performance observations remain outstanding. Product/Architecture acceptance is also outstanding.

Next action: resume **ATLAS-STAGING-PARITY-REHEARSAL-01** after approved operator sign-in; reuse the existing candidate facts and record actual API currentness/data gaps before consequential commands. Then resolve only observed bounded findings and prepare **PLANNING-PROCUREMENT-FREEZE-01**. No automatic merge, production activation or Warehouse work is authorized by this evidence.

Ponytail FULL: reused the existing catalog verifier, migration/deployment workflow and review facts; added no parity helper, seed machinery, deployment plumbing or application abstraction. Repository validation for this documentation-only delivery uses focused Markdown formatting/whitespace checks and the Draft PR's required GitHub frontend CI.
