# OPS v1 Recipe Change Order history

Owner-authorized scope, 5 November 2026: preserve surviving OPS v1 Change Order
records for staff review. This is supporting migration evidence, not a new
business lifecycle or a second effective-composition authority.

## Decision

Import source history as **read-only evidence**. Do not replay it into native
RecipeCompositionAdjustment roots or released operational documents. Source
discovery found 603 surviving rows, 17 inactive rows without cancellation dates,
an empty override audit log, and multiple active rows for 25 system targets.
Those observations are not a complete historical event stream. Activating legacy
rules requires a separate exact-context BOM reconciliation; this task does not
change calculation precedence or activate any rule.

Preserve each source record, stable source identity, original effective date,
source active flag, exact decimal text, notes and available creation timestamp.
Never represent source active as currently effective. Never invent original
issuers, approval, supersession or cancellation times. Import Actor/time describe
the technical import only. Historical BOM reconstruction remains the existing
backend resolver's responsibility and does not consume this archive.

## Snapshot and import

`OPS-V1-RECIPE-HISTORY.v1`, source `OPS_V1_RECIPE_HISTORY`, is an immutable,
SHA-256-checksummed snapshot of the four allowlisted source tables:
`ingredient_change_orders`, `system_bom_change_orders`, `school_wide_overrides`,
and `school_recipe_overrides`. One SQL statement captures rows and counts from
one database snapshot through the existing management read-only endpoint.
Require either a verified read-only role or a connected non-superuser in a
database-enforced READ ONLY transaction; require bypass-RLS visibility for source
completeness, record the actual privilege evidence, and never change source grants.
Reject unexpected source projects, duplicate
identities, missing arrays/count mismatches and malformed records.

`pnpm local:recipe-history -- --export --output PATH --snapshot-id ID` exports
privately without overwriting an existing file. It uses the existing
`ATLAS_STAGING_SUPABASE_ACCESS_TOKEN` environment variable, never a command-line
credential. Raw source snapshots must remain outside Git.

`pnpm local:recipe-history -- --file PATH` previews against the existing guarded
`atlas-master-rehearsal-01` disposable loopback target selected by
`SUPABASE_WORKDIR`. Apply additionally requires `--apply --actor-id UUID
--plan-checksum SHA256`. The private postgres-only importer writes only a
completed `atlas_legacy.import_batches` receipt containing the snapshot. There
is no hosted runner. Same identity/content replays; changed content under the
same identity rejects. Preserve prior snapshots and rows absent from later
snapshots. No source write, native adjustment write or master-data creation is
allowed.

## Existing operator read and UI

The existing `RMVP-02B.v2` `get_recipe_adjustment_operator_workbench` response
adds optional `workbench.legacy_history[]`. Missing means no archive support;
an empty array means no imported evidence. Malformed populated arrays fail the
frontend parser. Existing request versions and browser RPC names are unchanged.

Each history row contains `source_table`, `legacy_id`, `scope_kind`, `action`,
`source_active`, nullable `effective_from`, `source_created_at`, `quantity`,
`unit_name`, `dish_name`, `school_name`, `ingredient_name`, `substitute_name`,
`source_school_type_id`, and `note`. Quantities remain decimal strings. Read the latest observation per
source identity across completed snapshots; disappearance never deletes evidence.
The existing global adjustment-read capability authorizes this read. Browser
roles retain no direct private-table access. The read runtime receives SELECT
only for completed receipts of this exact source through forced RLS.

The existing Change Order workbench exposes a collapsed, searchable, bounded
read-only source-history section. It distinguishes original effective date from
current applicability, identifies inactive source records without claiming a
cancellation date, and offers no edit/cancel/activate action on imported history.

## Acceptance and rollback

Test complete extraction, read-only endpoint/role enforcement, exact decimals,
duplicates/counts/checksum rejection, Preview with no writes, Actor-bound Apply,
idempotent replay, cross-content conflict, retained disappeared rows, native
root preservation, forced RLS and unauthenticated/private-function denial. Test
UI disclosure, filtering, bounded rows and truthful inactive/unknown attribution.
Run focused checks; GitHub Actions owns full frontend validation.

No existing table, lifecycle, capability or public RPC is added. After a real
import, preserve receipts: rollback is a reviewed forward correction disabling
archive display/access, not deletion of historical evidence. No Staging apply,
Production write, deployment, merge or Warehouse work is part of this task.

## Local evidence — 5 November 2026

The independent `atlas-master-rehearsal-01` stack uses ports 553xx. Full migration
reset succeeded. A real snapshot taken through the connected Supabase tool in an
explicit READ ONLY transaction retained the actual `postgres` privilege metadata
and transaction state, without changing source grants. Snapshot checksum:
`c716605cf7a766ecc6165d1f6532ecdbcb944c588a9b6723501078edf0d7fd8d`.

Preview, Actor-bound Apply and identical replay retained all 603 source rows;
readback counted 603 rows including 17 inactive. Native roots and revisions stayed
at zero in the disposable database. The migration importer created no native
authority. Focused pgTAP additionally tests the authenticated read and denied
identity. Raw files and screenshots remain private outside Git.

Playwright rendered the shaped backend history at 1440px and 390px: explicit
disclosure, 25/50-row expansion, search, local table scrolling and no document
horizontal overflow or page errors passed. This is component-level evidence, not
a hosted deployment or full operator acceptance certification.

The shared local-query decoder also accepts the pinned CLI's `{rows, boundary}`
envelope while preserving support for its older array shape and rejecting invalid
result cardinality. This compatibility correction is covered by focused tests.

Security catalog reconciliation pins 690 normal policies, 375 private functions,
and 1,918 positive runtime grants. The delta is one source-restricted read policy,
two private fixed-path invokers, and three read-runtime privileges. Public RPC,
browser grants, schema/table/role/capability counts and forced RLS are unchanged.
Focused local results: 32 Recipe history pgTAP checks, 32 platform catalog checks,
185 frontend/script checks, and TypeScript pass. GitHub Actions remains the owner
of full routine validation.
