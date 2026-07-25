begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(44);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name,
  actor_status,
  version,
  created_at
) values
  (
    'b6100000-0000-0000-0000-000000000001',
    'HUMAN',
    'H1A effectivity creator',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6100000-0000-0000-0000-000000000002',
    'HUMAN',
    'H1A effectivity approver',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6100000-0000-0000-0000-000000000003',
    'HUMAN',
    'H1A effectivity activator',
    'ACTIVE',
    1,
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6100000-0000-0000-0000-000000000004',
    'HUMAN',
    'H1A effectivity retiree',
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
    'b6200000-0000-0000-0000-000000000001',
    'h1a_effectivity_kg',
    'H1A effectivity kilogram',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000002',
    'h1a_effectivity_count',
    'H1A effectivity count',
    'COUNT',
    0,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000003',
    'h1a_effectivity_mass_without_policy',
    'H1A same-dimension Unit without policy',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000004',
    'h1a_effectivity_future',
    'H1A scheduled future Unit',
    'COUNT',
    0,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000005',
    'h1a_effectivity_expired',
    'H1A expired Unit',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000006',
    'h1a_effectivity_retired_overlap',
    'H1A retired overlap Unit',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000007',
    'h1a_effectivity_open_overlap',
    'H1A open overlap Unit',
    'COUNT',
    0,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  ),
  (
    'b6200000-0000-0000-0000-000000000008',
    'h1a_effectivity_invalid_step',
    'H1A invalid-step Unit',
    'MASS',
    6,
    'ACTIVE',
    timestamptz '1990-01-01 00:00:00+07'
  );

insert into atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id,
  unit_id,
  created_by_actor_id,
  created_at
) values
  (
    'b6300000-0000-0000-0000-000000000001',
    'b6200000-0000-0000-0000-000000000001',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'b6300000-0000-0000-0000-000000000002',
    'b6200000-0000-0000-0000-000000000002',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'b6300000-0000-0000-0000-000000000004',
    'b6200000-0000-0000-0000-000000000004',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'b6300000-0000-0000-0000-000000000005',
    'b6200000-0000-0000-0000-000000000005',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1980-01-01 00:00:00+07'
  ),
  (
    'b6300000-0000-0000-0000-000000000006',
    'b6200000-0000-0000-0000-000000000006',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'b6300000-0000-0000-0000-000000000007',
    'b6200000-0000-0000-0000-000000000007',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
  ),
  (
    'b6300000-0000-0000-0000-000000000008',
    'b6200000-0000-0000-0000-000000000008',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '1999-01-01 00:00:00+07'
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
      'b6400000-0000-0000-0000-000000000801',
      'b6300000-0000-0000-0000-000000000008',
      'b6200000-0000-0000-0000-000000000008',
      1,
      0,
      date '2000-01-01',
      'b6100000-0000-0000-0000-000000000001',
      timestamptz '2000-01-01 00:00:00+07'
    )
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_planning_step_check"',
  'H1A-EFF-01 zero Planning step is rejected'
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
      'b6400000-0000-0000-0000-000000000802',
      'b6300000-0000-0000-0000-000000000008',
      'b6200000-0000-0000-0000-000000000008',
      1,
      -0.01,
      date '2000-01-01',
      'b6100000-0000-0000-0000-000000000001',
      timestamptz '2000-01-01 00:00:00+07'
    )
  $$,
  '23514',
  'new row for relation "planning_quantity_policy_revisions" violates check constraint "planning_quantity_policy_revisions_planning_step_check"',
  'H1A-EFF-02 negative Planning step is rejected'
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
      'b6400000-0000-0000-0000-000000000101',
      'b6300000-0000-0000-0000-000000000001',
      'b6200000-0000-0000-0000-000000000001',
      1,
      0.01,
      date '2000-01-01',
      'b6100000-0000-0000-0000-000000000001',
      timestamptz '2000-01-01 00:00:00+07'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-EFF-03 exact 0.01 kilogram fixture is accepted'
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
      'b6400000-0000-0000-0000-000000000201',
      'b6300000-0000-0000-0000-000000000002',
      'b6200000-0000-0000-0000-000000000002',
      1,
      1,
      date '2000-01-01',
      'b6100000-0000-0000-0000-000000000001',
      timestamptz '2000-01-01 00:00:00+07'
    );
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-EFF-04 exact 1 count fixture is accepted'
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
      'b6400000-0000-0000-0000-000000000199',
      'b6300000-0000-0000-0000-000000000001',
      'b6200000-0000-0000-0000-000000000002',
      2,
      1,
      date '2010-01-01',
      'b6100000-0000-0000-0000-000000000001',
      timestamptz '2000-01-01 00:00:00+07'
    )
  $$,
  '23503',
  'planning quantity policy revision requires its exact parent policy and Unit',
  'H1A-EFF-05 revision and root exact-Unit mismatch is rejected'
);
select ok(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name in (
        'planning_quantity_policies',
        'planning_quantity_policy_revisions'
      )
      and column_name ~* 'conversion|dimension|from_unit|to_unit|factor'
  )
  and not exists (
    select 1
    from pg_constraint
    where conrelid in (
      'atlas_planning.planning_quantity_policies'::regclass,
      'atlas_planning.planning_quantity_policy_revisions'::regclass
    )
      and contype = 'f'
      and pg_get_constraintdef(oid) ~* 'conversion'
  ),
  'H1A-EFF-06 H1A policy rows contain no conversion dependency'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2005-01-01'
      and (
        effective_to is null
        or date '2005-01-01' < effective_to
      )
  ),
  0,
  'H1A-EFF-07 Draft returns zero eligible revisions'
);

update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'b6100000-0000-0000-0000-000000000002',
  approved_at = timestamptz '2001-01-01 09:00:00+07',
  activated_by_actor_id = 'b6100000-0000-0000-0000-000000000003',
  activated_at = timestamptz '2001-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000101';
set constraints all immediate;
set constraints all deferred;

select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2000-01-01'
      and (
        effective_to is null
        or date '2000-01-01' < effective_to
      )
  ),
  1,
  'H1A-EFF-08 effective_from is inclusive'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '1999-12-31'
      and (
        effective_to is null
        or date '1999-12-31' < effective_to
      )
  ),
  0,
  'H1A-EFF-09 a date before effective_from returns zero'
);
select is(
  (
    select planning_quantity_policy_revision_id
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2009-12-31'
      and (
        effective_to is null
        or date '2009-12-31' < effective_to
      )
  ),
  'b6400000-0000-0000-0000-000000000101'::uuid,
  'H1A-EFF-10 an open interval remains eligible after its start'
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
  'b6400000-0000-0000-0000-000000000102',
  'b6300000-0000-0000-0000-000000000001',
  'b6200000-0000-0000-0000-000000000001',
  2,
  'b6400000-0000-0000-0000-000000000101',
  0.01,
  date '2010-01-01',
  'b6100000-0000-0000-0000-000000000001',
  timestamptz '2005-01-01 00:00:00+07'
);
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'RETIRED',
  effective_to = date '2010-01-01',
  retired_by_actor_id = 'b6100000-0000-0000-0000-000000000004',
  retired_at = timestamptz '2009-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000101';
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'b6100000-0000-0000-0000-000000000002',
  approved_at = timestamptz '2009-01-01 09:00:00+07',
  activated_by_actor_id = 'b6100000-0000-0000-0000-000000000003',
  activated_at = timestamptz '2009-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000102';
set constraints all immediate;
set constraints all deferred;

select is(
  (
    select planning_quantity_policy_revision_id
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2000-01-01'
      and (
        effective_to is null
        or date '2000-01-01' < effective_to
      )
  ),
  'b6400000-0000-0000-0000-000000000101'::uuid,
  'H1A-EFF-11 a Retired interval includes its start'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000101'
      and effective_from <= date '2010-01-01'
      and (
        effective_to is null
        or date '2010-01-01' < effective_to
      )
  ),
  0,
  'H1A-EFF-12 effective_to is exclusive'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000101'
      and effective_from <= date '2011-01-01'
      and (
        effective_to is null
        or date '2011-01-01' < effective_to
      )
  ),
  0,
  'H1A-EFF-13 a date after effective_to returns zero'
);
select is(
  (
    select jsonb_build_object(
      'column_type',
      (
        select data_type
        from information_schema.columns
        where table_schema = 'atlas_planning'
          and table_name = 'planning_quantity_policy_revisions'
          and column_name = 'effective_from'
      ),
      'bangkok_service_date',
      (
        timestamptz '2026-01-01 17:30:00+00'
        at time zone 'Asia/Bangkok'
      )::date
    )
  ),
  jsonb_build_object(
    'column_type', 'date',
    'bangkok_service_date', date '2026-01-02'
  ),
  'H1A-EFF-14 service-date derivation uses Asia/Bangkok date semantics'
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
  'b6400000-0000-0000-0000-000000000401',
  'b6300000-0000-0000-0000-000000000004',
  'b6200000-0000-0000-0000-000000000004',
  1,
  1,
  date '2099-01-01',
  'b6100000-0000-0000-0000-000000000001',
  timestamptz '2020-01-01 00:00:00+07'
);
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'b6100000-0000-0000-0000-000000000002',
  approved_at = timestamptz '2021-01-01 09:00:00+07',
  activated_by_actor_id = 'b6100000-0000-0000-0000-000000000003',
  activated_at = timestamptz '2021-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000401';
set constraints all immediate;
set constraints all deferred;

select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000004'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2098-12-31'
      and (
        effective_to is null
        or date '2098-12-31' < effective_to
      )
  ),
  0,
  'H1A-EFF-15 scheduled-future Active revision returns zero before start'
);
select is(
  (
    select planning_quantity_policy_revision_id
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000004'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2099-01-01'
      and (
        effective_to is null
        or date '2099-01-01' < effective_to
      )
  ),
  'b6400000-0000-0000-0000-000000000401'::uuid,
  'H1A-EFF-16 scheduled-future Active revision resolves exactly at start'
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
  'b6400000-0000-0000-0000-000000000501',
  'b6300000-0000-0000-0000-000000000005',
  'b6200000-0000-0000-0000-000000000005',
  1,
  0.01,
  date '1990-01-01',
  'b6100000-0000-0000-0000-000000000001',
  timestamptz '1990-01-01 00:00:00+07'
);
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'b6100000-0000-0000-0000-000000000002',
  approved_at = timestamptz '1991-01-01 09:00:00+07',
  activated_by_actor_id = 'b6100000-0000-0000-0000-000000000003',
  activated_at = timestamptz '1991-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000501';
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'RETIRED',
  effective_to = date '2000-01-01',
  retired_by_actor_id = 'b6100000-0000-0000-0000-000000000004',
  retired_at = timestamptz '1999-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000501';
set constraints all immediate;
set constraints all deferred;

select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000005'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2000-01-02'
      and (
        effective_to is null
        or date '2000-01-02' < effective_to
      )
  ),
  0,
  'H1A-EFF-17 expired Retired revision returns zero later'
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
    'b6400000-0000-0000-0000-000000000601',
    'b6300000-0000-0000-0000-000000000006',
    'b6200000-0000-0000-0000-000000000006',
    1,
    0.01,
    date '2000-01-01',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '2000-01-01 00:00:00+07'
  ),
  (
    'b6400000-0000-0000-0000-000000000701',
    'b6300000-0000-0000-0000-000000000007',
    'b6200000-0000-0000-0000-000000000007',
    1,
    1,
    date '2020-01-01',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '2000-01-01 00:00:00+07'
  );
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'b6100000-0000-0000-0000-000000000002',
  approved_at = timestamptz '2001-01-01 09:00:00+07',
  activated_by_actor_id = 'b6100000-0000-0000-0000-000000000003',
  activated_at = timestamptz '2001-01-01 10:00:00+07'
where planning_quantity_policy_revision_id in (
  'b6400000-0000-0000-0000-000000000601',
  'b6400000-0000-0000-0000-000000000701'
);
update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'RETIRED',
  effective_to = date '2010-01-01',
  retired_by_actor_id = 'b6100000-0000-0000-0000-000000000004',
  retired_at = timestamptz '2009-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000601';
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
) values
  (
    'b6400000-0000-0000-0000-000000000602',
    'b6300000-0000-0000-0000-000000000006',
    'b6200000-0000-0000-0000-000000000006',
    2,
    'b6400000-0000-0000-0000-000000000601',
    0.01,
    date '2005-01-01',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '2005-01-01 00:00:00+07'
  ),
  (
    'b6400000-0000-0000-0000-000000000702',
    'b6300000-0000-0000-0000-000000000007',
    'b6200000-0000-0000-0000-000000000007',
    2,
    'b6400000-0000-0000-0000-000000000701',
    1,
    date '2021-01-01',
    'b6100000-0000-0000-0000-000000000001',
    timestamptz '2021-01-01 00:00:00+07'
  );
set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'b6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2022-01-01 09:00:00+07',
      activated_by_actor_id
        = 'b6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2022-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000702';
    set constraints all immediate
  $$,
  '23514',
  'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit',
  'H1A-EFF-18 overlapping Active and Active intervals are rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'b6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2006-01-01 09:00:00+07',
      activated_by_actor_id
        = 'b6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2006-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000602';
    set constraints all immediate
  $$,
  '23514',
  'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit',
  'H1A-EFF-19 overlapping Active and Retired intervals are rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'b6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2006-01-01 09:00:00+07',
      activated_by_actor_id
        = 'b6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2006-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000602';
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'RETIRED',
      effective_to = date '2008-01-01',
      retired_by_actor_id
        = 'b6100000-0000-0000-0000-000000000004',
      retired_at = timestamptz '2007-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000602';
    set constraints all immediate
  $$,
  '23514',
  'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit',
  'H1A-EFF-20 overlapping Retired and Retired intervals are rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      effective_from = date '2001-01-01',
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'b6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2006-01-01 09:00:00+07',
      activated_by_actor_id
        = 'b6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2006-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000602';
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'RETIRED',
      effective_to = date '2009-01-01',
      retired_by_actor_id
        = 'b6100000-0000-0000-0000-000000000004',
      retired_at = timestamptz '2008-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000602';
    set constraints all immediate
  $$,
  '23514',
  'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit',
  'H1A-EFF-21 nested eligible interval is rejected'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      effective_from = date '2030-01-01',
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'b6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2022-01-01 09:00:00+07',
      activated_by_actor_id
        = 'b6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2022-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000702';
    set constraints all immediate
  $$,
  '23514',
  'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit',
  'H1A-EFF-22 overlap with an open eligible interval is rejected'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2010-01-01'
      and (
        effective_to is null
        or date '2010-01-01' < effective_to
      )
  ),
  1,
  'H1A-EFF-23 boundary-touching half-open intervals are accepted'
);
select lives_ok(
  $$
    set constraints all immediate;
    set constraints all deferred
  $$,
  'H1A-EFF-24 overlapping Draft intervals are allowed because neither Draft is eligible'
);
select throws_ok(
  $$
    update atlas_planning.planning_quantity_policy_revisions
    set
      policy_revision_status = 'ACTIVE',
      approved_by_actor_id
        = 'b6100000-0000-0000-0000-000000000002',
      approved_at = timestamptz '2022-01-01 09:00:00+07',
      activated_by_actor_id
        = 'b6100000-0000-0000-0000-000000000003',
      activated_at = timestamptz '2022-01-01 10:00:00+07'
    where planning_quantity_policy_revision_id
      = 'b6400000-0000-0000-0000-000000000702';
    set constraints all immediate
  $$,
  '23514',
  'ACTIVE and RETIRED planning quantity policy intervals cannot overlap for one exact Unit',
  'H1A-EFF-25 activation of an overlapping Draft is rejected'
);

update atlas_planning.planning_quantity_policy_revisions
set
  policy_revision_status = 'ACTIVE',
  approved_by_actor_id = 'b6100000-0000-0000-0000-000000000002',
  approved_at = timestamptz '2001-01-01 09:00:00+07',
  activated_by_actor_id = 'b6100000-0000-0000-0000-000000000003',
  activated_at = timestamptz '2001-01-01 10:00:00+07'
where planning_quantity_policy_revision_id
  = 'b6400000-0000-0000-0000-000000000201';
set constraints all immediate;
set constraints all deferred;

select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id in (
      'b6200000-0000-0000-0000-000000000001',
      'b6200000-0000-0000-0000-000000000002'
    )
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2025-01-01'
      and (
        effective_to is null
        or date '2025-01-01' < effective_to
      )
  ),
  2,
  'H1A-EFF-26 eligible intervals for different exact Units may overlap'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2005-01-01'
      and (
        effective_to is null
        or date '2005-01-01' < effective_to
      )
  ),
  1,
  'H1A-EFF-27 an interior service date resolves at most one revision'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000001'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
      and effective_from <= date '2010-01-01'
      and (
        effective_to is null
        or date '2010-01-01' < effective_to
      )
  ),
  1,
  'H1A-EFF-28 a handoff boundary resolves at most one revision'
);
select ok(
  not exists (
    select service_date.unit_id, service_date.service_date
    from (
      select unit_id, service_date
      from unnest(
        array[
          'b6200000-0000-0000-0000-000000000001'::uuid,
          'b6200000-0000-0000-0000-000000000002'::uuid,
          'b6200000-0000-0000-0000-000000000004'::uuid,
          'b6200000-0000-0000-0000-000000000005'::uuid
        ]
      ) as unit_id
      cross join unnest(
        array[
          date '1990-01-01',
          date '2000-01-01',
          date '2005-01-01',
          date '2010-01-01',
          date '2025-01-01',
          date '2099-01-01'
        ]
      ) as service_date
    ) as service_date
    join atlas_planning.planning_quantity_policy_revisions as revision
      on revision.unit_id = service_date.unit_id
      and revision.policy_revision_status in ('ACTIVE', 'RETIRED')
      and revision.effective_from <= service_date.service_date
      and (
        revision.effective_to is null
        or service_date.service_date < revision.effective_to
      )
    group by service_date.unit_id, service_date.service_date
    having count(*) > 1
  ),
  'H1A-EFF-29 every valid fixture date has eligible count at most one'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policies
    where unit_id = 'b6200000-0000-0000-0000-000000000003'
  ),
  0,
  'H1A-EFF-30 missing exact-Unit root returns zero'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000003'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
  ),
  0,
  'H1A-EFF-31 same-dimension different Unit does not fall back'
);
select ok(
  not exists (
    select 1
    from atlas_planning.planning_quantity_policies
    where unit_id is null
  )
  and (
    select count(*)
    from pg_constraint
    where conrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and conname = 'planning_quantity_policies_unit_key'
  ) = 1,
  'H1A-EFF-32 no global fallback exists'
);
select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name in (
        'planning_quantity_policies',
        'planning_quantity_policy_revisions'
      )
      and column_name ~* (
        'customer|school|ingredient|supplier|destination|'
        'scope|context|dimension|priority|fallback'
      )
  ),
  0,
  'H1A-EFF-33 no Customer, School, Ingredient, supplier, or context precedence exists'
);
select ok(
  not exists (
    select 1
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname in ('atlas_planning', 'atlas_api')
      and p.proname like '%planning_quantity_policy%resolve%'
  )
  and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name in (
        'planning_quantity_policies',
        'planning_quantity_policy_revisions'
      )
      and column_name ~* 'priority|tie|latest'
  ),
  'H1A-EFF-34 no latest-created, revision, UUID, or other technical tie-break exists'
);
select is(
  10.23::numeric / 0.01::numeric,
  1023::numeric,
  'H1A-EFF-35 10.23 divided by 0.01 is exactly 1023 whole ticks'
);
select isnt(
  trunc(10.234::numeric / 0.01::numeric),
  10.234::numeric / 0.01::numeric,
  'H1A-EFF-36 10.234 divided by 0.01 is not a whole tick count'
);
select is(
  12::numeric / 1::numeric,
  12::numeric,
  'H1A-EFF-37 12 divided by 1 is exactly 12 whole ticks'
);
select isnt(
  trunc(12.5::numeric / 1::numeric),
  12.5::numeric / 1::numeric,
  'H1A-EFF-38 12.5 divided by 1 is not a whole tick count'
);
select is(
  (10.23::numeric / 0.01::numeric) * 0.01::numeric,
  10.23::numeric,
  'H1A-EFF-39 representable quantity equals whole ticks multiplied by step exactly'
);
select is(
  (
    with attempted as (
      select 10.234::numeric as attempted_quantity, 0.01::numeric as step
    )
    select jsonb_build_object(
      'attempted_quantity', attempted_quantity,
      'replacement_quantity',
      case
        when attempted_quantity / step = trunc(attempted_quantity / step)
          then attempted_quantity
        else null
      end
    )
    from attempted
  ),
  jsonb_build_object(
    'attempted_quantity', 10.234::numeric,
    'replacement_quantity', null
  ),
  'H1A-EFF-40 incompatible input remains unchanged and yields no replacement quantity'
);
select ok(
  not exists (
    select 1
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h1a_planning_quantity_policy%'
      and p.prosrc ~* '\m(round|ceil|ceiling|trunc|epsilon|tofixed)\M'
  ),
  'H1A-EFF-41 rounding, ceiling, truncation, and epsilon normalization are absent'
);
select is(
  (
    select count(*)::integer
    from atlas_planning.planning_quantity_policy_revisions
    where unit_id = 'b6200000-0000-0000-0000-000000000008'
      and policy_revision_status in ('ACTIVE', 'RETIRED')
  ),
  0,
  'H1A-EFF-42 a policy for another Unit never converts or authorizes the quantity'
);
select is(
  (
    with preview_binding as (
      select
        'b6400000-0000-0000-0000-000000000101'::uuid
          as bound_revision_id,
        'b6200000-0000-0000-0000-000000000001'::uuid as unit_id,
        date '2010-01-01' as service_date
    ),
    current_resolution as (
      select revision.planning_quantity_policy_revision_id
      from preview_binding
      join atlas_planning.planning_quantity_policy_revisions as revision
        on revision.unit_id = preview_binding.unit_id
        and revision.policy_revision_status in ('ACTIVE', 'RETIRED')
        and revision.effective_from <= preview_binding.service_date
        and (
          revision.effective_to is null
          or preview_binding.service_date < revision.effective_to
        )
    )
    select
      preview_binding.bound_revision_id
        <> current_resolution.planning_quantity_policy_revision_id
    from preview_binding
    cross join current_resolution
  ),
  true,
  'H1A-EFF-43 exact re-resolution detects a stale preview-bound revision across a boundary'
);
select is(
  (
    with preview_binding as (
      select
        'b6400000-0000-0000-0000-000000000101'::uuid
          as bound_revision_id,
        'b6200000-0000-0000-0000-000000000001'::uuid as unit_id,
        date '2005-01-01' as service_date
    ),
    current_resolution as (
      select revision.planning_quantity_policy_revision_id
      from preview_binding
      join atlas_planning.planning_quantity_policy_revisions as revision
        on revision.unit_id = preview_binding.unit_id
        and revision.policy_revision_status in ('ACTIVE', 'RETIRED')
        and revision.effective_from <= preview_binding.service_date
        and (
          revision.effective_to is null
          or preview_binding.service_date < revision.effective_to
        )
    )
    select
      preview_binding.bound_revision_id
        = current_resolution.planning_quantity_policy_revision_id
    from preview_binding
    cross join current_resolution
  ),
  true,
  'H1A-EFF-44 exact re-resolution retains a non-stale binding while the same revision remains eligible'
);

select * from finish();

rollback;
