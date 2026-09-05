begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- Exact Atlas schema and relation posture.
select is(
  (
    select array_agg(nspname order by nspname)::text[]
    from pg_namespace
    where nspname like 'atlas\_%' escape '\'
  ),
  array[
    'atlas_admin',
    'atlas_api',
    'atlas_audit',
    'atlas_core',
    'atlas_dispatch',
    'atlas_evidence',
    'atlas_legacy',
    'atlas_planning',
    'atlas_procurement',
    'atlas_reporting'
  ]::text[],
  'CAT-01 exact Atlas schema catalog excludes every deferred schema'
);

select is(
  (
    select jsonb_build_object(
      'ordinary_tables', count(*) filter (where c.relkind = 'r'),
      'views', count(*) filter (where c.relkind in ('v', 'm'))
    )
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
  ),
  jsonb_build_object('ordinary_tables', 107, 'views', 2),
  'CAT-02 exact whole-platform table and view totals include 02B continuity evidence'
);

select is(
  (
    select jsonb_build_object(
      'authoritative_tables', count(*),
      'rls_enabled', count(*) filter (where c.relrowsecurity),
      'rls_forced', count(*) filter (where c.relforcerowsecurity)
    )
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in (
      'atlas_core',
      'atlas_admin',
      'atlas_planning',
      'atlas_procurement',
      'atlas_evidence',
      'atlas_dispatch',
      'atlas_audit',
      'atlas_legacy'
    )
      and c.relkind = 'r'
  ),
  jsonb_build_object(
    'authoritative_tables', 107,
    'rls_enabled', 107,
    'rls_forced', 107
  ),
  'CAT-03 every authoritative Atlas table has RLS enabled and forced'
);

-- Exact role, capability, owner, and policy catalogs.
select is(
  jsonb_build_object(
    'database_roles',
    (
      select to_jsonb(
        array_agg(
          format(
            '%s|login=%s|inherit=%s|super=%s|createrole=%s|createdb=%s|repl=%s|bypassrls=%s',
            rolname,
            rolcanlogin,
            rolinherit,
            rolsuper,
            rolcreaterole,
            rolcreatedb,
            rolreplication,
            rolbypassrls
          )
          order by rolname
        )
      )
      from pg_roles
      where rolname like 'atlas\_%' escape '\'
    ),
    'application_role_rows',
    (select count(*) from atlas_core.roles),
    'runtime_schema_create_grants',
    (
      select count(*)
      from unnest(
        array[
          'atlas_command_runtime',
          'atlas_confirmed_need_review_runtime',
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
          'atlas_master_data_command_runtime',
          'atlas_need_generation_runtime',
          'atlas_planning_command_runtime',
          'atlas_planning_materialization_runtime',
          'atlas_procurement_command_runtime',
          'atlas_read_runtime'
        ]
      ) runtime_role(role_name)
      cross join pg_namespace n
      where n.nspname like 'atlas\_%' escape '\'
        and has_schema_privilege(runtime_role.role_name, n.nspname, 'CREATE')
    )
  ),
  jsonb_build_object(
    'database_roles',
    to_jsonb(
      array[
        'atlas_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_confirmed_need_review_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_dispatch_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_evidence_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_master_data_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_need_generation_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_owner|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_planning_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_planning_materialization_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_procurement_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_read_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f'
      ]::text[]
    ),
    'application_role_rows', 0,
    'runtime_schema_create_grants', 0
  ),
  'CAT-04 exact Atlas role catalogs and runtime posture are retained'
);

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
      'capability_code', 'confirmed_need_approval.approve',
      'capability_name', 'Approve validated Confirmed Need batch',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'confirmed_need_generation.materialize',
      'capability_name', 'Materialize Confirmed Need from Need Generation',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'confirmed_need_quantities.confirm',
      'capability_name', 'Confirm Confirmed Need quantities',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'confirmed_need_quantities.preview',
      'capability_name', 'Preview Confirmed Need quantities',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'confirmed_need_release.release',
      'capability_name', 'Release approved Confirmed Need for purchase handoff',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'confirmed_need_review.read',
      'capability_name', 'Read Confirmed Need review',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'confirmed_need_validation.validate',
      'capability_name', 'Validate complete Confirmed Need batch',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.ingredients.write',
      'capability_name', 'Maintain Ingredients',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.priorities.write',
      'capability_name', 'Replace Ingredient Supplier Priorities',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.read',
      'capability_name', 'Read Master Data',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipe_adjustments.cancel',
      'capability_name', 'Cancel Recipe adjustment rules',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipe_adjustments.read',
      'capability_name', 'Read Recipe adjustment rules and effective BOM',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipe_adjustments.write',
      'capability_name', 'Create and supersede Recipe adjustment rules',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipes.import',
      'capability_name', 'Import Reviewed Recipe Workbooks',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipes.read',
      'capability_name', 'Read Dishes, Recipes and BOM',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipes.release',
      'capability_name', 'Release Recipe Versions for Planning',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipes.validate',
      'capability_name', 'Validate Recipe Versions',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.recipes.write',
      'capability_name', 'Maintain Dishes, Recipe Drafts and BOM',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.schools.write',
      'capability_name', 'Maintain School Portion Defaults',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'master_data.suppliers.write',
      'capability_name', 'Maintain Suppliers',
      'owning_domain', 'ADMIN',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.attendance.write',
      'capability_name', 'Maintain Attendance drafts',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.input_readiness.write',
      'capability_name', 'Evaluate and control Planning Input Readiness',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.inputs.approve',
      'capability_name', 'Approve and reopen Planning inputs',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.inputs.read',
      'capability_name', 'Read Weekly Menu and Attendance inputs',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.need_generation.write',
      'capability_name', 'Create and control Need Generation',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.pantry.write',
      'capability_name', 'Maintain Pantry source drafts',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'planning.weekly_menu.write',
      'capability_name', 'Maintain Weekly Menu drafts',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'procurement.school_catering.read',
      'capability_name', 'Read school-catering Procurement workbench',
      'owning_domain', 'PROCUREMENT',
      'capability_status', 'ACTIVE'
    ),
    jsonb_build_object(
      'capability_code', 'procurement.school_catering.write',
      'capability_name', 'Maintain school-catering supplier allocation',
      'owning_domain', 'PROCUREMENT',
      'capability_status', 'ACTIVE'
    )
  ),
  'CAT-05 exact capability catalog includes the bounded RMVP-07 lifecycle capabilities'
);

select is(
  (
    select array_agg(
      format('%s=%s', n.nspname, pg_get_userbyid(n.nspowner))
      order by n.nspname
    )::text[]
    from pg_namespace n
    where n.nspname like 'atlas\_%' escape '\'
  ),
  array[
    'atlas_admin=atlas_owner',
    'atlas_api=atlas_owner',
    'atlas_audit=atlas_owner',
    'atlas_core=atlas_owner',
    'atlas_dispatch=atlas_owner',
    'atlas_evidence=atlas_owner',
    'atlas_legacy=atlas_owner',
    'atlas_planning=atlas_owner',
    'atlas_procurement=atlas_owner',
    'atlas_reporting=atlas_owner'
  ]::text[],
  'CAT-06 exact Atlas schema ownership remains atlas_owner'
);

select is(
  (
    with policy_catalog as (
      select format(
        '%s|%s|%s|%s|%s|%s|%s|%s',
        n.nspname,
        c.relname,
        p.polname,
        p.polpermissive,
        p.polcmd,
        array(
          select coalesce(
            (select rolname from pg_roles where oid = role_oid),
            'PUBLIC'
          )
          from unnest(p.polroles) role_oid
          order by 1
        )::text,
        coalesce(pg_get_expr(p.polqual, p.polrelid), '<null>'),
        coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '<null>')
      ) as row_text
      from pg_policy p
      join pg_class c on c.oid = p.polrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname like 'atlas\_%' escape '\'
        and not (
          n.nspname = 'atlas_admin'
          and c.relname = 'units'
          and p.polname = 'rmvp_05_unit_lock'
        )
    )
    select jsonb_build_object(
      'count', count(*),
      'md5', md5(string_agg(row_text, E'\n' order by row_text))
    )
    from policy_catalog
  ),
  jsonb_build_object(
    'count', 633,
    'md5', 'ca91300869ea6ba094dd897158607206'
  ),
  'CAT-07 exact RLS catalog includes backend-only 02B continuity and integrity policies'
);

select ok(
  not exists (
    select 1
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and p.polroles && array[
        (select oid from pg_roles where rolname = 'anon'),
        (select oid from pg_roles where rolname = 'authenticated'),
        (select oid from pg_roles where rolname = 'service_role'),
        (select oid from pg_roles where rolname = 'atlas_command_runtime')
      ]
  ),
  'CAT-08 no RLS policy exposes API roles or retired command runtime'
);

-- Exact whole-platform privilege denials.
select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) api_role(role_name)
    cross join unnest(
      array[
        'atlas_core',
        'atlas_admin',
        'atlas_planning',
        'atlas_procurement',
        'atlas_evidence',
        'atlas_dispatch',
        'atlas_audit',
        'atlas_legacy',
        'atlas_reporting'
      ]
    ) private_schema(schema_name)
    where has_schema_privilege(
      api_role.role_name,
      private_schema.schema_name,
      'USAGE'
    )
  ),
  'CAT-09 API roles have no private Atlas schema usage'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) api_role(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in (
      'atlas_core',
      'atlas_admin',
      'atlas_planning',
      'atlas_procurement',
      'atlas_evidence',
      'atlas_dispatch',
      'atlas_audit',
      'atlas_legacy',
      'atlas_reporting'
    )
      and c.relkind in ('r', 'v', 'm')
      and (
        has_table_privilege(api_role.role_name, c.oid, 'SELECT')
        or has_table_privilege(api_role.role_name, c.oid, 'INSERT')
        or has_table_privilege(api_role.role_name, c.oid, 'UPDATE')
        or has_table_privilege(api_role.role_name, c.oid, 'DELETE')
        or has_table_privilege(api_role.role_name, c.oid, 'TRUNCATE')
        or has_table_privilege(api_role.role_name, c.oid, 'REFERENCES')
        or has_table_privilege(api_role.role_name, c.oid, 'TRIGGER')
      )
  )
  and not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) api_role(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in (
      'atlas_core',
      'atlas_admin',
      'atlas_planning',
      'atlas_procurement',
      'atlas_evidence',
      'atlas_dispatch',
      'atlas_audit',
      'atlas_legacy',
      'atlas_reporting'
    )
      and c.relkind = 'S'
      and (
        has_sequence_privilege(api_role.role_name, c.oid, 'USAGE')
        or has_sequence_privilege(api_role.role_name, c.oid, 'SELECT')
        or has_sequence_privilege(api_role.role_name, c.oid, 'UPDATE')
      )
  ),
  'CAT-10 API roles have no private relation or sequence privilege'
);

select ok(
  not exists (
    select 1
    from pg_namespace n
    cross join unnest(array['USAGE', 'CREATE']) privilege(privilege_name)
    where n.nspname like 'atlas\_%' escape '\'
      and has_schema_privilege(
        'atlas_command_runtime',
        n.nspname,
        privilege.privilege_name
      )
  )
  and not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join unnest(
      array[
        'SELECT',
        'INSERT',
        'UPDATE',
        'DELETE',
        'TRUNCATE',
        'REFERENCES',
        'TRIGGER'
      ]
    ) privilege(privilege_name)
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind in ('r', 'v', 'm')
      and has_table_privilege(
        'atlas_command_runtime',
        c.oid,
        privilege.privilege_name
      )
  )
  and not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join unnest(array['USAGE', 'SELECT', 'UPDATE']) privilege(privilege_name)
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'S'
      and has_sequence_privilege(
        'atlas_command_runtime',
        c.oid,
        privilege.privilege_name
      )
  )
  and not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname like 'atlas\_%' escape '\'
      and has_function_privilege('atlas_command_runtime', p.oid, 'EXECUTE')
  ),
  'CAT-11 retired command runtime has no Atlas privilege'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where grantee = 'atlas_read_runtime'
      and table_schema like 'atlas\_%' escape '\'
      and privilege_type <> 'SELECT'
  )
  and not exists (
    select 1
    from pg_namespace n
    where n.nspname like 'atlas\_%' escape '\'
      and has_schema_privilege('atlas_read_runtime', n.nspname, 'CREATE')
  )
  and not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname like 'atlas\_%' escape '\'
      and c.relkind = 'S'
      and (
        has_sequence_privilege('atlas_read_runtime', c.oid, 'USAGE')
        or has_sequence_privilege('atlas_read_runtime', c.oid, 'SELECT')
        or has_sequence_privilege('atlas_read_runtime', c.oid, 'UPDATE')
      )
  ),
  'CAT-12 read runtime remains select-only with no schema creation or sequence privilege'
);

-- Exact API boundary.
select is(
  (
    select array_agg(role_name order by role_name)::text[]
    from unnest(array['anon', 'authenticated', 'service_role']) role_name
    where has_schema_privilege(role_name, 'atlas_api', 'USAGE')
  ),
  array['authenticated']::text[],
  'CAT-13 atlas_api schema usage allowlist is exactly authenticated'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  107,
  'CAT-14 physical atlas_api function count is exactly one hundred seven'
);

select is(
  (
    select array_agg(
      format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
      order by p.proname, pg_get_function_identity_arguments(p.oid)
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)',
    'apply_recipe_import(request jsonb)',
    'apply_supplier_evidence_to_allocation(request jsonb)',
    'approve_attendance(request jsonb)',
    'approve_confirmed_needs(request jsonb)',
    'approve_pantry(request jsonb)',
    'approve_weekly_menu(request jsonb)',
    'cancel_recipe_composition_adjustment(request jsonb)',
    'close_successful_trip(request jsonb)',
    'confirm_dispatch_load(request jsonb)',
    'confirm_need_quantities(request jsonb)',
    'confirm_school_catering_supplier_recommendations(request jsonb)',
    'confirm_successful_delivery(request jsonb)',
    'copy_dish_recipes(request jsonb)',
    'copy_recipe_version(request jsonb)',
    'create_attendance_draft_from_defaults(request jsonb)',
    'create_confirmed_needs_from_generation(request jsonb)',
    'create_dish(request jsonb)',
    'create_dispatch_plan(request jsonb)',
    'create_ingredient(request jsonb)',
    'create_need_generation_run(request jsonb)',
    'create_or_assign_dispatch_trip(request jsonb)',
    'create_recipe_composition_adjustment(request jsonb)',
    'create_recipe_draft(request jsonb)',
    'create_recipe_successor_version(request jsonb)',
    'create_school_catering_purchase_order_drafts(request jsonb)',
    'create_supplier(request jsonb)',
    'evaluate_planning_input_readiness(request jsonb)',
    'execute_need_generation(request jsonb)',
    'get_command_audit_timeline(request jsonb)',
    'get_confirmed_need_review(request jsonb)',
    'get_confirmed_supplier_allocation_workbench(request jsonb)',
    'get_dish_recipe_operator_workbench(request jsonb)',
    'get_dish_recipe_workbench(request jsonb)',
    'get_dispatch_evidence_readiness(request jsonb)',
    'get_generated_purchase_review(request jsonb)',
    'get_ingredient_supplier_master_data(request jsonb)',
    'get_need_generation_workbench(request jsonb)',
    'get_operator_blockers(request jsonb)',
    'get_pantry_source_workbench(request jsonb)',
    'get_planning_input_preflight(request jsonb)',
    'get_planning_input_readiness_workbench(request jsonb)',
    'get_planning_inputs_workbench(request jsonb)',
    'get_planning_source_correction_impact(request jsonb)',
    'get_recipe_adjustment_operator_workbench(request jsonb)',
    'get_recipe_adjustment_workbench(request jsonb)',
    'get_recipe_effective_target_context(request jsonb)',
    'get_school_catering_procurement_workbench(request jsonb)',
    'get_school_catering_purchase_orders(request jsonb)',
    'get_school_master_data(request jsonb)',
    'get_supplier_direct_trace(request jsonb)',
    'invalidate_need_generation_run(request jsonb)',
    'invalidate_planning_input_readiness(request jsonb)',
    'prepare_planning_source_correction(request jsonb)',
    'prepare_school_catering_purchase_orders(request jsonb)',
    'preview_attendance_import(request jsonb)',
    'preview_confirmed_need_confirmation(request jsonb)',
    'preview_pantry_source(request jsonb)',
    'preview_recipe_composition_adjustment(request jsonb)',
    'preview_weekly_menu_import(request jsonb)',
    'record_dispatch_departure(request jsonb)',
    'record_supplier_receiving_evidence(request jsonb)',
    'record_wholesale_source(request jsonb)',
    'release_confirmed_needs(request jsonb)',
    'release_confirmed_needs_for_purchase_handoff(request jsonb)',
    'release_dispatch_requirement(request jsonb)',
    'release_need_generation_run(request jsonb)',
    'release_purchase_handoff(request jsonb)',
    'release_recipe(request jsonb)',
    'release_recipe_version_for_planning(request jsonb)',
    'release_school_catering_purchase_handoff(request jsonb)',
    'release_school_catering_purchase_order(request jsonb)',
    'release_supplier_purchase_order(request jsonb)',
    'release_wholesale_order(request jsonb)',
    'reopen_attendance(request jsonb)',
    'reopen_pantry(request jsonb)',
    'reopen_weekly_menu(request jsonb)',
    'replace_ingredient_supplier_priorities(request jsonb)',
    'replace_recipe_draft_composition(request jsonb)',
    'request_planning_input_need_generation(request jsonb)',
    'resolve_effective_recipe_composition(request jsonb)',
    'resolve_system_effective_recipe_composition(request jsonb)',
    'save_attendance(request jsonb)',
    'save_attendance_draft(request jsonb)',
    'save_confirmed_needs(request jsonb)',
    'save_confirmed_supplier_allocation(request jsonb)',
    'save_pantry(request jsonb)',
    'save_pantry_draft(request jsonb)',
    'save_recipe(request jsonb)',
    'save_school_catering_supplier_allocation(request jsonb)',
    'save_weekly_menu(request jsonb)',
    'save_weekly_menu_draft(request jsonb)',
    'set_dish_lifecycle(request jsonb)',
    'set_ingredient_lifecycle(request jsonb)',
    'set_recipe_lifecycle(request jsonb)',
    'supersede_recipe_composition_adjustment(request jsonb)',
    'update_dish(request jsonb)',
    'update_ingredient(request jsonb)',
    'update_school_portion_defaults(request jsonb)',
    'update_school_portion_defaults_bulk(request jsonb)',
    'update_supplier(request jsonb)',
    'validate_attendance(request jsonb)',
    'validate_confirmed_needs(request jsonb)',
    'validate_need_generation_run(request jsonb)',
    'validate_pantry(request jsonb)',
    'validate_recipe_version(request jsonb)',
    'validate_weekly_menu(request jsonb)'
  ]::text[],
  'CAT-15 ordered atlas_api signature catalog is exactly one hundred seven functions'
);

select is(
  (
    with pa_06a_registry(registry_id, registry_kind, function_name) as (
      values
        ('CMD-01', 'WRITE', 'record_wholesale_source'),
        ('CMD-02', 'WRITE', 'release_wholesale_order'),
        ('CMD-03', 'WRITE', 'release_purchase_handoff'),
        ('CMD-04', 'WRITE', 'release_dispatch_requirement'),
        ('CMD-05', 'WRITE', 'allocate_supplier_direct_fulfilment'),
        ('CMD-06', 'WRITE', 'release_supplier_purchase_order'),
        ('CMD-07', 'WRITE', 'record_supplier_receiving_evidence'),
        ('CMD-08', 'WRITE', 'apply_supplier_evidence_to_allocation'),
        ('CMD-09', 'WRITE', 'create_dispatch_plan'),
        ('CMD-10', 'WRITE', 'create_or_assign_dispatch_trip'),
        ('CMD-11', 'WRITE', 'confirm_dispatch_load'),
        ('CMD-12', 'WRITE', 'record_dispatch_departure'),
        ('CMD-13', 'WRITE', 'confirm_successful_delivery'),
        ('CMD-14', 'WRITE', 'close_successful_trip'),
        ('CMD-15', 'WRITE', 'create_confirmed_needs_from_generation'),
        ('READ-01', 'READ', 'get_supplier_direct_trace'),
        ('READ-02', 'READ', 'get_dispatch_evidence_readiness'),
        ('READ-03', 'READ', 'get_operator_blockers'),
        ('READ-04', 'READ', 'get_command_audit_timeline')
    )
    select jsonb_build_object(
      'writes',
      to_jsonb(
        array_agg(
          format('%s:%s', registry_id, function_name)
          order by registry_id
        ) filter (
          where registry_kind = 'WRITE'
            and to_regprocedure(
              format('atlas_api.%I(jsonb)', function_name)
            ) is not null
        )
      ),
      'reads',
      to_jsonb(
        array_agg(
          format('%s:%s', registry_id, function_name)
          order by registry_id
        ) filter (
          where registry_kind = 'READ'
            and to_regprocedure(
              format('atlas_api.%I(jsonb)', function_name)
            ) is not null
        )
      )
    )
    from pa_06a_registry
  ),
  jsonb_build_object(
    'writes',
    to_jsonb(
      array[
        'CMD-01:record_wholesale_source',
        'CMD-02:release_wholesale_order',
        'CMD-03:release_purchase_handoff',
        'CMD-04:release_dispatch_requirement',
        'CMD-05:allocate_supplier_direct_fulfilment',
        'CMD-06:release_supplier_purchase_order',
        'CMD-07:record_supplier_receiving_evidence',
        'CMD-08:apply_supplier_evidence_to_allocation',
        'CMD-09:create_dispatch_plan',
        'CMD-10:create_or_assign_dispatch_trip',
        'CMD-11:confirm_dispatch_load',
        'CMD-12:record_dispatch_departure',
        'CMD-13:confirm_successful_delivery',
        'CMD-14:close_successful_trip',
        'CMD-15:create_confirmed_needs_from_generation'
      ]::text[]
    ),
    'reads',
    to_jsonb(
      array[
        'READ-01:get_supplier_direct_trace',
        'READ-02:get_dispatch_evidence_readiness',
        'READ-03:get_operator_blockers',
        'READ-04:get_command_audit_timeline'
      ]::text[]
    )
  ),
  'CAT-16 PA-06A registry is exactly fifteen writes and four reads'
);

select is(
  (
    select array_agg(
      format(
        '%s(%s)=%s',
        p.proname,
        pg_get_function_identity_arguments(p.oid),
        r.rolname
      )
      order by p.proname, pg_get_function_identity_arguments(p.oid)
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)=atlas_procurement_command_runtime',
    'apply_recipe_import(request jsonb)=atlas_master_data_command_runtime',
    'apply_supplier_evidence_to_allocation(request jsonb)=atlas_evidence_command_runtime',
    'approve_attendance(request jsonb)=atlas_planning_command_runtime',
    'approve_confirmed_needs(request jsonb)=atlas_confirmed_need_review_runtime',
    'approve_pantry(request jsonb)=atlas_planning_command_runtime',
    'approve_weekly_menu(request jsonb)=atlas_planning_command_runtime',
    'cancel_recipe_composition_adjustment(request jsonb)=atlas_master_data_command_runtime',
    'close_successful_trip(request jsonb)=atlas_dispatch_command_runtime',
    'confirm_dispatch_load(request jsonb)=atlas_dispatch_command_runtime',
    'confirm_need_quantities(request jsonb)=atlas_confirmed_need_review_runtime',
    'confirm_school_catering_supplier_recommendations(request jsonb)=atlas_procurement_command_runtime',
    'confirm_successful_delivery(request jsonb)=atlas_dispatch_command_runtime',
    'copy_dish_recipes(request jsonb)=atlas_master_data_command_runtime',
    'copy_recipe_version(request jsonb)=atlas_master_data_command_runtime',
    'create_attendance_draft_from_defaults(request jsonb)=atlas_planning_command_runtime',
    'create_confirmed_needs_from_generation(request jsonb)=atlas_planning_materialization_runtime',
    'create_dish(request jsonb)=atlas_master_data_command_runtime',
    'create_dispatch_plan(request jsonb)=atlas_dispatch_command_runtime',
    'create_ingredient(request jsonb)=atlas_master_data_command_runtime',
    'create_need_generation_run(request jsonb)=atlas_need_generation_runtime',
    'create_or_assign_dispatch_trip(request jsonb)=atlas_dispatch_command_runtime',
    'create_recipe_composition_adjustment(request jsonb)=atlas_master_data_command_runtime',
    'create_recipe_draft(request jsonb)=atlas_master_data_command_runtime',
    'create_recipe_successor_version(request jsonb)=atlas_master_data_command_runtime',
    'create_school_catering_purchase_order_drafts(request jsonb)=atlas_procurement_command_runtime',
    'create_supplier(request jsonb)=atlas_master_data_command_runtime',
    'evaluate_planning_input_readiness(request jsonb)=atlas_planning_command_runtime',
    'execute_need_generation(request jsonb)=atlas_need_generation_runtime',
    'get_command_audit_timeline(request jsonb)=atlas_read_runtime',
    'get_confirmed_need_review(request jsonb)=atlas_confirmed_need_review_runtime',
    'get_confirmed_supplier_allocation_workbench(request jsonb)=atlas_read_runtime',
    'get_dish_recipe_operator_workbench(request jsonb)=atlas_read_runtime',
    'get_dish_recipe_workbench(request jsonb)=atlas_read_runtime',
    'get_dispatch_evidence_readiness(request jsonb)=atlas_read_runtime',
    'get_generated_purchase_review(request jsonb)=atlas_confirmed_need_review_runtime',
    'get_ingredient_supplier_master_data(request jsonb)=atlas_read_runtime',
    'get_need_generation_workbench(request jsonb)=atlas_need_generation_runtime',
    'get_operator_blockers(request jsonb)=atlas_read_runtime',
    'get_pantry_source_workbench(request jsonb)=atlas_read_runtime',
    'get_planning_input_preflight(request jsonb)=atlas_read_runtime',
    'get_planning_input_readiness_workbench(request jsonb)=atlas_read_runtime',
    'get_planning_inputs_workbench(request jsonb)=atlas_read_runtime',
    'get_planning_source_correction_impact(request jsonb)=atlas_read_runtime',
    'get_recipe_adjustment_operator_workbench(request jsonb)=atlas_read_runtime',
    'get_recipe_adjustment_workbench(request jsonb)=atlas_read_runtime',
    'get_recipe_effective_target_context(request jsonb)=atlas_read_runtime',
    'get_school_catering_procurement_workbench(request jsonb)=atlas_read_runtime',
    'get_school_catering_purchase_orders(request jsonb)=atlas_read_runtime',
    'get_school_master_data(request jsonb)=atlas_read_runtime',
    'get_supplier_direct_trace(request jsonb)=atlas_read_runtime',
    'invalidate_need_generation_run(request jsonb)=atlas_need_generation_runtime',
    'invalidate_planning_input_readiness(request jsonb)=atlas_planning_command_runtime',
    'prepare_planning_source_correction(request jsonb)=atlas_need_generation_runtime',
    'prepare_school_catering_purchase_orders(request jsonb)=atlas_confirmed_need_review_runtime',
    'preview_attendance_import(request jsonb)=atlas_read_runtime',
    'preview_confirmed_need_confirmation(request jsonb)=atlas_confirmed_need_review_runtime',
    'preview_pantry_source(request jsonb)=atlas_read_runtime',
    'preview_recipe_composition_adjustment(request jsonb)=atlas_read_runtime',
    'preview_weekly_menu_import(request jsonb)=atlas_read_runtime',
    'record_dispatch_departure(request jsonb)=atlas_dispatch_command_runtime',
    'record_supplier_receiving_evidence(request jsonb)=atlas_evidence_command_runtime',
    'record_wholesale_source(request jsonb)=atlas_planning_command_runtime',
    'release_confirmed_needs(request jsonb)=atlas_confirmed_need_review_runtime',
    'release_confirmed_needs_for_purchase_handoff(request jsonb)=atlas_confirmed_need_review_runtime',
    'release_dispatch_requirement(request jsonb)=atlas_planning_command_runtime',
    'release_need_generation_run(request jsonb)=atlas_need_generation_runtime',
    'release_purchase_handoff(request jsonb)=atlas_planning_command_runtime',
    'release_recipe(request jsonb)=atlas_master_data_command_runtime',
    'release_recipe_version_for_planning(request jsonb)=atlas_master_data_command_runtime',
    'release_school_catering_purchase_handoff(request jsonb)=atlas_planning_command_runtime',
    'release_school_catering_purchase_order(request jsonb)=atlas_procurement_command_runtime',
    'release_supplier_purchase_order(request jsonb)=atlas_procurement_command_runtime',
    'release_wholesale_order(request jsonb)=atlas_planning_command_runtime',
    'reopen_attendance(request jsonb)=atlas_planning_command_runtime',
    'reopen_pantry(request jsonb)=atlas_planning_command_runtime',
    'reopen_weekly_menu(request jsonb)=atlas_planning_command_runtime',
    'replace_ingredient_supplier_priorities(request jsonb)=atlas_master_data_command_runtime',
    'replace_recipe_draft_composition(request jsonb)=atlas_master_data_command_runtime',
    'request_planning_input_need_generation(request jsonb)=atlas_planning_command_runtime',
    'resolve_effective_recipe_composition(request jsonb)=atlas_read_runtime',
    'resolve_system_effective_recipe_composition(request jsonb)=atlas_read_runtime',
    'save_attendance(request jsonb)=atlas_planning_command_runtime',
    'save_attendance_draft(request jsonb)=atlas_planning_command_runtime',
    'save_confirmed_needs(request jsonb)=atlas_confirmed_need_review_runtime',
    'save_confirmed_supplier_allocation(request jsonb)=atlas_procurement_command_runtime',
    'save_pantry(request jsonb)=atlas_planning_command_runtime',
    'save_pantry_draft(request jsonb)=atlas_planning_command_runtime',
    'save_recipe(request jsonb)=atlas_master_data_command_runtime',
    'save_school_catering_supplier_allocation(request jsonb)=atlas_procurement_command_runtime',
    'save_weekly_menu(request jsonb)=atlas_planning_command_runtime',
    'save_weekly_menu_draft(request jsonb)=atlas_planning_command_runtime',
    'set_dish_lifecycle(request jsonb)=atlas_master_data_command_runtime',
    'set_ingredient_lifecycle(request jsonb)=atlas_master_data_command_runtime',
    'set_recipe_lifecycle(request jsonb)=atlas_master_data_command_runtime',
    'supersede_recipe_composition_adjustment(request jsonb)=atlas_master_data_command_runtime',
    'update_dish(request jsonb)=atlas_master_data_command_runtime',
    'update_ingredient(request jsonb)=atlas_master_data_command_runtime',
    'update_school_portion_defaults(request jsonb)=atlas_master_data_command_runtime',
    'update_school_portion_defaults_bulk(request jsonb)=atlas_master_data_command_runtime',
    'update_supplier(request jsonb)=atlas_master_data_command_runtime',
    'validate_attendance(request jsonb)=atlas_planning_command_runtime',
    'validate_confirmed_needs(request jsonb)=atlas_confirmed_need_review_runtime',
    'validate_need_generation_run(request jsonb)=atlas_need_generation_runtime',
    'validate_pantry(request jsonb)=atlas_planning_command_runtime',
    'validate_recipe_version(request jsonb)=atlas_master_data_command_runtime',
    'validate_weekly_menu(request jsonb)=atlas_planning_command_runtime'
  ]::text[],
  'CAT-17 exact API function owner mapping is retained'
);

select is(
  (
    select array_agg(
      format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
      order by p.proname, pg_get_function_identity_arguments(p.oid)
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)',
    'apply_recipe_import(request jsonb)',
    'apply_supplier_evidence_to_allocation(request jsonb)',
    'approve_attendance(request jsonb)',
    'approve_confirmed_needs(request jsonb)',
    'approve_pantry(request jsonb)',
    'approve_weekly_menu(request jsonb)',
    'cancel_recipe_composition_adjustment(request jsonb)',
    'close_successful_trip(request jsonb)',
    'confirm_dispatch_load(request jsonb)',
    'confirm_need_quantities(request jsonb)',
    'confirm_school_catering_supplier_recommendations(request jsonb)',
    'confirm_successful_delivery(request jsonb)',
    'copy_dish_recipes(request jsonb)',
    'copy_recipe_version(request jsonb)',
    'create_attendance_draft_from_defaults(request jsonb)',
    'create_confirmed_needs_from_generation(request jsonb)',
    'create_dish(request jsonb)',
    'create_dispatch_plan(request jsonb)',
    'create_ingredient(request jsonb)',
    'create_need_generation_run(request jsonb)',
    'create_or_assign_dispatch_trip(request jsonb)',
    'create_recipe_composition_adjustment(request jsonb)',
    'create_recipe_draft(request jsonb)',
    'create_recipe_successor_version(request jsonb)',
    'create_school_catering_purchase_order_drafts(request jsonb)',
    'create_supplier(request jsonb)',
    'evaluate_planning_input_readiness(request jsonb)',
    'execute_need_generation(request jsonb)',
    'get_command_audit_timeline(request jsonb)',
    'get_confirmed_need_review(request jsonb)',
    'get_confirmed_supplier_allocation_workbench(request jsonb)',
    'get_dish_recipe_operator_workbench(request jsonb)',
    'get_dish_recipe_workbench(request jsonb)',
    'get_dispatch_evidence_readiness(request jsonb)',
    'get_generated_purchase_review(request jsonb)',
    'get_ingredient_supplier_master_data(request jsonb)',
    'get_need_generation_workbench(request jsonb)',
    'get_operator_blockers(request jsonb)',
    'get_pantry_source_workbench(request jsonb)',
    'get_planning_input_preflight(request jsonb)',
    'get_planning_input_readiness_workbench(request jsonb)',
    'get_planning_inputs_workbench(request jsonb)',
    'get_planning_source_correction_impact(request jsonb)',
    'get_recipe_adjustment_operator_workbench(request jsonb)',
    'get_recipe_adjustment_workbench(request jsonb)',
    'get_recipe_effective_target_context(request jsonb)',
    'get_school_catering_procurement_workbench(request jsonb)',
    'get_school_catering_purchase_orders(request jsonb)',
    'get_school_master_data(request jsonb)',
    'get_supplier_direct_trace(request jsonb)',
    'invalidate_need_generation_run(request jsonb)',
    'invalidate_planning_input_readiness(request jsonb)',
    'prepare_planning_source_correction(request jsonb)',
    'prepare_school_catering_purchase_orders(request jsonb)',
    'preview_attendance_import(request jsonb)',
    'preview_confirmed_need_confirmation(request jsonb)',
    'preview_pantry_source(request jsonb)',
    'preview_recipe_composition_adjustment(request jsonb)',
    'preview_weekly_menu_import(request jsonb)',
    'record_dispatch_departure(request jsonb)',
    'record_supplier_receiving_evidence(request jsonb)',
    'record_wholesale_source(request jsonb)',
    'release_confirmed_needs(request jsonb)',
    'release_confirmed_needs_for_purchase_handoff(request jsonb)',
    'release_dispatch_requirement(request jsonb)',
    'release_need_generation_run(request jsonb)',
    'release_purchase_handoff(request jsonb)',
    'release_recipe(request jsonb)',
    'release_recipe_version_for_planning(request jsonb)',
    'release_school_catering_purchase_handoff(request jsonb)',
    'release_school_catering_purchase_order(request jsonb)',
    'release_supplier_purchase_order(request jsonb)',
    'release_wholesale_order(request jsonb)',
    'reopen_attendance(request jsonb)',
    'reopen_pantry(request jsonb)',
    'reopen_weekly_menu(request jsonb)',
    'replace_ingredient_supplier_priorities(request jsonb)',
    'replace_recipe_draft_composition(request jsonb)',
    'request_planning_input_need_generation(request jsonb)',
    'resolve_effective_recipe_composition(request jsonb)',
    'resolve_system_effective_recipe_composition(request jsonb)',
    'save_attendance(request jsonb)',
    'save_attendance_draft(request jsonb)',
    'save_confirmed_needs(request jsonb)',
    'save_confirmed_supplier_allocation(request jsonb)',
    'save_pantry(request jsonb)',
    'save_pantry_draft(request jsonb)',
    'save_recipe(request jsonb)',
    'save_school_catering_supplier_allocation(request jsonb)',
    'save_weekly_menu(request jsonb)',
    'save_weekly_menu_draft(request jsonb)',
    'set_dish_lifecycle(request jsonb)',
    'set_ingredient_lifecycle(request jsonb)',
    'set_recipe_lifecycle(request jsonb)',
    'supersede_recipe_composition_adjustment(request jsonb)',
    'update_dish(request jsonb)',
    'update_ingredient(request jsonb)',
    'update_school_portion_defaults(request jsonb)',
    'update_school_portion_defaults_bulk(request jsonb)',
    'update_supplier(request jsonb)',
    'validate_attendance(request jsonb)',
    'validate_confirmed_needs(request jsonb)',
    'validate_need_generation_run(request jsonb)',
    'validate_pantry(request jsonb)',
    'validate_recipe_version(request jsonb)',
    'validate_weekly_menu(request jsonb)'
  ]::text[],
  'CAT-18 authenticated execute allowlist is exactly one hundred seven functions'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  ),
  'CAT-19 anon executes no Atlas API function'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and has_function_privilege('service_role', p.oid, 'EXECUTE')
  ),
  'CAT-20 service_role executes no Atlas API function'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and (p.proname, pg_get_function_identity_arguments(p.oid)) not in (
        values
          ('allocate_supplier_direct_fulfilment', 'request jsonb'),
          ('apply_recipe_import', 'request jsonb'),
          ('apply_supplier_evidence_to_allocation', 'request jsonb'),
          ('approve_attendance', 'request jsonb'),
          ('approve_confirmed_needs', 'request jsonb'),
          ('approve_pantry', 'request jsonb'),
          ('approve_weekly_menu', 'request jsonb'),
          ('cancel_recipe_composition_adjustment', 'request jsonb'),
          ('close_successful_trip', 'request jsonb'),
          ('confirm_dispatch_load', 'request jsonb'),
          ('confirm_need_quantities', 'request jsonb'),
          ('confirm_school_catering_supplier_recommendations', 'request jsonb'),
          ('confirm_successful_delivery', 'request jsonb'),
          ('copy_dish_recipes', 'request jsonb'),
          ('copy_recipe_version', 'request jsonb'),
          ('create_attendance_draft_from_defaults', 'request jsonb'),
          ('create_confirmed_needs_from_generation', 'request jsonb'),
          ('create_dispatch_plan', 'request jsonb'),
          ('create_dish', 'request jsonb'),
          ('create_ingredient', 'request jsonb'),
          ('create_need_generation_run', 'request jsonb'),
          ('create_or_assign_dispatch_trip', 'request jsonb'),
          ('create_recipe_composition_adjustment', 'request jsonb'),
          ('create_recipe_draft', 'request jsonb'),
          ('create_recipe_successor_version', 'request jsonb'),
          ('create_school_catering_purchase_order_drafts', 'request jsonb'),
          ('create_supplier', 'request jsonb'),
          ('evaluate_planning_input_readiness', 'request jsonb'),
          ('execute_need_generation', 'request jsonb'),
          ('get_command_audit_timeline', 'request jsonb'),
          ('get_confirmed_need_review', 'request jsonb'),
          ('get_confirmed_supplier_allocation_workbench', 'request jsonb'),
          ('get_dispatch_evidence_readiness', 'request jsonb'),
          ('get_generated_purchase_review', 'request jsonb'),
          ('get_dish_recipe_operator_workbench', 'request jsonb'),
          ('get_dish_recipe_workbench', 'request jsonb'),
          ('get_ingredient_supplier_master_data', 'request jsonb'),
          ('get_need_generation_workbench', 'request jsonb'),
          ('get_operator_blockers', 'request jsonb'),
          ('get_pantry_source_workbench', 'request jsonb'),
          ('get_planning_input_preflight', 'request jsonb'),
          ('get_planning_input_readiness_workbench', 'request jsonb'),
          ('get_planning_inputs_workbench', 'request jsonb'),
          ('get_planning_source_correction_impact', 'request jsonb'),
          ('get_recipe_adjustment_workbench', 'request jsonb'),
          ('get_recipe_adjustment_operator_workbench', 'request jsonb'),
          ('get_recipe_effective_target_context', 'request jsonb'),
          ('get_school_catering_procurement_workbench', 'request jsonb'),
          ('get_school_catering_purchase_orders', 'request jsonb'),
          ('get_school_master_data', 'request jsonb'),
          ('get_supplier_direct_trace', 'request jsonb'),
          ('invalidate_need_generation_run', 'request jsonb'),
          ('invalidate_planning_input_readiness', 'request jsonb'),
          ('prepare_planning_source_correction', 'request jsonb'),
          ('prepare_school_catering_purchase_orders', 'request jsonb'),
          ('preview_attendance_import', 'request jsonb'),
          ('preview_confirmed_need_confirmation', 'request jsonb'),
          ('preview_pantry_source', 'request jsonb'),
          ('preview_recipe_composition_adjustment', 'request jsonb'),
          ('preview_weekly_menu_import', 'request jsonb'),
          ('record_dispatch_departure', 'request jsonb'),
          ('record_supplier_receiving_evidence', 'request jsonb'),
          ('record_wholesale_source', 'request jsonb'),
          ('release_confirmed_needs', 'request jsonb'),
          ('release_confirmed_needs_for_purchase_handoff', 'request jsonb'),
          ('release_dispatch_requirement', 'request jsonb'),
          ('release_need_generation_run', 'request jsonb'),
          ('release_purchase_handoff', 'request jsonb'),
          ('release_recipe', 'request jsonb'),
          ('release_recipe_version_for_planning', 'request jsonb'),
          ('release_school_catering_purchase_handoff', 'request jsonb'),
          ('release_school_catering_purchase_order', 'request jsonb'),
          ('release_supplier_purchase_order', 'request jsonb'),
          ('release_wholesale_order', 'request jsonb'),
          ('replace_ingredient_supplier_priorities', 'request jsonb'),
          ('replace_recipe_draft_composition', 'request jsonb'),
          ('request_planning_input_need_generation', 'request jsonb'),
          ('reopen_attendance', 'request jsonb'),
          ('reopen_pantry', 'request jsonb'),
          ('reopen_weekly_menu', 'request jsonb'),
          ('resolve_effective_recipe_composition', 'request jsonb'),
          ('resolve_system_effective_recipe_composition', 'request jsonb'),
          ('save_attendance', 'request jsonb'),
          ('save_attendance_draft', 'request jsonb'),
          ('save_confirmed_needs', 'request jsonb'),
          ('save_confirmed_supplier_allocation', 'request jsonb'),
          ('save_pantry', 'request jsonb'),
          ('save_pantry_draft', 'request jsonb'),
          ('save_recipe', 'request jsonb'),
          ('save_school_catering_supplier_allocation', 'request jsonb'),
          ('save_weekly_menu', 'request jsonb'),
          ('save_weekly_menu_draft', 'request jsonb'),
          ('set_dish_lifecycle', 'request jsonb'),
          ('set_ingredient_lifecycle', 'request jsonb'),
          ('set_recipe_lifecycle', 'request jsonb'),
          ('supersede_recipe_composition_adjustment', 'request jsonb'),
          ('update_dish', 'request jsonb'),
          ('update_ingredient', 'request jsonb'),
          ('update_school_portion_defaults', 'request jsonb'),
          ('update_school_portion_defaults_bulk', 'request jsonb'),
          ('update_supplier', 'request jsonb'),
          ('validate_attendance', 'request jsonb'),
          ('validate_confirmed_needs', 'request jsonb'),
          ('validate_need_generation_run', 'request jsonb'),
          ('validate_pantry', 'request jsonb'),
          ('validate_recipe_version', 'request jsonb'),
          ('validate_weekly_menu', 'request jsonb')
      )
  ),
  'CAT-21 no unreviewed atlas_api function or overload exists'
);

-- Bounded digest of the complete current platform catalog.
select is(
  (
    with table_catalog as (
      select format('%s.%s', n.nspname, c.relname) as row_text
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname like 'atlas\_%' escape '\'
        and c.relkind = 'r'
    ),
    view_catalog as (
      select format('%s.%s:%s', n.nspname, c.relname, c.relkind) as row_text
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname like 'atlas\_%' escape '\'
        and c.relkind in ('v', 'm')
    ),
    policy_catalog as (
      select format(
        '%s|%s|%s|%s|%s|%s|%s|%s',
        n.nspname,
        c.relname,
        p.polname,
        p.polpermissive,
        p.polcmd,
        array(
          select coalesce(
            (select rolname from pg_roles where oid = role_oid),
            'PUBLIC'
          )
          from unnest(p.polroles) role_oid
          order by 1
        )::text,
        coalesce(pg_get_expr(p.polqual, p.polrelid), '<null>'),
        coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '<null>')
      ) as row_text
      from pg_policy p
      join pg_class c on c.oid = p.polrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname like 'atlas\_%' escape '\'
        and not (
          n.nspname = 'atlas_admin'
          and c.relname = 'units'
          and p.polname = 'rmvp_05_unit_lock'
        )
    ),
    private_function_catalog as (
      select format(
        '%s|%s(%s)|owner=%s|definer=%s|config=%s',
        n.nspname,
        p.proname,
        pg_get_function_identity_arguments(p.oid),
        pg_get_userbyid(p.proowner),
        p.prosecdef,
        coalesce(p.proconfig::text, '<null>')
      ) as row_text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in (
        'atlas_core',
        'atlas_admin',
        'atlas_planning',
        'atlas_procurement',
        'atlas_evidence',
        'atlas_dispatch',
        'atlas_audit',
        'atlas_legacy',
        'atlas_reporting'
      )
    ),
    trigger_catalog as (
      select format(
        '%s.%s|%s|enabled=%s|deferrable=%s|initially_deferred=%s|function=%s.%s',
        n.nspname,
        c.relname,
        t.tgname,
        t.tgenabled,
        t.tgdeferrable,
        t.tginitdeferred,
        pn.nspname,
        p.proname
      ) as row_text
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
      join pg_proc p on p.oid = t.tgfoid
      join pg_namespace pn on pn.oid = p.pronamespace
      where n.nspname like 'atlas\_%' escape '\'
        and not t.tgisinternal
    ),
    target_roles as (
      select oid, rolname
      from pg_roles
      where rolname in (
        'anon',
        'authenticated',
        'service_role',
        'atlas_command_runtime',
        'atlas_confirmed_need_review_runtime',
        'atlas_dispatch_command_runtime',
        'atlas_evidence_command_runtime',
        'atlas_master_data_command_runtime',
        'atlas_need_generation_runtime',
        'atlas_planning_command_runtime',
        'atlas_planning_materialization_runtime',
        'atlas_procurement_command_runtime',
        'atlas_read_runtime'
      )
    ),
    positive_target_grant_catalog as (
      select format(
        'schema|%s|%s|%s|grantable=%s',
        n.nspname,
        r.rolname,
        a.privilege_type,
        a.is_grantable
      ) as row_text
      from pg_namespace n
      cross join lateral aclexplode(n.nspacl) a
      join target_roles r on r.oid = a.grantee
      where n.nspname like 'atlas\_%' escape '\'

      union all

      select format(
        'relation|%s.%s|%s|%s|grantable=%s',
        n.nspname,
        c.relname,
        r.rolname,
        a.privilege_type,
        a.is_grantable
      )
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      cross join lateral aclexplode(c.relacl) a
      join target_roles r on r.oid = a.grantee
      where n.nspname like 'atlas\_%' escape '\'

      union all

      select format(
        'column|%s.%s.%s|%s|%s|grantable=%s',
        n.nspname,
        c.relname,
        att.attname,
        r.rolname,
        a.privilege_type,
        a.is_grantable
      )
      from pg_attribute att
      join pg_class c on c.oid = att.attrelid
      join pg_namespace n on n.oid = c.relnamespace
      cross join lateral aclexplode(att.attacl) a
      join target_roles r on r.oid = a.grantee
      where n.nspname like 'atlas\_%' escape '\'
        and att.attnum > 0
        and not att.attisdropped
        and not (
          n.nspname = 'atlas_admin'
          and c.relname = 'units'
          and att.attname = 'unit_id'
          and r.rolname = 'atlas_confirmed_need_review_runtime'
          and a.privilege_type = 'UPDATE'
          and not a.is_grantable
        )

      union all

      select format(
        'function|%s.%s(%s)|%s|%s|grantable=%s',
        n.nspname,
        p.proname,
        pg_get_function_identity_arguments(p.oid),
        r.rolname,
        a.privilege_type,
        a.is_grantable
      )
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      cross join lateral aclexplode(p.proacl) a
      join target_roles r on r.oid = a.grantee
      where n.nspname like 'atlas\_%' escape '\'
    )
    select jsonb_build_object(
      'schema_count',
      (
        select count(*)
        from pg_namespace
        where nspname like 'atlas\_%' escape '\'
      ),
      'table_count', (select count(*) from table_catalog),
      'table_catalog_md5',
      (select md5(string_agg(row_text, E'\n' order by row_text)) from table_catalog),
      'view_count', (select count(*) from view_catalog),
      'view_catalog_md5',
      (select md5(string_agg(row_text, E'\n' order by row_text)) from view_catalog),
      'rls_enabled',
      (
        select count(*)
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname in (
          'atlas_core',
          'atlas_admin',
          'atlas_planning',
          'atlas_procurement',
          'atlas_evidence',
        'atlas_dispatch',
        'atlas_audit',
        'atlas_legacy'
        )
          and c.relkind = 'r'
          and c.relrowsecurity
      ),
      'rls_forced',
      (
        select count(*)
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname in (
          'atlas_core',
          'atlas_admin',
          'atlas_planning',
          'atlas_procurement',
          'atlas_evidence',
        'atlas_dispatch',
        'atlas_audit',
        'atlas_legacy'
        )
          and c.relkind = 'r'
          and c.relforcerowsecurity
      ),
      'database_role_count',
      (
        select count(*)
        from pg_roles
        where rolname like 'atlas\_%' escape '\'
      ),
      'application_role_count', (select count(*) from atlas_core.roles),
      'capability_count', (select count(*) from atlas_core.capabilities),
      'policy_count', (select count(*) from policy_catalog),
      'policy_catalog_md5',
      (select md5(string_agg(row_text, E'\n' order by row_text)) from policy_catalog),
      'rmvp_05_unit_lock_policy_count',
      (
        select count(*)
        from pg_policy p
        join pg_class c on c.oid = p.polrelid
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'atlas_admin'
          and c.relname = 'units'
          and p.polname = 'rmvp_05_unit_lock'
          and p.polcmd = 'w'
          and p.polpermissive
          and pg_get_expr(p.polqual, p.polrelid) = 'true'
          and pg_get_expr(p.polwithcheck, p.polrelid) = 'false'
          and cardinality(p.polroles) = 1
          and 'atlas_confirmed_need_review_runtime'::regrole::oid = any(p.polroles)
      ),
      'private_function_count', (select count(*) from private_function_catalog),
      'private_function_catalog_md5',
      (
        select md5(string_agg(row_text, E'\n' order by row_text))
        from private_function_catalog
      ),
      'trigger_count', (select count(*) from trigger_catalog),
      'trigger_catalog_md5',
      (select md5(string_agg(row_text, E'\n' order by row_text)) from trigger_catalog),
      'positive_target_grant_count',
      (select count(*) from positive_target_grant_catalog),
      'positive_target_grant_md5',
      (
        select md5(string_agg(row_text, E'\n' order by row_text))
        from positive_target_grant_catalog
      ),
      'rmvp_05_unit_lock_grant_count',
      (
        select count(*)
        from pg_attribute att
        join pg_class c on c.oid = att.attrelid
        join pg_namespace n on n.oid = c.relnamespace
        cross join lateral aclexplode(att.attacl) a
        join pg_roles r on r.oid = a.grantee
        where n.nspname = 'atlas_admin'
          and c.relname = 'units'
          and att.attname = 'unit_id'
          and r.rolname = 'atlas_confirmed_need_review_runtime'
          and a.privilege_type = 'UPDATE'
          and not a.is_grantable
      ),
      'api_function_count',
      (
        select count(*)
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'atlas_api'
      ),
      'pa_06a_write_count', 15,
      'pa_06a_read_count', 4,
      'authenticated_execute_count',
      (
        select count(*)
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'atlas_api'
          and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      ),
      'anon_execute_count',
      (
        select count(*)
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'atlas_api'
          and has_function_privilege('anon', p.oid, 'EXECUTE')
      ),
      'service_role_execute_count',
      (
        select count(*)
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'atlas_api'
          and has_function_privilege('service_role', p.oid, 'EXECUTE')
      )
    )
  ),
  jsonb_build_object(
    'schema_count', 10,
    'table_count', 107,
    'table_catalog_md5', 'e9af16a392c34332e06301fb7ea8c228',
    'view_count', 2,
    'view_catalog_md5', 'b3f19bc684dec3a9203c4eb578336420',
    'rls_enabled', 107,
    'rls_forced', 107,
    'database_role_count', 11,
    'application_role_count', 0,
    'capability_count', 29,
    'policy_count', 633,
    'policy_catalog_md5', 'ca91300869ea6ba094dd897158607206',
    'rmvp_05_unit_lock_policy_count', 1,
    'private_function_count', 267,
    'private_function_catalog_md5', '12568581dfa451a5a92a9c36f91dd4cf',
    'trigger_count', 103,
    'trigger_catalog_md5', '61df4c910da3cc1f70771084faa2ac10',
    'positive_target_grant_count', 1664,
    'positive_target_grant_md5', '2d52d6ced4a822847429f2ab30200102',
    'rmvp_05_unit_lock_grant_count', 1,
    'api_function_count', 107,
    'pa_06a_write_count', 15,
    'pa_06a_read_count', 4,
    'authenticated_execute_count', 107,
    'anon_execute_count', 0,
    'service_role_execute_count', 0
  ),
  'CAT-22 exact whole-platform security and catalog integrity summary is retained'
);

select * from finish();

rollback;
