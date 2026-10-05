# ATLAS-SHOPPING-LIST-XLSX-V1-CONNECTED-01

Status: IMPLEMENTED; native certification and final read-only audit PASS. Product
readiness additionally requires the final pushed head's required Frontend CI PASS.
Frozen authority: merged PR #347, starting main
`887be1b5df14bf6a45557c8b0514fe0e992a8645`.
Authorized checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`.
Branch: `feat/atlas-shopping-list-xlsx-v1-connected-01`. Draft PR only; no merge.

## Implementation plan and scope

Primary owns all edits. `TERRA_NOT_AVAILABLE`: requested Terra is absent from
the callable subagent model list. A read-only GPT-6.1 Sol/high reviewer completed
Contract Guardian preflight and final audit (PASS). Terra was not represented as
the reviewer. The primary model identifier is not independently exposed by this
desktop session; GPT-6.1 Sol was requested, with no availability blocker.

1. Replace legacy codec with frozen constants, exact numeric XML, bounded OPC
   parsing, closed metadata and complete Tables. Build 1–7-date collections from
   separate complete daily authorities. Only quantities become local proposals.
2. Load all authorized pages coherently. Refresh daily preflight and current line
   facts on import; refresh saved facts for export. Expose only existing backend
   Supplier advice names through one additive read-only export RPC.
3. Wire exact-day callbacks. Disable both actions while dirty/read-only/busy;
   discard asynchronous proposals when drafts/context/authority change.
4. Replace obsolete pre-contract assertions and retain AUD-003 exactness. Add
   schema conformance, negative structural/currentness controls, pagination,
   restart, no-write, UI and Supplier SQL coverage.
5. Generate a production workbook, certify native Excel16 edit/SaveAs/reopen/full
   Table sort and all native PDF pages. Complete read-only adversarial review,
   focused checks and final-head GitHub CI before Product readiness.

Allowed: Confirmed Need Shopping List modules/API, connected wiring, bounded
workbench controls/bridge and tests, one read-only migration/tests, affected docs.
Prohibited: Procurement/Dispatch behavior, new persisted business facts, automatic
Save, reason/note import, weekly Need state, new dependency, hosted deployment.

`MULTI_DATE_UI_DEFERRED_BY_EXACT_DAY_WORKBENCH`: no approved multi-date Need
draft surface exists. Current UI exports/imports only its exact date. Structurally
valid multi-date workbooks receive a capability error and make no local changes.
The core codec supports 1–7 daily batches atomically.

## Preflight findings

Legacy code used SL, draft quantities/notes, Unit code, landscape, 17 hidden
columns and no Table/meta envelope. Cached authority, binary numeric parsing,
missing current-step checks and unguarded asynchronous application were gaps.
Existing Unit name and backend Supplier helper are suitable; no new Unit field
or Supplier business rule is needed. Fresh authorized readback remains authority.

## TDD and evidence

Initial new codec suite: RED, 23 failures against legacy interface/behavior,
including raw parser exception leakage. Codec implementation: GREEN 23/23.
Supplier RPC pgTAP: RED 2/2 missing API; initial authorized read GREEN 2/2.
Service tests initially failed due missing service; coherent pagination, restart,
read-only/dirty and exact-day capability tests subsequently passed.
Final focused run: 7 suites, 166 tests PASS. Final TypeScript build-mode typecheck
PASS; `pnpm ui:vnext:check` PASS; `pnpm ops:workspace` PASS for the authorized
checkout (historical D-drive path is advisory). Supplier read RPC pgTAP: 17/17
PASS on local Supabase, including privilege/authorization and unchanged business
table counts. Full routine validation belongs to the required GitHub PR check.
The final connected-root factory assertion also passes (1/1), and the boundary
checker regression suite passes (44/44). Targeted formatting and diff whitespace
checks pass.
The first PR CI run exposed stale exact registry/catalog snapshots for the new
read RPC. Updated explicit entries/counts, owner mapping and authenticated
allowlist: transport 18/18 and whole-platform security catalog 28/28 PASS. The
grant fingerprint changes by exactly two nongrantable EXECUTE rows (dedicated
owner and authenticated); table/RLS/policy/private-helper fingerprints remain
unchanged. No production code or migration change was needed for this correction.
The staging catalog parser's dependent snapshot was also updated to the same
115 physical / 112 authenticated functions with explicit export-RPC membership.
Its 110 focused tests pass; compatibility-read exclusions remain in force.

## Production certification and closeout

The [production workbook](../xlsx/qa/connected-v1/production.xlsx) contains three
daily batches and 59 rows. The codec supports 1–7 dates; the connected exact-day
workbench deliberately rejects multi-date proposals before applying any change.
The [native edited workbook](../xlsx/qa/connected-v1/native-edited.xlsx) was opened
in Excel 16 without repair, edited, sorted using the full Table, saved and reopened.
Production import recovered exactly the edited line's quantity, preserved reasons
and made no backend command. [Native evidence](../xlsx/qa/connected-v1/native-excel.json)
and [local authorized round trip](../xlsx/qa/connected-v1/local-round-trip.json)
record these checks. The local read test uses rolled-back existing fixtures.

All exported quantities use shortest exact decimal text. V1 permits numeric safe
values but does not require them. Native SaveAs changed a nominally safe numeric
`123456789.1` to `123456789.09999999`; text removes that drift and simplifies the
exporter. Numeric imports still parse original XML decimals/exponents exactly,
before JavaScript floating-point conversion. AUD-003 and changed-line step/scale
controls pass; stale authority rejects the whole workbook.

The [native PDF](../xlsx/qa/connected-v1/production.pdf) and all four raster pages
were reviewed by primary and independently by the read-only fallback reviewer.
The frozen native print validator passed: 4 pages, 24/20/12/3 body rows, A4
portrait, 96% scale, 17.28 pt effective primary text, all 59 exact quantities,
zero hashes, no clipping. School-only display, complete Supplier names, long
ingredient names and continuation labels fit. Excel's unprinted Normal-style
font is Carlito 11, matching F13's column geometry; populated cells retain the
frozen Times New Roman sizes. Native PDF preview was inspected; interactive
Excel Print Preview was not separately automated.

Reproduce codec/native import checks with
`node scripts/certify-shopping-list-v1.mjs --verify-native`; add `--local` for
local authorized RPC readback. Print verification:
`python -X utf8 docs/xlsx/examples/validate-native-print.py docs/xlsx/qa/connected-v1/production.pdf docs/xlsx/qa/connected-v1/production.xlsx`.

Artifact SHA-256:

- Production XLSX: `C416109087531BC06284E427B6E2FE3318037995521A4F1F34819E93AAF55425`
- Native edited XLSX: `5A0973D40CF0FF823CC09381854AFB52DAA2052664BADE34EEAD6FC2B2481E42`
- Native PDF: `D5E15D9818EC0C3D601E6BBF9E5D4433324A130702D7E147D37A4B84CEBC3C23`

Final adversarial verdict: PASS, GPT-6.1 Sol/high read-only fallback. Resolved
findings: E date scalars are ignored, all cell/Table/validation formulas are
rejected, and each School retains a canonical label. Fresh saved authority,
pagination completeness, async context guards, no-write import, exact identity,
bounded OPC validation and Supplier security have no remaining review blocker.
Ponytail audit removed redundant wrappers/options and numeric export rewriting;
no dependency was added. Remaining operational work is Product review and any
separately authorized hosted migration deployment. This task creates a draft PR
only and does not merge or deploy.

## Security and rollback

Supplier RPC delegates the existing RMVP-05 authorization to
`get_confirmed_need_review`, uses the same dedicated runtime and fixed empty
search path, and exposes names keyed only to authorized page lines. EXECUTE is
revoked first; authenticated users still require the existing Actor/capability/
GLOBAL-scope checks. Temporary CREATE/SET privileges follow migration conventions
and are removed. No public/anon/internal-helper exposure or direct-table client.

One additive function migration; no table/column/trigger/write-path change.
Rollback requires reverting the connected frontend and then revoking/dropping
`atlas_api.get_confirmed_need_shopping_list_export(jsonb)` in a reviewed migration.
No business data rollback is needed. Local SQL tests use rolled-back fixtures.
Hosted Supabase, Retool, OPS v1 and hosted business writes: 0.
