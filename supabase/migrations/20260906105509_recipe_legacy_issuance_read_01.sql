-- RECIPE-LEGACY-ISSUANCE-READ-01: keep technical import provenance in the
-- immutable revision while exposing unavailable original business issuance as
-- null in the materially applicable effective Recipe history read.

set role atlas_owner;

create or replace function atlas_core.recipe_effective_history(
  reference_date date,
  target_school_id uuid,
  target_dish_id uuid,
  target_school_type_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_candidate_periods jsonb;
  v_relevant_adjustment_ids text[];
  v_period record;
  v_filtered_change_orders jsonb;
  v_current jsonb;
  v_last jsonb;
  v_merged_change_orders jsonb;
  v_periods jsonb := '[]'::jsonb;
begin
  v_candidate_periods :=
    atlas_core.recipe_effective_history_candidate_base(
      reference_date,
      target_school_id,
      target_dish_id,
      target_school_type_id
    );

  select pg_catalog.array_agg(distinct lineage.value ->> 'adjustment_id')
  into v_relevant_adjustment_ids
  from pg_catalog.jsonb_array_elements(
    coalesce(v_candidate_periods, '[]'::jsonb)
  ) period(value)
  cross join lateral pg_catalog.jsonb_array_elements(
    coalesce(period.value -> 'effective_bom', '[]'::jsonb)
  ) line(value)
  cross join lateral pg_catalog.jsonb_array_elements(
    coalesce(line.value -> 'lineage', '[]'::jsonb)
  ) lineage(value)
  where nullif(lineage.value ->> 'adjustment_id', '') is not null;

  for v_period in
    select period.value
    from pg_catalog.jsonb_array_elements(
      coalesce(v_candidate_periods, '[]'::jsonb)
    ) period(value)
    order by (period.value ->> 'period_from')::date
  loop
    select coalesce(
      pg_catalog.jsonb_agg(
        case
          when provenance.is_legacy_unattributed then
            change_order.value || pg_catalog.jsonb_build_object(
              'issuance_kind', 'LEGACY_UNATTRIBUTED',
              'issuer', null,
              'issued_at', null
            )
          else
            change_order.value || pg_catalog.jsonb_build_object(
              'issuance_kind', 'ATLAS_NATIVE'
            )
        end
        order by change_order.ordinality
      ),
      '[]'::jsonb
    )
    into v_filtered_change_orders
    from pg_catalog.jsonb_array_elements(
      coalesce(v_period.value -> 'change_orders', '[]'::jsonb)
    ) with ordinality change_order(value, ordinality)
    join atlas_admin.recipe_composition_adjustment_revisions revision
      on revision.recipe_composition_adjustment_revision_id =
        atlas_core.pa_05b_safe_uuid(change_order.value ->> 'revision_id')
    join lateral (
      select (
        revision.reason_code like 'LEGACY_%'
        or (
          revision.source_evidence ? 'historical_actor_approval_claimed'
          and coalesce(
            (
              revision.source_evidence
                ->> 'historical_actor_approval_claimed'
            )::boolean,
            false
          ) = false
        )
      ) as is_legacy_unattributed
    ) provenance on true
    where change_order.value ->> 'adjustment_id'
      = any(coalesce(v_relevant_adjustment_ids, array[]::text[]));

    v_current := pg_catalog.jsonb_set(
      v_period.value,
      '{change_orders}',
      v_filtered_change_orders
    );

    if v_last is null then
      v_last := v_current;
    elsif v_last -> 'effective_bom' = v_current -> 'effective_bom'
      and v_last ->> 'resolution_status'
        = v_current ->> 'resolution_status'
      and v_last -> 'blockers' = v_current -> 'blockers'
      and v_last -> 'warnings' = v_current -> 'warnings' then
      select coalesce(
        pg_catalog.jsonb_agg(
          evidence.value
          order by
            evidence.value ->> 'effective_from',
            (evidence.value ->> 'revision_number')::integer,
            evidence.value ->> 'adjustment_id'
        ),
        '[]'::jsonb
      )
      into v_merged_change_orders
      from (
        select distinct on (
          item.value ->> 'adjustment_id',
          item.value ->> 'revision_id'
        ) item.value
        from pg_catalog.jsonb_array_elements(
          coalesce(v_last -> 'change_orders', '[]'::jsonb)
          || coalesce(v_current -> 'change_orders', '[]'::jsonb)
        ) item(value)
        order by
          item.value ->> 'adjustment_id',
          item.value ->> 'revision_id'
      ) evidence;

      v_last := pg_catalog.jsonb_set(
        pg_catalog.jsonb_set(
          v_last,
          '{period_to}',
          coalesce(v_current -> 'period_to', 'null'::jsonb)
        ),
        '{change_orders}',
        v_merged_change_orders
      );
    else
      v_periods := v_periods || pg_catalog.jsonb_build_array(v_last);
      v_last := v_current;
    end if;
  end loop;

  if v_last is not null then
    v_periods := v_periods || pg_catalog.jsonb_build_array(v_last);
  end if;
  return v_periods;
end;
$$;

comment on function atlas_core.recipe_effective_history(
  date, uuid, uuid, uuid
) is 'RECIPE-EFFECTIVE.v1 materially applicable Dish history; legacy revisions without authoritative original attribution expose null business issuer/time while native revisions retain immutable Actor/time evidence.';

revoke execute on function
  atlas_core.recipe_effective_history(date, uuid, uuid, uuid)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.recipe_effective_history(date, uuid, uuid, uuid)
to atlas_read_runtime;

reset role;
