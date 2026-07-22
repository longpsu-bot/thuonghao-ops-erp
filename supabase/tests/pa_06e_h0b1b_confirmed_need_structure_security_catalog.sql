begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(52);

select has_table('atlas_planning', 'confirmed_need_line_revision_contributions', 'the exact contribution relation exists');
select columns_are(
  'atlas_planning',
  'confirmed_need_line_revision_contributions',
  array[
    'confirmed_need_line_revision_contribution_id',
    'confirmed_need_batch_id',
    'confirmed_need_line_id',
    'confirmed_need_line_revision_id',
    'need_generation_run_id',
    'need_generation_run_version',
    'need_generation_release_snapshot_id',
    'need_generation_release_snapshot_line_id',
    'theoretical_need_line_id',
    'service_date',
    'customer_id',
    'school_id',
    'delivery_location_id',
    'ingredient_id',
    'source_unit_id',
    'controlled_unit_id',
    'source_theoretical_quantity',
    'controlled_contribution_quantity',
    'created_at'
  ]::text[],
  'the contribution relation has exactly the approved nineteen columns'
);
select table_owner_is('atlas_planning', 'confirmed_need_line_revision_contributions', 'atlas_owner', 'atlas_owner owns contribution membership');
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass),
  'contribution membership has enabled and forced RLS'
);
select is(
  (
    select jsonb_object_agg(
      policy.polname,
      jsonb_build_object(
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
    )
    from pg_policy policy
    where policy.polrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass
  ),
  jsonb_build_object(
    'pa_06e_h0cb_contribution_insert', jsonb_build_object(
      'command', 'a',
      'permissive', true,
      'roles', jsonb_build_array('atlas_planning_materialization_runtime'),
      'using', null,
      'with_check', 'true'
    ),
    'pa_06e_h0cb_contribution_select', jsonb_build_object(
      'command', 'r',
      'permissive', true,
      'roles', jsonb_build_array('atlas_planning_materialization_runtime'),
      'using', 'true',
      'with_check', null
    )
  ),
  'contribution membership has exactly the two dedicated-runtime permissive policies'
);
select is(
  (
    select count(*)::integer
    from pg_class relation
    cross join lateral aclexplode(coalesce(relation.relacl, acldefault('r', relation.relowner))) privilege
    left join pg_roles role on role.oid = privilege.grantee
    where relation.oid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass
      and (privilege.grantee = 0 or role.rolname in ('anon', 'authenticated', 'service_role', 'atlas_planning_command_runtime'))
  ),
  0,
  'contribution membership has no PUBLIC, API-role, or Planning-runtime privileges'
);

select is(
  (select array_agg(column_name order by ordinal_position)::text[] from information_schema.columns where table_schema = 'atlas_planning' and table_name = 'confirmed_need_batches' and column_name in ('source_kind','origin_need_generation_run_id','origin_need_generation_run_version','origin_need_generation_release_snapshot_id','current_need_generation_run_id','current_need_generation_run_version','current_need_generation_release_snapshot_id')),
  array['source_kind','origin_need_generation_run_id','origin_need_generation_run_version','origin_need_generation_release_snapshot_id','current_need_generation_run_id','current_need_generation_run_version','current_need_generation_release_snapshot_id']::text[],
  'batch source generalization adds exactly the seven approved columns'
);
select is(
  (select array_agg(column_name order by ordinal_position)::text[] from information_schema.columns where table_schema = 'atlas_planning' and table_name = 'confirmed_need_lines' and column_name in ('source_kind','service_date','customer_id','school_id','delivery_location_id','ingredient_id','controlled_unit_id')),
  array['source_kind','service_date','customer_id','school_id','delivery_location_id','ingredient_id','controlled_unit_id']::text[],
  'stable-line source generalization adds exactly the seven approved columns'
);
select is(
  (select array_agg(column_name order by ordinal_position)::text[] from information_schema.columns where table_schema = 'atlas_planning' and table_name = 'confirmed_need_line_revisions' and column_name in ('source_kind','confirmed_need_batch_id','need_generation_run_id','need_generation_run_version','need_generation_release_snapshot_id','service_date','customer_id','school_id','delivery_location_id')),
  array['source_kind','confirmed_need_batch_id','need_generation_run_id','need_generation_run_version','need_generation_release_snapshot_id','service_date','customer_id','school_id','delivery_location_id']::text[],
  'revision source generalization adds exactly the nine approved columns'
);
select is((select count(*)::integer from information_schema.columns where table_schema = 'atlas_planning' and table_name in ('confirmed_need_batches','confirmed_need_lines','confirmed_need_line_revisions') and column_name = 'source_kind' and is_nullable = 'NO'), 3, 'source kind is non-null at all three aggregate levels');
select is((select count(*)::integer from information_schema.columns where table_schema = 'atlas_planning' and table_name in ('confirmed_need_batches','confirmed_need_lines','confirmed_need_line_revisions') and column_name = 'source_kind' and column_default = '''WHOLESALE''::text'), 3, 'source kind defaults to WHOLESALE at all three aggregate levels');
select is((select count(*)::integer from information_schema.columns where table_schema = 'atlas_planning' and ((table_name = 'confirmed_need_batches' and column_name = 'wholesale_order_id') or (table_name = 'confirmed_need_lines' and column_name = 'wholesale_order_line_id') or (table_name = 'confirmed_need_line_revisions' and column_name = 'wholesale_order_line_revision_id')) and is_nullable = 'YES'), 3, 'the three typed Wholesale source columns are nullable under family checks');
select is((select count(*)::integer from pg_constraint where conrelid = 'atlas_planning.confirmed_need_batches'::regclass and conname in ('confirmed_need_batches_source_kind_check','confirmed_need_batches_source_family_check')), 2, 'batch source-kind and source-family checks exist');
select is((select count(*)::integer from pg_constraint where conrelid = 'atlas_planning.confirmed_need_lines'::regclass and conname in ('confirmed_need_lines_source_kind_check','confirmed_need_lines_source_family_check')), 2, 'stable-line source-kind and source-family checks exist');
select is((select count(*)::integer from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revisions'::regclass and conname in ('confirmed_need_line_revisions_source_kind_check','confirmed_need_line_revisions_source_family_check')), 2, 'revision source-kind and source-family checks exist');
select is((select count(*)::integer from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname in ('confirmed_need_line_revision_contributions_quantity_check','confirmed_need_line_revision_contributions_unit_check')), 2, 'contribution no-conversion quantity and Unit checks exist');
select col_default_is('atlas_planning', 'confirmed_need_line_revision_contributions', 'confirmed_need_line_revision_contribution_id', 'gen_random_uuid()', 'contribution identity remains server-generated');

select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_admin.schools'::regclass and conname = 'schools_customer_id_school_id_key'), 'School has the minimum same-customer ownership key');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_batches'::regclass and conname = 'confirmed_need_batches_id_source_key'), 'batch/source-kind ownership key exists');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_lines'::regclass and conname = 'confirmed_need_lines_exact_owner_key'), 'stable-line exact ownership key exists');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revisions'::regclass and conname = 'confirmed_need_line_revisions_exact_owner_key'), 'revision exact ownership key exists');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.need_generation_release_snapshot_lines'::regclass and conname = 'need_generation_release_snapshot_lines_exact_owner_key'), 'release-snapshot-line exact ownership key exists');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_confirmed_need_owner_key'), 'Theoretical Need exact disposition and quantity ownership key exists');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.theoretical_need_lines'::regclass and conname = 'theoretical_need_lines_confirmed_need_fkey_key'), 'Theoretical Need child-carried ownership key exists');
select ok((select contype = 'u' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname = 'confirmed_need_line_revision_contributions_member_key'), 'revision membership prevents duplicate Theoretical Need members');

select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_batches'::regclass and conname = 'confirmed_need_batches_origin_release_fkey'), 'origin Need Generation release triple is restrictive');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_batches'::regclass and conname = 'confirmed_need_batches_current_release_fkey'), 'current Need Generation release triple is restrictive');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_lines'::regclass and conname = 'confirmed_need_lines_batch_source_fkey'), 'stable line binds exact batch/source kind');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_lines'::regclass and conname = 'confirmed_need_lines_school_customer_fkey'), 'stable line binds School to customer');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_lines'::regclass and conname = 'confirmed_need_lines_location_customer_fkey'), 'stable line binds destination to customer');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revisions'::regclass and conname = 'confirmed_need_line_revisions_line_owner_fkey'), 'revision binds the exact stable-line operational tuple');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revisions'::regclass and conname = 'confirmed_need_line_revisions_release_fkey'), 'revision binds the exact immutable release triple');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname = 'confirmed_need_line_revision_contributions_revision_fkey'), 'membership binds the exact revision-owned tuple');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname = 'confirmed_need_line_revision_contributions_snapshot_line_fkey'), 'membership binds exact release-snapshot membership');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname like 'confirmed_need_line_revision_contributions_theoretical_line_fk%'), 'membership binds all child-carried Theoretical Need facts');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname = 'confirmed_need_line_revision_contributions_school_fkey'), 'membership binds School to customer');
select ok((select confdeltype = 'r' from pg_constraint where conrelid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and conname = 'confirmed_need_line_revision_contributions_location_fkey'), 'membership binds destination to customer');

select is(
  (select array_agg(proname order by proname)::text[] from pg_proc join pg_namespace on pg_namespace.oid = pg_proc.pronamespace where nspname = 'atlas_planning' and proname like 'pa_06e_h0b1b%'),
  array['pa_06e_h0b1b_confirmed_need_current_source_consistency','pa_06e_h0b1b_confirmed_need_guard','pa_06e_h0b1b_confirmed_need_revision_membership_total']::text[],
  'the H0B1b function catalog is exact'
);
select is((select count(*)::integer from pg_proc join pg_namespace on pg_namespace.oid = pg_proc.pronamespace where nspname = 'atlas_planning' and proname like 'pa_06e_h0b1b%' and pg_get_userbyid(proowner) = 'atlas_owner' and not prosecdef and coalesce(proconfig,array[]::text[]) @> array['search_path=""']), 3, 'all three functions are atlas_owner invokers with empty search path');
select is(
  (
    select count(*)::integer
    from pg_proc function
    join pg_namespace namespace on namespace.oid = function.pronamespace
    cross join lateral aclexplode(coalesce(function.proacl, acldefault('f', function.proowner))) privilege
    left join pg_roles role on role.oid = privilege.grantee
    where namespace.nspname = 'atlas_planning'
      and function.proname like 'pa_06e_h0b1b%'
      and privilege.privilege_type = 'EXECUTE'
      and (privilege.grantee = 0 or role.rolname in ('anon','authenticated','service_role','atlas_planning_command_runtime'))
  ),
  0,
  'PUBLIC, API roles, and Planning runtime cannot execute H0B1b guards'
);
select is(
  (select array_agg(tgname order by tgname)::text[] from pg_trigger where not tgisinternal and tgname like 'confirmed_need%h0b1b%' or not tgisinternal and tgname in ('confirmed_need_batches_current_source_consistency','confirmed_need_lines_current_source_consistency','confirmed_need_line_revisions_current_source_consistency','confirmed_need_line_revisions_membership_total','confirmed_need_line_revision_contributions_membership_total')),
  array['confirmed_need_batches_current_source_consistency','confirmed_need_batches_h0b1b_guard','confirmed_need_line_revision_contributions_h0b1b_guard','confirmed_need_line_revision_contributions_membership_total','confirmed_need_line_revisions_current_source_consistency','confirmed_need_line_revisions_h0b1b_guard','confirmed_need_line_revisions_membership_total','confirmed_need_lines_current_source_consistency','confirmed_need_lines_h0b1b_guard']::text[],
  'the nine-trigger catalog is exact'
);
select is((select count(*)::integer from pg_trigger where not tgisinternal and tgname in ('confirmed_need_batches_h0b1b_guard','confirmed_need_lines_h0b1b_guard','confirmed_need_line_revisions_h0b1b_guard','confirmed_need_line_revision_contributions_h0b1b_guard','confirmed_need_batches_current_source_consistency','confirmed_need_lines_current_source_consistency','confirmed_need_line_revisions_current_source_consistency','confirmed_need_line_revisions_membership_total','confirmed_need_line_revision_contributions_membership_total')), 9, 'exactly nine H0B1b triggers exist');
select is((select count(*)::integer from pg_trigger where not tgisinternal and tgname in ('confirmed_need_batches_current_source_consistency','confirmed_need_lines_current_source_consistency','confirmed_need_line_revisions_current_source_consistency','confirmed_need_line_revisions_membership_total','confirmed_need_line_revision_contributions_membership_total') and tgdeferrable and tginitdeferred), 5, 'all five integrity triggers are deferrable and initially deferred');
select is((select count(*)::integer from pg_trigger where not tgisinternal and tgname in ('confirmed_need_batches_h0b1b_guard','confirmed_need_lines_h0b1b_guard','confirmed_need_line_revisions_h0b1b_guard','confirmed_need_line_revision_contributions_h0b1b_guard') and not tgdeferrable), 4, 'all four row guards are ordinary nondeferred triggers');
select is((select count(*)::integer from pg_trigger trigger join pg_class relation on relation.oid = trigger.tgrelid join pg_namespace namespace on namespace.oid = relation.relnamespace where not trigger.tgisinternal and trigger.tgname like '%h0b1b%' and relation.relname not in ('confirmed_need_batches','confirmed_need_lines','confirmed_need_line_revisions','confirmed_need_line_revision_contributions')), 0, 'H0B1b adds zero upstream or downstream triggers');

select is((select count(*)::integer from pg_policy where polrelid in ('atlas_planning.confirmed_need_batches'::regclass,'atlas_planning.confirmed_need_lines'::regclass,'atlas_planning.confirmed_need_line_revisions'::regclass) and polname in ('pa_05d_planning_select','pa_05d_planning_insert')), 6, 'all six named PA-05D Confirmed Need policies are retained');
select is((select count(*)::integer from pg_class relation cross join lateral aclexplode(coalesce(relation.relacl, acldefault('r', relation.relowner))) privilege join pg_roles role on role.oid = privilege.grantee where relation.oid in ('atlas_planning.confirmed_need_batches'::regclass,'atlas_planning.confirmed_need_lines'::regclass,'atlas_planning.confirmed_need_line_revisions'::regclass) and role.rolname = 'atlas_planning_command_runtime' and privilege.privilege_type in ('SELECT','INSERT','UPDATE')), 9, 'the nine existing PA-05D Confirmed Need runtime grants are retained');
select is((select count(*)::integer from pg_class relation cross join lateral aclexplode(coalesce(relation.relacl, acldefault('r', relation.relowner))) privilege join pg_roles role on role.oid = privilege.grantee where relation.oid = 'atlas_planning.confirmed_need_line_revision_contributions'::regclass and role.rolname = 'atlas_planning_command_runtime'), 0, 'Planning runtime has zero contribution privileges');
select is((select count(*)::integer from pg_proc join pg_namespace on pg_namespace.oid = pg_proc.pronamespace where nspname = 'atlas_api'), 19, 'the canonical atlas_api registry advances to exactly nineteen functions');
select is((select count(*)::integer from pg_proc join pg_namespace on pg_namespace.oid = pg_proc.pronamespace where nspname = 'atlas_api' and proname like '%confirmed_need%'), 1, 'H0Cb adds exactly CMD-15 to the Confirmed Need API catalog');
select is((select count(*)::integer from pg_class join pg_namespace on pg_namespace.oid = pg_class.relnamespace where nspname = 'atlas_planning' and relkind = 'r' and relname like 'confirmed_need%' and relname in ('confirmed_need_batches','confirmed_need_lines','confirmed_need_line_revisions','confirmed_need_line_revision_contributions')), 4, 'the generalized aggregate consists of exactly the three retained relations and one new relation');
select is((select regexp_count(pg_get_constraintdef(oid), 'WHOLESALE|NEED_GENERATION') from pg_constraint where conrelid = 'atlas_planning.confirmed_need_batches'::regclass and conname = 'confirmed_need_batches_source_kind_check'), 2, 'the source vocabulary contains only WHOLESALE and NEED_GENERATION');

select * from finish();
rollback;
