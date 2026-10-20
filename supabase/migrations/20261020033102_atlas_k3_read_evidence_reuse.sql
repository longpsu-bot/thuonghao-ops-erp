-- Owner #400: reuse identical evidence within each read statement only.
-- Owner also approved mixed-source PXK parity and the two source-lock helpers.
begin;

do $read_reuse$
declare
  target regprocedure;
  anchor text;
  definition text;
begin
  for target,anchor in values
    ('atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)'::regprocedure,
      'with base as ('),
    ('atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)'::regprocedure,
      'with shaped as ('),
    ('atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)'::regprocedure,
      '), visible as (')
  loop
    definition := pg_get_functiondef(target);
    if position(anchor in definition)=0 then
      raise exception 'K3 read evidence anchor changed: %',target;
    end if;
    execute replace(definition,anchor,replace(anchor,'as (','as materialized ('));
  end loop;

  target := 'atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)'::regprocedure;
  definition := pg_get_functiondef(target);
  anchor := $old$  select not exists(
    select 1
    from (
      select distinct po.school_catering_service_date service_date
      from atlas_procurement.purchase_orders po
      where po.purchase_order_kind='SCHOOL_CATERING'
        and po.school_catering_service_date between v_date_start and v_date_end
    ) scoped
    where not atlas_core.school_catering_procurement_date_current(scoped.service_date)
  ) into v_current;$old$;
  if position(anchor in definition)=0 then
    raise exception 'K3 distinct procurement date anchor changed';
  end if;
  execute replace(definition,anchor,$new$  with scoped as materialized (
    select distinct po.school_catering_service_date service_date
    from atlas_procurement.purchase_orders po
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date between v_date_start and v_date_end
  )
  select not exists(
    select 1 from scoped
    where not atlas_core.school_catering_procurement_date_current(scoped.service_date)
  ) into v_current;$new$);

  -- The same family proof is needed by both expected and actual membership.
  target := 'atlas_core.school_catering_po_draft_is_stale(uuid,uuid)'::regprocedure;
  definition := pg_get_functiondef(target);
  anchor := '  ), expected as (';
  if position(anchor in definition)=0 then
    raise exception 'K3 Draft expected membership anchor changed';
  end if;
  definition := replace(definition,anchor,$new$  ), projection_keys as (
    select f.family_id
    from root
    join atlas_procurement.school_catering_allocation_families f
      on f.service_date=root.school_catering_service_date
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
      and r.source_kind in ('PURCHASE_HANDOFF','CONFIRMED_NEED')
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id and s.supplier_id=root.supplier_id
    union
    select r.family_id
    from atlas_procurement.purchase_order_line_revisions polr
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.supplier_split_id=polr.school_catering_allocation_supplier_split_id
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_revision_id=s.family_revision_id
    where polr.purchase_order_revision_id=p_purchase_order_revision_id
  ), projections as materialized (
    select f.family_id,atlas_core.school_catering_family_projection(
      f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id) value
    from projection_keys keys
    join atlas_procurement.school_catering_allocation_families f using(family_id)
  ), expected as ($new$);
  anchor := $old$    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection$old$;
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2 then
    raise exception 'K3 Draft canonical projection call sites changed';
  end if;
  execute replace(definition,anchor,
    '    join projections projection on projection.family_id=f.family_id');
end $read_reuse$;

-- Owner #400/6283262062: deduplicate identities before canonical evaluation.
do $pxk_history_reuse$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure);
  anchor:=$old$  ), historical_commitments as materialized (
    select distinct atlas_core.school_catering_po_commitment_state(
      po.purchase_order_id,por.purchase_order_revision_id) commitment_state$old$;
  if position(anchor in definition)=0 then raise exception 'PXK history identity anchor changed'; end if;
  definition:=replace(definition,anchor,$new$  ), historical_purchase_orders as materialized (
    select distinct po.purchase_order_id,por.purchase_order_revision_id$new$);
  anchor:=$old$  ), state_base as ($old$;
  if position(anchor in definition)=0 then raise exception 'PXK history state anchor changed'; end if;
  execute replace(definition,anchor,$new$  ), historical_commitments as materialized (
    select distinct atlas_core.school_catering_po_commitment_state(
      po.purchase_order_id,po.purchase_order_revision_id) commitment_state
    from historical_purchase_orders po
  ), state_base as ($new$);
end $pxk_history_reuse$;

-- Corrected families retain exact K2 authority beside ordinary Handoff families.
do $pxk_corrected_sources$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure);
  anchor:='  ), contributions as materialized (';
  if position(anchor in definition)=0 then raise exception 'PXK contributions anchor changed'; end if;
  definition:=replace(definition,anchor,$new$  ), projections as materialized (
    select family.family_id,atlas_core.school_catering_family_projection(
      family.service_date,family.delivery_location_id,family.ingredient_id,family.unit_id) value
    from atlas_procurement.school_catering_allocation_families family
    where family.service_date=p_service_date and family.delivery_location_id=p_delivery_location_id
  ), contributions as materialized ($new$);
  anchor:=$old$    cross join lateral (
      select atlas_core.school_catering_family_projection(
        family.service_date,family.delivery_location_id,
        family.ingredient_id,family.unit_id) value
    ) projection$old$;
  if position(anchor in definition)=0 then raise exception 'PXK canonical projection anchor changed'; end if;
  definition:=replace(definition,anchor,
    '    join projections projection on projection.family_id=family.family_id');
  anchor:='  ), contribution_ranges as materialized (';
  if position(anchor in definition)=0 then raise exception 'PXK contribution ranges anchor changed'; end if;
  definition:=replace(definition,anchor,$new$    union all
    select contribution.family_contribution_id,contribution.contribution_quantity,
      revision.family_revision_id,revision.source_fingerprint,revision.family_quantity,
      family.ingredient_id,family.unit_id,confirmed_revision.school_id,
      contribution.confirmed_need_line_revision_id,contribution.confirmed_need_line_decision_id
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision
      on revision.family_id=family.family_id and revision.is_current
      and revision.source_kind='CONFIRMED_NEED'
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=revision.family_revision_id
      and contribution.purchase_handoff_line_revision_id is null
    join atlas_planning.confirmed_need_line_revisions confirmed_revision
      on confirmed_revision.confirmed_need_line_revision_id=contribution.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_lines confirmed_line
      on confirmed_line.confirmed_need_line_id=confirmed_revision.confirmed_need_line_id
    join projections projection on projection.family_id=family.family_id
    where family.service_date=p_service_date and family.delivery_location_id=p_delivery_location_id
      and confirmed_revision.service_date=p_service_date
      and confirmed_revision.delivery_location_id=p_delivery_location_id
      and confirmed_revision.ingredient_id=family.ingredient_id
      and confirmed_revision.unit_id=family.unit_id
      and confirmed_line.current_confirmed_need_line_decision_id=contribution.confirmed_need_line_decision_id
      and projection.value->>'complete'='true'
      and projection.value->>'corrected_source_eligible'='true'
      and projection.value->>'corrected_family'='true'
      and projection.value->>'source_kind'='CONFIRMED_NEED'
      and revision.source_confirmed_need_batch_id::text=projection.value->>'source_confirmed_need_batch_id'
      and revision.source_fingerprint=projection.value->>'source_fingerprint'
      and revision.family_quantity=atlas_core.pa_05b_safe_numeric(projection.value->>'family_quantity')
  ), contribution_ranges as materialized ($new$);
  anchor:='    join atlas_planning.purchase_handoff_line_revisions historical_handoff_line';
  if position(anchor in definition)=0 then raise exception 'PXK historical Handoff anchor changed'; end if;
  definition:=replace(definition,anchor,
    '    left join atlas_planning.purchase_handoff_line_revisions historical_handoff_line');
  anchor:='        historical_handoff_line.confirmed_need_line_revision_id';
  if position(anchor in definition)=0 then raise exception 'PXK historical Need anchor changed'; end if;
  definition:=replace(definition,anchor,$new$        coalesce(historical_contribution.confirmed_need_line_revision_id,
          historical_handoff_line.confirmed_need_line_revision_id)$new$);
  anchor:=$old$    select exists(select 1 from contribution_ranges where school_id=p_school_id)
        has_need,$old$;
  if position(anchor in definition)=0 then raise exception 'PXK current Need anchor changed'; end if;
  execute replace(definition,anchor,$new$    select exists(select 1 from contribution_ranges where school_id=p_school_id)
        and not exists(
          select 1 from atlas_procurement.school_catering_allocation_families family
          join atlas_procurement.school_catering_allocation_family_revisions revision
            on revision.family_id=family.family_id and revision.is_current
            and revision.source_kind='CONFIRMED_NEED'
          where family.service_date=p_service_date and family.delivery_location_id=p_delivery_location_id
            and (exists(select 1 from atlas_procurement.school_catering_allocation_family_contributions actual
              join atlas_planning.confirmed_need_line_revisions need
                on need.confirmed_need_line_revision_id=actual.confirmed_need_line_revision_id
              where actual.family_revision_id=revision.family_revision_id and need.school_id=p_school_id)
              or exists(select 1 from projections projection
                cross join lateral jsonb_array_elements(projection.value->'contributions') expected
                where projection.family_id=family.family_id and expected->>'school_id'=p_school_id::text))
            and (not exists(select 1 from contributions c where c.family_revision_id=revision.family_revision_id)
              or (select count(*) from contributions c where c.family_revision_id=revision.family_revision_id)
                <> (select count(*) from atlas_procurement.school_catering_allocation_family_contributions c
                  where c.family_revision_id=revision.family_revision_id))
        ) has_need,$new$);

  -- A first PXK scope may consist entirely of corrected families.
  definition:=pg_get_functiondef('atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)'::regprocedure);
  anchor:=$old$     and contribution.purchase_handoff_line_revision_id is not null
    join atlas_planning.purchase_handoff_line_revisions handoff$old$;
  if position(anchor in definition)=0 then raise exception 'PXK typed scope anchor changed'; end if;
  definition:=replace(definition,anchor,
    '    left join atlas_planning.purchase_handoff_line_revisions handoff');
  anchor:=$old$        handoff.confirmed_need_line_revision_id
    where revision.is_current and revision.source_kind='PURCHASE_HANDOFF'$old$;
  if position(anchor in definition)=0 then raise exception 'PXK scope Need identity anchor changed'; end if;
  execute replace(definition,anchor,$new$        coalesce(contribution.confirmed_need_line_revision_id,handoff.confirmed_need_line_revision_id)
    where revision.is_current and revision.source_kind in ('PURCHASE_HANDOFF','CONFIRMED_NEED')$new$);
end $pxk_corrected_sources$;

-- Explicit Owner approval: serialize source changes through PXK persistence.
do $pxk_source_locks$
declare definition text; anchor text;
begin
  definition:=pg_get_functiondef('atlas_core.purchase_review_lock_confirmed_source(uuid)'::regprocedure);
  anchor:='declare corrected boolean; preflight jsonb;';
  if position(anchor in definition)=0 then raise exception 'Need lock declaration anchor changed'; end if;
  definition:=replace(definition,anchor,
    'declare corrected boolean; preflight jsonb; locked_run uuid; locked_batch_run uuid;');
  anchor:=$old$  select batch_status='REOPENED' and released_at is not null into corrected
  from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch;
  if corrected then
    perform run.need_generation_run_id from atlas_planning.need_generation_runs run
    join atlas_planning.confirmed_need_batches batch
      on batch.current_need_generation_run_id=run.need_generation_run_id
    where batch.confirmed_need_batch_id=p_batch order by run.need_generation_run_id for share of run;
    perform 1 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch for update;$old$;
  if position(anchor in definition)=0 then raise exception 'Need run/batch lock anchor changed'; end if;
  definition:=replace(definition,anchor,$new$  select run.need_generation_run_id into locked_run
  from atlas_planning.need_generation_runs run
  join atlas_planning.confirmed_need_batches batch
    on batch.current_need_generation_run_id=run.need_generation_run_id
  where batch.confirmed_need_batch_id=p_batch for share of run;
  select current_need_generation_run_id,batch_status='REOPENED' and released_at is not null
    into locked_batch_run,corrected
  from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch for update;
  if locked_batch_run is distinct from locked_run then
    raise serialization_failure using message='Confirmed Need source changed while locking';
  end if;
  if corrected then$new$);
  anchor:=$old$  else
    perform 1 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch for update;
  end if;$old$;
  if position(anchor in definition)=0 then raise exception 'Need ordinary batch lock anchor changed'; end if;
  execute replace(definition,anchor,'  end if;');

  definition:=pg_get_functiondef('atlas_core.school_dispatch_lock_sources(date,uuid)'::regprocedure);
  anchor:=$old$begin
  perform 1$old$;
  if position(anchor in definition)=0 then raise exception 'PXK source lock anchor changed'; end if;
  execute replace(definition,anchor,$new$begin
  perform atlas_core.purchase_review_lock_confirmed_source(batch.confirmed_need_batch_id)
  from atlas_planning.confirmed_need_batches batch
  where batch.source_kind='NEED_GENERATION'
    and exists(select 1 from atlas_planning.confirmed_need_lines line
      where line.confirmed_need_batch_id=batch.confirmed_need_batch_id
        and line.service_date=p_service_date and line.delivery_location_id=p_delivery_location_id)
  order by batch.confirmed_need_batch_id;
  perform 1$new$);
end $pxk_source_locks$;

commit;
