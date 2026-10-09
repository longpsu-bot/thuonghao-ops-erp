# School cooking groups — Document System Class C amendment

Authority: the Product Owner's bounded amendment to PR #360, recorded in
`TASK-ATLAS-DOCUMENT-SYSTEM-01.md`. Admin owns one optional current School cooking
group; School remains the business recipient. Cooking group is distinct from
Customer grouping, issuer, delivery location, and export packaging.

`atlas_admin.cooking_groups` stores UUID identity, trimmed 1–200 character name,
boolean `active`, optimistic `version`, and ordinary creation/update timestamps.
`atlas_admin.school_cooking_group_memberships` has School UUID as primary key and
a required group UUID foreign key. Absence means no group. No approval, effective
dating, membership lifecycle, or membership history is added.

## Admin APIs

All three APIs use existing `RMVP-01.v1` envelopes and GLOBAL Admin authorization.
Reads require `master_data.read`; writes require `master_data.schools.write`.
Tables force RLS and have no browser/service-role table grants. APIs use existing
dedicated runtimes, fixed empty search paths, and authenticated-only execution.

| Function                          | Payload                                                                           | Result                                                                                                      |
| --------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `get_cooking_groups(jsonb)`       | `{}`                                                                              | `cooking_groups: [{ cooking_group_id, cooking_group_name, active, version }]`, including inactive groups    |
| `upsert_cooking_group(jsonb)`     | `{ cooking_group_id: UUID or null, cooking_group_name: string, active: boolean }` | Standard command result with `affected_aggregate_ids.cooking_group_id` and `new_versions.aggregate_version` |
| `set_school_cooking_group(jsonb)` | `{ school_id: UUID, cooking_group_id: UUID or null }`                             | Standard command result with `affected_aggregate_ids.school_id` and updated School version                  |

Creation uses explicit null group ID and expected version `1`; update uses current
group version. Group saves require reason `COOKING_GROUP_SAVED`. Assignment and
clearing use current School version and reason `SCHOOL_COOKING_GROUP_SET`. Clearing
requires explicit null. Unknown payload fields and invalid/null types are rejected.
Every success emits existing domain/audit events and completes an idempotent receipt.
Exact replay returns the original response; conflicting replay or stale version
cannot overwrite facts.

Only active Schools can receive an active existing group. Missing group returns
`NOT_FOUND`; inactive group returns `COOKING_GROUP_INACTIVE`; inactive School returns
`SCHOOL_INACTIVE`. A group with members cannot deactivate
(`COOKING_GROUP_HAS_MEMBERS`); operators must move or clear its Schools first.
Relational guards also reject School deactivation while membership exists.
Assignment locks School then target group; group updates lock the group and reject
members, serializing assignment against deactivation. PK identity enforces zero or
one group per School; many Schools may share a group.

The existing `get_school_master_data` response adds nullable `cooking_group_id` and
`cooking_group_name` to every School row. No new School endpoint is introduced.

## Released snapshots

New official PO line inserts freeze nullable `cooking_group_id` and
`cooking_group_name` in each School entry of `school_breakdown_snapshot`. New PXK
release inserts freeze `cooking_group_id_snapshot` and `cooking_group_name_snapshot`;
released shaped reads expose these as `cooking_group_id` and `cooking_group_name`.
No group address is stored. Ungrouped snapshots carry nulls.

Both capture paths consume the same current Admin membership. Later moves, removal,
group rename, or deactivation do not alter released snapshots. New captures use
current facts. Old releases are not backfilled: absent/null values remain ordinary
School headers. Exporters never reconstruct `Nấu tại` from current Admin data or
text heuristics. School IDs and exact quantity lineage remain intact.

PO `Ghi chú` remains frozen `supplier_note_snapshot`; PXK row `Ghi chú` is blank
physical working space, with the release note retained at document level. This
amendment does not resolve outward-code or released PO Ingredient/Unit label gaps.

## Verification and rollback

`atlas_school_cooking_groups.sql` covers mutations, replay, versions, activity
constraints, capability/scope denials, and private security posture. Existing PO/PXK
suites cover capture and immutable history after moves, rename, and removal. The
exact platform catalog includes the two tables, three APIs, guards, policies/grants.

Forward migration: `20261009075715_atlas_school_cooking_groups.sql`. It seeds no
membership, reads no legacy/hosted data, and performs no historical backfill. Legacy
adoption requires explicit PO/Dispatch reconciliation; absent retained values remain
`COOKING_GROUP_RECONCILIATION_REQUIRED`. Forward rollback disables new maintenance
or exposure while retaining current and frozen facts. Dropping released snapshot
columns is not a valid rollback.
