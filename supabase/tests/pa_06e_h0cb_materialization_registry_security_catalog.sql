begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(63);

-- Exact two-function and nineteen-executable catalog.
select has_function('atlas_api', 'create_confirmed_needs_from_generation', array['jsonb'], 'CMD-15 exists with the exact jsonb signature');
select has_function('atlas_core', 'pa_06e_h0cb_validate_materialization_request', array['jsonb'], 'the private H0Cb validator exists');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname,p.proname) in (('atlas_core','pa_06e_h0cb_validate_materialization_request'),('atlas_api','create_confirmed_needs_from_generation'))), 2, 'H0Cb adds exactly two functions');
select is((select pg_get_function_result('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure)), 'jsonb', 'CMD-15 returns jsonb');
select is((select pg_get_function_result('atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure)), 'jsonb', 'validator returns jsonb');
select is((select provolatile::text from pg_proc where oid='atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure), 'v', 'CMD-15 is volatile');
select is((select provolatile::text from pg_proc where oid='atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure), 's', 'validator is stable');
select ok((select prosecdef from pg_proc where oid='atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure), 'CMD-15 is SECURITY DEFINER');
select isnt((select prosecdef from pg_proc where oid='atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure), true, 'validator remains a security invoker');
select is((select proconfig from pg_proc where oid='atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure), array['search_path=""']::text[], 'CMD-15 has fixed empty search_path');
select is((select proconfig from pg_proc where oid='atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure), array['search_path=""']::text[], 'validator has fixed empty search_path');
select is((select pg_get_userbyid(proowner) from pg_proc where oid='atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure), 'atlas_planning_materialization_runtime', 'the dedicated runtime owns CMD-15');
select is((select pg_get_userbyid(proowner) from pg_proc where oid='atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure), 'atlas_owner', 'atlas_owner owns the private validator');
select is((select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='atlas_api' and p.proname='create_confirmed_needs_from_generation'), 1, 'CMD-15 has no overload');

-- Capability and dedicated runtime.
select is((select count(*)::integer from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize'), 1, 'the exact capability exists once');
select is((select owning_domain||':'||capability_status from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize'), 'PLANNING:ACTIVE', 'capability is active in Planning');
select ok(exists(select 1 from pg_roles where rolname='atlas_planning_materialization_runtime'), 'dedicated runtime exists');
select isnt((select rolcanlogin from pg_roles where rolname='atlas_planning_materialization_runtime'), true, 'runtime is NOLOGIN');
select isnt((select rolinherit from pg_roles where rolname='atlas_planning_materialization_runtime'), true, 'runtime is NOINHERIT');
select is((select count(*)::integer from pg_proc where pg_get_userbyid(proowner)='atlas_planning_materialization_runtime'), 1, 'runtime owns exactly one function');
select is((select n.nspname||'.'||p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where pg_get_userbyid(p.proowner)='atlas_planning_materialization_runtime'), 'atlas_api.create_confirmed_needs_from_generation', 'runtime owns only CMD-15');
select is((select count(*)::integer from pg_auth_members m join pg_roles r on r.oid=m.member where r.rolname='atlas_planning_materialization_runtime'), 0, 'runtime is not a member of another role');
select is((select count(*)::integer from pg_auth_members m join pg_roles r on r.oid=m.roleid join pg_roles member on member.oid=m.member where r.rolname='atlas_planning_materialization_runtime' and member.rolname='postgres' and m.admin_option and not m.inherit_option and not m.set_option), 1, 'only the standard non-inheriting postgres ownership administration link remains');
select is((select count(*)::integer from information_schema.usage_privileges where grantee='atlas_planning_materialization_runtime' and privilege_type='CREATE'), 0, 'runtime has no schema CREATE');
select is((select count(*)::integer from information_schema.role_usage_grants where grantee='atlas_planning_materialization_runtime' and object_type='SEQUENCE'), 0, 'runtime has no sequence usage');

-- Execute boundary.
select ok(has_function_privilege('authenticated','atlas_api.create_confirmed_needs_from_generation(jsonb)','EXECUTE'), 'authenticated can execute CMD-15');
select isnt(has_function_privilege('anon','atlas_api.create_confirmed_needs_from_generation(jsonb)','EXECUTE'), true, 'anon cannot execute CMD-15');
select isnt(has_function_privilege('service_role','atlas_api.create_confirmed_needs_from_generation(jsonb)','EXECUTE'), true, 'service_role cannot execute CMD-15');
select isnt(has_function_privilege('public','atlas_api.create_confirmed_needs_from_generation(jsonb)','EXECUTE'), true, 'PUBLIC cannot execute CMD-15');
select isnt(has_function_privilege('public','atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)','EXECUTE'), true, 'PUBLIC cannot execute the validator');
select is((select count(*)::integer from (values('anon'),('authenticated'),('service_role')) roles(role_name) where has_function_privilege(role_name,'atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)','EXECUTE')), 0, 'API roles cannot execute the validator');
select ok(has_function_privilege('atlas_planning_materialization_runtime','atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)','EXECUTE'), 'runtime may invoke the validator');
select is((select count(*)::integer from information_schema.role_routine_grants where grantee='atlas_planning_materialization_runtime' and privilege_type='EXECUTE'), 11, 'runtime has exactly the eleven practical function executes');
select is((select count(*)::integer from pg_namespace n where n.nspname in ('atlas_core','atlas_admin','atlas_planning','atlas_audit','atlas_api') and has_schema_privilege('atlas_planning_materialization_runtime',n.oid,'USAGE')), 5, 'runtime has usage on exactly five Atlas schemas');

-- Practical minimum relation privileges.
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and privilege_type='SELECT'), 45, 'runtime selects exactly the approved forty-five relations');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and privilege_type='INSERT'), 7, 'runtime inserts exactly seven receipt/domain/audit relations');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and privilege_type='UPDATE'), 1, 'only the receipt has table-level UPDATE');
select is((select count(*)::integer from information_schema.role_column_grants where grantee='atlas_planning_materialization_runtime' and table_schema='atlas_planning' and table_name='confirmed_need_batches' and privilege_type='UPDATE' and column_name in ('current_need_generation_run_id','current_need_generation_run_version','current_need_generation_release_snapshot_id','version','updated_at')), 5, 'batch UPDATE is limited to current-source/version metadata');
select is((select count(*)::integer from information_schema.role_column_grants where grantee='atlas_planning_materialization_runtime' and table_schema='atlas_planning' and table_name='confirmed_need_line_revisions' and privilege_type='UPDATE' and column_name in ('revision_status','is_current')), 2, 'revision UPDATE is limited to current/status metadata');
select isnt(has_column_privilege('atlas_planning_materialization_runtime','atlas_planning.confirmed_need_batches','batch_status','UPDATE'), true, 'runtime cannot mutate batch lifecycle');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_name like 'purchase_handoff%'), 0, 'runtime has no Purchase Handoff relation privilege');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_schema='atlas_procurement'), 0, 'runtime has no Procurement relation privilege');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_schema='atlas_evidence'), 0, 'runtime has no Evidence relation privilege');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_schema='atlas_dispatch'), 0, 'runtime has no Dispatch relation privilege');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_materialization_runtime' and table_schema in ('public','ops_v2')), 0, 'runtime has no public or legacy relation privilege');
select is((select count(*)::integer from information_schema.role_table_grants where grantee in ('anon','authenticated','service_role') and table_schema in ('atlas_core','atlas_admin','atlas_planning','atlas_audit') and table_name in ('command_receipts','confirmed_need_batches','confirmed_need_lines','confirmed_need_line_revisions','confirmed_need_line_revision_contributions')), 0, 'API roles gain no direct private-table privilege');

-- Verb-specific forced-RLS policy surface.
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) where r.rolname='atlas_planning_materialization_runtime'), 57, 'runtime has exactly fifty-seven verb-specific policies');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) where r.rolname='atlas_planning_materialization_runtime' and p.polcmd='r'), 47, 'runtime has forty-seven SELECT policies');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) where r.rolname='atlas_planning_materialization_runtime' and p.polcmd='a'), 7, 'runtime has seven INSERT policies');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) where r.rolname='atlas_planning_materialization_runtime' and p.polcmd='w'), 3, 'runtime has three UPDATE policies');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) where r.rolname='atlas_planning_materialization_runtime' and p.polcmd='*'), 0, 'runtime has no FOR ALL policy');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) where r.rolname='atlas_planning_materialization_runtime' and p.polrelid='atlas_core.command_receipts'::regclass), 3, 'receipt has exact select/insert/update policies');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) join pg_class c on c.oid=p.polrelid where r.rolname='atlas_planning_materialization_runtime' and c.relname like 'confirmed_need%'), 10, 'Confirmed Need destinations have exact verb policies');
select is((select count(*)::integer from pg_policy p join pg_roles r on r.oid=any(p.polroles) join pg_class c on c.oid=p.polrelid join pg_namespace n on n.oid=c.relnamespace where r.rolname='atlas_planning_materialization_runtime' and n.nspname='atlas_audit'), 4, 'audit destinations have exact select/insert policies');
select is((select count(*)::integer from pg_policy p where p.polname like 'pa_06e_h0cb%' and p.polroles && array[(select oid from pg_roles where rolname='authenticated')]), 0, 'H0Cb adds no API-role table policy');

-- Existing runtime isolation and bounded source contract.
select is((select count(*)::integer from pg_proc where pg_get_userbyid(proowner)='atlas_planning_command_runtime'), 13, 'planning command runtime owns exactly four PA-05D and nine RMVP-03A functions');
select is((select count(*)::integer from information_schema.role_table_grants where grantee='atlas_planning_command_runtime' and table_name in ('need_generation_runs','need_generation_release_snapshots','confirmed_need_line_revision_contributions')), 0, 'PA-05D runtime receives no H0Cb source or membership access');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%set_config(''lock_timeout'', ''5s'', true)%'), 'CMD-15 fixes the five-second lock timeout');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like '%set_config(''statement_timeout'', ''120s'', true)%'), 'CMD-15 fixes the 120-second statement timeout');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) like all(array['%created_confirmed_need_line_count%','%reused_confirmed_need_line_count%','%retired_confirmed_need_line_count%','%created_line_revision_count%','%created_revision_contribution_count%','%current_line_revision_count%','%superseded_line_revision_count%'])), 'CMD-15 contains exactly the seven named bounded count fields');
select ok((select pg_get_functiondef('atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)'::regprocedure) like '%PA-06E-H0C.v1%'), 'validator owns the accepted H0C contract version');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) not like '%LOOP%'), 'CMD-15 has no internal retry loop');
select ok((select pg_get_functiondef('atlas_api.create_confirmed_needs_from_generation(jsonb)'::regprocedure) not like '%confirmed_need_line_ids%'), 'bounded response exposes no generated line-ID array');

select * from finish();
rollback;
