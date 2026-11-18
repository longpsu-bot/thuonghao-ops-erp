-- A metadata-only replacement on an adjusted quantity reuses its existing
-- quantity revision. Its before/after evidence comes from the current decision.
do $migration$
declare
  patch record;
  definition text;
begin
  for patch in select * from (values
    ('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure,
     '  v_kind text;', '  v_kind text;
  v_same_adjustment boolean;'),
    ('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure,
$old$    if v_quantity is not null and v_quantity = v_revision.confirmed_quantity then$old$,
$new$    v_same_adjustment := v_line.current_confirmed_need_line_decision_id is not null
      and v_decision.decision_kind = 'ADJUSTED_QUANTITY_CONFIRMED'
      and v_decision.confirmed_need_line_revision_id = v_revision.confirmed_need_line_revision_id
      and v_quantity = v_decision.confirmed_quantity_after
      and v_reason in ('PLANNING_STEP_ADJUSTMENT', 'OPERATIONAL_QUANTITY_ADJUSTMENT', 'OTHER');
    if v_quantity is not null and v_quantity = v_revision.confirmed_quantity and not v_same_adjustment then$new$),
    ('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure,
     $old$'proposed_quantity_before', v_revision.confirmed_quantity::text$old$,
     $new$'proposed_quantity_before', case when v_same_adjustment then v_decision.proposed_quantity_before else v_revision.confirmed_quantity end::text$new$),
    ('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure,
     $old$'successor_revision_required', v_kind = 'ADJUSTED_QUANTITY_CONFIRMED'$old$,
     $new$'successor_revision_required', v_kind = 'ADJUSTED_QUANTITY_CONFIRMED' and not v_same_adjustment$new$),
    ('atlas_api.save_confirmed_needs(jsonb)'::regprocedure,
     $old$where item->>'decision_kind' is distinct from 'ADJUSTED_QUANTITY_CONFIRMED'$old$,
     $new$where item->>'decision_kind' is distinct from 'ADJUSTED_QUANTITY_CONFIRMED'
        or (item->>'successor_revision_required')::boolean is not true$new$)
  ) as edits(target, original, replacement)
  loop
    definition := replace(pg_get_functiondef(patch.target), E'\r\n', E'\n');
    if cardinality(string_to_array(definition, patch.original)) <> 2 then
      raise exception 'Expected one metadata replacement anchor in %', patch.target;
    end if;
    execute replace(definition, patch.original, patch.replacement);
  end loop;
end;
$migration$;
