begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(37);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

-- Bounded public surface and least-privilege runtime (1-7).
select is(
  (select array_agg(capability_code order by capability_code)::text[]
   from atlas_core.capabilities
   where capability_code in (
     'confirmed_need_review.read',
     'confirmed_need_quantities.preview',
     'confirmed_need_quantities.confirm'
   )),
  array[
    'confirmed_need_quantities.confirm',
    'confirmed_need_quantities.preview',
    'confirmed_need_review.read'
  ]::text[],
  'RMVP05-01 exactly three RMVP-05 capabilities exist'
);
select is(
  (select count(*)::integer
   from atlas_core.role_capabilities rc
   join atlas_core.capabilities c using (capability_id)
   where c.capability_code like 'confirmed_need%'),
  0,
  'RMVP05-02 no production application role receives an RMVP-05 capability'
);
select is(
  (select array_agg(p.proname order by p.proname)::text[]
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname in (
     'get_confirmed_need_review',
     'preview_confirmed_need_confirmation',
     'confirm_need_quantities'
   )),
  array[
    'confirm_need_quantities',
    'get_confirmed_need_review',
    'preview_confirmed_need_confirmation'
  ]::text[],
  'RMVP05-03 the public surface is exactly the three reviewed functions'
);
select ok(
  (select bool_and(pg_get_userbyid(p.proowner) = 'atlas_confirmed_need_review_runtime')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname in (
     'get_confirmed_need_review',
     'preview_confirmed_need_confirmation',
     'confirm_need_quantities'
   )),
  'RMVP05-04 the dedicated runtime owns all three APIs'
);
select ok(
  (select bool_and(p.prosecdef and p.proconfig = array['search_path=""']::text[])
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname in (
     'get_confirmed_need_review',
     'preview_confirmed_need_confirmation',
     'confirm_need_quantities'
   )),
  'RMVP05-05 every API is a fixed-search-path security definer'
);
select ok(
  (select bool_and(
     has_function_privilege('authenticated', p.oid, 'EXECUTE')
     and not has_function_privilege('anon', p.oid, 'EXECUTE')
     and not has_function_privilege('service_role', p.oid, 'EXECUTE')
   )
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'atlas_api' and p.proname in (
     'get_confirmed_need_review',
     'preview_confirmed_need_confirmation',
     'confirm_need_quantities'
   )),
  'RMVP05-06 only authenticated receives public execute'
);
select is(
  (select jsonb_build_object(
     'login', rolcanlogin, 'inherit', rolinherit, 'superuser', rolsuper,
     'create_role', rolcreaterole, 'create_db', rolcreatedb,
     'replication', rolreplication, 'bypass_rls', rolbypassrls
   ) from pg_roles where rolname = 'atlas_confirmed_need_review_runtime'),
  jsonb_build_object(
    'login', false, 'inherit', false, 'superuser', false,
    'create_role', false, 'create_db', false,
    'replication', false, 'bypass_rls', false
  ),
  'RMVP05-07 the runtime is NOLOGIN NOINHERIT and unprivileged'
);

create temporary table rmvp05_context (batch_id uuid);
grant select, insert on rmvp05_context to authenticated;

create function pg_temp.rmvp05_rmvp04_command(
  p_command_id uuid,
  p_key text,
  p_expected_version bigint,
  p_reason text,
  p_payload jsonb
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-04.v1',
    'command_id', p_command_id,
    'correlation_id', gen_random_uuid(),
    'idempotency_key', p_key,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', 'f5000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', transaction_timestamp(),
    'reason_code', p_reason,
    'reason_note', null,
    'payload', p_payload
  );
$$;

create function pg_temp.rmvp05_cmd15(p_run_id uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'PA-06E-H0C.v1',
    'command_id', 'f5000000-0000-0000-0000-000000000015'::uuid,
    'correlation_id', gen_random_uuid(),
    'idempotency_key', 'rmvp05-materialize',
    'expected_version', 1,
    'requested_by_auth_subject', 'f5000000-0000-0000-0000-000000000101'::uuid,
    'requested_at', transaction_timestamp(),
    'reason_code', 'RMVP05_MATERIALIZATION',
    'reason_note', 'RMVP-05 focused acceptance prerequisite',
    'payload', jsonb_build_object(
      'need_generation_run_id', p_run_id,
      'need_generation_run_version', 3,
      'confirmed_need_batch_id', null
    )
  );
$$;

create function pg_temp.rmvp05_read(
  p_batch_id uuid,
  p_subject uuid default 'f5000000-0000-0000-0000-000000000101'
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject', p_subject,
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', p_batch_id,
      'filters', jsonb_build_object(),
      'line_offset', 0,
      'line_limit', 100
    )
  );
$$;

create function pg_temp.rmvp05_lines(
  p_first_quantity text default null,
  p_first_reason text default 'PROPOSAL_ACCEPTED',
  p_first_note text default null,
  p_second_quantity text default null,
  p_second_reason text default 'PROPOSAL_ACCEPTED',
  p_second_note text default null
) returns jsonb language sql stable security definer set search_path = '' as $$
  with ordered as (
    select l.confirmed_need_line_id, l.current_confirmed_need_line_decision_id,
      r.confirmed_need_line_revision_id, r.confirmed_quantity,
      row_number() over (order by l.ingredient_id, l.confirmed_need_line_id) as ordinal
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r
      on r.confirmed_need_line_id = l.confirmed_need_line_id and r.is_current
    where l.confirmed_need_batch_id = (select batch_id from pg_temp.rmvp05_context)
  )
  select jsonb_agg(jsonb_build_object(
    'confirmed_need_line_id', confirmed_need_line_id,
    'expected_current_revision_id', confirmed_need_line_revision_id,
    'expected_current_decision_id', current_confirmed_need_line_decision_id,
    'proposed_confirmed_quantity', case when ordinal = 1
      then coalesce(p_first_quantity, confirmed_quantity::text)
      else coalesce(p_second_quantity, confirmed_quantity::text) end,
    'reason_code', case when ordinal = 1 then p_first_reason else p_second_reason end,
    'reason_note', case when ordinal = 1 then p_first_note else p_second_note end
  ) order by confirmed_need_line_id)
  from ordered;
$$;

create function pg_temp.rmvp05_single_line(
  p_ordinal integer,
  p_quantity text default null,
  p_reason text default 'PROPOSAL_ACCEPTED',
  p_note text default null
) returns jsonb language sql stable security definer set search_path = '' as $$
  with ordered as (
    select l.confirmed_need_line_id, l.current_confirmed_need_line_decision_id,
      r.confirmed_need_line_revision_id, r.confirmed_quantity,
      row_number() over (order by l.ingredient_id, l.confirmed_need_line_id) as ordinal
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r
      on r.confirmed_need_line_id = l.confirmed_need_line_id and r.is_current
    where l.confirmed_need_batch_id = (select batch_id from pg_temp.rmvp05_context)
  )
  select jsonb_agg(jsonb_build_object(
    'confirmed_need_line_id', confirmed_need_line_id,
    'expected_current_revision_id', confirmed_need_line_revision_id,
    'expected_current_decision_id', current_confirmed_need_line_decision_id,
    'proposed_confirmed_quantity', coalesce(p_quantity, confirmed_quantity::text),
    'reason_code', p_reason,
    'reason_note', p_note
  )) from ordered where ordinal = p_ordinal;
$$;

create function pg_temp.rmvp05_preview(
  p_version bigint,
  p_lines jsonb,
  p_subject uuid default 'f5000000-0000-0000-0000-000000000101'
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'requested_by_auth_subject', p_subject,
    'correlation_id', gen_random_uuid(),
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', (select batch_id from pg_temp.rmvp05_context),
      'expected_batch_version', p_version,
      'lines', p_lines
    )
  );
$$;

create function pg_temp.rmvp05_confirm(
  p_command_id uuid,
  p_key text,
  p_version bigint,
  p_hash text,
  p_lines jsonb,
  p_subject uuid default 'f5000000-0000-0000-0000-000000000101'
) returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-05.v1',
    'command_id', p_command_id,
    'correlation_id', 'f5000000-0000-0000-0000-000000000501'::uuid,
    'idempotency_key', p_key,
    'expected_version', p_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp(),
    'reason_code', 'CONFIRMED_NEED_QUANTITIES_CONFIRMED',
    'reason_note', null,
    'payload', jsonb_build_object(
      'confirmed_need_batch_id', (select batch_id from pg_temp.rmvp05_context),
      'preview_hash', p_hash,
      'lines', p_lines
    )
  );
$$;

-- Synthetic authorization and a compact, real Pantry-only RMVP-04 source.
insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('f5000000-0000-0000-0000-000000000001', 'HUMAN', 'RMVP-05 operator'),
  ('f5000000-0000-0000-0000-000000000002', 'HUMAN', 'RMVP-05 capability-free actor'),
  ('f5000000-0000-0000-0000-000000000003', 'HUMAN', 'RMVP-05 wrong-scope actor');
insert into atlas_core.actor_auth_subjects (actor_auth_subject_id, actor_id, auth_subject_id) values
  ('f5000000-0000-0000-0000-000000000011', 'f5000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000101'),
  ('f5000000-0000-0000-0000-000000000012', 'f5000000-0000-0000-0000-000000000002', 'f5000000-0000-0000-0000-000000000102'),
  ('f5000000-0000-0000-0000-000000000013', 'f5000000-0000-0000-0000-000000000003', 'f5000000-0000-0000-0000-000000000103');
insert into atlas_core.roles (role_id, role_code, role_name) values
  ('f5000000-0000-0000-0000-000000000020', 'rmvp05.operator', 'RMVP-05 operator'),
  ('f5000000-0000-0000-0000-000000000021', 'rmvp05.denied', 'RMVP-05 denied');
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'f5000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities where capability_code in (
  'planning.need_generation.write',
  'confirmed_need_generation.materialize',
  'confirmed_need_review.read',
  'confirmed_need_quantities.preview',
  'confirmed_need_quantities.confirm'
);
insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('f5000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000020'),
  ('f5000000-0000-0000-0000-000000000002', 'f5000000-0000-0000-0000-000000000021'),
  ('f5000000-0000-0000-0000-000000000003', 'f5000000-0000-0000-0000-000000000020');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('f5000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('f5000000-0000-0000-0000-000000000002', 'GLOBAL');

set local session_replication_role = replica;

insert into atlas_admin.customers (customer_id, customer_code, customer_name, customer_type)
values ('f5100000-0000-0000-0000-000000000001', 'rmvp05-customer', 'RMVP-05 Customer', 'SCHOOL_CATERING');
insert into atlas_admin.delivery_locations (delivery_location_id, customer_id, location_code, location_name, address_text, timezone_name)
values ('f5100000-0000-0000-0000-000000000002', 'f5100000-0000-0000-0000-000000000001', 'rmvp05-kitchen', 'RMVP-05 Kitchen', 'Fixture kitchen', 'Asia/Ho_Chi_Minh');
insert into atlas_admin.school_types (school_type_id, school_type_code, school_type_name)
values ('f5100000-0000-0000-0000-000000000003', 'rmvp05-type', 'RMVP-05 Type');
insert into atlas_admin.schools (school_id, customer_id, school_code, school_name, school_type_id, default_delivery_location_id, display_order)
values ('f5100000-0000-0000-0000-000000000004', 'f5100000-0000-0000-0000-000000000001', 'rmvp05-school', 'RMVP-05 School', 'f5100000-0000-0000-0000-000000000003', 'f5100000-0000-0000-0000-000000000002', 10);
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code)
values ('f5100000-0000-0000-0000-000000000005', 'rmvp05-kg', 'RMVP-05 kilogram', 'mass');
insert into atlas_admin.ingredients (ingredient_id, ingredient_code, ingredient_name) values
  ('f5100000-0000-0000-0000-000000000006', 'rmvp05-rice', 'RMVP-05 rice'),
  ('f5100000-0000-0000-0000-000000000007', 'rmvp05-beans', 'RMVP-05 beans');

insert into atlas_planning.weekly_menus (weekly_menu_id, week_start, week_end, source_type, source_name, source_signature, row_count, imported_by_actor_id, weekly_menu_status, latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id)
values ('f5200000-0000-0000-0000-000000000001', '2026-11-02', '2026-11-08', 'FIXTURE', 'RMVP-05 empty menu', 'rmvp05-menu', 0, 'f5000000-0000-0000-0000-000000000001', 'APPROVED', 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:00:00+07', 'f5200000-0000-0000-0000-000000000002');
insert into atlas_planning.weekly_menu_approval_snapshots (weekly_menu_approval_snapshot_id, weekly_menu_id, weekly_menu_version, approved_by_actor_id, approved_at)
values ('f5200000-0000-0000-0000-000000000002', 'f5200000-0000-0000-0000-000000000001', 1, 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:00:00+07');

insert into atlas_planning.attendance_batches (attendance_batch_id, period_start, period_end, source_type, source_name, source_signature, row_count, imported_by_actor_id, attendance_status, latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id)
values ('f5300000-0000-0000-0000-000000000001', '2026-11-02', '2026-11-08', 'FIXTURE', 'RMVP-05 empty attendance', 'rmvp05-attendance', 0, 'f5000000-0000-0000-0000-000000000001', 'APPROVED', 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:01:00+07', 'f5300000-0000-0000-0000-000000000002');
insert into atlas_planning.attendance_approval_snapshots (attendance_approval_snapshot_id, attendance_batch_id, attendance_version, approved_by_actor_id, approved_at)
values ('f5300000-0000-0000-0000-000000000002', 'f5300000-0000-0000-0000-000000000001', 1, 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:01:00+07');

insert into atlas_planning.pantry_need_purposes (pantry_need_purpose_id, purpose_code, purpose_name_vi, purpose_description, note_rule, purpose_status, display_order)
values ('f5400000-0000-0000-0000-000000000001', 'rmvp05_supplement', 'Bổ sung RMVP-05', 'Synthetic focused fixture.', 'OPTIONAL', 'ACTIVE', 10);
insert into atlas_planning.pantry_need_batches (pantry_need_batch_id, week_start, source_signature, no_additions_confirmed, requesting_actor_id, pantry_need_batch_status, latest_approved_by_actor_id, latest_approved_at, latest_approval_snapshot_id)
values ('f5400000-0000-0000-0000-000000000002', '2026-11-02', repeat('f', 64), false, 'f5000000-0000-0000-0000-000000000001', 'APPROVED', 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:02:00+07', 'f5400000-0000-0000-0000-000000000003');
insert into atlas_planning.pantry_need_lines (pantry_need_line_id, pantry_need_batch_id, service_date, school_id, delivery_location_id, ingredient_id, unit_id, pantry_need_purpose_id, requested_quantity, note, source_request_reference, source_row_reference, updated_by_actor_id) values
  ('f5400000-0000-0000-0000-000000000004', 'f5400000-0000-0000-0000-000000000002', '2026-11-02', 'f5100000-0000-0000-0000-000000000004', 'f5100000-0000-0000-0000-000000000002', 'f5100000-0000-0000-0000-000000000006', 'f5100000-0000-0000-0000-000000000005', 'f5400000-0000-0000-0000-000000000001', 2, 'Rice supplement', 'RMVP05', '1', 'f5000000-0000-0000-0000-000000000001'),
  ('f5400000-0000-0000-0000-000000000005', 'f5400000-0000-0000-0000-000000000002', '2026-11-02', 'f5100000-0000-0000-0000-000000000004', 'f5100000-0000-0000-0000-000000000002', 'f5100000-0000-0000-0000-000000000007', 'f5100000-0000-0000-0000-000000000005', 'f5400000-0000-0000-0000-000000000001', 3, 'Bean supplement', 'RMVP05', '2', 'f5000000-0000-0000-0000-000000000001');
insert into atlas_planning.pantry_need_approval_snapshots (pantry_need_approval_snapshot_id, pantry_need_batch_id, approved_batch_version, approved_by_actor_id, approved_at, source_signature, no_additions_confirmed, line_count)
values ('f5400000-0000-0000-0000-000000000003', 'f5400000-0000-0000-0000-000000000002', 1, 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:02:00+07', repeat('f', 64), false, 2);
insert into atlas_planning.pantry_need_approval_snapshot_lines (
  pantry_need_approval_snapshot_id, pantry_need_line_id, service_date,
  school_id, school_code_snapshot, school_name_snapshot,
  delivery_location_id, delivery_location_code_snapshot, delivery_location_name_snapshot, delivery_location_address_snapshot,
  ingredient_id, ingredient_code_snapshot, ingredient_name_snapshot,
  unit_id, unit_code_snapshot, unit_name_snapshot,
  pantry_need_purpose_id, purpose_code_snapshot, purpose_name_snapshot, purpose_description_snapshot, purpose_note_rule_snapshot,
  requested_quantity, note, source_request_reference, source_row_reference
) values
  ('f5400000-0000-0000-0000-000000000003', 'f5400000-0000-0000-0000-000000000004', '2026-11-02', 'f5100000-0000-0000-0000-000000000004', 'rmvp05-school', 'RMVP-05 School', 'f5100000-0000-0000-0000-000000000002', 'rmvp05-kitchen', 'RMVP-05 Kitchen', 'Fixture kitchen', 'f5100000-0000-0000-0000-000000000006', 'rmvp05-rice', 'RMVP-05 rice', 'f5100000-0000-0000-0000-000000000005', 'rmvp05-kg', 'RMVP-05 kilogram', 'f5400000-0000-0000-0000-000000000001', 'rmvp05_supplement', 'Bổ sung RMVP-05', 'Synthetic focused fixture.', 'OPTIONAL', 2, 'Rice supplement', 'RMVP05', '1'),
  ('f5400000-0000-0000-0000-000000000003', 'f5400000-0000-0000-0000-000000000005', '2026-11-02', 'f5100000-0000-0000-0000-000000000004', 'rmvp05-school', 'RMVP-05 School', 'f5100000-0000-0000-0000-000000000002', 'rmvp05-kitchen', 'RMVP-05 Kitchen', 'Fixture kitchen', 'f5100000-0000-0000-0000-000000000007', 'rmvp05-beans', 'RMVP-05 beans', 'f5100000-0000-0000-0000-000000000005', 'rmvp05-kg', 'RMVP-05 kilogram', 'f5400000-0000-0000-0000-000000000001', 'rmvp05_supplement', 'Bổ sung RMVP-05', 'Synthetic focused fixture.', 'OPTIONAL', 3, 'Bean supplement', 'RMVP05', '2');

insert into atlas_planning.need_generation_calculation_contracts (need_generation_calculation_contract_id, contract_code, current_revision_id, version, created_at, updated_at)
values ('f5400000-0000-0000-0000-000000000010', 'school_catering_proportional_per_basis', 'f5400000-0000-0000-0000-000000000011', 1, '2026-11-01 07:00:00+07', '2026-11-01 07:00:00+07');
insert into atlas_planning.need_generation_calculation_contract_revisions (need_generation_calculation_contract_revision_id, need_generation_calculation_contract_id, revision_number, formula_kind, quantity_precision, quantity_scale, factor_precision, factor_scale, final_coercion_mode, approved_by_actor_id, approved_at)
values ('f5400000-0000-0000-0000-000000000011', 'f5400000-0000-0000-0000-000000000010', 1, 'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS', 20, 6, 24, 12, 'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO', 'f5000000-0000-0000-0000-000000000001', '2026-11-01 07:00:00+07');

insert into atlas_planning.planning_input_sets (planning_input_set_id, period_start, period_end, readiness_status, current_evaluation_id)
values ('f5400000-0000-0000-0000-000000000020', '2026-11-02', '2026-11-02', 'NEED_GENERATION_REQUESTED', 'f5400000-0000-0000-0000-000000000021');
insert into atlas_planning.planning_input_evaluations (
  planning_input_evaluation_id, planning_input_set_id, evaluation_version, evaluation_result,
  weekly_menu_id, weekly_menu_version, weekly_menu_approval_snapshot_id,
  attendance_batch_id, attendance_version, attendance_approval_snapshot_id,
  pantry_need_batch_id, pantry_need_batch_version, pantry_need_approval_snapshot_id,
  blocking_issue_count, warning_count, evaluated_by_actor_id, evaluated_at
) values (
  'f5400000-0000-0000-0000-000000000021', 'f5400000-0000-0000-0000-000000000020', 1, 'READY',
  'f5200000-0000-0000-0000-000000000001', 1, 'f5200000-0000-0000-0000-000000000002',
  'f5300000-0000-0000-0000-000000000001', 1, 'f5300000-0000-0000-0000-000000000002',
  'f5400000-0000-0000-0000-000000000002', 1, 'f5400000-0000-0000-0000-000000000003',
  0, 0, 'f5000000-0000-0000-0000-000000000001', '2026-11-01 09:03:00+07'
);

set local session_replication_role = origin;
set constraints all immediate;
set constraints all deferred;

create temporary table rmvp05_responses (response_name text primary key, response jsonb not null);
create temporary table rmvp05_requests (request_name text primary key, request jsonb not null);
grant select, insert on rmvp05_responses, rmvp05_requests to authenticated;

insert into rmvp05_requests values (
  'create-run',
  pg_temp.rmvp05_rmvp04_command(
    'f5000000-0000-0000-0000-000000000031', 'rmvp05-create-run', 1,
    'NEED_GENERATION_CREATED', jsonb_build_object(
      'planning_input_set_id', 'f5400000-0000-0000-0000-000000000020',
      'planning_input_evaluation_id', 'f5400000-0000-0000-0000-000000000021',
      'period_start', '2026-11-02', 'period_end', '2026-11-02'
    )
  )
);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000101', true);
insert into rmvp05_responses select 'create-run', atlas_api.create_need_generation_run(request) from rmvp05_requests where request_name = 'create-run';
reset role;
select ok(
  (select response->>'success' = 'true' and response->'new_versions'->>'need_generation_run_version' = '1'
   and (select count(*) from atlas_planning.theoretical_need_lines l where l.need_generation_run_id = (response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid) = 2
   from rmvp05_responses where response_name = 'create-run'),
  'RMVP05-08 real RMVP-04 creates a two-line Pantry-only run'
);

insert into rmvp05_requests
select 'validate-run', pg_temp.rmvp05_rmvp04_command(
  'f5000000-0000-0000-0000-000000000032', 'rmvp05-validate-run', 1,
  'NEED_GENERATION_VALIDATED', jsonb_build_object('need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id')
) from rmvp05_responses where response_name = 'create-run';
set local role authenticated;
insert into rmvp05_responses select 'validate-run', atlas_api.validate_need_generation_run(request) from rmvp05_requests where request_name = 'validate-run';
reset role;
select ok((select response->>'success' = 'true' and response->'new_versions'->>'need_generation_run_version' = '2' from rmvp05_responses where response_name = 'validate-run'), 'RMVP05-09 real RMVP-04 validation succeeds');

insert into rmvp05_requests
select 'release-run', pg_temp.rmvp05_rmvp04_command(
  'f5000000-0000-0000-0000-000000000033', 'rmvp05-release-run', 2,
  'NEED_GENERATION_RELEASED', jsonb_build_object('need_generation_run_id', response->'affected_aggregate_ids'->>'need_generation_run_id')
) from rmvp05_responses where response_name = 'create-run';
set local role authenticated;
insert into rmvp05_responses select 'release-run', atlas_api.release_need_generation_run(request) from rmvp05_requests where request_name = 'release-run';
reset role;
select ok(
  (select response->>'success' = 'true' and response->'new_versions'->>'need_generation_run_version' = '3'
   and (select count(*) from atlas_planning.need_generation_release_snapshot_lines s where s.need_generation_release_snapshot_id = (response->'affected_aggregate_ids'->>'need_generation_release_snapshot_id')::uuid) = 2
   from rmvp05_responses where response_name = 'release-run'),
  'RMVP05-10 real RMVP-04 release captures both lines'
);

set local role authenticated;
insert into rmvp05_responses
select 'materialize', atlas_api.create_confirmed_needs_from_generation(pg_temp.rmvp05_cmd15((response->'affected_aggregate_ids'->>'need_generation_run_id')::uuid))
from rmvp05_responses where response_name = 'create-run';
reset role;
set constraints all immediate;
set constraints all deferred;
insert into rmvp05_context
select (response->'affected_aggregate_ids'->>'confirmed_need_batch_id')::uuid
from rmvp05_responses where response_name = 'materialize';
select ok(
  (select response->>'success' = 'true' from rmvp05_responses where response_name = 'materialize')
  and (select count(*) from atlas_planning.confirmed_need_lines where confirmed_need_batch_id = (select batch_id from rmvp05_context)) = 2,
  'RMVP05-11 real CMD-15 materializes the two-line batch'
);

set local role authenticated;
insert into rmvp05_responses select 'read-missing-policy', atlas_api.get_confirmed_need_review(pg_temp.rmvp05_read((select batch_id from rmvp05_context)));
reset role;
select ok(
  (select response->>'success' = 'true'
    and response->'workbench'->'line_counts'->>'total' = '2'
    and response->'workbench'->'allowed_actions'->>'confirm_quantities' = 'false'
    and response->'workbench'->'lines'->0->'blockers' @> '[{"code":"MISSING_PLANNING_QUANTITY_POLICY"}]'::jsonb
   from rmvp05_responses where response_name = 'read-missing-policy'),
  'RMVP05-12 read exposes exact lines and blocks a missing Unit policy'
);

set local session_replication_role = replica;
insert into atlas_planning.planning_quantity_policies (planning_quantity_policy_id, unit_id, created_by_actor_id)
values ('f5600000-0000-0000-0000-000000000001', 'f5100000-0000-0000-0000-000000000005', 'f5000000-0000-0000-0000-000000000001');
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, planning_step, effective_from, policy_revision_status,
  created_by_actor_id, created_at, approved_by_actor_id, approved_at,
  activated_by_actor_id, activated_at
) values (
  'f5600000-0000-0000-0000-000000000002', 'f5600000-0000-0000-0000-000000000001', 'f5100000-0000-0000-0000-000000000005',
  1, 0.25, '2026-01-01', 'ACTIVE',
  'f5000000-0000-0000-0000-000000000001', '2026-01-01 08:00:00+07',
  'f5000000-0000-0000-0000-000000000001', '2026-01-01 08:01:00+07',
  'f5000000-0000-0000-0000-000000000001', '2026-01-01 08:02:00+07'
);
set local session_replication_role = origin;

set local session_replication_role = replica;
insert into atlas_planning.planning_quantity_policy_revisions (
  planning_quantity_policy_revision_id, planning_quantity_policy_id, unit_id,
  revision_number, predecessor_policy_revision_id, planning_step, effective_from,
  policy_revision_status, created_by_actor_id, created_at, approved_by_actor_id,
  approved_at, activated_by_actor_id, activated_at
) values (
  'f5600000-0000-0000-0000-000000000003', 'f5600000-0000-0000-0000-000000000001', 'f5100000-0000-0000-0000-000000000005',
  2, 'f5600000-0000-0000-0000-000000000002', 0.50, '2026-06-01',
  'ACTIVE', 'f5000000-0000-0000-0000-000000000001', '2026-06-01 08:00:00+07',
  'f5000000-0000-0000-0000-000000000001', '2026-06-01 08:01:00+07',
  'f5000000-0000-0000-0000-000000000001', '2026-06-01 08:02:00+07'
);
set local session_replication_role = origin;
set local role authenticated;
insert into rmvp05_responses select 'preview-ambiguous', atlas_api.preview_confirmed_need_confirmation(pg_temp.rmvp05_preview(1, pg_temp.rmvp05_lines()));
reset role;
select is((select response->'preview'->>'error_code' from rmvp05_responses where response_name = 'preview-ambiguous'), 'AMBIGUOUS_PLANNING_QUANTITY_POLICY', 'RMVP05-13 ambiguous effective policy blocks preview');
set local session_replication_role = replica;
delete from atlas_planning.planning_quantity_policy_revisions
where planning_quantity_policy_revision_id = 'f5600000-0000-0000-0000-000000000003';
set local session_replication_role = origin;

set local role authenticated;
insert into rmvp05_responses select 'preview-nonrepresentable', atlas_api.preview_confirmed_need_confirmation(pg_temp.rmvp05_preview(1, pg_temp.rmvp05_lines(null, 'PROPOSAL_ACCEPTED', null, '3.10', 'PLANNING_STEP_ADJUSTMENT', null)));
reset role;
select is((select response->'preview'->>'error_code' from rmvp05_responses where response_name = 'preview-nonrepresentable'), 'QUANTITY_NOT_REPRESENTABLE', 'RMVP05-14 a nonintegral exact Planning step is blocked');

create temporary table rmvp05_before_preview as
select
  (select count(*) from atlas_core.command_receipts) as receipts,
  (select count(*) from atlas_audit.domain_events) as events,
  (select count(*) from atlas_audit.audit_events) as audits,
  (select count(*) from atlas_planning.confirmed_need_line_decisions) as decisions,
  (select count(*) from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id = (select batch_id from rmvp05_context)) as revisions,
  (select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id = (select batch_id from rmvp05_context)) as version;

insert into rmvp05_requests values (
  'mixed-lines',
  pg_temp.rmvp05_lines(null, 'PROPOSAL_ACCEPTED', null, '3.25', 'PLANNING_STEP_ADJUSTMENT', null)
);
set local role authenticated;
insert into rmvp05_responses select 'preview-mixed', atlas_api.preview_confirmed_need_confirmation(pg_temp.rmvp05_preview(1, request)) from rmvp05_requests where request_name = 'mixed-lines';
reset role;
select is(
  (select jsonb_object_agg(line->>'decision_kind', jsonb_build_object(
     'quantity', line->>'confirmed_quantity_after',
     'step', line->>'planning_step', 'ticks', line->>'planning_tick_count',
     'successor', line->>'successor_revision_required'
   ))
   from rmvp05_responses r cross join lateral jsonb_array_elements(r.response->'preview'->'ordered_preview_lines') line
   where r.response_name = 'preview-mixed'),
  jsonb_build_object(
    'UNCHANGED_PROPOSAL_ACCEPTED', jsonb_build_object('quantity', '2.000000', 'step', '0.250000', 'ticks', '8', 'successor', 'false'),
    'ADJUSTED_QUANTITY_CONFIRMED', jsonb_build_object('quantity', '3.250000', 'step', '0.250000', 'ticks', '13', 'successor', 'true')
  ),
  'RMVP05-15 shared preview distinguishes unchanged and adjusted exact quantities'
);
select is(
  (select to_jsonb(now_counts) from (
    select
      (select count(*) from atlas_core.command_receipts) as receipts,
      (select count(*) from atlas_audit.domain_events) as events,
      (select count(*) from atlas_audit.audit_events) as audits,
      (select count(*) from atlas_planning.confirmed_need_line_decisions) as decisions,
      (select count(*) from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id = (select batch_id from rmvp05_context)) as revisions,
      (select version from atlas_planning.confirmed_need_batches where confirmed_need_batch_id = (select batch_id from rmvp05_context)) as version
  ) now_counts),
  (select to_jsonb(rmvp05_before_preview) from rmvp05_before_preview),
  'RMVP05-16 preview performs no authoritative or receipt write'
);

insert into rmvp05_requests
select 'confirm-mixed', pg_temp.rmvp05_confirm(
  'f5000000-0000-0000-0000-000000000041', 'rmvp05-confirm-mixed', 1,
  response->'preview'->>'preview_hash', (select request from rmvp05_requests where request_name = 'mixed-lines')
) from rmvp05_responses where response_name = 'preview-mixed';
set local role authenticated;
insert into rmvp05_responses select 'confirm-mixed', atlas_api.confirm_need_quantities(request) from rmvp05_requests where request_name = 'confirm-mixed';
reset role;
select is(
  (select jsonb_build_object(
    'success', response->>'success', 'version', response->>'new_batch_version',
    'unchanged', response->>'unchanged_accepted_line_count', 'adjusted', response->>'adjusted_line_count'
  ) from rmvp05_responses where response_name = 'confirm-mixed'),
  jsonb_build_object('success', 'true', 'version', '2', 'unchanged', '1', 'adjusted', '1'),
  'RMVP05-17 mixed confirmation succeeds and advances the batch once'
);
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id = (select batch_id from rmvp05_context) and revision_number = 1 and is_current), 1, 'RMVP05-18 unchanged acceptance creates no successor revision');
select is((select count(*)::integer from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id = (select batch_id from rmvp05_context) and revision_number = 2 and is_current and confirmed_quantity = 3.25), 1, 'RMVP05-19 adjustment creates exactly one current successor revision');
select is(
  (select jsonb_build_object('members', count(*), 'source_total', sum(source_theoretical_quantity), 'controlled_total', sum(controlled_contribution_quantity))
   from atlas_planning.confirmed_need_line_revision_contributions c
   join atlas_planning.confirmed_need_line_revisions r using (confirmed_need_line_revision_id)
   where r.confirmed_need_batch_id = (select batch_id from rmvp05_context) and r.revision_number = 2),
  jsonb_build_object('members', 1, 'source_total', 3.000000, 'controlled_total', 3.000000),
  'RMVP05-20 adjusted successor preserves the exact source membership without recalculation'
);
select is(
  (select jsonb_object_agg(decision_kind, count order by decision_kind) from (
    select decision_kind, count(*)::integer as count from atlas_planning.confirmed_need_line_decisions group by decision_kind
  ) kinds),
  jsonb_build_object('ADJUSTED_QUANTITY_CONFIRMED', 1, 'UNCHANGED_PROPOSAL_ACCEPTED', 1),
  'RMVP05-21 both H1B1 decision kinds and current pointers are persisted'
);
select ok(
  (select count(*) = 2 from atlas_planning.confirmed_need_lines where current_confirmed_need_line_decision_id is not null)
  and (select count(*) = 1 from atlas_audit.domain_events where command_id = 'f5000000-0000-0000-0000-000000000041')
  and (select count(*) = 1 from atlas_audit.audit_events where command_id = 'f5000000-0000-0000-0000-000000000041')
  and (select count(*) = 1 from atlas_core.command_receipts where command_id = 'f5000000-0000-0000-0000-000000000041' and outcome = 'COMPLETED'),
  'RMVP05-22 pointers, event, audit, and completed receipt commit atomically'
);

set local role authenticated;
insert into rmvp05_responses select 'confirm-replay', atlas_api.confirm_need_quantities(request) from rmvp05_requests where request_name = 'confirm-mixed';
reset role;
select is((select response from rmvp05_responses where response_name = 'confirm-replay'), (select response from rmvp05_responses where response_name = 'confirm-mixed'), 'RMVP05-23 exact replay returns the immutable original response');
select ok(
  (select count(*) = 2 from atlas_planning.confirmed_need_line_decisions)
  and (select count(*) = 3 from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id = (select batch_id from rmvp05_context))
  and (select version = 2 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id = (select batch_id from rmvp05_context)),
  'RMVP05-24 exact replay creates no duplicate business evidence'
);
set local role authenticated;
insert into rmvp05_responses
select 'confirm-conflict', atlas_api.confirm_need_quantities(request || jsonb_build_object('idempotency_key', 'rmvp05-confirm-changed'))
from rmvp05_requests where request_name = 'confirm-mixed';
reset role;
select is((select response->>'error_code' from rmvp05_responses where response_name = 'confirm-conflict'), 'IDEMPOTENCY_CONFLICT', 'RMVP05-25 changed idempotency reuse fails');

set local role authenticated;
insert into rmvp05_responses
select 'confirm-stale', atlas_api.confirm_need_quantities(pg_temp.rmvp05_confirm(
  'f5000000-0000-0000-0000-000000000042', 'rmvp05-confirm-stale', 1,
  (select response->'preview'->>'preview_hash' from rmvp05_responses where response_name = 'preview-mixed'),
  (select request from rmvp05_requests where request_name = 'mixed-lines')
));
reset role;
select ok(
  (select response->>'error_code' = 'STALE_CONFIRMED_NEED_BATCH' from rmvp05_responses where response_name = 'confirm-stale')
  and (select count(*) = 2 from atlas_planning.confirmed_need_line_decisions)
  and (select version = 2 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id = (select batch_id from rmvp05_context)),
  'RMVP05-26 stale preview fails without a business write'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000102', true);
insert into rmvp05_responses select 'capability-denied', atlas_api.get_confirmed_need_review(pg_temp.rmvp05_read((select batch_id from rmvp05_context), 'f5000000-0000-0000-0000-000000000102'));
select set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000103', true);
insert into rmvp05_responses select 'scope-denied', atlas_api.get_confirmed_need_review(pg_temp.rmvp05_read((select batch_id from rmvp05_context), 'f5000000-0000-0000-0000-000000000103'));
reset role;
select is((select response->>'error_code' from rmvp05_responses where response_name = 'capability-denied'), 'CAPABILITY_DENIED', 'RMVP05-27 capability-free human call fails');
select is((select response->>'error_code' from rmvp05_responses where response_name = 'scope-denied'), 'SCOPE_DENIED', 'RMVP05-28 wrong-scope human call fails');
create temporary table rmvp05_access_results (role_name text primary key, call_denied boolean not null);
grant insert, select on rmvp05_access_results to anon, service_role;
set local role anon;
do $$ begin
  begin
    perform atlas_api.get_confirmed_need_review('{}'::jsonb);
    insert into rmvp05_access_results values ('anon', false);
  exception when insufficient_privilege then
    insert into rmvp05_access_results values ('anon', true);
  end;
end $$;
reset role;
set local role service_role;
do $$ begin
  begin
    perform atlas_api.get_confirmed_need_review('{}'::jsonb);
    insert into rmvp05_access_results values ('service_role', false);
  exception when insufficient_privilege then
    insert into rmvp05_access_results values ('service_role', true);
  end;
end $$;
reset role;
select ok((select call_denied from rmvp05_access_results where role_name = 'anon'), 'RMVP05-29 anon execute is revoked');
select ok((select call_denied from rmvp05_access_results where role_name = 'service_role'), 'RMVP05-30 service-role execute is revoked');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'f5000000-0000-0000-0000-000000000101', true);
insert into rmvp05_responses select 'replacement-note-missing', atlas_api.preview_confirmed_need_confirmation(pg_temp.rmvp05_preview(2, pg_temp.rmvp05_single_line(1)));
insert into rmvp05_responses select 'replacement-preview', atlas_api.preview_confirmed_need_confirmation(pg_temp.rmvp05_preview(2, pg_temp.rmvp05_single_line(1, null, 'PROPOSAL_ACCEPTED', 'Confirmed against corrected evidence')));
reset role;
select is((select response->'preview'->>'error_code' from rmvp05_responses where response_name = 'replacement-note-missing'), 'REASON_NOTE_REQUIRED', 'RMVP05-31 replacement decision requires a nonblank correction note');
select ok(
  (select response->'preview'->>'success' = 'true'
    and response->'preview'->'warnings' @> '[{"code":"DECISION_REPLACEMENT"}]'::jsonb
   from rmvp05_responses where response_name = 'replacement-preview'),
  'RMVP05-32 valid replacement preview warns that immutable history will grow'
);
insert into rmvp05_requests
select 'replacement-confirm', pg_temp.rmvp05_confirm(
  'f5000000-0000-0000-0000-000000000043', 'rmvp05-replacement', 2,
  response->'preview'->>'preview_hash', pg_temp.rmvp05_single_line(1, null, 'PROPOSAL_ACCEPTED', 'Confirmed against corrected evidence')
) from rmvp05_responses where response_name = 'replacement-preview';
set local role authenticated;
insert into rmvp05_responses select 'replacement-confirm', atlas_api.confirm_need_quantities(request) from rmvp05_requests where request_name = 'replacement-confirm';
reset role;
select ok((select response->>'success' = 'true' and response->>'new_batch_version' = '3' from rmvp05_responses where response_name = 'replacement-confirm'), 'RMVP05-33 replacement confirmation advances the batch once');
select ok(
  (select count(*) = 1 from atlas_planning.confirmed_need_line_decisions where decision_number = 2 and predecessor_decision_id is not null and confirmed_need_batch_version = 3)
  and (select count(*) = 3 from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id = (select batch_id from rmvp05_context)),
  'RMVP05-34 replacement appends predecessor-linked history without a quantity successor'
);

set local role authenticated;
insert into rmvp05_responses select 'read-final', atlas_api.get_confirmed_need_review(pg_temp.rmvp05_read((select batch_id from rmvp05_context)));
reset role;
select is(
  (select jsonb_agg(jsonb_build_object(
    'theoretical', line->>'theoretical_quantity',
    'proposal', line->>'proposed_confirmed_quantity',
    'confirmed', line->>'confirmed_quantity_after',
    'history', jsonb_array_length(line->'decision_history')
  ) order by line->'ingredient'->>'name')
   from rmvp05_responses r cross join lateral jsonb_array_elements(r.response->'workbench'->'lines') line
   where r.response_name = 'read-final'),
  jsonb_build_array(
    jsonb_build_object('theoretical', '3.000000', 'proposal', '3.250000', 'confirmed', '3.250000', 'history', 1),
    jsonb_build_object('theoretical', '2.000000', 'proposal', '2.000000', 'confirmed', '2.000000', 'history', 2)
  ),
  'RMVP05-35 readback preserves exact decimal strings and complete decision history'
);
select is(
  (select jsonb_build_object(
    'total', response->'workbench'->'line_counts'->>'total',
    'unreviewed', response->'workbench'->'line_counts'->>'unreviewed',
    'confirmed', response->'workbench'->'line_counts'->>'confirmed',
    'adjusted', response->'workbench'->'line_counts'->>'adjusted',
    'version', response->'workbench'->>'batch_version'
  ) from rmvp05_responses where response_name = 'read-final'),
  jsonb_build_object('total', '2', 'unreviewed', '0', 'confirmed', '2', 'adjusted', '1', 'version', '3'),
  'RMVP05-36 authoritative counts and version reflect current decisions'
);
select ok(
  (select response->'workbench'->'allowed_actions'->>'preview_confirmation' = 'true'
    and jsonb_array_length(response->'workbench'->'blockers') = 0
   from rmvp05_responses where response_name = 'read-final'),
  'RMVP05-37 review remains available for governed replacement decisions'
);

select * from finish();
rollback;
