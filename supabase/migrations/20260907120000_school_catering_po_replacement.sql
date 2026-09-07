-- Complete School-catering Purchase Order replacement roots and removed-supplier safety.

reset role;
grant atlas_owner,atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set true;
set role atlas_owner;

alter table atlas_procurement.purchase_orders
  add column replaces_purchase_order_id uuid
    references atlas_procurement.purchase_orders(purchase_order_id) on delete restrict;

alter table atlas_procurement.purchase_orders
  add constraint purchase_orders_replacement_not_self_check
    check (replaces_purchase_order_id is null
      or replaces_purchase_order_id<>purchase_order_id);

drop index atlas_procurement.purchase_orders_school_catering_supplier_date_key;

create unique index purchase_orders_school_catering_supplier_date_draft_key
  on atlas_procurement.purchase_orders(supplier_id,school_catering_service_date)
  where purchase_order_kind='SCHOOL_CATERING'
    and purchase_order_status='DRAFT';

create unique index purchase_orders_school_catering_supplier_date_released_key
  on atlas_procurement.purchase_orders(supplier_id,school_catering_service_date)
  where purchase_order_kind='SCHOOL_CATERING'
    and purchase_order_status='RELEASED_TO_SUPPLIER';

create unique index purchase_orders_school_catering_replacement_predecessor_key
  on atlas_procurement.purchase_orders(replaces_purchase_order_id)
  where purchase_order_kind='SCHOOL_CATERING'
    and replaces_purchase_order_id is not null;

create index purchase_orders_school_catering_replacement_lookup_idx
  on atlas_procurement.purchase_orders(
    supplier_id,school_catering_service_date,replaces_purchase_order_id
  ) where purchase_order_kind='SCHOOL_CATERING';

comment on column atlas_procurement.purchase_orders.replaces_purchase_order_id is
  'Direct predecessor root for a complete School-catering replacement PO; null for original roots.';

grant create on schema atlas_core to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

create function atlas_core.school_catering_po_commitment_state(
  p_purchase_order_id uuid,p_purchase_order_revision_id uuid
) returns text
language sql
stable
security definer
set search_path=''
as $$
  select case
    when po.purchase_order_status='SUPERSEDED' then 'SUPERSEDED'
    when po.purchase_order_status='DRAFT' then
      case when atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id)
        then 'DRAFT_STALE' else 'DRAFT_CURRENT' end
    when po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and not atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id) then 'CURRENT'
    when po.purchase_order_status='RELEASED_TO_SUPPLIER' and exists(
      select 1
      from atlas_procurement.school_catering_allocation_families f
      join atlas_procurement.school_catering_allocation_family_revisions r
        on r.family_id=f.family_id and r.is_current
      join atlas_procurement.school_catering_allocation_supplier_splits s
        on s.family_revision_id=r.family_revision_id
       and s.supplier_id=po.supplier_id
      cross join lateral (
        select atlas_core.school_catering_family_projection(
          f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
        ) value
      ) projection
      where f.service_date=po.school_catering_service_date
        and r.source_fingerprint=projection.value ->> 'source_fingerprint'
        and r.family_quantity=
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')
    ) then 'REPLACEMENT_REQUIRED'
    when po.purchase_order_status='RELEASED_TO_SUPPLIER'
      then 'CANCELLATION_REQUIRED'
    else po.purchase_order_status
  end
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=p_purchase_order_id
    and po.purchase_order_kind='SCHOOL_CATERING';
$$;

create function atlas_core.school_catering_procurement_date_current(
  p_service_date date
) returns boolean
language sql
stable
security definer
set search_path=''
as $$
  with current_suppliers as (
    select distinct s.supplier_id
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date=p_service_date
      and r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')
  )
  select (atlas_core.school_catering_po_date_readiness(p_service_date)
      ->> 'ready')::boolean
    and not exists(
      select 1 from current_suppliers current_supplier
      where not exists(
        select 1
        from atlas_procurement.purchase_orders po
        join atlas_procurement.purchase_order_revisions por
          on por.purchase_order_id=po.purchase_order_id and por.is_current
        where po.purchase_order_kind='SCHOOL_CATERING'
          and po.school_catering_service_date=p_service_date
          and po.supplier_id=current_supplier.supplier_id
          and po.purchase_order_status='RELEASED_TO_SUPPLIER'
          and atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id)='CURRENT'
      )
    )
    and not exists(
      select 1
      from atlas_procurement.purchase_orders po
      join atlas_procurement.purchase_order_revisions por
        on por.purchase_order_id=po.purchase_order_id and por.is_current
      where po.purchase_order_kind='SCHOOL_CATERING'
        and po.school_catering_service_date=p_service_date
        and po.purchase_order_status='RELEASED_TO_SUPPLIER'
        and atlas_core.school_catering_po_commitment_state(
          po.purchase_order_id,por.purchase_order_revision_id)<>'CURRENT'
    );
$$;

revoke execute on function
  atlas_core.school_catering_po_commitment_state(uuid,uuid),
  atlas_core.school_catering_procurement_date_current(date)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.school_catering_po_commitment_state(uuid,uuid),
  atlas_core.school_catering_procurement_date_current(date)
to atlas_read_runtime,atlas_procurement_command_runtime,atlas_dispatch_command_runtime;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_read_runtime;

-- A replacement release uses the existing hardened release command. This trigger
-- performs the predecessor status transition before the new released-root update,
-- so the single-active-release index and both root changes are one transaction.
grant create on schema atlas_core to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;

create function atlas_core.school_catering_po_replacement_release_guard()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_replaced atlas_procurement.purchase_orders%rowtype;
  v_receipt atlas_core.command_receipts%rowtype;
  v_revision atlas_procurement.purchase_order_revisions%rowtype;
begin
  if new.purchase_order_kind<>'SCHOOL_CATERING'
     or new.replaces_purchase_order_id is null
     or old.purchase_order_status<>'DRAFT'
     or new.purchase_order_status<>'RELEASED_TO_SUPPLIER' then
    return new;
  end if;

  select po.* into v_replaced
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=new.replaces_purchase_order_id
  for update;
  if v_replaced.purchase_order_id is null
     or v_replaced.purchase_order_kind<>'SCHOOL_CATERING'
     or v_replaced.purchase_order_status<>'RELEASED_TO_SUPPLIER'
     or v_replaced.supplier_id<>new.supplier_id
     or v_replaced.school_catering_service_date<>new.school_catering_service_date then
    raise exception using errcode='23514',
      message='replacement release requires its active same-supplier/date predecessor';
  end if;

  select por.* into strict v_revision
  from atlas_procurement.purchase_order_revisions por
  where por.purchase_order_id=new.purchase_order_id and por.is_current
    and por.revision_status='RELEASED_TO_SUPPLIER';
  select receipt.* into strict v_receipt
  from atlas_core.command_receipts receipt
  where receipt.command_id=v_revision.command_id;

  update atlas_procurement.purchase_orders
  set purchase_order_status='SUPERSEDED',version=version+1,
    updated_at=transaction_timestamp()
  where purchase_order_id=v_replaced.purchase_order_id;

  insert into atlas_audit.domain_events(
    event_type,source_domain,aggregate_type,aggregate_id,aggregate_version,
    command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary
  ) values(
    'SchoolCateringPurchaseOrderSuperseded','PROCUREMENT','PurchaseOrder',
    v_replaced.purchase_order_id,v_replaced.version+1,v_receipt.command_receipt_id,
    v_receipt.command_id,v_receipt.correlation_id,v_receipt.actor_id,
    transaction_timestamp(),jsonb_build_object(
      'replacement_purchase_order_id',new.purchase_order_id,
      'document_number',v_replaced.document_number,
      'supplier_id',v_replaced.supplier_id,
      'service_date',v_replaced.school_catering_service_date));
  insert into atlas_audit.audit_events(
    event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_before,aggregate_version_after,command_receipt_id,
    command_id,correlation_id,actor_id,reason_code,reason_note,before_summary,
    after_summary,source_interface,occurred_at
  ) values(
    'SchoolCateringPurchaseOrderSuperseded','PROCUREMENT','PurchaseOrder',
    v_replaced.purchase_order_id,v_replaced.version,v_replaced.version+1,
    v_receipt.command_receipt_id,v_receipt.command_id,v_receipt.correlation_id,
    v_receipt.actor_id,'SCHOOL_CATERING_PO_REPLACED',v_revision.reason_note,
    jsonb_build_object('status','RELEASED_TO_SUPPLIER',
      'document_number',v_replaced.document_number),
    jsonb_build_object('status','SUPERSEDED',
      'replacement_purchase_order_id',new.purchase_order_id,
      'document_number',v_replaced.document_number),
    'atlas_api',transaction_timestamp());
  return new;
end;
$$;

revoke execute on function
  atlas_core.school_catering_po_replacement_release_guard()
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.school_catering_po_replacement_release_guard()
to atlas_owner;

reset role;
set role atlas_owner;
create trigger school_catering_po_replacement_release
  before update of purchase_order_status
  on atlas_procurement.purchase_orders
  for each row execute function
    atlas_core.school_catering_po_replacement_release_guard();

grant create on schema atlas_api to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;

create function atlas_api.create_school_catering_purchase_order_replacement(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_name constant text := 'create_school_catering_purchase_order_replacement';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb; v_begin jsonb; v_receipt uuid;
  v_replaced_id uuid; v_expected_revision_id uuid; v_expected_version bigint;
  v_replaced atlas_procurement.purchase_orders%rowtype;
  v_replaced_revision atlas_procurement.purchase_order_revisions%rowtype;
  v_replacement atlas_procurement.purchase_orders%rowtype;
  v_prior atlas_procurement.purchase_order_revisions%rowtype;
  v_row record; v_supplier_name text; v_readiness jsonb;
  v_revision_id uuid; v_line_id uuid; v_prior_line_id uuid;
  v_created boolean := false; v_event uuid; v_audit uuid; v_response jsonb; v_error jsonb;
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
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at')>
       transaction_timestamp()+interval '60 seconds'
     or btrim(coalesce(request ->> 'idempotency_key',''))=''
     or request ->> 'reason_code' is distinct from
       'SCHOOL_CATERING_PO_REPLACEMENT_CREATED'
     or jsonb_typeof(request -> 'payload')<>'object'
     or (request -> 'payload')-array['replaced_purchase_order_id',
       'expected_purchase_order_revision_id']<>'{}'::jsonb
     or not (request -> 'payload' ?& array['replaced_purchase_order_id',
       'expected_purchase_order_revision_id']) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The bounded replacement request is invalid.','PROCUREMENT',v_name);
  end if;
  v_replaced_id := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,replaced_purchase_order_id}');
  v_expected_revision_id := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,expected_purchase_order_revision_id}');
  v_expected_version := atlas_core.pa_05b_safe_bigint(request ->> 'expected_version');
  if v_replaced_id is null or v_expected_revision_id is null
     or v_expected_version<1 then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The released purchase order and expected revision are required.',
      'PROCUREMENT',v_name);
  end if;

  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;

  v_begin := atlas_core.pa_05b_begin_command(request,v_actor_id,v_name,'PROCUREMENT',
    'school-catering-po-replacement:' || v_replaced_id::text);
  if v_begin ->> 'status' in ('REPLAY','ERROR') then return v_begin -> 'response'; end if;
  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select po.* into v_replaced
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=v_replaced_id
    and po.purchase_order_kind='SCHOOL_CATERING';
  if v_replaced.purchase_order_id is null then
    v_error := atlas_core.pa_05b_command_error(request,'PURCHASE_ORDER_NOT_FOUND',
      'The released School-catering purchase order was not found.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'school-catering-po:' || v_replaced.school_catering_service_date::text || ':' ||
      v_replaced.supplier_id::text,0));

  for v_row in
    select f.family_id,f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,
        'allocated_quantity',s.allocated_quantity) order by s.supplier_id) splits
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    where f.service_date=v_replaced.school_catering_service_date
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
    on r.family_id=f.family_id and r.is_current
  join atlas_procurement.school_catering_allocation_supplier_splits s
    on s.family_revision_id=r.family_revision_id
  where f.service_date=v_replaced.school_catering_service_date
  order by f.family_id,s.supplier_id for share of f,r;

  select po.* into v_replaced
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=v_replaced_id for update;
  select por.* into v_replaced_revision
  from atlas_procurement.purchase_order_revisions por
  where por.purchase_order_id=v_replaced_id and por.is_current for share;
  if v_replaced.purchase_order_status<>'RELEASED_TO_SUPPLIER'
     or v_replaced.version<>v_expected_version
     or v_replaced_revision.purchase_order_revision_id is distinct from
       v_expected_revision_id then
    v_error := atlas_core.pa_05b_command_error(request,'STALE_VERSION',
      'The released purchase order no longer matches the replacement request.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if not atlas_core.school_catering_po_draft_is_stale(
      v_replaced_id,v_expected_revision_id) then
    v_error := atlas_core.pa_05b_command_error(request,'PO_REPLACEMENT_NOT_REQUIRED',
      'The released supplier commitment already matches current allocation.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if not exists(
    select 1
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date=v_replaced.school_catering_service_date
      and s.supplier_id=v_replaced.supplier_id
      and r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')
  ) then
    v_error := atlas_core.pa_05b_command_error(request,'CANCELLATION_REQUIRED',
      'The supplier has no current allocation. Resolve the active supplier commitment under an approved cancellation process before continuing.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  v_readiness := atlas_core.school_catering_po_date_readiness(
    v_replaced.school_catering_service_date);
  if not (v_readiness ->> 'ready')::boolean then
    v_error := atlas_core.pa_05b_command_error(request,'PO_REPLACEMENT_BLOCKED',
      'Current allocation is not ready for a complete replacement.',
      'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;

  select po.* into v_replacement
  from atlas_procurement.purchase_orders po
  where po.replaces_purchase_order_id=v_replaced_id
    and po.purchase_order_status='DRAFT' for update;
  if v_replacement.purchase_order_id is null then
    insert into atlas_procurement.purchase_orders(
      supplier_id,purchase_order_kind,school_catering_service_date,
      purchase_order_status,document_number,version,replaces_purchase_order_id
    ) values(v_replaced.supplier_id,'SCHOOL_CATERING',
      v_replaced.school_catering_service_date,'DRAFT',null,1,v_replaced_id)
    returning * into v_replacement;
    v_created := true;
    v_prior.purchase_order_revision_id := null;
    v_prior.revision_number := 0;
  else
    select por.* into strict v_prior
    from atlas_procurement.purchase_order_revisions por
    where por.purchase_order_id=v_replacement.purchase_order_id and por.is_current
    for update;
    if not atlas_core.school_catering_po_draft_is_stale(
        v_replacement.purchase_order_id,v_prior.purchase_order_revision_id) then
      v_error := atlas_core.pa_05b_command_error(request,
        'PO_REPLACEMENT_ALREADY_CURRENT',
        'A current replacement draft already exists for this supplier commitment.',
        'PROCUREMENT',v_name);
      return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
    end if;
    update atlas_procurement.purchase_order_revisions set is_current=false
    where purchase_order_revision_id=v_prior.purchase_order_revision_id;
    update atlas_procurement.purchase_orders
    set version=version+1,updated_at=transaction_timestamp()
    where purchase_order_id=v_replacement.purchase_order_id
    returning * into v_replacement;
  end if;

  select supplier_name into strict v_supplier_name
  from atlas_admin.suppliers where supplier_id=v_replaced.supplier_id;
  insert into atlas_procurement.purchase_order_revisions(
    purchase_order_id,revision_number,revision_kind,revision_status,is_current,
    predecessor_revision_id,service_date,delivery_location_id,
    supplier_name_snapshot,delivery_location_snapshot,released_by_actor_id,
    released_at,reason_note,command_id
  ) values(v_replacement.purchase_order_id,v_prior.revision_number+1,
    'SUPERSEDING','DRAFT',true,v_prior.purchase_order_revision_id,
    v_replaced.school_catering_service_date,null,v_supplier_name,'Nhiều điểm giao',
    null,null,request ->> 'reason_note',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'))
  returning purchase_order_revision_id into v_revision_id;

  for v_row in
    select f.family_id,f.ingredient_id,f.unit_id,f.delivery_location_id,f.service_date,
      s.supplier_split_id,s.allocated_quantity
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date=v_replaced.school_catering_service_date
      and s.supplier_id=v_replaced.supplier_id
      and r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')
    order by f.family_id
  loop
    select pol.purchase_order_line_id into v_line_id
    from atlas_procurement.purchase_order_lines pol
    where pol.purchase_order_id=v_replacement.purchase_order_id
      and pol.school_catering_allocation_family_id=v_row.family_id;
    if v_line_id is null then
      insert into atlas_procurement.purchase_order_lines(
        purchase_order_id,school_catering_allocation_family_id
      ) values(v_replacement.purchase_order_id,v_row.family_id)
      returning purchase_order_line_id into v_line_id;
    end if;
    select polr.purchase_order_line_revision_id into v_prior_line_id
    from atlas_procurement.purchase_order_line_revisions polr
    where polr.purchase_order_line_id=v_line_id
    order by polr.created_at desc,polr.purchase_order_line_revision_id desc limit 1;
    insert into atlas_procurement.purchase_order_line_revisions(
      purchase_order_revision_id,purchase_order_line_id,
      school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,
      unit_id,delivery_location_id,service_date,predecessor_revision_id
    ) values(v_revision_id,v_line_id,v_row.supplier_split_id,v_row.ingredient_id,
      v_row.allocated_quantity,v_row.unit_id,v_row.delivery_location_id,
      v_row.service_date,v_prior_line_id);
  end loop;

  insert into atlas_audit.domain_events(
    event_type,source_domain,aggregate_type,aggregate_id,aggregate_version,
    command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary
  ) values('SchoolCateringPurchaseOrderReplacementDrafted','PROCUREMENT',
    'PurchaseOrder',v_replacement.purchase_order_id,v_replacement.version,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    transaction_timestamp(),jsonb_build_object(
      'replaces_purchase_order_id',v_replaced_id,
      'purchase_order_revision_id',v_revision_id,
      'supplier_id',v_replaced.supplier_id,
      'service_date',v_replaced.school_catering_service_date))
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(
    event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,
    reason_code,reason_note,after_summary,source_interface,occurred_at
  ) values('SchoolCateringPurchaseOrderReplacementDrafted','PROCUREMENT',
    'PurchaseOrder',v_replacement.purchase_order_id,v_replacement.version,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    request ->> 'reason_code',request ->> 'reason_note',jsonb_build_object(
      'status','DRAFT','replaces_purchase_order_id',v_replaced_id,
      'purchase_order_revision_id',v_revision_id),
    'atlas_api',transaction_timestamp()) returning audit_event_id into v_audit;

  v_response := jsonb_build_object('success',true,
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'command_id',request ->> 'command_id','correlation_id',request ->> 'correlation_id',
    'idempotency_status','COMPLETED',
    'purchase_order_id',v_replacement.purchase_order_id,
    'purchase_order_revision_id',v_revision_id,
    'replaces_purchase_order_id',v_replaced_id,
    'new_version',v_replacement.version,
    'created',v_created,'emitted_event_ids',jsonb_build_array(v_event),
    'audit_event_ids',jsonb_build_array(v_audit),
    'authoritative_readback',jsonb_build_object(
      'purchase_order_id',v_replacement.purchase_order_id,
      'purchase_order_revision_id',v_revision_id,
      'replaces_purchase_order_id',v_replaced_id,
      'status','DRAFT','version',v_replacement.version,
      'document_number',null),
    'safe_operator_message','Đã tạo đơn mua thay thế đầy đủ để kiểm tra.',
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when serialization_failure or deadlock_detected or unique_violation then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'The replacement draft could not acquire a safe transaction state. Retry the exact request.',
    'PROCUREMENT',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'The replacement draft could not be created safely.','PROCUREMENT',v_name);
end;
$$;

revoke execute on function
  atlas_api.create_school_catering_purchase_order_replacement(jsonb)
from public,anon,service_role;
grant execute on function
  atlas_api.create_school_catering_purchase_order_replacement(jsonb)
to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_procurement_command_runtime;
revoke create on schema atlas_core from atlas_procurement_command_runtime;

-- Preserve the v1 read contract while enriching each row with replacement and
-- removed-supplier state. The base function remains private to its owner.
grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

alter function atlas_api.get_school_catering_purchase_orders(jsonb)
  rename to get_school_catering_purchase_orders_v1_base;
revoke execute on function
  atlas_api.get_school_catering_purchase_orders_v1_base(jsonb)
from public,anon,authenticated,service_role;

create function atlas_api.get_school_catering_purchase_orders(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_base jsonb; v_rows jsonb; v_current boolean; v_date_start date; v_date_end date;
begin
  v_base := atlas_api.get_school_catering_purchase_orders_v1_base(request);
  if not coalesce((v_base ->> 'success')::boolean,false) then return v_base; end if;
  v_date_start := (v_base ->> 'date_start')::date;
  v_date_end := (v_base ->> 'date_end')::date;

  with shaped as (
    select item.value original,po.purchase_order_id,po.purchase_order_status,
      po.replaces_purchase_order_id,por.purchase_order_revision_id,
      atlas_core.school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id) commitment_state,
      (select child.purchase_order_id
       from atlas_procurement.purchase_orders child
       where child.replaces_purchase_order_id=po.purchase_order_id
       order by child.created_at desc limit 1) replaced_by_purchase_order_id,
      exists(
        select 1
        from atlas_procurement.purchase_orders child
        join atlas_procurement.purchase_order_revisions child_revision
          on child_revision.purchase_order_id=child.purchase_order_id
         and child_revision.is_current
        where child.replaces_purchase_order_id=po.purchase_order_id
          and child.purchase_order_status='DRAFT'
          and atlas_core.school_catering_po_draft_is_stale(
            child.purchase_order_id,child_revision.purchase_order_revision_id)
      ) replacement_draft_stale
    from jsonb_array_elements(v_base -> 'purchase_orders') item
    join atlas_procurement.purchase_orders po
      on po.purchase_order_id=(item.value ->> 'purchase_order_id')::uuid
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
  )
  select coalesce(jsonb_agg(
    s.original || jsonb_build_object(
      'replaces_purchase_order_id',s.replaces_purchase_order_id,
      'replaced_by_purchase_order_id',s.replaced_by_purchase_order_id,
      'commitment_state',s.commitment_state,
      'stale',s.commitment_state in (
        'DRAFT_STALE','REPLACEMENT_REQUIRED','CANCELLATION_REQUIRED'),
      'release_eligible',s.commitment_state='DRAFT_CURRENT',
      'export_ready',s.purchase_order_status in (
        'RELEASED_TO_SUPPLIER','SUPERSEDED'),
      'blockers',case s.commitment_state
        when 'REPLACEMENT_REQUIRED' then jsonb_build_array('PO_REPLACEMENT_REQUIRED')
        when 'CANCELLATION_REQUIRED' then jsonb_build_array('CANCELLATION_REQUIRED')
        else s.original -> 'blockers' end,
      'allowed_actions',(s.original -> 'allowed_actions') || jsonb_build_object(
        'release',s.commitment_state='DRAFT_CURRENT',
        'export',s.purchase_order_status in ('RELEASED_TO_SUPPLIER','SUPERSEDED'),
        'create_replacement',s.commitment_state='REPLACEMENT_REQUIRED'
          and (s.replaced_by_purchase_order_id is null
            or s.replacement_draft_stale)),
      'disabled_reasons',case s.commitment_state
        when 'REPLACEMENT_REQUIRED' then jsonb_build_array('PO_REPLACEMENT_REQUIRED')
        when 'CANCELLATION_REQUIRED' then jsonb_build_array('CANCELLATION_REQUIRED')
        when 'SUPERSEDED' then jsonb_build_array('PO_SUPERSEDED')
        else s.original -> 'disabled_reasons' end
    ) order by s.original ->> 'service_date',
      s.original #>> '{supplier,supplier_name}',s.purchase_order_id
  ),'[]'::jsonb) into v_rows from shaped s;

  select not exists(
    select 1
    from (
      select distinct po.school_catering_service_date service_date
      from atlas_procurement.purchase_orders po
      where po.purchase_order_kind='SCHOOL_CATERING'
        and po.school_catering_service_date between v_date_start and v_date_end
    ) scoped
    where not atlas_core.school_catering_procurement_date_current(scoped.service_date)
  ) into v_current;

  return v_base || jsonb_build_object(
    'purchase_orders',v_rows,'procurement_current',v_current,
    'blockers',case when v_current then '[]'::jsonb
      else jsonb_build_array('PROCUREMENT_NOT_CURRENT') end);
exception when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_READ_FAILURE',
    'The School-catering purchase orders could not be read safely.',
    'PROCUREMENT','get_school_catering_purchase_orders');
end;
$$;

revoke execute on function atlas_api.get_school_catering_purchase_orders(jsonb)
from public,anon,service_role;
grant execute on function atlas_api.get_school_catering_purchase_orders(jsonb)
to authenticated;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;

reset role;
grant atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set false;
