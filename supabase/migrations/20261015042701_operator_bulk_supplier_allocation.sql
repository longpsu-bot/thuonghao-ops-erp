-- Optional bulk Allocation orchestration; no source, commitment or scope policy changes.
begin;
reset role;
grant atlas_procurement_command_runtime to postgres with set true;
set role atlas_owner;
create function atlas_core.supplier_allocation_bulk_candidates(
  p_actor uuid,p_start date,p_end date,p_schools jsonb,p_impact boolean
) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare
  sources jsonb; source jsonb; advice jsonb; splits jsonb; proposed jsonb;
  schools jsonb; family jsonb; candidate jsonb; context jsonb; impact jsonb;
  result jsonb:='[]'; reason text; kind text; f record; r record; display record;
begin
  select coalesce(jsonb_agg(value),'[]') into sources
    from atlas_core.purchase_review_confirmed_sources(p_start,p_end) value;
  -- Retain Handoff only where no current Confirmed source owns the whole family.
  for source in
    select atlas_core.school_catering_family_projection(k.service_date,k.delivery_location_id,k.ingredient_id,k.unit_id)
      ||jsonb_build_object('source_kind','PURCHASE_HANDOFF','complete',true)
    from (select distinct h.service_date,h.delivery_location_id,h.ingredient_id,h.unit_id
      from atlas_planning.purchase_handoff_line_revisions h
      join atlas_planning.purchase_handoff_revisions rev using(purchase_handoff_revision_id)
      join atlas_planning.purchase_handoff_batches b using(purchase_handoff_batch_id)
      join atlas_planning.purchase_demand_references d using(purchase_handoff_line_revision_id)
      where rev.is_current and rev.revision_status='RELEASED_TO_PROCUREMENT'
        and b.handoff_status='RELEASED_TO_PROCUREMENT' and d.source_kind='NEED_GENERATION'
        and h.service_date between p_start and p_end) k
    where not exists(select 1 from jsonb_array_elements(sources) c
      where c->>'service_date'=k.service_date::text and c->>'delivery_location_id'=k.delivery_location_id::text
        and c->>'ingredient_id'=k.ingredient_id::text and c->>'unit_id'=k.unit_id::text)
  loop sources:=sources||jsonb_build_array(source); end loop;
  -- Canonical ambiguity is an exclusion, never duplicate applicable candidates.
  select coalesce(jsonb_agg(case when n=1 then variants->0 else (variants->0)||jsonb_build_object(
    'complete',false,'source_ambiguous',true,'family_quantity',null,'contributions',(
      select jsonb_agg(c) from jsonb_array_elements(variants) v,
        lateral jsonb_array_elements(v->'contributions') c)) end order by key),'[]') into sources
  from (select jsonb_build_array(value->'service_date',value->'delivery_location_id',value->'ingredient_id',value->'unit_id') key,
    count(*) n,jsonb_agg(value order by value::text) variants from jsonb_array_elements(sources) value
    group by 1) grouped;
  for source in select value from jsonb_array_elements(sources)
    order by value->>'service_date',value->>'delivery_location_id',value->>'ingredient_id',value->>'unit_id'
  loop
    if not atlas_core.school_catering_actor_has_scope(p_actor,null,null,(source->>'delivery_location_id')::uuid) then continue; end if;
    select x.* into f from atlas_procurement.school_catering_allocation_families x
      where x.service_date=(source->>'service_date')::date and x.delivery_location_id=(source->>'delivery_location_id')::uuid
        and x.ingredient_id=(source->>'ingredient_id')::uuid and x.unit_id=(source->>'unit_id')::uuid;
    select x.* into r from atlas_procurement.school_catering_allocation_family_revisions x where x.family_id=f.family_id and x.is_current;
    if r.source_kind='PURCHASE_HANDOFF' and source->>'batch_status'='RELEASED_FOR_PURCHASE_HANDOFF'
      and coalesce((source->>'complete')::boolean,false) then
      source:=source||atlas_core.school_catering_family_projection((source->>'service_date')::date,
        (source->>'delivery_location_id')::uuid,(source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid)
        ||jsonb_build_object('source_kind','PURCHASE_HANDOFF');
    end if;
    if source->>'source_kind'='PURCHASE_HANDOFF' then
      source:=jsonb_set(source,'{contributions}',(select coalesce(jsonb_agg(c||jsonb_build_object(
        'school_id',n.school_id,'customer_id',n.customer_id,
        'contribution_quantity',(c->>'contribution_quantity')::numeric(20,6)::text)
        order by c->>'purchase_handoff_line_revision_id'),'[]')
        from jsonb_array_elements(source->'contributions') c
        join atlas_planning.purchase_handoff_line_revisions h
          on h.purchase_handoff_line_revision_id=(c->>'purchase_handoff_line_revision_id')::uuid
        left join atlas_planning.confirmed_need_line_revisions nr using(confirmed_need_line_revision_id)
        left join atlas_planning.confirmed_need_lines n using(confirmed_need_line_id)));
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('school_id',s.school_id,'school_name',s.school_name)
      order by s.school_name,s.school_id),'[]') into schools from atlas_admin.schools s
      where exists(select 1 from jsonb_array_elements(source->'contributions') c where c->>'school_id'=s.school_id::text);
    if jsonb_array_length(p_schools)>0 and not exists(select 1 from jsonb_array_elements(schools) s
      where p_schools @> jsonb_build_array(s->>'school_id')) then continue; end if;
    advice:=atlas_core.purchase_review_supplier_advice((source->>'service_date')::date,
      (source->>'ingredient_id')::uuid,(source->>'family_quantity')::numeric);
    select coalesce(jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,'supplier_name',sp.supplier_name,
      'allocated_quantity',s.allocated_quantity::text,'split_ratio',s.split_ratio::text,'supplier_note',s.supplier_note)
      order by s.supplier_id),'[]') into splits from atlas_procurement.school_catering_allocation_supplier_splits s
      join atlas_admin.suppliers sp using(supplier_id) where s.family_revision_id=r.family_revision_id;
    kind:=null; proposed:=null;
    reason:=case when source->>'source_ambiguous'='true' then 'CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING'
      when not coalesce((source->>'complete')::boolean,false) then 'CONFIRMED_NEED_INCOMPLETE'
      when (source->>'family_quantity')::numeric<=0 then 'ZERO_QUANTITY'
      when jsonb_array_length(advice->'eligible_suppliers')=0 then 'NO_ELIGIBLE_SUPPLIER'
      when r.family_revision_id is null and advice->'recommendation'='null'::jsonb then 'NO_UNIQUE_PREFERRED_SUPPLIER'
      else 'EXISTING_DECISION_PRESERVED' end;
    if coalesce((source->>'complete')::boolean,false) and (source->>'family_quantity')::numeric>0
      and (source->>'source_kind'='PURCHASE_HANDOFF' or source->>'batch_status' in ('DRAFT_REVIEW','REOPENED','RELEASED_FOR_PURCHASE_HANDOFF')) then
      if r.family_revision_id is null and advice->'recommendation'<>'null'::jsonb then
        kind:='DEFAULT';
        proposed:=jsonb_build_array(jsonb_build_object('supplier_id',advice#>'{recommendation,supplier_id}',
          'allocated_quantity',(source->>'family_quantity')::numeric(20,6)::text,'supplier_note',null));
      elsif r.family_revision_id is not null and r.source_fingerprint<>source->>'source_fingerprint'
        and jsonb_array_length(splits)>0 and not exists(select 1 from jsonb_array_elements(splits) s
          where not exists(select 1 from jsonb_array_elements(advice->'eligible_suppliers') e where e->>'supplier_id'=s->>'supplier_id')) then
        kind:='REBALANCE';
        select jsonb_agg(jsonb_build_object('supplier_id',supplier_id,'supplier_note',note,
          'allocated_quantity',(case when rn=cnt then (source->>'family_quantity')::numeric-prior_total else qty end)::numeric(20,6)::text)
          order by supplier_id) into proposed from (
          select x.*,coalesce(sum(qty) filter(where rn<cnt) over(),0) prior_total from (
            select s->>'supplier_id' supplier_id,s->'supplier_note' note,
              round((source->>'family_quantity')::numeric*(s->>'split_ratio')::numeric,6) qty,
              row_number() over(order by s->>'supplier_id') rn,count(*) over() cnt from jsonb_array_elements(splits) s) x) y;
        if exists(select 1 from jsonb_array_elements(proposed) s where (s->>'allocated_quantity')::numeric<=0) then
          kind:=null; proposed:=null; reason:='NON_POSITIVE_SPLIT';
        end if;
      elsif exists(select 1 from jsonb_array_elements(splits) s where not exists(
        select 1 from jsonb_array_elements(advice->'eligible_suppliers') e where e->>'supplier_id'=s->>'supplier_id')) then
        reason:='SUPPLIER_NOT_ELIGIBLE';
      end if;
    end if;
    if jsonb_array_length(source->'contributions')=0 or exists(
      select 1 from jsonb_array_elements(source->'contributions') c
      where atlas_core.pa_05b_safe_uuid(c->>'school_id') is null) then
      kind:=null; proposed:=null; reason:='SCHOOL_LINEAGE_UNAVAILABLE';
    end if;
    family:=jsonb_build_object('service_date',source->'service_date','delivery_location_id',source->'delivery_location_id',
      'ingredient_id',source->'ingredient_id','unit_id',source->'unit_id','source_kind',source->'source_kind',
      'expected_family_version',coalesce(f.version,0),'expected_source_fingerprint',source->'source_fingerprint');
    if source->>'source_kind'='CONFIRMED_NEED' then family:=family||jsonb_build_object(
      'expected_source_batch_id',source->'source_confirmed_need_batch_id',
      'expected_source_batch_version',source->'source_confirmed_need_batch_version'); end if;
    context:=jsonb_build_object('family',family,'family_quantity',source->'family_quantity',
      'existing_splits',splits,'eligible_suppliers',advice->'eligible_suppliers','proposal_kind',kind,'proposed_splits',proposed);
    candidate:=case when kind is null then null else jsonb_build_object('family',family,'proposal_kind',kind,
      'proposed_splits',proposed,'proposal_fingerprint',md5(context::text)) end;
    select l.location_name,i.ingredient_name,
      case when nullif(btrim(u.unit_name),'') is not null and u.unit_name<>'?' and u.unit_name !~ '[[:cntrl:]]' and u.unit_name !~* '^(v1-unit-|atlas-unit-|[0-9a-f]{8}-)'
        then u.unit_name else 'Chưa có tên đơn vị' end unit_label into display
      from atlas_admin.delivery_locations l join atlas_admin.ingredients i on i.ingredient_id=(source->>'ingredient_id')::uuid
      join atlas_admin.units u on u.unit_id=(source->>'unit_id')::uuid
      where l.delivery_location_id=(source->>'delivery_location_id')::uuid;
    impact:='[]';
    if p_impact then
      select coalesce(jsonb_agg(jsonb_build_object('purchase_order_id',po.purchase_order_id,
        'document_number',po.document_number,'version',po.version,'status',po.purchase_order_status,
        'purchase_order_revision_id',rev.purchase_order_revision_id,'supplier_name',coalesce(nullif(btrim(rev.supplier_name_snapshot),''),'Chưa có tên NCC'),
        'commitment_state',atlas_core.school_catering_po_commitment_state(po.purchase_order_id,rev.purchase_order_revision_id),
        'lines',(select jsonb_agg(jsonb_build_object('ingredient_id',lr.ingredient_id,'unit_id',lr.unit_id,
          'ordered_quantity',lr.ordered_quantity::numeric(20,6)::text,'delivery_location_id',lr.delivery_location_id))
          from atlas_procurement.purchase_order_line_revisions lr join atlas_procurement.purchase_order_lines line using(purchase_order_line_id)
          where lr.purchase_order_revision_id=rev.purchase_order_revision_id and line.school_catering_allocation_family_id=f.family_id))
        order by po.purchase_order_id),'[]') into impact
      from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev
        on rev.purchase_order_id=po.purchase_order_id and rev.is_current
      where po.purchase_order_kind='SCHOOL_CATERING'
        and atlas_core.school_catering_purchase_order_actor_has_full_scope(p_actor,po.purchase_order_id)
        and exists(select 1 from atlas_procurement.purchase_order_line_revisions lr
          join atlas_procurement.purchase_order_lines line using(purchase_order_line_id)
          where lr.purchase_order_revision_id=rev.purchase_order_revision_id
            and line.school_catering_allocation_family_id=f.family_id);
    end if;
    result:=result||jsonb_build_array(source||to_jsonb(display)||jsonb_build_object(
      'family_quantity',case when source->>'family_quantity' is null then null else (source->>'family_quantity')::numeric(20,6)::text end,
      'schools',schools,'splits',splits,'eligible_suppliers',advice->'eligible_suppliers','decision_origin',r.decision_origin,
      'candidate',candidate,'exclusion_reason',case when candidate is null then reason else null end,
      'purchase_order_impact',jsonb_build_object('coverage','AUTHORIZED_DOCUMENTS_ONLY','documents',impact)));
  end loop;
  return result;
end;
$$;
revoke all on function atlas_core.supplier_allocation_bulk_candidates(uuid,date,date,jsonb,boolean) from public,anon,authenticated,service_role;
grant execute on function atlas_core.supplier_allocation_bulk_candidates(uuid,date,date,jsonb,boolean)
  to atlas_read_runtime,atlas_procurement_command_runtime;
reset role;
-- Preserve the existing read for ordinary callers, including its closed legacy forwarding.
do $read$
declare definition text:=pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
begin
  -- pg_get_functiondef preserves body line endings from the migration transport.
  definition:=replace(definition,E'\r\n',E'\n');
  if strpos(definition,'v_blockers jsonb:=''[]'';')=0
    or strpos(definition,'else null end);')=0 then raise exception 'Unexpected Allocation read definition'; end if;
  definition:=replace(definition,'  v_blockers jsonb:=''[]'';',
    '  v_include_bulk boolean:=false; v_bulk jsonb; v_blockers jsonb:=''[]'';');
  definition:=replace(definition,E'begin\n  if jsonb_typeof(request)',
    $body$begin
  if request->'payload' ? 'include_bulk_preview' then
    if jsonb_typeof(request#>'{payload,include_bulk_preview}') is distinct from 'boolean' then
      return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Bộ lọc phân bổ không hợp lệ.',
        'PROCUREMENT','get_confirmed_supplier_allocation_workbench');
    end if;
    v_include_bulk:=(request#>>'{payload,include_bulk_preview}')::boolean;
    request:=jsonb_set(request,'{payload}',(request->'payload')-'include_bulk_preview');
  end if;
  if jsonb_typeof(request)$body$);
  definition:=replace(definition,'else null end);',
    $body$else null end) || case when v_include_bulk then
      jsonb_build_object('bulk_preview',(
        select jsonb_build_object('families',families,'total_count',jsonb_array_length(families),
          'applicable_count',(select count(*) from jsonb_array_elements(families) e where e->'candidate'<>'null'::jsonb),
          'excluded_count',(select count(*) from jsonb_array_elements(families) e where e->'candidate'='null'::jsonb),
          'allowed',v_can_write)
        from (select atlas_core.supplier_allocation_bulk_candidates(v_actor_id,v_start,v_end,
          coalesce(request#>'{payload,school_ids}','[]'),true) families) preview))
      else '{}'::jsonb end;$body$);
  if strpos(definition,'v_include_bulk:=')=0 then raise exception 'Bulk read amendment failed'; end if;
  execute definition;
end;
$read$;

set role atlas_owner;
grant create on schema atlas_api,atlas_core to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;
-- Extract one existing command implementation with an optional trusted source
-- seam. Public Save supplies NULL; only the private bulk command supplies evidence.
do $resolved_child$
declare definition text:=pg_get_functiondef('atlas_api.save_confirmed_supplier_allocation(jsonb)'::regprocedure);
begin
  if strpos(definition,'atlas_core.purchase_review_persist_allocation(v_actor_id,')=0
    or strpos(definition,'''MANUAL'',''CONFIRMED_NEED'');')=0 then
    raise exception 'Unexpected Confirmed allocation child command';
  end if;
  definition:=replace(definition,'atlas_api.save_confirmed_supplier_allocation(request jsonb)',
    'atlas_core.purchase_review_save_confirmed_allocation(request jsonb, p_sources jsonb)');
  definition:=replace(definition,'atlas_core.purchase_review_persist_allocation(v_actor_id,',
    'atlas_core.purchase_review_persist_resolved_allocation(v_actor_id,');
  definition:=replace(definition,'''MANUAL'',''CONFIRMED_NEED'');','''MANUAL'',''CONFIRMED_NEED'',p_sources);');
  execute definition;
end;
$resolved_child$;
revoke all on function atlas_core.purchase_review_save_confirmed_allocation(jsonb,jsonb) from public,anon,authenticated,service_role;
create or replace function atlas_api.save_confirmed_supplier_allocation(request jsonb)
returns jsonb language sql volatile security definer set search_path='' as $save$
  select atlas_core.purchase_review_save_confirmed_allocation(request,null);
$save$;


create function atlas_api.apply_supplier_allocation_batch(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  name constant text:='apply_supplier_allocation_batch'; actor jsonb; actor_id uuid; response jsonb;
  begun jsonb; receipt uuid; candidates jsonb:=request#>'{payload,candidates}'; scope jsonb:=request#>'{payload,scope}';
  first_date date; last_date date;
  entry jsonb; current_entry jsonb; fresh jsonb; family jsonb; child jsonb; child_request jsonb;
  conflicts jsonb:='[]'; applied jsonb:='[]'; row_data record; child_id uuid; ingredient_ids jsonb;
  child_failure jsonb; event_id uuid; audit_id uuid; confirmed_sources jsonb; final_sources jsonb;
begin
  begin
    first_date:=nullif(scope->>'date_start','')::date; last_date:=nullif(scope->>'date_end','')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Ngày phân bổ không hợp lệ.','PROCUREMENT',name);
  end;
  if jsonb_typeof(request) is distinct from 'object'
    or request->>'contract_version' is distinct from 'SUPPLIER-ALLOCATION-BATCH.v1'
    or request->>'reason_code' is distinct from 'SUPPLIER_ALLOCATION_BATCH_APPLIED'
    or atlas_core.pa_05b_safe_bigint(request->>'expected_version') is distinct from 1::bigint
    or not(request ?& array['contract_version','command_id','correlation_id','idempotency_key','expected_version',
      'requested_by_auth_subject','requested_at','reason_code','reason_note','payload'])
    or request-array['contract_version','command_id','correlation_id','idempotency_key','expected_version',
      'requested_by_auth_subject','requested_at','reason_code','reason_note','payload']<>'{}'
    or atlas_core.pa_05b_safe_uuid(request->>'command_id') is null
    or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
    or nullif(btrim(request->>'idempotency_key'),'') is null or length(request->>'idempotency_key')>200
    or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at') is null
    or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at')>transaction_timestamp()+interval '60 seconds'
    or jsonb_typeof(request->'payload') is distinct from 'object'
    or (request->'payload')-array['scope','candidates']<>'{}'
    or jsonb_typeof(scope) is distinct from 'object'
    or scope-array['date_start','date_end','school_ids']<>'{}'
    or first_date is null or last_date is null or last_date<first_date or last_date-first_date>31
    or jsonb_typeof(candidates) is distinct from 'array' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Chọn phạm vi và đề xuất phân bổ hợp lệ.','PROCUREMENT',name);
  end if;
  if jsonb_array_length(candidates)=0 or
    (scope?'school_ids' and jsonb_typeof(scope->'school_ids') is distinct from 'array') then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Chọn ít nhất một đề xuất hợp lệ.','PROCUREMENT',name);
  end if;
  if exists(select 1 from jsonb_array_elements(coalesce(scope->'school_ids','[]')) s
    where jsonb_typeof(s)<>'string' or atlas_core.pa_05b_safe_uuid(s#>>'{}') is null) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Phạm vi Trường không hợp lệ.','PROCUREMENT',name);
  end if;
  for entry in select value from jsonb_array_elements(candidates) loop
    family:=entry->'family';
    begin
      if nullif(family->>'service_date','')::date not between first_date and last_date then raise invalid_datetime_format; end if;
    exception when invalid_datetime_format or datetime_field_overflow then
      return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Ngày phân bổ không hợp lệ.','PROCUREMENT',name);
    end;
    if jsonb_typeof(entry) is distinct from 'object' or entry-array['family','proposal_kind','proposal_fingerprint','proposed_splits']<>'{}'
      or jsonb_typeof(family) is distinct from 'object'
      or family-array['service_date','delivery_location_id','ingredient_id','unit_id','source_kind','expected_family_version',
        'expected_source_fingerprint','expected_source_batch_id','expected_source_batch_version']<>'{}'
      or nullif(family->>'service_date','') is null
      or (family->>'service_date')::date not between first_date and last_date
      or atlas_core.pa_05b_safe_uuid(family->>'delivery_location_id') is null
      or atlas_core.pa_05b_safe_uuid(family->>'ingredient_id') is null or atlas_core.pa_05b_safe_uuid(family->>'unit_id') is null
      or family->>'source_kind' not in ('CONFIRMED_NEED','PURCHASE_HANDOFF')
      or atlas_core.pa_05b_safe_bigint(family->>'expected_family_version') is null
      or atlas_core.pa_05b_safe_bigint(family->>'expected_family_version')<0
      or nullif(family->>'expected_source_fingerprint','') is null
      or entry->>'proposal_kind' not in ('DEFAULT','REBALANCE')
      or jsonb_typeof(entry->'proposed_splits') is distinct from 'array'
      or nullif(entry->>'proposal_fingerprint','') is null then
      return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Đề xuất phân bổ không hợp lệ.','PROCUREMENT',name);
    end if;
  end loop;
  if (select count(*) from jsonb_array_elements(candidates))<>(select count(distinct jsonb_build_array(
    (e#>>'{family,service_date}')::date,(e#>>'{family,delivery_location_id}')::uuid,
    (e#>>'{family,ingredient_id}')::uuid,(e#>>'{family,unit_id}')::uuid)) from jsonb_array_elements(candidates) e) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Một nhóm phân bổ chỉ được chọn một lần.','PROCUREMENT',name);
  end if;
  actor:=atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',name);
  if actor?'error' then return actor->'error'; end if;
  actor_id:=(actor->>'actor_id')::uuid;
  response:=atlas_core.pa_05b_authorize_actor(request,actor_id,'procurement.school_catering.write','PROCUREMENT',name,null,null,null);
  if response is not null and response->>'error_code'<>'SCOPE_DENIED' then return response; end if;
  for entry in select value from jsonb_array_elements(candidates) loop
    if not atlas_core.school_catering_actor_has_scope(actor_id,null,null,(entry#>>'{family,delivery_location_id}')::uuid) then
      return atlas_core.pa_05b_command_error(request,'SCOPE_DENIED','Ngoài phạm vi phân bổ được phép.','PROCUREMENT',name);
    end if;
  end loop;
  begun:=atlas_core.pa_05b_begin_command(request,actor_id,name,'PROCUREMENT','supplier-allocation-batch:'||(request->>'command_id'));
  if begun->>'status' in ('REPLAY','ERROR') then return begun->'response'; end if;
  receipt:=(begun->>'receipt_id')::uuid;
  begin
    -- Lock every overlapping CN source first; selected-family resolution cannot hide ambiguity.
    for row_data in select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
      where b.period_start<=last_date and b.period_end>=first_date
        and exists(select 1 from atlas_planning.confirmed_need_lines l
          where l.confirmed_need_batch_id=b.confirmed_need_batch_id and l.source_kind='NEED_GENERATION')
      order by b.confirmed_need_batch_id
    loop perform atlas_core.purchase_review_lock_confirmed_source(row_data.confirmed_need_batch_id); end loop;
    select jsonb_agg(distinct e#>'{family,ingredient_id}') into ingredient_ids from jsonb_array_elements(candidates) e;
    perform atlas_core.purchase_review_lock_default_supplier_evidence(ingredient_ids);
    for entry in select value from jsonb_array_elements(candidates)
      order by value#>>'{family,service_date}',value#>>'{family,delivery_location_id}',value#>>'{family,ingredient_id}',value#>>'{family,unit_id}'
    loop
      family:=entry->'family';
      perform atlas_core.school_catering_lock_handoff_source((family->>'service_date')::date,
        (family->>'delivery_location_id')::uuid,(family->>'ingredient_id')::uuid,(family->>'unit_id')::uuid);
    end loop;
    perform 1 from atlas_procurement.school_catering_allocation_families f
      where exists(select 1 from jsonb_array_elements(candidates) e
        where f.service_date=(e#>>'{family,service_date}')::date and f.delivery_location_id=(e#>>'{family,delivery_location_id}')::uuid
          and f.ingredient_id=(e#>>'{family,ingredient_id}')::uuid and f.unit_id=(e#>>'{family,unit_id}')::uuid)
      order by f.family_id for update;
    select coalesce(jsonb_agg(value order by value::text),'[]') into confirmed_sources
      from atlas_core.purchase_review_confirmed_sources(first_date,last_date) value;
    fresh:=atlas_core.supplier_allocation_bulk_candidates(actor_id,first_date,last_date,coalesce(scope->'school_ids','[]'),false);
    for entry in select value from jsonb_array_elements(candidates) loop
      select value->'candidate' into current_entry from jsonb_array_elements(fresh)
      where value->>'service_date'=entry#>>'{family,service_date}'
        and value->>'delivery_location_id'=entry#>>'{family,delivery_location_id}'
        and value->>'ingredient_id'=entry#>>'{family,ingredient_id}' and value->>'unit_id'=entry#>>'{family,unit_id}';
      if current_entry is distinct from entry then conflicts:=conflicts||jsonb_build_array(jsonb_build_object(
        'family',entry->'family','reason','STALE_BULK_PROPOSAL')); end if;
    end loop;
    if jsonb_array_length(conflicts)>0 then
      child_failure:=atlas_core.pa_05b_command_error(request,'STALE_BULK_PROPOSAL',
        'Đề xuất đã thay đổi. Tải lại để xem và chọn lại.','PROCUREMENT',name)||jsonb_build_object('conflicts',conflicts);
      raise exception using errcode='PBB01';
    end if;
    for entry in select value from jsonb_array_elements(candidates)
      order by value#>>'{family,service_date}',value#>>'{family,delivery_location_id}',value#>>'{family,ingredient_id}',value#>>'{family,unit_id}'
    loop
      family:=entry->'family'; child_id:=gen_random_uuid();
      child_request:=request||jsonb_build_object('command_id',child_id,
        'idempotency_key','bulk:'||receipt::text||':'||md5(jsonb_build_array(family->'service_date',family->'delivery_location_id',family->'ingredient_id',family->'unit_id')::text),
        'expected_version',family->'expected_family_version','payload',jsonb_build_object(
          'family',family-array['source_kind','expected_family_version'],'splits',entry->'proposed_splits'));
      if family->>'source_kind'='CONFIRMED_NEED' then
        child_request:=child_request||jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','reason_code','CONFIRMED_SUPPLIER_ALLOCATION_SAVED');
        child:=atlas_core.purchase_review_save_confirmed_allocation(child_request,confirmed_sources);
      else
        child_request:=child_request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1','reason_code','SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED');
        child:=atlas_api.save_school_catering_supplier_allocation(child_request);
      end if;
      if child->>'success' is distinct from 'true' then
        child_failure:=atlas_core.pa_05b_command_error(request,coalesce(child->>'error_code','INTERNAL_COMMAND_FAILURE'),
          'Chưa lưu nhóm phân bổ; toàn bộ lựa chọn đã được hoàn tác.','PROCUREMENT',name,
          coalesce((child->>'retryable')::boolean,false))||jsonb_build_object('conflicts',jsonb_build_array(jsonb_build_object(
            'family',family,'reason',child->>'error_code')));
        raise exception using errcode='PBB01';
      end if;
      applied:=applied||jsonb_build_array(child->'family');
    end loop;
    select coalesce(jsonb_agg(value order by value::text),'[]') into final_sources
      from atlas_core.purchase_review_confirmed_sources(first_date,last_date) value
      where exists(select 1 from jsonb_array_elements(candidates) e
        where value->>'service_date'=e#>>'{family,service_date}' and value->>'delivery_location_id'=e#>>'{family,delivery_location_id}'
          and value->>'ingredient_id'=e#>>'{family,ingredient_id}' and value->>'unit_id'=e#>>'{family,unit_id}');
    if final_sources is distinct from (select coalesce(jsonb_agg(value order by value::text),'[]')
      from jsonb_array_elements(confirmed_sources) value where exists(select 1 from jsonb_array_elements(candidates) e
        where value->>'service_date'=e#>>'{family,service_date}' and value->>'delivery_location_id'=e#>>'{family,delivery_location_id}'
          and value->>'ingredient_id'=e#>>'{family,ingredient_id}' and value->>'unit_id'=e#>>'{family,unit_id}')) then
      child_failure:=atlas_core.pa_05b_command_error(request,'STALE_BULK_PROPOSAL',
        'Nguồn nhu cầu đã thay đổi. Tải lại để xem lại đề xuất.','PROCUREMENT',name);
      raise exception using errcode='PBB01';
    end if;
  exception when sqlstate 'PBB01' then
    if coalesce((child_failure->>'retryable')::boolean,false) then raise serialization_failure; end if;
    return atlas_core.pa_05b_finish_command(receipt,child_failure,false);
  end;
  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,aggregate_version,
    command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary)
  values('SupplierAllocationBatchApplied','PROCUREMENT','AllocationFamilySet',(request->>'command_id')::uuid,1,
    receipt,(request->>'command_id')::uuid,(request->>'correlation_id')::uuid,actor_id,transaction_timestamp(),
    jsonb_build_object('families',applied)) returning domain_event_id into event_id;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,aggregate_version_after,
    command_receipt_id,command_id,correlation_id,actor_id,reason_code,reason_note,after_summary,source_interface,occurred_at)
  values('SupplierAllocationBatchApplied','PROCUREMENT','AllocationFamilySet',(request->>'command_id')::uuid,1,
    receipt,(request->>'command_id')::uuid,(request->>'correlation_id')::uuid,actor_id,request->>'reason_code',request->>'reason_note',
    jsonb_build_object('families',applied),'atlas_api',transaction_timestamp()) returning audit_event_id into audit_id;
  response:=jsonb_build_object('success',true,'contract_version','SUPPLIER-ALLOCATION-BATCH.v1',
    'command_id',request->'command_id','correlation_id',request->'correlation_id','idempotency_status','COMPLETED',
    'families',applied,'applied_count',jsonb_array_length(applied),'emitted_event_ids',jsonb_build_array(event_id),
    'audit_event_ids',jsonb_build_array(audit_id),'warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(receipt,response,true);
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE','Thử lại đúng yêu cầu đã gửi.','PROCUREMENT',name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE','Chưa lưu phân bổ an toàn.','PROCUREMENT',name);
end;
$$;
revoke all on function atlas_api.apply_supplier_allocation_batch(jsonb) from public,anon,service_role;
grant execute on function atlas_api.apply_supplier_allocation_batch(jsonb) to authenticated;
reset role;
set role atlas_owner;
revoke create on schema atlas_api,atlas_core from atlas_procurement_command_runtime;
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
commit;
