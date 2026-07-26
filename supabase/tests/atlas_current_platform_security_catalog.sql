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
  jsonb_build_object('ordinary_tables', 85, 'views', 2),
  'CAT-02 exact whole-platform table and view totals are 85 and 2'
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
      'atlas_audit'
    )
      and c.relkind = 'r'
  ),
  jsonb_build_object(
    'authoritative_tables', 85,
    'rls_enabled', 85,
    'rls_forced', 85
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
          'atlas_dispatch_command_runtime',
          'atlas_evidence_command_runtime',
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
        'atlas_dispatch_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
        'atlas_evidence_command_runtime|login=f|inherit=f|super=f|createrole=f|createdb=f|repl=f|bypassrls=f',
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
      'capability_code', 'confirmed_need_generation.materialize',
      'capability_name', 'Materialize Confirmed Need from Need Generation',
      'owning_domain', 'PLANNING',
      'capability_status', 'ACTIVE'
    )
  ),
  'CAT-05 exact capability catalog contains only active Planning materialization'
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
    )
    select jsonb_build_object(
      'count', count(*),
      'md5', md5(string_agg(row_text, E'\n' order by row_text))
    )
    from policy_catalog
  ),
  jsonb_build_object(
    'count', 305,
    'md5', '5361b5d7d902fe4afbd99ac8268352b8'
  ),
  'CAT-07 exact 305-policy RLS catalog fingerprint is retained'
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
  19,
  'CAT-14 physical atlas_api function count is exactly nineteen'
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
  'CAT-15 ordered atlas_api signature catalog is exactly nineteen functions'
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
    'apply_supplier_evidence_to_allocation(request jsonb)=atlas_evidence_command_runtime',
    'close_successful_trip(request jsonb)=atlas_dispatch_command_runtime',
    'confirm_dispatch_load(request jsonb)=atlas_dispatch_command_runtime',
    'confirm_successful_delivery(request jsonb)=atlas_dispatch_command_runtime',
    'create_confirmed_needs_from_generation(request jsonb)=atlas_planning_materialization_runtime',
    'create_dispatch_plan(request jsonb)=atlas_dispatch_command_runtime',
    'create_or_assign_dispatch_trip(request jsonb)=atlas_dispatch_command_runtime',
    'get_command_audit_timeline(request jsonb)=atlas_read_runtime',
    'get_dispatch_evidence_readiness(request jsonb)=atlas_read_runtime',
    'get_operator_blockers(request jsonb)=atlas_read_runtime',
    'get_supplier_direct_trace(request jsonb)=atlas_read_runtime',
    'record_dispatch_departure(request jsonb)=atlas_dispatch_command_runtime',
    'record_supplier_receiving_evidence(request jsonb)=atlas_evidence_command_runtime',
    'record_wholesale_source(request jsonb)=atlas_planning_command_runtime',
    'release_dispatch_requirement(request jsonb)=atlas_planning_command_runtime',
    'release_purchase_handoff(request jsonb)=atlas_planning_command_runtime',
    'release_supplier_purchase_order(request jsonb)=atlas_procurement_command_runtime',
    'release_wholesale_order(request jsonb)=atlas_planning_command_runtime'
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
  'CAT-18 authenticated execute allowlist is exactly nineteen functions'
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
          ('apply_supplier_evidence_to_allocation', 'request jsonb'),
          ('close_successful_trip', 'request jsonb'),
          ('confirm_dispatch_load', 'request jsonb'),
          ('confirm_successful_delivery', 'request jsonb'),
          ('create_confirmed_needs_from_generation', 'request jsonb'),
          ('create_dispatch_plan', 'request jsonb'),
          ('create_or_assign_dispatch_trip', 'request jsonb'),
          ('get_command_audit_timeline', 'request jsonb'),
          ('get_dispatch_evidence_readiness', 'request jsonb'),
          ('get_operator_blockers', 'request jsonb'),
          ('get_supplier_direct_trace', 'request jsonb'),
          ('record_dispatch_departure', 'request jsonb'),
          ('record_supplier_receiving_evidence', 'request jsonb'),
          ('record_wholesale_source', 'request jsonb'),
          ('release_dispatch_requirement', 'request jsonb'),
          ('release_purchase_handoff', 'request jsonb'),
          ('release_supplier_purchase_order', 'request jsonb'),
          ('release_wholesale_order', 'request jsonb')
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
        'atlas_dispatch_command_runtime',
        'atlas_evidence_command_runtime',
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
          'atlas_audit'
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
          'atlas_audit'
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
    'schema_count', 9,
    'table_count', 85,
    'table_catalog_md5', 'd77e7ae71a8efd10b5f2b28c0c3971e0',
    'view_count', 2,
    'view_catalog_md5', 'b3f19bc684dec3a9203c4eb578336420',
    'rls_enabled', 85,
    'rls_forced', 85,
    'database_role_count', 8,
    'application_role_count', 0,
    'capability_count', 1,
    'policy_count', 305,
    'policy_catalog_md5', '5361b5d7d902fe4afbd99ac8268352b8',
    'private_function_count', 53,
    'private_function_catalog_md5', '58d2b206d2172399ffe6fd14c6954404',
    'trigger_count', 65,
    'trigger_catalog_md5', '63a5ad67bf386acd37275b3bce0a544d',
    'positive_target_grant_count', 604,
    'positive_target_grant_md5', 'ad5dd8c4bfa2f9475ff3727aa7e52ee1',
    'api_function_count', 19,
    'pa_06a_write_count', 15,
    'pa_06a_read_count', 4,
    'authenticated_execute_count', 19,
    'anon_execute_count', 0,
    'service_role_execute_count', 0
  ),
  'CAT-22 exact whole-platform security and catalog integrity summary is retained'
);

select * from finish();

rollback;
