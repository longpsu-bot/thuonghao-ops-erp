begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(36);

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
    'warning_count', 'evaluated_by_actor_id', 'evaluated_at',
    'pantry_need_batch_id', 'pantry_need_batch_version',
    'pantry_need_approval_snapshot_id'
  ]::text[],
  'planning_input_evaluations has only exact source, count, actor, and Pantry evidence'
);

select is(
  (
    select jsonb_agg(
      jsonb_build_object(
        'column', a.attname,
        'nullable', not a.attnotnull,
        'default', pg_get_expr(d.adbin, d.adrelid)
      )
      order by a.attnum
    )
    from pg_attribute a
    left join pg_attrdef d
      on d.adrelid = a.attrelid and d.adnum = a.attnum
    where a.attrelid =
        'atlas_planning.planning_input_evaluations'::regclass
      and a.attname in (
        'pantry_need_batch_id',
        'pantry_need_batch_version',
        'pantry_need_approval_snapshot_id'
      )
  ),
  jsonb_build_array(
    jsonb_build_object(
      'column', 'pantry_need_batch_id',
      'nullable', true,
      'default', null
    ),
    jsonb_build_object(
      'column', 'pantry_need_batch_version',
      'nullable', true,
      'default', null
    ),
    jsonb_build_object(
      'column', 'pantry_need_approval_snapshot_id',
      'nullable', true,
      'default', null
    )
  ),
  'the three Pantry binding columns are nullable and default-free'
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
    'planning_input_evaluations_pantry_snapshot_fkey',
    'planning_input_evaluations_set_fkey',
    'planning_input_evaluations_weekly_menu_snapshot_fkey'
  ]::text[],
  'evaluations have only the root, actor, and three typed snapshot foreign keys'
);

select ok(
  exists (
    select 1
    from pg_constraint con
    where con.conrelid =
        'atlas_planning.planning_input_evaluations'::regclass
      and con.conname = 'planning_input_evaluations_pantry_family_check'
      and con.contype = 'c'
      and pg_get_constraintdef(con.oid) like
        '%pantry_need_batch_id IS NULL%'
      and pg_get_constraintdef(con.oid) like
        '%pantry_need_batch_version IS NULL%'
      and pg_get_constraintdef(con.oid) like
        '%pantry_need_approval_snapshot_id IS NULL%'
      and pg_get_constraintdef(con.oid) like
        '%pantry_need_batch_id IS NOT NULL%'
      and pg_get_constraintdef(con.oid) like
        '%pantry_need_batch_version > 0%'
      and pg_get_constraintdef(con.oid) like
        '%pantry_need_approval_snapshot_id IS NOT NULL%'
  ),
  'the Pantry family is all-null or all-present with a positive version'
);

select is(
  (
    select pg_get_constraintdef(con.oid)
    from pg_constraint con
    where con.conrelid =
        'atlas_planning.pantry_need_approval_snapshots'::regclass
      and con.conname =
        'pantry_need_approval_snapshots_readiness_ownership_key'
  ),
  'UNIQUE (pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version)',
  'Pantry snapshots expose the exact readiness ownership triple'
);

select is(
  (
    select pg_get_constraintdef(con.oid)
    from pg_constraint con
    where con.conrelid =
        'atlas_planning.planning_input_evaluations'::regclass
      and con.conname = 'planning_input_evaluations_pantry_snapshot_fkey'
  ),
  'FOREIGN KEY (pantry_need_approval_snapshot_id, pantry_need_batch_id, pantry_need_batch_version) REFERENCES atlas_planning.pantry_need_approval_snapshots(pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version) ON DELETE RESTRICT',
  'evaluations bind the exact Pantry snapshot, batch, and approved version'
);

select is(
  (
    select jsonb_build_object(
      'columns',
      (
        select jsonb_agg(a.attname order by key_column.ordinality)
        from unnest(idx.indkey::smallint[]) with ordinality
          as key_column(attnum, ordinality)
        join pg_attribute a
          on a.attrelid = idx.indrelid
          and a.attnum = key_column.attnum
        where key_column.ordinality <= idx.indnkeyatts
      ),
      'predicate',
      pg_get_expr(idx.indpred, idx.indrelid)
    )
    from pg_index idx
    join pg_class index_relation on index_relation.oid = idx.indexrelid
    where index_relation.relname =
      'planning_input_evaluations_pantry_snapshot_idx'
      and idx.indrelid =
        'atlas_planning.planning_input_evaluations'::regclass
  ),
  jsonb_build_object(
    'columns',
    jsonb_build_array(
      'pantry_need_approval_snapshot_id',
      'pantry_need_batch_id',
      'pantry_need_batch_version'
    ),
    'predicate',
    '(pantry_need_approval_snapshot_id IS NOT NULL)'
  ),
  'the Pantry binding index leads with the exact evaluation-side FK order'
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
  8,
  'all eight operational readiness foreign keys use ON DELETE RESTRICT'
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
      'MISSING_PANTRY_APPROVAL_SNAPSHOT',
      'SOURCE_SNAPSHOT_OWNERSHIP_MISMATCH',
      'WEEKLY_MENU_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'ATTENDANCE_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
      'PANTRY_PERIOD_DOES_NOT_COVER_EVALUATED_PERIOD',
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
  12,
  'the issue-code catalog contains all and only the twelve approved codes'
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
      and policy.polname = 'pa_06e_h0cb_materialization_select'
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
    select count(*)::integer
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid in (
      'atlas_planning.weekly_menus'::regclass,
      'atlas_planning.weekly_menu_approval_snapshots'::regclass,
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.pantry_need_batches'::regclass,
      'atlas_planning.pantry_need_approval_snapshots'::regclass
    )
      and not t.tgisinternal
      and p.proname like 'pa_06e_h0a4b%'
  ),
  0,
  'readiness adds no trigger to Weekly Menu, Attendance, or Pantry sources'
);

select is(
  jsonb_build_object(
    'sets', (select count(*) from atlas_planning.planning_input_sets),
    'evaluations',
    (select count(*) from atlas_planning.planning_input_evaluations),
    'issues',
    (select count(*) from atlas_planning.planning_input_evaluation_issues)
  ),
  jsonb_build_object('sets', 0, 'evaluations', 0, 'issues', 0),
  'PANTRY-RDY-02 seeds and backfills no readiness row'
);

select ok(
  to_regclass('public.planning_input_sets') is null
    and to_regclass('ops_v2.planning_input_sets') is null,
  'H0A4b creates no public or ops_v2 readiness surface'
);

select is(
  (
    select jsonb_agg(
      jsonb_build_object(
        'capability_code', capability_code,
        'capability_status', capability_status,
        'owning_domain', owning_domain
      )
      order by capability_code
    )
    from atlas_core.capabilities
    where capability_code like 'planning.input_readiness.%'
  ),
  jsonb_build_array(
    jsonb_build_object(
      'capability_code', 'planning.input_readiness.write',
      'capability_status', 'ACTIVE',
      'owning_domain', 'PLANNING'
    )
  ),
  'readiness capability vocabulary is exactly the active Planning-owned RMVP-03B write capability'
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
