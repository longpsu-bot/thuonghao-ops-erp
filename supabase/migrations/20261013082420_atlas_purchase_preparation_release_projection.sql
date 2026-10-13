-- Forward migration 105. Keep currentness checks; share only evidence resolved
-- by the backend inside default materialization, never browser-supplied facts.
begin;

grant atlas_procurement_command_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_procurement_command_runtime;
reset role;

do $narrow_source_sort$
declare
  target regprocedure := 'atlas_core.purchase_review_confirmed_sources(date,date)'::regprocedure;
  definition text := pg_get_functiondef(target);
  prior pg_proc%rowtype;
  updated pg_proc%rowtype;
begin
  select * into strict prior from pg_proc where oid=target;
  if position('b.evaluation,' in definition)=0
    or position('evaluation->>''outcome''' in definition)=0 then
    raise exception 'Confirmed source projection boundary mismatch';
  end if;
  -- The complete evaluation JSON was copied into each family sort tuple.
  definition:=replace(definition,
    'atlas_core.rmvp_06_canonical_evaluation(b.confirmed_need_batch_id) evaluation',
    'atlas_core.rmvp_06_canonical_evaluation(b.confirmed_need_batch_id)->>''outcome'' outcome');
  definition:=replace(replace(definition,'b.evaluation','b.outcome'),
    'evaluation->>''outcome''','outcome');
  execute definition;
  select * into strict updated from pg_proc where oid=target;
  if (to_jsonb(updated)-'prosrc') is distinct from (to_jsonb(prior)-'prosrc') then
    raise exception 'Source projection changed function catalog posture';
  end if;
end;
$narrow_source_sort$;

-- Preserve the exact readiness predicates in private overloads. Existing
-- one-argument callers still resolve fresh authoritative sources themselves.
do $resolved_readiness$
declare
  name text;
  definition text;
  original text;
  replacement text;
begin
  foreach name in array array['purchase_review_allocation_ready','purchase_review_preparation_allocation_ready'] loop
    definition:=pg_get_functiondef(format('atlas_core.%I(uuid)',name)::regprocedure);
    if name='purchase_review_allocation_ready' then
      original:='select p from atlas_core.purchase_review_confirmed_batch_sources(p_batch) p';
      replacement:='select p from pg_catalog.jsonb_array_elements(p_sources) source(p)
      where p->>''source_confirmed_need_batch_id''=p_batch::text';
    else
      original:='from atlas_core.purchase_review_confirmed_batch_sources(p_batch) source(value)';
      replacement:='from pg_catalog.jsonb_array_elements(p_sources) source(value)
    where value->>''source_confirmed_need_batch_id''=p_batch::text';
    end if;
    if (length(definition)-length(replace(definition,original,'')))/length(original)<>1 then
      raise exception 'Resolved readiness boundary mismatch: %',name;
    end if;
    definition:=replace(definition,'(p_batch uuid)','(p_batch uuid, p_sources jsonb)');
    execute replace(definition,original,replacement);
    execute format('alter function atlas_core.%I(uuid,jsonb) owner to atlas_procurement_command_runtime',name);
    execute format('revoke all on function atlas_core.%I(uuid,jsonb) from public,anon,authenticated,service_role',name);
  end loop;
end;
$resolved_readiness$;

-- Lock persisted supplier/allocation evidence, then let the existing fresh
-- readiness query prove source currentness. A successful readiness result
-- requires every positive source to have a current revision for this batch;
-- stale/missing/wrong-batch allocations still fail the unchanged predicate.
do $allocation_locks$
declare
  target regprocedure := 'atlas_core.purchase_review_lock_allocations(uuid)'::regprocedure;
  definition text := pg_get_functiondef(target);
  original text := $old$for p in select source.value from atlas_core.purchase_review_confirmed_batch_sources(p_batch) source(value)
    order by source.value->>'ingredient_id',source.value->>'service_date',source.value->>'delivery_location_id',source.value->>'unit_id' loop$old$;
  replacement text := $new$for p in
    select jsonb_build_object('ingredient_id',f.ingredient_id,'service_date',f.service_date,
      'delivery_location_id',f.delivery_location_id,'unit_id',f.unit_id,
      'splits',coalesce(jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id)
        order by s.supplier_id) filter(where s.supplier_id is not null),'[]'::jsonb))
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
    left join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
    where r.is_current and r.source_confirmed_need_batch_id=p_batch
    group by f.ingredient_id,f.service_date,f.delivery_location_id,f.unit_id
    order by f.ingredient_id::text,f.service_date::text,f.delivery_location_id::text,f.unit_id::text loop$new$;
  prior pg_proc%rowtype;
  updated pg_proc%rowtype;
begin
  select * into strict prior from pg_proc where oid=target;
  if (length(definition)-length(replace(definition,original,'')))/length(original)<>1 then
    raise exception 'Allocation lock boundary mismatch';
  end if;
  definition:=replace(definition,original,replacement);
  original:=$old$    select coalesce(jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id)),'[]') into v_splits
      from atlas_procurement.school_catering_allocation_families f
      join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
      join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
      where r.is_current and f.service_date=(p->>'service_date')::date
        and f.delivery_location_id=(p->>'delivery_location_id')::uuid
        and f.ingredient_id=(p->>'ingredient_id')::uuid and f.unit_id=(p->>'unit_id')::uuid;$old$;
  if (length(definition)-length(replace(definition,original,'')))/length(original)<>1 then
    raise exception 'Allocation supplier aggregation boundary mismatch';
  end if;
  execute replace(definition,original,'    v_splits:=p->''splits'';');
  select * into strict updated from pg_proc where oid=target;
  if (to_jsonb(updated)-'prosrc') is distinct from (to_jsonb(prior)-'prosrc') then
    raise exception 'Allocation lock changed function catalog posture';
  end if;
end;
$allocation_locks$;

do $default_readiness$
declare
  target regprocedure := 'atlas_core.purchase_review_materialize_default_allocations(uuid,uuid,uuid)'::regprocedure;
  definition text := pg_get_functiondef(target);
  prior pg_proc%rowtype;
  updated pg_proc%rowtype;
begin
  select * into strict prior from pg_proc where oid=target;
  if position('if not atlas_core.purchase_review_preparation_allocation_ready(p_batch) then' in definition)=0
    or position('if not atlas_core.purchase_review_allocation_ready(p_batch) then' in definition)=0 then
    raise exception 'Default readiness boundary mismatch';
  end if;
  definition:=replace(definition,
    'if not atlas_core.purchase_review_preparation_allocation_ready(p_batch) then',
    'if not atlas_core.purchase_review_preparation_allocation_ready(p_batch,sources) then');
  definition:=replace(definition,
    'if not atlas_core.purchase_review_allocation_ready(p_batch) then',
    '-- Refresh even when there were no generated defaults; existing allocations may have waited.
  if current_sources is null then
    current_sources:=atlas_core.purchase_review_confirmed_source_universe(p_batch);
  end if;
  if not atlas_core.purchase_review_allocation_ready(p_batch,current_sources) then');
  execute definition;
  select * into strict updated from pg_proc where oid=target;
  if (to_jsonb(updated)-'prosrc') is distinct from (to_jsonb(prior)-'prosrc') then
    raise exception 'Default readiness changed function catalog posture';
  end if;
end;
$default_readiness$;

set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime;
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
commit;
