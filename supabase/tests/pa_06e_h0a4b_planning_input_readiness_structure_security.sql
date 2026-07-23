begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(30);

select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'planning_input%'
  ),
  array[
    'planning_input_evaluation_issues',
    'planning_input_evaluations',
    'planning_input_sets'
  ]::text[],
  'H0A4b creates exactly the three approved private relations'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.planning_input_sets'::regclass
      and a.attnum > 0 and not a.attisdropped
  ),
  array[
    'planning_input_set_id', 'period_start', 'period_end',
    'readiness_status', 'current_evaluation_id', 'created_at', 'updated_at'
  ]::text[],
  'planning_input_sets has only the approved stable-root columns'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.planning_input_evaluations'::regclass
      and a.attnum > 0 and not a.attisdropped
  ),
  array[
    'planning_input_evaluation_id', 'planning_input_set_id',
    'evaluation_version', 'evaluation_result', 'weekly_menu_id',
    'weekly_menu_version', 'weekly_menu_approval_snapshot_id',
    'attendance_batch_id', 'attendance_version',
    'attendance_approval_snapshot_id', 'blocking_issue_count',
    'warning_count', 'evaluated_by_actor_id', 'evaluated_at'
  ]::text[],
  'planning_input_evaluations has only exact source, count, and actor evidence'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.planning_input_evaluation_issues'::regclass
      and a.attnum > 0 and not a.attisdropped
  ),
  array[
    'planning_input_readiness_issue_id', 'planning_input_evaluation_id',
    'planning_input_set_id', 'evaluation_version', 'severity', 'issue_code',
    'message', 'input_type', 'school_id', 'service_date'
  ]::text[],
  'planning_input_evaluation_issues has only immutable classified evidence columns'
);

select is(
  (
    select count(*)::integer
    from pg_attrdef d
    join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
    where d.adrelid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    )
      and a.attname in (
        'planning_input_set_id', 'planning_input_evaluation_id',
        'planning_input_readiness_issue_id'
      )
      and pg_get_expr(d.adbin, d.adrelid) = 'gen_random_uuid()'
  ),
  3,
  'all three H0A4b identities are database-generated UUIDs'
);

select is(
  (
    select array_agg(con.conname order by con.conname)::text[]
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and con.contype = 'p'
  ),
  array[
    'planning_input_evaluation_issues_pkey',
    'planning_input_evaluations_pkey',
    'planning_input_sets_pkey'
  ]::text[],
  'each H0A4b relation has its exact UUID primary key'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_sets'::regclass
      and con.conname = 'planning_input_sets_period_key'
      and con.contype = 'u'
  ),
  'one stable Planning Input Set exists for one exact evaluated period'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_sets'::regclass
      and con.conname = 'planning_input_sets_current_evaluation_fkey'
      and con.contype = 'f' and con.condeferrable and con.condeferred
      and con.confdeltype = 'r'
  ),
  'the root current pointer is a deferred RESTRICT ownership foreign key'
);

select is(
  (
    select array_agg(con.conname order by con.conname)::text[]
    from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_evaluations'::regclass
      and con.contype = 'f'
  ),
  array[
    'planning_input_evaluations_actor_fkey',
    'planning_input_evaluations_attendance_snapshot_fkey',
    'planning_input_evaluations_set_fkey',
    'planning_input_evaluations_weekly_menu_snapshot_fkey'
  ]::text[],
  'evaluations have only the root, actor, and two typed snapshot foreign keys'
);

select is(
  (
    select pg_get_constraintdef(con.oid)
    from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_evaluation_issues'::regclass
      and con.conname = 'planning_input_evaluation_issues_evaluation_fkey'
  ),
  'FOREIGN KEY (planning_input_evaluation_id, planning_input_set_id, evaluation_version) REFERENCES atlas_planning.planning_input_evaluations(planning_input_evaluation_id, planning_input_set_id, evaluation_version) ON DELETE RESTRICT',
  'issues carry exact evaluation/root/version ownership'
);

select is(
  (
    select count(*)::integer
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and con.contype = 'f' and con.confdeltype = 'r'
  ),
  7,
  'all seven operational H0A4b foreign keys use ON DELETE RESTRICT'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
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
  'every H0A4b foreign key has a matching leading-column index'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_sets'::regclass
      and con.conname = 'planning_input_sets_status_check'
      and pg_get_constraintdef(con.oid) ilike all (array[
        '%NOT_READY%', '%READY%', '%NEED_GENERATION_REQUESTED%', '%INVALIDATED%'
      ])
  ),
  'root status vocabulary is exact'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_evaluations'::regclass
      and con.conname = 'planning_input_evaluations_result_check'
      and pg_get_constraintdef(con.oid) like '%NOT_READY%'
      and pg_get_constraintdef(con.oid) like '%READY%'
  ),
  'evaluation results are limited to NOT_READY and READY'
);

select is(
  (
    select count(*)::integer
    from unnest(array[
      'MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT',
      'MISSING_ATTENDANCE_APPROVAL_SNAPSHOT',
      'SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH',
      'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'STALE_OR_MISMATCHED_SNAPSHOT_BINDING',
      'REQUEST_WITHOUT_CURRENT_READY_EVALUATION',
      'MENU_SCHOOL_DATE_WITHOUT_ATTENDANCE',
      'ATTENDANCE_SCHOOL_DATE_WITHOUT_MENU',
      'ZERO_ATTENDANCE_FOR_PLANNED_MENU'
    ]) as code(value)
    where (
      select pg_get_constraintdef(con.oid)
      from pg_constraint con
      where con.conrelid = 'atlas_planning.planning_input_evaluation_issues'::regclass
        and con.conname = 'planning_input_evaluation_issues_code_check'
    ) like '%' || code.value || '%'
  ),
  10,
  'the issue-code catalog contains all and only the ten approved codes'
);

select ok(
  exists (
    select 1 from pg_constraint con
    where con.conrelid = 'atlas_planning.planning_input_evaluation_issues'::regclass
      and con.conname = 'planning_input_evaluation_issues_severity_code_check'
      and pg_get_constraintdef(con.oid) like '%BLOCKING%'
      and pg_get_constraintdef(con.oid) like '%WARNING%'
  ),
  'blocking and warning codes are physically classified by severity'
);

select ok(
  exists (
    select 1 from pg_index idx
    where idx.indrelid = 'atlas_planning.planning_input_evaluation_issues'::regclass
      and idx.indisunique and idx.indnullsnotdistinct
  ),
  'contextual issue uniqueness treats null contexts deterministically'
);

select is(
  (
    select count(*)::integer from pg_class c
    where c.oid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and c.relrowsecurity
  ), 3,
  'RLS is enabled on all three private relations'
);

select is(
  (
    select count(*)::integer from pg_class c
    where c.oid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and c.relforcerowsecurity
  ), 3,
  'RLS is forced on all three private relations'
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
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
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
        ('atlas_planning.planning_input_sets'),
        ('atlas_planning.planning_input_evaluations'),
        ('atlas_planning.planning_input_evaluation_issues')
    ) expected(relation_name)
  ),
  'H0A4b has exactly three dedicated-runtime permissive SELECT policies'
);

select is(
  (
    select count(*)::integer from pg_class c
    where c.oid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and pg_get_userbyid(c.relowner) = 'atlas_owner'
  ), 3,
  'atlas_owner owns every H0A4b relation'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    join pg_roles r on r.oid = acl.grantee
    where c.oid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and r.rolname in ('anon', 'authenticated', 'service_role')
  ), 0,
  'API roles have zero relation privileges'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning' and p.proname like 'pa_06e_h0a4b%'
  ),
  array[
    'pa_06e_h0a4b_planning_input_evaluation_guard',
    'pa_06e_h0a4b_planning_input_integrity_guard',
    'pa_06e_h0a4b_planning_input_issue_guard',
    'pa_06e_h0a4b_planning_input_set_guard'
  ]::text[],
  'the private H0A4b guard-function catalog is exact'
);

select is(
  (
    select count(*)::integer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning' and p.proname like 'pa_06e_h0a4b%'
      and pg_get_userbyid(p.proowner) = 'atlas_owner'
      and not p.prosecdef
      and coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ), 4,
  'every guard is atlas_owner-owned, invoker-security, and has an empty search_path'
);

select is(
  (
    select count(*)::integer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    left join pg_roles r on r.oid = acl.grantee
    where n.nspname = 'atlas_planning' and p.proname like 'pa_06e_h0a4b%'
      and acl.privilege_type = 'EXECUTE'
      and (acl.grantee = 0 or r.rolname in ('anon', 'authenticated', 'service_role'))
  ), 0,
  'PUBLIC and API roles cannot execute private H0A4b guards'
);

select is(
  (
    select array_agg(t.tgname order by t.tgname)::text[]
    from pg_trigger t
    where t.tgrelid in (
      'atlas_planning.planning_input_sets'::regclass,
      'atlas_planning.planning_input_evaluations'::regclass,
      'atlas_planning.planning_input_evaluation_issues'::regclass
    ) and not t.tgisinternal
  ),
  array[
    'planning_input_evaluation_issues_guard',
    'planning_input_evaluation_issues_integrity',
    'planning_input_evaluations_guard',
    'planning_input_evaluations_integrity',
    'planning_input_sets_guard',
    'planning_input_sets_integrity'
  ]::text[],
  'the lifecycle, immutability, and deferred integrity trigger catalog is exact'
);

select is(
  (
    select count(*)::integer from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ), 19,
  'H0A4b remains compatible with the exact 19-function atlas_api surface'
);

select ok(
  to_regclass('public.planning_input_sets') is null
    and to_regclass('ops_v2.planning_input_sets') is null,
  'H0A4b creates no public or ops_v2 readiness surface'
);

select is(
  (
    select count(*)::integer from atlas_core.capabilities
    where capability_code like 'planning.input_readiness.%'
  ), 0,
  'H0A4b adds no capability or seed vocabulary'
);

select is(
  (
    select count(*)::integer from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning' and c.relkind = 'S'
      and c.relname like 'planning_input%'
  ), 0,
  'database-generated UUID identities require no new sequences'
);

select * from finish();
rollback;
