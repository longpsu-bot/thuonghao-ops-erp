-- Reuse the installed proof within each existing statement, preserving lock phases.
do $replacement_proof$
declare definition text; family_pattern text; context_expression text; projection_anchor text;
begin
  definition:=pg_get_functiondef('atlas_api.create_school_catering_purchase_order_replacement(jsonb)'::regprocedure);
  context_expression:=$context$case when exists(
    select 1 from atlas_planning.confirmed_need_batches batch
    join atlas_planning.confirmed_need_lines line using(confirmed_need_batch_id)
    where batch.batch_status='REOPENED' and batch.released_at is not null
      and line.service_date=v_replaced.school_catering_service_date)
    then atlas_core.procurement_read_context(v_replaced.school_catering_service_date,v_replaced.school_catering_service_date)
    else '{"sources":[],"confirmed":{}}'::jsonb end$context$;
  projection_anchor:=$anchor$    cross join lateral (
      select atlas_core.school_catering_family_projection($anchor$;
  if regexp_count(definition,'cross join lateral \(')<>2
    or (length(definition)-length(replace(definition,projection_anchor,'')))/length(projection_anchor)<>2 then
    raise exception 'Replacement family statement anchors changed';
  end if;
  definition:=replace(definition,projection_anchor,
    '    cross join (with context as materialized (select '||context_expression||' value)
      select value from context) proof_context'||E'\n'||projection_anchor);
  family_pattern:='atlas_core\.school_catering_family_projection\([[:space:]]*f\.service_date,f\.delivery_location_id,f\.ingredient_id,f\.unit_id[[:space:]]*\)';
  if regexp_count(definition,family_pattern)<>2 then raise exception 'Replacement family proof anchors changed'; end if;
  definition:=regexp_replace(definition,family_pattern,
    'atlas_core.procurement_read_school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,proof_context.value)','g');
  if regexp_count(definition,'atlas_core.school_catering_po_date_readiness\(')<>1 then
    raise exception 'Replacement readiness anchor changed';
  end if;
  definition:=replace(definition,'atlas_core.school_catering_po_date_readiness('||E'\n    v_replaced.school_catering_service_date)',
    '(with context as materialized (select '||context_expression||' value)
      select atlas_core.procurement_read_school_catering_po_date_readiness(v_replaced.school_catering_service_date,context.value) from context)');
  if position('atlas_core.school_catering_po_date_readiness(' in definition)>0 then raise exception 'Replacement readiness substitution failed'; end if;
  execute definition;
end $replacement_proof$;
