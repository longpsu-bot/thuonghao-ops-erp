begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(57);

set local session_replication_role = replica;

insert into atlas_core.actors (actor_id, actor_type, display_name)
values ('d4600000-0000-0000-0000-000000000001', 'HUMAN', 'Operational proposal planner');
insert into atlas_core.actor_auth_subjects (actor_id, auth_subject_id)
values ('d4600000-0000-0000-0000-000000000001', 'd4600000-0000-0000-0000-000000000002');
insert into atlas_core.roles (role_id, role_code, role_name)
values ('d4600000-0000-0000-0000-000000000003', 'planning.operational.proposal', 'Operational proposal planner');
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'd4600000-0000-0000-0000-000000000003', capability_id
from atlas_core.capabilities
where capability_code in (
  'confirmed_need_generation.materialize',
  'confirmed_need_review.read',
  'confirmed_need_quantities.preview',
  'confirmed_need_quantities.confirm'
);
insert into atlas_core.actor_role_memberships (actor_id, role_id)
values ('d4600000-0000-0000-0000-000000000001', 'd4600000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes (actor_id, scope_kind)
values ('d4600000-0000-0000-0000-000000000001', 'GLOBAL');

insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type)
values ('d4600000-0000-0000-0000-000000000010', 'proposal-customer', 'Proposal customer', 'SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name, address_text
) values (
  'd4600000-0000-0000-0000-000000000011', 'd4600000-0000-0000-0000-000000000010',
  'proposal-location', 'Proposal location', 'Local fixture'
);
insert into atlas_admin.school_types (school_type_id, school_type_code, school_type_name)
values ('d4600000-0000-0000-0000-000000000012', 'proposal-school-type', 'Proposal school type');
insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id, default_delivery_location_id
) values (
  'd4600000-0000-0000-0000-000000000013', 'd4600000-0000-0000-0000-000000000010',
  'proposal-school', 'Proposal school', 'd4600000-0000-0000-0000-000000000012',
  'd4600000-0000-0000-0000-000000000011'
);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code) values
  ('d4600000-0000-0000-0000-000000000014', 'proposal-kg', 'Kilogram', 'mass'),
  ('d4600000-0000-0000-0000-000000000015', 'proposal-count', 'Piece', 'count'),
  ('d4600000-0000-0000-0000-000000000016', 'proposal-missing', 'Missing policy unit', 'count'),
  ('d4600000-0000-0000-0000-000000000017', 'proposal-future', 'Future policy unit', 'count'),
  ('d4600000-0000-0000-0000-000000000018', 'proposal-kg-incompatible', 'Incompatible kilogram fixture', 'mass');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name)
select
  ('d4600000-0000-0000-0000-' || lpad((100 + ordinal)::text, 12, '0'))::uuid,
  'proposal-ingredient-' || ordinal,
  'Proposal ingredient ' || ordinal
from generate_series(1, 15) ordinal;

update atlas_admin.ingredients
set purchase_unit_id = 'd4600000-0000-0000-0000-000000000014',
    order_step = case ingredient_id
      when 'd4600000-0000-0000-0000-000000000104' then 0.25
      when 'd4600000-0000-0000-0000-000000000108' then 0.5
      when 'd4600000-0000-0000-0000-000000000114' then 0.5
      else 0.1
    end
where ingredient_id between
  'd4600000-0000-0000-0000-000000000101'
  and 'd4600000-0000-0000-0000-000000000115';

update atlas_admin.ingredients
set purchase_unit_id = 'd4600000-0000-0000-0000-000000000015',
    order_step = case ingredient_id
      when 'd4600000-0000-0000-0000-000000000106' then 2
      when 'd4600000-0000-0000-0000-000000000107' then 6
    end
where ingredient_id in (
  'd4600000-0000-0000-0000-000000000106',
  'd4600000-0000-0000-0000-000000000107'
);

update atlas_admin.ingredients
set purchase_unit_id = 'd4600000-0000-0000-0000-000000000018',
    order_step = 0.005
where ingredient_id = 'd4600000-0000-0000-0000-000000000115';

update atlas_admin.ingredients
set purchase_unit_id = case ingredient_id
      when 'd4600000-0000-0000-0000-000000000109'
        then 'd4600000-0000-0000-0000-000000000016'::uuid
      when 'd4600000-0000-0000-0000-000000000110'
        then 'd4600000-0000-0000-0000-000000000017'::uuid
    end,
    order_step = 1
where ingredient_id in (
  'd4600000-0000-0000-0000-000000000109',
  'd4600000-0000-0000-0000-000000000110'
);

insert into atlas_planning.planning_quantity_policies (
  planning_quantity_policy_id, unit_id, created_by_actor_id
) values
  ('d4600000-0000-0000-0000-000000000020', 'd4600000-0000-0000-0000-000000000014', 'd4600000-0000-0000-0000-000000000001'),
  ('d4600000-0000-0000-0000-000000000021', 'd4600000-0000-0000-0000-000000000015', 'd4600000-0000-0000-0000-000000000001'),
  ('d4600000-0000-0000-0000-000000000022', 'd4600000-0000-0000-0000-000000000017', 'd4600000-0000-0000-0000-000000000001'),
  ('d4600000-0000-0000-0000-000000000023', 'd4600000-0000-0000-0000-000000000018', 'd4600000-0000-0000-0000-000000000001');
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, planning_step, effective_from, policy_revision_status,
  created_by_actor_id, created_at, approved_by_actor_id, approved_at,
  activated_by_actor_id, activated_at
) values
  ('d4600000-0000-0000-0000-000000000030', 'd4600000-0000-0000-0000-000000000020', 'd4600000-0000-0000-0000-000000000014',
   1, 0.01, '2026-01-01', 'ACTIVE', 'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
   'd4600000-0000-0000-0000-000000000001', transaction_timestamp(), 'd4600000-0000-0000-0000-000000000001', transaction_timestamp()),
  ('d4600000-0000-0000-0000-000000000031', 'd4600000-0000-0000-0000-000000000021', 'd4600000-0000-0000-0000-000000000015',
   1, 1, '2026-01-01', 'ACTIVE', 'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
   'd4600000-0000-0000-0000-000000000001', transaction_timestamp(), 'd4600000-0000-0000-0000-000000000001', transaction_timestamp()),
  ('d4600000-0000-0000-0000-000000000032', 'd4600000-0000-0000-0000-000000000022', 'd4600000-0000-0000-0000-000000000017',
   1, 1, '2027-01-01', 'ACTIVE', 'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
   'd4600000-0000-0000-0000-000000000001', transaction_timestamp(), 'd4600000-0000-0000-0000-000000000001', transaction_timestamp());
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, planning_step, effective_from, policy_revision_status,
  created_by_actor_id, created_at, approved_by_actor_id, approved_at,
  activated_by_actor_id, activated_at
) values (
  'd4600000-0000-0000-0000-000000000034', 'd4600000-0000-0000-0000-000000000023',
  'd4600000-0000-0000-0000-000000000018', 1, 0.01, '2026-01-01', 'ACTIVE',
  'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
  'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
  'd4600000-0000-0000-0000-000000000001', transaction_timestamp()
);

create function pg_temp.proposal_seed_run(
  p_run uuid,
  p_snapshot uuid,
  p_release uuid,
  p_start date,
  p_end date,
  p_lines jsonb,
  p_predecessor_run uuid default null
) returns void
language plpgsql
as $$
declare
  v_input_set uuid := gen_random_uuid();
  v_evaluation uuid := gen_random_uuid();
  v_menu uuid := gen_random_uuid();
  v_menu_snapshot uuid := gen_random_uuid();
  v_attendance uuid := gen_random_uuid();
  v_attendance_snapshot uuid := gen_random_uuid();
  v_contract uuid := gen_random_uuid();
  v_contract_revision uuid := gen_random_uuid();
  v_line jsonb;
  v_selection uuid;
  v_use uuid;
  v_recipe uuid;
  v_recipe_version uuid;
  v_recipe_line uuid;
  v_recipe_line_revision uuid;
begin
  if p_predecessor_run is not null then
    select planning_input_set_id, planning_input_evaluation_id
      into v_input_set, v_evaluation
    from atlas_planning.need_generation_runs
    where need_generation_run_id = p_predecessor_run;
  end if;

  insert into atlas_planning.need_generation_runs (
    need_generation_run_id, planning_input_set_id, planning_input_evaluation_id, evaluation_version,
    period_start, period_end, attempt_ordinal, predecessor_need_generation_run_id,
    input_snapshot_id, run_status, version, generated_line_count, blocking_issue_count,
    warning_count, generated_by_actor_id, generated_at, validated_by_actor_id,
    validated_at, released_by_actor_id, released_at, updated_at
  ) values (
    p_run, v_input_set, v_evaluation, 1, p_start, p_end,
    case when p_predecessor_run is null then 1 else 2 end, p_predecessor_run,
    p_snapshot, 'RELEASED_FOR_CONFIRMATION', 1, jsonb_array_length(p_lines), 0, 0,
    'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
    'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
    'd4600000-0000-0000-0000-000000000001', transaction_timestamp(), transaction_timestamp()
  );

  insert into atlas_planning.need_generation_input_snapshots (
    need_generation_input_snapshot_id, need_generation_run_id, planning_input_set_id,
    planning_input_evaluation_id, evaluation_version, weekly_menu_id, weekly_menu_version,
    weekly_menu_approval_snapshot_id, attendance_batch_id, attendance_version,
    attendance_approval_snapshot_id, need_generation_calculation_contract_id,
    need_generation_calculation_contract_revision_id, calculation_contract_revision_number, captured_at
  ) values (
    p_snapshot, p_run, v_input_set, v_evaluation, 1, v_menu, 1, v_menu_snapshot,
    v_attendance, 1, v_attendance_snapshot, v_contract, v_contract_revision, 1,
    transaction_timestamp()
  );

  insert into atlas_planning.need_generation_release_snapshots (
    need_generation_release_snapshot_id, need_generation_run_id, released_run_version,
    need_generation_input_snapshot_id, released_by_actor_id, released_at,
    generated_line_count, active_line_count, removed_line_count, blocking_issue_count, warning_count
  ) values (
    p_release, p_run, 1, p_snapshot, 'd4600000-0000-0000-0000-000000000001',
    transaction_timestamp(), jsonb_array_length(p_lines), jsonb_array_length(p_lines), 0, 0, 0
  );

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_selection := gen_random_uuid();
    v_use := gen_random_uuid();
    v_recipe := gen_random_uuid();
    v_recipe_version := gen_random_uuid();
    v_recipe_line := gen_random_uuid();
    v_recipe_line_revision := gen_random_uuid();

    insert into atlas_planning.need_generation_recipe_selections (
      need_generation_recipe_selection_id, need_generation_input_snapshot_id, need_generation_run_id,
      weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id,
      weekly_menu_version, weekly_menu_line_id, school_id, dish_id, recipe_id,
      recipe_version_id, recipe_version_number, selection_scope, selected_at
    ) values (
      v_selection, p_snapshot, p_run, gen_random_uuid(), v_menu_snapshot, v_menu, 1,
      gen_random_uuid(), 'd4600000-0000-0000-0000-000000000013', gen_random_uuid(),
      v_recipe, v_recipe_version, 1, 'GENERAL', transaction_timestamp()
    );
    insert into atlas_planning.need_generation_recipe_line_uses (
      need_generation_recipe_line_use_id, need_generation_input_snapshot_id, need_generation_run_id,
      need_generation_recipe_selection_id, recipe_id, recipe_version_id, recipe_line_id,
      recipe_line_revision_id, captured_at
    ) values (
      v_use, p_snapshot, p_run, v_selection, v_recipe, v_recipe_version,
      v_recipe_line, v_recipe_line_revision, transaction_timestamp()
    );
    insert into atlas_planning.theoretical_need_lines (
      theoretical_need_line_id, need_generation_run_id, need_generation_input_snapshot_id,
      need_generation_recipe_selection_id, need_generation_recipe_line_use_id,
      weekly_menu_approval_snapshot_line_id, weekly_menu_approval_snapshot_id, weekly_menu_id,
      weekly_menu_version, weekly_menu_line_id, attendance_approval_snapshot_line_id,
      attendance_approval_snapshot_id, attendance_batch_id, attendance_version,
      attendance_line_id, school_id, service_date, dish_id, recipe_id, recipe_version_id,
      recipe_line_id, recipe_line_revision_id, ingredient_id, unit_id,
      need_generation_calculation_contract_id, need_generation_calculation_contract_revision_id,
      calculation_contract_revision_number, predecessor_need_generation_run_id,
      predecessor_theoretical_need_line_id, line_disposition, theoretical_quantity, created_at
    ) values (
      (v_line->>'theoretical_id')::uuid, p_run, p_snapshot, v_selection, v_use,
      gen_random_uuid(), v_menu_snapshot, v_menu, 1, gen_random_uuid(), gen_random_uuid(),
      v_attendance_snapshot, v_attendance, 1, gen_random_uuid(),
      'd4600000-0000-0000-0000-000000000013', (v_line->>'service_date')::date,
      gen_random_uuid(), v_recipe, v_recipe_version, v_recipe_line, v_recipe_line_revision,
      (v_line->>'ingredient_id')::uuid, (v_line->>'unit_id')::uuid, v_contract,
      v_contract_revision, 1, p_predecessor_run,
      nullif(v_line->>'predecessor_id', '')::uuid, 'ACTIVE',
      (v_line->>'quantity')::numeric, transaction_timestamp()
    );
    insert into atlas_planning.need_generation_release_snapshot_lines (
      need_generation_release_snapshot_line_id, need_generation_release_snapshot_id,
      need_generation_run_id, released_run_version, theoretical_need_line_id
    ) values (gen_random_uuid(), p_release, p_run, 1, (v_line->>'theoretical_id')::uuid);
  end loop;
end
$$;

create function pg_temp.proposal_request(
  p_run uuid,
  p_command uuid,
  p_key text,
  p_batch uuid default null,
  p_expected bigint default 1
) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 'PA-06E-H0C.v1',
    'command_id', p_command,
    'correlation_id', gen_random_uuid(),
    'idempotency_key', p_key,
    'expected_version', p_expected,
    'requested_by_auth_subject', 'd4600000-0000-0000-0000-000000000002'::uuid,
    'requested_at', transaction_timestamp(),
    'reason_code', 'PLANNING_OPERATIONAL_PROPOSAL_TEST',
    'reason_note', 'rolled-back local fixture',
    'payload', jsonb_build_object(
      'need_generation_run_id', p_run,
      'need_generation_run_version', 1,
      'confirmed_need_batch_id', p_batch
    )
  )
$$;

select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000001000', 'd4600000-0000-0000-0000-000000001001',
  'd4600000-0000-0000-0000-000000001002', '2026-09-17', '2026-09-17',
  jsonb_build_array(
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001101','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000101','unit_id','d4600000-0000-0000-0000-000000000014','quantity','0.04'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001102','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000101','unit_id','d4600000-0000-0000-0000-000000000014','quantity','0.04'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001103','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000102','unit_id','d4600000-0000-0000-0000-000000000014','quantity','0.0255'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001104','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000103','unit_id','d4600000-0000-0000-0000-000000000014','quantity','0.105'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001105','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000104','unit_id','d4600000-0000-0000-0000-000000000014','quantity','1.225'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001106','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000105','unit_id','d4600000-0000-0000-0000-000000000014','quantity','228'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001107','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000106','unit_id','d4600000-0000-0000-0000-000000000015','quantity','3.8'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001108','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000107','unit_id','d4600000-0000-0000-0000-000000000015','quantity','13'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001109','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000113','unit_id','d4600000-0000-0000-0000-000000000014','quantity','1.225'),
    jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000001110','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000114','unit_id','d4600000-0000-0000-0000-000000000014','quantity','1.225')
  )
);

set local session_replication_role = origin;

create temporary table proposal_results (result_name text primary key, response jsonb not null);
grant select, insert on proposal_results to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4600000-0000-0000-0000-000000000002', true);
insert into proposal_results values (
  'examples',
  atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request(
    'd4600000-0000-0000-0000-000000001000', 'd4600000-0000-0000-0000-000000001900', 'proposal-examples'
  ))
);
reset role;

select is((select response->>'success' from proposal_results where result_name='examples'), 'true', 'POP-01 materialization succeeds with exact Unit policies');
select is((select response#>>'{result_counts,created_confirmed_need_line_count}' from proposal_results where result_name='examples'), '9', 'POP-02 ten contributions form nine operational identities');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000101'), '(0.080000,0.100000)', 'POP-03 aggregate 0.04 + 0.04 is rounded once by Ingredient step 0.1');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000102'), '(0.025500,0.100000)', 'POP-04 raw 0.0255 kg uses Ingredient step 0.1, not H1A 0.01');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000103'), '(0.105000,0.200000)', 'POP-05 raw 0.105 kg uses Ingredient step 0.1');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000104'), '(1.225000,1.250000)', 'POP-06 raw 1.225 kg uses unconventional Ingredient step 0.25');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000105'), '(228.000000,228.000000)', 'POP-07 representable 228 kg remains 228');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000106'), '(3.800000,4.000000)', 'POP-08 raw count 3.8 proposes 4');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000107'), '(13.000000,18.000000)', 'POP-09 raw count 13 uses Ingredient step 6');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000113'), '(1.225000,1.300000)', 'POP-09A raw 1.225 kg uses normal Ingredient step 0.1');
select is((select row(theoretical_quantity, confirmed_quantity)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000114'), '(1.225000,1.500000)', 'POP-09B raw 1.225 kg uses unconventional Ingredient step 0.5');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions r where r.theoretical_quantity=(select sum(c.controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions c where c.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id)), 9::bigint, 'POP-10 every raw revision total remains its exact membership sum');
select is((select jsonb_agg(theoretical_quantity order by theoretical_need_line_id) from atlas_planning.theoretical_need_lines where need_generation_run_id='d4600000-0000-0000-0000-000000001000'), '[0.040000,0.040000,0.025500,0.105000,1.225000,228.000000,3.800000,13.000000,1.225000,1.225000]'::jsonb, 'POP-11 materialization does not rewrite theoretical source quantities');
select is((select proposal_rounding_step from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000104'), 0.25::numeric, 'POP-11A revision snapshots the exact Ingredient rounding step');
select is((select proposal_rounding_ingredient_version from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000104'), 1::bigint, 'POP-11B revision snapshots the exact Ingredient version');
select is((select count(*) from atlas_planning.theoretical_need_lines where need_generation_run_id='d4600000-0000-0000-0000-000000001000'), 10::bigint, 'POP-12 materialization neither adds nor removes theoretical lines');
select is((select count(*) from atlas_planning.purchase_handoff_batches), 0::bigint, 'POP-13 materialization creates no Purchase Handoff');

create function pg_temp.proposal_read(p_batch uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject', 'd4600000-0000-0000-0000-000000000002'::uuid,
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', p_batch,
      'filters', '{}'::jsonb,
      'line_offset', 0,
      'line_limit', 100
    )
  )
$$;

create function pg_temp.proposal_decision_lines(p_mode text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_agg(jsonb_build_object(
    'confirmed_need_line_id', line.confirmed_need_line_id,
    'expected_current_revision_id', revision.confirmed_need_line_revision_id,
    'expected_current_decision_id', line.current_confirmed_need_line_decision_id,
    'proposed_confirmed_quantity', case
      when p_mode in ('VALID', 'INVALID_KG')
        and line.ingredient_id = 'd4600000-0000-0000-0000-000000000114'
        then case when p_mode = 'VALID' then '1.37' else '1.375' end
      when p_mode in ('VALID_COUNT', 'INVALID_COUNT')
        and line.ingredient_id = 'd4600000-0000-0000-0000-000000000107'
        then case when p_mode = 'VALID_COUNT' then '17' else '17.5' end
      else revision.confirmed_quantity::text
    end,
    'reason_code', case
      when p_mode in ('VALID', 'INVALID_KG')
        and line.ingredient_id = 'd4600000-0000-0000-0000-000000000114'
        then 'OPERATIONAL_QUANTITY_ADJUSTMENT'
      when p_mode in ('VALID_COUNT', 'INVALID_COUNT')
        and line.ingredient_id = 'd4600000-0000-0000-0000-000000000107'
        then 'OPERATIONAL_QUANTITY_ADJUSTMENT'
      else 'PROPOSAL_ACCEPTED'
    end,
    'reason_note', case
      when p_mode in ('VALID', 'INVALID_KG')
        and line.ingredient_id = 'd4600000-0000-0000-0000-000000000114'
        then 'Explicit operator adjustment'
      when p_mode in ('VALID_COUNT', 'INVALID_COUNT')
        and line.ingredient_id = 'd4600000-0000-0000-0000-000000000107'
        then 'Count adjustment fixture'
      else null
    end
  ) order by line.confirmed_need_line_id)
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id = line.confirmed_need_line_id
   and revision.is_current
  where line.confirmed_need_batch_id = (
    select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
    from pg_temp.proposal_results
    where result_name = 'examples'
  )
$$;

create function pg_temp.proposal_preview(p_lines jsonb)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject', 'd4600000-0000-0000-0000-000000000002'::uuid,
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', (
        select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
        from pg_temp.proposal_results where result_name='examples'
      ),
      'expected_batch_version', 1,
      'lines', p_lines
    )
  )
$$;

create function pg_temp.proposal_save(p_lines jsonb)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v2',
    'command_id', 'd4600000-0000-0000-0000-000000001901'::uuid,
    'correlation_id', gen_random_uuid(),
    'idempotency_key', 'proposal-first-save',
    'expected_version', 1,
    'requested_by_auth_subject', 'd4600000-0000-0000-0000-000000000002'::uuid,
    'requested_at', transaction_timestamp(),
    'reason_code', 'CONFIRMED_NEED_SAVED',
    'reason_note', null,
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', (
        select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
        from pg_temp.proposal_results where result_name='examples'
      ),
      'lines', p_lines
    )
  )
$$;

grant execute on function pg_temp.proposal_read(uuid),
  pg_temp.proposal_decision_lines(text), pg_temp.proposal_preview(jsonb),
  pg_temp.proposal_save(jsonb) to authenticated;

set local role authenticated;
insert into proposal_results values (
  'review',
  atlas_api.get_confirmed_need_review(pg_temp.proposal_read((
    select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
    from proposal_results where result_name='examples'
  )))
);
insert into proposal_results values (
  'preview-valid',
  atlas_api.preview_confirmed_need_confirmation(
    pg_temp.proposal_preview(pg_temp.proposal_decision_lines('VALID'))
  )
);
insert into proposal_results values (
  'preview-invalid-kg',
  atlas_api.preview_confirmed_need_confirmation(
    pg_temp.proposal_preview(pg_temp.proposal_decision_lines('INVALID_KG'))
  )
);
insert into proposal_results values (
  'preview-invalid-count',
  atlas_api.preview_confirmed_need_confirmation(
    pg_temp.proposal_preview(pg_temp.proposal_decision_lines('INVALID_COUNT'))
  )
);
insert into proposal_results values (
  'preview-valid-count',
  atlas_api.preview_confirmed_need_confirmation(
    pg_temp.proposal_preview(pg_temp.proposal_decision_lines('VALID_COUNT'))
  )
);
insert into proposal_results values (
  'save',
  atlas_api.save_confirmed_needs(
    pg_temp.proposal_save(pg_temp.proposal_decision_lines('VALID'))
  )
);
insert into proposal_results values (
  'review-after-save',
  atlas_api.get_confirmed_need_review(pg_temp.proposal_read((
    select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
    from proposal_results where result_name='examples'
  )))
);
reset role;

select ok((select response->>'success'='true'
  and response#>>'{workbench,line_counts,total}'='9'
  and exists (
    select 1
    from jsonb_array_elements(response#>'{workbench,lines}') read_line
    where read_line#>>'{ingredient,id}'='d4600000-0000-0000-0000-000000000104'
      and read_line->>'proposal_rounding_step'='0.250000'
  ) from proposal_results where result_name='review'), 'POPD-01 authorized readback exposes all fresh lines and the proposal rounding snapshot');
select is((select response->'preview'->>'success' from proposal_results where result_name='preview-valid'), 'true', 'POPD-02 exact proposal acceptance and one exact human adjustment preview successfully');
select is((select jsonb_object_agg(decision_kind, line_count) from (select preview_line->>'decision_kind' decision_kind, count(*)::integer line_count from proposal_results cross join lateral jsonb_array_elements(response->'preview'->'ordered_preview_lines') preview_line where result_name='preview-valid' group by decision_kind) counts), jsonb_build_object('ADJUSTED_QUANTITY_CONFIRMED',1,'UNCHANGED_PROPOSAL_ACCEPTED',8), 'POPD-03 system proposals remain unchanged acceptance while one real edit is adjusted');
select is((select response->'preview'->>'error_code' from proposal_results where result_name='preview-invalid-kg'), 'QUANTITY_NOT_REPRESENTABLE', 'POPD-04 human 1.375 at H1A kg step 0.01 fails closed despite Ingredient proposal step 0.5');
select ok((select response->'preview'->>'preview_hash' is null and response->'preview'->'blockers'->0 ? 'replacement_quantity' is false from proposal_results where result_name='preview-invalid-kg'), 'POPD-05 invalid human input returns no hash or replacement quantity');
select is((select response->'preview'->>'error_code' from proposal_results where result_name='preview-invalid-count'), 'QUANTITY_NOT_REPRESENTABLE', 'POPD-06 human 17.5 at H1A count step 1 fails closed despite Ingredient proposal step 6');
select is((select row(preview_line->>'confirmed_quantity_after',preview_line->>'planning_step',preview_line->>'planning_tick_count',preview_line->>'decision_kind')::text from proposal_results r cross join lateral jsonb_array_elements(r.response->'preview'->'ordered_preview_lines') preview_line where r.result_name='preview-valid-count' and (preview_line->>'confirmed_need_line_id')::uuid=(select confirmed_need_line_id from atlas_planning.confirmed_need_lines where ingredient_id='d4600000-0000-0000-0000-000000000107' and confirmed_need_batch_id=(select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from proposal_results where result_name='examples'))), '(17.000000,1.000000,17,ADJUSTED_QUANTITY_CONFIRMED)', 'POPD-06A human count 17 is valid under H1A 1 even when the Ingredient proposal step is 6');
select is((select row(preview_line->>'confirmed_quantity_after',preview_line->>'planning_step',preview_line->>'planning_tick_count',preview_line->>'decision_kind')::text from proposal_results r cross join lateral jsonb_array_elements(r.response->'preview'->'ordered_preview_lines') preview_line where r.result_name='preview-valid' and (preview_line->>'confirmed_need_line_id')::uuid=(select confirmed_need_line_id from atlas_planning.confirmed_need_lines where ingredient_id='d4600000-0000-0000-0000-000000000104' and confirmed_need_batch_id=(select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from proposal_results where result_name='examples'))), '(1.250000,0.010000,125,UNCHANGED_PROPOSAL_ACCEPTED)', 'POPD-07 an Ingredient-rounded proposal remains exactly representable by H1A');
select ok((select response->>'success'='true' and response#>>'{authoritative_readback,authoritative_batch_status}'='DRAFT_REVIEW' from proposal_results where result_name='save'), 'POPD-08 first Save succeeds and remains in Draft review');
select is((select jsonb_object_agg(decision_kind, line_count) from (select decision_kind, count(*)::integer line_count from atlas_planning.confirmed_need_line_decisions where confirmed_need_batch_id=(select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from proposal_results where result_name='examples') group by decision_kind) counts), jsonb_build_object('ADJUSTED_QUANTITY_CONFIRMED',1,'UNCHANGED_PROPOSAL_ACCEPTED',8), 'POPD-09 first Save creates eight accepted proposals and one explicit adjustment');
select is((select jsonb_object_agg(reason_code, line_count) from (select reason_code, count(*)::integer line_count from atlas_planning.confirmed_need_line_decisions where confirmed_need_batch_id=(select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from proposal_results where result_name='examples') group by reason_code) counts), jsonb_build_object('OPERATIONAL_QUANTITY_ADJUSTMENT',1,'PROPOSAL_ACCEPTED',8), 'POPD-10 system quantization never creates a human Planning-step adjustment');
select is((select count(*) from atlas_planning.confirmed_need_line_decisions where confirmed_need_batch_id=(select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from proposal_results where result_name='examples') and decision_number=1 and predecessor_decision_id is null), 9::bigint, 'POPD-11 every fresh line receives exactly one first decision');
select is((select row(theoretical_quantity,confirmed_quantity,proposal_rounding_step,proposal_rounding_ingredient_version)::text from atlas_planning.confirmed_need_line_revisions where ingredient_id='d4600000-0000-0000-0000-000000000114' and revision_number=2 and is_current), '(1.225000,1.370000,0.500000,1)', 'POPD-12 v2 Save carries the exact proposal snapshot into the adjusted successor revision');
select is((select row(read_line->>'theoretical_quantity',read_line->>'proposed_confirmed_quantity',read_line->>'confirmed_quantity_after',read_line->>'proposal_rounding_step')::text from proposal_results r cross join lateral jsonb_array_elements(r.response#>'{workbench,lines}') read_line where r.result_name='review-after-save' and read_line#>>'{ingredient,id}'='d4600000-0000-0000-0000-000000000114'), '(1.225000,1.500000,1.370000,0.500000)', 'POPD-12A v2 post-Save readback keeps the system proposal distinct from the human decision');
select is((select count(*) from atlas_planning.purchase_handoff_batches), 0::bigint, 'POPD-13 first Save creates no Purchase Handoff');

set local session_replication_role = replica;
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000002000', 'd4600000-0000-0000-0000-000000002001',
  'd4600000-0000-0000-0000-000000002002', '2026-09-17', '2026-09-17',
  jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000002101','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000108','unit_id','d4600000-0000-0000-0000-000000000014','quantity','0.0255'))
);
set local session_replication_role = origin;
set local role authenticated;
insert into proposal_results values (
  'correction-initial',
  atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request(
    'd4600000-0000-0000-0000-000000002000', 'd4600000-0000-0000-0000-000000002900', 'proposal-correction-initial'
  ))
);
reset role;
select is((select response->>'success' from proposal_results where result_name='correction-initial'), 'true', 'POP-14 correction fixture initial materialization succeeds');
create temporary table proposal_old_revision as
select confirmed_need_line_revision_id, md5(jsonb_build_object(
  'theoretical_quantity', r.theoretical_quantity,
  'confirmed_quantity', r.confirmed_quantity,
  'unit_id', r.unit_id,
  'need_generation_run_id', r.need_generation_run_id,
  'need_generation_release_snapshot_id', r.need_generation_release_snapshot_id
)::text) fingerprint
from atlas_planning.confirmed_need_line_revisions r
where need_generation_run_id='d4600000-0000-0000-0000-000000002000';

set local session_replication_role = replica;
update atlas_planning.need_generation_runs
set run_status='INVALIDATED', invalidated_by_actor_id='d4600000-0000-0000-0000-000000000001', invalidated_at=transaction_timestamp()
where need_generation_run_id='d4600000-0000-0000-0000-000000002000';
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000002200', 'd4600000-0000-0000-0000-000000002201',
  'd4600000-0000-0000-0000-000000002202', '2026-09-17', '2026-09-17',
  jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000002301','predecessor_id','d4600000-0000-0000-0000-000000002101','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000108','unit_id','d4600000-0000-0000-0000-000000000014','quantity','0.105')),
  'd4600000-0000-0000-0000-000000002000'
);
set local session_replication_role = origin;
set local role authenticated;
insert into proposal_results values (
  'correction',
  atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request(
    'd4600000-0000-0000-0000-000000002200', 'd4600000-0000-0000-0000-000000002901',
    'proposal-correction', (select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid from proposal_results where result_name='correction-initial')
  ))
);
reset role;
select is((select response->>'success' from proposal_results where result_name='correction'), 'true', 'POP-15 correction materialization succeeds');
select is((select md5(jsonb_build_object(
  'theoretical_quantity', r.theoretical_quantity,
  'confirmed_quantity', r.confirmed_quantity,
  'unit_id', r.unit_id,
  'need_generation_run_id', r.need_generation_run_id,
  'need_generation_release_snapshot_id', r.need_generation_release_snapshot_id
)::text) from atlas_planning.confirmed_need_line_revisions r join proposal_old_revision old using(confirmed_need_line_revision_id)), (select fingerprint from proposal_old_revision), 'POP-16 correction changes lifecycle state without rewriting historical quantity/source facts');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id=(select confirmed_need_line_id from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='d4600000-0000-0000-0000-000000002000')), 2::bigint, 'POP-17 correction appends one successor revision');
select is((select theoretical_quantity from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='d4600000-0000-0000-0000-000000002200' and is_current), 0.105000::numeric, 'POP-18 correction preserves the new exact raw total');
select is((select confirmed_quantity from atlas_planning.confirmed_need_line_revisions where need_generation_run_id='d4600000-0000-0000-0000-000000002200' and is_current), 0.500000::numeric, 'POP-19 correction derives the new proposal from the current Ingredient rounding step');
select is((select sum(controlled_contribution_quantity) from atlas_planning.confirmed_need_line_revision_contributions c join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id) where r.need_generation_run_id='d4600000-0000-0000-0000-000000002200'), 0.105000::numeric, 'POP-20 correction membership remains exact raw evidence');

set local session_replication_role = replica;
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000003000', 'd4600000-0000-0000-0000-000000003001', 'd4600000-0000-0000-0000-000000003002',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000003101','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000109','unit_id','d4600000-0000-0000-0000-000000000016','quantity','1'))
);
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000003200', 'd4600000-0000-0000-0000-000000003201', 'd4600000-0000-0000-0000-000000003202',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000003301','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000110','unit_id','d4600000-0000-0000-0000-000000000017','quantity','1'))
);
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000003400', 'd4600000-0000-0000-0000-000000003401', 'd4600000-0000-0000-0000-000000003402',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000003501','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000111','unit_id','d4600000-0000-0000-0000-000000000014','quantity','1'))
);
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, predecessor_policy_revision_id, planning_step, effective_from,
  policy_revision_status, created_by_actor_id, created_at, approved_by_actor_id,
  approved_at, activated_by_actor_id, activated_at
) values (
  'd4600000-0000-0000-0000-000000000033', 'd4600000-0000-0000-0000-000000000020',
  'd4600000-0000-0000-0000-000000000014', 2, 'd4600000-0000-0000-0000-000000000030',
  0.02, '2026-01-01', 'ACTIVE', 'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
  'd4600000-0000-0000-0000-000000000001', transaction_timestamp(),
  'd4600000-0000-0000-0000-000000000001', transaction_timestamp()
);
set local session_replication_role = origin;

set local role authenticated;
insert into proposal_results values ('missing-policy', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000003000','d4600000-0000-0000-0000-000000003900','proposal-missing-policy')));
insert into proposal_results values ('ineffective-policy', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000003200','d4600000-0000-0000-0000-000000003901','proposal-ineffective-policy')));
insert into proposal_results values ('ambiguous-policy', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000003400','d4600000-0000-0000-0000-000000003902','proposal-ambiguous-policy')));
reset role;

select is((select response->>'error_code' from proposal_results where result_name='missing-policy'), 'MISSING_PLANNING_QUANTITY_POLICY', 'POP-21 missing exact Unit policy fails closed');
select is((select count(*) from atlas_planning.confirmed_need_batches where origin_need_generation_run_id='d4600000-0000-0000-0000-000000003000'), 0::bigint, 'POP-22 missing policy creates no partial batch');
select is((select response->>'error_code' from proposal_results where result_name='ineffective-policy'), 'MISSING_PLANNING_QUANTITY_POLICY', 'POP-23 policy with no effective revision fails closed');
select is((select count(*) from atlas_planning.confirmed_need_batches where origin_need_generation_run_id='d4600000-0000-0000-0000-000000003200'), 0::bigint, 'POP-24 ineffective policy creates no partial batch');
select is((select response->>'error_code' from proposal_results where result_name='ambiguous-policy'), 'AMBIGUOUS_PLANNING_QUANTITY_POLICY', 'POP-25 overlapping effective revisions fail closed');
select is((select count(*) from atlas_planning.confirmed_need_batches where origin_need_generation_run_id='d4600000-0000-0000-0000-000000003400'), 0::bigint, 'POP-26 ambiguous policy creates no partial batch');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where need_generation_run_id in ('d4600000-0000-0000-0000-000000003000','d4600000-0000-0000-0000-000000003200','d4600000-0000-0000-0000-000000003400')), 0::bigint, 'POP-27 every policy-resolution failure leaves zero revisions');

set local session_replication_role = replica;
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000004000', 'd4600000-0000-0000-0000-000000004001', 'd4600000-0000-0000-0000-000000004002',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000004101','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000112','unit_id','d4600000-0000-0000-0000-000000000014','quantity','1'))
);
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000004200', 'd4600000-0000-0000-0000-000000004201', 'd4600000-0000-0000-0000-000000004202',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000004301','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000112','unit_id','d4600000-0000-0000-0000-000000000015','quantity','1'))
);
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000004400', 'd4600000-0000-0000-0000-000000004401', 'd4600000-0000-0000-0000-000000004402',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000004501','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000112','unit_id','d4600000-0000-0000-0000-000000000014','quantity','1'))
);
select pg_temp.proposal_seed_run(
  'd4600000-0000-0000-0000-000000004600', 'd4600000-0000-0000-0000-000000004601', 'd4600000-0000-0000-0000-000000004602',
  '2026-09-17', '2026-09-17', jsonb_build_array(jsonb_build_object('theoretical_id','d4600000-0000-0000-0000-000000004701','service_date','2026-09-17','ingredient_id','d4600000-0000-0000-0000-000000000115','unit_id','d4600000-0000-0000-0000-000000000018','quantity','1'))
);
update atlas_admin.ingredients
set order_step = null
where ingredient_id='d4600000-0000-0000-0000-000000000112';
set local session_replication_role = origin;
set local role authenticated;
insert into proposal_results values ('invalid-rounding-config', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000004000','d4600000-0000-0000-0000-000000004900','proposal-invalid-rounding-config')));
insert into proposal_results values ('incompatible-kg-step', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000004600','d4600000-0000-0000-0000-000000004903','proposal-incompatible-kg-step')));
reset role;

set local session_replication_role = replica;
update atlas_admin.ingredients
set purchase_unit_id='d4600000-0000-0000-0000-000000000015', order_step = 2.5
where ingredient_id='d4600000-0000-0000-0000-000000000112';
set local session_replication_role = origin;
set local role authenticated;
insert into proposal_results values ('incompatible-rounding-step', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000004200','d4600000-0000-0000-0000-000000004901','proposal-incompatible-rounding-step')));
reset role;

set local session_replication_role = replica;
update atlas_admin.ingredients
set purchase_unit_id='d4600000-0000-0000-0000-000000000015', order_step=1
where ingredient_id='d4600000-0000-0000-0000-000000000112';
set local session_replication_role = origin;
set local role authenticated;
insert into proposal_results values ('rounding-unit-mismatch', atlas_api.create_confirmed_needs_from_generation(pg_temp.proposal_request('d4600000-0000-0000-0000-000000004400','d4600000-0000-0000-0000-000000004902','proposal-rounding-unit-mismatch')));
reset role;

select is((select response->>'error_code' from proposal_results where result_name='invalid-rounding-config'), 'INGREDIENT_ROUNDING_CONFIGURATION_INVALID', 'POP-28 missing Ingredient order_step fails closed');
select is((select count(*) from atlas_planning.confirmed_need_batches where origin_need_generation_run_id='d4600000-0000-0000-0000-000000004000'), 0::bigint, 'POP-29 invalid Ingredient rounding configuration creates no partial batch');
select is((select response->>'error_code' from proposal_results where result_name='incompatible-kg-step'), 'INGREDIENT_ROUNDING_STEP_INCOMPATIBLE', 'POP-29A kg Ingredient order_step 0.005 is incompatible with H1A 0.01');
select is((select count(*) from atlas_planning.confirmed_need_batches where origin_need_generation_run_id='d4600000-0000-0000-0000-000000004600'), 0::bigint, 'POP-29B incompatible kg Ingredient step creates no partial batch');
select is((select response->>'error_code' from proposal_results where result_name='incompatible-rounding-step'), 'INGREDIENT_ROUNDING_STEP_INCOMPATIBLE', 'POP-30 COUNT Ingredient order_step 2.5 is incompatible with H1A 1');
select is((select count(*) from atlas_planning.confirmed_need_batches where origin_need_generation_run_id='d4600000-0000-0000-0000-000000004200'), 0::bigint, 'POP-31 incompatible Ingredient rounding step creates no partial batch');
select is((select response->>'error_code' from proposal_results where result_name='rounding-unit-mismatch'), 'INGREDIENT_ROUNDING_CONFIGURATION_INVALID', 'POP-32 Ingredient purchase Unit mismatch fails closed');
select is((select count(*) from atlas_planning.confirmed_need_line_revisions where need_generation_run_id in ('d4600000-0000-0000-0000-000000004000','d4600000-0000-0000-0000-000000004200','d4600000-0000-0000-0000-000000004400','d4600000-0000-0000-0000-000000004600')), 0::bigint, 'POP-33 every Ingredient rounding failure leaves zero revisions');

select throws_ok(
  $$update atlas_planning.confirmed_need_line_revisions
    set proposal_rounding_step = 0.25
    where ingredient_id = 'd4600000-0000-0000-0000-000000000114'
      and revision_number = 2$$,
  '23514',
  'Confirmed Need revision source identity and theoretical total are immutable',
  'POP-34 proposal rounding step is immutable revision evidence'
);
select throws_ok(
  $$update atlas_planning.confirmed_need_line_revisions
    set proposal_rounding_ingredient_version = 2
    where ingredient_id = 'd4600000-0000-0000-0000-000000000114'
      and revision_number = 2$$,
  '23514',
  'Confirmed Need revision source identity and theoretical total are immutable',
  'POP-35 proposal Ingredient version is immutable revision evidence'
);

set local session_replication_role = replica;
update atlas_planning.confirmed_need_line_revisions
set proposal_rounding_step = null,
    proposal_rounding_ingredient_version = null
where ingredient_id = 'd4600000-0000-0000-0000-000000000101'
  and is_current;
set local session_replication_role = origin;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4600000-0000-0000-0000-000000000002', true);
insert into proposal_results values (
  'legacy-readback',
  atlas_api.get_confirmed_need_review(pg_temp.proposal_read((
    select (response#>>'{affected_aggregate_ids,confirmed_need_batch_id}')::uuid
    from proposal_results where result_name='examples'
  )))
);
reset role;
select is(
  (select jsonb_build_object(
    'theoretical', read_line->>'theoretical_quantity',
    'proposal', read_line->>'proposed_confirmed_quantity',
    'step', read_line->'proposal_rounding_step'
  ) from proposal_results r
  cross join lateral jsonb_array_elements(r.response#>'{workbench,lines}') read_line
  where r.result_name='legacy-readback'
    and read_line#>>'{ingredient,id}'='d4600000-0000-0000-0000-000000000101'),
  jsonb_build_object('theoretical','0.080000','proposal','0.100000','step',null),
  'POP-36 legacy null-snapshot readback retains the stored proposal fallback'
);

select * from finish();
rollback;
