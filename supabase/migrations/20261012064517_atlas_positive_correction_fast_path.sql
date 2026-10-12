-- Restore indexed positive predecessor identity; zero ancestry is a fallback.
-- Complete effective bodies from migration 101; no business-row rewrite.
-- Existing owners, grants, search paths, RLS, guards and timeouts are retained.
reset role;
create temporary table atlas_positive_runtime_access_before as
select role.rolname, membership.admin_option, membership.inherit_option, membership.set_option
from pg_catalog.pg_roles role left join pg_catalog.pg_auth_members membership
  on membership.roleid=role.oid and membership.member='postgres'::regrole
 and membership.grantor='postgres'::regrole
where role.rolname in ('atlas_planning_materialization_runtime','atlas_need_generation_runtime');
create temporary table atlas_positive_schema_access_before as
select role_name,pg_catalog.has_schema_privilege(role_name,'atlas_core','CREATE') as had_create
from (values ('atlas_planning_materialization_runtime'),('atlas_need_generation_runtime')) access(role_name);
grant atlas_planning_materialization_runtime to postgres with set true;
grant atlas_need_generation_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime;
grant create on schema atlas_core to atlas_need_generation_runtime;
reset role;
set role atlas_planning_materialization_runtime;
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
       and (
         old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
     and (
         old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
     and (
         old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
       and (
         old_contribution.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when new_theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = new_theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             new_theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
       and (
         old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when successor.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             successor.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
       and (
         old_contribution.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when successor.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = successor.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             successor.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
       and (
         old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
       and (
         old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
     and (
         old_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or old_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
        and (
         prior_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or prior_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
                and (
         predecessor_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or predecessor_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
              and (
         prior_contribution.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
         or prior_contribution.confirmed_need_line_revision_contribution_id = case
           when theoretical.predecessor_theoretical_need_line_id is null or v_batch_id is null then null
           when exists (
             select 1 from atlas_planning.theoretical_need_lines zero_predecessor
             where zero_predecessor.theoretical_need_line_id = theoretical.predecessor_theoretical_need_line_id
               and zero_predecessor.line_disposition = 'ACTIVE'
               and zero_predecessor.theoretical_quantity = 0
           ) then atlas_core.zero_demand_predecessor_contribution(
             theoretical.predecessor_theoretical_need_line_id, v_batch_id
           ) end
       )
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
           and predecessor_contribution.delivery_location_id is null
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
reset role;
set role atlas_need_generation_runtime;
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
          case when line.predecessor_theoretical_need_line_id is null or v_confirmed.confirmed_need_batch_id is null then null
          else coalesce(
          (select direct.confirmed_need_line_revision_contribution_id
           from atlas_planning.confirmed_need_line_revision_contributions direct
           join atlas_planning.confirmed_need_line_revisions direct_revision
             on direct_revision.confirmed_need_line_revision_id = direct.confirmed_need_line_revision_id
           where direct.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
             and direct.confirmed_need_batch_id = v_confirmed.confirmed_need_batch_id
           order by direct_revision.revision_number desc,
                    direct.confirmed_need_line_revision_contribution_id
           limit 1),
          case when exists (
            select 1 from atlas_planning.theoretical_need_lines zero_predecessor
            where zero_predecessor.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
              and zero_predecessor.line_disposition = 'ACTIVE'
              and zero_predecessor.theoretical_quantity = 0
          ) then atlas_core.zero_demand_predecessor_contribution(
            line.predecessor_theoretical_need_line_id, v_confirmed.confirmed_need_batch_id
          ) end
        ) end
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
          case when line.predecessor_theoretical_need_line_id is null or v_confirmed.confirmed_need_batch_id is null then null
          else coalesce(
          (select direct.confirmed_need_line_revision_contribution_id
           from atlas_planning.confirmed_need_line_revision_contributions direct
           join atlas_planning.confirmed_need_line_revisions direct_revision
             on direct_revision.confirmed_need_line_revision_id = direct.confirmed_need_line_revision_id
           where direct.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
             and direct.confirmed_need_batch_id = v_confirmed.confirmed_need_batch_id
           order by direct_revision.revision_number desc,
                    direct.confirmed_need_line_revision_contribution_id
           limit 1),
          case when exists (
            select 1 from atlas_planning.theoretical_need_lines zero_predecessor
            where zero_predecessor.theoretical_need_line_id = line.predecessor_theoretical_need_line_id
              and zero_predecessor.line_disposition = 'ACTIVE'
              and zero_predecessor.theoretical_quantity = 0
          ) then atlas_core.zero_demand_predecessor_contribution(
            line.predecessor_theoretical_need_line_id, v_confirmed.confirmed_need_batch_id
          ) end
        ) end
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
reset role;
-- Restore exact pre-migration role membership and schema privileges.
do $restore_access$
declare access record;
begin
 for access in select * from pg_temp.atlas_positive_schema_access_before loop
  if not access.had_create then
   execute pg_catalog.format('revoke create on schema atlas_core from %I',access.role_name);
  end if;
 end loop;
 for access in select * from pg_temp.atlas_positive_runtime_access_before loop
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
drop table pg_temp.atlas_positive_schema_access_before;
drop table pg_temp.atlas_positive_runtime_access_before;
