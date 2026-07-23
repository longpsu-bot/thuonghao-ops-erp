begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(28);

-- This suite owns only the H0A3b database shape and fail-closed boundary.
select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'attendance%'
  ),
  array[
    'attendance_approval_snapshot_lines',
    'attendance_approval_snapshots',
    'attendance_batches',
    'attendance_lines'
  ]::text[],
  'H0A3b creates exactly the four approved private Attendance relations'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_batches'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_batch_id',
    'period_start',
    'period_end',
    'source_type',
    'source_name',
    'source_signature',
    'attendance_status',
    'row_count',
    'imported_by_actor_id',
    'imported_at',
    'latest_approved_by_actor_id',
    'latest_approved_at',
    'latest_approval_snapshot_id',
    'version',
    'created_at',
    'updated_at'
  ]::text[],
  'attendance_batches has only the bounded source, lifecycle, approval, and version fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_line_id',
    'attendance_batch_id',
    'school_id',
    'service_date',
    'student_portions',
    'teacher_portions',
    'line_status',
    'source_row_reference',
    'created_by_actor_id',
    'created_at',
    'updated_by_actor_id',
    'updated_at'
  ]::text[],
  'attendance_lines has only stable School/date exact portions and actor/time fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_approval_snapshots'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_approval_snapshot_id',
    'attendance_batch_id',
    'attendance_version',
    'approved_by_actor_id',
    'approved_at'
  ]::text[],
  'Attendance approval headers contain only exact batch/version and approval evidence'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_planning.attendance_approval_snapshot_lines'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'attendance_approval_snapshot_line_id',
    'attendance_approval_snapshot_id',
    'attendance_batch_id',
    'attendance_version',
    'attendance_line_id',
    'school_id',
    'service_date',
    'student_portions',
    'teacher_portions',
    'source_row_reference'
  ]::text[],
  'Attendance approval snapshot lines contain only the exact accepted line copy'
);

select is(
  (
    select count(*)::integer
    from pg_attrdef ad
    join pg_attribute a
      on a.attrelid = ad.adrelid
     and a.attnum = ad.adnum
    where ad.adrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and a.attname in (
        'attendance_batch_id',
        'attendance_line_id',
        'attendance_approval_snapshot_id',
        'attendance_approval_snapshot_line_id'
      )
      and pg_get_expr(ad.adbin, ad.adrelid) = 'gen_random_uuid()'
  ),
  4,
  'all four H0A3b identities are database-generated UUIDs'
);

select is(
  (
    select array_agg(format_type(a.atttypid, a.atttypmod) order by a.attname)::text[]
    from pg_attribute a
    where a.attrelid in (
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and a.attname in ('student_portions', 'teacher_portions')
      and a.attnum > 0
      and not a.attisdropped
  ),
  array['integer', 'integer', 'integer', 'integer']::text[],
  'working and approved student/teacher portions are exact integers'
);

select ok(
  to_regclass('atlas_planning.attendance_issues') is null
  and to_regclass('atlas_planning.attendance_events') is null
  and to_regclass('atlas_planning.attendance_defaults') is null,
  'H0A3b creates no issue, event, reason, default, or policy relation'
);

select ok(
  to_regclass('public.attendance_batches') is null
  and to_regclass('ops_v2.attendance_batches') is null,
  'H0A3b creates no public or OPS v2 Attendance relation'
);

select is(
  (
    select count(*)::integer
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
  ),
  48,
  'the four Attendance relations have exactly the approved 48 constraints and constraint triggers'
);

select is(
  (
    select array_agg(con.conname order by con.conname)::text[]
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
  ),
  array[
    'attendance_approval_snapshot_lines_assignment_key',
    'attendance_approval_snapshot_lines_attendance_line_fkey',
    'attendance_approval_snapshot_lines_integrity_guard',
    'attendance_approval_snapshot_lines_line_key',
    'attendance_approval_snapshot_lines_pkey',
    'attendance_approval_snapshot_lines_school_fkey',
    'attendance_approval_snapshot_lines_snapshot_fkey',
    'attendance_approval_snapshot_lines_source_row_reference_check',
    'attendance_approval_snapshot_lines_student_portions_check',
    'attendance_approval_snapshot_lines_teacher_portions_check',
    'attendance_approval_snapshot_lines_version_check',
    'attendance_approval_snapshots_approved_by_actor_fkey',
    'attendance_approval_snapshots_batch_fkey',
    'attendance_approval_snapshots_batch_version_key',
    'attendance_approval_snapshots_id_batch_key',
    'attendance_approval_snapshots_id_ownership_key',
    'attendance_approval_snapshots_integrity_guard',
    'attendance_approval_snapshots_pkey',
    'attendance_approval_snapshots_version_check',
    'attendance_batches_approval_evidence_check',
    'attendance_batches_approved_status_evidence_check',
    'attendance_batches_id_version_key',
    'attendance_batches_imported_by_actor_fkey',
    'attendance_batches_latest_approval_snapshot_fkey',
    'attendance_batches_latest_approved_by_actor_fkey',
    'attendance_batches_period_check',
    'attendance_batches_period_key',
    'attendance_batches_pkey',
    'attendance_batches_row_count_check',
    'attendance_batches_snapshot_integrity_guard',
    'attendance_batches_source_name_check',
    'attendance_batches_source_signature_check',
    'attendance_batches_source_type_check',
    'attendance_batches_status_check',
    'attendance_batches_timestamps_check',
    'attendance_batches_version_check',
    'attendance_lines_assignment_key',
    'attendance_lines_batch_fkey',
    'attendance_lines_created_by_actor_fkey',
    'attendance_lines_id_batch_key',
    'attendance_lines_pkey',
    'attendance_lines_school_fkey',
    'attendance_lines_source_row_reference_check',
    'attendance_lines_status_check',
    'attendance_lines_student_portions_check',
    'attendance_lines_teacher_portions_check',
    'attendance_lines_timestamps_check',
    'attendance_lines_updated_by_actor_fkey'
  ]::text[],
  'the Attendance constraint catalog is exact'
);

select is(
  (
    select array_agg(
      format('%s.%s->%s:%s', c.relname, con.conname, con.confrelid::regclass::text, con.confdeltype)
      order by c.relname, con.conname
    )::text[]
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    where con.conrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and con.contype = 'f'
  ),
  array[
    'attendance_approval_snapshot_lines.attendance_approval_snapshot_lines_attendance_line_fkey->atlas_planning.attendance_lines:r',
    'attendance_approval_snapshot_lines.attendance_approval_snapshot_lines_school_fkey->atlas_admin.schools:r',
    'attendance_approval_snapshot_lines.attendance_approval_snapshot_lines_snapshot_fkey->atlas_planning.attendance_approval_snapshots:r',
    'attendance_approval_snapshots.attendance_approval_snapshots_approved_by_actor_fkey->atlas_core.actors:r',
    'attendance_approval_snapshots.attendance_approval_snapshots_batch_fkey->atlas_planning.attendance_batches:r',
    'attendance_batches.attendance_batches_imported_by_actor_fkey->atlas_core.actors:r',
    'attendance_batches.attendance_batches_latest_approval_snapshot_fkey->atlas_planning.attendance_approval_snapshots:r',
    'attendance_batches.attendance_batches_latest_approved_by_actor_fkey->atlas_core.actors:r',
    'attendance_lines.attendance_lines_batch_fkey->atlas_planning.attendance_batches:r',
    'attendance_lines.attendance_lines_created_by_actor_fkey->atlas_core.actors:r',
    'attendance_lines.attendance_lines_school_fkey->atlas_admin.schools:r',
    'attendance_lines.attendance_lines_updated_by_actor_fkey->atlas_core.actors:r'
  ]::text[],
  'all 12 Attendance foreign keys have the exact approved target and RESTRICT action'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and con.contype = 'f'
      and not exists (
        select 1
        from pg_index idx
        where idx.indrelid = con.conrelid
          and idx.indisvalid
          and (
            select array_agg(key_column.attnum::smallint order by key_column.ordinality)
            from unnest(idx.indkey::smallint[]) with ordinality
              as key_column(attnum, ordinality)
            where key_column.ordinality <= cardinality(con.conkey)
          ) = con.conkey
      )
  ),
  'every Attendance foreign key has a matching leading-column index'
);

select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relname like 'attendance%_idx'
      and c.relkind = 'i'
  ),
  array[
    'attendance_approval_snapshot_lines_attendance_line_idx',
    'attendance_approval_snapshot_lines_school_idx',
    'attendance_approval_snapshot_lines_snapshot_ownership_idx',
    'attendance_approval_snapshots_approved_by_actor_idx',
    'attendance_batches_imported_by_actor_idx',
    'attendance_batches_latest_approval_snapshot_idx',
    'attendance_batches_latest_approved_by_actor_idx',
    'attendance_lines_created_by_actor_idx',
    'attendance_lines_school_idx',
    'attendance_lines_updated_by_actor_idx'
  ]::text[],
  'the explicit Attendance index catalog is exact'
);

select is(
  (
    select array_agg(format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid)) order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
  ),
  array[
    'pa_06e_h0a3b_attendance_lifecycle_guard()',
    'pa_06e_h0a3b_attendance_line_guard()',
    'pa_06e_h0a3b_attendance_snapshot_guard()',
    'pa_06e_h0a3b_attendance_snapshot_integrity_guard()'
  ]::text[],
  'H0A3b exposes exactly four private guard functions'
);

select is(
  (
    select array_agg(t.tgname order by t.tgname)::text[]
    from pg_trigger t
    where t.tgrelid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and not t.tgisinternal
  ),
  array[
    'attendance_approval_snapshot_lines_immutable_guard',
    'attendance_approval_snapshot_lines_integrity_guard',
    'attendance_approval_snapshots_immutable_guard',
    'attendance_approval_snapshots_integrity_guard',
    'attendance_batches_lifecycle_guard',
    'attendance_batches_snapshot_integrity_guard',
    'attendance_lines_mutability_guard'
  ]::text[],
  'H0A3b installs exactly the four row guards and three deferred integrity guards'
);

select ok(
  not exists (
    select 1
    from pg_class c
    where c.oid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and (not c.relrowsecurity or not c.relforcerowsecurity)
  ),
  'all four H0A3b relations have RLS enabled and forced'
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
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
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
        ('atlas_planning.attendance_batches'),
        ('atlas_planning.attendance_lines'),
        ('atlas_planning.attendance_approval_snapshots'),
        ('atlas_planning.attendance_approval_snapshot_lines')
    ) expected(relation_name)
  ),
  'H0A3b has exactly four dedicated-runtime permissive SELECT policies'
);

select is(
  (
    select count(*)::integer
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'S'
      and c.relname like 'attendance%'
  ),
  0,
  'database-generated UUID identities add no Attendance sequences or sequence grants'
);

select is(
  (
    select array_agg(owner.rolname order by c.relname)::text[]
    from pg_class c
    join pg_roles owner on owner.oid = c.relowner
    where c.oid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
  ),
  array['atlas_owner', 'atlas_owner', 'atlas_owner', 'atlas_owner']::text[],
  'all four H0A3b relations are owned by atlas_owner'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles owner on owner.oid = p.proowner
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
      and owner.rolname = 'atlas_owner'
  ),
  4,
  'the four minimum private H0A3b guard functions are owned by atlas_owner'
);

select ok(
  not exists (
    select 1
    from pg_class c
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    left join pg_roles grantee on grantee.oid = acl.grantee
    where c.oid in (
      'atlas_planning.attendance_batches'::regclass,
      'atlas_planning.attendance_lines'::regclass,
      'atlas_planning.attendance_approval_snapshots'::regclass,
      'atlas_planning.attendance_approval_snapshot_lines'::regclass
    )
      and (acl.grantee = 0 or grantee.rolname in ('anon', 'authenticated', 'service_role'))
  ),
  'PUBLIC and API roles have no H0A3b table privileges of any kind'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    left join pg_roles grantee on grantee.oid = acl.grantee
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
      and (acl.grantee = 0 or grantee.rolname in ('anon', 'authenticated', 'service_role'))
      and acl.privilege_type = 'EXECUTE'
  ),
  'PUBLIC and API roles cannot execute private H0A3b guard functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_planning'
      and p.proname like 'pa_06e_h0a3b_%'
      and not coalesce(p.proconfig, array[]::text[]) @> array['search_path=""']
  ),
  'every private H0A3b guard function has a hardened empty search path'
);

select ok(
  not exists (
    select 1
    from pg_default_acl d
    join pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral aclexplode(d.defaclacl) privilege
    left join pg_roles grantee on grantee.oid = privilege.grantee
    where d.defaclrole = 'atlas_owner'::regrole
      and n.nspname = 'atlas_planning'
      and d.defaclobjtype in ('r', 'S', 'f')
      and (
        privilege.grantee = 0
        or grantee.rolname in ('anon', 'authenticated', 'service_role')
      )
  ),
  'atlas_owner Attendance default privileges remain fail-closed for PUBLIC and API roles'
);

select is(
  (
    select array_agg(
      format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
      order by p.proname
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)',
    'apply_supplier_evidence_to_allocation(request jsonb)',
    'close_successful_trip(request jsonb)',
    'confirm_dispatch_load(request jsonb)',
    'confirm_successful_delivery(request jsonb)',
    'create_confirmed_needs_from_generation(request jsonb)',
    'create_dispatch_plan(request jsonb)',
    'create_or_assign_dispatch_trip(request jsonb)',
    'get_command_audit_timeline(request jsonb)',
    'get_dispatch_evidence_readiness(request jsonb)',
    'get_operator_blockers(request jsonb)',
    'get_supplier_direct_trace(request jsonb)',
    'record_dispatch_departure(request jsonb)',
    'record_supplier_receiving_evidence(request jsonb)',
    'record_wholesale_source(request jsonb)',
    'release_dispatch_requirement(request jsonb)',
    'release_purchase_handoff(request jsonb)',
    'release_supplier_purchase_order(request jsonb)',
    'release_wholesale_order(request jsonb)'
  ]::text[],
  'the exact 19-function atlas_api registry includes CMD-15'
);

select is((select count(*)::integer from atlas_core.roles), 0, 'H0A3b seeds no roles');
select is(
  (
    select jsonb_agg(
      jsonb_build_object(
        'capability_code', capability_code,
        'capability_name', capability_name,
        'owning_domain', owning_domain,
        'capability_status', capability_status
      )
      order by capability_code
    )
    from atlas_core.capabilities
  ),
  jsonb_build_array(
    jsonb_build_object(
      'capability_code', 'confirmed_need_generation.materialize',
      'capability_name', 'Materialize Confirmed Need from Need Generation',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    )
  ),
  'the capability catalog contains only the active Planning materialization capability'
);

select * from finish();

rollback;
