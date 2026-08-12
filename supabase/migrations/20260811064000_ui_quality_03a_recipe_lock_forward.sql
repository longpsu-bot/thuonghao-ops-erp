-- UI-QUALITY-03A forward-only Dish-wide Recipe lock correction.
--
-- The July RMVP-02A/RMVP-03A migrations are already applied on Atlas Staging
-- and therefore remain immutable. This migration adds the lock predicate,
-- serializes approved-Menu commitment with base Recipe mutation, and hardens
-- the still-callable RMVP-02A.v1 command boundary without rewriting history.

grant atlas_read_runtime, atlas_planning_command_runtime
  to atlas_owner with set true;
grant create on schema atlas_core
  to atlas_read_runtime, atlas_planning_command_runtime;

set role atlas_owner;

create or replace function atlas_core.uiq03a_dish_used_operationally(
  p_dish_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_planning.weekly_menu_approval_snapshot_lines menu_line
    where menu_line.dish_id = p_dish_id
  );
$$;

create or replace function atlas_core.uiq03a_rmvp_02a_target_dish_ids(
  request jsonb,
  command_name text
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_payload jsonb := request -> 'payload';
  v_document jsonb;
  v_ids uuid[] := '{}'::uuid[];
begin
  case command_name
    when 'update_dish', 'set_dish_lifecycle', 'create_recipe_draft' then
      v_ids := array[
        atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id')
      ];

    when 'set_recipe_lifecycle' then
      select array_agg(recipe.dish_id order by recipe.dish_id)
      into v_ids
      from atlas_admin.recipes recipe
      where recipe.recipe_id = atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'recipe_id'
      );

    when 'create_recipe_successor_version',
         'replace_recipe_draft_composition',
         'validate_recipe_version',
         'release_recipe_version_for_planning' then
      select array_agg(recipe.dish_id order by recipe.dish_id)
      into v_ids
      from atlas_admin.recipe_versions version
      join atlas_admin.recipes recipe
        on recipe.recipe_id = version.recipe_id
      where version.recipe_version_id = atlas_core.pa_05b_safe_uuid(
        v_payload ->> 'recipe_version_id'
      );

    when 'copy_recipe_version' then
      v_ids := array[
        atlas_core.pa_05b_safe_uuid(v_payload ->> 'target_dish_id')
      ];

    when 'apply_recipe_import' then
      begin
        v_document := (v_payload ->> 'canonical_json')::jsonb;
      exception when others then
        return '{}'::uuid[];
      end;

      if pg_catalog.jsonb_typeof(v_document -> 'rows') = 'array' then
        select array_agg(dish.dish_id order by dish.dish_id)
        into v_ids
        from atlas_admin.dishes dish
        join (
          select distinct pg_catalog.lower(
            pg_catalog.btrim(item ->> 'dish_code')
          ) as dish_code
          from pg_catalog.jsonb_array_elements(v_document -> 'rows') item
          where nullif(pg_catalog.btrim(item ->> 'dish_code'), '') is not null
        ) import_scope
          on import_scope.dish_code = dish.dish_code;
      end if;

    else
      -- create_dish and non-mutating/unrelated commands do not target an
      -- existing Dish identity and therefore do not participate in this guard.
      return '{}'::uuid[];
  end case;

  return coalesce(
    (
      select array_agg(distinct target.dish_id order by target.dish_id)
      from pg_catalog.unnest(coalesce(v_ids, '{}'::uuid[])) as target(dish_id)
      where target.dish_id is not null
    ),
    '{}'::uuid[]
  );
end;
$$;

create or replace function atlas_core.rmvp_02a_prepare_command(
  request jsonb,
  command_name text,
  capability_code text,
  aggregate_scope text
)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_dish_id uuid;
begin
  v_error := atlas_core.rmvp_02a_validate_command_request(
    request,
    command_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_error
    );
  end if;

  v_context := atlas_core.rmvp_01_authorize_global(
    request, capability_code, command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_context -> 'error'
    );
  end if;

  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request, v_actor_id, command_name, 'ADMIN', aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN', 'response', v_begin -> 'response'
    );
  end if;

  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  foreach v_dish_id in array
    atlas_core.uiq03a_rmvp_02a_target_dish_ids(request, command_name)
  loop
    -- Shared with the approved-Menu snapshot trigger below. The advisory lock
    -- is transaction-scoped, so a Recipe mutation and first committed Menu use
    -- for the same Dish cannot both cross the decision boundary concurrently.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_dish_id::text, 17403)
    );

    if atlas_core.uiq03a_dish_used_operationally(v_dish_id) then
      return pg_catalog.jsonb_build_object(
        'status', 'RETURN',
        'response', atlas_core.pa_05b_finish_command(
          v_receipt_id,
          atlas_core.pa_05b_command_error(
            request,
            'INVARIANT_VIOLATION',
            'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.',
            'ADMIN',
            command_name
          ),
          false
        )
      );
    end if;
  end loop;

  return pg_catalog.jsonb_build_object(
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.uiq03a_lock_weekly_menu_recipe_dishes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dish_id uuid;
begin
  -- Lock the whole active Dish set in deterministic UUID order on the first
  -- snapshot-line insert. Repeated row-trigger calls are transaction-reentrant.
  for v_dish_id in
    select distinct line.dish_id
    from atlas_planning.weekly_menu_lines line
    where line.weekly_menu_id = new.weekly_menu_id
      and line.line_status = 'ACTIVE'
    order by line.dish_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_dish_id::text, 17403)
    );
  end loop;

  return new;
end;
$$;

create trigger uiq03a_lock_recipe_dishes_on_menu_approval
before insert on atlas_planning.weekly_menu_approval_snapshot_lines
for each row
execute function atlas_core.uiq03a_lock_weekly_menu_recipe_dishes();

comment on function atlas_core.uiq03a_dish_used_operationally(uuid) is
  'UI-QUALITY-03A canonical Dish-wide lock predicate: true after the Dish appears in immutable approved Weekly Menu evidence.';
comment on function atlas_core.uiq03a_rmvp_02a_target_dish_ids(jsonb, text) is
  'UI-QUALITY-03A private resolver for existing Dish identities targeted by still-callable RMVP-02A base-mutation commands.';
comment on function atlas_core.uiq03a_lock_weekly_menu_recipe_dishes() is
  'UI-QUALITY-03A serializes first committed approved-menu use against base Dish/Recipe mutation using the same transaction advisory lock.';

revoke execute on function
  atlas_core.uiq03a_dish_used_operationally(uuid),
  atlas_core.uiq03a_rmvp_02a_target_dish_ids(jsonb, text),
  atlas_core.uiq03a_lock_weekly_menu_recipe_dishes()
from public, anon, authenticated, service_role;

grant execute on function
  atlas_core.uiq03a_dish_used_operationally(uuid),
  atlas_core.uiq03a_rmvp_02a_target_dish_ids(jsonb, text)
to atlas_master_data_command_runtime;

grant execute on function
  atlas_core.uiq03a_dish_used_operationally(uuid)
to atlas_read_runtime;

alter function atlas_core.uiq03a_dish_used_operationally(uuid)
  owner to atlas_read_runtime;
alter function atlas_core.uiq03a_rmvp_02a_target_dish_ids(jsonb, text)
  owner to atlas_read_runtime;
alter function atlas_core.uiq03a_lock_weekly_menu_recipe_dishes()
  owner to atlas_planning_command_runtime;

reset role;

revoke create on schema atlas_core
  from atlas_read_runtime, atlas_planning_command_runtime;

revoke atlas_read_runtime, atlas_planning_command_runtime from atlas_owner;
