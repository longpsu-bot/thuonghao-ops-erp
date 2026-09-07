begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(24);

select has_table(
  'atlas_planning', 'pantry_need_school_date_modes',
  'DIN-001 current Pantry owns an explicit School/date composition fact'
);
select has_table(
  'atlas_planning', 'pantry_need_approval_snapshot_school_date_modes',
  'DIN-002 immutable Pantry approval snapshots own School/date composition evidence'
);
select columns_are(
  'atlas_planning', 'pantry_need_school_date_modes',
  array['pantry_need_batch_id','school_id','service_date','direct_need_mode','updated_by_actor_id','updated_at'],
  'DIN-003 current mode stores only the exact authority and update evidence'
);
select columns_are(
  'atlas_planning', 'pantry_need_approval_snapshot_school_date_modes',
  array['pantry_need_approval_snapshot_id','pantry_need_batch_id','school_id','service_date','direct_need_mode'],
  'DIN-004 snapshot mode stores only immutable authority and ownership'
);
select ok(
  (select pg_get_constraintdef(oid) like '%ADDITIVE%COMPLETE%'
   from pg_constraint
   where conrelid='atlas_planning.pantry_need_school_date_modes'::regclass
     and conname='pantry_need_school_date_modes_mode_check'),
  'DIN-005 the mode vocabulary is closed to ADDITIVE and COMPLETE'
);
select ok(
  (select pg_get_constraintdef(oid) like '%pantry_need_batch_id, school_id, service_date%'
   from pg_constraint
   where conrelid='atlas_planning.pantry_need_school_date_modes'::regclass
     and contype='p'),
  'DIN-006 one current fact exists per Pantry batch and School/date'
);
select ok(
  (select pg_get_constraintdef(oid) like '%pantry_need_approval_snapshot_id, school_id, service_date%'
   from pg_constraint
   where conrelid='atlas_planning.pantry_need_approval_snapshot_school_date_modes'::regclass
     and contype='p'),
  'DIN-007 one immutable fact exists per approval snapshot and School/date'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid='atlas_planning.pantry_need_school_date_modes'::regclass),
  'DIN-008 current mode has enabled and forced RLS'
);
select ok(
  (select relrowsecurity and relforcerowsecurity
   from pg_class where oid='atlas_planning.pantry_need_approval_snapshot_school_date_modes'::regclass),
  'DIN-009 snapshot mode has enabled and forced RLS'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema='atlas_planning'
     and table_name in ('pantry_need_school_date_modes','pantry_need_approval_snapshot_school_date_modes')
     and grantee in ('anon','authenticated','service_role')),
  0,
  'DIN-010 browser and service roles have no direct mode-table grants'
);
select has_function(
  'atlas_core', 'direct_need_effective_mode', array['uuid','uuid','date'],
  'DIN-011 one helper resolves immutable mode with legacy compatibility'
);
select has_function(
  'atlas_core', 'direct_need_snapshot_complete_only', array['uuid','date'],
  'DIN-012 one helper proves direct-complete snapshot eligibility'
);
select has_function(
  'atlas_core', 'direct_need_evaluation_ready', array['uuid','date','date'],
  'DIN-013 readiness has one closed full-source-or-direct-complete predicate'
);
select ok(
  pg_get_functiondef(
    'atlas_core.direct_need_effective_mode(uuid,uuid,date)'::regprocedure
  ) like '%''ADDITIVE''%',
  'DIN-014 absent historical mode is interpreted as ADDITIVE'
);
select is(
  (select array_agg(attnotnull order by attnum)::boolean[]
   from pg_attribute
   where attrelid='atlas_planning.need_generation_input_snapshots'::regclass
     and attname in ('weekly_menu_id','weekly_menu_version','weekly_menu_approval_snapshot_id',
       'attendance_batch_id','attendance_version','attendance_approval_snapshot_id')),
  array[false,false,false,false,false,false]::boolean[],
  'DIN-015 Menu and Attendance snapshot bindings are physically nullable'
);
select ok(
  (select pg_get_constraintdef(oid) like all(array[
     '%weekly_menu_id IS NULL%attendance_batch_id IS NULL%',
     '%weekly_menu_id IS NOT NULL%attendance_batch_id IS NOT NULL%'])
   from pg_constraint
   where conrelid='atlas_planning.need_generation_input_snapshots'::regclass
     and conname='need_generation_input_snapshots_source_composition_check'),
  'DIN-016 input snapshots permit only complete catering or complete direct bindings'
);
select ok(
  pg_get_functiondef('atlas_api.save_pantry(jsonb)'::regprocedure) like '%PANTRY-02.v3%school_date_modes%',
  'DIN-017 consequential Pantry Save owns the v3 mode payload'
);
select ok(
  pg_get_functiondef('atlas_api.preview_pantry_source(jsonb)'::regprocedure) like '%PANTRY-02.v3%school_date_modes%',
  'DIN-018 preview accepts mode facts without writing'
);
select ok(
  pg_get_functiondef('atlas_api.get_pantry_source_workbench(jsonb)'::regprocedure) like '%school_date_modes%',
  'DIN-019 the common Pantry workbench returns current mode facts'
);
select ok(
  pg_get_functiondef('atlas_api.create_need_generation_run(jsonb)'::regprocedure) like '%direct_need_evaluation_ready%',
  'DIN-020 generation rechecks the closed direct-complete authority'
);
select ok(
  pg_get_functiondef('atlas_api.create_need_generation_run(jsonb)'::regprocedure) like '%direct_need_effective_mode%COMPLETE%',
  'DIN-021 Recipe generation suppresses exact COMPLETE School/date scopes'
);
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname like 'atlas\_%' escape '\'
     and c.relkind='r'
     and c.relname ~ '(source_registry|workflow_engine|generic_recipient)'),
  0,
  'DIN-022 no generic source, workflow, or recipient relation is introduced'
);
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname like 'atlas\_%' escape '\'
     and c.relkind='r'
     and c.relname ~ '(stock|inventory|reservation|pick|vehicle|driver)'),
  0,
  'DIN-023 Direct Need adds no stock, inventory, picking, vehicle, or driver relation'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='atlas_api' and p.proname like '%wholesale%direct%need%'),
  0,
  'DIN-024 normal direct School Need creates no parallel wholesale API'
);

select * from finish();
rollback;
