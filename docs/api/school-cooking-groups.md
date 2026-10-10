# School cooking locations and Dispatch groups

Authority: Owner task `TASK-ATLAS-DOCUMENT-SCHOOL-GROUPING-02.md`, superseding
export combination by cooking group. Admin retains the existing cooking-group
UUID/name authority as the physical Cooking Location; it does not create a second
competing location table. School remains the business recipient.

## Explicit independent facts

`atlas_admin.cooking_groups` retains identity, name, active, version and timestamps,
and adds `location_kind: SCHOOL | COMPANY | null` plus nullable `host_school_id`.
SCHOOL requires an existing School UUID. COMPANY requires a null host and the exact canonical name `Công ty Thượng Hảo`. Legacy
unresolved locations retain null kind/host until explicitly resolved; names never
infer kind or host. `school_cooking_group_memberships` remains one current optional
location per School, with School UUID as PK. No membership dating/history is added.

`atlas_admin.dispatch_groups` stores independent UUID, trimmed 1–200 character
name, active, version and timestamps. `atlas_admin.dispatch_group_members` has
School UUID as PK and a required Dispatch group FK. Absence means no membership.
A cooking assignment never creates or changes Dispatch membership, or vice versa.

## Admin APIs

All APIs retain `RMVP-01.v1`, GLOBAL authorization, `master_data.read` for reads
and `master_data.schools.write` for writes. Tables force RLS with no browser or
service-role table grants. Fixed empty paths, dedicated runtime owners and
explicit authenticated-only execution preserve the existing security boundary.

| Function                    | Payload                                                                           | Result                                                                                                       |
| --------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `get_cooking_groups`        | `{}`                                                                              | `cooking_groups: [{ cooking_group_id, cooking_group_name, active, version, location_kind, host_school_id }]` |
| `upsert_cooking_group`      | `{ cooking_group_id, cooking_group_name, active, location_kind, host_school_id }` | Existing command result with affected Cooking Group identity/version                                         |
| `set_school_cooking_group`  | `{ school_id, cooking_group_id: UUID or null }`                                   | Updated School identity/version                                                                              |
| `get_dispatch_groups`       | `{}`                                                                              | `dispatch_groups: [{ dispatch_group_id, dispatch_group_name, active, version }]`                             |
| `upsert_dispatch_group`     | `{ dispatch_group_id: UUID or null, dispatch_group_name, active }`                | Affected Dispatch Group identity/version                                                                     |
| `set_school_dispatch_group` | `{ school_id, dispatch_group_id: UUID or null }`                                  | Updated School identity/version                                                                              |

Create uses null group ID and expected version 1; update uses the current group
version. Cooking save/assignment reasons remain `COOKING_GROUP_SAVED` and
`SCHOOL_COOKING_GROUP_SET`; Dispatch uses `DISPATCH_GROUP_SAVED` and
`SCHOOL_DISPATCH_GROUP_SET`. Assignment/clear uses the current School version;
clear requires explicit null. Every successful mutation records the existing
idempotency receipt, domain event and audit evidence. Exact replay returns the
original response; stale versions and conflicting replay cannot overwrite facts.

New Cooking Locations require explicit kind and host fields. Legacy update
envelopes omitting both remain callable for existing IDs and preserve stored
kind/host. Partial facts, unknown fields and invalid/null types reject. A new
assignment to unresolved location returns
`COOKING_LOCATION_RECONCILIATION_REQUIRED`. Missing targets return `NOT_FOUND`;
inactive target returns `COOKING_GROUP_INACTIVE` or `DISPATCH_GROUP_INACTIVE`.
Inactive Schools cannot receive membership (`SCHOOL_INACTIVE`). Groups with
members cannot deactivate (`COOKING_GROUP_HAS_MEMBERS` or
`DISPATCH_GROUP_HAS_MEMBERS`); membership also prevents School deactivation.

`get_school_master_data` adds nullable `cooking_location_id`,
`cooking_location_name`, `cooking_location_kind`,
`cooking_location_host_school_id`, `dispatch_group_id` and `dispatch_group_name`.
It preserves `cooking_group_id`/`cooking_group_name` compatibility aliases.

## Frozen operational evidence

Future official PO School breakdown entries and PXK release reads capture the
same six canonical fields, retaining cooking compatibility aliases. PXK stores
corresponding `_snapshot` columns. The private command-runtime locking helper
locks ordered Schools, then ordered cooking and Dispatch groups before capture;
assignment guards and group updates serialize changes against this capture.

PO never combines different Schools for shared Cooking Location or Dispatch
membership. Dispatch packaging may combine captured group/date/Ingredient/Unit/
operational-note partitions while retaining every School/source identity and exact
quantity. Self-cooking labels compare host School UUID with recipient UUID.
Unresolved kind/host does not fabricate self-cooking or a suffix. Exporters consume
frozen evidence only. Reassignment, rename, clear and deactivation preserve old
releases. Historical absent/null fields remain absent/null; no backfill is run.
School breakdown UPDATE is guarded, including historical null evidence; PXK's
existing full-row immutable guard covers every new snapshot column.

## Verification and rollback

`atlas_document_school_grouping_02.sql` verifies explicit facts, independent
mutation, replay/version checks, denied capabilities and private forced-RLS
security. Existing cooking, PO and PXK suites preserve prior assertions and cover
typed snapshots and history after rename/reassignment/removal. The exact platform
catalog checks every added API, policy, owner and reviewed positive grant.

Append-only migration: `20261010102603_atlas_document_school_grouping_02.sql`.
It seeds no identities/memberships and writes no staging, live OPS or Retool data.
Hosted configuration stays blocked by `SCHOOL_MASTER_RECONCILIATION_REQUIRED`
until explicit source-to-Atlas identities are reconciled. Forward rollback revokes
new authoring/exposure while retaining current and frozen facts. Dropping snapshots
or reconstructing released values from current master data is not a valid rollback.
