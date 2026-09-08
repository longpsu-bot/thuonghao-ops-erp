grant atlas_owner,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set true;
grant create on schema atlas_api to atlas_procurement_command_runtime;
set role atlas_procurement_command_runtime;

CREATE OR REPLACE FUNCTION atlas_api.release_school_catering_purchase_order(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_name constant text := 'release_school_catering_purchase_order';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb; v_begin jsonb; v_receipt uuid;
  v_purchase_order_id uuid; v_expected_revision_id uuid; v_expected_version bigint;
  v_root record; v_revision record; v_supplier record; v_row record;
  v_new_revision_id uuid; v_new_line_revision_id uuid;
  v_document_number text; v_event uuid; v_audit uuid; v_response jsonb; v_error jsonb;
  v_line_revision_ids jsonb := '[]'::jsonb;
begin
  if request is null or jsonb_typeof(request)<>'object'
     or not (request ?& array['contract_version','command_id','correlation_id',
       'idempotency_key','expected_version','requested_by_auth_subject','requested_at',
       'reason_code','reason_note','payload'])
     or request-array['contract_version','command_id','correlation_id','idempotency_key',
       'expected_version','requested_by_auth_subject','requested_at','reason_code',
       'reason_note','payload']<>'{}'::jsonb
     or request ->> 'contract_version' is distinct from 'SCHOOL-CATERING-PROCUREMENT.v1'
     or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
     or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at') is null
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at')>transaction_timestamp()+interval '60 seconds'
     or btrim(coalesce(request ->> 'idempotency_key',''))=''
     or request ->> 'reason_code' is distinct from 'SCHOOL_CATERING_PO_RELEASED'
     or jsonb_typeof(request -> 'payload')<>'object'
     or (request -> 'payload')-array['purchase_order_id',
       'expected_purchase_order_revision_id']<>'{}'::jsonb
     or not (request -> 'payload' ?& array['purchase_order_id',
       'expected_purchase_order_revision_id']) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The bounded school-catering PO release request is invalid.','PROCUREMENT',v_name);
  end if;
  v_purchase_order_id := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,purchase_order_id}');
  v_expected_revision_id := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,expected_purchase_order_revision_id}');
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  if v_purchase_order_id is null or v_expected_revision_id is null
     or v_expected_version<1 then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The purchase order identity and expected revision are required.',
      'PROCUREMENT',v_name);
  end if;

  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;

  -- Receipt acquisition precedes lifecycle checks so an exact completed replay wins.
  v_begin := atlas_core.pa_05b_begin_command(request,v_actor_id,v_name,'PROCUREMENT',
    'school-catering-po:' || v_purchase_order_id::text);
  if v_begin ->> 'status' in ('REPLAY','ERROR') then return v_begin -> 'response'; end if;
  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select po.* into v_root
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=v_purchase_order_id
    and po.purchase_order_kind='SCHOOL_CATERING';
  if v_root.purchase_order_id is null then
    v_error := atlas_core.pa_05b_command_error(request,'PURCHASE_ORDER_NOT_FOUND',
      'The school-catering purchase order was not found.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'school-catering-po:' || v_root.school_catering_service_date::text || ':' ||
      v_root.supplier_id::text,0));

  -- Lock all current source families in a stable order, including supplier evidence.
  for v_row in
    select f.family_id,f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,
        'allocated_quantity',s.allocated_quantity) order by s.supplier_id) splits
    from atlas_procurement.purchase_order_line_revisions polr
    join atlas_procurement.purchase_order_lines pol
      on pol.purchase_order_line_id=polr.purchase_order_line_id
    join atlas_procurement.school_catering_allocation_families f
      on f.family_id=pol.school_catering_allocation_family_id
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    where polr.purchase_order_revision_id=v_expected_revision_id
    group by f.family_id,f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
    order by f.family_id
  loop
    perform atlas_core.school_catering_lock_supplier_evidence(
      v_row.service_date,v_row.ingredient_id,v_row.splits,false);
    perform atlas_core.school_catering_lock_handoff_source(
      v_row.service_date,v_row.delivery_location_id,v_row.ingredient_id,v_row.unit_id);
  end loop;
  perform 1
  from atlas_procurement.school_catering_allocation_families f
  join atlas_procurement.school_catering_allocation_family_revisions r
    on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
  join atlas_procurement.school_catering_allocation_supplier_splits s
    on s.family_revision_id=r.family_revision_id
  where f.service_date=v_root.school_catering_service_date
  order by f.family_id,s.supplier_id for share of f,r;

  select po.* into v_root
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=v_purchase_order_id
  for update;
  if v_root.purchase_order_status='RELEASED_TO_SUPPLIER' then
    v_error := atlas_core.pa_05b_command_error(request,'PO_ALREADY_RELEASED',
      'The school-catering purchase order is already released.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if v_root.purchase_order_status<>'DRAFT' or v_root.version<>v_expected_version then
    v_error := atlas_core.pa_05b_command_error(request,'STALE_VERSION',
      'The purchase order version no longer matches the release request.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  select por.* into v_revision
  from atlas_procurement.purchase_order_revisions por
  where por.purchase_order_id=v_purchase_order_id and por.is_current
  for update;
  if v_revision.purchase_order_revision_id is distinct from v_expected_revision_id
     or v_revision.revision_status<>'DRAFT' then
    v_error := atlas_core.pa_05b_command_error(request,'STALE_VERSION',
      'The current purchase order revision no longer matches the release request.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if atlas_core.school_catering_po_draft_is_stale(
      v_purchase_order_id,v_expected_revision_id) then
    v_error := atlas_core.pa_05b_command_error(request,'PO_DRAFT_STALE',
      'The draft uses superseded allocation evidence and must be regenerated.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;

  select supplier_id,supplier_name,supplier_status into v_supplier
  from atlas_admin.suppliers where supplier_id=v_root.supplier_id;
  if v_supplier.supplier_id is null or v_supplier.supplier_status<>'ACTIVE' then
    v_error := atlas_core.pa_05b_command_error(request,'SUPPLIER_INACTIVE',
      'The supplier is no longer active.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if not exists(
    select 1 from atlas_procurement.purchase_order_line_revisions polr
    where polr.purchase_order_revision_id=v_expected_revision_id
  ) or exists(
    select 1
    from atlas_procurement.purchase_order_line_revisions polr
    where polr.purchase_order_revision_id=v_expected_revision_id
      and not exists(
        select 1 from atlas_admin.supplier_eligibilities e
        where e.supplier_id=v_root.supplier_id and e.ingredient_id=polr.ingredient_id
          and e.eligibility_status='ACTIVE'
          and e.effective_from<=v_root.school_catering_service_date
          and (e.effective_to is null or e.effective_to>v_root.school_catering_service_date)
      )
  ) then
    v_error := atlas_core.pa_05b_command_error(request,'SUPPLIER_INELIGIBLE',
      'The supplier is not currently eligible for every purchase-order line.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;

  v_document_number := format('PO-%s-%s',
    to_char(v_root.school_catering_service_date,'YYYYMMDD'),
    upper(substr(replace(v_purchase_order_id::text,'-',''),1,16)));
  update atlas_procurement.purchase_order_revisions set is_current=false
  where purchase_order_revision_id=v_expected_revision_id;
  insert into atlas_procurement.purchase_order_revisions(
    purchase_order_id,revision_number,revision_kind,revision_status,is_current,
    predecessor_revision_id,service_date,delivery_location_id,supplier_name_snapshot,
    delivery_location_snapshot,released_by_actor_id,released_at,reason_note,command_id
  ) values(v_purchase_order_id,v_revision.revision_number+1,'SUPERSEDING',
    'RELEASED_TO_SUPPLIER',true,v_expected_revision_id,
    v_root.school_catering_service_date,null,v_supplier.supplier_name,
    'Nhiều điểm giao',v_actor_id,transaction_timestamp(),request ->> 'reason_note',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'))
  returning purchase_order_revision_id into v_new_revision_id;

  for v_row in
    select polr.*
    from atlas_procurement.purchase_order_line_revisions polr
    where polr.purchase_order_revision_id=v_expected_revision_id
    order by polr.purchase_order_line_id
  loop
    insert into atlas_procurement.purchase_order_line_revisions(
      purchase_order_revision_id,purchase_order_line_id,
      school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,
      unit_id,delivery_location_id,service_date,predecessor_revision_id
    ) values(v_new_revision_id,v_row.purchase_order_line_id,
      v_row.school_catering_allocation_supplier_split_id,v_row.ingredient_id,
      v_row.ordered_quantity,v_row.unit_id,v_row.delivery_location_id,v_row.service_date,
      v_row.purchase_order_line_revision_id)
    returning purchase_order_line_revision_id into v_new_line_revision_id;
    v_line_revision_ids := v_line_revision_ids || jsonb_build_array(v_new_line_revision_id);
  end loop;
  update atlas_procurement.purchase_orders
  set document_number=v_document_number,purchase_order_status='RELEASED_TO_SUPPLIER',
    version=version+1,updated_at=transaction_timestamp()
  where purchase_order_id=v_purchase_order_id;

  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version,command_receipt_id,command_id,correlation_id,actor_id,occurred_at,
    payload_summary)
  values('SchoolCateringPurchaseOrderReleased','PROCUREMENT','PurchaseOrder',
    v_purchase_order_id,v_root.version+1,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    transaction_timestamp(),jsonb_build_object('purchase_order_revision_id',v_new_revision_id,
      'document_number',v_document_number,'supplier_id',v_root.supplier_id,
      'service_date',v_root.school_catering_service_date))
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_before,aggregate_version_after,command_receipt_id,command_id,
    correlation_id,actor_id,reason_code,reason_note,after_summary,source_interface,occurred_at)
  values('SchoolCateringPurchaseOrderReleased','PROCUREMENT','PurchaseOrder',
    v_purchase_order_id,v_root.version,v_root.version+1,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    request ->> 'reason_code',request ->> 'reason_note',jsonb_build_object(
      'purchase_order_revision_id',v_new_revision_id,'document_number',v_document_number,
      'status','RELEASED_TO_SUPPLIER'),'atlas_api',transaction_timestamp())
  returning audit_event_id into v_audit;

  v_response := jsonb_build_object('success',true,
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'command_id',request ->> 'command_id','correlation_id',request ->> 'correlation_id',
    'idempotency_status','COMPLETED','purchase_order_id',v_purchase_order_id,
    'purchase_order_revision_id',v_new_revision_id,'document_number',v_document_number,
    'purchase_order_line_revision_ids',v_line_revision_ids,
    'new_version',v_root.version+1,'emitted_event_ids',jsonb_build_array(v_event),
    'audit_event_ids',jsonb_build_array(v_audit),
    'authoritative_readback',jsonb_build_object(
      'purchase_order_id',v_purchase_order_id,
      'purchase_order_revision_id',v_new_revision_id,
      'supplier_id',v_root.supplier_id,
      'service_date',v_root.school_catering_service_date,
      'status','RELEASED_TO_SUPPLIER','version',v_root.version+1,
      'document_number',v_document_number,
      'purchase_order_line_revision_ids',v_line_revision_ids),
    'safe_operator_message','Đã phát hành đơn mua cho nhà cung cấp.',
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'The PO release could not acquire a safe transaction state. Retry the exact request.',
    'PROCUREMENT',v_name,true);
when unique_violation then
  return atlas_core.pa_05b_command_error(request,'INVARIANT_VIOLATION',
    'The deterministic purchase-order number conflicts with an existing document.',
    'PROCUREMENT',v_name);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'The school-catering purchase order could not be released safely.',
    'PROCUREMENT',v_name);
end;
$function$;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_procurement_command_runtime;

grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

CREATE OR REPLACE FUNCTION atlas_api.get_confirmed_supplier_allocation_workbench(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_start date:=atlas_core.pa_05d_safe_date(request#>>'{payload,date_start}');
  v_end date:=atlas_core.pa_05d_safe_date(request#>>'{payload,date_end}');
  v_actor jsonb; v_actor_id uuid; v_error jsonb; v_can_write boolean;
  p jsonb; a jsonb; v_splits jsonb; v_contributions jsonb; v_rebalance jsonb; v_state text; v_rows jsonb:='[]';
  f record; r record; d record; v_complete boolean; v_eligible boolean; v_schools jsonb; v_legacy jsonb;
  v_blockers jsonb:='[]'; v_row jsonb; v_search text:=nullif(request#>>'{payload,search}','');
begin
  if jsonb_typeof(request) is distinct from 'object' or jsonb_typeof(request->'payload') is distinct from 'object'
    or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
    or request->>'contract_version' is distinct from 'CONFIRMED-SUPPLIER-ALLOCATION.v1'
    or v_start is null or v_end is null or v_end<v_start or v_end-v_start>31
    or (request->'payload')-array['date_start','date_end','school_ids','states','search']<>'{}'::jsonb then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Chọn ngày phân bổ hợp lệ.',
      'PROCUREMENT','get_confirmed_supplier_allocation_workbench');
  end if;
  if (request->'payload' ? 'school_ids' and jsonb_typeof(request#>'{payload,school_ids}') is distinct from 'array')
    or (request->'payload' ? 'states' and jsonb_typeof(request#>'{payload,states}') is distinct from 'array')
    or (request->'payload' ? 'search' and jsonb_typeof(request#>'{payload,search}') not in ('string','null')) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Bộ lọc phân bổ không hợp lệ.',
      'PROCUREMENT','get_confirmed_supplier_allocation_workbench');
  end if;
  if exists(select 1 from jsonb_array_elements(coalesce(request#>'{payload,school_ids}','[]')) x
      where jsonb_typeof(x)<>'string' or atlas_core.pa_05b_safe_uuid(x#>>'{}') is null)
    or exists(select 1 from jsonb_array_elements(coalesce(request#>'{payload,states}','[]')) x
      where jsonb_typeof(x)<>'string' or x#>>'{}' not in ('UNALLOCATED','BALANCED','STALE_REBALANCE_AVAILABLE','NEEDS_REALLOCATION','BLOCKED')) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Bộ lọc phân bổ không hợp lệ.',
      'PROCUREMENT','get_confirmed_supplier_allocation_workbench');
  end if;
  v_actor:=atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT','get_confirmed_supplier_allocation_workbench');
  if v_actor?'error' then return v_actor->'error'; end if;
  v_actor_id:=(v_actor->>'actor_id')::uuid;
  v_error:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,'procurement.school_catering.read',
    'PROCUREMENT','get_confirmed_supplier_allocation_workbench',null,null,null);
  if v_error is not null and v_error->>'error_code'<>'SCOPE_DENIED' then return v_error; end if;
  v_error:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,'procurement.school_catering.write',
    'PROCUREMENT','get_confirmed_supplier_allocation_workbench',null,null,null);
  v_can_write:=v_error is null or v_error->>'error_code'='SCOPE_DENIED';
  for p in select * from atlas_core.purchase_review_confirmed_sources(v_start,v_end) loop
    if not atlas_core.school_catering_actor_has_scope(v_actor_id,null,null,(p->>'delivery_location_id')::uuid) then continue; end if;
    v_complete:=coalesce((p->>'complete')::boolean,false);
    if not v_complete then v_blockers:='["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."]'; end if;
    if v_complete and (p->>'family_quantity')::numeric<=0 then continue; end if;
    select x.* into f from atlas_procurement.school_catering_allocation_families x
      where x.service_date=(p->>'service_date')::date and x.delivery_location_id=(p->>'delivery_location_id')::uuid
        and x.ingredient_id=(p->>'ingredient_id')::uuid and x.unit_id=(p->>'unit_id')::uuid;
    select x.* into r from atlas_procurement.school_catering_allocation_family_revisions x
      where x.family_id=f.family_id and x.is_current;
    select coalesce(jsonb_agg(jsonb_build_object('school_id',s.school_id,'school_name',s.school_name)
      order by s.school_name,s.school_id),'[]') into v_schools
      from atlas_admin.schools s where exists(select 1 from jsonb_array_elements(p->'contributions') c
        where c->>'school_id'=s.school_id::text);
    -- Once promoted, retain the real Handoff source for currentness and legacy Save.
    if r.source_kind='PURCHASE_HANDOFF' and p->>'batch_status'='RELEASED_FOR_PURCHASE_HANDOFF' then
      p:=p || atlas_core.school_catering_family_projection((p->>'service_date')::date,
        (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)
        || jsonb_build_object('source_kind','PURCHASE_HANDOFF');
    end if;
    a:=atlas_core.purchase_review_supplier_advice((p->>'service_date')::date,(p->>'ingredient_id')::uuid,
      (p->>'family_quantity')::numeric);
    select coalesce(jsonb_agg(jsonb_build_object('supplier_split_id',s.supplier_split_id,
      'supplier_id',s.supplier_id,'supplier_name',sp.supplier_name,
      'allocated_quantity',s.allocated_quantity::text,'split_ratio',s.split_ratio::text) order by s.supplier_id),'[]')
      into v_splits from atlas_procurement.school_catering_allocation_supplier_splits s
      join atlas_admin.suppliers sp on sp.supplier_id=s.supplier_id where s.family_revision_id=r.family_revision_id;
    v_eligible:=not exists(select 1 from jsonb_array_elements(v_splits) s where not exists(
      select 1 from jsonb_array_elements(a->'eligible_suppliers') e where e->>'supplier_id'=s->>'supplier_id'));
    v_state:=case when not v_complete then 'BLOCKED' when r.family_revision_id is null then 'UNALLOCATED'
      when r.source_fingerprint=p->>'source_fingerprint' and v_eligible
        and r.family_quantity=(p->>'family_quantity')::numeric
        and (select sum((s->>'allocated_quantity')::numeric) from jsonb_array_elements(v_splits) s)=r.family_quantity then 'BALANCED'
      when r.source_fingerprint<>p->>'source_fingerprint' and v_eligible then 'STALE_REBALANCE_AVAILABLE'
      when not v_eligible then 'NEEDS_REALLOCATION' else 'BLOCKED' end;
    v_rebalance:=null;
    if v_state='STALE_REBALANCE_AVAILABLE' then
      select jsonb_agg(jsonb_build_object('supplier_id',supplier_id,'split_ratio',ratio::numeric(20,12)::text,
        'allocated_quantity',(case when rn=cnt then (p->>'family_quantity')::numeric-prior_total else qty end)::numeric(20,6)::text)
        order by supplier_id) into v_rebalance from (
        select x.*,coalesce(sum(qty) filter(where rn<cnt) over(),0) prior_total from (
          select s->>'supplier_id' supplier_id,(s->>'split_ratio')::numeric ratio,
            round((p->>'family_quantity')::numeric*(s->>'split_ratio')::numeric,6) qty,
            row_number() over(order by s->>'supplier_id') rn,count(*) over() cnt from jsonb_array_elements(v_splits) s) x) y;
    end if;
    select l.location_name,i.ingredient_name,u.unit_code,
      case when jsonb_array_length(v_schools)=1 then v_schools#>>'{0,school_id}' else null end school_id,
      (select string_agg(s->>'school_name',', ' order by s->>'school_name') from jsonb_array_elements(v_schools) s) school_name into d
      from atlas_admin.delivery_locations l join atlas_admin.ingredients i on i.ingredient_id=(p->>'ingredient_id')::uuid
      join atlas_admin.units u on u.unit_id=(p->>'unit_id')::uuid
      where l.delivery_location_id=(p->>'delivery_location_id')::uuid;
    select coalesce(jsonb_agg(contribution || jsonb_build_object(
      'contribution_quantity',
      (contribution->>'contribution_quantity')::numeric(20,6)::text)
      order by contribution_ordinal),'[]'::jsonb)
      into v_contributions
    from jsonb_array_elements(p->'contributions')
      with ordinality as source(contribution,contribution_ordinal);
    v_row:=p || to_jsonb(d) || jsonb_build_object('family',jsonb_build_object(
      'service_date',p->'service_date','delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','family_id',f.family_id,'version',coalesce(f.version,0),
      'source_fingerprint',p->'source_fingerprint','source_kind',p->'source_kind',
      'source_confirmed_need_batch_id',p->'source_confirmed_need_batch_id',
      'source_confirmed_need_batch_version',p->'source_confirmed_need_batch_version'),
      'family_quantity',case when p->>'family_quantity' is null then null
        else (p->>'family_quantity')::numeric(20,6)::text end,
      'contributions',v_contributions,'schools',v_schools,'splits',v_splits,'state',v_state,
      'contribution_count',jsonb_array_length(p->'contributions'),'eligible_suppliers',a->'eligible_suppliers',
      'recommendation',case when r.family_revision_id is null and v_complete then a->'recommendation' else null end,
      'rebalance_proposal',v_rebalance,'allowed_actions',jsonb_build_object(
        'save_allocation',v_can_write and v_complete and jsonb_array_length(a->'eligible_suppliers')>0
          and (p->>'source_kind'='PURCHASE_HANDOFF' or p->>'batch_status' in ('DRAFT_REVIEW','REOPENED','RELEASED_FOR_PURCHASE_HANDOFF')),
        'confirm_recommendation',false),'disabled_reasons',case when not v_complete then v_blockers else '[]'::jsonb end,
      'blockers',case when not v_complete then v_blockers else '[]'::jsonb end,'warnings',a->'warnings');
    if (jsonb_array_length(coalesce(request#>'{payload,school_ids}','[]'))=0 or
        exists(select 1 from jsonb_array_elements(v_schools) s
          where request#>'{payload,school_ids}' @> jsonb_build_array(s->>'school_id')))
      and (jsonb_array_length(coalesce(request#>'{payload,states}','[]'))=0 or request#>'{payload,states}' @> jsonb_build_array(v_state))
      and (v_search is null or concat_ws(' ',d.school_name,d.location_name,d.ingredient_name,v_splits::text) ilike '%'||v_search||'%') then
      v_rows:=v_rows||jsonb_build_array(v_row);
    end if;
  end loop;
  -- Historical Handoff authority remains accessible when its generation source
  -- is no longer the current review source. Never substitute it for current CN.
  v_legacy:=atlas_api.get_school_catering_procurement_workbench(
    request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1'));
  for v_row in select value from jsonb_array_elements(coalesce(v_legacy->'rows','[]')) loop
    if not exists(select 1 from atlas_core.purchase_review_confirmed_sources(v_start,v_end) source
      where source->>'service_date'=v_row->>'service_date'
        and source->>'delivery_location_id'=v_row->>'delivery_location_id'
        and source->>'ingredient_id'=v_row->>'ingredient_id' and source->>'unit_id'=v_row->>'unit_id') then
      v_rows:=v_rows||jsonb_build_array(v_row||jsonb_build_object('complete',true,
        'family',(v_row->'family')||jsonb_build_object('source_kind','PURCHASE_HANDOFF')));
    end if;
  end loop;
  return jsonb_build_object('success',true,'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'date_start',v_start,'date_end',v_end,'rows',v_rows,'blockers',v_blockers,'warnings','[]'::jsonb,
    'preparation',case when v_start=v_end then atlas_core.purchase_review_preparation_status(v_start,v_actor_id) else null end);
end;
$function$;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;

reset role;
grant atlas_owner,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set false;
