begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(31);

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

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values
  (
    'd1500000-0000-0000-0000-000000000010',
    'HUMAN',
    'DIN preview writer'
  ),
  (
    'd1500000-0000-0000-0000-000000000011',
    'HUMAN',
    'DIN preview reader'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values
  (
    'd1500000-0000-0000-0000-000000000012',
    'd1500000-0000-0000-0000-000000000010',
    'd1500000-0000-0000-0000-000000000110'
  ),
  (
    'd1500000-0000-0000-0000-000000000013',
    'd1500000-0000-0000-0000-000000000011',
    'd1500000-0000-0000-0000-000000000111'
  );

insert into atlas_core.roles (
  role_id,
  role_code,
  role_name
) values
  (
    'd1500000-0000-0000-0000-000000000014',
    'din.preview_writer',
    'DIN preview writer'
  ),
  (
    'd1500000-0000-0000-0000-000000000015',
    'din.preview_reader',
    'DIN preview reader'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'd1500000-0000-0000-0000-000000000014',
  capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code in (
  'planning.inputs.read',
  'planning.pantry.write'
);

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'd1500000-0000-0000-0000-000000000015',
  capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code = 'planning.inputs.read';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'd1500000-0000-0000-0000-000000000010',
    'd1500000-0000-0000-0000-000000000014'
  ),
  (
    'd1500000-0000-0000-0000-000000000011',
    'd1500000-0000-0000-0000-000000000015'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('d1500000-0000-0000-0000-000000000010', 'GLOBAL'),
  ('d1500000-0000-0000-0000-000000000011', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name,
  customer_type
) values (
  'd1500000-0000-0000-0000-000000000020',
  'din-preview-school-customer',
  'DIN Preview School Customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values (
  'd1500000-0000-0000-0000-000000000021',
  'd1500000-0000-0000-0000-000000000020',
  'din-preview-kitchen',
  'DIN Preview Kitchen',
  'DIN preview test address'
);

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values (
  'd1500000-0000-0000-0000-000000000022',
  'din-preview-primary',
  'DIN Preview Primary'
);

insert into atlas_admin.schools (
  school_id,
  customer_id,
  school_code,
  school_name,
  school_type_id,
  default_delivery_location_id,
  display_order,
  default_student_portions,
  default_teacher_portions
) values (
  'd1500000-0000-0000-0000-000000000023',
  'd1500000-0000-0000-0000-000000000020',
  'din-preview-school',
  'DIN Preview School',
  'd1500000-0000-0000-0000-000000000022',
  'd1500000-0000-0000-0000-000000000021',
  1,
  100,
  10
);

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code,
  decimal_scale
) values (
  'd1500000-0000-0000-0000-000000000024',
  'din-preview-kg',
  'DIN Preview kilogram',
  'MASS',
  6
);

insert into atlas_admin.ingredients (
  ingredient_id,
  ingredient_code,
  ingredient_name,
  ingredient_group,
  purchase_unit_id,
  ingredient_type,
  shopping_type,
  order_step
) values (
  'd1500000-0000-0000-0000-000000000025',
  'din-preview-rice',
  'DIN Preview Rice',
  'Food',
  'd1500000-0000-0000-0000-000000000024',
  'Food',
  'Planned',
  1
);

insert into atlas_planning.pantry_need_purposes (
  pantry_need_purpose_id,
  purpose_code,
  purpose_name_vi,
  purpose_description,
  note_rule,
  purpose_status,
  display_order
) values (
  'd1500000-0000-4000-8000-000000000026',
  'din_preview_supplement',
  'Bổ sung kiểm thử DIN',
  'Isolated Direct Ingredient Need preview fixture.',
  'REQUIRED',
  'ACTIVE',
  150
);

create temporary table din_preview_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on din_preview_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'd1500000-0000-0000-0000-000000000110',
  true
);

insert into din_preview_results values (
  'initial-preview',
  atlas_api.preview_pantry_source(jsonb_build_object(
    'contract_version', 'PANTRY-02.v3',
    'requested_by_auth_subject',
      'd1500000-0000-0000-0000-000000000110',
    'correlation_id', 'd1500000-0000-0000-0000-000000000120',
    'payload', jsonb_build_object(
      'week_start', '2047-01-07',
      'no_additions_confirmed', false,
      'rows', jsonb_build_array(jsonb_build_object(
        'service_date', '2047-01-07',
        'school_id', 'd1500000-0000-0000-0000-000000000023',
        'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
        'pantry_need_purpose_id',
          'd1500000-0000-4000-8000-000000000026',
        'requested_quantity', '2.500000',
        'note', 'Existing approved additive row',
        'source_request_reference', 'DIN-INITIAL',
        'source_row_reference', 'DIN-1'
      )),
      'school_date_modes', jsonb_build_array(jsonb_build_object(
        'school_id', 'd1500000-0000-0000-0000-000000000023',
        'service_date', '2047-01-07',
        'direct_need_mode', 'ADDITIVE'
      ))
    )
  ))
);

insert into din_preview_results
select
  'initial-save',
  atlas_api.save_pantry(jsonb_build_object(
    'contract_version', 'PANTRY-02.v3',
    'command_id', 'd1500000-0000-0000-0000-000000000121',
    'correlation_id', 'd1500000-0000-0000-0000-000000000122',
    'idempotency_key', 'din-preview-initial-save',
    'expected_version', 1,
    'requested_by_auth_subject',
      'd1500000-0000-0000-0000-000000000110',
    'requested_at', transaction_timestamp(),
    'reason_code', 'DIRECT_NEED_TEST',
    'reason_note', 'Create approved ADDITIVE preview fixture.',
    'payload', jsonb_build_object(
      'week_start', '2047-01-07',
      'no_additions_confirmed', false,
      'source_signature',
        initial.response_payload #>> '{preview,source_signature}',
      'expected_source_signature', null,
      'rows', jsonb_build_array(jsonb_build_object(
        'service_date', '2047-01-07',
        'school_id', 'd1500000-0000-0000-0000-000000000023',
        'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
        'pantry_need_purpose_id',
          'd1500000-0000-4000-8000-000000000026',
        'requested_quantity', '2.500000',
        'note', 'Existing approved additive row',
        'source_request_reference', 'DIN-INITIAL',
        'source_row_reference', 'DIN-1'
      )),
      'school_date_modes', jsonb_build_array(jsonb_build_object(
        'school_id', 'd1500000-0000-0000-0000-000000000023',
        'service_date', '2047-01-07',
        'direct_need_mode', 'ADDITIVE'
      ))
    )
  ))
from din_preview_results initial
where initial.result_name = 'initial-preview';

reset role;

select ok(
  (select response_payload->>'success' = 'true'
   from din_preview_results where result_name = 'initial-save')
  and (select pantry_need_batch_status = 'APPROVED'
       from atlas_planning.pantry_need_batches
       where week_start = '2047-01-07')
  and (select direct_need_mode = 'ADDITIVE'
       from atlas_planning.pantry_need_school_date_modes mode
       join atlas_planning.pantry_need_batches batch
         using (pantry_need_batch_id)
       where batch.week_start = '2047-01-07'
         and mode.school_id =
           'd1500000-0000-0000-0000-000000000023'
         and mode.service_date = '2047-01-07'),
  'DIN-025 fixture creates one approved Pantry week with an ADDITIVE direct row'
);

set local role authenticated;

insert into din_preview_results values (
  'v3-approved-replacement',
  atlas_api.preview_pantry_source(jsonb_build_object(
    'contract_version', 'PANTRY-02.v3',
    'requested_by_auth_subject',
      'd1500000-0000-0000-0000-000000000110',
    'correlation_id', 'd1500000-0000-0000-0000-000000000123',
    'payload', jsonb_build_object(
      'week_start', '2047-01-07',
      'no_additions_confirmed', false,
      'rows', jsonb_build_array(
        jsonb_build_object(
          'service_date', '2047-01-07',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '2.500000',
          'note', 'Existing approved additive row',
          'source_request_reference', 'DIN-INITIAL',
          'source_row_reference', 'DIN-1'
        ),
        jsonb_build_object(
          'service_date', '2047-01-08',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '3.000000',
          'note', 'New complete direct row',
          'source_request_reference', 'DIN-REPLACEMENT',
          'source_row_reference', 'DIN-2'
        )
      ),
      'school_date_modes', jsonb_build_array(
        jsonb_build_object(
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'service_date', '2047-01-07',
          'direct_need_mode', 'ADDITIVE'
        ),
        jsonb_build_object(
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'service_date', '2047-01-08',
          'direct_need_mode', 'COMPLETE'
        )
      )
    )
  ))
);

insert into din_preview_results values (
  'v1-approved-replacement',
  atlas_api.preview_pantry_source(jsonb_build_object(
    'contract_version', 'PANTRY-02.v1',
    'requested_by_auth_subject',
      'd1500000-0000-0000-0000-000000000110',
    'correlation_id', 'd1500000-0000-0000-0000-000000000124',
    'payload', jsonb_build_object(
      'week_start', '2047-01-07',
      'no_additions_confirmed', false,
      'rows', jsonb_build_array(
        jsonb_build_object(
          'service_date', '2047-01-07',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '2.500000',
          'note', 'Existing approved additive row',
          'source_request_reference', 'DIN-INITIAL',
          'source_row_reference', 'DIN-1'
        ),
        jsonb_build_object(
          'service_date', '2047-01-08',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '3.000000',
          'note', 'New complete direct row',
          'source_request_reference', 'DIN-REPLACEMENT',
          'source_row_reference', 'DIN-2'
        )
      )
    )
  ))
);

insert into din_preview_results values (
  'v3-approved-blocked',
  atlas_api.preview_pantry_source(jsonb_build_object(
    'contract_version', 'PANTRY-02.v3',
    'requested_by_auth_subject',
      'd1500000-0000-0000-0000-000000000110',
    'correlation_id', 'd1500000-0000-0000-0000-000000000125',
    'payload', jsonb_build_object(
      'week_start', '2047-01-07',
      'no_additions_confirmed', false,
      'rows', jsonb_build_array(
        jsonb_build_object(
          'service_date', '2047-01-07',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '2.500000',
          'note', 'Existing approved additive row',
          'source_request_reference', 'DIN-INITIAL',
          'source_row_reference', 'DIN-1'
        ),
        jsonb_build_object(
          'service_date', '2047-01-08',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '3.000000',
          'note', null,
          'source_request_reference', 'DIN-BLOCKED',
          'source_row_reference', 'DIN-3'
        )
      ),
      'school_date_modes', jsonb_build_array(
        jsonb_build_object(
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'service_date', '2047-01-07',
          'direct_need_mode', 'ADDITIVE'
        ),
        jsonb_build_object(
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'service_date', '2047-01-08',
          'direct_need_mode', 'COMPLETE'
        )
      )
    )
  ))
);

select set_config(
  'request.jwt.claim.sub',
  'd1500000-0000-0000-0000-000000000111',
  true
);

insert into din_preview_results values (
  'v3-approved-no-write',
  atlas_api.preview_pantry_source(jsonb_build_object(
    'contract_version', 'PANTRY-02.v3',
    'requested_by_auth_subject',
      'd1500000-0000-0000-0000-000000000111',
    'correlation_id', 'd1500000-0000-0000-0000-000000000126',
    'payload', jsonb_build_object(
      'week_start', '2047-01-07',
      'no_additions_confirmed', false,
      'rows', jsonb_build_array(
        jsonb_build_object(
          'service_date', '2047-01-07',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '2.500000',
          'note', 'Existing approved additive row',
          'source_request_reference', 'DIN-INITIAL',
          'source_row_reference', 'DIN-1'
        ),
        jsonb_build_object(
          'service_date', '2047-01-08',
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'ingredient_id', 'd1500000-0000-0000-0000-000000000025',
          'pantry_need_purpose_id',
            'd1500000-0000-4000-8000-000000000026',
          'requested_quantity', '3.000000',
          'note', 'New complete direct row',
          'source_request_reference', 'DIN-REPLACEMENT',
          'source_row_reference', 'DIN-2'
        )
      ),
      'school_date_modes', jsonb_build_array(
        jsonb_build_object(
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'service_date', '2047-01-07',
          'direct_need_mode', 'ADDITIVE'
        ),
        jsonb_build_object(
          'school_id', 'd1500000-0000-0000-0000-000000000023',
          'service_date', '2047-01-08',
          'direct_need_mode', 'COMPLETE'
        )
      )
    )
  ))
);

reset role;

select is(
  (select response_payload->>'success'
   from din_preview_results where result_name = 'v3-approved-replacement'),
  'true',
  'DIN-026 v3 approved replacement preview succeeds'
);

select is(
  (select response_payload#>>'{preview,comparison,status}'
   from din_preview_results where result_name = 'v3-approved-replacement'),
  'REPLACEMENT',
  'DIN-027 v3 approved changed Pantry is classified as REPLACEMENT'
);

select is(
  (select response_payload#>>'{preview,can_save}'
   from din_preview_results where result_name = 'v3-approved-replacement'),
  'true',
  'DIN-028 v3 approved replacement is eligible for the correction-impact gate'
);

select is(
  (select response_payload#>>'{preview,can_save}'
   from din_preview_results where result_name = 'v1-approved-replacement'),
  'false',
  'DIN-029 v1 approved replacement retains compatibility lifecycle denial'
);

select ok(
  (select response_payload#>>'{preview,can_save}' = 'false'
     and jsonb_path_exists(
       response_payload,
       '$.preview.issues.blockers[*] ? (@.code == "MISSING_REQUIRED_NOTE")'
     )
   from din_preview_results where result_name = 'v3-approved-blocked'),
  'DIN-030 v3 approved replacement with a real blocker remains ineligible'
);

select ok(
  (select response_payload->>'success' = 'true'
     and response_payload#>>'{preview,can_save}' = 'false'
   from din_preview_results where result_name = 'v3-approved-no-write'),
  'DIN-031 v3 approved replacement requires planning.pantry.write'
);

select * from finish();
rollback;
