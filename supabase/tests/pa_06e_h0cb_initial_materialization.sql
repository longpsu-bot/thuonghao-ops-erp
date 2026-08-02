begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(80);

-- A compact authoritative-source fixture. Replica mode is limited to source
-- arrangement; CMD-15 and every target invariant execute with triggers active.
set local session_replication_role = replica;

insert into atlas_core.actors (actor_id, actor_type, display_name)
values ('cb100000-0000-0000-0000-000000000001','HUMAN','H0Cb initial planner');
insert into atlas_core.actor_auth_subjects (actor_id, auth_subject_id)
values ('cb100000-0000-0000-0000-000000000001','cb100000-0000-0000-0000-000000000002');
insert into atlas_core.roles (role_id, role_code, role_name)
values ('cb100000-0000-0000-0000-000000000003','h0cb.initial.planner','H0Cb initial planner');
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'cb100000-0000-0000-0000-000000000003', capability_id
from atlas_core.capabilities where capability_code='confirmed_need_generation.materialize';
insert into atlas_core.actor_role_memberships (actor_id, role_id)
values ('cb100000-0000-0000-0000-000000000001','cb100000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes (actor_id, scope_kind)
values ('cb100000-0000-0000-0000-000000000001','GLOBAL');

insert into atlas_admin.customers (customer_id,customer_code,customer_name,customer_type)
values ('cb100000-0000-0000-0000-000000000010','h0cb-initial-customer','H0Cb initial customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id,customer_id,location_code,location_name,address_text)
values ('cb100000-0000-0000-0000-000000000011','cb100000-0000-0000-0000-000000000010','h0cb-initial-location','H0Cb initial location','Local fixture');
insert into atlas_admin.school_types (school_type_id,school_type_code,school_type_name)
values ('cb100000-0000-0000-0000-000000000012','h0cb-initial-type','H0Cb initial type');
insert into atlas_admin.schools (school_id,customer_id,school_code,school_name,school_type_id,default_delivery_location_id)
values ('cb100000-0000-0000-0000-000000000013','cb100000-0000-0000-0000-000000000010','h0cb-initial-school','H0Cb initial school','cb100000-0000-0000-0000-000000000012','cb100000-0000-0000-0000-000000000011');
insert into atlas_admin.units (unit_id,unit_code,unit_name,dimension_code)
values ('cb100000-0000-0000-0000-000000000014','h0cb-initial-kg','H0Cb kilogram','mass');
insert into atlas_admin.ingredients (ingredient_id,ingredient_code,ingredient_name) values
 ('cb100000-0000-0000-0000-000000000015','h0cb-initial-rice','H0Cb rice'),
 ('cb100000-0000-0000-0000-000000000016','h0cb-initial-oil','H0Cb oil');

insert into atlas_planning.need_generation_runs (
  need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,evaluation_version,
  period_start,period_end,attempt_ordinal,input_snapshot_id,run_status,version,
  generated_line_count,blocking_issue_count,warning_count,generated_by_actor_id,generated_at,
  validated_by_actor_id,validated_at,released_by_actor_id,released_at,updated_at
) values (
  'cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000101',
  'cb100000-0000-0000-0000-000000000102',1,date '2026-07-22',date '2026-07-23',1,
  'cb100000-0000-0000-0000-000000000103','RELEASED_FOR_CONFIRMATION',1,3,0,0,
  'cb100000-0000-0000-0000-000000000001',timestamptz '2026-07-22 08:00:00+07',
  'cb100000-0000-0000-0000-000000000001',timestamptz '2026-07-22 08:01:00+07',
  'cb100000-0000-0000-0000-000000000001',timestamptz '2026-07-22 08:02:00+07',
  timestamptz '2026-07-22 08:02:00+07'
);
insert into atlas_planning.need_generation_input_snapshots (
  need_generation_input_snapshot_id,need_generation_run_id,planning_input_set_id,
  planning_input_evaluation_id,evaluation_version,weekly_menu_id,weekly_menu_version,
  weekly_menu_approval_snapshot_id,attendance_batch_id,attendance_version,
  attendance_approval_snapshot_id,need_generation_calculation_contract_id,
  need_generation_calculation_contract_revision_id,calculation_contract_revision_number,captured_at
) values (
  'cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100',
  'cb100000-0000-0000-0000-000000000101','cb100000-0000-0000-0000-000000000102',1,
  'cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000105',
  'cb100000-0000-0000-0000-000000000106',1,'cb100000-0000-0000-0000-000000000107',
  'cb100000-0000-0000-0000-000000000108','cb100000-0000-0000-0000-000000000109',1,
  timestamptz '2026-07-22 08:00:00+07'
);
insert into atlas_planning.need_generation_recipe_selections (
  need_generation_recipe_selection_id,need_generation_input_snapshot_id,need_generation_run_id,
  weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,
  weekly_menu_version,weekly_menu_line_id,school_id,dish_id,recipe_id,recipe_version_id,
  recipe_version_number,selection_scope,selected_at
) values
 ('cb100000-0000-0000-0000-000000000110','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000120','cb100000-0000-0000-0000-000000000105','cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000130','cb100000-0000-0000-0000-000000000013','cb100000-0000-0000-0000-000000000140','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142',1,'GENERAL',timestamptz '2026-07-22 08:00:00+07'),
 ('cb100000-0000-0000-0000-000000000111','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000121','cb100000-0000-0000-0000-000000000105','cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000131','cb100000-0000-0000-0000-000000000013','cb100000-0000-0000-0000-000000000140','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142',1,'GENERAL',timestamptz '2026-07-22 08:00:00+07'),
 ('cb100000-0000-0000-0000-000000000112','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000122','cb100000-0000-0000-0000-000000000105','cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000132','cb100000-0000-0000-0000-000000000013','cb100000-0000-0000-0000-000000000140','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142',1,'GENERAL',timestamptz '2026-07-22 08:00:00+07');
insert into atlas_planning.need_generation_recipe_line_uses (
  need_generation_recipe_line_use_id,need_generation_input_snapshot_id,need_generation_run_id,
  need_generation_recipe_selection_id,recipe_id,recipe_version_id,recipe_line_id,
  recipe_line_revision_id,captured_at
) values
 ('cb100000-0000-0000-0000-000000000150','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000110','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142','cb100000-0000-0000-0000-000000000151','cb100000-0000-0000-0000-000000000152',timestamptz '2026-07-22 08:00:00+07'),
 ('cb100000-0000-0000-0000-000000000153','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000111','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142','cb100000-0000-0000-0000-000000000154','cb100000-0000-0000-0000-000000000155',timestamptz '2026-07-22 08:00:00+07'),
 ('cb100000-0000-0000-0000-000000000156','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000112','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142','cb100000-0000-0000-0000-000000000157','cb100000-0000-0000-0000-000000000158',timestamptz '2026-07-22 08:00:00+07');

insert into atlas_planning.theoretical_need_lines (
  theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,
  need_generation_recipe_selection_id,need_generation_recipe_line_use_id,
  weekly_menu_approval_snapshot_line_id,weekly_menu_approval_snapshot_id,weekly_menu_id,
  weekly_menu_version,weekly_menu_line_id,attendance_approval_snapshot_line_id,
  attendance_approval_snapshot_id,attendance_batch_id,attendance_version,attendance_line_id,
  school_id,service_date,dish_id,recipe_id,recipe_version_id,recipe_line_id,
  recipe_line_revision_id,ingredient_id,unit_id,need_generation_calculation_contract_id,
  need_generation_calculation_contract_revision_id,calculation_contract_revision_number,
  line_disposition,theoretical_quantity,created_at
) values
 ('cb100000-0000-0000-0000-000000000160','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000110','cb100000-0000-0000-0000-000000000150','cb100000-0000-0000-0000-000000000120','cb100000-0000-0000-0000-000000000105','cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000130','cb100000-0000-0000-0000-000000000170','cb100000-0000-0000-0000-000000000107','cb100000-0000-0000-0000-000000000106',1,'cb100000-0000-0000-0000-000000000180','cb100000-0000-0000-0000-000000000013',date '2026-07-22','cb100000-0000-0000-0000-000000000140','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142','cb100000-0000-0000-0000-000000000151','cb100000-0000-0000-0000-000000000152','cb100000-0000-0000-0000-000000000015','cb100000-0000-0000-0000-000000000014','cb100000-0000-0000-0000-000000000108','cb100000-0000-0000-0000-000000000109',1,'ACTIVE',10,timestamptz '2026-07-22 08:00:00+07'),
 ('cb100000-0000-0000-0000-000000000161','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000111','cb100000-0000-0000-0000-000000000153','cb100000-0000-0000-0000-000000000121','cb100000-0000-0000-0000-000000000105','cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000131','cb100000-0000-0000-0000-000000000171','cb100000-0000-0000-0000-000000000107','cb100000-0000-0000-0000-000000000106',1,'cb100000-0000-0000-0000-000000000181','cb100000-0000-0000-0000-000000000013',date '2026-07-22','cb100000-0000-0000-0000-000000000140','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142','cb100000-0000-0000-0000-000000000154','cb100000-0000-0000-0000-000000000155','cb100000-0000-0000-0000-000000000015','cb100000-0000-0000-0000-000000000014','cb100000-0000-0000-0000-000000000108','cb100000-0000-0000-0000-000000000109',1,'ACTIVE',2,timestamptz '2026-07-22 08:00:00+07'),
 ('cb100000-0000-0000-0000-000000000162','cb100000-0000-0000-0000-000000000100','cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000112','cb100000-0000-0000-0000-000000000156','cb100000-0000-0000-0000-000000000122','cb100000-0000-0000-0000-000000000105','cb100000-0000-0000-0000-000000000104',1,'cb100000-0000-0000-0000-000000000132','cb100000-0000-0000-0000-000000000172','cb100000-0000-0000-0000-000000000107','cb100000-0000-0000-0000-000000000106',1,'cb100000-0000-0000-0000-000000000182','cb100000-0000-0000-0000-000000000013',date '2026-07-23','cb100000-0000-0000-0000-000000000140','cb100000-0000-0000-0000-000000000141','cb100000-0000-0000-0000-000000000142','cb100000-0000-0000-0000-000000000157','cb100000-0000-0000-0000-000000000158','cb100000-0000-0000-0000-000000000016','cb100000-0000-0000-0000-000000000014','cb100000-0000-0000-0000-000000000108','cb100000-0000-0000-0000-000000000109',1,'ACTIVE',3,timestamptz '2026-07-22 08:00:00+07');

insert into atlas_planning.need_generation_release_snapshots (
  need_generation_release_snapshot_id,need_generation_run_id,released_run_version,
  need_generation_input_snapshot_id,released_by_actor_id,released_at,generated_line_count,
  active_line_count,removed_line_count,blocking_issue_count,warning_count
) values ('cb100000-0000-0000-0000-000000000190','cb100000-0000-0000-0000-000000000100',1,'cb100000-0000-0000-0000-000000000103','cb100000-0000-0000-0000-000000000001',timestamptz '2026-07-22 08:02:00+07',3,3,0,0,0);
insert into atlas_planning.need_generation_release_snapshot_lines (
  need_generation_release_snapshot_line_id,need_generation_release_snapshot_id,
  need_generation_run_id,released_run_version,theoretical_need_line_id
) values
 ('cb100000-0000-0000-0000-000000000191','cb100000-0000-0000-0000-000000000190','cb100000-0000-0000-0000-000000000100',1,'cb100000-0000-0000-0000-000000000160'),
 ('cb100000-0000-0000-0000-000000000192','cb100000-0000-0000-0000-000000000190','cb100000-0000-0000-0000-000000000100',1,'cb100000-0000-0000-0000-000000000161'),
 ('cb100000-0000-0000-0000-000000000193','cb100000-0000-0000-0000-000000000190','cb100000-0000-0000-0000-000000000100',1,'cb100000-0000-0000-0000-000000000162');

set local session_replication_role = origin;

create temporary table h0cb_initial_results (result_name text primary key, response_payload jsonb not null);
grant select,insert on h0cb_initial_results to authenticated;
create function pg_temp.h0cb_initial_request(p_command uuid,p_key text,p_note text default 'initial')
returns jsonb language sql stable set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'contract_version','PA-06E-H0C.v1','command_id',p_command,
    'correlation_id','cb100000-0000-0000-0000-000000000901'::uuid,
    'idempotency_key',p_key,'expected_version',1,
    'requested_by_auth_subject','cb100000-0000-0000-0000-000000000002'::uuid,
    'requested_at',pg_catalog.transaction_timestamp(),'reason_code','H0CB_INITIAL_TEST',
    'reason_note',p_note,'payload',pg_catalog.jsonb_build_object(
      'need_generation_run_id','cb100000-0000-0000-0000-000000000100'::uuid,
      'need_generation_run_version',1,'confirmed_need_batch_id',null
    )
  )
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','cb100000-0000-0000-0000-000000000002',true);
insert into h0cb_initial_results values ('created',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_initial_request('cb100000-0000-0000-0000-000000000900','h0cb-initial')));
insert into h0cb_initial_results values ('replay',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_initial_request('cb100000-0000-0000-0000-000000000900','h0cb-initial')));
insert into h0cb_initial_results values ('changed',atlas_api.create_confirmed_needs_from_generation(pg_temp.h0cb_initial_request('cb100000-0000-0000-0000-000000000900','h0cb-initial','changed')));
reset role;

-- Successful envelope and bounded response (1-25).
select is((select response_payload->>'success' from h0cb_initial_results where result_name='created'),'true','initial command succeeds');
select is((select response_payload->>'idempotency_status' from h0cb_initial_results where result_name='created'),'COMPLETED','success is completed');
select is((select response_payload->>'command_id' from h0cb_initial_results where result_name='created'),'cb100000-0000-0000-0000-000000000900','response keeps command ID');
select is((select response_payload->>'correlation_id' from h0cb_initial_results where result_name='created'),'cb100000-0000-0000-0000-000000000901','response keeps correlation ID');
select is((select response_payload#>>'{affected_aggregate_ids,need_generation_run_id}' from h0cb_initial_results where result_name='created'),'cb100000-0000-0000-0000-000000000100','response identifies source run');
select ok((select response_payload#>>'{affected_aggregate_ids,confirmed_need_batch_id}' is not null from h0cb_initial_results where result_name='created'),'response identifies created batch');
select is((select response_payload#>>'{new_versions,need_generation_run_version}' from h0cb_initial_results where result_name='created'),'1','response returns source version');
select is((select response_payload#>>'{new_versions,confirmed_need_batch_version}' from h0cb_initial_results where result_name='created'),'1','response returns batch version one');
select is((select response_payload#>>'{result_counts,created_confirmed_need_line_count}' from h0cb_initial_results where result_name='created'),'2','two exact operational groups create two lines');
select is((select response_payload#>>'{result_counts,reused_confirmed_need_line_count}' from h0cb_initial_results where result_name='created'),'0','initial creation reuses no line');
select is((select response_payload#>>'{result_counts,retired_confirmed_need_line_count}' from h0cb_initial_results where result_name='created'),'0','initial creation retires no line');
select is((select response_payload#>>'{result_counts,created_line_revision_count}' from h0cb_initial_results where result_name='created'),'2','two revisions are created');
select is((select response_payload#>>'{result_counts,created_revision_contribution_count}' from h0cb_initial_results where result_name='created'),'3','all three release members are captured');
select is((select response_payload#>>'{result_counts,current_line_revision_count}' from h0cb_initial_results where result_name='created'),'2','two revisions are current');
select is((select response_payload#>>'{result_counts,superseded_line_revision_count}' from h0cb_initial_results where result_name='created'),'0','no initial revision is superseded');
select is((select count(*)::integer from jsonb_object_keys((select response_payload->'affected_aggregate_ids' from h0cb_initial_results where result_name='created'))),2,'aggregate IDs are bounded to two fields');
select is((select count(*)::integer from jsonb_object_keys((select response_payload->'new_versions' from h0cb_initial_results where result_name='created'))),2,'new versions are bounded to two fields');
select is((select count(*)::integer from jsonb_object_keys((select response_payload->'result_counts' from h0cb_initial_results where result_name='created'))),7,'result counts contain exactly seven fields');
select is((select jsonb_typeof(response_payload->'emitted_event_ids') from h0cb_initial_results where result_name='created'),'array','event IDs use shared envelope');
select is((select jsonb_array_length(response_payload->'emitted_event_ids') from h0cb_initial_results where result_name='created'),1,'one event is emitted');
select is((select jsonb_array_length(response_payload->'audit_event_ids') from h0cb_initial_results where result_name='created'),1,'one audit event is emitted');
select is((select response_payload->'warnings' from h0cb_initial_results where result_name='created'),'[]'::jsonb,'success has no warnings');
select is((select response_payload->'blockers' from h0cb_initial_results where result_name='created'),'[]'::jsonb,'success has no blockers');
select isnt((select response_payload ? 'confirmed_need_line_ids' from h0cb_initial_results where result_name='created'),true,'response has no generated line IDs');
select isnt((select response_payload ? 'membership_ids' from h0cb_initial_results where result_name='created'),true,'response has no membership IDs');

-- Authoritative batch, grouping, revisions, and membership (26-61).
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),1,'one Need Generation batch exists');
select is((select batch_status from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),'DRAFT_REVIEW','batch starts in Draft Review');
select is((select version from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),1::bigint,'batch starts at version one');
select is((select period_start from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),date '2026-07-22','batch captures period start');
select is((select period_end from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),date '2026-07-23','batch captures period end');
select is((select origin_need_generation_run_id from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),'cb100000-0000-0000-0000-000000000100'::uuid,'batch captures origin run');
select is((select current_need_generation_run_id from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),'cb100000-0000-0000-0000-000000000100'::uuid,'batch current run equals origin');
select is((select origin_need_generation_release_snapshot_id from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),'cb100000-0000-0000-0000-000000000190'::uuid,'batch captures origin release');
select is((select current_need_generation_release_snapshot_id from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),'cb100000-0000-0000-0000-000000000190'::uuid,'batch current release equals origin');
select is((select created_by_actor_id from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),'cb100000-0000-0000-0000-000000000001'::uuid,'authenticated actor creates batch');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where source_kind='NEED_GENERATION'),2,'grouping creates exactly two stable lines');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where customer_id='cb100000-0000-0000-0000-000000000010'),2,'both lines capture owning customer');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where school_id='cb100000-0000-0000-0000-000000000013'),2,'both lines capture School');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where delivery_location_id='cb100000-0000-0000-0000-000000000011'),2,'both lines capture current default destination');
select is((select count(*)::integer from atlas_planning.confirmed_need_lines where controlled_unit_id='cb100000-0000-0000-0000-000000000014'),2,'source Unit is controlled Unit');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where source_kind='NEED_GENERATION'),2,'exactly two revisions exist');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where revision_number=1),2,'both revisions are revision one');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where revision_status='DRAFT'),2,'both revisions are Draft');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where is_current),2,'both revisions are current');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where predecessor_revision_id is null),2,'initial revisions have no predecessor');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb100000-0000-0000-0000-000000000015'),12::numeric,'same-identity contributions sum exactly to twelve');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb100000-0000-0000-0000-000000000015'),12::numeric,'Draft proposal equals exact theoretical sum');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb100000-0000-0000-0000-000000000016'),3::numeric,'second operational group retains exact quantity');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where ingredient_id='cb100000-0000-0000-0000-000000000016'),3::numeric,'second proposal equals exact theoretical quantity');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions),3,'membership is complete');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where ingredient_id='cb100000-0000-0000-0000-000000000015'),2,'grouped rice revision has two members');
select is((select sum(controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions where ingredient_id='cb100000-0000-0000-0000-000000000015'),12::numeric,'rice membership total equals revision total');
select is((select sum(controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions where ingredient_id='cb100000-0000-0000-0000-000000000016'),3::numeric,'oil membership total equals revision total');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions where source_unit_id=controlled_unit_id),3,'every membership preserves no-conversion Unit');
select is((select count(distinct theoretical_need_line_id)::integer from atlas_planning.confirmed_need_line_revision_contributions),3,'each active source line appears once');
select is((select count(distinct need_generation_release_snapshot_line_id)::integer from atlas_planning.confirmed_need_line_revision_contributions),3,'each active release member appears once');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id) where c.controlled_contribution_quantity>0 and r.theoretical_quantity>0),3,'positive memberships attach to positive revisions');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions r where r.theoretical_quantity=(select sum(c.controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions c where c.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id)),2,'each revision equals its exact membership total');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_quantity=theoretical_quantity),2,'all Draft proposals equal theory without claiming approval');
select is((select count(*)::integer from atlas_planning.confirmed_need_approval_snapshots),0,'materialization creates no approval snapshot');
select is((select count(*)::integer from atlas_planning.purchase_handoff_batches),0,'materialization creates no Purchase Handoff');

-- Receipt, event, audit, replay, and conflict certainty (62-80).
select is((select count(*)::integer from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),1,'one command receipt exists');
select is((select outcome from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),'COMPLETED','receipt is completed');
select is((select expected_version from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),1::bigint,'receipt stores creation sentinel');
select ok((select response_payload is not null from atlas_core.command_receipts where command_name='create_confirmed_needs_from_generation'),'receipt stores exact response');
select is((select count(*)::integer from atlas_audit.domain_events where event_type='ConfirmedNeedsCreated'),1,'one creation domain event exists');
select is((select aggregate_version from atlas_audit.domain_events where event_type='ConfirmedNeedsCreated'),1::bigint,'event records batch version one');
select is((select payload_summary#>>'{result_counts,created_revision_contribution_count}' from atlas_audit.domain_events where event_type='ConfirmedNeedsCreated'),'3','event contains bounded contribution count');
select isnt((select payload_summary ? 'memberships' from atlas_audit.domain_events where event_type='ConfirmedNeedsCreated'),true,'event contains no membership array');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='ConfirmedNeedsCreated'),1,'one creation audit event exists');
select is((select aggregate_version_before from atlas_audit.audit_events where event_type='ConfirmedNeedsCreated'),null::bigint,'creation audit has no prior version');
select is((select aggregate_version_after from atlas_audit.audit_events where event_type='ConfirmedNeedsCreated'),1::bigint,'creation audit records version one');
select is((select after_summary->>'batch_status' from atlas_audit.audit_events where event_type='ConfirmedNeedsCreated'),'DRAFT_REVIEW','audit records Draft Review');
select is((select response_payload from h0cb_initial_results where result_name='replay'),(select response_payload from h0cb_initial_results where result_name='created'),'exact replay returns byte-equivalent payload');
select is((select response_payload->>'error_code' from h0cb_initial_results where result_name='changed'),'IDEMPOTENCY_CONFLICT','changed command reuse conflicts');
select is((select response_payload->>'retryable' from h0cb_initial_results where result_name='changed'),'false','changed reuse is nonretryable');
select is((select count(*)::integer from atlas_planning.confirmed_need_batches where source_kind='NEED_GENERATION'),1,'replay creates no second batch');
select is((select row((select count(*)::integer from atlas_planning.confirmed_need_line_revisions), count(*) filter (where contribution_family='RECIPE_DERIVED')::integer)::text from atlas_planning.theoretical_need_lines where need_generation_run_id='cb100000-0000-0000-0000-000000000100'),'(2,3)','replay creates no second revision set and the historical fixture defaults exactly to Recipe-derived');
select is((select count(*)::integer from atlas_audit.domain_events where event_type='ConfirmedNeedsCreated'),1,'replay emits no duplicate event');
select is((select count(*)::integer from atlas_audit.audit_events where event_type='ConfirmedNeedsCreated'),1,'conflict emits no audit event');

select * from finish();
rollback;
