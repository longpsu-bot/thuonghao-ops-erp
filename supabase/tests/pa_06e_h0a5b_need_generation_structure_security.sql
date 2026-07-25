begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(43);

select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname in (
        'need_generation_calculation_contracts',
        'need_generation_calculation_contract_revisions',
        'need_generation_runs',
        'need_generation_input_snapshots',
        'need_generation_recipe_selections',
        'need_generation_recipe_line_uses',
        'theoretical_need_lines',
        'need_generation_issues',
        'need_generation_release_snapshots',
        'need_generation_release_snapshot_lines',
        'need_generation_release_snapshot_issues'
      )
  ),
  array[
    'need_generation_calculation_contract_revisions',
    'need_generation_calculation_contracts',
    'need_generation_input_snapshots',
    'need_generation_issues',
    'need_generation_recipe_line_uses',
    'need_generation_recipe_selections',
    'need_generation_release_snapshot_issues',
    'need_generation_release_snapshot_lines',
    'need_generation_release_snapshots',
    'need_generation_runs',
    'theoretical_need_lines'
  ]::text[],
  'H0A5b creates exactly the approved eleven private relations'
);

select has_table('atlas_planning', 'need_generation_calculation_contracts', 'calculation contract root exists');
select has_table('atlas_planning', 'need_generation_calculation_contract_revisions', 'calculation contract revisions exist');
select has_table('atlas_planning', 'need_generation_runs', 'need generation runs exist');
select has_table('atlas_planning', 'need_generation_input_snapshots', 'typed input snapshots exist');
select has_table('atlas_planning', 'need_generation_recipe_selections', 'recipe selections exist');
select has_table('atlas_planning', 'need_generation_recipe_line_uses', 'recipe composition uses exist');
select has_table('atlas_planning', 'theoretical_need_lines', 'atomic theoretical lines exist');
select has_table('atlas_planning', 'need_generation_issues', 'immutable classified issues exist');
select has_table('atlas_planning', 'need_generation_release_snapshots', 'release snapshots exist');
select has_table('atlas_planning', 'need_generation_release_snapshot_lines', 'release line membership exists');
select has_table('atlas_planning', 'need_generation_release_snapshot_issues', 'release issue membership exists');

select has_function(
  'atlas_planning',
  'pa_06e_h0a5b_calculation_contract_guard',
  array[]::text[]
);
select has_function(
  'atlas_planning',
  'pa_06e_h0a5b_need_generation_run_guard',
  array[]::text[]
);
select has_function(
  'atlas_planning',
  'pa_06e_h0a5b_immutable_evidence_guard',
  array[]::text[]
);
select has_function(
  'atlas_planning',
  'pa_06e_h0a5b_need_generation_integrity_guard',
  array[]::text[]
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a5b%'
  ),
  array[
    'pa_06e_h0a5b_calculation_contract_guard',
    'pa_06e_h0a5b_immutable_evidence_guard',
    'pa_06e_h0a5b_need_generation_integrity_guard',
    'pa_06e_h0a5b_need_generation_run_guard'
  ]::text[],
  'the private guard-function catalog is exact'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a5b%'
      and pg_get_userbyid(p.proowner) = 'atlas_owner'
      and not p.prosecdef
      and coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  4,
  'all four guards are atlas_owner-owned invoker functions with empty search_path'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    left join pg_roles r on r.oid = acl.grantee
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a5b%'
      and acl.privilege_type = 'EXECUTE'
      and (acl.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
  ),
  0,
  'PUBLIC and API roles cannot execute the private guards'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relname in (
        'need_generation_calculation_contracts',
        'need_generation_calculation_contract_revisions',
        'need_generation_runs',
        'need_generation_input_snapshots',
        'need_generation_recipe_selections',
        'need_generation_recipe_line_uses',
        'theoretical_need_lines',
        'need_generation_issues',
        'need_generation_release_snapshots',
        'need_generation_release_snapshot_lines',
        'need_generation_release_snapshot_issues'
      )
      and pg_get_userbyid(c.relowner) = 'atlas_owner'
  ),
  11,
  'atlas_owner owns all eleven relations'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relname like any (array[
        'need_generation_%', 'theoretical_need_lines'
      ])
      and c.relkind = 'r'
      and c.relrowsecurity
      and c.relforcerowsecurity
  ),
  11,
  'RLS is enabled and forced on every H0A5b relation'
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
      'atlas_planning.need_generation_calculation_contracts'::regclass,
      'atlas_planning.need_generation_calculation_contract_revisions'::regclass,
      'atlas_planning.need_generation_runs'::regclass,
      'atlas_planning.need_generation_input_snapshots'::regclass,
      'atlas_planning.need_generation_recipe_selections'::regclass,
      'atlas_planning.need_generation_recipe_line_uses'::regclass,
      'atlas_planning.theoretical_need_lines'::regclass,
      'atlas_planning.need_generation_issues'::regclass,
      'atlas_planning.need_generation_release_snapshots'::regclass,
      'atlas_planning.need_generation_release_snapshot_lines'::regclass,
      'atlas_planning.need_generation_release_snapshot_issues'::regclass
    )
  ),
  (
    select jsonb_agg(
      jsonb_build_object(
        'relation', expected.relation_name,
        'name', 'pa_06e_h0cb_materialization_select',
        'command', 'r',
        'permissive', true,
        'roles', jsonb_build_array('atlas_planning_materialization_runtime'),
        'using', 'true',
        'with_check', null
      )
      order by expected.relation_name
    )
    from (
      values
        ('atlas_planning.need_generation_calculation_contracts'),
        ('atlas_planning.need_generation_calculation_contract_revisions'),
        ('atlas_planning.need_generation_runs'),
        ('atlas_planning.need_generation_input_snapshots'),
        ('atlas_planning.need_generation_recipe_selections'),
        ('atlas_planning.need_generation_recipe_line_uses'),
        ('atlas_planning.theoretical_need_lines'),
        ('atlas_planning.need_generation_issues'),
        ('atlas_planning.need_generation_release_snapshots'),
        ('atlas_planning.need_generation_release_snapshot_lines'),
        ('atlas_planning.need_generation_release_snapshot_issues')
    ) expected(relation_name)
  ),
  'H0A5b has exactly eleven dedicated-runtime permissive SELECT policies'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    left join pg_roles r on r.oid = acl.grantee
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
      and (acl.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
  ),
  0,
  'PUBLIC and API roles have zero direct relation privileges'
);

select is(
  (
    select count(*)::integer
    from pg_trigger t
    where t.tgrelid in (
      select c.oid
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning'
        and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and not t.tgisinternal
  ),
  22,
  'the H0A5b trigger catalog contains exactly twenty-two triggers'
);

select is(
  (
    select count(*)::integer
    from pg_trigger t
    where t.tgrelid in (
      select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning' and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and not t.tgisinternal and t.tgconstraint = 0 and t.tgname like '%_guard'
  ),
  11,
  'every H0A5b relation has one ordinary guard trigger'
);

select is(
  (
    select count(*)::integer
    from pg_trigger t
    join pg_constraint con on con.oid = t.tgconstraint
    where t.tgrelid in (
      select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning' and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and not t.tgisinternal and t.tgname like '%_integrity'
      and con.condeferrable and con.condeferred
  ),
  11,
  'every H0A5b relation has one initially deferred integrity trigger'
);

select is(
  (
    select array_agg(t.tgname order by t.tgname)::text[]
    from pg_trigger t
    where t.tgrelid in (
      select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning' and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and not t.tgisinternal
  ),
  array[
    'need_generation_calculation_contract_revisions_guard',
    'need_generation_calculation_contract_revisions_integrity',
    'need_generation_calculation_contracts_guard',
    'need_generation_calculation_contracts_integrity',
    'need_generation_input_snapshots_guard',
    'need_generation_input_snapshots_integrity',
    'need_generation_issues_guard',
    'need_generation_issues_integrity',
    'need_generation_recipe_line_uses_guard',
    'need_generation_recipe_line_uses_integrity',
    'need_generation_recipe_selections_guard',
    'need_generation_recipe_selections_integrity',
    'need_generation_release_snapshot_issues_guard',
    'need_generation_release_snapshot_issues_integrity',
    'need_generation_release_snapshot_lines_guard',
    'need_generation_release_snapshot_lines_integrity',
    'need_generation_release_snapshots_guard',
    'need_generation_release_snapshots_integrity',
    'need_generation_runs_guard',
    'need_generation_runs_integrity',
    'theoretical_need_lines_guard',
    'theoretical_need_lines_integrity'
  ]::text[],
  'all twenty-two trigger names are exact'
);

select is(
  (
    select count(*)::integer
    from pg_constraint con
    where con.conrelid in (
      select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning' and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and con.contype = 'f' and con.confdeltype <> 'r'
  ),
  0,
  'all H0A5b foreign keys use ON DELETE RESTRICT'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conrelid in (
      select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning' and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and con.contype = 'f'
      and not exists (
        select 1 from pg_index idx
        where idx.indrelid = con.conrelid and idx.indisvalid
          and (
            select array_agg(k.attnum::smallint order by k.ordinality)
            from unnest(idx.indkey::smallint[]) with ordinality as k(attnum, ordinality)
            where k.ordinality <= cardinality(con.conkey)
          ) = con.conkey
      )
  ),
  'every operational H0A5b foreign key has a matching leading-column index'
);

select is(
  (
    select count(*)::integer
    from pg_attrdef d
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where d.adrelid in (
      select c.oid from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'atlas_planning' and c.relkind = 'r'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
    ) and a.attname in (
      'need_generation_calculation_contract_id',
      'need_generation_calculation_contract_revision_id',
      'need_generation_run_id',
      'need_generation_input_snapshot_id',
      'need_generation_recipe_selection_id',
      'need_generation_recipe_line_use_id',
      'theoretical_need_line_id',
      'need_generation_issue_id',
      'need_generation_release_snapshot_id',
      'need_generation_release_snapshot_line_id',
      'need_generation_release_snapshot_issue_id'
    ) and pg_get_expr(d.adbin, d.adrelid) = 'gen_random_uuid()'
  ),
  11,
  'all eleven relation identities are database-generated UUIDs'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning' and c.relkind = 'S'
      and (c.relname like 'need_generation_%' or c.relname like 'theoretical_need%')
  ),
  0,
  'H0A5b introduces no sequence-backed business identity'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.need_generation_calculation_contracts'::regclass
      and con.conname = 'need_generation_calculation_contracts_code_check'
      and pg_get_constraintdef(con.oid) like '%school_catering_proportional_per_basis%'
  ),
  'the calculation contract code is physically fixed'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.need_generation_calculation_contract_revisions'::regclass
      and con.conname = 'need_generation_contract_revisions_formula_check'
      and pg_get_constraintdef(con.oid) like '%STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS%'
  ),
  'the authoritative formula kind is physically fixed'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.need_generation_calculation_contract_revisions'::regclass
      and con.conname = 'need_generation_contract_revisions_coercion_check'
      and pg_get_constraintdef(con.oid) like '%POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO%'
  ),
  'the final numeric coercion mode is physically fixed'
);

select is(
  (
    select count(*)::integer
    from unnest(array[
      'MISSING_ATTENDANCE_SNAPSHOT_LINE', 'MISSING_ELIGIBLE_RECIPE',
      'AMBIGUOUS_ELIGIBLE_RECIPE', 'MISSING_OR_INCOMPLETE_RELEASED_RECIPE_COMPOSITION',
      'INVALID_NONPOSITIVE_RECIPE_BASIS', 'MISSING_EXACT_RECIPE_LINE_REVISION',
      'INACTIVE_OR_INVALID_DISH', 'INACTIVE_OR_INVALID_RECIPE',
      'INACTIVE_OR_INVALID_INGREDIENT', 'INACTIVE_OR_INVALID_UNIT',
      'MISSING_REQUIRED_CONVERSION_RULE', 'INVALID_CONVERSION_FACTOR',
      'NEGATIVE_OR_INVALID_CALCULATION_RESULT', 'MISSING_TYPED_SOURCE_TRACE',
      'DUPLICATE_ATOMIC_SOURCE_ANCHOR', 'INVALID_PREDECESSOR', 'PREDECESSOR_FORK',
      'UNSUPPORTED_SPLIT', 'UNSUPPORTED_MERGE', 'SILENT_PREDECESSOR_OMISSION',
      'INVALID_REMOVAL_EVIDENCE', 'UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL',
      'ZERO_ACTIVE_THEORETICAL_QUANTITY', 'RELEASE_ATTEMPTED_WITH_BLOCKING_ISSUES',
      'RELEASE_MEMBERSHIP_MISSING', 'RELEASE_MEMBERSHIP_EXTRA',
      'RELEASE_MEMBERSHIP_ALTERED', 'RELEASE_MEMBERSHIP_DUPLICATED',
      'RELEASE_MEMBERSHIP_CROSS_RUN', 'RELEASE_MEMBERSHIP_WRONG_VERSION',
      'RELEASE_ISSUE_SUMMARY_MISMATCH'
    ]) code(value)
    where (
      select pg_get_constraintdef(con.oid)
      from pg_constraint con
      where con.conrelid = 'atlas_planning.need_generation_issues'::regclass
        and con.conname = 'need_generation_issues_code_check'
    ) like '%' || code.value || '%'
  ),
  31,
  'the persisted issue catalog contains exactly the thirty-one post-entry codes'
);

select ok(
  (
    select pg_get_constraintdef(con.oid)
    from pg_constraint con
    where con.conrelid = 'atlas_planning.need_generation_issues'::regclass
      and con.conname = 'need_generation_issues_code_check'
  ) not like all (array[
    '%READINESS_ROOT_NOT_REQUESTED%',
    '%CURRENT_READINESS_EVALUATION_NOT_READY%',
    '%STALE_READINESS_EVALUATION%',
    '%STALE_READINESS_SOURCE_SNAPSHOT%'
  ]),
  'the four pre-run failure classifications are not persisted'
);

select ok(
  to_regclass('public.need_generation_runs') is null
    and to_regclass('ops_v2.need_generation_runs') is null
    and to_regclass('public.theoretical_need_lines') is null
    and to_regclass('ops_v2.theoretical_need_lines') is null,
  'H0A5b creates no public or ops_v2 surface'
);

select is(
  (
    select count(*)::integer
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where not t.tgisinternal
      and t.tgfoid in (
        select p.oid from pg_proc p join pg_namespace pn on pn.oid = p.pronamespace
        where pn.nspname = 'atlas_planning' and p.proname like 'pa_06e_h0a5b%'
      )
      and not (
        n.nspname = 'atlas_planning'
        and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
      )
  ),
  0,
  'no H0A5b guard is attached to an upstream source relation'
);

select is(
  (
    select count(*)::integer
    from atlas_core.capabilities
    where capability_code like 'need_generation.%'
       or capability_code like 'planning.need_generation.%'
  ),
  0,
  'H0A5b adds no runtime capability or capability seed'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning' and c.relkind = 'r'
      and c.relname in (
        'need_generation_calculation_contracts',
        'need_generation_calculation_contract_revisions',
        'need_generation_runs',
        'need_generation_input_snapshots',
        'need_generation_recipe_selections',
        'need_generation_recipe_line_uses',
        'theoretical_need_lines',
        'need_generation_issues',
        'need_generation_release_snapshots',
        'need_generation_release_snapshot_lines',
        'need_generation_release_snapshot_issues'
      )
      and exists (select 1 from pg_attribute a where a.attrelid = c.oid and a.attname = 'source_type')
  ),
  0,
  'the physical lineage model contains no polymorphic source registry columns'
);

select is(
  (
    select coalesce(sum(x.rows), 0)::bigint
    from (
      select count(*)::bigint as rows from atlas_planning.need_generation_calculation_contracts
      union all select count(*) from atlas_planning.need_generation_calculation_contract_revisions
      union all select count(*) from atlas_planning.need_generation_runs
      union all select count(*) from atlas_planning.need_generation_input_snapshots
      union all select count(*) from atlas_planning.need_generation_recipe_selections
      union all select count(*) from atlas_planning.need_generation_recipe_line_uses
      union all select count(*) from atlas_planning.theoretical_need_lines
      union all select count(*) from atlas_planning.need_generation_issues
      union all select count(*) from atlas_planning.need_generation_release_snapshots
      union all select count(*) from atlas_planning.need_generation_release_snapshot_lines
      union all select count(*) from atlas_planning.need_generation_release_snapshot_issues
    ) x
  ),
  0::bigint,
  'the additive migration creates no production rows'
);

select is(
  (
    select format('%s,%s,%s', data_type, numeric_precision, numeric_scale)
    from information_schema.columns
    where table_schema = 'atlas_planning'
      and table_name = 'theoretical_need_lines'
      and column_name = 'theoretical_quantity'
  ),
  'numeric,20,6',
  'authoritative theoretical quantity has the exact numeric(20,6) typmod'
);

select is(
  (
    select count(*)::integer
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and (c.relname like 'need_generation_%' or c.relname = 'theoretical_need_lines')
      and a.attnum > 0 and not a.attisdropped
      and a.atttypid in ('json'::regtype, 'jsonb'::regtype)
  ),
  0,
  'typed H0A5b lineage uses no JSON columns'
);

select * from finish();
rollback;
