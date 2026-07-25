begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(50);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name,
  actor_status,
  version,
  created_at
) values
  (
    'a6100000-0000-0000-0000-000000000001',
    'HUMAN',
    'H1A lifecycle creator',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6100000-0000-0000-0000-000000000002',
    'HUMAN',
    'H1A lifecycle approver',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6100000-0000-0000-0000-000000000003',
    'HUMAN',
    'H1A lifecycle activator',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6100000-0000-0000-0000-000000000004',
    'HUMAN',
    'H1A lifecycle retiree',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  );

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code,
  decimal_scale,
  unit_status,
  created_at
) values
  (
    'a6200000-0000-0000-0000-000000000001',
    'h1a_lifecycle_kg',
    'H1A lifecycle kilogram',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6200000-0000-0000-0000-000000000002',
    'h1a_lifecycle_count',
    'H1A lifecycle count',
    'COUNT',
    0,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6200000-0000-0000-0000-000000000003',
    'h1a_lifecycle_other',
    'H1A lifecycle other',
    'OTHER',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6200000-0000-0000-0000-000000000004',
    'h1a_lifecycle_history',
    'H1A lifecycle history',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6200000-0000-0000-0000-000000000005',
    'h1a_lifecycle_future',
    'H1A lifecycle future',
    'COUNT',
    0,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'a6200000-0000-0000-0000-000000000006',
    'h1a_lifecycle_cross',
    'H1A lifecycle cross Unit',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  );

insert into atlas_planning.planning_quantity_policies (
  unit_id,
  created_by_actor_id
) values (
  'a6200000-0000-0000-0000-000000000001',
  'a6100000-0000-0000-0000-000000000001'
);

select ok(
  (
    select
      planning_quantity_policy_id is not null
      and created_at is not null
    from atlas_planning.planning_quantity_policies
    where unit_id = 'a6200000-0000-0000-0000-000000000001'
  ),
  'H1A-LIF-01 database defaults populate root identity and creation time'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policies (
      unit_id,
      created_by_actor_id
    ) values (
      'a6200000-0000-0000-0000-000000000001',
      'a6100000-0000-0000-0000-000000000001'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "planning_quantity_policies_unit_key"',
  'H1A-LIF-02 duplicate root for one exact Unit is rejected'
);
select lives_ok(
  $$
    insert into atlas_planning.planning_quantity_policies (
      planning_quantity_policy_id,
      unit_id,
      created_by_actor_id,
      created_at
    ) values (
      'a6300000-0000-0000-0000-000000000002',
      'a6200000-0000-0000-0000-000000000002',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '1999-01-01 00:00:00+07'
    )
  $$,
  'H1A-LIF-03 distinct exact Units may own distinct roots'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policies
    set planning_quantity_policy_id
      = 'a6300000-0000-0000-0000-000000000099'
    where unit_id = 'a6200000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'planning quantity policy identity, Unit, creator, and creation time are immutable',
  'H1A-LIF-04 root identity is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policies
    set unit_id = 'a6200000-0000-0000-0000-000000000006'
    where unit_id = 'a6200000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'planning quantity policy identity, Unit, creator, and creation time are immutable',
  'H1A-LIF-05 root Unit is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policies
    set created_by_actor_id = 'a6100000-0000-0000-0000-000000000002'
    where unit_id = 'a6200000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'planning quantity policy identity, Unit, creator, and creation time are immutable',
  'H1A-LIF-06 root creator is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policies
    set created_at = created_at + interval '1 second'
    where unit_id = 'a6200000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'planning quantity policy identity, Unit, creator, and creation time are immutable',
  'H1A-LIF-07 root creation time is immutable'
);
select throws_ok(
  $$
    delete from atlas_planning.planning_quantity_policies
    where unit_id = 'a6200000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'planning quantity policies cannot be deleted',
  'H1A-LIF-08 root DELETE is rejected'
);

insert into atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id,
  unit_id,
  created_by_actor_id,
  created_at
) values
  (
    'a6300000-0000-0000-0000-000000000003',
    'a6200000-0000-0000-0000-000000000003',
    'a6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'a6300000-0000-0000-0000-000000000004',
    'a6200000-0000-0000-0000-000000000004',
    'a6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'a6300000-0000-0000-0000-000000000005',
    'a6200000-0000-0000-0000-000000000005',
    'a6100000-0000-0000-0000-000000000001',
    timestamptz '2020-01-01 00:00:00+07'
  ),
  (
    'a6300000-0000-0000-0000-000000000006',
    'a6200000-0000-0000-0000-000000000006',
    'a6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  );

select lives_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000201',
      'a6300000-0000-0000-0000-000000000002',
      'a6200000-0000-0000-0000-000000000002',
      1,
      1,
      date '2020-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-LIF-09 revision 1 Draft with null predecessor succeeds'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000301',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      1,
      'a6400000-0000-0000-0000-000000000201',
      0.5,
      date '2020-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_predecessor_shape_check"',
  'H1A-LIF-10 revision 1 with a predecessor is rejected'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000302',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      0,
      0.5,
      date '2020-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_predecessor_shape_check"',
  'H1A-LIF-11 nonpositive revision number is rejected'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000303',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      2,
      0.5,
      date '2020-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_predecessor_shape_check"',
  'H1A-LIF-12 later revision without predecessor is rejected'
);

insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,
  planning_quantity_policy_id,
  unit_id,
  revision_number,
  planning_step,
  effective_from,
  created_by_actor_id,
  created_at
) values (
  'a6400000-0000-0000-0000-000000000300',
  'a6300000-0000-0000-0000-000000000003',
  'a6200000-0000-0000-0000-000000000003',
  1,
  0.5,
  date '2020-01-01',
  'a6100000-0000-0000-0000-000000000001',
  timestamptz '2020-01-01 00:00:00+07'
);
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000303',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      3,
      'a6400000-0000-0000-0000-000000000300',
      0.5,
      date '2022-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    );
    set constraints all immediate
  $$,
  '23514',
  'planning quantity policy revision numbers must be positive and contiguous within the root',
  'H1A-LIF-13 revision-number gap is rejected when deferred constraints are forced'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000302',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      2,
      'a6400000-0000-0000-0000-000000000302',
      0.5,
      date '2021-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    );
    set constraints all immediate
  $$,
  '23514',
  'each planning quantity policy revision must name its direct same-root and same-Unit predecessor',
  'H1A-LIF-14 non-direct predecessor number is rejected when deferred constraints are forced'
);

insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,
  planning_quantity_policy_id,
  unit_id,
  revision_number,
  planning_step,
  effective_from,
  created_by_actor_id,
  created_at
) values (
  'a6400000-0000-0000-0000-000000000600',
  'a6300000-0000-0000-0000-000000000006',
  'a6200000-0000-0000-0000-000000000006',
  1,
  0.25,
  date '2020-01-01',
  'a6100000-0000-0000-0000-000000000001',
  timestamptz '2020-01-01 00:00:00+07'
);
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000304',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      2,
      'a6400000-0000-0000-0000-000000000600',
      0.5,
      date '2021-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23503',
  'insert or update on table "planning_quantity_policy_revisions" violates foreign key constraint "planning_quantity_policy_revisions_predecessor_fkey"',
  'H1A-LIF-15 cross-root predecessor is rejected'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000305',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      2,
      'a6400000-0000-0000-0000-000000000600',
      0.5,
      date '2021-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23503',
  'insert or update on table "planning_quantity_policy_revisions" violates foreign key constraint "planning_quantity_policy_revisions_predecessor_fkey"',
  'H1A-LIF-16 cross-Unit predecessor is rejected'
);

insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,
  planning_quantity_policy_id,
  unit_id,
  revision_number,
  predecessor_policy_revision_id,
  planning_step,
  effective_from,
  created_by_actor_id,
  created_at
) values (
  'a6400000-0000-0000-0000-000000000302',
  'a6300000-0000-0000-0000-000000000003',
  'a6200000-0000-0000-0000-000000000003',
  2,
  'a6400000-0000-0000-0000-000000000300',
  0.5,
  date '2021-01-01',
  'a6100000-0000-0000-0000-000000000001',
  timestamptz '2020-01-01 00:00:00+07'
);
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000303',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      3,
      'a6400000-0000-0000-0000-000000000300',
      0.5,
      date '2022-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "planning_quantity_policy_revisions_predecessor_key"',
  'H1A-LIF-17 predecessor fork is rejected'
);
select throws_ok(
  $$
    insert into atlas_planning.planning_quantity_policy_revisions (
      planning_quantity_policy_revision_id,
      planning_quantity_policy_id,
      unit_id,
      revision_number,
      predecessor_policy_revision_id,
      planning_step,
      effective_from,
      created_by_actor_id,
      created_at
    ) values (
      'a6400000-0000-0000-0000-000000000399',
      'a6300000-0000-0000-0000-000000000003',
      'a6200000-0000-0000-0000-000000000003',
      2,
      'a6400000-0000-0000-0000-000000000399',
      0.5,
      date '2022-01-01',
      'a6100000-0000-0000-0000-000000000001',
      timestamptz '2020-01-01 00:00:00+07'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "planning_quantity_policy_revisions_policy_revision_key"',
  'H1A-LIF-18 duplicate root-local revision number is rejected'
);

select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000299'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-19 Draft revision identity is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set planning_quantity_policy_id
      = 'a6300000-0000-0000-0000-000000000003'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-20 Draft policy-root ownership is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set unit_id = 'a6200000-0000-0000-0000-000000000003'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-21 Draft Unit is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set revision_number = 2
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-22 Draft revision number is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set predecessor_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-23 Draft predecessor is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set created_by_actor_id = 'a6100000-0000-0000-0000-000000000002'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-24 Draft creator is immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set created_at = created_at + interval '1 second'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revision identity, ownership, lineage, creator, and creation time are immutable',
  'H1A-LIF-25 Draft creation time is immutable'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set planning_step = 2
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  'H1A-LIF-26 Draft Planning-step correction succeeds'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set effective_from = date '2021-01-01'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  'H1A-LIF-27 Draft effective_from correction succeeds'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set effective_to = date '2030-01-01'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  'H1A-LIF-28 Draft effective_to correction succeeds'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      approved_by_actor_id
        = 'a6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2022-01-01 09:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201';
    update atlas_planning.planning_quantity_policy_revisions
    set approved_at = timestamptz '2022-01-01 09:01:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  'H1A-LIF-29 paired Draft approval evidence may be set and corrected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set approved_at = null
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_evidence_check"',
  'H1A-LIF-30 incomplete approval pair is rejected'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2025-01-01'
      and (
        effective_to is null
        or date '2025-01-01' < effective_to
      )
  ),
  0,
  'H1A-LIF-31 Draft is ineligible for resolution'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'RETIRED',
      activated_by_actor_id
        = 'a6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2022-01-01 10:00:00+07',
      retired_by_actor_id
        = 'a6100000-0000-0000-0000-000000000004',
      retired_at = timestamptz '2022-01-01 11:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000201'
  $$,
  '23514',
  'planning quantity policy revisions follow DRAFT to ACTIVE to RETIRED',
  'H1A-LIF-32 direct DRAFT to RETIRED transition is rejected'
);

insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id,
  planning_quantity_policy_id,
  unit_id,
  revision_number,
  planning_step,
  effective_from,
  created_by_actor_id,
  created_at
) values
  (
    'a6400000-0000-0000-0000-000000000401',
    'a6300000-0000-0000-0000-000000000004',
    'a6200000-0000-0000-0000-000000000004',
    1,
    0.01,
    date '1900-01-01',
    'a6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'a6400000-0000-0000-0000-000000000501',
    'a6300000-0000-0000-0000-000000000005',
    'a6200000-0000-0000-0000-000000000005',
    1,
    1,
    date '2099-01-01',
    'a6100000-0000-0000-0000-000000000001',
    timestamptz '2020-01-01 00:00:00+07'
  );
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_at = timestamptz '2000-01-01 09:00:00+07',
      activated_by_actor_id
        = 'a6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2000-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_evidence_check"',
  'H1A-LIF-33 activation without approver actor is rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'a6100000-0000-0000-0000-000000000002',
      activated_by_actor_id
        = 'a6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2000-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_evidence_check"',
  'H1A-LIF-34 activation without approval time is rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'a6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2000-01-01 09:00:00+07',
      activated_at = timestamptz '2000-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_evidence_check"',
  'H1A-LIF-35 activation without activator actor is rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'a6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2000-01-01 09:00:00+07',
      activated_by_actor_id
        = 'a6100000-0000-0000-0000-000000000003'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_evidence_check"',
  'H1A-LIF-36 activation without activation time is rejected'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'a6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2000-01-01 09:00:00+07',
      activated_by_actor_id
        = 'a6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2000-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-LIF-37 complete activation with a historical effective_from succeeds independently of the transaction date'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'a6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2021-01-01 09:00:00+07',
      activated_by_actor_id
        = 'a6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2021-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000501';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-LIF-38 complete activation with a scheduled future effective_from succeeds'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set planning_step = 2
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000501'
  $$,
  '23514',
  'ACTIVE planning quantity policy revisions may only be retired',
  'H1A-LIF-39 Active Planning-step mutation is rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set effective_from = date '2098-01-01'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000501'
  $$,
  '23514',
  'ACTIVE planning quantity policy revisions may only be retired',
  'H1A-LIF-40 Active effective_from mutation is rejected'
);
select lives_ok(
  $$
    do $block$
    declare
      rejected_count integer := 0;
    begin
      begin
        update atlas_planning.planning_quantity_policy_revisions
        set approved_by_actor_id
          = 'a6100000-0000-0000-0000-000000000001'
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000501';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      begin
        update atlas_planning.planning_quantity_policy_revisions
        set activated_at = activated_at + interval '1 second'
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000501';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      if rejected_count <> 2 then
        raise exception 'Active identity or evidence mutation unexpectedly succeeded';
      end if;
    end
    $block$
  $$,
  'H1A-LIF-41 Active identity, predecessor, approval, and activation evidence remain immutable'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set policy_revision_status = 'DRAFT'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000501'
  $$,
  '23514',
  'ACTIVE planning quantity policy revisions may only be retired',
  'H1A-LIF-42 ACTIVE to DRAFT is rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set effective_to = date '2100-01-01'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000501'
  $$,
  '23514',
  'ACTIVE planning quantity policy revisions may only be retired',
  'H1A-LIF-43 Active interval cannot close without the retirement transition and evidence'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'RETIRED',
      effective_to = date '1950-01-01',
      retired_by_actor_id
        = 'a6100000-0000-0000-0000-000000000004'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  $$,
  '23514',
  'retirement must atomically close the open interval and record paired evidence',
  'H1A-LIF-44 retirement with incomplete actor and time evidence is rejected'
);
select lives_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'RETIRED',
      effective_to = date '1950-01-01',
      retired_by_actor_id
        = 'a6100000-0000-0000-0000-000000000004',
      retired_at = timestamptz '2001-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401';
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-LIF-45 retirement with a historical effective_to succeeds independently of the transaction date'
);
select is(
  (
    select jsonb_build_object(
      'status', policy_revision_status,
      'effective_to', effective_to,
      'retired_by', retired_by_actor_id,
      'retired_at', retired_at
    )
    from atlas_planning.planning_quantity_policy_revisions
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  ),
  jsonb_build_object(
    'status', 'RETIRED',
    'effective_to', date '1950-01-01',
    'retired_by', 'a6100000-0000-0000-0000-000000000004'::uuid,
    'retired_at', timestamptz '2001-01-01 10:00:00+07'
  ),
  'H1A-LIF-46 controlled retirement atomically closes the interval and records paired evidence'
);
select lives_ok(
  $$
    do $block$
    declare
      rejected_count integer := 0;
    begin
      begin
        update atlas_planning.planning_quantity_policy_revisions
        set effective_to = date '1960-01-01'
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000401';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      begin
        update atlas_planning.planning_quantity_policy_revisions
        set effective_to = date '1940-01-01'
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000401';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      begin
        update atlas_planning.planning_quantity_policy_revisions
        set
          policy_revision_status = 'ACTIVE',
          effective_to = null,
          retired_by_actor_id = null,
          retired_at = null
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000401';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      if rejected_count <> 3 then
        raise exception 'a retired close, extension, or reopen unexpectedly succeeded';
      end if;
    end
    $block$
  $$,
  'H1A-LIF-47 a second close, interval extension, and reopen are rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set planning_step = planning_step
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  $$,
  '23514',
  'RETIRED planning quantity policy revisions are immutable',
  'H1A-LIF-48 every Retired update is rejected'
);
select lives_ok(
  $$
    do $block$
    declare
      rejected_count integer := 0;
    begin
      begin
        delete from atlas_planning.planning_quantity_policy_revisions
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000201';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      begin
        delete from atlas_planning.planning_quantity_policy_revisions
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000501';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      begin
        delete from atlas_planning.planning_quantity_policy_revisions
        where planning_quantity_policy_revision_id
          = 'a6400000-0000-0000-0000-000000000401';
      exception when check_violation then
        rejected_count := rejected_count + 1;
      end;

      if rejected_count <> 3 then
        raise exception 'a Draft, Active, or Retired revision DELETE unexpectedly succeeded';
      end if;
    end
    $block$
  $$,
  'H1A-LIF-49 Draft, Active, and Retired revision DELETE attempts are rejected'
);
select is(
  (
    select jsonb_build_object(
      'revision_id', planning_quantity_policy_revision_id,
      'root_id', planning_quantity_policy_id,
      'unit_id', unit_id,
      'revision_number', revision_number,
      'effective_from', effective_from,
      'effective_to', effective_to,
      'approved_by', approved_by_actor_id,
      'activated_by', activated_by_actor_id,
      'retired_by', retired_by_actor_id
    )
    from atlas_planning.planning_quantity_policy_revisions
    where planning_quantity_policy_revision_id
      = 'a6400000-0000-0000-0000-000000000401'
  ),
  jsonb_build_object(
    'revision_id', 'a6400000-0000-0000-0000-000000000401'::uuid,
    'root_id', 'a6300000-0000-0000-0000-000000000004'::uuid,
    'unit_id', 'a6200000-0000-0000-0000-000000000004'::uuid,
    'revision_number', 1,
    'effective_from', date '1900-01-01',
    'effective_to', date '1950-01-01',
    'approved_by', 'a6100000-0000-0000-0000-000000000002'::uuid,
    'activated_by', 'a6100000-0000-0000-0000-000000000003'::uuid,
    'retired_by', 'a6100000-0000-0000-0000-000000000004'::uuid
  ),
  'H1A-LIF-50 retired historical identity, interval, and actor evidence remain queryable'
);

select * from finish();

rollback;
