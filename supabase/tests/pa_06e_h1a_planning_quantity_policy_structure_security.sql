begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(56);

select has_table(
  'atlas_planning',
  'planning_quantity_policies',
  'H1A-STR-01 root relation exists'
);
select has_table(
  'atlas_planning',
  'planning_quantity_policy_revisions',
  'H1A-STR-02 revision relation exists'
);
select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'planning_quantity_polic%'
  ),
  array[
    'planning_quantity_policies',
    'planning_quantity_policy_revisions'
  ]::text[],
  'H1A-STR-03 exact H1A relation catalog contains only the two approved relations'
);
select columns_are(
  'atlas_planning',
  'planning_quantity_policies',
  array[
    'planning_quantity_policy_id',
    'unit_id',
    'created_by_actor_id',
    'created_at'
  ]::text[],
  'H1A-STR-04 root relation has the exact approved column order'
);
select columns_are(
  'atlas_planning',
  'planning_quantity_policy_revisions',
  array[
    'planning_quantity_policy_revision_id',
    'planning_quantity_policy_id',
    'unit_id',
    'revision_number',
    'predecessor_policy_revision_id',
    'planning_step',
    'effective_from',
    'effective_to',
    'policy_revision_status',
    'created_by_actor_id',
    'created_at',
    'approved_by_actor_id',
    'approved_at',
    'activated_by_actor_id',
    'activated_at',
    'retired_by_actor_id',
    'retired_at'
  ]::text[],
  'H1A-STR-05 revision relation has the exact approved column order'
);
select is(
  (
    select array_agg(
      format(
        '%s|%s|%s',
        column_name,
        udt_name,
        is_nullable
      )
      order by ordinal_position
    )::text[]
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'planning_quantity_policies'
  ),
  array[
    'planning_quantity_policy_id|uuid|NO',
    'unit_id|uuid|NO',
    'created_by_actor_id|uuid|NO',
    'created_at|timestamptz|NO'
  ]::text[],
  'H1A-STR-06 root type and nullability fingerprint is exact'
);
select is(
  (
    select array_agg(
      format(
        '%s|%s|%s|%s|%s',
        column_name,
        udt_name,
        is_nullable,
        coalesce(numeric_precision::text, '-'),
        coalesce(numeric_scale::text, '-')
      )
      order by ordinal_position
    )::text[]
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'planning_quantity_policy_revisions'
  ),
  array[
    'planning_quantity_policy_revision_id|uuid|NO|-|-',
    'planning_quantity_policy_id|uuid|NO|-|-',
    'unit_id|uuid|NO|-|-',
    'revision_number|int8|NO|64|0',
    'predecessor_policy_revision_id|uuid|YES|-|-',
    'planning_step|numeric|NO|20|6',
    'effective_from|date|NO|-|-',
    'effective_to|date|YES|-|-',
    'policy_revision_status|text|NO|-|-',
    'created_by_actor_id|uuid|NO|-|-',
    'created_at|timestamptz|NO|-|-',
    'approved_by_actor_id|uuid|YES|-|-',
    'approved_at|timestamptz|YES|-|-',
    'activated_by_actor_id|uuid|YES|-|-',
    'activated_at|timestamptz|YES|-|-',
    'retired_by_actor_id|uuid|YES|-|-',
    'retired_at|timestamptz|YES|-|-'
  ]::text[],
  'H1A-STR-07 revision type, scale, and nullability fingerprint is exact'
);
select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and (
        (
          table_name = 'planning_quantity_policies'
          and column_name = 'planning_quantity_policy_id'
        )
        or (
          table_name = 'planning_quantity_policy_revisions'
          and column_name = 'planning_quantity_policy_revision_id'
        )
      )
      and column_default = 'gen_random_uuid()'
  ),
  2,
  'H1A-STR-08 both UUID identities are database generated'
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
      and column_name = 'created_at'
      and column_default = 'transaction_timestamp()'
  ),
  2,
  'H1A-STR-09 both creation timestamps use the database acceptance time'
);

select ok(
  (
    select contype = 'p'
      and conkey = array[
        (
          select attnum
          from pg_attribute
          where attrelid = 'atlas_planning.planning_quantity_policies'::regclass
            and attname = 'planning_quantity_policy_id'
        )
      ]::smallint[]
    from pg_constraint
    where conrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and conname = 'planning_quantity_policies_pkey'
  ),
  'H1A-STR-10 root primary key is exact'
);
select ok(
  (
    select contype = 'p'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_pkey'
  ),
  'H1A-STR-11 revision primary key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid) = 'UNIQUE (unit_id)'
    from pg_constraint
    where conrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and conname = 'planning_quantity_policies_unit_key'
  ),
  'H1A-STR-12 one root per exact Unit unique key exists'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (planning_quantity_policy_id, unit_id)'
    from pg_constraint
    where conrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and conname = 'planning_quantity_policies_id_unit_key'
  ),
  'H1A-STR-13 root composite ownership key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (planning_quantity_policy_id, revision_number)'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_policy_revision_key'
  ),
  'H1A-STR-14 root-local revision-number unique key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (planning_quantity_policy_id, planning_quantity_policy_revision_id, unit_id)'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_exact_owner_key'
  ),
  'H1A-STR-15 revision exact ownership key is exact'
);
select ok(
  (
    select contype = 'u'
      and pg_get_constraintdef(oid)
        = 'UNIQUE (planning_quantity_policy_id, predecessor_policy_revision_id)'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_predecessor_key'
  ),
  'H1A-STR-16 non-forking predecessor unique key is exact'
);
select ok(
  (
    select contype = 'c'
      and regexp_replace(pg_get_constraintdef(oid), '\s+', '', 'g')
        = 'CHECK((revision_number>0))'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_revision_number_check'
  ),
  'H1A-STR-17 positive revision-number check is exact'
);
select ok(
  (
    select contype = 'c'
      and pg_get_constraintdef(oid) like '%revision_number = 1%'
      and pg_get_constraintdef(oid) like '%revision_number > 1%'
      and pg_get_constraintdef(oid) like '%predecessor_policy_revision_id%'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_predecessor_shape_check'
  ),
  'H1A-STR-18 revision-one and later predecessor-shape check is exact'
);
select ok(
  (
    select contype = 'c'
      and pg_get_constraintdef(oid) like '%planning_step >%'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_planning_step_check'
  )
  and (
    select numeric_precision = 20 and numeric_scale = 6
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'planning_quantity_policy_revisions'
      and column_name = 'planning_step'
  ),
  'H1A-STR-19 numeric(20,6) positive Planning-step contract is exact'
);
select ok(
  (
    select contype = 'c'
      and regexp_count(pg_get_constraintdef(oid), 'DRAFT|ACTIVE|RETIRED') = 3
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_status_check'
  ),
  'H1A-STR-20 exact three-status check exists'
);
select ok(
  (
    select contype = 'c'
      and pg_get_constraintdef(oid) like '%effective_to IS NULL%'
      and pg_get_constraintdef(oid) like '%effective_to > effective_from%'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_period_check'
  ),
  'H1A-STR-21 half-open period-validity check is exact'
);
select ok(
  (
    select contype = 'c'
      and pg_get_constraintdef(oid) like '%approved_by_actor_id%'
      and pg_get_constraintdef(oid) like '%activated_by_actor_id%'
      and pg_get_constraintdef(oid) like '%retired_by_actor_id%'
      and pg_get_constraintdef(oid) like '%approved_at >= created_at%'
      and pg_get_constraintdef(oid) like '%activated_at >= approved_at%'
      and pg_get_constraintdef(oid) like '%retired_at >= activated_at%'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_evidence_check'
  ),
  'H1A-STR-22 lifecycle evidence pairs and timestamp order are constrained'
);

select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_admin.units'::regclass
    from pg_constraint
    where conrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and conname = 'planning_quantity_policies_unit_fkey'
  ),
  'H1A-STR-23 root Unit foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_core.actors'::regclass
    from pg_constraint
    where conrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and conname = 'planning_quantity_policies_created_by_actor_fkey'
  ),
  'H1A-STR-24 root creator foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid
        = 'atlas_planning.planning_quantity_policies'::regclass
      and pg_get_constraintdef(oid) like
        '%(planning_quantity_policy_id, unit_id)%'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_policy_unit_fkey'
  ),
  'H1A-STR-25 revision binds its exact root and Unit restrictively'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_admin.units'::regclass
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_unit_fkey'
  ),
  'H1A-STR-26 revision direct Unit foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid
        = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and pg_get_constraintdef(oid) like
        '%planning_quantity_policy_id, predecessor_policy_revision_id, unit_id%'
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_predecessor_fkey'
  ),
  'H1A-STR-27 same-root and same-Unit predecessor foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_core.actors'::regclass
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_created_by_actor_fkey'
  ),
  'H1A-STR-28 revision creator foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_core.actors'::regclass
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_approved_by_actor_fkey'
  ),
  'H1A-STR-29 revision approver foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_core.actors'::regclass
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_activated_by_actor_fkey'
  ),
  'H1A-STR-30 revision activator foreign key is restrictive'
);
select ok(
  (
    select contype = 'f' and confdeltype = 'r'
      and confrelid = 'atlas_core.actors'::regclass
    from pg_constraint
    where conrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and conname = 'planning_quantity_policy_revisions_retired_by_actor_fkey'
  ),
  'H1A-STR-31 revision retiree foreign key is restrictive'
);
select is(
  (
    select jsonb_build_object(
      'count', count(*),
      'names', to_jsonb(array_agg(conname order by conname)),
      'restrictive', count(*) filter (where confdeltype = 'r')
    )
    from pg_constraint
    where conrelid in (
      'atlas_planning.planning_quantity_policies'::regclass,
      'atlas_planning.planning_quantity_policy_revisions'::regclass
    )
      and contype = 'f'
  ),
  jsonb_build_object(
    'count', 9,
    'names', to_jsonb(
      array[
        'planning_quantity_policies_created_by_actor_fkey',
        'planning_quantity_policies_unit_fkey',
        'planning_quantity_policy_revisions_activated_by_actor_fkey',
        'planning_quantity_policy_revisions_approved_by_actor_fkey',
        'planning_quantity_policy_revisions_created_by_actor_fkey',
        'planning_quantity_policy_revisions_policy_unit_fkey',
        'planning_quantity_policy_revisions_predecessor_fkey',
        'planning_quantity_policy_revisions_retired_by_actor_fkey',
        'planning_quantity_policy_revisions_unit_fkey'
      ]::text[]
    ),
    'restrictive', 9
  ),
  'H1A-STR-32 exact nine-FK catalog is entirely ON DELETE RESTRICT'
);

select is(
  (
    select array_agg(ci.relname order by ci.relname)::text[]
    from pg_index as i
    join pg_class as ci on ci.oid = i.indexrelid
    where i.indrelid = 'atlas_planning.planning_quantity_policies'::regclass
      and (i.indisprimary or i.indisunique)
  ),
  array[
    'planning_quantity_policies_id_unit_key',
    'planning_quantity_policies_pkey',
    'planning_quantity_policies_unit_key'
  ]::text[],
  'H1A-STR-33 exact root constraint-index catalog exists'
);
select is(
  (
    select array_agg(ci.relname order by ci.relname)::text[]
    from pg_index as i
    join pg_class as ci on ci.oid = i.indexrelid
    where i.indrelid
      = 'atlas_planning.planning_quantity_policy_revisions'::regclass
      and (i.indisprimary or i.indisunique)
  ),
  array[
    'planning_quantity_policy_revisions_exact_owner_key',
    'planning_quantity_policy_revisions_pkey',
    'planning_quantity_policy_revisions_policy_revision_key',
    'planning_quantity_policy_revisions_predecessor_key'
  ]::text[],
  'H1A-STR-34 exact revision constraint-index catalog exists'
);
select ok(
  (
    select
      array(
        select pg_get_indexdef(i.indexrelid, position, true)
        from generate_series(1, i.indnkeyatts) as position
        order by position
      ) = array[
        'unit_id',
        'policy_revision_status',
        'effective_from',
        'effective_to',
        'planning_quantity_policy_revision_id'
      ]::text[]
      and pg_get_expr(i.indpred, i.indrelid) like '%ACTIVE%'
      and pg_get_expr(i.indpred, i.indrelid) like '%RETIRED%'
    from pg_index as i
    join pg_class as ci on ci.oid = i.indexrelid
    where ci.relname = 'planning_quantity_policy_revisions_resolution_idx'
      and i.indrelid
        = 'atlas_planning.planning_quantity_policy_revisions'::regclass
  ),
  'H1A-STR-35 exact partial Unit and effectivity resolution index exists'
);
select ok(
  (
    select
      array(
        select pg_get_indexdef(i.indexrelid, position, true)
        from generate_series(1, i.indnkeyatts) as position
        order by position
      ) = array[
        'predecessor_policy_revision_id',
        'planning_quantity_policy_id',
        'unit_id'
      ]::text[]
      and pg_get_expr(i.indpred, i.indrelid)
        = '(predecessor_policy_revision_id IS NOT NULL)'
    from pg_index as i
    join pg_class as ci on ci.oid = i.indexrelid
    where ci.relname = 'planning_quantity_policy_revisions_predecessor_idx'
      and i.indrelid
        = 'atlas_planning.planning_quantity_policy_revisions'::regclass
  ),
  'H1A-STR-36 exact partial predecessor lookup and FK index exists'
);
select is(
  (
    select count(*)::integer
    from pg_indexes
    where schemaname = 'atlas_planning'
      and tablename = 'planning_quantity_policies'
      and indexname = 'planning_quantity_policies_created_by_actor_idx'
      and indexdef like '%(created_by_actor_id)'
  ),
  1,
  'H1A-STR-37 root creator FK index exists'
);
select is(
  (
    select count(*)::integer
    from pg_indexes
    where schemaname = 'atlas_planning'
      and tablename = 'planning_quantity_policy_revisions'
      and indexname = 'planning_quantity_policy_revisions_unit_idx'
      and indexdef like '%(unit_id)'
      and indexdef not like '% WHERE %'
  ),
  1,
  'H1A-STR-38 full revision Unit FK index exists'
);
select is(
  (
    select count(*)::integer
    from pg_indexes
    where schemaname = 'atlas_planning'
      and tablename = 'planning_quantity_policy_revisions'
      and indexname = 'planning_quantity_policy_revisions_created_by_actor_idx'
      and indexdef like '%(created_by_actor_id)'
  ),
  1,
  'H1A-STR-39 revision creator FK index exists'
);
select is(
  (
    select array_agg(indexname order by indexname)::text[]
    from pg_indexes
    where schemaname = 'atlas_planning'
      and tablename = 'planning_quantity_policy_revisions'
      and indexname in (
        'planning_quantity_policy_revisions_approved_by_actor_idx',
        'planning_quantity_policy_revisions_activated_by_actor_idx',
        'planning_quantity_policy_revisions_retired_by_actor_idx'
      )
      and indexdef like '% WHERE %IS NOT NULL%'
  ),
  array[
    'planning_quantity_policy_revisions_activated_by_actor_idx',
    'planning_quantity_policy_revisions_approved_by_actor_idx',
    'planning_quantity_policy_revisions_retired_by_actor_idx'
  ]::text[],
  'H1A-STR-40 exact three optional-actor partial indexes exist'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h1a_planning_quantity_policy%'
  ),
  array[
    'pa_06e_h1a_planning_quantity_policy_effectivity_integrity',
    'pa_06e_h1a_planning_quantity_policy_guard',
    'pa_06e_h1a_planning_quantity_policy_revision_guard'
  ]::text[],
  'H1A-STR-41 exact three-function H1A catalog exists'
);
select is(
  (
    select count(*)::integer
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h1a_planning_quantity_policy%'
      and p.prorettype = 'trigger'::regtype
      and pg_get_userbyid(p.proowner) = 'atlas_owner'
      and not p.prosecdef
      and coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  3,
  'H1A-STR-42 all three functions return trigger and are atlas_owner invokers with empty search path'
);
select ok(
  not exists (
    select 1
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h1a_planning_quantity_policy%'
      and p.prosrc ~* '\mexecute\M'
  )
  and (
    select count(*)::integer
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname in (
        'pa_06e_h1a_planning_quantity_policy_revision_guard',
        'pa_06e_h1a_planning_quantity_policy_effectivity_integrity'
      )
      and p.prosrc like '%atlas_planning.%'
  ) = 2,
  'H1A-STR-43 all SQL is static and every relation reference is schema qualified'
);
select ok(
  (
    select
      position('if tg_op = ''INSERT''' in p.prosrc) > 0
      and position('elsif tg_op = ''UPDATE''' in p.prosrc) > 0
      and position('for update' in lower(p.prosrc))
        > position('elsif tg_op = ''UPDATE''' in p.prosrc)
      and p.prosrc like
        '%policy.planning_quantity_policy_id = v_planning_quantity_policy_id%'
      and p.prosrc like '%policy.unit_id = v_unit_id%'
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname
        = 'pa_06e_h1a_planning_quantity_policy_revision_guard'
  ),
  'H1A-STR-44 revision INSERT and UPDATE both take the exact parent policy and Unit FOR UPDATE lock before validation'
);
select ok(
  not exists (
    select 1
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h1a_planning_quantity_policy%'
      and p.prosrc ~* (
        'current_date|now\s*\(|transaction_timestamp\s*\(|'
        'clock_timestamp\s*\(|statement_timestamp\s*\(|asia/bangkok'
      )
  ),
  'H1A-STR-45 lifecycle functions contain no transaction-date authority'
);
select is(
  (
    select count(*)::integer
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) as privilege
    left join pg_roles as role on role.oid = privilege.grantee
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h1a_planning_quantity_policy%'
      and privilege.privilege_type = 'EXECUTE'
      and (
        privilege.grantee = 0
        or role.rolname in (
          'anon',
          'authenticated',
          'service_role',
          'atlas_command_runtime',
          'atlas_confirmed_need_review_runtime',
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
          'atlas_planning_command_runtime',
          'atlas_planning_materialization_runtime',
          'atlas_procurement_command_runtime',
          'atlas_read_runtime'
        )
      )
  ),
  0,
  'H1A-STR-46 PUBLIC, API, service, and runtime roles execute no H1A function'
);

select is(
  (
    select array_agg(t.tgname order by t.tgname)::text[]
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    join pg_namespace as n on n.oid = c.relnamespace
    where not t.tgisinternal
      and n.nspname = 'atlas_planning'
      and t.tgname like 'planning_quantity_polic%'
  ),
  array[
    'planning_quantity_policies_guard',
    'planning_quantity_policy_revisions_effectivity_integrity',
    'planning_quantity_policy_revisions_guard'
  ]::text[],
  'H1A-STR-47 exact three-trigger H1A catalog exists'
);
select ok(
  (
    select
      c.relname = 'planning_quantity_policies'
      and not t.tgdeferrable
      and pg_get_triggerdef(t.oid) like '%BEFORE DELETE OR UPDATE%'
      and pg_get_triggerdef(t.oid) like
        '%pa_06e_h1a_planning_quantity_policy_guard()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname = 'planning_quantity_policies_guard'
      and not t.tgisinternal
  ),
  'H1A-STR-48 root ordinary guard has the exact relation, events, timing, and function'
);
select ok(
  (
    select
      c.relname = 'planning_quantity_policy_revisions'
      and not t.tgdeferrable
      and pg_get_triggerdef(t.oid) like
        '%BEFORE INSERT OR DELETE OR UPDATE%'
      and pg_get_triggerdef(t.oid) like
        '%pa_06e_h1a_planning_quantity_policy_revision_guard()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname = 'planning_quantity_policy_revisions_guard'
      and not t.tgisinternal
  ),
  'H1A-STR-49 revision ordinary guard has the exact relation, events, timing, and function'
);
select ok(
  (
    select
      c.relname = 'planning_quantity_policy_revisions'
      and t.tgdeferrable
      and t.tginitdeferred
      and pg_get_triggerdef(t.oid) like '%AFTER INSERT OR UPDATE%'
      and pg_get_triggerdef(t.oid) like
        '%pa_06e_h1a_planning_quantity_policy_effectivity_integrity()%'
    from pg_trigger as t
    join pg_class as c on c.oid = t.tgrelid
    where t.tgname
      = 'planning_quantity_policy_revisions_effectivity_integrity'
      and not t.tgisinternal
  ),
  'H1A-STR-50 deferred effectivity trigger has the exact relation, events, function, and flags'
);
select is(
  (
    select count(*)::integer
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relname in (
        'planning_quantity_policies',
        'planning_quantity_policy_revisions'
      )
      and pg_get_userbyid(c.relowner) = 'atlas_owner'
  ),
  2,
  'H1A-STR-51 atlas_owner owns both relations'
);
select is(
  (
    select count(*)::integer
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relname in (
        'planning_quantity_policies',
        'planning_quantity_policy_revisions'
      )
      and c.relrowsecurity
      and c.relforcerowsecurity
  ),
  2,
  'H1A-STR-52 both relations have enabled and forced RLS'
);
select is(
  (
    select jsonb_agg(
      jsonb_build_object(
        'relation', policy.polrelid::regclass::text,
        'name', policy.polname,
        'command', policy.polcmd,
        'permissive', policy.polpermissive,
        'roles', (
          select jsonb_agg(role.rolname order by role.rolname)
          from unnest(policy.polroles) policy_role(role_oid)
          left join pg_roles role on role.oid = policy_role.role_oid
        ),
        'using', pg_get_expr(policy.polqual, policy.polrelid),
        'with_check', pg_get_expr(policy.polwithcheck, policy.polrelid)
      )
      order by policy.polrelid::regclass::text, policy.polname
    )
    from pg_policy policy
    where policy.polrelid in (
      'atlas_planning.planning_quantity_policies'::regclass,
      'atlas_planning.planning_quantity_policy_revisions'::regclass
    )
  ),
  (
    select jsonb_agg(
      jsonb_build_object(
        'relation', expected.relation_name,
        'name', expected.policy_name,
        'command', expected.command,
        'permissive', true,
        'roles', jsonb_build_array('atlas_confirmed_need_review_runtime'),
        'using', 'true',
        'with_check', expected.with_check
      )
      order by expected.relation_name, expected.policy_name
    )
    from (
      values
        (
          'atlas_planning.planning_quantity_policies',
          'rmvp_05_confirmed_need_select',
          'r',
          null::text
        ),
        (
          'atlas_planning.planning_quantity_policies',
          'rmvp_05_policy_root_lock',
          'w',
          'true'
        ),
        (
          'atlas_planning.planning_quantity_policy_revisions',
          'rmvp_05_confirmed_need_select',
          'r',
          null::text
        ),
        (
          'atlas_planning.planning_quantity_policy_revisions',
          'rmvp_06_policy_revision_lock',
          'w',
          'false'
        )
    ) expected(relation_name, policy_name, command, with_check)
  ),
  'H1A-STR-53 exact four-policy catalog includes the RMVP-06 revision lock and no unknown policy'
);
select is(
  (select jsonb_build_object(
    'rmvp_05_runtime_select', count(*) filter (
      where role.rolname = 'atlas_confirmed_need_review_runtime'
        and privilege.privilege_type = 'SELECT'
    ),
    'other_browser_or_runtime', count(*) filter (
      where privilege.grantee = 0
        or role.rolname in (
          'anon',
          'authenticated',
          'service_role',
          'atlas_command_runtime',
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
          'atlas_planning_command_runtime',
          'atlas_planning_materialization_runtime',
          'atlas_procurement_command_runtime',
          'atlas_read_runtime'
        )
    )
  )
    from pg_class as c
    cross join lateral aclexplode(
      coalesce(c.relacl, acldefault('r', c.relowner))
    ) as privilege
    left join pg_roles as role on role.oid = privilege.grantee
    where c.oid in (
      'atlas_planning.planning_quantity_policies'::regclass,
      'atlas_planning.planning_quantity_policy_revisions'::regclass
    )
  ),
  jsonb_build_object(
    'rmvp_05_runtime_select', 2,
    'other_browser_or_runtime', 0
  ),
  'H1A-STR-54 only the dedicated RMVP-05 runtime has exact SELECT on both H1A relations'
);
select ok(
  to_regclass('public.planning_quantity_policies') is null
  and to_regclass('public.planning_quantity_policy_revisions') is null
  and to_regclass('ops_v2.planning_quantity_policies') is null
  and to_regclass('ops_v2.planning_quantity_policy_revisions') is null
  and not exists (
    select 1
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'S'
      and c.relname like 'planning_quantity_polic%'
  ),
  'H1A-STR-55 no public or ops_v2 copy, compatibility relation, or H1A sequence exists'
);
select is(
  jsonb_build_object(
    'roles',
    (
      select count(*)
      from pg_roles
      where rolname like '%planning_quantity_polic%'
    ),
    'capabilities',
    (
      select count(*)
      from atlas_core.capabilities
      where capability_code like '%planning_quantity_polic%'
    ),
    'api_functions',
    (
      select count(*)
      from pg_proc as p
      join pg_namespace as n on n.oid = p.pronamespace
      where n.nspname = 'atlas_api'
        and p.proname like '%planning_quantity_polic%'
    ),
    'api_total',
    (
      select count(*)
      from pg_proc as p
      join pg_namespace as n on n.oid = p.pronamespace
      where n.nspname = 'atlas_api'
    ),
    'rmvp_06_api_names',
    (
      select array_agg(p.proname order by p.proname)::text[]
      from pg_proc as p
      join pg_namespace as n on n.oid = p.pronamespace
      where n.nspname = 'atlas_api'
        and p.proname = 'validate_confirmed_needs'
    ),
    'rmvp_07_api_names',
    (
      select array_agg(p.proname order by p.proname)::text[]
      from pg_proc as p
      join pg_namespace as n on n.oid = p.pronamespace
      where n.nspname = 'atlas_api'
        and p.proname in (
          'approve_confirmed_needs',
          'release_confirmed_needs_for_purchase_handoff'
        )
    ),
    'rmvp_03b_api_names',
    (
      select array_agg(p.proname order by p.proname)::text[]
      from pg_proc as p
      join pg_namespace as n on n.oid = p.pronamespace
      where n.nspname = 'atlas_api'
        and p.proname in (
          'evaluate_planning_input_readiness',
          'get_planning_input_readiness_workbench',
          'invalidate_planning_input_readiness',
          'request_planning_input_need_generation'
        )
    ),
    'seed_rows',
    (
      select
        (select count(*) from atlas_planning.planning_quantity_policies)
        + (
          select count(*)
          from atlas_planning.planning_quantity_policy_revisions
        )
    )
  ),
  jsonb_build_object(
    'roles', 0,
    'capabilities', 0,
    'api_functions', 0,
    'api_total', 84,
    'rmvp_06_api_names', array[
      'validate_confirmed_needs'
    ]::text[],
    'rmvp_07_api_names', array[
      'approve_confirmed_needs',
      'release_confirmed_needs_for_purchase_handoff'
    ]::text[],
    'rmvp_03b_api_names', array[
      'evaluate_planning_input_readiness',
      'get_planning_input_readiness_workbench',
      'invalidate_planning_input_readiness',
      'request_planning_input_need_generation'
    ]::text[],
    'seed_rows', 0
  ),
  'H1A-STR-56 H1A retains no own role, capability, API, or seed while the current RMVP-07/RMVP-06/RMVP-03B API catalog stays exact'
);

select * from finish();

rollback;
