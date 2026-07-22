# Decision PA-06E-H0B1b — Confirmed Need persistence

**Status:** Accepted and implemented for local/private persistence

**Date:** 2026-07-22

**Issue:** [#135](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/135)

**Authority:** Issue #135, [Decision PA-06E-H0B1](decision-pa-06e-h0b1-confirmed-need-identity-membership.md), merged H0A1/H0A5b persistence, the [PA-06E-H0 contract](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md), PA-01 through PA-03, and the merged PA-04/PA-05D database contract.

## Outcome

The private Planning aggregate now supports exactly two source kinds:

```text
WHOLESALE
NEED_GENERATION
```

The existing relations atlas_planning.confirmed_need_batches, atlas_planning.confirmed_need_lines, and atlas_planning.confirmed_need_line_revisions are generalized in place. Exactly one relation, atlas_planning.confirmed_need_line_revision_contributions, is created.

No command, API, event, receipt, audit surface, application code, generated type, hosted deployment, or production-data action is part of this decision. H0C materialization and H1 review/decision work remain separate.

## Typed source families

source_kind is required at batch, stable-line, and revision level and defaults to WHOLESALE solely so unchanged PA-05D inserts remain compatible.

- A WHOLESALE batch has wholesale_order_id and no Need Generation origin/current fields. Its lines and revisions retain their exact Wholesale source IDs and have no school-catering source fields or contributions.
- A NEED_GENERATION batch has no Wholesale source. It has complete origin and controlled-current triples of run ID, released run version, and release snapshot ID. Its stable lines and revisions have complete Need Generation and operational identity families.
- Every child source kind must agree with its owner. Partially populated or mixed families are rejected.

The batch origin is immutable. Current initially equals origin and can advance only to the direct released successor in the same Planning Input Set, period, and linear predecessor chain. Historical revision sources are retained.

## Stable school-catering identity

The exact stable-line identity is:

```text
confirmed_need_batch_id
+ service_date
+ customer_id
+ school_id
+ delivery_location_id
+ ingredient_id
+ controlled_unit_id
```

It excludes Dish, Menu, Recipe, RecipeLine, Theoretical Need ID, source order, supplier, purchase Unit, actor scope, authorization concepts, tokens, hashes, JSON, and UI state.

The migration adds atlas_admin.schools (customer_id, school_id) as the required supporting unique key and reuses the existing same-customer delivery-location key. Restrictive composite foreign keys prove that School and destination belong to the captured customer. No Admin trigger is added.

## Physical column catalog

### confirmed_need_batches

Added columns:

- source_kind
- origin_need_generation_run_id
- origin_need_generation_run_version
- origin_need_generation_release_snapshot_id
- current_need_generation_run_id
- current_need_generation_run_version
- current_need_generation_release_snapshot_id

wholesale_order_id becomes nullable only by the mutually exclusive source-family check.

### confirmed_need_lines

Added columns:

- source_kind
- service_date
- customer_id
- school_id
- delivery_location_id
- ingredient_id
- controlled_unit_id

wholesale_order_line_id becomes nullable only by the mutually exclusive source-family check.

### confirmed_need_line_revisions

Added columns:

- source_kind
- confirmed_need_batch_id
- need_generation_run_id
- need_generation_run_version
- need_generation_release_snapshot_id
- service_date
- customer_id
- school_id
- delivery_location_id

The existing ingredient_id and unit_id carry the exact Ingredient and controlled Unit. Existing rows are backfilled with their owning batch ID before that column becomes required. wholesale_order_line_revision_id becomes nullable only by the mutually exclusive source-family check.

### confirmed_need_line_revision_contributions

The new relation has exactly:

- confirmed_need_line_revision_contribution_id
- confirmed_need_batch_id
- confirmed_need_line_id
- confirmed_need_line_revision_id
- need_generation_run_id
- need_generation_run_version
- need_generation_release_snapshot_id
- need_generation_release_snapshot_line_id
- theoretical_need_line_id
- service_date
- customer_id
- school_id
- delivery_location_id
- ingredient_id
- source_unit_id
- controlled_unit_id
- source_theoretical_quantity
- controlled_contribution_quantity
- created_at

The originating command remains on the owning line revision and is not duplicated.

## Supporting keys and restrictive proof

The implementation adds only the keys needed to bind typed facts:

- (customer_id, school_id) on Schools;
- exact release-snapshot-line ownership on H0A5b release snapshot lines;
- exact Theoretical Need source-fact ownership, with ACTIVE disposition enforced by the deferred guard;
- batch ID plus source kind;
- stable-line exact owner and operational identity;
- revision exact owner/source/operational identity; and
- revision plus Theoretical Need line membership uniqueness.

The contribution's exact child-carried fields omit source_kind and line_disposition by design. Separate supporting parent keys make its restrictive composite foreign keys possible, while the ordinary and deferred guards require NEED_GENERATION ownership and ACTIVE source disposition.

## No-conversion and membership invariants

For every contribution:

```text
controlled_unit_id = source_unit_id
controlled_contribution_quantity = source_theoretical_quantity
```

The source Unit and quantity equal the exact immutable Theoretical Need facts. The controlled Unit also equals the stable-line Unit and revision Unit. Different Units therefore create different operational lines.

Every Need Generation revision has nonempty, immutable, nondeletable membership. It contains every and only ACTIVE release member in its service-date/School/Ingredient/source-Unit group. Its theoretical_quantity equals the exact PostgreSQL numeric sum of controlled contributions. REMOVED members, substitutions, omissions, duplicates, conversion, rounding, clamps, residuals, and hidden allocations are rejected.

For the batch's controlled-current release, all current revision memberships form one exact disjoint partition: every active release line appears once, with no omission or duplication across lines, groups, or destinations. The invariant is enforced from the existing deferred batch/line current-source boundary and from revision/contribution membership changes. A released source with active members cannot own an empty Confirmed Need batch, and a stable line without a current revision cannot commit. An empty active-release set may have an empty partition. Historical, noncurrent, and superseded memberships remain immutable but do not participate in current-partition counting.

## Function and trigger catalog

Exactly three owner-only, security-invoker functions are created with an empty fixed search_path, fully qualified static SQL, owner atlas_owner, and no execution privilege for PUBLIC, API roles, service_role, or atlas_planning_command_runtime:

1. atlas_planning.pa_06e_h0b1b_confirmed_need_guard()
2. atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()
3. atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()

Exactly nine triggers are created:

1. confirmed_need_batches_h0b1b_guard
2. confirmed_need_lines_h0b1b_guard
3. confirmed_need_line_revisions_h0b1b_guard
4. confirmed_need_line_revision_contributions_h0b1b_guard
5. confirmed_need_batches_current_source_consistency
6. confirmed_need_lines_current_source_consistency
7. confirmed_need_line_revisions_current_source_consistency
8. confirmed_need_line_revisions_membership_total
9. confirmed_need_line_revision_contributions_membership_total

The final five are DEFERRABLE INITIALLY DEFERRED. No trigger is installed on an upstream H0A5b or Admin relation.

The partition correction reuses the existing functions and triggers. The catalogs remain exactly three functions, nine triggers, and five deferred triggers. The four-suite test and assertion catalogs also remain unchanged at 52, 56, 68, and 80 assertions (256 total), with 19 files and 1138 assertions in the registered regression.

## PA-05D and security compatibility

The three existing relations remain owned by atlas_owner, retain forced RLS, and retain the named pa_05d_planning_select and pa_05d_planning_insert policies and PA-05D runtime grants. Unchanged PA-05D commands create only WHOLESALE rows, with unchanged request/response, lifecycle, quantity, snapshot, downstream identity, event, receipt, audit, lock, and pass-through behavior.

The contribution relation is owned by atlas_owner, has RLS enabled and forced, has zero policies, and grants no privilege to PUBLIC, anon, authenticated, service_role, or atlas_planning_command_runtime. The canonical atlas_api registry remains 18 functions.

## Migration and rollback boundary

The change is one additive, version-controlled local migration. It does not seed rows or modify an earlier migration. Before deployment, rollback is a normal Git revert. After deployment, rollback requires a forward migration because the new typed columns, constraints, keys, functions, triggers, and membership relation may own authoritative history; destructive rollback is not authorized.
