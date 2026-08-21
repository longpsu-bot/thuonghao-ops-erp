-- Issue #213: the normal RMVP-02A.v2 Recipe Save must make a newly
-- created Dish eligible for Planning in the same authoritative command.
-- create_dish remains DRAFT and the support lifecycle API remains callable.

create or replace function atlas_core.uiq03a_finish_success(
  request jsonb,
  p_actor_id uuid,
  p_receipt_id uuid,
  p_event_type text,
  p_recipe_version_id uuid,
  p_version_before bigint,
  p_version_after bigint,
  p_before_summary jsonb,
  p_after_summary jsonb,
  p_safe_message text,
  p_dish_id uuid,
  p_school_type_id uuid
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_recipe_events jsonb;
  v_dish_events jsonb;
  v_dish atlas_admin.dishes%rowtype;
  v_dish_activated boolean := false;
  v_response jsonb;
begin
  select dish.* into v_dish
  from atlas_admin.dishes dish
  where dish.dish_id = p_dish_id
  for update;

  if p_event_type = 'RecipeSaved' and v_dish.dish_status = 'DRAFT' then
    if not exists (
      select 1
      from atlas_admin.dish_types dish_type
      where dish_type.dish_type_id = v_dish.dish_type_id
        and dish_type.dish_type_status = 'ACTIVE'
    ) then
      raise exception using
        errcode = '23514',
        message = 'Issue 213 Dish activation requires an active Dish Type.';
    end if;

    update atlas_admin.dishes
    set dish_status = 'ACTIVE',
        version = version + 1,
        updated_at = pg_catalog.transaction_timestamp()
    where dish_id = p_dish_id
      and dish_status = 'DRAFT'
    returning * into v_dish;

    v_dish_activated := found;
    if v_dish_activated then
      v_dish_events := atlas_core.rmvp_01_record_change(
        request,
        p_actor_id,
        p_receipt_id,
        'DishActivated',
        'Dish',
        p_dish_id,
        v_dish.version - 1,
        v_dish.version,
        pg_catalog.jsonb_build_object(
          'dish_status', 'DRAFT',
          'dish_type_id', v_dish.dish_type_id
        ),
        pg_catalog.jsonb_build_object(
          'dish_status', 'ACTIVE',
          'dish_type_id', v_dish.dish_type_id,
          'activation_source', 'RMVP-02A.v2.save_recipe'
        )
      );
    end if;
  end if;

  v_recipe_events := atlas_core.rmvp_01_record_change(
    request,
    p_actor_id,
    p_receipt_id,
    p_event_type,
    'RecipeVersion',
    p_recipe_version_id,
    p_version_before,
    p_version_after,
    p_before_summary,
    p_after_summary
  );

  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02A.v2',
    'command_name', request ->> 'reason_code',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'dish_id', p_dish_id,
      'recipe_version_id', p_recipe_version_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version', p_version_after,
      'dish_version', v_dish.version
    ),
    'emitted_event_ids', case
      when v_dish_activated then pg_catalog.jsonb_build_array(
        v_dish_events -> 'domain_event_id',
        v_recipe_events -> 'domain_event_id'
      )
      else pg_catalog.jsonb_build_array(
        v_recipe_events -> 'domain_event_id'
      )
    end,
    'audit_event_ids', case
      when v_dish_activated then pg_catalog.jsonb_build_array(
        v_dish_events -> 'audit_event_id',
        v_recipe_events -> 'audit_event_id'
      )
      else pg_catalog.jsonb_build_array(
        v_recipe_events -> 'audit_event_id'
      )
    end,
    'authoritative_readback', atlas_core.uiq03a_workbench_payload(
      p_actor_id, p_dish_id, p_school_type_id
    ),
    'safe_operator_message', p_safe_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(p_receipt_id, v_response, true);
end;
$$;

alter function atlas_core.uiq03a_finish_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
  text, uuid, uuid
) owner to atlas_owner;

comment on function atlas_core.uiq03a_finish_success(
  jsonb, uuid, uuid, text, uuid, bigint, bigint, jsonb, jsonb,
  text, uuid, uuid
) is
  'RMVP-02A.v2 command finalizer. Recipe Save atomically activates an eligible DRAFT Dish with separate Dish and Recipe event/audit evidence; replay and already-ACTIVE Save do not repeat the lifecycle transition.';
