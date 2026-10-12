-- Product-approved hotfix: zero derived demand is valid and non-actionable.
-- Complete effective baseline bodies; no historical migration is edited.
-- No table, lifecycle, RLS, calculation, Procurement or Dispatch change.
reset role;
create temporary table atlas_zero_demand_runtime_access_before as
select role.rolname, membership.admin_option, membership.inherit_option, membership.set_option
from pg_catalog.pg_roles role left join pg_catalog.pg_auth_members membership
  on membership.roleid=role.oid and membership.member='postgres'::regrole
 and membership.grantor='postgres'::regrole
where role.rolname in ('atlas_planning_materialization_runtime','atlas_read_runtime',
 'atlas_need_generation_runtime','atlas_planning_command_runtime');
create temporary table atlas_zero_demand_schema_access_before as
select role_name,schema_name,pg_catalog.has_schema_privilege(role_name,schema_name,'CREATE') as had_create
from (values ('atlas_planning_materialization_runtime','atlas_core'),('atlas_read_runtime','atlas_core'),
 ('atlas_need_generation_runtime','atlas_core'),('atlas_planning_command_runtime','atlas_core'),
 ('atlas_need_generation_runtime','atlas_api')) access(role_name,schema_name);
grant atlas_planning_materialization_runtime to postgres with set true;
grant atlas_read_runtime to postgres with set true;
grant atlas_need_generation_runtime to postgres with set true;
grant atlas_planning_command_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime;
grant create on schema atlas_core to atlas_read_runtime;
grant create on schema atlas_core to atlas_need_generation_runtime;
grant create on schema atlas_core to atlas_planning_command_runtime;
reset role;
set role atlas_planning_materialization_runtime;

-- Walk only immutable zero observations to recover the last materialized
-- destination/line identity. A positive predecessor never gets skipped.
create or replace function atlas_core.zero_demand_predecessor_contribution(
  predecessor_line_id uuid, batch_id uuid
) returns uuid language sql stable strict security definer set search_path = '' as $function$
  with recursive ancestry as (
    select line.theoretical_need_line_id, line.predecessor_theoretical_need_line_id,
           line.theoretical_quantity, line.line_disposition,
           array[line.theoretical_need_line_id] as visited, 0 as depth
    from atlas_planning.theoretical_need_lines line
    where line.theoretical_need_line_id = predecessor_line_id
    union all
    select line.theoretical_need_line_id, line.predecessor_theoretical_need_line_id,
           line.theoretical_quantity, line.line_disposition,
           ancestry.visited || line.theoretical_need_line_id, ancestry.depth + 1
    from ancestry join atlas_planning.theoretical_need_lines line
      on line.theoretical_need_line_id = ancestry.predecessor_theoretical_need_line_id
    where ancestry.line_disposition = 'ACTIVE' and ancestry.theoretical_quantity = 0
      and not line.theoretical_need_line_id = any(ancestry.visited)
  )
  select contribution.confirmed_need_line_revision_contribution_id
  from ancestry
  join atlas_planning.confirmed_need_line_revision_contributions contribution
    on contribution.theoretical_need_line_id = ancestry.theoretical_need_line_id
   and contribution.confirmed_need_batch_id = batch_id
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
  order by ancestry.depth, revision.revision_number desc,
           contribution.confirmed_need_line_revision_contribution_id
  limit 1;
$function$;
revoke all on function atlas_core.zero_demand_predecessor_contribution(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.zero_demand_predecessor_contribution(uuid,uuid)
  to atlas_planning_materialization_runtime,atlas_need_generation_runtime,
     atlas_confirmed_need_review_runtime,
     atlas_planning_command_runtime,atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.planning_contract_01_materialize_confirmed_needs(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_command_name constant text := 'create_confirmed_needs_from_generation';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_authorization_error jsonb;
  v_internal jsonb;
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
  v_invalid_rounding_config_count integer := 0;
  v_missing_policy_count integer := 0;
  v_ambiguous_policy_count integer := 0;
  v_incompatible_rounding_step_count integer := 0;
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

  v_internal := atlas_core.planning_contract_01_internal_context(request);
  if v_internal is not null then
    v_actor_id := atlas_core.pa_05b_safe_uuid(v_internal ->> 'actor_id');
    v_receipt_id := atlas_core.pa_05b_safe_uuid(v_internal ->> 'receipt_id');
  else
    v_actor_context := atlas_core.pa_05b_resolve_actor(
      request, 'PLANNING', v_command_name
    );
    if v_actor_context ? 'error' then
      return v_actor_context -> 'error';
    end if;
    if v_actor_context ->> 'actor_type' <> 'HUMAN' then
      return atlas_core.pa_05b_command_error(
        request, 'DELEGATION_NOT_SUPPORTED',
        'Only an active authenticated human actor may materialize Confirmed Need.',
        'PLANNING', v_command_name
      );
    end if;
    v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');
  end if;

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

  if v_internal is null then
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
       and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions old_revision
         where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
           and (old_revision.is_current or exists (select 1 from atlas_planning.theoretical_need_lines predecessor where predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id and predecessor.line_disposition = 'ACTIVE' and predecessor.theoretical_quantity = 0))
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
                and scope.delivery_location_id = case
                  when theoretical.contribution_family = 'PANTRY_DIRECT'
                    then theoretical.delivery_location_id
                  when old_contribution.delivery_location_id is not null
                    then old_contribution.delivery_location_id
                  else school.default_delivery_location_id
                end
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

  end if;

  if v_internal is null then
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
    if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
      return v_begin -> 'response';
    end if;
    v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  end if;

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
    select theoretical.delivery_location_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.contribution_family = 'PANTRY_DIRECT'
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
      and theoretical.contribution_family = 'RECIPE_DERIVED'
      and not (
        theoretical.line_disposition = 'REMOVED'
        and theoretical.recipe_replacement_predecessor_selection_id is not null
        and theoretical.recipe_replacement_successor_selection_id is not null
      )
      and (selection.need_generation_recipe_selection_id is null or recipe_use.need_generation_recipe_line_use_id is null)
  ) then
    v_error := atlas_core.pa_05b_command_error(
      request, 'SOURCE_LINEAGE_INCOMPLETE',
      'The released source does not retain its complete typed input and contribution lineage.',
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
  if v_active_count = 0
     and (
       v_initial
       or v_release_member_count = 0
       or exists (
         select 1
         from atlas_planning.need_generation_release_snapshot_lines release_line
         join atlas_planning.theoretical_need_lines theoretical
           on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
         where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
           and not (
             theoretical.contribution_family = 'PANTRY_DIRECT'
             and theoretical.line_disposition = 'REMOVED'
           )
       )
     ) then
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
    left join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_admin.customers customer on customer.customer_id = school.customer_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    left join atlas_admin.delivery_locations location
      on location.delivery_location_id = case
        when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
        when old_contribution.delivery_location_id is not null
          then old_contribution.delivery_location_id
        else school.default_delivery_location_id
      end
     and location.customer_id = school.customer_id
    left join atlas_admin.ingredients ingredient on ingredient.ingredient_id = theoretical.ingredient_id
    left join atlas_admin.units unit_record on unit_record.unit_id = theoretical.unit_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
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
    and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0;

  select count(*)::integer into v_group_count
  from (
    select theoretical.service_date, school.customer_id, theoretical.school_id,
           case
             when theoretical.contribution_family = 'PANTRY_DIRECT'
               then theoretical.delivery_location_id
             when old_contribution.delivery_location_id is not null
               then old_contribution.delivery_location_id
             else school.default_delivery_location_id
           end delivery_location_id,
           theoretical.ingredient_id, theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on not v_initial
     and old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
     and exists (
       select 1 from atlas_planning.confirmed_need_line_revisions old_revision
       where old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
         and old_revision.is_current
     )
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end,
             theoretical.ingredient_id, theoretical.unit_id
  ) grouped;

  -- Resolve Ingredient rounding configuration and the human confirmation
  -- policy once, set-wise, for every released operational identity. All
  -- configuration failures occur before any Confirmed Need row is written.
  with policy_keys as (
    select distinct theoretical.service_date, theoretical.ingredient_id,
           theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id =
        v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
  ), proposal_resolution as (
    select policy_key.service_date, policy_key.ingredient_id, policy_key.unit_id,
           ingredient.ingredient_id as resolved_ingredient_id,
           ingredient.purchase_unit_id,
           ingredient.order_step,
           ingredient.version as ingredient_version,
           count(policy_revision.planning_quantity_policy_revision_id)::integer
             as policy_count,
           min(policy_revision.planning_step) as planning_step
    from policy_keys policy_key
    left join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = policy_key.ingredient_id
     and ingredient.ingredient_status = 'ACTIVE'
    left join atlas_planning.planning_quantity_policy_revisions policy_revision
      on policy_revision.unit_id = policy_key.unit_id
     and policy_revision.policy_revision_status in ('ACTIVE', 'RETIRED')
     and policy_revision.effective_from <= policy_key.service_date
     and (
       policy_revision.effective_to is null
       or policy_key.service_date < policy_revision.effective_to
     )
    group by policy_key.service_date, policy_key.ingredient_id,
             policy_key.unit_id, ingredient.ingredient_id,
             ingredient.purchase_unit_id, ingredient.order_step,
             ingredient.version
  )
  select
    count(*) filter (
      where resolved_ingredient_id is null
         or purchase_unit_id is distinct from unit_id
         or order_step is null
         or order_step <= 0
         or ingredient_version is null
         or ingredient_version <= 0
    )::integer,
    count(*) filter (where policy_count = 0)::integer,
    count(*) filter (where policy_count > 1)::integer,
    count(*) filter (
      where resolved_ingredient_id is not null
        and purchase_unit_id = unit_id
        and order_step > 0
        and ingredient_version > 0
        and policy_count = 1
        and pg_catalog.mod(order_step, planning_step) <> 0
    )::integer
  into v_invalid_rounding_config_count, v_missing_policy_count,
       v_ambiguous_policy_count, v_incompatible_rounding_step_count
  from proposal_resolution;

  if v_invalid_rounding_config_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INGREDIENT_ROUNDING_CONFIGURATION_INVALID',
      'Every Ingredient requires a positive rounding step in its exact controlled Unit.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_missing_policy_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'MISSING_PLANNING_QUANTITY_POLICY',
      'No eligible exact-Unit Planning quantity policy exists for the service date.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_ambiguous_policy_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'AMBIGUOUS_PLANNING_QUANTITY_POLICY',
      'More than one eligible exact-Unit Planning quantity policy exists for the service date.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_incompatible_rounding_step_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INGREDIENT_ROUNDING_STEP_INCOMPATIBLE',
      'The Ingredient rounding step is not an exact positive integer multiple of the human confirmation step.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

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

  -- A released all-zero observation has audit authority but no procurement
  -- authority. Corrections still traverse the existing supersession path.
  if v_initial and v_group_count = 0 then
    return atlas_core.pa_05b_finish_command(v_receipt_id,
      pg_catalog.jsonb_build_object(
        'success', true, 'command_id', request ->> 'command_id',
        'correlation_id', request ->> 'correlation_id', 'idempotency_status', 'COMPLETED',
        'affected_aggregate_ids', pg_catalog.jsonb_build_object(
          'need_generation_run_id', v_run_id, 'confirmed_need_batch_id', null),
        'new_versions', pg_catalog.jsonb_build_object('need_generation_run_version', v_run_version,'confirmed_need_batch_version',null),
        'result_counts', pg_catalog.jsonb_build_object(
          'created_confirmed_need_line_count',0,'reused_confirmed_need_line_count',0,
          'retired_confirmed_need_line_count',0,'created_line_revision_count',0,
          'created_revision_contribution_count',0,'current_line_revision_count',0,
          'superseded_line_revision_count',0,'carried_forward_count',0,'needs_review_count',0,
          'changed_count',0,'new_count',0,'removed_count',0),
        'emitted_event_ids','[]'::jsonb,'audit_event_ids','[]'::jsonb,
        'safe_operator_message','Không có nhu cầu.', 'warnings','[]'::jsonb,'blockers','[]'::jsonb
      ), true);
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
      case
        when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
        else school.default_delivery_location_id
      end,
      theoretical.ingredient_id,
      theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
    group by theoretical.service_date, school.customer_id, theoretical.school_id,
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               else school.default_delivery_location_id
             end,
             theoretical.ingredient_id, theoretical.unit_id;
    get diagnostics v_created_line_count = row_count;

    with proposal_resolution as (
      select
        target_line.confirmed_need_line_id,
        ingredient.order_step as proposal_rounding_step,
        ingredient.version as proposal_rounding_ingredient_version
      from atlas_planning.confirmed_need_lines target_line
      join atlas_admin.ingredients ingredient
        on ingredient.ingredient_id = target_line.ingredient_id
       and ingredient.ingredient_status = 'ACTIVE'
       and ingredient.purchase_unit_id = target_line.controlled_unit_id
       and ingredient.order_step > 0
       and ingredient.version > 0
      join atlas_planning.planning_quantity_policy_revisions policy_revision
        on policy_revision.unit_id = target_line.controlled_unit_id
       and policy_revision.policy_revision_status in ('ACTIVE', 'RETIRED')
       and policy_revision.effective_from <= target_line.service_date
       and (
         policy_revision.effective_to is null
         or target_line.service_date < policy_revision.effective_to
       )
      where target_line.confirmed_need_batch_id = v_batch_id
        and target_line.source_kind = 'NEED_GENERATION'
      group by target_line.confirmed_need_line_id, ingredient.order_step,
               ingredient.version
      having count(policy_revision.planning_quantity_policy_revision_id) = 1
         and pg_catalog.mod(
           ingredient.order_step, min(policy_revision.planning_step)
         ) = 0
    )
    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id,
      revision_number,
      wholesale_order_line_revision_id,
      ingredient_id,
      theoretical_quantity,
      confirmed_quantity,
      proposal_rounding_step,
      proposal_rounding_ingredient_version,
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
      pg_catalog.ceil(
        sum(theoretical.theoretical_quantity)
          / proposal.proposal_rounding_step
      ) * proposal.proposal_rounding_step,
      proposal.proposal_rounding_step,
      proposal.proposal_rounding_ingredient_version,
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
    join proposal_resolution proposal
      on proposal.confirmed_need_line_id = target_line.confirmed_need_line_id
    join atlas_planning.need_generation_release_snapshot_lines release_line
      on release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
     and theoretical.service_date = target_line.service_date
     and theoretical.school_id = target_line.school_id
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
     and theoretical.ingredient_id = target_line.ingredient_id
     and theoretical.unit_id = target_line.controlled_unit_id
    where target_line.confirmed_need_batch_id = v_batch_id
      and target_line.source_kind = 'NEED_GENERATION'
    group by target_line.confirmed_need_line_id, target_line.ingredient_id,
             target_line.controlled_unit_id, target_line.service_date,
             target_line.customer_id, target_line.school_id,
             target_line.delivery_location_id,
             proposal.proposal_rounding_step,
             proposal.proposal_rounding_ingredient_version;
    get diagnostics v_created_revision_count = row_count;
    if v_created_revision_count <> v_group_count then
      raise exception 'Planning policy resolution changed during materialization';
    end if;

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
      and theoretical.theoretical_quantity > 0
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.source_kind = 'NEED_GENERATION'
     and target_line.service_date = theoretical.service_date
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
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
       or not (
         v_batch.current_need_generation_run_version = v_old_run.version
         or (
           v_internal is not null
           and v_old_run.run_status = 'INVALIDATED'
           and v_old_run.version =
             v_batch.current_need_generation_run_version + 1
         )
       )
       or not exists (
         select 1 from atlas_planning.need_generation_release_snapshots old_release
         where old_release.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
           and old_release.need_generation_run_id = v_old_run.need_generation_run_id
           and old_release.released_run_version =
             v_batch.current_need_generation_run_version
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
       and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(new_theoretical.predecessor_theoretical_need_line_id, v_batch_id)
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions current_predecessor
         where current_predecessor.confirmed_need_line_revision_id =
             old_contribution.confirmed_need_line_revision_id
           and current_predecessor.is_current
       )
      left join atlas_planning.confirmed_need_line_revisions old_revision
        on old_revision.confirmed_need_line_revision_id = old_contribution.confirmed_need_line_revision_id
       and old_revision.is_current
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and new_theoretical.line_disposition = 'ACTIVE'
        and new_theoretical.theoretical_quantity > 0
        and new_theoretical.predecessor_theoretical_need_line_id is not null
        and not exists (select 1 from atlas_planning.theoretical_need_lines predecessor where predecessor.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id and predecessor.line_disposition = 'ACTIVE' and predecessor.theoretical_quantity = 0)
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
      having count(successor_member.need_generation_release_snapshot_line_id) <> 1
         or count(successor_member.need_generation_release_snapshot_line_id)
              filter (
                where successor.line_disposition = 'ACTIVE'
                   or (
                     successor.contribution_family = 'PANTRY_DIRECT'
                     and successor.line_disposition = 'REMOVED'
                   )
                   or (
                     successor.contribution_family = 'RECIPE_DERIVED'
                     and successor.line_disposition = 'REMOVED'
                     and successor.recipe_replacement_predecessor_selection_id is not null
                     and successor.recipe_replacement_successor_selection_id is not null
                   )
              ) <> 1
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_REMOVAL_POLICY_REQUIRED',
        'A prior contribution lacks one accepted active or Pantry removal successor.',
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
       and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(successor.predecessor_theoretical_need_line_id, v_batch_id)
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and (
          successor.service_date <> old_contribution.service_date
          or successor.school_id <> old_contribution.school_id
          or (
            successor.unit_id <> old_contribution.source_unit_id
            and not atlas_core.planning_legacy_adoption_unit_transition_allowed(
              old_contribution.theoretical_need_line_id,
              successor.theoretical_need_line_id
            )
          )
        )
    ) then
      v_error := atlas_core.pa_05b_command_error(
        request, 'SOURCE_SPLIT_MERGE_POLICY_REQUIRED',
        'The successor changes an operational fact across the no-conversion or split-merge boundary.',
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
       and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(successor.predecessor_theoretical_need_line_id, v_batch_id)
      join atlas_admin.schools school on school.school_id = successor.school_id
      where new_release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and successor.line_disposition = 'ACTIVE'
        and successor.contribution_family = 'RECIPE_DERIVED'
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
    if (v_old_current_count = 0 and exists (
      select 1 from atlas_planning.theoretical_need_lines prior
      where prior.need_generation_run_id = v_old_run.need_generation_run_id
        and prior.line_disposition = 'ACTIVE' and prior.theoretical_quantity > 0
    )) or exists (
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
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions current_predecessor
         where current_predecessor.confirmed_need_line_revision_id =
             old_contribution.confirmed_need_line_revision_id
           and current_predecessor.is_current
       )
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               case
                 when theoretical.contribution_family = 'PANTRY_DIRECT'
                   then theoretical.delivery_location_id
                 when old_contribution.delivery_location_id is not null
                   then old_contribution.delivery_location_id
                 else school.default_delivery_location_id
               end,
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

    with proposal_resolution as (
      select
        target_line.confirmed_need_line_id,
        ingredient.order_step as proposal_rounding_step,
        ingredient.version as proposal_rounding_ingredient_version
      from atlas_planning.confirmed_need_lines target_line
      join atlas_admin.ingredients ingredient
        on ingredient.ingredient_id = target_line.ingredient_id
       and ingredient.ingredient_status = 'ACTIVE'
       and ingredient.purchase_unit_id = target_line.controlled_unit_id
       and ingredient.order_step > 0
       and ingredient.version > 0
      join atlas_planning.planning_quantity_policy_revisions policy_revision
        on policy_revision.unit_id = target_line.controlled_unit_id
       and policy_revision.policy_revision_status in ('ACTIVE', 'RETIRED')
       and policy_revision.effective_from <= target_line.service_date
       and (
         policy_revision.effective_to is null
         or target_line.service_date < policy_revision.effective_to
       )
      where target_line.confirmed_need_batch_id = v_batch_id
        and target_line.source_kind = 'NEED_GENERATION'
      group by target_line.confirmed_need_line_id, ingredient.order_step,
               ingredient.version
      having count(policy_revision.planning_quantity_policy_revision_id) = 1
         and pg_catalog.mod(
           ingredient.order_step, min(policy_revision.planning_step)
         ) = 0
    )
    insert into atlas_planning.confirmed_need_line_revisions (
      confirmed_need_line_id,
      revision_number,
      wholesale_order_line_revision_id,
      ingredient_id,
      theoretical_quantity,
      confirmed_quantity,
      proposal_rounding_step,
      proposal_rounding_ingredient_version,
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
      pg_catalog.ceil(
        grouped.theoretical_total / proposal.proposal_rounding_step
      ) * proposal.proposal_rounding_step,
      proposal.proposal_rounding_step,
      proposal.proposal_rounding_ingredient_version,
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
             case
               when theoretical.contribution_family = 'PANTRY_DIRECT'
                 then theoretical.delivery_location_id
               when old_contribution.delivery_location_id is not null
                 then old_contribution.delivery_location_id
               else school.default_delivery_location_id
             end delivery_location_id,
             theoretical.ingredient_id, theoretical.unit_id,
             sum(theoretical.theoretical_quantity) theoretical_total
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
        on old_contribution.confirmed_need_batch_id = v_batch_id
       and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
       and exists (
         select 1
         from atlas_planning.confirmed_need_line_revisions current_predecessor
         where current_predecessor.confirmed_need_line_revision_id =
             old_contribution.confirmed_need_line_revision_id
           and current_predecessor.is_current
       )
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
      group by theoretical.service_date, school.customer_id, theoretical.school_id,
               case
                 when theoretical.contribution_family = 'PANTRY_DIRECT'
                   then theoretical.delivery_location_id
                 when old_contribution.delivery_location_id is not null
                   then old_contribution.delivery_location_id
                 else school.default_delivery_location_id
               end,
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
    join proposal_resolution proposal
      on proposal.confirmed_need_line_id = target_line.confirmed_need_line_id
    left join lateral (
      select prior.confirmed_need_line_revision_id, prior.revision_number
      from atlas_planning.confirmed_need_line_revisions prior
      where prior.confirmed_need_line_id = target_line.confirmed_need_line_id
      order by prior.revision_number desc
      limit 1
    ) prior_revision on true;
    get diagnostics v_created_revision_count = row_count;
    if v_created_revision_count <> v_group_count then
      raise exception 'Planning policy resolution changed during rematerialization';
    end if;

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
      and theoretical.theoretical_quantity > 0
    join atlas_admin.schools school on school.school_id = theoretical.school_id
    left join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.confirmed_need_batch_id = v_batch_id
     and old_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
     and exists (
       select 1
       from atlas_planning.confirmed_need_line_revisions current_predecessor
       where current_predecessor.confirmed_need_line_revision_id =
           old_contribution.confirmed_need_line_revision_id
         and current_predecessor.is_current
     )
    join atlas_planning.confirmed_need_lines target_line
      on target_line.confirmed_need_batch_id = v_batch_id
     and target_line.service_date = theoretical.service_date
     and target_line.customer_id = school.customer_id
     and target_line.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       when old_contribution.delivery_location_id is not null
         then old_contribution.delivery_location_id
       else school.default_delivery_location_id
     end
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

    perform atlas_core.planning_contract_02b_apply_decision_continuity(
      v_batch_id,
      v_batch.current_need_generation_run_id,
      v_batch.current_need_generation_run_version,
      v_batch.current_need_generation_release_snapshot_id,
      v_run_id,
      v_run_version,
      v_release.need_generation_release_snapshot_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
      v_actor_id
    );

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
    'superseded_line_revision_count', v_superseded_revision_count,
    'carried_forward_count', (
      select count(*)::integer
      from atlas_planning.confirmed_need_line_decision_continuity continuity
      where continuity.command_id = atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
        and continuity.continuity_kind = 'CARRIED_FORWARD'
    ),
    'needs_review_count', (
      select count(*)::integer
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_id = line.confirmed_need_line_id
       and revision.is_current
      where line.confirmed_need_batch_id = v_batch_id
        and line.current_confirmed_need_line_decision_id is null
    ),
    'changed_count', (
      select count(*)::integer
      from atlas_planning.confirmed_need_line_decision_continuity continuity
      where continuity.command_id = atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
        and continuity.continuity_kind in (
          'INVALIDATED_PROPOSAL_CHANGE',
          'INVALIDATED_POLICY_INCOMPATIBLE'
        )
    ),
    'new_count', v_created_line_count,
    'removed_count',
      atlas_core.planning_contract_02b_removed_business_fact_count(
        v_batch_id,
        v_batch.current_need_generation_run_id,
        v_batch.current_need_generation_run_version,
        v_batch.current_need_generation_release_snapshot_id,
        v_run_id,
        v_run_version,
        v_release.need_generation_release_snapshot_id
      )
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
$function$;
reset role;
set role atlas_owner;
CREATE OR REPLACE FUNCTION atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_batch_id uuid;
  v_revision_id uuid;
  v_source_kind text;
  v_current_snapshot_id uuid;
  v_retiring boolean := false;
begin
  v_batch_id := new.confirmed_need_batch_id;
  -- NG_SCALE_MEMBERSHIP: both registered trigger tables identify one revision.
  -- Its nonempty membership, every exact contribution, sum, predecessor and
  -- completeness checks all remain. Unchanged immutable sibling revisions do
  -- not need revalidation. The final GLOBAL partition check is NOT filtered.
  v_revision_id:=new.confirmed_need_line_revision_id;
  -- Retiring an immutable revision changes only its current pointer. Its
  -- membership and captured predecessor facts are unchanged; validate this
  -- revision locally, but still prove the complete CURRENT release partition.
  if tg_table_name='confirmed_need_line_revisions' and tg_op='UPDATE' then
    v_retiring := old.is_current and not new.is_current
      and new.revision_status='SUPERSEDED'
      and (to_jsonb(old)-array['is_current','revision_status'])
        =(to_jsonb(new)-array['is_current','revision_status']);
  end if;


  select batch.source_kind, batch.current_need_generation_release_snapshot_id
  into strict v_source_kind, v_current_snapshot_id
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;
  -- Historical membership can supply predecessor/captured-location facts to
  -- later revisions. Preserve the original full-batch validation whenever a
  -- historical revision is touched; only current-source revisions are local.
  if not exists (
    select 1 from atlas_planning.confirmed_need_line_revisions target_revision
    where target_revision.confirmed_need_line_revision_id = v_revision_id
      and target_revision.is_current
      and target_revision.need_generation_release_snapshot_id = v_current_snapshot_id
  ) then
    if not v_retiring then v_revision_id:=null; end if;
  end if;


  if v_source_kind = 'WHOLESALE' then
    if exists (
      select 1
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_batch_id = v_batch_id
    ) then
      raise exception using errcode = '23514', message = 'Wholesale Confirmed Need revisions cannot have contributions';
    end if;
    return null;
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and (v_revision_id is null or revision.confirmed_need_line_revision_id = v_revision_id)
      and revision.source_kind = 'NEED_GENERATION'
      and not exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions contribution
        where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
      )
  ) then
    raise exception using errcode = '23514', message = 'Every Need Generation revision requires nonempty contribution membership';
  end if;

  -- LIVE_OWNER_SCOPE: changes outside this revision remain checked globally.
  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id=contribution.confirmed_need_line_id
    join atlas_admin.schools school on school.school_id=contribution.school_id
    where contribution.confirmed_need_batch_id=v_batch_id
      and school.customer_id<>line.customer_id
  ) then
    raise exception using errcode='23514',message='Need Generation contribution facts are not exact active release facts';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id = revision.confirmed_need_line_id
    join atlas_planning.need_generation_release_snapshot_lines snapshot_line
      on snapshot_line.need_generation_release_snapshot_line_id = contribution.need_generation_release_snapshot_line_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = contribution.theoretical_need_line_id
    join atlas_admin.schools school
      on school.school_id = contribution.school_id
    left join lateral (
      select prior_contribution.delivery_location_id
      from atlas_planning.confirmed_need_line_revision_contributions prior_contribution
      where prior_contribution.confirmed_need_batch_id = v_batch_id
        and prior_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
      order by prior_contribution.created_at,
               prior_contribution.confirmed_need_line_revision_contribution_id
      limit 1
    ) predecessor_contribution
      on theoretical.contribution_family = 'RECIPE_DERIVED'
     and theoretical.predecessor_theoretical_need_line_id is not null
    where contribution.confirmed_need_batch_id = v_batch_id
      and (v_revision_id is null or contribution.confirmed_need_line_revision_id=v_revision_id)
      and (
        revision.source_kind <> 'NEED_GENERATION'
        or contribution.confirmed_need_batch_id <> revision.confirmed_need_batch_id
        or contribution.confirmed_need_line_id <> revision.confirmed_need_line_id
        or contribution.need_generation_run_id <> revision.need_generation_run_id
        or contribution.need_generation_run_version <> revision.need_generation_run_version
        or contribution.need_generation_release_snapshot_id <> revision.need_generation_release_snapshot_id
        or snapshot_line.need_generation_release_snapshot_id <> revision.need_generation_release_snapshot_id
        or snapshot_line.need_generation_run_id <> revision.need_generation_run_id
        or snapshot_line.released_run_version <> revision.need_generation_run_version
        or snapshot_line.theoretical_need_line_id <> theoretical.theoretical_need_line_id
        or theoretical.need_generation_run_id <> revision.need_generation_run_id
        or theoretical.line_disposition <> 'ACTIVE'
        or theoretical.theoretical_quantity <= 0
        or theoretical.service_date <> line.service_date
        or theoretical.school_id <> line.school_id
        or theoretical.ingredient_id <> line.ingredient_id
        or theoretical.unit_id <> line.controlled_unit_id
        or theoretical.theoretical_quantity <> contribution.source_theoretical_quantity
        or contribution.service_date <> line.service_date
        or contribution.customer_id <> line.customer_id
        or contribution.school_id <> line.school_id
        or contribution.delivery_location_id <> line.delivery_location_id
        or contribution.ingredient_id <> line.ingredient_id
        or contribution.source_unit_id <> line.controlled_unit_id
        or contribution.controlled_unit_id <> line.controlled_unit_id
        or contribution.controlled_contribution_quantity <> contribution.source_theoretical_quantity
        or school.customer_id <> line.customer_id
        or contribution.delivery_location_id is distinct from case
          when theoretical.contribution_family = 'PANTRY_DIRECT'
            then theoretical.delivery_location_id
          when predecessor_contribution.delivery_location_id is not null
            then predecessor_contribution.delivery_location_id
          else revision.delivery_location_id
        end
      )
  ) then
    raise exception using errcode = '23514', message = 'Need Generation contribution facts are not exact active release facts';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id = v_batch_id
      and (v_revision_id is null or revision.confirmed_need_line_revision_id = v_revision_id)
      and revision.source_kind = 'NEED_GENERATION'
      and (
        revision.theoretical_quantity is distinct from (
          select sum(contribution.controlled_contribution_quantity)
          from atlas_planning.confirmed_need_line_revision_contributions contribution
          where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
        )
        or exists (
          select 1
          from atlas_planning.need_generation_release_snapshot_lines snapshot_line
          join atlas_planning.theoretical_need_lines theoretical
            on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
          where snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
            and theoretical.line_disposition = 'ACTIVE'
            and theoretical.theoretical_quantity > 0
            and theoretical.contribution_family = 'RECIPE_DERIVED'
            and theoretical.predecessor_theoretical_need_line_id is not null
            and not exists (select 1 from atlas_planning.theoretical_need_lines predecessor where predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id and predecessor.line_disposition = 'ACTIVE' and predecessor.theoretical_quantity = 0)
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions predecessor_contribution
              where predecessor_contribution.confirmed_need_batch_id = v_batch_id
                and predecessor_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
            )
        )
        or exists (
          select 1
          from atlas_planning.need_generation_release_snapshot_lines snapshot_line
          join atlas_planning.theoretical_need_lines theoretical
            on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
          left join lateral (
            select prior_contribution.delivery_location_id
            from atlas_planning.confirmed_need_line_revision_contributions prior_contribution
            where prior_contribution.confirmed_need_batch_id = v_batch_id
              and prior_contribution.confirmed_need_line_revision_contribution_id = atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id)
            order by prior_contribution.created_at,
                     prior_contribution.confirmed_need_line_revision_contribution_id
            limit 1
          ) predecessor_contribution
            on theoretical.contribution_family = 'RECIPE_DERIVED'
           and theoretical.predecessor_theoretical_need_line_id is not null
          left join lateral (
            select captured.delivery_location_id
            from atlas_planning.confirmed_need_line_revision_contributions captured
            where captured.confirmed_need_batch_id = v_batch_id
              and captured.theoretical_need_line_id = theoretical.theoretical_need_line_id
            order by captured.created_at,
                     captured.confirmed_need_line_revision_contribution_id
            limit 1
          ) captured_contribution
            on theoretical.contribution_family = 'RECIPE_DERIVED'
           and atlas_core.zero_demand_predecessor_contribution(theoretical.predecessor_theoretical_need_line_id, v_batch_id) is null
          where snapshot_line.need_generation_release_snapshot_id = revision.need_generation_release_snapshot_id
            and theoretical.line_disposition = 'ACTIVE'
            and theoretical.theoretical_quantity > 0
            and theoretical.service_date = revision.service_date
            and theoretical.school_id = revision.school_id
            and theoretical.ingredient_id = revision.ingredient_id
            and theoretical.unit_id = revision.unit_id
            and revision.delivery_location_id is not distinct from case
              when theoretical.contribution_family = 'PANTRY_DIRECT'
                then theoretical.delivery_location_id
              when predecessor_contribution.delivery_location_id is not null
                then predecessor_contribution.delivery_location_id
              else captured_contribution.delivery_location_id
            end
            and not exists (
              select 1
              from atlas_planning.confirmed_need_line_revision_contributions contribution
              where contribution.confirmed_need_line_revision_id = revision.confirmed_need_line_revision_id
                and contribution.theoretical_need_line_id = theoretical.theoretical_need_line_id
            )
        )
      )
  ) then
    raise exception using errcode = '23514', message = 'Need Generation revision membership is incomplete or its total is inexact';
  end if;

  if exists (
    select snapshot_line.theoretical_need_line_id
    from atlas_planning.need_generation_release_snapshot_lines snapshot_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
    left join atlas_planning.confirmed_need_line_revision_contributions contribution
      on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
    left join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
      and revision.confirmed_need_batch_id = v_batch_id
      and revision.is_current
    where snapshot_line.need_generation_release_snapshot_id = v_current_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
            and theoretical.theoretical_quantity > 0
      -- PARTITION_SCOPE: historical changes retain NULL and full coverage.
      -- Current inserts keep the complete group membership validation above;
      -- immutable contributions cannot silently disappear from an old revision.
      and (v_revision_id is null or v_retiring or exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions affected
        where affected.confirmed_need_line_revision_id=v_revision_id
          and affected.need_generation_release_snapshot_line_id=snapshot_line.need_generation_release_snapshot_line_id
      ))
    group by snapshot_line.theoretical_need_line_id
    having count(revision.confirmed_need_line_revision_id) <> 1
  ) then
    raise exception using errcode = '23514', message = 'Current Need Generation revisions must exactly partition the active release';
  end if;

  return null;
end;
$function$;
CREATE OR REPLACE FUNCTION atlas_planning.pa_06e_h0b1b_confirmed_need_current_source_consistency()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_batch_id uuid;
  v_line_id uuid;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
begin
  v_batch_id := new.confirmed_need_batch_id;

  select batch.* into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  -- INSERT_EVENT_SCOPE: a stable-line event introduces only one immutable
  -- source identity. The batch event remains queued and proves completeness,
  -- including when constraints are flushed before any revision is inserted.
  if tg_op = 'INSERT' and tg_table_name = 'confirmed_need_lines' then
    if v_batch.source_kind = 'WHOLESALE' then
      if new.source_kind <> 'WHOLESALE' or not exists (
        select 1
        from atlas_planning.wholesale_order_lines source_line
        where source_line.wholesale_order_line_id = new.wholesale_order_line_id
          and source_line.wholesale_order_id = v_batch.wholesale_order_id
      ) then
        raise exception using errcode = '23514',
          message = 'Wholesale Confirmed Need source chain is inconsistent';
      end if;
    elsif new.source_kind <> 'NEED_GENERATION' then
      raise exception using errcode = '23514',
        message = 'Need Generation stable lines must agree with the batch source kind';
    end if;
    return null;
  end if;

  -- INSERT_EVENT_SCOPE: a new current revision owns one immutable identity,
  -- one predecessor edge and the release members attached to its stable line.
  -- The separate membership-total guard still proves nonempty exact facts,
  -- totals, predecessor provenance and completeness for this revision.
  if tg_op = 'INSERT'
     and tg_table_name = 'confirmed_need_line_revisions' then
    if not new.is_current then
      -- Historical revision INSERTs retain the broader path below.
      null;
    elsif v_batch.source_kind = 'WHOLESALE' then
      if not exists (
        select 1
        from atlas_planning.confirmed_need_lines line
        join atlas_planning.wholesale_order_line_revisions source_revision
          on source_revision.wholesale_order_line_revision_id = new.wholesale_order_line_revision_id
        where line.confirmed_need_line_id = new.confirmed_need_line_id
          and line.confirmed_need_batch_id = v_batch_id
          and line.source_kind = 'WHOLESALE'
          and new.source_kind = 'WHOLESALE'
          and source_revision.wholesale_order_line_id = line.wholesale_order_line_id
          and source_revision.ingredient_id = new.ingredient_id
          and source_revision.unit_id = new.unit_id
          and source_revision.requested_quantity = new.theoretical_quantity
          and new.confirmed_quantity = new.theoretical_quantity
      ) then
        raise exception using errcode = '23514',
          message = 'Wholesale Confirmed Need source chain is inconsistent';
      end if;
      return null;
    else

      if not exists (
      select 1
      from atlas_planning.confirmed_need_lines line
      join atlas_planning.need_generation_runs source_run
        on source_run.need_generation_run_id = new.need_generation_run_id
      join atlas_planning.need_generation_release_snapshots source_snapshot
        on source_snapshot.need_generation_release_snapshot_id = new.need_generation_release_snapshot_id
       and source_snapshot.need_generation_run_id = new.need_generation_run_id
       and source_snapshot.released_run_version = new.need_generation_run_version
      where line.confirmed_need_line_id = new.confirmed_need_line_id
        and line.confirmed_need_batch_id = v_batch_id
        and new.source_kind = 'NEED_GENERATION'
        and row(
          new.need_generation_run_id,
          new.need_generation_run_version,
          new.need_generation_release_snapshot_id
        ) = row(
          v_batch.current_need_generation_run_id,
          v_batch.current_need_generation_run_version,
          v_batch.current_need_generation_release_snapshot_id
        )
        and source_run.run_status = 'RELEASED_FOR_CONFIRMATION'
        and source_run.version = new.need_generation_run_version
        and source_run.period_start = v_batch.period_start
        and source_run.period_end = v_batch.period_end
        and row(
          new.service_date,
          new.customer_id,
          new.school_id,
          new.delivery_location_id,
          new.ingredient_id,
          new.unit_id
        ) = row(
          line.service_date,
          line.customer_id,
          line.school_id,
          line.delivery_location_id,
          line.ingredient_id,
          line.controlled_unit_id
        )
      ) then
        raise exception using errcode = '23514',
          message = 'Need Generation revision source or operational identity is inconsistent';
      end if;

      if (new.revision_number = 1 and new.predecessor_revision_id is not null)
         or (new.revision_number > 1 and not exists (
           select 1
           from atlas_planning.confirmed_need_line_revisions predecessor
           where predecessor.confirmed_need_line_revision_id = new.predecessor_revision_id
             and predecessor.confirmed_need_line_id = new.confirmed_need_line_id
             and predecessor.revision_number = new.revision_number - 1
         )) then
        raise exception using errcode = '23514',
          message = 'Need Generation current revision predecessor is stale';
      end if;

      if exists (
      select snapshot_line.need_generation_release_snapshot_line_id
      from atlas_planning.need_generation_release_snapshot_lines snapshot_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions contribution
        on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
       and contribution.confirmed_need_batch_id = v_batch_id
       and contribution.need_generation_run_id = v_batch.current_need_generation_run_id
       and contribution.need_generation_run_version = v_batch.current_need_generation_run_version
       and contribution.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
      left join atlas_planning.confirmed_need_line_revisions revision
        on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
       and revision.confirmed_need_batch_id = v_batch_id
       and revision.source_kind = 'NEED_GENERATION'
       and revision.is_current
       and revision.need_generation_run_id = v_batch.current_need_generation_run_id
       and revision.need_generation_run_version = v_batch.current_need_generation_run_version
       and revision.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
      where snapshot_line.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
        and theoretical.theoretical_quantity > 0
        and exists (
          select 1
          from atlas_planning.confirmed_need_line_revision_contributions affected
          where affected.confirmed_need_batch_id = v_batch_id
            and affected.confirmed_need_line_id = new.confirmed_need_line_id
            and affected.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
        )
      group by snapshot_line.need_generation_release_snapshot_line_id
      having count(revision.confirmed_need_line_revision_id) <> 1
      ) then
        raise exception using errcode = '23514',
          message = 'Current Need Generation revisions must exactly partition the active release';
      end if;
      return null;
    end if;
  end if;

  -- Existing UPDATE and historical-revision semantics begin here.
  if v_batch.source_kind = 'WHOLESALE' then
    if exists (
      select 1
      from atlas_planning.confirmed_need_lines line
      left join atlas_planning.wholesale_order_lines source_line
        on source_line.wholesale_order_line_id = line.wholesale_order_line_id
      where line.confirmed_need_batch_id = v_batch_id
        and (
          line.source_kind <> 'WHOLESALE'
          or source_line.wholesale_order_id is distinct from v_batch.wholesale_order_id
        )
    ) or exists (
      select 1
      from atlas_planning.confirmed_need_line_revisions revision
      join atlas_planning.confirmed_need_lines line
        on line.confirmed_need_line_id = revision.confirmed_need_line_id
      left join atlas_planning.wholesale_order_line_revisions source_revision
        on source_revision.wholesale_order_line_revision_id = revision.wholesale_order_line_revision_id
      where revision.confirmed_need_batch_id = v_batch_id
        and (
          revision.source_kind <> 'WHOLESALE'
          or source_revision.wholesale_order_line_id is distinct from line.wholesale_order_line_id
          or source_revision.ingredient_id is distinct from revision.ingredient_id
          or source_revision.unit_id is distinct from revision.unit_id
          or source_revision.requested_quantity is distinct from revision.theoretical_quantity
          or revision.confirmed_quantity is distinct from revision.theoretical_quantity
        )
    ) or exists (
      select 1
      from atlas_planning.confirmed_need_line_revision_contributions contribution
      where contribution.confirmed_need_batch_id = v_batch_id
    ) then
      raise exception using errcode = '23514',
        message = 'Wholesale Confirmed Need source chain is inconsistent';
    end if;
    return null;
  end if;

  if tg_table_name in ('confirmed_need_lines', 'confirmed_need_line_revisions') then
    v_line_id := new.confirmed_need_line_id;
  end if;

  if not exists (
    select 1
    from atlas_planning.need_generation_runs origin_run
    join atlas_planning.need_generation_runs current_run
      on current_run.need_generation_run_id = v_batch.current_need_generation_run_id
    where origin_run.need_generation_run_id = v_batch.origin_need_generation_run_id
      and current_run.run_status = 'RELEASED_FOR_CONFIRMATION'
      and current_run.version = v_batch.current_need_generation_run_version
      and origin_run.planning_input_set_id = current_run.planning_input_set_id
      and origin_run.period_start = v_batch.period_start
      and origin_run.period_end = v_batch.period_end
      and current_run.period_start = v_batch.period_start
      and current_run.period_end = v_batch.period_end
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation batch source must be released with the exact input set and period';
  end if;

  if tg_table_name = 'confirmed_need_batches' then
    if tg_op = 'UPDATE'
       and row(
         new.current_need_generation_run_id,
         new.current_need_generation_run_version,
         new.current_need_generation_release_snapshot_id
       ) is distinct from row(
         old.current_need_generation_run_id,
         old.current_need_generation_run_version,
         old.current_need_generation_release_snapshot_id
       )
       and not exists (
         select 1
         from atlas_planning.need_generation_runs successor
         join atlas_planning.need_generation_runs predecessor
           on predecessor.need_generation_run_id = old.current_need_generation_run_id
         where successor.need_generation_run_id = new.current_need_generation_run_id
           and successor.predecessor_need_generation_run_id = old.current_need_generation_run_id
           and successor.planning_input_set_id = predecessor.planning_input_set_id
           and successor.period_start = predecessor.period_start
           and successor.period_end = predecessor.period_end
           and successor.run_status = 'RELEASED_FOR_CONFIRMATION'
       ) then
      raise exception using errcode = '23514',
        message = 'Need Generation current source may advance only to the direct released successor';
    end if;
  end if;

  if not exists (
    with recursive source_chain as (
      select run.need_generation_run_id, run.predecessor_need_generation_run_id
      from atlas_planning.need_generation_runs run
      where run.need_generation_run_id = v_batch.current_need_generation_run_id
      union all
      select predecessor.need_generation_run_id, predecessor.predecessor_need_generation_run_id
      from atlas_planning.need_generation_runs predecessor
      join source_chain child
        on child.predecessor_need_generation_run_id = predecessor.need_generation_run_id
    )
    select 1 from source_chain
    where need_generation_run_id = v_batch.origin_need_generation_run_id
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation current source is outside the origin predecessor chain';
  end if;

  if exists (
    select 1
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id
      and (v_line_id is null or line.confirmed_need_line_id = v_line_id)
      and line.source_kind <> 'NEED_GENERATION'
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation stable lines must agree with the batch source kind';
  end if;

  if exists (
    with recursive source_chain as (
      select run.need_generation_run_id
      from atlas_planning.need_generation_runs run
      where run.need_generation_run_id = v_batch.current_need_generation_run_id
      union all
      select predecessor.need_generation_run_id
      from atlas_planning.need_generation_runs predecessor
      join atlas_planning.need_generation_runs child
        on child.predecessor_need_generation_run_id = predecessor.need_generation_run_id
      join source_chain chain
        on chain.need_generation_run_id = child.need_generation_run_id
    )
    select 1
    from atlas_planning.confirmed_need_line_revisions revision
    join atlas_planning.confirmed_need_lines line
      on line.confirmed_need_line_id = revision.confirmed_need_line_id
    where revision.confirmed_need_batch_id = v_batch_id
      and (v_line_id is null or revision.confirmed_need_line_id = v_line_id)
      and (
        revision.source_kind <> 'NEED_GENERATION'
        or revision.service_date is distinct from line.service_date
        or revision.customer_id is distinct from line.customer_id
        or revision.school_id is distinct from line.school_id
        or revision.delivery_location_id is distinct from line.delivery_location_id
        or revision.ingredient_id is distinct from line.ingredient_id
        or revision.unit_id is distinct from line.controlled_unit_id
        or not exists (
          select 1 from source_chain
          where source_chain.need_generation_run_id = revision.need_generation_run_id
        )
        or (
          revision.is_current and row(
            revision.need_generation_run_id,
            revision.need_generation_run_version,
            revision.need_generation_release_snapshot_id
          ) is distinct from row(
            v_batch.current_need_generation_run_id,
            v_batch.current_need_generation_run_version,
            v_batch.current_need_generation_release_snapshot_id
          )
        )
      )
  ) then
    raise exception using errcode = '23514',
      message = 'Need Generation revision source or operational identity is inconsistent';
  end if;

  if exists (
    select snapshot_line.need_generation_release_snapshot_line_id
    from atlas_planning.need_generation_release_snapshot_lines snapshot_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = snapshot_line.theoretical_need_line_id
    left join atlas_planning.confirmed_need_line_revision_contributions contribution
      on contribution.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
     and contribution.confirmed_need_batch_id = v_batch_id
     and contribution.need_generation_run_id = v_batch.current_need_generation_run_id
     and contribution.need_generation_run_version = v_batch.current_need_generation_run_version
     and contribution.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
    left join atlas_planning.confirmed_need_line_revisions revision
      on revision.confirmed_need_line_revision_id = contribution.confirmed_need_line_revision_id
     and revision.confirmed_need_batch_id = v_batch_id
     and revision.source_kind = 'NEED_GENERATION'
     and revision.is_current
     and revision.need_generation_run_id = v_batch.current_need_generation_run_id
     and revision.need_generation_run_version = v_batch.current_need_generation_run_version
     and revision.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
    where snapshot_line.need_generation_release_snapshot_id = v_batch.current_need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
        and theoretical.theoretical_quantity > 0
      and (v_line_id is null or exists (
        select 1
        from atlas_planning.confirmed_need_line_revision_contributions affected
        where affected.confirmed_need_batch_id = v_batch_id
          and affected.confirmed_need_line_id = v_line_id
          and affected.need_generation_release_snapshot_line_id = snapshot_line.need_generation_release_snapshot_line_id
      ))
    group by snapshot_line.need_generation_release_snapshot_line_id
    having count(revision.confirmed_need_line_revision_id) <> 1
  ) then
    raise exception using errcode = '23514',
      message = 'Current Need Generation revisions must exactly partition the active release';
  end if;

  return null;
end;
$function$;
reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.planning_contract_01_preflight_payload(period_start date, period_end date, supplied_candidates jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_payload jsonb:=atlas_core.direct_need_legacy_preflight_payload(
    period_start,period_end,supplied_candidates
  );
  v_direct jsonb;
  v_selected_snapshot uuid;
  v_current_snapshot uuid;
  v_current_run uuid;
  v_selected_fingerprint text;
  v_current_fingerprint text;
begin
  if period_start is distinct from period_end
    or v_payload->>'downstream_currentness'='LEGACY_OVERLAP'
  then return v_payload; end if;

  v_direct:=atlas_core.direct_need_current_complete_source(period_start);
  if v_direct is not null then
    v_payload:=jsonb_set(v_payload,'{direct_need_scopes}',(
      select coalesce(jsonb_agg(jsonb_build_object(
        'school_id',mode.school_id,'service_date',mode.service_date,
        'direct_need_mode',mode.direct_need_mode
      ) order by mode.school_id),'[]'::jsonb)
      from atlas_planning.pantry_need_approval_snapshot_school_date_modes mode
      where mode.pantry_need_approval_snapshot_id=(v_direct->>'pantry_need_approval_snapshot_id')::uuid
        and mode.service_date=period_start
    ),true);
    v_payload:=jsonb_set(v_payload,'{direct_need_source_mode}',
      case when v_payload#>>'{source_evidence,weekly_menu,selection_state}'='SELECTED'
        and v_payload#>>'{source_evidence,attendance,selection_state}'='SELECTED'
        then '"COMPOSED"'::jsonb else '"COMPLETE_ONLY"'::jsonb end,true);
    v_payload:=jsonb_set(v_payload,'{source_evidence,pantry,selection_state}','"SELECTED"'::jsonb,true);
    v_payload:=jsonb_set(v_payload,'{source_evidence,pantry,selected}',v_direct,true);
    if v_payload->>'direct_need_source_mode'='COMPLETE_ONLY' then
      v_payload:=jsonb_set(v_payload,'{source_evidence,weekly_menu}',
        jsonb_build_object('selection_state','NOT_REQUIRED','selected',null),true);
      v_payload:=jsonb_set(v_payload,'{source_evidence,attendance}',
        jsonb_build_object('selection_state','NOT_REQUIRED','selected',null),true);
      v_payload:=jsonb_set(v_payload,'{readiness_state}','"READY"'::jsonb,true);
      v_payload:=jsonb_set(v_payload,'{issues}','[]'::jsonb,true);
      v_payload:=jsonb_set(v_payload,'{blocking_issue_count}','0'::jsonb,true);
    end if;
  end if;

  v_selected_snapshot:=atlas_core.pa_05b_safe_uuid(
    v_payload#>>'{source_evidence,pantry,selected,pantry_need_approval_snapshot_id}'
  );
  v_selected_fingerprint:=atlas_core.direct_need_snapshot_fingerprint(
    v_selected_snapshot,period_start
  );
  v_current_run:=atlas_core.pa_05b_safe_uuid(
    v_payload#>>'{current_need,need_generation_run_id}'
  );
  v_current_snapshot:=atlas_core.pa_05b_safe_uuid(
    v_payload#>>'{current_need,pantry_need_approval_snapshot_id}'
  );
  v_current_fingerprint:=atlas_core.direct_need_snapshot_fingerprint(
    v_current_snapshot,period_start
  );
  v_payload:=jsonb_set(v_payload,'{direct_need_fingerprints}',
    jsonb_build_object('selected',v_selected_fingerprint,
      'current',v_current_fingerprint),true);

  if v_current_run is not null and v_selected_snapshot is not null then
    if v_selected_fingerprint is distinct from v_current_fingerprint then
      v_payload:=jsonb_set(v_payload,'{downstream_currentness}','"OUTDATED"'::jsonb,true);
    elsif v_payload#>>'{current_need,weekly_menu_id}' is null
      and v_payload#>>'{current_need,attendance_batch_id}' is null
    then
      v_payload:=jsonb_set(v_payload,'{downstream_currentness}','"CURRENT"'::jsonb,true);
    end if;
  end if;
  -- Retained v1 release is theoretical evidence until existing positive
  -- Confirmed Need authority has been corrected in the atomic boundary.
  if v_payload#>>'{current_need,requires_materialization}'='true' then
    v_payload := v_payload || jsonb_build_object('pending_materialization',
      v_payload->>'downstream_currentness'='CURRENT','downstream_currentness','OUTDATED');
  end if;
  if v_payload->>'downstream_currentness' = 'CURRENT' then
    v_payload := v_payload || jsonb_build_object('demand_state', v_payload#>'{current_need,demand_state}');
  end if;
  return v_payload;
end;
$function$;
reset role;
set role atlas_need_generation_runtime;
CREATE OR REPLACE FUNCTION atlas_core.planning_contract_01_current_need_payload(period_start date, period_end date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select pg_catalog.jsonb_build_object(
    'demand_state', case when exists (
      select 1 from atlas_planning.theoretical_need_lines line
      where line.need_generation_run_id=run.need_generation_run_id
        and line.line_disposition='ACTIVE' and line.theoretical_quantity>0
    ) then 'POSITIVE_DEMAND' else 'NO_DEMAND' end,
    'requires_materialization', batch.confirmed_need_batch_id is null and pending_batch.confirmed_need_batch_id is not null,
    'confirmed_need_batch_id', coalesce(batch.confirmed_need_batch_id,pending_batch.confirmed_need_batch_id),
    'confirmed_need_batch_status', coalesce(batch.batch_status,pending_batch.batch_status),
    'confirmed_need_batch_version', coalesce(batch.version,pending_batch.version),
    'need_generation_run_id', run.need_generation_run_id,
    'need_generation_run_version', run.version,
    'need_generation_run_status', run.run_status,
    'need_generation_release_snapshot_id',
      coalesce(batch.current_need_generation_release_snapshot_id, (select release.need_generation_release_snapshot_id from atlas_planning.need_generation_release_snapshots release where release.need_generation_run_id=run.need_generation_run_id)),
    'weekly_menu_id', snapshot.weekly_menu_id,
    'weekly_menu_version', snapshot.weekly_menu_version,
    'weekly_menu_approval_snapshot_id',
      snapshot.weekly_menu_approval_snapshot_id,
    'attendance_batch_id', snapshot.attendance_batch_id,
    'attendance_version', snapshot.attendance_version,
    'attendance_approval_snapshot_id',
      snapshot.attendance_approval_snapshot_id,
    'pantry_need_batch_id', snapshot.pantry_need_batch_id,
    'pantry_need_batch_version', snapshot.pantry_need_batch_version,
    'pantry_need_approval_snapshot_id',
      snapshot.pantry_need_approval_snapshot_id
  )
  from atlas_planning.need_generation_runs run
  left join atlas_planning.confirmed_need_batches batch
    on run.need_generation_run_id = batch.current_need_generation_run_id
   and batch.source_kind = 'NEED_GENERATION'
  left join lateral (
    select candidate.* from atlas_planning.confirmed_need_batches candidate
    where candidate.source_kind='NEED_GENERATION'
      and candidate.period_start=run.period_start and candidate.period_end=run.period_end
    order by candidate.updated_at desc,candidate.confirmed_need_batch_id limit 1
  ) pending_batch on batch.confirmed_need_batch_id is null
  join atlas_planning.need_generation_input_snapshots snapshot
    on snapshot.need_generation_run_id = run.need_generation_run_id
  where run.period_start = planning_contract_01_current_need_payload.period_start
    and run.period_end = planning_contract_01_current_need_payload.period_end
    and (batch.confirmed_need_batch_id is not null or (
      run.run_status = 'RELEASED_FOR_CONFIRMATION'
      and not exists (select 1 from atlas_planning.theoretical_need_lines line
        where line.need_generation_run_id=run.need_generation_run_id
          and line.line_disposition='ACTIVE' and line.theoretical_quantity>0)
      and exists (select 1 from atlas_planning.need_generation_release_snapshots release
        where release.need_generation_run_id=run.need_generation_run_id)

    ))
  order by run.attempt_ordinal desc, run.need_generation_run_id
  limit 1;
$function$;
CREATE OR REPLACE FUNCTION atlas_core.rmvp_04_workbench_payload(period_start date, period_end date, requested_run_id uuid DEFAULT NULL::uuid, filters jsonb DEFAULT '{}'::jsonb, group_offset integer DEFAULT 0, group_limit integer DEFAULT 100, detail_group jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_terminal atlas_planning.need_generation_runs%rowtype;
  v_selected atlas_planning.need_generation_runs%rowtype;
  v_confirmed atlas_planning.confirmed_need_batches%rowtype;
  v_groups jsonb := '[]'::jsonb;
  v_group_count bigint := 0;
  v_detail jsonb := '[]'::jsonb;
  v_history jsonb := '[]'::jsonb;
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_sources jsonb := '{}'::jsonb;
  v_materialization_mode text := 'NONE';
  v_can_materialize boolean := false;
  v_can_invalidate boolean := false;
  v_downstream_safe boolean := true;
  v_filter_date date := atlas_core.rmvp_04_safe_date(
    filters ->> 'service_date'
  );
  v_filter_school uuid := atlas_core.pa_05b_safe_uuid(
    filters ->> 'school_id'
  );
  v_filter_ingredient uuid := atlas_core.pa_05b_safe_uuid(
    filters ->> 'ingredient_id'
  );
  v_filter_family text := nullif(filters ->> 'contribution_family', '');
begin
  select input_set.* into v_set
  from atlas_planning.planning_input_sets as input_set
  where input_set.period_start = rmvp_04_workbench_payload.period_start
    and input_set.period_end = rmvp_04_workbench_payload.period_end;

  if v_set.planning_input_set_id is not null then
    select evaluation.* into v_evaluation
    from atlas_planning.planning_input_evaluations as evaluation
    where evaluation.planning_input_evaluation_id = v_set.current_evaluation_id;

    select run.* into v_terminal
    from atlas_planning.need_generation_runs as run
    where run.planning_input_set_id = v_set.planning_input_set_id
    order by run.attempt_ordinal desc
    limit 1;

    if requested_run_id is null then
      v_selected := v_terminal;
    else
      select run.* into v_selected
      from atlas_planning.need_generation_runs as run
      where run.need_generation_run_id = requested_run_id
        and run.planning_input_set_id = v_set.planning_input_set_id
        and run.period_start = rmvp_04_workbench_payload.period_start
        and run.period_end = rmvp_04_workbench_payload.period_end;
      if v_selected.need_generation_run_id is null then
        return pg_catalog.jsonb_build_object(
          'validation_error', 'FOREIGN_PERIOD_RUN'
        );
      end if;
    end if;

    v_sources := pg_catalog.jsonb_build_object(
      'weekly_menu', pg_catalog.jsonb_strip_nulls(
        pg_catalog.jsonb_build_object(
          'weekly_menu_id', v_evaluation.weekly_menu_id,
          'version', v_evaluation.weekly_menu_version,
          'approval_snapshot_id', v_evaluation.weekly_menu_approval_snapshot_id,
          'line_count', (
            select count(*)
            from atlas_planning.weekly_menu_approval_snapshot_lines as line
            where line.weekly_menu_approval_snapshot_id =
              v_evaluation.weekly_menu_approval_snapshot_id
          )
        )
      ),
      'attendance', pg_catalog.jsonb_strip_nulls(
        pg_catalog.jsonb_build_object(
          'attendance_batch_id', v_evaluation.attendance_batch_id,
          'version', v_evaluation.attendance_version,
          'approval_snapshot_id', v_evaluation.attendance_approval_snapshot_id,
          'line_count', (
            select count(*)
            from atlas_planning.attendance_approval_snapshot_lines as line
            where line.attendance_approval_snapshot_id =
              v_evaluation.attendance_approval_snapshot_id
          )
        )
      ),
      'pantry', pg_catalog.jsonb_strip_nulls(
        pg_catalog.jsonb_build_object(
          'pantry_need_batch_id', v_evaluation.pantry_need_batch_id,
          'version', v_evaluation.pantry_need_batch_version,
          'approval_snapshot_id', v_evaluation.pantry_need_approval_snapshot_id,
          'line_count', (
            select count(*)
            from atlas_planning.pantry_need_approval_snapshot_lines as line
            where line.pantry_need_approval_snapshot_id =
              v_evaluation.pantry_need_approval_snapshot_id
          )
        )
      )
    );

    select coalesce(pg_catalog.jsonb_agg(item order by ordinal desc), '[]'::jsonb)
    into v_history
    from (
      select run.attempt_ordinal as ordinal,
        pg_catalog.jsonb_build_object(
          'need_generation_run_id', run.need_generation_run_id,
          'attempt_ordinal', run.attempt_ordinal,
          'predecessor_need_generation_run_id',
            run.predecessor_need_generation_run_id,
          'status', run.run_status,
          'version', run.version,
          'generated_line_count', run.generated_line_count,
          'blocking_issue_count', run.blocking_issue_count,
          'warning_count', run.warning_count,
          'generated_at', run.generated_at,
          'validated_at', run.validated_at,
          'released_at', run.released_at,
          'invalidated_at', run.invalidated_at
        ) as item
      from atlas_planning.need_generation_runs as run
      where run.planning_input_set_id = v_set.planning_input_set_id
    ) as history;
  end if;

  if v_selected.need_generation_run_id is not null then
    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'need_generation_issue_id', issue.need_generation_issue_id,
        'issue_code', issue.issue_code,
        'message', issue.message,
        'school_id', issue.school_id,
        'service_date', issue.service_date,
        'ingredient_id', issue.ingredient_id,
        'unit_id', issue.unit_id,
        'theoretical_need_line_id', issue.theoretical_need_line_id
      ) order by issue.created_at, issue.need_generation_issue_id
    ), '[]'::jsonb)
    into v_blockers
    from atlas_planning.need_generation_issues as issue
    where issue.need_generation_run_id = v_selected.need_generation_run_id
      and issue.severity = 'BLOCKING';

    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'need_generation_issue_id', issue.need_generation_issue_id,
        'issue_code', issue.issue_code,
        'message', issue.message,
        'school_id', issue.school_id,
        'service_date', issue.service_date,
        'ingredient_id', issue.ingredient_id,
        'unit_id', issue.unit_id,
        'theoretical_need_line_id', issue.theoretical_need_line_id
      ) order by issue.created_at, issue.need_generation_issue_id
    ), '[]'::jsonb)
    into v_warnings
    from atlas_planning.need_generation_issues as issue
    where issue.need_generation_run_id = v_selected.need_generation_run_id
      and issue.severity = 'WARNING';

    select batch.* into v_confirmed
    from atlas_planning.confirmed_need_batches as batch
    where batch.source_kind = 'NEED_GENERATION'
      and (
        batch.current_need_generation_run_id = v_selected.need_generation_run_id
        or batch.origin_need_generation_run_id in (
          select chain.need_generation_run_id
          from atlas_planning.need_generation_runs as chain
          where chain.planning_input_set_id = v_selected.planning_input_set_id
        )
      )
    order by (
      batch.current_need_generation_run_id = v_selected.need_generation_run_id
    ) desc, batch.updated_at desc
    limit 1;

    with operational_lines as (
      select line.*,
        school.customer_id,
        school.school_name,
        coalesce(
          confirmed_revision.delivery_location_id,
          line.delivery_location_id,
          predecessor_contribution.delivery_location_id,
          school.default_delivery_location_id
        ) as effective_delivery_location_id
      from atlas_planning.theoretical_need_lines as line
      join atlas_admin.schools as school on school.school_id = line.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions as contribution
        on contribution.theoretical_need_line_id = line.theoretical_need_line_id
       and contribution.need_generation_run_id = line.need_generation_run_id
      left join atlas_planning.confirmed_need_line_revisions as confirmed_revision
        on confirmed_revision.confirmed_need_line_revision_id =
          contribution.confirmed_need_line_revision_id
      left join atlas_planning.confirmed_need_line_revision_contributions as predecessor_contribution
        on predecessor_contribution.confirmed_need_line_revision_contribution_id =
          atlas_core.zero_demand_predecessor_contribution(
            line.predecessor_theoretical_need_line_id,v_confirmed.confirmed_need_batch_id
          )
      where line.need_generation_run_id = v_selected.need_generation_run_id
        and (v_filter_date is null or line.service_date = v_filter_date)
        and (v_filter_school is null or line.school_id = v_filter_school)
        and (v_filter_ingredient is null or line.ingredient_id = v_filter_ingredient)
        and (v_filter_family is null or line.contribution_family = v_filter_family)
    ), grouped as (
      select line.service_date,
        line.customer_id,
        line.school_id,
        line.school_name,
        line.effective_delivery_location_id as delivery_location_id,
        location.location_name as delivery_location_name,
        line.ingredient_id,
        ingredient.ingredient_name,
        line.unit_id,
        unit.unit_name,
        sum(line.theoretical_quantity) as total_theoretical_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'RECIPE_DERIVED'
        ) as recipe_derived_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'PANTRY_DIRECT'
        ) as pantry_direct_quantity,
        count(*) filter (where line.line_disposition = 'ACTIVE') as active_count,
        count(*) filter (where line.line_disposition = 'REMOVED') as removed_count,
        (
          select count(*)
          from atlas_planning.need_generation_issues as issue
          where issue.need_generation_run_id = v_selected.need_generation_run_id
            and issue.severity = 'WARNING'
            and exists (
              select 1
              from operational_lines as issue_line
              where issue_line.theoretical_need_line_id =
                  issue.theoretical_need_line_id
                and issue_line.service_date = line.service_date
                and issue_line.customer_id = line.customer_id
                and issue_line.school_id = line.school_id
                and issue_line.effective_delivery_location_id =
                  line.effective_delivery_location_id
                and issue_line.ingredient_id = line.ingredient_id
                and issue_line.unit_id = line.unit_id
            )
        ) as warning_count
      from operational_lines as line
      join atlas_admin.delivery_locations as location
        on location.delivery_location_id = line.effective_delivery_location_id
      join atlas_admin.ingredients as ingredient
        on ingredient.ingredient_id = line.ingredient_id
      join atlas_admin.units as unit on unit.unit_id = line.unit_id
      group by line.service_date, line.customer_id, line.school_id,
        line.school_name, line.effective_delivery_location_id,
        location.location_name, line.ingredient_id, ingredient.ingredient_name,
        line.unit_id, unit.unit_name
    ), numbered as (
      select grouped.*, count(*) over () as total_count
      from grouped
    )
    select coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'service_date', page.service_date,
        'customer_id', page.customer_id,
        'school_id', page.school_id,
        'school_name', page.school_name,
        'delivery_location_id', page.delivery_location_id,
        'delivery_location_name', page.delivery_location_name,
        'ingredient_id', page.ingredient_id,
        'ingredient_name', page.ingredient_name,
        'unit_id', page.unit_id,
        'unit_name', page.unit_name,
        'total_theoretical_quantity', page.total_theoretical_quantity,
        'recipe_derived_quantity', coalesce(page.recipe_derived_quantity, 0),
        'pantry_direct_quantity', coalesce(page.pantry_direct_quantity, 0),
        'active_contribution_count', page.active_count,
        'removed_contribution_count', page.removed_count,
        'warning_count', page.warning_count
      ) order by page.service_date, page.school_name,
        page.delivery_location_name, page.ingredient_name, page.unit_name
    ), '[]'::jsonb), coalesce(max(page.total_count), 0)
    into v_groups, v_group_count
    from (
      select * from numbered
      order by service_date, school_name, delivery_location_name,
        ingredient_name, unit_name
      offset group_offset limit group_limit
    ) as page;

    if detail_group is not null then
      select coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_strip_nulls(pg_catalog.jsonb_build_object(
          'theoretical_need_line_id', line.theoretical_need_line_id,
          'contribution_family', line.contribution_family,
          'theoretical_quantity', line.theoretical_quantity,
          'unit_id', line.unit_id,
          'unit_name', unit.unit_name,
          'disposition', line.line_disposition,
          'dish_name', dish.dish_name,
          'recipe_id', line.recipe_id,
          'pantry_purpose', pantry.purpose_name_snapshot,
          'pantry_source_reference', pantry.source_request_reference,
          'warning_references', (
            select coalesce(pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'issue_code', issue.issue_code,
                'message', issue.message
              ) order by issue.created_at
            ), '[]'::jsonb)
            from atlas_planning.need_generation_issues as issue
            where issue.need_generation_run_id = line.need_generation_run_id
              and issue.theoretical_need_line_id = line.theoretical_need_line_id
              and issue.severity = 'WARNING'
          )
        )) order by line.contribution_family, line.theoretical_need_line_id
      ), '[]'::jsonb)
      into v_detail
      from atlas_planning.theoretical_need_lines as line
      join atlas_admin.schools as school on school.school_id = line.school_id
      join atlas_admin.units as unit on unit.unit_id = line.unit_id
      left join atlas_admin.dishes as dish on dish.dish_id = line.dish_id
      left join atlas_planning.pantry_need_approval_snapshot_lines as pantry
        on pantry.pantry_need_approval_snapshot_id =
          line.pantry_need_approval_snapshot_id
       and pantry.pantry_need_line_id = line.pantry_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions as contribution
        on contribution.theoretical_need_line_id = line.theoretical_need_line_id
       and contribution.need_generation_run_id = line.need_generation_run_id
      left join atlas_planning.confirmed_need_line_revisions as confirmed_revision
        on confirmed_revision.confirmed_need_line_revision_id =
          contribution.confirmed_need_line_revision_id
      left join atlas_planning.confirmed_need_line_revision_contributions as predecessor_contribution
        on predecessor_contribution.confirmed_need_line_revision_contribution_id =
          atlas_core.zero_demand_predecessor_contribution(
            line.predecessor_theoretical_need_line_id,v_confirmed.confirmed_need_batch_id
          )
      where line.need_generation_run_id = v_selected.need_generation_run_id
        and line.service_date = atlas_core.rmvp_04_safe_date(
          detail_group ->> 'service_date'
        )
        and line.school_id = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'school_id'
        )
        and coalesce(
          confirmed_revision.delivery_location_id,
          line.delivery_location_id,
          predecessor_contribution.delivery_location_id,
          school.default_delivery_location_id
        ) = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'delivery_location_id'
        )
        and line.ingredient_id = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'ingredient_id'
        )
        and line.unit_id = atlas_core.pa_05b_safe_uuid(
          detail_group ->> 'unit_id'
        );
    end if;

    if v_confirmed.confirmed_need_batch_id is not null then
      v_materialization_mode := case
        when v_confirmed.origin_need_generation_run_id =
          v_confirmed.current_need_generation_run_id then 'INITIAL'
        else 'CORRECTION'
      end;
    end if;

    v_can_materialize := v_selected.need_generation_run_id =
        v_terminal.need_generation_run_id
      and v_selected.run_status = 'RELEASED_FOR_CONFIRMATION'
      and (v_confirmed.confirmed_need_batch_id is not null or exists (
        select 1 from atlas_planning.theoretical_need_lines as line
        where line.need_generation_run_id=v_selected.need_generation_run_id
          and line.line_disposition='ACTIVE' and line.theoretical_quantity>0
      ))
      and (
        v_confirmed.confirmed_need_batch_id is null
        or (
          v_confirmed.current_need_generation_run_id <>
            v_selected.need_generation_run_id
          and v_confirmed.batch_status in ('DRAFT_REVIEW', 'REOPENED')
        )
      );

    if v_selected.run_status = 'RELEASED_FOR_CONFIRMATION'
      and v_confirmed.confirmed_need_batch_id is not null
    then
      v_downstream_safe := v_confirmed.batch_status in (
        'DRAFT_REVIEW', 'REOPENED'
      ) and not exists (
        select 1
        from atlas_planning.purchase_handoff_batches as handoff
        where handoff.confirmed_need_batch_id =
          v_confirmed.confirmed_need_batch_id
          and handoff.handoff_status not in ('INVALIDATED', 'REOPENED')
      );
    end if;
    v_can_invalidate := v_selected.need_generation_run_id =
      v_terminal.need_generation_run_id
      and v_selected.run_status in (
        'GENERATED', 'VALIDATED', 'RELEASED_FOR_CONFIRMATION'
      )
      and v_downstream_safe;
  end if;

  return pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object(
      'period_start', period_start, 'period_end', period_end
    ),
    'planning_input_set', case when v_set.planning_input_set_id is null
      then null else pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set.planning_input_set_id,
        'readiness_status', v_set.readiness_status,
        'current_evaluation_id', v_set.current_evaluation_id
      ) end,
    'current_evaluation', case when v_evaluation.planning_input_evaluation_id is null
      then null else pg_catalog.jsonb_build_object(
        'planning_input_evaluation_id',
          v_evaluation.planning_input_evaluation_id,
        'evaluation_version', v_evaluation.evaluation_version,
        'evaluation_result', v_evaluation.evaluation_result,
        'blocking_issue_count', v_evaluation.blocking_issue_count,
        'warning_count', v_evaluation.warning_count,
        'evaluated_at', v_evaluation.evaluated_at
      ) end,
    'source_evidence', v_sources,
    'terminal_run_id', v_terminal.need_generation_run_id,
    'selected_run', case when v_selected.need_generation_run_id is null
      then null else pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_selected.need_generation_run_id,
        'attempt_ordinal', v_selected.attempt_ordinal,
        'predecessor_need_generation_run_id',
          v_selected.predecessor_need_generation_run_id,
        'status', v_selected.run_status,
        'version', v_selected.version,
        'generated_line_count', v_selected.generated_line_count,
        'blocking_issue_count', v_selected.blocking_issue_count,
        'warning_count', v_selected.warning_count,
        'generated_at', v_selected.generated_at,
        'validated_at', v_selected.validated_at,
        'released_at', v_selected.released_at,
        'invalidated_at', v_selected.invalidated_at,
        'release_snapshot_id', (
          select release.need_generation_release_snapshot_id
          from atlas_planning.need_generation_release_snapshots as release
          where release.need_generation_run_id = v_selected.need_generation_run_id
        )
      ) end,
    'blocking_issues', v_blockers,
    'warnings', v_warnings,
    'grouped_requirements', v_groups,
    'atomic_detail', v_detail,
    'run_history', v_history,
    'materialization', pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id', v_confirmed.confirmed_need_batch_id,
      'confirmed_need_batch_version', v_confirmed.version,
      'confirmed_need_status', v_confirmed.batch_status,
      'materialization_mode', v_materialization_mode
    ),
    'allowed_actions', pg_catalog.jsonb_build_object(
      'create', coalesce(v_set.readiness_status = 'NEED_GENERATION_REQUESTED'
        and v_evaluation.evaluation_result = 'READY'
        and v_evaluation.blocking_issue_count = 0
        and (v_terminal.need_generation_run_id is null
          or v_terminal.run_status = 'INVALIDATED'), false),
      'validate', coalesce(v_selected.need_generation_run_id =
          v_terminal.need_generation_run_id
        and v_selected.run_status = 'GENERATED'
        and v_selected.blocking_issue_count = 0, false),
      'release', coalesce(v_selected.need_generation_run_id =
          v_terminal.need_generation_run_id
        and v_selected.run_status = 'VALIDATED'
        and v_selected.blocking_issue_count = 0, false),
      'materialize', coalesce(v_selected.need_generation_run_id =
          v_terminal.need_generation_run_id and v_can_materialize, false),
      'invalidate', coalesce(v_can_invalidate, false)
    ),
    'disabled_reasons', pg_catalog.jsonb_build_object(
      'create', case
        when v_set.planning_input_set_id is null
          or v_set.readiness_status <> 'NEED_GENERATION_REQUESTED'
          then 'Return to Sẵn sàng đầu vào and request Need Generation first.'
        when v_evaluation.evaluation_result <> 'READY'
          or v_evaluation.blocking_issue_count > 0
          then 'Planning Input Readiness must be READY without blockers.'
        when v_terminal.run_status <> 'INVALIDATED' then
          'The terminal Need Generation run is still active.'
        else null end,
      'validate', case
        when v_selected.run_status <> 'GENERATED'
          then 'Only the terminal generated run can be validated.'
        when v_selected.blocking_issue_count > 0
          then 'Resolve blocking issues through corrected source evidence.'
        else null end,
      'release', case
        when v_selected.run_status <> 'VALIDATED'
          then 'Validate the terminal run before release.'
        when v_selected.blocking_issue_count > 0
          then 'A run with blockers cannot be released.'
        else null end,
      'materialize', case
        when v_selected.run_status <> 'RELEASED_FOR_CONFIRMATION'
          then 'Release Need Generation before creating Confirmed Need.'
        when v_confirmed.confirmed_need_batch_id is null and not exists (
          select 1 from atlas_planning.theoretical_need_lines as line
          where line.need_generation_run_id=v_selected.need_generation_run_id
            and line.line_disposition='ACTIVE' and line.theoretical_quantity>0
        ) then 'Không có nhu cầu.'
        when v_confirmed.current_need_generation_run_id =
          v_selected.need_generation_run_id
          then 'This released run is already materialized.'
        when v_confirmed.confirmed_need_batch_id is not null
          and v_confirmed.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
          then 'Confirmed Need requires a separate controlled correction.'
        else null end,
      'invalidate', case
        when not v_downstream_safe
          then 'Downstream commitment requires a separate controlled correction.'
        when v_selected.run_status = 'INVALIDATED'
          then 'This run is already invalidated.'
        else null end
    ),
    'pagination', pg_catalog.jsonb_build_object(
      'offset', group_offset,
      'limit', group_limit,
      'total_groups', v_group_count,
      'has_more', group_offset + group_limit < v_group_count
    )
  );
end;
$function$;
CREATE OR REPLACE FUNCTION atlas_core.issue_223_execute_need_generation_v2(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_variable
declare
  v_name constant text := 'execute_need_generation';
  v_contract constant text := 'RMVP-04.v2';
  v_start date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_start'
  );
  v_end date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_end'
  );
  v_expected_run_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'expected_current_need_generation_run_id'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_preflight jsonb;
  v_terminal atlas_planning.need_generation_runs%rowtype;
  v_set atlas_planning.planning_input_sets%rowtype;
  v_evaluation atlas_planning.planning_input_evaluations%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_release atlas_planning.need_generation_release_snapshots%rowtype;
  v_stale_types jsonb := '[]'::jsonb;
  v_request_v1 jsonb;
  v_result jsonb;
  v_error jsonb;
  v_run_id uuid;
  v_run_version bigint;
  v_set_id uuid;
  v_evaluation_id uuid;
  v_evaluation_version bigint;
  v_recorded jsonb;
  v_response jsonb;
  v_adopt_released_zero boolean := false;
  v_bridge_receipt_id uuid;
  v_bridge_result jsonb;
begin
  if v_start is null or v_end is null or v_end < v_start
     or v_end - v_start + 1 > 14
     or (request -> 'payload') - array[
       'period_start', 'period_end',
       'expected_current_need_generation_run_id'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'period_start', 'period_end',
       'expected_current_need_generation_run_id'
     ])
     or (
       request -> 'payload' -> 'expected_current_need_generation_run_id'
         <> 'null'::jsonb
       and v_expected_run_id is null
     ) then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'VALIDATION_FAILED',
      'The atomic Need Generation payload is invalid.'
    ) || pg_catalog.jsonb_build_object('write_certainty','NO_COMMITTED_CHANGE');
  end if;
  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.need_generation.write',
    'need-generation:' || v_start::text || ':' || v_end::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    -- Only pre-execution rejections prove no write. Never rewrite a stored
    -- receipt replay or infer certainty for an in-progress command.
    if v_prepare#>>'{response,error_code}' in (
      'VALIDATION_FAILED','AUTHENTICATION_REQUIRED','AUTH_SUBJECT_MISMATCH',
      'ACTOR_NOT_FOUND','AUTH_SUBJECT_INACTIVE','ACTOR_INACTIVE',
      'DELEGATION_NOT_SUPPORTED','CAPABILITY_DENIED','SCOPE_DENIED'
    ) and not exists (select 1 from atlas_core.command_receipts receipt
      where receipt.command_id=atlas_core.pa_05b_safe_uuid(request->>'command_id')
        and receipt.response_payload = v_prepare->'response') then
      v_prepare := pg_catalog.jsonb_set(v_prepare,'{response,write_certainty}',
        '"NO_COMMITTED_CHANGE"'::jsonb,true);
    end if;
    return (v_prepare -> 'response') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  begin
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_receipt_id', v_receipt_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_actor_id', v_actor_id::text, true
    );
    perform pg_catalog.set_config(
      'atlas.planning_contract_01_command_name', v_name, true
    );
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'PLANNING-CONTRACT-01:' || v_start::text || ':' || v_end::text, 0
      )
    );

    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_start, v_end, null
    );
    if v_preflight ->> 'readiness_state' <> 'READY' then
      v_error := atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'PLANNING_INPUTS_NOT_READY',
        'Current completed Planning sources contain blocking issues.',
        '[]'::jsonb, v_preflight -> 'issues'
      );
      raise sqlstate 'PC104' using message = 'Planning preflight is blocked';
    end if;

    select run.* into v_terminal
    from atlas_planning.need_generation_runs run
    join atlas_planning.planning_input_sets input_set
      on input_set.planning_input_set_id = run.planning_input_set_id
    where input_set.period_start = v_start
      and input_set.period_end = v_end
    order by run.attempt_ordinal desc
    limit 1
    for update of run;

    if v_terminal.need_generation_run_id is null then
      if v_expected_run_id is not null
         or atlas_core.pa_05b_safe_bigint(
           request ->> 'expected_version'
         ) <> 1 then
        v_error := atlas_core.planning_contract_01_command_error(
          request, v_name, v_contract, 'STALE_VERSION',
          'No current Need Generation run exists for the reviewed period.'
        );
        raise sqlstate 'PC104' using message = 'Need Generation expectation is stale';
      end if;
    elsif v_expected_run_id is distinct from
        v_terminal.need_generation_run_id
      or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <>
        v_terminal.version then
      v_error := atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'STALE_VERSION',
        'The current Need Generation run changed after preflight.',
        '[]'::jsonb,
        pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
          'need_generation_run_id', v_terminal.need_generation_run_id,
          'run_status', v_terminal.run_status
        )), v_terminal.version
      );
      raise sqlstate 'PC104' using message = 'Need Generation version is stale';
    end if;

    select batch.* into v_batch from atlas_planning.confirmed_need_batches batch
    where batch.source_kind='NEED_GENERATION' and batch.period_start=v_start and batch.period_end=v_end
    order by batch.updated_at desc,batch.confirmed_need_batch_id limit 1 for update;
    v_adopt_released_zero := coalesce((v_preflight#>>'{current_need,requires_materialization}')::boolean,false)
      and v_terminal.run_status='RELEASED_FOR_CONFIRMATION'
      and v_batch.batch_status in ('DRAFT_REVIEW','REOPENED')
      and v_terminal.predecessor_need_generation_run_id=v_batch.current_need_generation_run_id;

    if v_preflight ->> 'downstream_currentness' = 'CURRENT'
       and not atlas_core.planning_legacy_adoption_regeneration_required(
         v_terminal.need_generation_run_id
       ) then
      v_response := pg_catalog.jsonb_build_object(
        'success', true, 'contract_version', v_contract,
        'command_id', request ->> 'command_id',
        'correlation_id', request ->> 'correlation_id',
        'idempotency_status', 'NO_CHANGE',
        'affected_aggregate_ids', pg_catalog.jsonb_build_object(
          'need_generation_run_id',
            v_preflight -> 'current_need' -> 'need_generation_run_id',
          'need_generation_release_snapshot_id',
            v_preflight -> 'current_need' ->
              'need_generation_release_snapshot_id',
          'confirmed_need_batch_id',
            v_preflight -> 'current_need' -> 'confirmed_need_batch_id'
        ),
        'new_versions', pg_catalog.jsonb_build_object(
          'need_generation_run_version',
            v_preflight -> 'current_need' -> 'need_generation_run_version',
          'confirmed_need_batch_version',
            v_preflight -> 'current_need' -> 'confirmed_need_batch_version'
        ),
        'emitted_event_ids', '[]'::jsonb,
        'audit_event_ids', '[]'::jsonb,
        'authoritative_readback', pg_catalog.jsonb_build_object(
          'preflight', v_preflight
        ),
        'downstream_currentness', 'CURRENT',
        'safe_operator_message',
          'Nhu cầu hiện tại đã khớp với toàn bộ dữ liệu nguồn.',
        'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
      );
      return atlas_core.planning_contract_01_finish_receipt(
        v_receipt_id, v_response, true
      );
    end if;

    if v_adopt_released_zero then
      v_run_id := v_terminal.need_generation_run_id;
      v_run_version := v_terminal.version;
    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'PA-06E-H0C.v1',
      coalesce(v_batch.version, 1),
      case when v_batch.confirmed_need_batch_id is null
        then 'CONFIRMED_NEED_MATERIALIZED'
        else 'CONFIRMED_NEED_CORRECTED' end,
      null,
      pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_run_id,
        'need_generation_run_version', v_run_version,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id
      )
    );
    if not coalesce((v_preflight->>'pending_materialization')::boolean,false) then
      -- Separate H0C receipt/event identity for the intermediate correction;
      -- both commands still roll back with the outer atomic transaction.
      v_request_v1 := v_request_v1 || pg_catalog.jsonb_build_object(
        'command_id',pg_catalog.md5((request->>'command_id')||':zero-bridge:'||v_run_id::text)::uuid,
        'idempotency_key','zero-bridge:'||pg_catalog.md5((request->>'command_id')||':'||(request->>'idempotency_key')||':'||v_run_id::text)
      );
      v_bridge_result := atlas_core.pa_05b_begin_command(v_request_v1,v_actor_id,
        'execute_need_generation','PLANNING','zero-bridge:'||v_run_id::text);
      if v_bridge_result->>'status'<>'NEW' then
        v_error := v_bridge_result->'response';
        raise sqlstate 'PC104' using message='Zero bridge receipt could not begin';
      end if;
      v_bridge_receipt_id := atlas_core.pa_05b_safe_uuid(v_bridge_result->>'receipt_id');
      perform pg_catalog.set_config('atlas.planning_contract_01_receipt_id',v_bridge_receipt_id::text,true);
    end if;
    v_result := atlas_core.planning_contract_01_materialize_confirmed_needs(
      v_request_v1
    );
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Confirmed Need materialization failed';
    end if;

    if v_bridge_receipt_id is not null then
      perform atlas_core.planning_contract_01_finish_receipt(v_bridge_receipt_id,v_result,true);
      perform pg_catalog.set_config('atlas.planning_contract_01_receipt_id',v_receipt_id::text,true);
    end if;

    -- Flush the private materializer's deferred cross-aggregate guards while
    -- the released run and its Confirmed Need pointer are mutually current.
    -- This keeps a later correction from rechecking an obsolete queued event
    -- after the predecessor has been deliberately invalidated.
    set constraints all immediate;
    set constraints all deferred;

    end if;
    if v_adopt_released_zero and coalesce((v_preflight->>'pending_materialization')::boolean,false) then
      -- Complete the pending direct correction with the released source itself;
      -- invalidating it would create an ambiguous indirect R3 successor.
      v_run_id := v_terminal.need_generation_run_id;
      v_run_version := v_terminal.version;
      v_set_id := v_terminal.planning_input_set_id;
      select snapshot.planning_input_evaluation_id into v_evaluation_id
      from atlas_planning.need_generation_input_snapshots snapshot
      where snapshot.need_generation_input_snapshot_id=v_terminal.input_snapshot_id;
    else
    if v_terminal.need_generation_run_id is not null
       and v_terminal.run_status <> 'INVALIDATED' then
      v_request_v1 := atlas_core.planning_contract_01_legacy_request(
        request, 'RMVP-04.v1', v_terminal.version,
        case when v_preflight ->> 'downstream_currentness' = 'CURRENT'
          then 'PLANNING_CORRECTION' else 'UPSTREAM_SOURCE_CHANGED' end,
        coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
          case when v_preflight ->> 'downstream_currentness' = 'CURRENT'
            then 'D-047 governed Recipe adoption correction; command ' || (request ->> 'command_id')
            else 'Dữ liệu nguồn hoàn tất đã thay đổi.' end),
        pg_catalog.jsonb_build_object(
          'need_generation_run_id', v_terminal.need_generation_run_id
        )
      );
      v_result := atlas_api.invalidate_need_generation_run(v_request_v1);
      if coalesce((v_result ->> 'success')::boolean, false) = false then
        v_error := v_result || pg_catalog.jsonb_build_object(
          'contract_version', v_contract, 'command_name', v_name
        );
        raise sqlstate 'PC104' using message = 'Prior generation invalidation failed';
      end if;
    end if;

    select input_set.* into v_set
    from atlas_planning.planning_input_sets input_set
    where input_set.period_start = v_start
      and input_set.period_end = v_end
    for update;
    if v_set.planning_input_set_id is not null then
      select evaluation.* into v_evaluation
      from atlas_planning.planning_input_evaluations evaluation
      where evaluation.planning_input_evaluation_id =
        v_set.current_evaluation_id;
      if v_set.readiness_status in ('READY', 'NEED_GENERATION_REQUESTED') then
        v_stale_types := atlas_core.rmvp_03b_stale_source_types(
          v_evaluation.planning_input_evaluation_id, v_start, v_end
        );
        v_request_v1 := pg_catalog.jsonb_build_object(
          'contract_version', 'RMVP-03B.v1',
          'command_id', request -> 'command_id',
          'correlation_id', request -> 'correlation_id',
          'idempotency_key', request -> 'idempotency_key',
          'requested_by_auth_subject', request -> 'requested_by_auth_subject',
          'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
          'expected_root_status', v_set.readiness_status,
          'expected_current_evaluation_id',
            v_evaluation.planning_input_evaluation_id,
          'expected_current_evaluation_version',
            v_evaluation.evaluation_version,
          'reason_code', case
            when pg_catalog.jsonb_array_length(v_stale_types) > 0
              then 'UPSTREAM_SOURCE_CHANGED'
            else 'PLANNING_REVIEW_CORRECTION' end,
          'reason_note', case
            when pg_catalog.jsonb_array_length(v_stale_types) > 0 then null
            else 'Tái đánh giá tự động trong lệnh tạo nhu cầu.' end,
          'payload', pg_catalog.jsonb_build_object(
            'planning_input_set_id', v_set.planning_input_set_id,
            'period_start', v_start, 'period_end', v_end
          )
        );
        v_result := atlas_api.invalidate_planning_input_readiness(v_request_v1);
        if coalesce((v_result ->> 'success')::boolean, false) = false then
          v_error := v_result || pg_catalog.jsonb_build_object(
            'contract_version', v_contract, 'command_name', v_name
          );
          raise sqlstate 'PC104' using message = 'Readiness invalidation failed';
        end if;
        select input_set.* into v_set
        from atlas_planning.planning_input_sets input_set
        where input_set.planning_input_set_id = v_set.planning_input_set_id;
      end if;
    end if;

    v_request_v1 := pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-03B.v1',
      'command_id', request -> 'command_id',
      'correlation_id', request -> 'correlation_id',
      'idempotency_key', request -> 'idempotency_key',
      'requested_by_auth_subject', request -> 'requested_by_auth_subject',
      'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
      'expected_root_status', coalesce(v_set.readiness_status, 'ABSENT'),
      'expected_current_evaluation_id', case
        when v_set.planning_input_set_id is null then null
        else v_set.current_evaluation_id end,
      'expected_current_evaluation_version', case
        when v_set.planning_input_set_id is null then null
        else (
          select evaluation.evaluation_version
          from atlas_planning.planning_input_evaluations evaluation
          where evaluation.planning_input_evaluation_id =
            v_set.current_evaluation_id
        ) end,
      'reason_code', 'READINESS_EVALUATION_REQUESTED',
      'reason_note', null,
      'payload', pg_catalog.jsonb_build_object(
        'period_start', v_start, 'period_end', v_end,
        'source_candidates', pg_catalog.jsonb_build_object(
          'weekly_menu', pg_catalog.jsonb_build_object(
            'weekly_menu_id', v_preflight -> 'source_evidence' ->
              'weekly_menu' -> 'selected' -> 'weekly_menu_id',
            'weekly_menu_version', v_preflight -> 'source_evidence' ->
              'weekly_menu' -> 'selected' -> 'weekly_menu_version',
            'weekly_menu_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'weekly_menu' ->
                'selected' -> 'weekly_menu_approval_snapshot_id'
          ),
          'attendance', pg_catalog.jsonb_build_object(
            'attendance_batch_id', v_preflight -> 'source_evidence' ->
              'attendance' -> 'selected' -> 'attendance_batch_id',
            'attendance_version', v_preflight -> 'source_evidence' ->
              'attendance' -> 'selected' -> 'attendance_version',
            'attendance_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'attendance' ->
                'selected' -> 'attendance_approval_snapshot_id'
          ),
          'pantry', pg_catalog.jsonb_build_object(
            'pantry_need_batch_id', v_preflight -> 'source_evidence' ->
              'pantry' -> 'selected' -> 'pantry_need_batch_id',
            'pantry_need_batch_version', v_preflight -> 'source_evidence' ->
              'pantry' -> 'selected' -> 'pantry_need_batch_version',
            'pantry_need_approval_snapshot_id',
              v_preflight -> 'source_evidence' -> 'pantry' ->
                'selected' -> 'pantry_need_approval_snapshot_id'
          )
        )
      )
    );
    if v_preflight ->> 'direct_need_source_mode' = 'COMPLETE_ONLY' then
      v_result := atlas_core.direct_need_prepare_evaluation(
        request,v_actor_id,v_start,v_end,v_preflight
      );
    else
      v_result := atlas_api.evaluate_planning_input_readiness(v_request_v1);
    end if;
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Readiness evaluation failed';
    end if;
    v_set_id := atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->> 'planning_input_set_id'
    );
    v_evaluation_id := atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->>
        'planning_input_evaluation_id'
    );
    v_evaluation_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'current_evaluation_version'
    );

    v_request_v1 := pg_catalog.jsonb_build_object(
      'contract_version', 'RMVP-03B.v1',
      'command_id', request -> 'command_id',
      'correlation_id', request -> 'correlation_id',
      'idempotency_key', request -> 'idempotency_key',
      'requested_by_auth_subject', request -> 'requested_by_auth_subject',
      'requested_at', pg_catalog.to_jsonb(pg_catalog.transaction_timestamp()),
      'expected_root_status', 'READY',
      'expected_current_evaluation_id', v_evaluation_id,
      'expected_current_evaluation_version', v_evaluation_version,
      'reason_code', 'NEED_GENERATION_HANDOFF_REQUESTED',
      'reason_note', null,
      'payload', pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set_id,
        'period_start', v_start, 'period_end', v_end
      )
    );
    v_result := atlas_api.request_planning_input_need_generation(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Readiness handoff failed';
    end if;

    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-04.v1', v_evaluation_version,
      'NEED_GENERATION_CREATED', null,
      pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set_id,
        'planning_input_evaluation_id', v_evaluation_id,
        'period_start', v_start, 'period_end', v_end
      )
    );
    v_result := atlas_api.create_need_generation_run(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Need Generation creation failed';
    end if;
    v_run_id := atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->> 'need_generation_run_id'
    );
    v_run_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'need_generation_run_version'
    );

    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-04.v1', v_run_version,
      'NEED_GENERATION_VALIDATED', null,
      pg_catalog.jsonb_build_object('need_generation_run_id', v_run_id)
    );
    v_result := atlas_api.validate_need_generation_run(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Need Generation integrity validation failed';
    end if;
    v_run_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'need_generation_run_version'
    );

    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'RMVP-04.v1', v_run_version,
      'NEED_GENERATION_RELEASED', null,
      pg_catalog.jsonb_build_object('need_generation_run_id', v_run_id)
    );
    v_result := atlas_api.release_need_generation_run(v_request_v1);
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Need Generation release failed';
    end if;
    v_run_version := atlas_core.pa_05b_safe_bigint(
      v_result -> 'new_versions' ->> 'need_generation_run_version'
    );

    end if;

    select batch.* into v_batch
    from atlas_planning.confirmed_need_batches batch
    where batch.source_kind = 'NEED_GENERATION'
      and batch.period_start = v_start and batch.period_end = v_end
    order by batch.updated_at desc, batch.confirmed_need_batch_id
    limit 1
    for update;
    if not (v_adopt_released_zero and coalesce((v_preflight->>'pending_materialization')::boolean,false)) then
    v_request_v1 := atlas_core.planning_contract_01_legacy_request(
      request, 'PA-06E-H0C.v1',
      coalesce(v_batch.version, 1),
      case when v_batch.confirmed_need_batch_id is null
        then 'CONFIRMED_NEED_MATERIALIZED'
        else 'CONFIRMED_NEED_CORRECTED' end,
      null,
      pg_catalog.jsonb_build_object(
        'need_generation_run_id', v_run_id,
        'need_generation_run_version', v_run_version,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id
      )
    );
    v_result := atlas_core.planning_contract_01_materialize_confirmed_needs(
      v_request_v1
    );
    if coalesce((v_result ->> 'success')::boolean, false) = false then
      v_error := v_result || pg_catalog.jsonb_build_object(
        'contract_version', v_contract, 'command_name', v_name
      );
      raise sqlstate 'PC104' using message = 'Confirmed Need materialization failed';
    end if;

    -- Flush the private materializer's deferred cross-aggregate guards while
    -- the released run and its Confirmed Need pointer are mutually current.
    -- This keeps a later correction from rechecking an obsolete queued event
    -- after the predecessor has been deliberately invalidated.
    set constraints all immediate;
    set constraints all deferred;

    end if;

    select run.* into v_run
    from atlas_planning.need_generation_runs run
    where run.need_generation_run_id = v_run_id;
    select release_snapshot.* into v_release
    from atlas_planning.need_generation_release_snapshots release_snapshot
    where release_snapshot.need_generation_run_id = v_run_id;
    select batch.* into v_batch
    from atlas_planning.confirmed_need_batches batch
    where batch.confirmed_need_batch_id = atlas_core.pa_05b_safe_uuid(
      v_result -> 'affected_aggregate_ids' ->> 'confirmed_need_batch_id'
    );
    v_recorded := atlas_core.rmvp_04_record_change(
      request, v_actor_id, v_receipt_id, 'NeedGenerationExecuted',
      v_run_id, v_run.version, v_run.version,
      pg_catalog.jsonb_build_object(
        'downstream_currentness',
          v_preflight ->> 'downstream_currentness'
      ),
      pg_catalog.jsonb_build_object(
        'run_status', v_run.run_status,
        'release_snapshot_id',
          v_release.need_generation_release_snapshot_id,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id,
        'confirmed_need_batch_version', v_batch.version
      )
    );
    v_preflight := atlas_core.planning_contract_01_preflight_payload(
      v_start, v_end, null
    );
    if v_preflight ->> 'downstream_currentness' <> 'CURRENT' then
      v_error := atlas_core.planning_contract_01_command_error(
        request, v_name, v_contract, 'INVARIANT_VIOLATION',
        'The committed Need result did not become current.'
      );
      raise sqlstate 'PC104' using message = 'Committed generation is not current';
    end if;
    v_response := pg_catalog.jsonb_build_object(
      'success', true, 'contract_version', v_contract,
      'command_id', request ->> 'command_id',
      'correlation_id', request ->> 'correlation_id',
      'idempotency_status', 'COMPLETED',
      'affected_aggregate_ids', pg_catalog.jsonb_build_object(
        'planning_input_set_id', v_set_id,
        'planning_input_evaluation_id', v_evaluation_id,
        'need_generation_run_id', v_run_id,
        'need_generation_release_snapshot_id',
          v_release.need_generation_release_snapshot_id,
        'confirmed_need_batch_id', v_batch.confirmed_need_batch_id
      ),
      'new_versions', pg_catalog.jsonb_build_object(
        'need_generation_run_version', v_run.version,
        'confirmed_need_batch_version', v_batch.version
      ),
      'result_counts', v_result -> 'result_counts',
      'emitted_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'domain_event_id'
      ),
      'audit_event_ids', pg_catalog.jsonb_build_array(
        v_recorded -> 'audit_event_id'
      ),
      'authoritative_readback', pg_catalog.jsonb_build_object(
        'preflight', v_preflight,
        'need_generation', atlas_core.rmvp_04_workbench_payload(
          v_start, v_end, v_run_id, '{}'::jsonb, 0, 100, null
        )
      ),
      'downstream_currentness', 'CURRENT',
      'safe_operator_message', case
        when v_preflight->>'demand_state'='NO_DEMAND' then 'Không có nhu cầu.'
        when v_terminal.need_generation_run_id is null
          then 'Đã tạo nhu cầu và Phiếu nhu cầu xác nhận trong một giao dịch.'
        else 'Đã cập nhật nhu cầu và hiệu chỉnh Phiếu nhu cầu xác nhận trong một giao dịch.'
      end,
      'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
    );
  exception when sqlstate 'PC104' then
    -- Exit the inner subtransaction AND the outer receipt-owning block.
    -- The outer concurrency handler returns the safe retryable envelope after
    -- PostgreSQL has rolled back the receipt and every nested business write.
    if v_error->>'retryable'='true'
       and v_error->>'error_code'='RETRYABLE_CONCURRENCY_FAILURE' then
      raise serialization_failure using message='Nested Planning transaction must be retried';
    end if;
    return atlas_core.planning_contract_01_finish_receipt(
      v_receipt_id, v_error || pg_catalog.jsonb_build_object('write_certainty','NO_COMMITTED_CHANGE'), false
    );
  end;
  return atlas_core.planning_contract_01_finish_receipt(
    v_receipt_id, v_response, true
  );
exception
  when serialization_failure or deadlock_detected
    or lock_not_available or query_canceled then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Need Generation could not acquire a safe transaction state. Retry the exact request.'
    ) || pg_catalog.jsonb_build_object('retryable',true,'write_certainty','NO_COMMITTED_CHANGE');
  when others then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
      'Need Generation could not be executed atomically.'
    ) || pg_catalog.jsonb_build_object('write_certainty','NO_COMMITTED_CHANGE');
end;
$function$;
reset role;
set role atlas_planning_command_runtime;
CREATE OR REPLACE FUNCTION atlas_core.issue_222_source_impact_payload(source_kind text, source_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_dates date[] := atlas_core.issue_222_affected_dates(
    source_kind, source_payload
  );
  v_date date;
  v_current_need jsonb;
  v_chains jsonb;
  v_policy text;
  v_action text;
  v_message text;
  v_items jsonb := '[]'::jsonb;
  v_allowed boolean := true;
  v_blocker text;
begin
  foreach v_date in array v_dates loop
    v_current_need := atlas_core.planning_contract_01_current_need_payload(v_date,v_date);
    select coalesce(pg_catalog.jsonb_agg(
      atlas_core.issue_222_chain_payload(run.need_generation_run_id)
      order by run.period_start, run.period_end, run.need_generation_run_id
    ), '[]'::jsonb) into v_chains
    from atlas_planning.need_generation_runs run
    where run.run_status <> 'INVALIDATED'
      and v_date between run.period_start and run.period_end;

    if pg_catalog.jsonb_array_length(v_chains) = 0 then
      v_policy := 'SAFE_NOT_GENERATED';
      v_action := 'SAVE_SOURCE';
      v_message := 'Có thể lưu thay đổi; ngày này chưa tạo Nhu cầu.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where (chain ->> 'later_downstream_commitment_exists')::boolean
    ) then
      v_policy := 'BLOCKED_BY_DOWNSTREAM_COMMITMENT';
      v_action := 'START_DOWNSTREAM_CORRECTION';
      v_message := 'Nhu cầu ngày này đã có cam kết vận hành phía sau; cần quy trình hiệu chỉnh riêng.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where (chain ->> 'active_purchase_handoff_exists')::boolean
    ) then
      v_policy := 'BLOCKED_BY_PURCHASE_HANDOFF';
      v_action := 'START_DOWNSTREAM_CORRECTION';
      v_message := 'Nhu cầu ngày này đã bàn giao cho Thu mua; cần hiệu chỉnh hạ nguồn riêng.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where coalesce(chain ->> 'confirmed_need_status', '')
        not in ('DRAFT_REVIEW', 'REOPENED')
        and not coalesce(
          chain->>'confirmed_need_batch_id' is null
          and chain->>'run_status'='RELEASED_FOR_CONFIRMATION'
          and chain->>'need_generation_run_id'=v_current_need->>'need_generation_run_id'
          and v_current_need->>'demand_state'='NO_DEMAND'
          and (v_current_need->>'confirmed_need_batch_id' is null or (v_current_need->>'requires_materialization'='true' and v_current_need->>'confirmed_need_batch_status' in ('DRAFT_REVIEW','REOPENED'))),false
        )
    ) then
      v_policy := 'PLANNING_RELEASE_CORRECTION_REQUIRED';
      v_action := 'PREPARE_PLANNING_CORRECTION';
      v_message := 'Nhu cầu đã được Kế hoạch cam kết; hãy mở lại cam kết trước khi lưu.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where (chain ->> 'is_legacy_range')::boolean
    ) then
      v_policy := 'LEGACY_RANGE_CORRECTION_REQUIRED';
      v_action := 'RETIRE_LEGACY_RANGE';
      v_message := 'Ngày này thuộc Nhu cầu nhiều ngày cũ; cần xử lý toàn bộ khoảng trước khi lưu.';
    else
      v_policy := 'SAFE_REGENERATE';
      v_action := 'CONFIRM_SAVE_THEN_REGENERATE';
      v_message := 'Lưu thay đổi sẽ làm Nhu cầu ngày này cần được tạo lại.';
    end if;

    if v_policy not in ('SAFE_NOT_GENERATED', 'SAFE_REGENERATE') then
      v_allowed := false;
      v_blocker := coalesce(v_blocker, v_policy);
    end if;
    v_items := v_items || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'service_date', v_date,
        'need_state', case
          when pg_catalog.jsonb_array_length(v_chains) = 0 then 'NOT_GENERATED'
          when exists (
            select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
            where (chain ->> 'is_legacy_range')::boolean
          ) then 'LEGACY_OVERLAP'
          else 'GENERATED' end,
        'confirmed_need_state', case
          when pg_catalog.jsonb_array_length(v_chains) = 0 then null
          when pg_catalog.jsonb_array_length(v_chains) = 1
            then v_chains -> 0 ->> 'confirmed_need_status'
          else 'MULTIPLE_CHAINS' end,
        'planning_release_occurred', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'planning_release_occurred')::boolean
        ),
        'purchase_handoff_exists', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'active_purchase_handoff_exists')::boolean
        ),
        'later_downstream_commitment_exists', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'later_downstream_commitment_exists')::boolean
        ),
        'legacy_overlap_exists', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'is_legacy_range')::boolean
        ),
        'correction_policy', v_policy,
        'safe_to_save', v_policy in ('SAFE_NOT_GENERATED', 'SAFE_REGENERATE'),
        'next_required_action', v_action,
        'operator_message', v_message,
        'chains', v_chains
      )
    );
  end loop;

  return pg_catalog.jsonb_build_object(
    'source_kind', pg_catalog.upper(source_kind),
    'material_change', pg_catalog.cardinality(v_dates) > 0,
    'affected_service_dates', to_jsonb(v_dates),
    'date_impacts', v_items,
    'save_allowed', v_allowed,
    'save_blocker_code', v_blocker
  );
end;
$function$;
reset role;
set role atlas_owner;
grant create on schema atlas_api to atlas_need_generation_runtime;
reset role;
set role atlas_need_generation_runtime;
CREATE OR REPLACE FUNCTION atlas_api.execute_need_generation(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET plan_cache_mode TO 'force_generic_plan'
AS $function$
declare
  v_contract text := request ->> 'contract_version';
  v_service_date date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'service_date'
  );
  v_period_start date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_start'
  );
  v_period_end date := atlas_core.rmvp_04_safe_date(
    request -> 'payload' ->> 'period_end'
  );
  v_v2_request jsonb;
  v_result jsonb;
  v_legacy_overlap jsonb;
  v_prior_compatibility text := pg_catalog.current_setting(
    'atlas.issue_223_period_compatibility', true
  );
begin
  if v_contract = 'RMVP-04.v2' then
    if v_period_start is not null
       and v_period_end is not null
       and v_period_start is distinct from v_period_end then
      return atlas_core.planning_contract_01_command_error(
        request, 'execute_need_generation', 'RMVP-04.v2',
        'MULTI_DAY_NEED_GENERATION_RETIRED',
        'Public multi-day Need Generation is retired; use one service date.'
      ) || pg_catalog.jsonb_build_object('write_certainty','NO_COMMITTED_CHANGE');
    end if;
    perform pg_catalog.set_config(
      'atlas.issue_223_period_compatibility', 'true', true
    );
    v_result := atlas_core.issue_223_execute_need_generation_v2(request);
    perform pg_catalog.set_config(
      'atlas.issue_223_period_compatibility',
      coalesce(v_prior_compatibility, ''), true
    );
    return v_result;
  end if;

  if v_contract is distinct from 'RMVP-04.v3'
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object'
     or v_service_date is null
     or (request -> 'payload') - array[
       'service_date', 'expected_current_need_generation_run_id'
     ] <> '{}'::jsonb
     or not (request -> 'payload' ?& array[
       'service_date', 'expected_current_need_generation_run_id'
     ]) then
    return atlas_core.planning_contract_01_command_error(
      request, 'execute_need_generation', 'RMVP-04.v3',
      'VALIDATION_FAILED',
      'The daily Need Generation payload is invalid.'
    ) || pg_catalog.jsonb_build_object('write_certainty','NO_COMMITTED_CHANGE');
  end if;

  v_v2_request := pg_catalog.jsonb_set(
    pg_catalog.jsonb_set(
      request, '{contract_version}', '"RMVP-04.v2"'::jsonb, true
    ),
    '{payload}',
    pg_catalog.jsonb_build_object(
      'period_start', v_service_date,
      'period_end', v_service_date,
      'expected_current_need_generation_run_id',
        request -> 'payload' -> 'expected_current_need_generation_run_id'
    ), true
  );
  v_result := atlas_core.issue_223_execute_need_generation_v2(v_v2_request);

  if v_result ->> 'error_code' = 'PLANNING_INPUTS_NOT_READY'
     and exists (
       select 1
       from pg_catalog.jsonb_array_elements(
         coalesce(
           v_result -> 'blocking_references', '[]'::jsonb
         )
       ) issue
       where issue ->> 'issue_code' =
         'ACTIVE_LEGACY_NEED_RANGE_OVERLAP'
     ) then
    select issue -> 'legacy_overlap'
    into v_legacy_overlap
    from pg_catalog.jsonb_array_elements(
      coalesce(
        v_result -> 'blocking_references', '[]'::jsonb
      )
    ) issue
    where issue ->> 'issue_code' = 'ACTIVE_LEGACY_NEED_RANGE_OVERLAP'
    limit 1;
    v_result := pg_catalog.jsonb_set(
      pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_result, '{error_code}',
          '"ACTIVE_LEGACY_NEED_RANGE_OVERLAP"'::jsonb, true
        ),
        '{safe_operator_message}',
        '"An active historical multi-day Need commitment contains this service date."'::jsonb,
        true
      ),
      '{legacy_overlap}', v_legacy_overlap, true
    );
  end if;

  return pg_catalog.jsonb_set(
    v_result, '{contract_version}', '"RMVP-04.v3"'::jsonb, true
  );
end;
$function$;
reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_need_generation_runtime;
reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_planning_materialization_runtime;
revoke create on schema atlas_core from atlas_read_runtime;
revoke create on schema atlas_core from atlas_need_generation_runtime;
revoke create on schema atlas_core from atlas_planning_command_runtime;
reset role;
-- Restore the exact existing role/schema access, including absent membership.
do $restore_access$
declare access record;
begin
 for access in select * from pg_temp.atlas_zero_demand_schema_access_before loop
  if not access.had_create then
   execute pg_catalog.format('revoke create on schema %I from %I',access.schema_name,access.role_name);
  else
   execute pg_catalog.format('grant create on schema %I to %I',access.schema_name,access.role_name);
  end if;
 end loop;
 for access in select * from pg_temp.atlas_zero_demand_runtime_access_before loop
  if access.admin_option is null then
   execute pg_catalog.format('revoke %I from postgres',access.rolname);
  else
   execute pg_catalog.format('grant %I to postgres with admin %s, inherit %s, set %s',
    access.rolname,case when access.admin_option then 'true' else 'false' end,
    case when access.inherit_option then 'true' else 'false' end,
    case when access.set_option then 'true' else 'false' end);
  end if;
 end loop;
end;
$restore_access$;
drop table pg_temp.atlas_zero_demand_schema_access_before;
drop table pg_temp.atlas_zero_demand_runtime_access_before;
