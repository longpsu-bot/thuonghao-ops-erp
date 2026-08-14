-- UI-QUALITY-03B: additive operator-shaped Recipe Change Order read.
-- RMVP-02B.v1 reads and commands remain unchanged and callable.

grant atlas_read_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_read_runtime;
set role atlas_read_runtime;

create function atlas_core.uiq03b_recipe_adjustment_operator_payload(
  reference_date date
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with operator_recipe_lines as (
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'recipe_line_id', line.recipe_line_id,
          'recipe_id', line.recipe_id,
          'dish_id', recipe.dish_id,
          'school_type_id', recipe.school_type_id,
          'line_code', line.line_code,
          'ingredient_id', revision.ingredient_id,
          'ingredient_name', ingredient.ingredient_name,
          'quantity_per_basis', revision.quantity_per_basis,
          'unit_id', revision.unit_id,
          'unit_name', unit.unit_name
        )
        order by dish.dish_name, ingredient.ingredient_name,
          line.recipe_line_id
      ),
      '[]'::jsonb
    ) as payload
    from atlas_admin.recipe_lines line
    join atlas_admin.recipes recipe
      on recipe.recipe_id = line.recipe_id
     and recipe.recipe_status = 'ACTIVE'
    join atlas_admin.dishes dish
      on dish.dish_id = recipe.dish_id
    join atlas_admin.recipe_versions version
      on version.recipe_id = recipe.recipe_id
     and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
    join atlas_admin.recipe_line_revisions revision
      on revision.recipe_version_id = version.recipe_version_id
     and revision.recipe_line_id = line.recipe_line_id
     and revision.line_disposition = 'PRESENT'
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = revision.ingredient_id
    join atlas_admin.units unit
      on unit.unit_id = revision.unit_id
  ),
  rows as (
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'adjustment_id', root.recipe_composition_adjustment_id,
          'version', root.version,
          'current_revision_id', root.current_revision_id,
          'current_revision_number', root.current_revision_number,
          'can_correct', root.lifecycle_status = 'ACTIVE',
          'can_cancel',
            root.lifecycle_status = 'ACTIVE'
            and (
              current_revision.effective_to is null
              or reference_date < current_revision.effective_to
            ),
          'scope_kind', root.scope_kind,
          'action_kind', root.action_kind,
          'school_id', root.school_id,
          'dish_id', root.dish_id,
          'school_type_id', root.school_type_id,
          'target_ingredient_id', root.target_ingredient_id,
          'target_recipe_line_id', root.target_recipe_line_id,
          'adjustment_line_id', root.adjustment_line_id,
          'temporal_state',
            case
              when applicable.revision_status = 'CANCELLED'
                then 'CANCELLED'
              when applicable.revision_status = 'ACTIVE'
                   and expired_successor.has_expired_successor
                then 'ACTIVE_RESUMED'
              when applicable.revision_status = 'ACTIVE'
                   and future.revision_status = 'CANCELLED'
                then 'ACTIVE_CANCELLATION_SCHEDULED'
              when applicable.revision_status = 'ACTIVE'
                   and future.revision_status = 'ACTIVE'
                then 'ACTIVE_CHANGE_SCHEDULED'
              when applicable.revision_status = 'ACTIVE'
                then 'ACTIVE'
              when reference_date < first_revision.effective_from
                then 'SCHEDULED'
              else 'EXPIRED'
            end,
          'temporal_state_date',
            case
              when applicable.revision_status = 'ACTIVE'
                   and future.revision_status in ('ACTIVE', 'CANCELLED')
                then future.effective_from
              when applicable.revision_status is null
                   and reference_date < first_revision.effective_from
                then first_revision.effective_from
              else null
            end,
          'display_revision', pg_catalog.jsonb_build_object(
            'revision_id', display_revision.recipe_composition_adjustment_revision_id,
            'revision_status', display_revision.revision_status,
            'effective_from', display_revision.effective_from,
            'effective_to', display_revision.effective_to,
            'substitute_ingredient_id', display_revision.substitute_ingredient_id,
            'quantity_per_basis', display_revision.quantity_per_basis,
            'unit_id', display_revision.unit_id,
            'reason_note', display_revision.reason_note,
            'issued_at', display_revision.created_at,
            'issuance_kind',
              case
                when display_revision.reason_code like 'LEGACY_%'
                  or (
                    display_revision.source_evidence
                      ? 'historical_actor_approval_claimed'
                    and coalesce(
                      (
                        display_revision.source_evidence
                          ->> 'historical_actor_approval_claimed'
                      )::boolean,
                      false
                    ) = false
                  )
                  then 'LEGACY_UNATTRIBUTED'
                else 'ATLAS_NATIVE'
              end,
            'issued_by_actor_name',
              case
                when display_revision.reason_code like 'LEGACY_%'
                  or (
                    display_revision.source_evidence
                      ? 'historical_actor_approval_claimed'
                    and coalesce(
                      (
                        display_revision.source_evidence
                          ->> 'historical_actor_approval_claimed'
                      )::boolean,
                      false
                    ) = false
                  )
                  then null
                else display_actor.display_name
              end
          ),
          'command_revision', pg_catalog.jsonb_build_object(
            'revision_id', current_revision.recipe_composition_adjustment_revision_id,
            'effective_from', current_revision.effective_from,
            'effective_to', current_revision.effective_to,
            'substitute_ingredient_id', current_revision.substitute_ingredient_id,
            'quantity_per_basis', current_revision.quantity_per_basis,
            'unit_id', current_revision.unit_id,
            'reason_note', current_revision.reason_note
          ),
          'history', history.payload
        )
        order by display_revision.created_at desc,
          root.recipe_composition_adjustment_id
      ),
      '[]'::jsonb
    ) as payload
    from atlas_admin.recipe_composition_adjustments root
    join atlas_admin.recipe_composition_adjustment_revisions first_revision
      on first_revision.recipe_composition_adjustment_id =
        root.recipe_composition_adjustment_id
     and first_revision.revision_number = 1
    join atlas_admin.recipe_composition_adjustment_revisions current_revision
      on current_revision.recipe_composition_adjustment_revision_id =
        root.current_revision_id
    left join lateral (
      select revision.*
      from atlas_admin.recipe_composition_adjustment_revisions revision
      where revision.recipe_composition_adjustment_id =
          root.recipe_composition_adjustment_id
        and reference_date >= revision.effective_from
        and (
          revision.effective_to is null
          or reference_date < revision.effective_to
        )
      order by revision.revision_number desc
      limit 1
    ) applicable on true
    left join lateral (
      select revision.*
      from atlas_admin.recipe_composition_adjustment_revisions revision
      where revision.recipe_composition_adjustment_id =
          root.recipe_composition_adjustment_id
        and revision.effective_from > reference_date
      order by revision.effective_from, revision.revision_number
      limit 1
    ) future on true
    left join lateral (
      select exists (
        select 1
        from atlas_admin.recipe_composition_adjustment_revisions revision
        where revision.recipe_composition_adjustment_id =
            root.recipe_composition_adjustment_id
          and applicable.recipe_composition_adjustment_revision_id is not null
          and revision.revision_number > applicable.revision_number
          and revision.revision_status = 'ACTIVE'
          and revision.effective_to is not null
          and revision.effective_to <= reference_date
      ) as has_expired_successor
    ) expired_successor on true
    join lateral (
      select coalesce(
        applicable.recipe_composition_adjustment_revision_id,
        case
          when reference_date < first_revision.effective_from
            then first_revision.recipe_composition_adjustment_revision_id
          else current_revision.recipe_composition_adjustment_revision_id
        end
      ) as revision_id
    ) display_choice on true
    join atlas_admin.recipe_composition_adjustment_revisions display_revision
      on display_revision.recipe_composition_adjustment_revision_id =
        display_choice.revision_id
    join atlas_core.actors display_actor
      on display_actor.actor_id = display_revision.created_by_actor_id
    join lateral (
      select coalesce(
        pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'revision_id', revision.recipe_composition_adjustment_revision_id,
            'business_event_kind',
              case
                when revision.revision_status = 'CANCELLED' then 'CANCELLED'
                when revision.revision_number = 1 then 'CREATED'
                else 'CORRECTED'
              end,
            'effective_from', revision.effective_from,
            'effective_to', revision.effective_to,
            'substitute_ingredient_id', revision.substitute_ingredient_id,
            'quantity_per_basis', revision.quantity_per_basis,
            'unit_id', revision.unit_id,
            'reason_note', revision.reason_note,
            'issued_at', revision.created_at,
            'issuance_kind',
              case
                when revision.reason_code like 'LEGACY_%'
                  or (
                    revision.source_evidence
                      ? 'historical_actor_approval_claimed'
                    and coalesce(
                      (
                        revision.source_evidence
                          ->> 'historical_actor_approval_claimed'
                      )::boolean,
                      false
                    ) = false
                  )
                  then 'LEGACY_UNATTRIBUTED'
                else 'ATLAS_NATIVE'
              end,
            'issued_by_actor_name',
              case
                when revision.reason_code like 'LEGACY_%'
                  or (
                    revision.source_evidence
                      ? 'historical_actor_approval_claimed'
                    and coalesce(
                      (
                        revision.source_evidence
                          ->> 'historical_actor_approval_claimed'
                      )::boolean,
                      false
                    ) = false
                  )
                  then null
                else actor.display_name
              end
          )
          order by revision.revision_number desc
        ),
        '[]'::jsonb
      ) as payload
      from atlas_admin.recipe_composition_adjustment_revisions revision
      join atlas_core.actors actor
        on actor.actor_id = revision.created_by_actor_id
      where revision.recipe_composition_adjustment_id =
        root.recipe_composition_adjustment_id
    ) history on true
  )
  select (
    atlas_core.rmvp_02b_adjustment_workbench_payload()
      - 'adjustments'
      - 'recipe_lines'
  ) || pg_catalog.jsonb_build_object(
    'reference_date', reference_date,
    'recipe_lines', operator_recipe_lines.payload,
    'operator_rows', rows.payload
  )
  from operator_recipe_lines, rows;
$$;

create function atlas_api.get_recipe_adjustment_operator_workbench(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_recipe_adjustment_operator_workbench';
  v_validation_request jsonb;
  v_error jsonb;
  v_context jsonb;
  v_reference_date date;
begin
  if request is null
     or pg_catalog.jsonb_typeof(request) <> 'object'
     or request ->> 'contract_version' is distinct from 'RMVP-02B.v2' then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RMVP-02B.v2',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'The operator read requires RMVP-02B.v2.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'contract_version',
          'message', 'Use RMVP-02B.v2.'
        )
      ),
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  v_validation_request := request || pg_catalog.jsonb_build_object(
    'contract_version', 'RMVP-02B.v1'
  );
  v_error := atlas_core.rmvp_02b_validate_read_request(
    v_validation_request,
    v_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_set(
      v_error,
      '{contract_version}',
      '"RMVP-02B.v2"'::jsonb
    );
  end if;

  v_reference_date := atlas_core.rmvp_02b_safe_date(
    request -> 'payload' ->> 'as_of_date'
  );
  if v_reference_date is null then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'contract_version', 'RMVP-02B.v2',
      'error_code', 'VALIDATION_FAILED',
      'safe_message', 'An explicit valid reference date is required.',
      'domain', 'ADMIN',
      'read_name', v_name,
      'field_errors', pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.as_of_date',
          'message', 'A valid ISO date is required.'
        )
      ),
      'blocking_references', '[]'::jsonb,
      'correlation_id', request ->> 'correlation_id'
    );
  end if;

  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.recipe_adjustments.read',
    v_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_set(
      v_context -> 'error',
      '{contract_version}',
      '"RMVP-02B.v2"'::jsonb
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-02B.v2',
    'correlation_id', request ->> 'correlation_id',
    'workbench',
      atlas_core.uiq03b_recipe_adjustment_operator_payload(
        v_reference_date
      ),
    'safe_operator_message',
      'Authorized Recipe adjustment operator workbench returned.'
  );
exception when others then
  return pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-02B.v2',
    'error_code', 'INTERNAL_READ_FAILURE',
    'safe_message',
      'Recipe adjustment operator data could not be returned safely.',
    'domain', 'ADMIN',
    'read_name', v_name,
    'field_errors', '[]'::jsonb,
    'blocking_references', '[]'::jsonb,
    'correlation_id', request ->> 'correlation_id'
  );
end;
$$;

reset role;

alter function atlas_core.uiq03b_recipe_adjustment_operator_payload(date)
  owner to atlas_owner;
alter function atlas_api.get_recipe_adjustment_operator_workbench(jsonb)
  owner to atlas_read_runtime;

revoke create on schema atlas_core, atlas_api from atlas_read_runtime;

revoke execute on function
  atlas_core.uiq03b_recipe_adjustment_operator_payload(date)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.uiq03b_recipe_adjustment_operator_payload(date)
to atlas_read_runtime;

revoke execute on function
  atlas_api.get_recipe_adjustment_operator_workbench(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.get_recipe_adjustment_operator_workbench(jsonb)
to authenticated;

comment on function atlas_api.get_recipe_adjustment_operator_workbench(jsonb)
is 'RMVP-02B.v2 explicit-date operator read with server-derived temporal state, human-reference catalogs, issuance provenance, immutable business history, and internal command identity.';

revoke atlas_read_runtime from postgres;
