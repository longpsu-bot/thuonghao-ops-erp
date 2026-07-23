-- PA-06E-H0Cb: materialize one exact released Need Generation result into
-- Draft Confirmed Need operational lines, revisions, and contribution membership.
-- This migration adds exactly CMD-15, one private validator, one dedicated
-- runtime, and one capability. It creates no relation, view, trigger, sequence,
-- read API, downstream fact, or production actor/scope seed.

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_roles
    where rolname = 'atlas_planning_materialization_runtime'
  ) then
    create role atlas_planning_materialization_runtime nologin noinherit;
  end if;
end
$$;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values (
  'confirmed_need_generation.materialize',
  'Materialize Confirmed Need from Need Generation',
  'PLANNING',
  'ACTIVE'
);

grant usage on schema atlas_core, atlas_admin, atlas_planning, atlas_audit, atlas_api
  to atlas_planning_materialization_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.customers,
  atlas_admin.schools,
  atlas_admin.school_types,
  atlas_admin.delivery_locations,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions,
  atlas_planning.weekly_menus,
  atlas_planning.weekly_menu_lines,
  atlas_planning.weekly_menu_approval_snapshots,
  atlas_planning.weekly_menu_approval_snapshot_lines,
  atlas_planning.attendance_batches,
  atlas_planning.attendance_lines,
  atlas_planning.attendance_approval_snapshots,
  atlas_planning.attendance_approval_snapshot_lines,
  atlas_planning.planning_input_sets,
  atlas_planning.planning_input_evaluations,
  atlas_planning.planning_input_evaluation_issues,
  atlas_planning.need_generation_calculation_contracts,
  atlas_planning.need_generation_calculation_contract_revisions,
  atlas_planning.need_generation_runs,
  atlas_planning.need_generation_input_snapshots,
  atlas_planning.need_generation_recipe_selections,
  atlas_planning.need_generation_recipe_line_uses,
  atlas_planning.theoretical_need_lines,
  atlas_planning.need_generation_issues,
  atlas_planning.need_generation_release_snapshots,
  atlas_planning.need_generation_release_snapshot_lines,
  atlas_planning.need_generation_release_snapshot_issues,
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_line_revision_contributions
to atlas_planning_materialization_runtime;

-- PostgreSQL row locks require UPDATE privilege. These column grants are only
-- for deterministic source locking; there is deliberately no matching UPDATE
-- RLS policy on immutable/reference rows.
grant update (customer_id) on atlas_admin.customers to atlas_planning_materialization_runtime;
grant update (school_id) on atlas_admin.schools to atlas_planning_materialization_runtime;
grant update (school_type_id) on atlas_admin.school_types to atlas_planning_materialization_runtime;
grant update (delivery_location_id) on atlas_admin.delivery_locations to atlas_planning_materialization_runtime;
grant update (ingredient_id) on atlas_admin.ingredients to atlas_planning_materialization_runtime;
grant update (unit_id) on atlas_admin.units to atlas_planning_materialization_runtime;
grant update (dish_id) on atlas_admin.dishes to atlas_planning_materialization_runtime;
grant update (recipe_id) on atlas_admin.recipes to atlas_planning_materialization_runtime;
grant update (recipe_version_id) on atlas_admin.recipe_versions to atlas_planning_materialization_runtime;
grant update (recipe_line_id) on atlas_admin.recipe_lines to atlas_planning_materialization_runtime;
grant update (recipe_line_revision_id) on atlas_admin.recipe_line_revisions to atlas_planning_materialization_runtime;
grant update (weekly_menu_id) on atlas_planning.weekly_menus to atlas_planning_materialization_runtime;
grant update (weekly_menu_line_id) on atlas_planning.weekly_menu_lines to atlas_planning_materialization_runtime;
grant update (weekly_menu_approval_snapshot_id) on atlas_planning.weekly_menu_approval_snapshots to atlas_planning_materialization_runtime;
grant update (weekly_menu_approval_snapshot_line_id) on atlas_planning.weekly_menu_approval_snapshot_lines to atlas_planning_materialization_runtime;
grant update (attendance_batch_id) on atlas_planning.attendance_batches to atlas_planning_materialization_runtime;
grant update (attendance_line_id) on atlas_planning.attendance_lines to atlas_planning_materialization_runtime;
grant update (attendance_approval_snapshot_id) on atlas_planning.attendance_approval_snapshots to atlas_planning_materialization_runtime;
grant update (attendance_approval_snapshot_line_id) on atlas_planning.attendance_approval_snapshot_lines to atlas_planning_materialization_runtime;
grant update (planning_input_set_id) on atlas_planning.planning_input_sets to atlas_planning_materialization_runtime;
grant update (planning_input_evaluation_id) on atlas_planning.planning_input_evaluations to atlas_planning_materialization_runtime;
grant update (planning_input_readiness_issue_id) on atlas_planning.planning_input_evaluation_issues to atlas_planning_materialization_runtime;
grant update (need_generation_calculation_contract_id) on atlas_planning.need_generation_calculation_contracts to atlas_planning_materialization_runtime;
grant update (need_generation_calculation_contract_revision_id) on atlas_planning.need_generation_calculation_contract_revisions to atlas_planning_materialization_runtime;
grant update (need_generation_run_id) on atlas_planning.need_generation_runs to atlas_planning_materialization_runtime;
grant update (need_generation_input_snapshot_id) on atlas_planning.need_generation_input_snapshots to atlas_planning_materialization_runtime;
grant update (need_generation_recipe_selection_id) on atlas_planning.need_generation_recipe_selections to atlas_planning_materialization_runtime;
grant update (need_generation_recipe_line_use_id) on atlas_planning.need_generation_recipe_line_uses to atlas_planning_materialization_runtime;
grant update (theoretical_need_line_id) on atlas_planning.theoretical_need_lines to atlas_planning_materialization_runtime;
grant update (need_generation_issue_id) on atlas_planning.need_generation_issues to atlas_planning_materialization_runtime;
grant update (need_generation_release_snapshot_id) on atlas_planning.need_generation_release_snapshots to atlas_planning_materialization_runtime;
grant update (need_generation_release_snapshot_line_id) on atlas_planning.need_generation_release_snapshot_lines to atlas_planning_materialization_runtime;
grant update (need_generation_release_snapshot_issue_id) on atlas_planning.need_generation_release_snapshot_issues to atlas_planning_materialization_runtime;
grant update (confirmed_need_line_id) on atlas_planning.confirmed_need_lines to atlas_planning_materialization_runtime;

grant insert, update on atlas_core.command_receipts
  to atlas_planning_materialization_runtime;
grant insert on
  atlas_planning.confirmed_need_batches,
  atlas_planning.confirmed_need_lines,
  atlas_planning.confirmed_need_line_revisions,
  atlas_planning.confirmed_need_line_revision_contributions,
  atlas_audit.domain_events,
  atlas_audit.audit_events
to atlas_planning_materialization_runtime;
grant update (
  current_need_generation_run_id,
  current_need_generation_run_version,
  current_need_generation_release_snapshot_id,
  version,
  updated_at
) on atlas_planning.confirmed_need_batches to atlas_planning_materialization_runtime;
grant update (revision_status, is_current)
  on atlas_planning.confirmed_need_line_revisions
  to atlas_planning_materialization_runtime;
grant select (domain_event_id) on atlas_audit.domain_events
  to atlas_planning_materialization_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
  to atlas_planning_materialization_runtime;

-- Core authorization and receipt policies.
create policy pa_06e_h0cb_materialization_select on atlas_core.actors
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_core.actor_auth_subjects
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_core.roles
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_core.capabilities
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_core.role_capabilities
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_core.actor_role_memberships
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_core.actor_scopes
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_receipt_select on atlas_core.command_receipts
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_receipt_insert on atlas_core.command_receipts
  for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_receipt_update on atlas_core.command_receipts
  for update to atlas_planning_materialization_runtime using (true) with check (true);

-- Read-only Admin evidence.
create policy pa_06e_h0cb_materialization_select on atlas_admin.customers
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.schools
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.school_types
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.delivery_locations
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.ingredients
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.units
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.dishes
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.recipes
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.recipe_versions
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.recipe_lines
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_admin.recipe_line_revisions
  for select to atlas_planning_materialization_runtime using (true);

-- Read-only Menu, Attendance, readiness, and Need Generation evidence.
create policy pa_06e_h0cb_materialization_select on atlas_planning.weekly_menus for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.weekly_menu_lines for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.weekly_menu_approval_snapshots for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.weekly_menu_approval_snapshot_lines for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.attendance_batches for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.attendance_lines for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.attendance_approval_snapshots for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.attendance_approval_snapshot_lines for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.planning_input_sets for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.planning_input_evaluations for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.planning_input_evaluation_issues for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_calculation_contracts for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_calculation_contract_revisions for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_runs for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_input_snapshots for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_recipe_selections for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_recipe_line_uses for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.theoretical_need_lines for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_issues for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_release_snapshots for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_release_snapshot_lines for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.need_generation_release_snapshot_issues for select to atlas_planning_materialization_runtime using (true);

-- Confirmed Need destination and downstream-read policies.
create policy pa_06e_h0cb_materialization_select on atlas_planning.confirmed_need_batches
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_insert on atlas_planning.confirmed_need_batches
  for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_update on atlas_planning.confirmed_need_batches
  for update to atlas_planning_materialization_runtime using (true) with check (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.confirmed_need_lines
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_insert on atlas_planning.confirmed_need_lines
  for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_select on atlas_planning.confirmed_need_line_revisions
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_insert on atlas_planning.confirmed_need_line_revisions
  for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_update on atlas_planning.confirmed_need_line_revisions
  for update to atlas_planning_materialization_runtime using (true) with check (true);
create policy pa_06e_h0cb_contribution_select on atlas_planning.confirmed_need_line_revision_contributions
  as permissive for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_contribution_insert on atlas_planning.confirmed_need_line_revision_contributions
  as permissive for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_audit_insert on atlas_audit.domain_events
  for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_audit_select on atlas_audit.domain_events
  for select to atlas_planning_materialization_runtime using (true);
create policy pa_06e_h0cb_materialization_audit_insert on atlas_audit.audit_events
  for insert to atlas_planning_materialization_runtime with check (true);
create policy pa_06e_h0cb_materialization_audit_select on atlas_audit.audit_events
  for select to atlas_planning_materialization_runtime using (true);

create function atlas_core.pa_06e_h0cb_validate_materialization_request(request jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_requested_at timestamptz;
  v_expected_version bigint;
  v_run_version bigint;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The command request must be a JSON object.',
      'PLANNING',
      'create_confirmed_needs_from_generation',
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'request', 'message', 'A JSON object is required.')
      )
    );
  end if;

  if request - array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ] <> '{}'::jsonb then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'request', 'message', 'Unknown command envelope fields are not accepted.')
    );
  end if;
  if not (request ?& array[
    'contract_version', 'command_id', 'correlation_id', 'idempotency_key',
    'expected_version', 'requested_by_auth_subject', 'requested_at',
    'reason_code', 'reason_note', 'payload'
  ]) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'request', 'message', 'The complete Atlas command envelope is required.')
    );
  end if;
  if request ->> 'contract_version' is distinct from 'PA-06E-H0C.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'contract_version', 'message', 'Use PA-06E-H0C.v1.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'command_id', 'message', 'A valid UUID is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'correlation_id', 'message', 'A valid UUID is required.')
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'idempotency_key', 'message', 'A non-empty key of at most 200 characters is required.')
    );
  end if;
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  if v_expected_version is null or v_expected_version <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'expected_version', 'message', 'A positive integer version is required.')
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_by_auth_subject', 'message', 'A valid UUID is required.')
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
  if v_requested_at is null or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'requested_at', 'message', 'A valid non-future timestamp is required.')
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_code', 'message', 'A reason code is required.')
    );
  end if;
  if not (request ? 'reason_note')
     or (request -> 'reason_note' <> 'null'::jsonb and pg_catalog.jsonb_typeof(request -> 'reason_note') <> 'string') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'reason_note', 'message', 'The reason_note field is required and may be null or text.')
    );
  end if;

  if request -> 'payload' is null or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object('field', 'payload', 'message', 'A JSON object is required.')
    );
  else
    v_payload := request -> 'payload';
    if not (v_payload ?& array[
      'need_generation_run_id', 'need_generation_run_version', 'confirmed_need_batch_id'
    ]) or v_payload - array[
      'need_generation_run_id', 'need_generation_run_version', 'confirmed_need_batch_id'
    ] <> '{}'::jsonb then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload', 'message', 'Provide exactly the run ID, run version, and nullable Confirmed Need batch ID.')
      );
    end if;
    if atlas_core.pa_05b_safe_uuid(v_payload ->> 'need_generation_run_id') is null then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.need_generation_run_id', 'message', 'A valid UUID is required.')
      );
    end if;
    v_run_version := atlas_core.pa_05b_safe_bigint(v_payload ->> 'need_generation_run_version');
    if v_run_version is null or v_run_version <= 0 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.need_generation_run_version', 'message', 'A positive released run version is required.')
      );
    end if;
    if v_payload -> 'confirmed_need_batch_id' <> 'null'::jsonb
       and (
         pg_catalog.jsonb_typeof(v_payload -> 'confirmed_need_batch_id') <> 'string'
         or atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id') is null
       ) then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'payload.confirmed_need_batch_id', 'message', 'Use null for initial materialization or one valid batch UUID for correction.')
      );
    end if;
    if v_payload -> 'confirmed_need_batch_id' = 'null'::jsonb
       and v_expected_version is distinct from 1 then
      v_errors := v_errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('field', 'expected_version', 'message', 'Initial materialization uses expected_version 1.')
      );
    end if;
  end if;

  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The materialization request is invalid.',
      'PLANNING',
      'create_confirmed_needs_from_generation',
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create function atlas_api.create_confirmed_needs_from_generation(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'create_confirmed_needs_from_generation';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_begin jsonb;
  v_receipt_id uuid;
  v_run_id uuid;
  v_run_version bigint;
  v_batch_id uuid;
  v_expected_version bigint;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_old_run atlas_planning.need_generation_runs%rowtype;
  v_release atlas_planning.need_generation_release_snapshots%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_initial boolean;
  v_active_count integer := 0;
  v_school_count integer := 0;
  v_group_count integer := 0;
  v_release_member_count integer := 0;
  v_created_line_count integer := 0;
  v_reused_line_count integer := 0;
  v_retired_line_count integer := 0;
  v_created_revision_count integer := 0;
  v_created_contribution_count integer := 0;
  v_current_revision_count integer := 0;
  v_superseded_revision_count integer := 0;
  v_old_current_count integer := 0;
  v_reused_old_count integer := 0;
  v_batch_version_before bigint;
  v_batch_version_after bigint;
  v_event_type text;
  v_domain_event_id uuid;
  v_audit_event_id uuid;
  v_counts jsonb;
  v_response jsonb;
begin
  v_error := atlas_core.pa_06e_h0cb_validate_materialization_request(request);
  if v_error is not null then return v_error; end if;

  v_run_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'need_generation_run_id');
  v_run_version := atlas_core.pa_05b_safe_bigint(v_payload ->> 'need_generation_run_version');
  v_batch_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id');
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  v_initial := v_batch_id is null;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  if v_actor_context ->> 'actor_type' <> 'HUMAN' then
    return atlas_core.pa_05b_command_error(
      request, 'DELEGATION_NOT_SUPPORTED',
      'Only an active authenticated human actor may materialize Confirmed Need.',
      'PLANNING', v_command_name
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select source_run.* into v_run
  from atlas_planning.need_generation_runs source_run
  where source_run.need_generation_run_id = v_run_id;
  if not found or v_run.run_status <> 'RELEASED_FOR_CONFIRMATION' then
    return atlas_core.pa_05b_command_error(
      request, 'GENERATION_NOT_RELEASED',
      'The requested Need Generation run is not released for confirmation.',
      'PLANNING', v_command_name
    );
  end if;
  if v_run.version <> v_run_version then
    return atlas_core.pa_05b_command_error(
      request, 'SOURCE_REVISION_STALE',
      'The requested Need Generation run version is stale.',
      'PLANNING', v_command_name, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
  end if;

  select release_snapshot.* into v_release
  from atlas_planning.need_generation_release_snapshots release_snapshot
  where release_snapshot.need_generation_run_id = v_run_id;
  if not found or v_release.released_run_version <> v_run_version then
    return atlas_core.pa_05b_command_error(
      request, 'GENERATION_NOT_RELEASED',
      'The exact immutable Need Generation release snapshot is unavailable.',
      'PLANNING', v_command_name
    );
  end if;

  if not v_initial then
    select target_batch.* into v_batch
    from atlas_planning.confirmed_need_batches target_batch
    where target_batch.confirmed_need_batch_id = v_batch_id;
    if not found or v_batch.source_kind <> 'NEED_GENERATION' then
      return atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED',
        'The requested Confirmed Need batch could not be validated.',
        'PLANNING', v_command_name
      );
    end if;
  end if;

  -- Reuse the common helper for capability and ordinary scope semantics. A
  -- SCOPE_DENIED result is refined below against the complete H0C four-kind
  -- scope set, including SCHOOL, which predates no generic PA-05B parameter.
  v_authorization_error := atlas_core.pa_05b_authorize_actor(
    request, v_actor_id, 'confirmed_need_generation.materialize',
    'PLANNING', v_command_name, null, null, null
  );
  if v_authorization_error is not null
     and v_authorization_error ->> 'error_code' <> 'SCOPE_DENIED' then
    return v_authorization_error;
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and not exists (
        select 1
        from atlas_core.actor_scopes scope
        where scope.actor_id = v_actor_id
          and scope.scope_status = 'ACTIVE'
          and scope.effective_from <= pg_catalog.transaction_timestamp()
          and (scope.effective_to is null or scope.effective_to > pg_catalog.transaction_timestamp())
          and (
            scope.scope_kind = 'GLOBAL'
            or (scope.scope_kind = 'CUSTOMER' and scope.customer_id = school.customer_id)
            or (scope.scope_kind = 'SCHOOL' and scope.school_id = school.school_id)
            or (
              scope.scope_kind = 'DELIVERY_LOCATION'
              and scope.delivery_location_id = coalesce(
                old_contribution.delivery_location_id,
                school.default_delivery_location_id
              )
            )
          )
      )
  ) then
    return atlas_core.pa_05b_command_error(
      request, 'SCOPE_DENIED',
      'The actor does not cover the complete released contribution set.',
      'PLANNING', v_command_name
    );
  end if;

  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    v_command_name,
    'PLANNING',
    case when v_initial
      then 'need-generation-run:' || v_run_id::text
      else 'confirmed-need-batch:' || v_batch_id::text
    end
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform pg_catalog.set_config('lock_timeout', '5s', true);
  perform pg_catalog.set_config('statement_timeout', '120s', true);

  -- Admin reference locks, always UUID ordered.
  perform 1
  from atlas_admin.customers customer
  where customer.customer_id in (
    select school.customer_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  )
  order by customer.customer_id for key share;
  perform 1
  from atlas_admin.schools school
  where school.school_id in (
    select theoretical.school_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  )
  order by school.school_id for key share;
  perform 1
  from atlas_admin.delivery_locations location
  where location.delivery_location_id in (
    select school.default_delivery_location_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    union
    select contribution.delivery_location_id
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
    where not v_initial
      and contribution.confirmed_need_batch_id = v_batch_id
      and revision.is_current
  )
  order by location.delivery_location_id for key share;
  perform 1
  from atlas_admin.ingredients ingredient
  where ingredient.ingredient_id in (
    select theoretical.ingredient_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ) order by ingredient.ingredient_id for key share;
  perform 1
  from atlas_admin.units unit_record
  where unit_record.unit_id in (
    select theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ) order by unit_record.unit_id for key share;

  -- Typed Recipe/source evidence precedes mutable Planning aggregate locks.
  perform 1 from atlas_planning.need_generation_input_snapshots snapshot
    where snapshot.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by snapshot.need_generation_input_snapshot_id for key share;
  perform 1 from atlas_planning.need_generation_recipe_selections selection
    where selection.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by selection.need_generation_recipe_selection_id for key share;
  perform 1 from atlas_planning.need_generation_recipe_line_uses recipe_use
    where recipe_use.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by recipe_use.need_generation_recipe_line_use_id for key share;

  perform 1 from atlas_planning.planning_input_sets input_set
    where input_set.planning_input_set_id = v_run.planning_input_set_id for key share;
  perform 1 from atlas_planning.planning_input_evaluations evaluation
    where evaluation.planning_input_set_id = v_run.planning_input_set_id
    order by evaluation.planning_input_evaluation_id for key share;
  perform 1 from atlas_planning.need_generation_runs source_run
    where source_run.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by source_run.need_generation_run_id for update;
  perform 1 from atlas_planning.need_generation_release_snapshots release_snapshot
    where release_snapshot.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by release_snapshot.need_generation_release_snapshot_id for key share;
  perform 1 from atlas_planning.need_generation_release_snapshot_lines release_line
    where release_line.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by release_line.need_generation_release_snapshot_line_id for key share;
  perform 1 from atlas_planning.theoretical_need_lines theoretical
    where theoretical.need_generation_run_id in (
      select candidate from pg_catalog.unnest(array_remove(array[v_run_id, v_batch.current_need_generation_run_id], null)) candidate
    ) order by theoretical.theoretical_need_line_id for key share;

  if not v_initial then
    perform 1 from atlas_planning.confirmed_need_batches target_batch
      where target_batch.confirmed_need_batch_id = v_batch_id for update;
    perform 1 from atlas_planning.confirmed_need_lines target_line
      where target_line.confirmed_need_batch_id = v_batch_id
      order by target_line.confirmed_need_line_id for key share;
    perform 1 from atlas_planning.confirmed_need_line_revisions target_revision
      where target_revision.confirmed_need_batch_id = v_batch_id and target_revision.is_current
      order by target_revision.confirmed_need_line_revision_id for update;
  end if;

  -- Reread authoritative state after the deterministic lock set.
  select source_run.* into v_run
  from atlas_planning.need_generation_runs source_run
  where source_run.need_generation_run_id = v_run_id;
  select release_snapshot.* into v_release
  from atlas_planning.need_generation_release_snapshots release_snapshot
  where release_snapshot.need_generation_run_id = v_run_id;
  if v_run.run_status <> 'RELEASED_FOR_CONFIRMATION'
     or v_run.version <> v_run_version
     or v_release.released_run_version <> v_run_version
     or v_release.need_generation_input_snapshot_id <> v_run.input_snapshot_id then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_REVISION_STALE',
      'The released Need Generation source changed before materialization.',
      'PLANNING', v_command_name, false, '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_release_member_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
  select count(*)::integer into v_active_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    and theoretical.line_disposition = 'ACTIVE';

  if not exists (
    select 1 from atlas_planning.need_generation_input_snapshots snapshot
    where snapshot.need_generation_input_snapshot_id = v_run.input_snapshot_id
      and snapshot.need_generation_run_id = v_run_id
  ) or exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    left join atlas_planning.need_generation_recipe_selections selection
      on selection.need_generation_recipe_selection_id = theoretical.need_generation_recipe_selection_id
     and selection.need_generation_run_id = theoretical.need_generation_run_id
    left join atlas_planning.need_generation_recipe_line_uses recipe_use
      on recipe_use.need_generation_recipe_line_use_id = theoretical.need_generation_recipe_line_use_id
     and recipe_use.need_generation_run_id = theoretical.need_generation_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and (selection.need_generation_recipe_selection_id is null or recipe_use.need_generation_recipe_line_use_id is null)
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_LINEAGE_INCOMPLETE',
      'The released source does not retain its complete typed input and Recipe lineage.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_release_member_count <> v_release.generated_line_count
     or v_active_count <> v_release.active_line_count
     or v_release.generated_line_count <> v_release.active_line_count + v_release.removed_line_count then
    v_error := atlas_core.pa_05b_command_error(
      request, 'CONTRIBUTION_MEMBERSHIP_INVALID',
      'The immutable release membership does not match its released counts.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_active_count = 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'EMPTY_ACTIVE_RELEASE',
      'The released Need Generation result has no active contribution.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity = 0
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED',
      'An active released contribution has zero quantity.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if exists (
    select 1
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    left join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_admin.customers customer on customer.customer_id = school.customer_id
    left join atlas_admin.delivery_locations location
      on location.delivery_location_id = school.default_delivery_location_id
     and location.customer_id = school.customer_id
    left join atlas_admin.ingredients ingredient on ingredient.ingredient_id = theoretical.ingredient_id
    left join atlas_admin.units unit_record on unit_record.unit_id = theoretical.unit_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and (
        theoretical.service_date < v_run.period_start
        or theoretical.service_date > v_run.period_end
        or school.school_status is distinct from 'ACTIVE'
        or school.customer_type is distinct from 'SCHOOL_CATERING'
        or customer.customer_type is distinct from 'SCHOOL_CATERING'
        or customer.customer_status is distinct from 'ACTIVE'
        or location.location_status is distinct from 'ACTIVE'
        or ingredient.ingredient_status is distinct from 'ACTIVE'
        or unit_record.unit_status is distinct from 'ACTIVE'
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_MAPPING_INCOMPLETE',
      'The released contribution set has an inactive or inconsistent operational reference.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(distinct theoretical.school_id)::integer into v_school_count
  from atlas_planning.need_generation_release_snapshot_lines release_line
  join atlas_planning.theoretical_need_lines theoretical
    on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
  where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    and theoretical.line_disposition = 'ACTIVE';

  select count(*)::integer into v_group_count
  from (
    select theoretical.service_date, school.customer_id, theoretical.school_id,
           coalesce(old_contribution.delivery_location_id, school.default_delivery_location_id) delivery_location_id,
           theoretical.ingredient_id, theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
     and exists (
       select 1 from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             coalesce(old_contribution.delivery_location_id, school.default_delivery_location_id),
             theoretical.ingredient_id, theoretical.unit_id
  ) grouped;

  if (v_run.period_end - v_run.period_start + 1) > 14
     or v_school_count > 500
     or v_active_count > 25000
     or v_group_count > 15000 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'MATERIALIZATION_LIMIT_EXCEEDED',
      'The released result exceeds a bounded materialization limit.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_initial then
    if exists (
      select 1 from atlas_planning.confirmed_need_batches existing_batch
      where existing_batch.source_kind = 'NEED_GENERATION'
        and existing_batch.origin_need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'This released Need Generation result already has a Confirmed Need batch.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    insert into atlas_planning.confirmed_need_batches (
      wholesale_order_id,
      period_start,
      period_end,
      batch_status,
      version,
      created_by_actor_id,
      source_kind,
      origin_need_generation_run_id,
      origin_need_generation_run_version,
      origin_need_generation_release_snapshot_id,
      current_need_generation_run_id,
      current_need_generation_run_version,
      current_need_generation_release_snapshot_id
    ) values (
      null,
      v_run.period_start,
      v_run.period_end,
      'DRAFT_REVIEW',
      1,
      v_actor_id,
      'NEED_GENERATION',
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id
    ) returning confirmed_need_batch_id into v_batch_id;

    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id,
      wholesale_order_line_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      controlled_unit_id
    )
    select
      v_batch_id,
      null,
      'NEED_GENERATION',
      theoretical.service_date,
      school.customer_id,
      theoretical.school_id,
      school.default_delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             school.default_delivery_location_id, theoretical.ingredient_id, theoretical.unit_id;
    get diagnostics v_created_line_count = row_count;

    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id,
      revision_number,
      wholesale_order_line_revision_id,
      ingredient_id,
      theoretical_quantity,
      confirmed_quantity,
      unit_id,
      revision_status,
      is_current,
      predecessor_revision_id,
      command_id,
      created_by_actor_id,
      source_kind,
      confirmed_need_batch_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id
    )
    select
      target_line.confirmed_need_line_id,
      1,
      null,
      target_line.ingredient_id,
      sum(theoretical.theoretical_quantity),
      sum(theoretical.theoretical_quantity),
      target_line.controlled_unit_id,
      'DRAFT',
      true,
      null,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id,
      'NEED_GENERATION',
      v_batch_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      target_line.service_date,
      target_line.customer_id,
      target_line.school_id,
      target_line.delivery_location_id
    from atlas_planning.confirmed_need_lines target_line
    join atlas_planning.need_generation_release_snapshot_lines release_line
      on release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
     and theoretical.service_date = target_line.service_date
     and theoretical.school_id = target_line.school_id
     and theoretical.ingredient_id = target_line.ingredient_id
     and theoretical.unit_id = target_line.controlled_unit_id
    where target_line.confirmed_need_batch_id = v_batch_id
      and target_line.source_kind = 'NEED_GENERATION'
    group by target_line.confirmed_need_line_id, target_line.ingredient_id,
             target_line.controlled_unit_id, target_line.service_date,
             target_line.customer_id, target_line.school_id, target_line.delivery_location_id;
    get diagnostics v_created_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revision_contributions (
      confirmed_need_batch_id,
      confirmed_need_line_id,
      confirmed_need_line_revision_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      need_generation_release_snapshot_line_id,
      theoretical_need_line_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      source_unit_id,
      controlled_unit_id,
      source_theoretical_quantity,
      controlled_contribution_quantity
    )
    select
      v_batch_id,
      target_line.confirmed_need_line_id,
      target_revision.confirmed_need_line_revision_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      release_line.need_generation_release_snapshot_line_id,
      theoretical.theoretical_need_line_id,
      theoretical.service_date,
      target_line.customer_id,
      theoretical.school_id,
      target_line.delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id,
      target_line.controlled_unit_id,
      theoretical.theoretical_quantity,
      theoretical.theoretical_quantity
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.source_kind = 'NEED_GENERATION'
     and target_line.service_date = theoretical.service_date
     and target_line.school_id = theoretical.school_id
     and target_line.ingredient_id = theoretical.ingredient_id
     and target_line.controlled_unit_id = theoretical.unit_id
    join atlas_planning.confirmed_need_line_revisions target_revision
      on target_revision.confirmed_need_line_id = target_line.confirmed_need_line_id
     and target_revision.is_current
     and target_revision.need_generation_run_id = v_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
    get diagnostics v_created_contribution_count = row_count;

    v_reused_line_count := 0;
    v_retired_line_count := 0;
    v_current_revision_count := v_created_revision_count;
    v_superseded_revision_count := 0;
    v_batch_version_before := null;
    v_batch_version_after := 1;
    v_event_type := 'ConfirmedNeedsCreated';
  else
    select target_batch.* into v_batch
    from atlas_planning.confirmed_need_batches target_batch
    where target_batch.confirmed_need_batch_id = v_batch_id;

    if v_batch.version <> v_expected_version then
      v_error := atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The Confirmed Need batch changed. Refresh before rematerialization.',
        'PLANNING', v_command_name, false, '[]'::jsonb,
        pg_catalog.jsonb_build_array(v_batch_id), v_batch.version
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF' then
      v_error := atlas_core.pa_05b_command_error(
        request, 'DOWNSTREAM_CORRECTION_REQUIRED',
        'Released Confirmed Need requires an explicit downstream correction policy.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then
      v_error := atlas_core.pa_05b_command_error(
        request, 'REOPEN_REQUIRED',
        'The Confirmed Need batch must be explicitly reopened before rematerialization.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    select prior_run.* into v_old_run
    from atlas_planning.need_generation_runs prior_run
    where prior_run.need_generation_run_id = v_batch.current_need_generation_run_id;
    if not found
       or v_batch.current_need_generation_run_version <> v_old_run.version
       or not exists (
         select 1 from atlas_planning.need_generation_release_snapshots old_release
         where old_release.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
           and old_release.need_generation_run_id = v_old_run.need_generation_run_id
           and old_release.released_run_version = v_old_run.version
       ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REVISION_STALE',
        'The Confirmed Need batch current source is stale.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;
    if v_run.predecessor_need_generation_run_id is distinct from v_old_run.need_generation_run_id
       or v_run.planning_input_set_id <> v_old_run.planning_input_set_id
       or v_run.period_start <> v_old_run.period_start
       or v_run.period_end <> v_old_run.period_end
       or v_batch.period_start <> v_run.period_start
       or v_batch.period_end <> v_run.period_end then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SUCCESSOR_AMBIGUOUS',
        'The requested run is not the exact direct released successor of the batch current source.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines new_theoretical
        on new_theoretical.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
       and old_revision.is_current
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and new_theoretical.line_disposition = 'ACTIVE'
        and new_theoretical.predecessor_theoretical_need_line_id is not null
        and (
          new_theoretical.predecessor_need_generation_run_id <> v_old_run.need_generation_run_id
          or old_contribution.confirmed_need_line_revision_contribution_id is null
          or old_revision.confirmed_need_line_revision_id is null
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_MAPPING_INCOMPLETE',
        'A successor contribution is not mapped to exactly one prior current contribution.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select old_contribution.theoretical_need_line_id
      from atlas_planning.confirmed_need_line_revision_contributions old_contribution
      join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
      left join atlas_planning.theoretical_need_lines successor
        on successor.predecessor_theoretical_need_line_id = old_contribution.theoretical_need_line_id
       and successor.need_generation_run_id = v_run_id
      left join atlas_planning.need_generation_release_snapshot_lines successor_member
        on successor_member.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
       and successor_member.theoretical_need_line_id = successor.theoretical_need_line_id
      where old_contribution.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
      group by old_contribution.theoretical_need_line_id
      having count(successor_member.need_generation_release_snapshot_line_id)
               filter (where successor.line_disposition = 'ACTIVE') <> 1
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REMOVAL_POLICY_REQUIRED',
        'A prior contribution is removed without an accepted one-to-one Ingredient move.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines successor
        on successor.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and (
          successor.service_date <> old_contribution.service_date
          or successor.school_id <> old_contribution.school_id
          or successor.unit_id <> old_contribution.source_unit_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SPLIT_MERGE_POLICY_REQUIRED',
        'The successor changes an operational fact other than the accepted one-to-one Ingredient correction.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.need_generation_release_snapshot_lines new_release_line
      join atlas_planning.theoretical_need_lines successor
        on successor.theoretical_need_line_id = new_release_line.theoretical_need_line_id
      join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = successor.school_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and school.default_delivery_location_id <> old_contribution.delivery_location_id
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'OPERATIONAL_IDENTITY_UNAPPROVED',
        'A School default destination changed for an existing contribution.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    select count(*)::integer into v_old_current_count
    from atlas_planning.confirmed_need_line_revisions old_revision
    where old_revision.confirmed_need_batch_id = v_batch_id
      and old_revision.is_current;
    if v_old_current_count = 0 or exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions old_revision
      where old_revision.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
        and row(
          old_revision.need_generation_run_id,
          old_revision.need_generation_run_version,
          old_revision.need_generation_release_snapshot_id
        ) is distinct from row(
          v_batch.current_need_generation_run_id,
          v_batch.current_need_generation_run_version,
          v_batch.current_need_generation_release_snapshot_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'CONTRIBUTION_MEMBERSHIP_INVALID',
        'The current Confirmed Need revision partition is incomplete or stale.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    if exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions old_revision
      where old_revision.confirmed_need_batch_id = v_batch_id
        and old_revision.is_current
        and old_revision.theoretical_quantity is distinct from (
          select sum(old_contribution.controlled_contribution_quantity)
          from atlas_planning.confirmed_need_line_revision_contributions old_contribution
          where old_contribution.confirmed_need_line_revision_id = old_revision.confirmed_need_line_revision_id
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'CONTRIBUTION_TOTAL_MISMATCH',
        'A current Confirmed Need revision does not equal its complete contribution membership.',
        'PLANNING', v_command_name
      );
      return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
    end if;

    -- Add only genuinely absent stable identities; exact identities are reused.
    insert into atlas_planning.confirmed_need_lines (
      confirmed_need_batch_id,
      wholesale_order_line_id,
      source_kind,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      controlled_unit_id
    )
    select
      v_batch_id,
      null,
      'NEED_GENERATION',
      grouped.service_date,
      grouped.customer_id,
      grouped.school_id,
      grouped.delivery_location_id,
      grouped.ingredient_id,
      grouped.unit_id
    from (
      select theoretical.service_date, school.customer_id, theoretical.school_id,
             coalesce(old_contribution.delivery_location_id, school.default_delivery_location_id) delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               coalesce(old_contribution.delivery_location_id, school.default_delivery_location_id),
               theoretical.ingredient_id, theoretical.unit_id
    ) grouped
    where not exists (
      select 1 from atlas_planning.confirmed_need_lines existing_line
      where existing_line.confirmed_need_batch_id = v_batch_id
        and existing_line.source_kind = 'NEED_GENERATION'
        and existing_line.service_date = grouped.service_date
        and existing_line.customer_id = grouped.customer_id
        and existing_line.school_id = grouped.school_id
        and existing_line.delivery_location_id = grouped.delivery_location_id
        and existing_line.ingredient_id = grouped.ingredient_id
        and existing_line.controlled_unit_id = grouped.unit_id
    );
    get diagnostics v_created_line_count = row_count;
    v_reused_line_count := v_group_count - v_created_line_count;

    update atlas_planning.confirmed_need_line_revisions old_revision
    set revision_status = 'SUPERSEDED', is_current = false
    where old_revision.confirmed_need_batch_id = v_batch_id
      and old_revision.is_current;
    get diagnostics v_superseded_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id,
      revision_number,
      wholesale_order_line_revision_id,
      ingredient_id,
      theoretical_quantity,
      confirmed_quantity,
      unit_id,
      revision_status,
      is_current,
      predecessor_revision_id,
      command_id,
      created_by_actor_id,
      source_kind,
      confirmed_need_batch_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id
    )
    select
      target_line.confirmed_need_line_id,
      coalesce(prior_revision.revision_number + 1, 1),
      null,
      target_line.ingredient_id,
      grouped.theoretical_total,
      grouped.theoretical_total,
      target_line.controlled_unit_id,
      'DRAFT',
      true,
      prior_revision.confirmed_need_line_revision_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id,
      'NEED_GENERATION',
      v_batch_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      target_line.service_date,
      target_line.customer_id,
      target_line.school_id,
      target_line.delivery_location_id
    from (
      select theoretical.service_date, school.customer_id, theoretical.school_id,
             coalesce(old_contribution.delivery_location_id, school.default_delivery_location_id) delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id,
             sum(theoretical.theoretical_quantity) theoretical_total
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               coalesce(old_contribution.delivery_location_id, school.default_delivery_location_id),
               theoretical.ingredient_id, theoretical.unit_id
    ) grouped
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = grouped.service_date
     and target_line.customer_id = grouped.customer_id
     and target_line.school_id = grouped.school_id
     and target_line.delivery_location_id = grouped.delivery_location_id
     and target_line.ingredient_id = grouped.ingredient_id
     and target_line.controlled_unit_id = grouped.unit_id
    left join lateral (
      select prior.confirmed_need_line_revision_id, prior.revision_number
      from atlas_planning.confirmed_need_line_revisions prior
      where prior.confirmed_need_line_id = target_line.confirmed_need_line_id
      order by prior.revision_number desc
      limit 1
    ) prior_revision on true;
    get diagnostics v_created_revision_count = row_count;

    insert into atlas_planning.confirmed_need_line_revision_contributions (
      confirmed_need_batch_id,
      confirmed_need_line_id,
      confirmed_need_line_revision_id,
      need_generation_run_id,
      need_generation_run_version,
      need_generation_release_snapshot_id,
      need_generation_release_snapshot_line_id,
      theoretical_need_line_id,
      service_date,
      customer_id,
      school_id,
      delivery_location_id,
      ingredient_id,
      source_unit_id,
      controlled_unit_id,
      source_theoretical_quantity,
      controlled_contribution_quantity
    )
    select
      v_batch_id,
      target_line.confirmed_need_line_id,
      target_revision.confirmed_need_line_revision_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      release_line.need_generation_release_snapshot_line_id,
      theoretical.theoretical_need_line_id,
      theoretical.service_date,
      target_line.customer_id,
      theoretical.school_id,
      target_line.delivery_location_id,
      theoretical.ingredient_id,
      theoretical.unit_id,
      target_line.controlled_unit_id,
      theoretical.theoretical_quantity,
      theoretical.theoretical_quantity
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = theoretical.service_date
     and target_line.customer_id = school.customer_id
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = coalesce(
       old_contribution.delivery_location_id,
       school.default_delivery_location_id
     )
     and target_line.ingredient_id = theoretical.ingredient_id
     and target_line.controlled_unit_id = theoretical.unit_id
    join atlas_planning.confirmed_need_line_revisions target_revision
      on target_revision.confirmed_need_line_id = target_line.confirmed_need_line_id
     and target_revision.is_current
     and target_revision.need_generation_run_id = v_run_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id;
    get diagnostics v_created_contribution_count = row_count;

    select count(*)::integer into v_reused_old_count
    from atlas_planning.confirmed_need_line_revisions current_revision
    join atlas_planning.confirmed_need_line_revisions prior_revision
      on prior_revision.confirmed_need_line_revision_id = current_revision.predecessor_revision_id
    where current_revision.confirmed_need_batch_id = v_batch_id
      and current_revision.is_current
      and current_revision.need_generation_run_id = v_run_id
      and prior_revision.need_generation_run_id = v_old_run.need_generation_run_id;
    v_retired_line_count := v_old_current_count - v_reused_old_count;
    v_current_revision_count := v_created_revision_count;
    v_batch_version_before := v_batch.version;
    v_batch_version_after := v_batch.version + 1;
    v_event_type := 'ConfirmedNeedsRematerialized';

    update atlas_planning.confirmed_need_batches target_batch
    set current_need_generation_run_id = v_run_id,
        current_need_generation_run_version = v_run_version,
        current_need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id,
        version = v_batch_version_after,
        updated_at = pg_catalog.transaction_timestamp()
    where target_batch.confirmed_need_batch_id = v_batch_id;
  end if;

  v_counts := pg_catalog.jsonb_build_object(
    'created_confirmed_need_line_count', v_created_line_count,
    'reused_confirmed_need_line_count', v_reused_line_count,
    'retired_confirmed_need_line_count', v_retired_line_count,
    'created_line_revision_count', v_created_revision_count,
    'created_revision_contribution_count', v_created_contribution_count,
    'current_line_revision_count', v_current_revision_count,
    'superseded_line_revision_count', v_superseded_revision_count
  );

  insert into atlas_audit.domain_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    occurred_at,
    payload_summary
  ) values (
    v_event_type,
    'PLANNING',
    'ConfirmedNeedBatch',
    v_batch_id,
    v_batch_version_after,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    pg_catalog.transaction_timestamp(),
    pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'need_generation_run_version', v_run_version,
      'need_generation_release_snapshot_id', v_release.need_generation_release_snapshot_id,
      'service_period', pg_catalog.jsonb_build_object(
        'period_start', v_run.period_start,
        'period_end', v_run.period_end
      ),
      'result_counts', v_counts
    )
  ) returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version_before,
    aggregate_version_after,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    reason_code,
    reason_note,
    before_summary,
    after_summary,
    source_interface,
    occurred_at
  ) values (
    v_event_type,
    'PLANNING',
    'ConfirmedNeedBatch',
    v_batch_id,
    v_batch_version_before,
    v_batch_version_after,
    v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    pg_catalog.jsonb_build_object(
      'batch_status', case when v_initial then null else v_batch.batch_status end,
      'version', v_batch_version_before,
      'current_source', case when v_initial then null else pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_batch.current_need_generation_run_id,
        'need_generation_run_version', v_batch.current_need_generation_run_version,
        'need_generation_release_snapshot_id', v_batch.current_need_generation_release_snapshot_id
      ) end,
      'result_counts', case when v_initial then null else pg_catalog.jsonb_build_object(
        'current_line_revision_count', v_old_current_count
      ) end
    ),
    pg_catalog.jsonb_build_object(
      'batch_status', 'DRAFT_REVIEW',
      'version', v_batch_version_after,
      'current_source', pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_run_id,
        'need_generation_run_version', v_run_version,
        'need_generation_release_snapshot_id', v_release.need_generation_release_snapshot_id
      ),
      'result_counts', v_counts
    ),
    'atlas_api',
    pg_catalog.transaction_timestamp()
  ) returning audit_event_id into v_audit_event_id;

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'confirmed_need_batch_id', v_batch_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'need_generation_run_version', v_run_version,
      'confirmed_need_batch_version', v_batch_version_after
    ),
    'result_counts', v_counts,
    'emitted_event_ids', pg_catalog.jsonb_build_array(v_domain_event_id),
    'audit_event_ids', pg_catalog.jsonb_build_array(v_audit_event_id),
    'safe_operator_message', case when v_initial
      then 'Draft Confirmed Need created from the released generation result.'
      else 'Draft Confirmed Need rematerialized from the direct released successor.'
    end,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
exception
  when serialization_failure or deadlock_detected or lock_not_available or query_canceled then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      v_command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Confirmed Need could not be materialized safely.',
      'PLANNING',
      v_command_name
    );
end;
$$;

alter function atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)
  owner to atlas_owner;
grant atlas_planning_materialization_runtime to postgres with set true;
grant create on schema atlas_api to atlas_planning_materialization_runtime;
alter function atlas_api.create_confirmed_needs_from_generation(jsonb)
  owner to atlas_planning_materialization_runtime;

revoke create on schema atlas_core, atlas_admin, atlas_planning, atlas_audit, atlas_api
  from atlas_planning_materialization_runtime;

grant execute on function
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean),
  atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)
to atlas_planning_materialization_runtime;

revoke all on function atlas_core.pa_06e_h0cb_validate_materialization_request(jsonb)
  from public, anon, authenticated, service_role;
set role atlas_planning_materialization_runtime;
revoke all on function atlas_api.create_confirmed_needs_from_generation(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function atlas_api.create_confirmed_needs_from_generation(jsonb)
  to authenticated;
reset role;
revoke atlas_planning_materialization_runtime from postgres;

comment on role atlas_planning_materialization_runtime
  is 'PA-06E-H0Cb no-login, no-inherit SECURITY DEFINER owner of exactly CMD-15.';
