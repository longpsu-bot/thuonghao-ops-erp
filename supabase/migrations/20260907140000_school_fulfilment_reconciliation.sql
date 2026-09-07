-- Read-only School PO/PXK reconciliation at captured operational scope.

reset role;
grant atlas_owner,atlas_read_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core,atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

create function atlas_core.school_fulfilment_compare(p_po_lines jsonb,p_pxk_lines jsonb)
returns jsonb language sql immutable security definer set search_path='' as $$
  with po as (
    select (line->>'ingredient_id')::uuid ingredient_id,max(line->>'ingredient_name') ingredient_name,
      (line->>'unit_id')::uuid unit_id,max(line->>'unit_code') unit_code,
      sum((line->>'quantity')::numeric)::numeric(20,6) quantity
    from jsonb_array_elements(coalesce(p_po_lines,'[]'::jsonb)) line
    group by (line->>'ingredient_id')::uuid,(line->>'unit_id')::uuid
  ), pxk as (
    select (line->>'ingredient_id')::uuid ingredient_id,max(line->>'ingredient_name') ingredient_name,
      (line->>'unit_id')::uuid unit_id,max(line->>'unit_code') unit_code,
      sum((line->>'quantity')::numeric)::numeric(20,6) quantity
    from jsonb_array_elements(coalesce(p_pxk_lines,'[]'::jsonb)) line
    group by (line->>'ingredient_id')::uuid,(line->>'unit_id')::uuid
  ), detail as (
    select coalesce(po.ingredient_id,pxk.ingredient_id) ingredient_id,
      coalesce(po.ingredient_name,pxk.ingredient_name) ingredient_name,
      coalesce(po.unit_id,pxk.unit_id) unit_id,coalesce(po.unit_code,pxk.unit_code) unit_code,
      coalesce(po.quantity,0)::numeric(20,6) po_quantity,
      coalesce(pxk.quantity,0)::numeric(20,6) pxk_quantity,
      (coalesce(po.quantity,0)-coalesce(pxk.quantity,0))::numeric(20,6) delta_quantity,
      po.ingredient_id is not null po_present,pxk.ingredient_id is not null pxk_present
    from po full join pxk using(ingredient_id,unit_id)
  ), status as (
    select case when not exists(select 1 from po) then 'NO_PO'
      when not exists(select 1 from pxk) then 'NO_PXK'
      when exists(select 1 from detail where not po_present or not pxk_present)
        then 'INGREDIENT_CHANGED'
      when exists(select 1 from detail where po_quantity<>pxk_quantity) then 'MISMATCH'
      else 'OK' end comparison_status
  ), totals as (
    select unit_id,max(unit_code) unit_code,sum(po_quantity)::numeric(20,6) po_quantity,
      sum(pxk_quantity)::numeric(20,6) pxk_quantity,
      sum(delta_quantity)::numeric(20,6) delta_quantity from detail group by unit_id
  )
  select jsonb_build_object('comparison_status',(select comparison_status from status),
    'quantity_totals_by_unit',coalesce((select jsonb_agg(jsonb_build_object(
      'unit_id',unit_id,'unit_code',unit_code,'po_quantity',po_quantity::text,
      'pxk_quantity',pxk_quantity::text,'delta_quantity',delta_quantity::text)
      order by unit_code,unit_id) from totals),'[]'::jsonb),
    'details',coalesce((select jsonb_agg(jsonb_build_object(
      'ingredient_id',ingredient_id,'ingredient_name',ingredient_name,'unit_id',unit_id,
      'unit_code',unit_code,'po_quantity',po_quantity::text,
      'pxk_quantity',pxk_quantity::text,'delta_quantity',delta_quantity::text)
      order by ingredient_name,ingredient_id,unit_id) from detail),'[]'::jsonb));
$$;

create function atlas_core.school_fulfilment_reconciliation_scope(
  p_service_date date,p_school_id uuid,p_delivery_location_id uuid
) returns jsonb language sql stable security definer set search_path='' as $$
  with preview as materialized (select atlas_core.school_dispatch_release_preview(
    p_service_date,p_school_id,p_delivery_location_id) value),
  current_release as materialized (
    select release.* from atlas_dispatch.school_dispatch_releases release
    where release.service_date=p_service_date and release.school_id=p_school_id
      and release.delivery_location_id=p_delivery_location_id and release.release_status='RELEASED'
  ), po_lines as materialized (
    select jsonb_build_object('ingredient_id',line->>'ingredient_id',
      'ingredient_name',line->>'ingredient_name','unit_id',line->>'unit_id',
      'unit_code',line->>'unit_code','quantity',
      sum((source->>'covered_quantity')::numeric)::numeric(20,6)::text) value
    from preview cross join lateral jsonb_array_elements(preview.value->'lines') line
    cross join lateral jsonb_array_elements(line->'sources') source
    where source->>'purchase_order_id' is not null
    group by line->>'ingredient_id',line->>'ingredient_name',line->>'unit_id',line->>'unit_code'
  ), pxk_lines as materialized (
    select jsonb_build_object('ingredient_id',line.ingredient_id,
      'ingredient_name',line.ingredient_name_snapshot,'unit_id',line.unit_id,
      'unit_code',line.unit_code_snapshot,'quantity',line.quantity::text) value
    from current_release release join atlas_dispatch.school_dispatch_release_lines line
      on line.school_dispatch_release_id=release.school_dispatch_release_id
  ), comparison as materialized (select atlas_core.school_fulfilment_compare(
    coalesce((select jsonb_agg(value) from po_lines),'[]'::jsonb),
    coalesce((select jsonb_agg(value) from pxk_lines),'[]'::jsonb)) value),
  enriched_details as materialized (
    select coalesce(jsonb_agg(detail||jsonb_build_object(
      'purchase_order_ids',coalesce((select jsonb_agg(document.purchase_order_id
        order by document.document_number) from (
          select distinct po.purchase_order_id,po.document_number
          from preview
          cross join lateral jsonb_array_elements(preview.value->'lines') preview_line
          cross join lateral jsonb_array_elements(preview_line->'sources') source
          join atlas_procurement.purchase_orders po
            on po.purchase_order_id=(source->>'purchase_order_id')::uuid
          where preview_line->>'ingredient_id'=detail->>'ingredient_id'
            and preview_line->>'unit_id'=detail->>'unit_id') document),'[]'::jsonb),
      'school_dispatch_release_line_id',(select line.school_dispatch_release_line_id
        from current_release release
        join atlas_dispatch.school_dispatch_release_lines line
          on line.school_dispatch_release_id=release.school_dispatch_release_id
        where line.ingredient_id=(detail->>'ingredient_id')::uuid
          and line.unit_id=(detail->>'unit_id')::uuid)
    ) order by detail->>'ingredient_name',detail->>'ingredient_id',detail->>'unit_id'),
    '[]'::jsonb) value
    from comparison cross join lateral jsonb_array_elements(comparison.value->'details') detail
  ),
  po_documents as materialized (
    select distinct po.purchase_order_id,po.document_number
    from preview cross join lateral jsonb_array_elements(preview.value->'lines') line
    cross join lateral jsonb_array_elements(line->'sources') source
    join atlas_procurement.purchase_orders po
      on po.purchase_order_id=(source->>'purchase_order_id')::uuid
  ), operational as (
    select case when not (preview.value->>'ready')::boolean then 'BLOCKED'
      when not exists(select 1 from current_release) then 'READY'
      when (select source_fingerprint from current_release)=preview.value->>'source_fingerprint'
        then 'CURRENT' else 'REPLACEMENT_REQUIRED' end pxk_state from preview
  )
  select jsonb_build_object('service_date',p_service_date,'school_id',p_school_id,
    'school_name',preview.value->>'school_name','delivery_location_id',p_delivery_location_id,
    'delivery_location_name',preview.value->>'delivery_location_name',
    'comparison_status',comparison.value->>'comparison_status',
    'quantity_totals_by_unit',comparison.value->'quantity_totals_by_unit',
    'purchase_order_numbers',coalesce((select jsonb_agg(document_number order by document_number)
      from po_documents),'[]'::jsonb),
    'purchase_order_ids',coalesce((select jsonb_agg(purchase_order_id order by document_number)
      from po_documents),'[]'::jsonb),
    'pxk_document_number',(select document_number from current_release),
    'school_dispatch_release_id',(select school_dispatch_release_id from current_release),
    'pxk_state',(select pxk_state from operational),
    'blockers',preview.value->'blockers'||case
      when (select pxk_state from operational)='REPLACEMENT_REQUIRED'
        then jsonb_build_array('PXK_REPLACEMENT_REQUIRED') else '[]'::jsonb end,
    'warnings',preview.value->'warnings','details',enriched_details.value,
    'history',coalesce((select jsonb_agg(atlas_core.school_dispatch_release_json(
      history.school_dispatch_release_id) order by history.released_at desc)
      from atlas_dispatch.school_dispatch_releases history
      where history.service_date=p_service_date and history.school_id=p_school_id
        and history.delivery_location_id=p_delivery_location_id),'[]'::jsonb))
  from preview cross join comparison cross join enriched_details;
$$;

create function atlas_api.get_school_fulfilment_reconciliation_workbench(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_name constant text := 'get_school_fulfilment_reconciliation_workbench';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb;
  v_start date; v_end date; v_search text; v_rows jsonb;
begin
  if request is null or jsonb_typeof(request)<>'object'
     or request-array['contract_version','requested_by_auth_subject','correlation_id','payload']<>'{}'::jsonb
     or not (request ?& array['contract_version','requested_by_auth_subject','correlation_id','payload'])
     or request->>'contract_version' is distinct from 'SCHOOL-FULFILMENT-RECONCILIATION.v1'
     or atlas_core.pa_05b_safe_uuid(request->>'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
     or jsonb_typeof(request->'payload')<>'object'
     or (request->'payload')-array['date_start','date_end','school_ids','search']<>'{}'::jsonb
     or not (request->'payload' ?& array['date_start','date_end','school_ids','search'])
     or jsonb_typeof(request#>'{payload,school_ids}')<>'array' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Provide a valid bounded School fulfilment reconciliation scope.','DISPATCH',v_name);
  end if;
  begin
    v_start:=nullif(btrim(request#>>'{payload,date_start}'),'')::date;
    v_end:=nullif(btrim(request#>>'{payload,date_end}'),'')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The School fulfilment date range is invalid.','DISPATCH',v_name);
  end;
  v_search:=nullif(btrim(request#>>'{payload,search}'),'');
  if v_start is null or v_end is null or v_end<v_start or v_end-v_start>30
     or exists(select 1 from jsonb_array_elements_text(request#>'{payload,school_ids}') value
       where atlas_core.pa_05b_safe_uuid(value) is null) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Use an inclusive date range of at most 31 days and valid Schools.','DISPATCH',v_name);
  end if;
  v_actor:=atlas_core.pa_05b_resolve_actor(request,'DISPATCH',v_name);
  if v_actor ? 'error' then return v_actor->'error'; end if;
  v_actor_id:=atlas_core.pa_05b_safe_uuid(v_actor->>'actor_id');
  v_auth:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.read','DISPATCH',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;
  with confirmed_scopes as (
    select distinct (source.value->>'service_date')::date service_date,
      (contribution->>'school_id')::uuid school_id,
      (source.value->>'delivery_location_id')::uuid delivery_location_id
    from atlas_core.purchase_review_confirmed_sources(v_start,v_end) source(value)
    cross join lateral jsonb_array_elements(source.value->'contributions') contribution
  ), allocation_scopes as (
    select distinct confirmed.service_date,confirmed.school_id,confirmed.delivery_location_id
    from atlas_procurement.school_catering_allocation_family_revisions revision
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=revision.family_revision_id
      and contribution.purchase_handoff_line_revision_id is not null
    join atlas_planning.purchase_handoff_line_revisions handoff
      on handoff.purchase_handoff_line_revision_id=contribution.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions confirmed
      on confirmed.confirmed_need_line_revision_id=handoff.confirmed_need_line_revision_id
    where revision.is_current and revision.source_kind='PURCHASE_HANDOFF'
      and confirmed.service_date between v_start and v_end
  ), release_scopes as (
    select release.service_date,release.school_id,release.delivery_location_id
    from atlas_dispatch.school_dispatch_releases release
    where release.service_date between v_start and v_end and release.release_status='RELEASED'
  ), scopes as (
    select * from confirmed_scopes union select * from allocation_scopes union select * from release_scopes
  ), visible as (
    select scope.*,row.value from scopes scope cross join lateral (select
      atlas_core.school_fulfilment_reconciliation_scope(scope.service_date,
        scope.school_id,scope.delivery_location_id) value) row
    where atlas_core.school_catering_actor_has_scope(v_actor_id,null,scope.school_id,scope.delivery_location_id)
      and (jsonb_array_length(request#>'{payload,school_ids}')=0 or scope.school_id::text in
        (select jsonb_array_elements_text(request#>'{payload,school_ids}')))
  ), searched as (
    select * from visible where v_search is null
      or value->>'school_name' ilike '%'||v_search||'%'
      or value->>'delivery_location_name' ilike '%'||v_search||'%'
      or coalesce(value->>'pxk_document_number','') ilike '%'||v_search||'%'
      or (value->'purchase_order_numbers')::text ilike '%'||v_search||'%'
  )
  select coalesce(jsonb_agg(value order by service_date,value->>'school_name',school_id),
    '[]'::jsonb) into v_rows from searched;
  return jsonb_build_object('success',true,
    'contract_version','SCHOOL-FULFILMENT-RECONCILIATION.v1',
    'date_start',v_start,'date_end',v_end,'rows',v_rows,
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
exception when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_READ_FAILURE',
    'The School fulfilment reconciliation workbench could not be read safely.',
    'DISPATCH',v_name);
end;
$$;

revoke execute on function atlas_core.school_fulfilment_compare(jsonb,jsonb),
  atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function atlas_core.school_fulfilment_compare(jsonb,jsonb),
  atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid) to atlas_read_runtime;
revoke execute on function atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)
from public,anon,service_role;
grant execute on function atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)
to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_core,atlas_api from atlas_read_runtime;
reset role;
revoke atlas_read_runtime from postgres;
