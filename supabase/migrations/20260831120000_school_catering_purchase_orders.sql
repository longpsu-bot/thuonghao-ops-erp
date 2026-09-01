-- School-catering Purchase Order drafts, release, and authoritative read.

reset role;
grant atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set true;
set role atlas_owner;

alter table atlas_procurement.purchase_orders
  add column purchase_order_kind text not null default 'SUPPLIER_DIRECT_WHOLESALE',
  add column school_catering_service_date date;

alter table atlas_procurement.purchase_orders
  add constraint purchase_orders_kind_check
    check (purchase_order_kind in ('SUPPLIER_DIRECT_WHOLESALE','SCHOOL_CATERING')),
  add constraint purchase_orders_school_catering_date_check
    check (
      (purchase_order_kind='SCHOOL_CATERING' and school_catering_service_date is not null)
      or
      (purchase_order_kind='SUPPLIER_DIRECT_WHOLESALE' and school_catering_service_date is null)
    );

create unique index purchase_orders_school_catering_supplier_date_key
  on atlas_procurement.purchase_orders(supplier_id,school_catering_service_date)
  where purchase_order_kind='SCHOOL_CATERING'
    and purchase_order_status not in ('CANCELLED','SUPERSEDED');

alter table atlas_procurement.purchase_order_lines
  alter column fulfilment_allocation_line_id drop not null,
  add column school_catering_allocation_family_id uuid
    references atlas_procurement.school_catering_allocation_families(family_id)
    on delete restrict,
  add constraint purchase_order_lines_source_xor_check
    check (num_nonnulls(
      fulfilment_allocation_line_id,school_catering_allocation_family_id
    )=1);

create unique index purchase_order_lines_school_catering_family_key
  on atlas_procurement.purchase_order_lines(
    purchase_order_id,school_catering_allocation_family_id
  ) where school_catering_allocation_family_id is not null;

create index purchase_order_lines_school_catering_family_idx
  on atlas_procurement.purchase_order_lines(school_catering_allocation_family_id)
  where school_catering_allocation_family_id is not null;

alter table atlas_procurement.purchase_order_line_revisions
  alter column fulfilment_allocation_line_revision_id drop not null,
  add column school_catering_allocation_supplier_split_id uuid
    references atlas_procurement.school_catering_allocation_supplier_splits(
      supplier_split_id
    ) on delete restrict,
  add constraint purchase_order_line_revisions_source_xor_check
    check (num_nonnulls(
      fulfilment_allocation_line_revision_id,
      school_catering_allocation_supplier_split_id
    )=1);

create index purchase_order_line_revisions_school_catering_split_idx
  on atlas_procurement.purchase_order_line_revisions(
    school_catering_allocation_supplier_split_id
  ) where school_catering_allocation_supplier_split_id is not null;

alter table atlas_procurement.purchase_order_revisions
  alter column delivery_location_id drop not null;

create function atlas_core.purchase_order_revision_integrity_guard()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_revision_id uuid;
  v_root atlas_procurement.purchase_orders%rowtype;
  v_revision atlas_procurement.purchase_order_revisions%rowtype;
begin
  if tg_table_name='purchase_order_revisions' then
    v_revision_id := new.purchase_order_revision_id;
  else
    v_revision_id := new.purchase_order_revision_id;
  end if;

  select por.* into v_revision
  from atlas_procurement.purchase_order_revisions por
  where por.purchase_order_revision_id=v_revision_id;
  if not found then
    return new;
  end if;

  select po.* into strict v_root
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=v_revision.purchase_order_id;

  if not exists(
    select 1
    from atlas_procurement.purchase_order_line_revisions polr
    where polr.purchase_order_revision_id=v_revision_id
  ) then
    raise exception using errcode='23514',
      message='purchase order revision requires at least one line revision';
  end if;

  if exists(
    select 1
    from atlas_procurement.purchase_order_line_revisions polr
    join atlas_procurement.purchase_order_lines pol
      on pol.purchase_order_line_id=polr.purchase_order_line_id
    where polr.purchase_order_revision_id=v_revision_id
      and pol.purchase_order_id<>v_revision.purchase_order_id
  ) then
    raise exception using errcode='23514',
      message='purchase order revision and stable line roots must match';
  end if;

  if v_root.purchase_order_kind='SUPPLIER_DIRECT_WHOLESALE' then
    if v_revision.delivery_location_id is null then
      raise exception using errcode='23514',
        message='wholesale purchase order revision requires header delivery location';
    end if;
    if exists(
      select 1
      from atlas_procurement.purchase_order_line_revisions polr
      where polr.purchase_order_revision_id=v_revision_id
        and (
          polr.delivery_location_id<>v_revision.delivery_location_id
          or polr.service_date<>v_revision.service_date
          or polr.fulfilment_allocation_line_revision_id is null
          or polr.school_catering_allocation_supplier_split_id is not null
        )
    ) then
      raise exception using errcode='23514',
        message='wholesale PO lines must match the authoritative header';
    end if;
  else
    if v_revision.delivery_location_id is not null
       or v_revision.delivery_location_snapshot<>'Nhiều điểm giao'
       or v_revision.service_date<>v_root.school_catering_service_date then
      raise exception using errcode='23514',
        message='school-catering PO revision requires multi-destination header shape';
    end if;
    if exists(
      select 1
      from atlas_procurement.purchase_order_line_revisions polr
      where polr.purchase_order_revision_id=v_revision_id
        and (
          polr.delivery_location_id is null
          or polr.service_date<>v_root.school_catering_service_date
          or polr.fulfilment_allocation_line_revision_id is not null
          or polr.school_catering_allocation_supplier_split_id is null
        )
    ) then
      raise exception using errcode='23514',
        message='school-catering PO lines require exact split, location, and date';
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function atlas_core.purchase_order_revision_integrity_guard()
  from public;

create constraint trigger school_catering_purchase_order_revision_integrity
  after insert or update on atlas_procurement.purchase_order_revisions
  deferrable initially deferred
  for each row execute function atlas_core.purchase_order_revision_integrity_guard();

create constraint trigger school_catering_purchase_order_line_revision_integrity
  after insert or update on atlas_procurement.purchase_order_line_revisions
  deferrable initially deferred
  for each row execute function atlas_core.purchase_order_revision_integrity_guard();

comment on column atlas_procurement.purchase_orders.purchase_order_kind is
  'Shared PO source kind; wholesale remains the migration-safe default.';
comment on column atlas_procurement.purchase_orders.school_catering_service_date is
  'Supplier/date identity grain for SCHOOL_CATERING PO roots only.';
comment on column atlas_procurement.purchase_order_lines.school_catering_allocation_family_id is
  'Stable school-catering PO line source, mutually exclusive with wholesale allocation line.';
comment on column atlas_procurement.purchase_order_line_revisions.school_catering_allocation_supplier_split_id is
  'Immutable school-catering PO line-revision source, mutually exclusive with wholesale allocation revision.';

create function atlas_core.school_catering_po_date_readiness(p_service_date date)
returns jsonb
language sql
stable
security invoker
set search_path=''
as $$
  with source_families as (
    select distinct lr.service_date,lr.delivery_location_id,lr.ingredient_id,lr.unit_id
    from atlas_planning.purchase_handoff_batches b
    join atlas_planning.purchase_handoff_revisions hr
      on hr.purchase_handoff_batch_id=b.purchase_handoff_batch_id
     and hr.is_current and hr.revision_status='RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_handoff_line_revisions lr
      on lr.purchase_handoff_revision_id=hr.purchase_handoff_revision_id
    join atlas_planning.purchase_demand_references d
      on d.purchase_handoff_line_revision_id=lr.purchase_handoff_line_revision_id
     and d.source_kind='NEED_GENERATION'
    where b.handoff_status='RELEASED_TO_PROCUREMENT'
      and lr.service_date=p_service_date
  ), states as (
    select sf.*,f.family_id,r.family_revision_id,r.source_fingerprint,
      projection.value projection,
      (select count(*) from atlas_procurement.school_catering_allocation_supplier_splits s
        where s.family_revision_id=r.family_revision_id) split_count,
      (select coalesce(sum(s.allocated_quantity),0)
        from atlas_procurement.school_catering_allocation_supplier_splits s
        where s.family_revision_id=r.family_revision_id) split_quantity,
      case
        when f.family_id is null or r.family_revision_id is null then 'ALLOCATION_MISSING'
        when r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
          or r.family_quantity is distinct from
            atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')
          then 'SOURCE_CHANGED'
        when not exists(
          select 1
          from atlas_procurement.school_catering_allocation_supplier_splits s
          where s.family_revision_id=r.family_revision_id
        ) or (select coalesce(sum(s.allocated_quantity),0)
          from atlas_procurement.school_catering_allocation_supplier_splits s
          where s.family_revision_id=r.family_revision_id)<>r.family_quantity
          then 'ALLOCATION_IMBALANCED'
        when exists(
          select 1
          from atlas_procurement.school_catering_allocation_supplier_splits s
          left join atlas_admin.suppliers supplier on supplier.supplier_id=s.supplier_id
          where s.family_revision_id=r.family_revision_id
            and (
              supplier.supplier_id is null or supplier.supplier_status<>'ACTIVE'
              or not exists(
                select 1 from atlas_admin.supplier_eligibilities eligibility
                where eligibility.supplier_id=s.supplier_id
                  and eligibility.ingredient_id=sf.ingredient_id
                  and eligibility.eligibility_status='ACTIVE'
                  and eligibility.effective_from<=p_service_date
                  and (eligibility.effective_to is null
                    or eligibility.effective_to>p_service_date)
              )
            )
        )
          then 'SUPPLIER_INELIGIBLE'
        else null
      end blocker
    from source_families sf
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        sf.service_date,sf.delivery_location_id,sf.ingredient_id,sf.unit_id
      ) value
    ) projection
    left join atlas_procurement.school_catering_allocation_families f
      on f.service_date=sf.service_date
     and f.delivery_location_id=sf.delivery_location_id
     and f.ingredient_id=sf.ingredient_id and f.unit_id=sf.unit_id
    left join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
  ), blockers as (
    select coalesce(jsonb_agg(jsonb_build_object(
      'service_date',service_date,'delivery_location_id',delivery_location_id,
      'ingredient_id',ingredient_id,'unit_id',unit_id,'family_id',family_id,
      'family_revision_id',family_revision_id,'reason',blocker
    ) order by delivery_location_id,ingredient_id,unit_id)
      filter(where blocker is not null),'[]'::jsonb) value
    from states
  )
  select jsonb_build_object(
    'service_date',p_service_date,
    'family_count',(select count(*) from states),
    'ready',(select count(*)>0 and count(*) filter(where blocker is not null)=0 from states),
    'blockers',case when (select count(*) from states)=0
      then jsonb_build_array(jsonb_build_object(
        'service_date',p_service_date,'reason','NO_CURRENT_FAMILIES'))
      else blockers.value end
  )
  from blockers;
$$;

create function atlas_core.school_catering_po_draft_is_stale(
  p_purchase_order_id uuid,p_purchase_order_revision_id uuid
) returns boolean
language sql
stable
security invoker
set search_path=''
as $$
  with root as (
    select po.supplier_id,po.school_catering_service_date
    from atlas_procurement.purchase_orders po
    where po.purchase_order_id=p_purchase_order_id
      and po.purchase_order_kind='SCHOOL_CATERING'
  ), expected as (
    select s.supplier_split_id
    from root
    join atlas_procurement.school_catering_allocation_families f
      on f.service_date=root.school_catering_service_date
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id and s.supplier_id=root.supplier_id
  ), actual as (
    select polr.school_catering_allocation_supplier_split_id supplier_split_id
    from atlas_procurement.purchase_order_line_revisions polr
    where polr.purchase_order_revision_id=p_purchase_order_revision_id
  )
  select exists(
    select 1
    from atlas_procurement.purchase_order_line_revisions polr
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.supplier_split_id=polr.school_catering_allocation_supplier_split_id
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_revision_id=s.family_revision_id
    join atlas_procurement.school_catering_allocation_families f using(family_id)
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where polr.purchase_order_revision_id=p_purchase_order_revision_id
      and (not r.is_current
        or r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint')
  ) or exists((select supplier_split_id from expected except select supplier_split_id from actual))
    or exists((select supplier_split_id from actual except select supplier_split_id from expected));
$$;

revoke execute on function atlas_core.school_catering_po_date_readiness(date),
  atlas_core.school_catering_po_draft_is_stale(uuid,uuid) from public;
grant execute on function atlas_core.school_catering_po_date_readiness(date),
  atlas_core.school_catering_po_draft_is_stale(uuid,uuid)
  to atlas_procurement_command_runtime,atlas_read_runtime;

grant update(document_number,purchase_order_status,version,updated_at)
  on atlas_procurement.purchase_orders to atlas_procurement_command_runtime;
grant update(is_current) on atlas_procurement.purchase_order_revisions
  to atlas_procurement_command_runtime;

create policy school_catering_po_root_update
  on atlas_procurement.purchase_orders for update
  to atlas_procurement_command_runtime
  using(purchase_order_kind='SCHOOL_CATERING')
  with check(purchase_order_kind='SCHOOL_CATERING');
create policy school_catering_po_revision_update
  on atlas_procurement.purchase_order_revisions for update
  to atlas_procurement_command_runtime
  using(exists(
    select 1 from atlas_procurement.purchase_orders po
    where po.purchase_order_id=purchase_order_revisions.purchase_order_id
      and po.purchase_order_kind='SCHOOL_CATERING'
  ))
  with check(exists(
    select 1 from atlas_procurement.purchase_orders po
    where po.purchase_order_id=purchase_order_revisions.purchase_order_id
      and po.purchase_order_kind='SCHOOL_CATERING'
  ));

grant create on schema atlas_api to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;

create function atlas_api.create_school_catering_purchase_order_drafts(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_name constant text := 'create_school_catering_purchase_order_drafts';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb; v_begin jsonb; v_receipt uuid;
  v_date_start date; v_date_end date; v_date date; v_readiness jsonb;
  v_ready_dates jsonb := '[]'::jsonb; v_skipped_dates jsonb := '[]'::jsonb;
  v_created jsonb := '[]'::jsonb; v_regenerated jsonb := '[]'::jsonb;
  v_supplier record; v_row record; v_root record; v_prior record;
  v_purchase_order_id uuid; v_purchase_order_revision_id uuid;
  v_purchase_order_line_id uuid; v_predecessor_line_revision_id uuid;
  v_revision_number integer; v_event uuid; v_audit uuid; v_response jsonb;
  v_supplier_name text; v_is_stale boolean;
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
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version')<>1
     or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at') is null
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at')>transaction_timestamp()
     or btrim(coalesce(request ->> 'idempotency_key',''))=''
     or request ->> 'reason_code' is distinct from 'SCHOOL_CATERING_PO_DRAFTS_CREATED'
     or jsonb_typeof(request -> 'payload')<>'object'
     or (request -> 'payload')-array['date_start','date_end']<>'{}'::jsonb
     or not (request -> 'payload' ?& array['date_start','date_end']) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The bounded school-catering PO draft request is invalid.','PROCUREMENT',v_name);
  end if;
  begin
    v_date_start := nullif(btrim(request #>> '{payload,date_start}'),'')::date;
    v_date_end := nullif(btrim(request #>> '{payload,date_end}'),'')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The PO draft date range is invalid.','PROCUREMENT',v_name);
  end;
  if v_date_start is null or v_date_end is null or v_date_end<v_date_start
     or v_date_end-v_date_start>30 then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Use an inclusive date range of at most 31 days.','PROCUREMENT',v_name);
  end if;

  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;

  -- Derive complete date readiness before the command receipt or any domain write.
  for v_date in select generate_series(v_date_start,v_date_end,interval '1 day')::date loop
    v_readiness := atlas_core.school_catering_po_date_readiness(v_date);
    if (v_readiness ->> 'ready')::boolean then
      v_ready_dates := v_ready_dates || jsonb_build_array(to_char(v_date,'YYYY-MM-DD'));
    else
      v_skipped_dates := v_skipped_dates || jsonb_build_array(v_readiness);
    end if;
  end loop;

  v_begin := atlas_core.pa_05b_begin_command(request,v_actor_id,v_name,'PROCUREMENT',
    'school-catering-po-drafts:' || v_date_start::text || ':' || v_date_end::text);
  if v_begin ->> 'status' in ('REPLAY','ERROR') then return v_begin -> 'response'; end if;
  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  -- Reuse PR-A's deterministic evidence locks, then lock family revisions.
  for v_row in
    select f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,
        'allocated_quantity',s.allocated_quantity) order by s.supplier_id) splits
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    where f.service_date between v_date_start and v_date_end
    group by f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
    order by f.service_date,f.ingredient_id,f.delivery_location_id,f.unit_id
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
  where f.service_date between v_date_start and v_date_end
  order by f.family_id for update of f,r;

  -- Recompute readiness under the deterministic source locks.
  v_ready_dates := '[]'::jsonb; v_skipped_dates := '[]'::jsonb;
  for v_date in select generate_series(v_date_start,v_date_end,interval '1 day')::date loop
    v_readiness := atlas_core.school_catering_po_date_readiness(v_date);
    if (v_readiness ->> 'ready')::boolean then
      v_ready_dates := v_ready_dates || jsonb_build_array(to_char(v_date,'YYYY-MM-DD'));
    else
      v_skipped_dates := v_skipped_dates || jsonb_build_array(v_readiness);
    end if;
  end loop;

  for v_supplier in
    select distinct f.service_date,s.supplier_id
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    where to_char(f.service_date,'YYYY-MM-DD') in (
      select value #>> '{}' from jsonb_array_elements(v_ready_dates)
    )
    order by f.service_date,s.supplier_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'school-catering-po:' || v_supplier.service_date::text || ':' || v_supplier.supplier_id::text,0));
    select null::uuid purchase_order_revision_id,0::integer revision_number into v_prior;
    select po.purchase_order_id,po.purchase_order_status,po.version
      into v_root
    from atlas_procurement.purchase_orders po
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.supplier_id=v_supplier.supplier_id
      and po.school_catering_service_date=v_supplier.service_date
      and po.purchase_order_status not in ('CANCELLED','SUPERSEDED')
    for update;

    if v_root.purchase_order_id is null then
      insert into atlas_procurement.purchase_orders(
        supplier_id,purchase_order_kind,school_catering_service_date,
        purchase_order_status,document_number,version
      ) values(v_supplier.supplier_id,'SCHOOL_CATERING',v_supplier.service_date,
        'DRAFT',null,1)
      returning purchase_order_id into v_purchase_order_id;
      v_revision_number := 1;
      v_prior.purchase_order_revision_id := null;
      v_created := v_created || jsonb_build_array(v_purchase_order_id);
    elsif v_root.purchase_order_status='RELEASED_TO_SUPPLIER' then
      continue;
    else
      v_purchase_order_id := v_root.purchase_order_id;
      select por.purchase_order_revision_id,por.revision_number
        into v_prior
      from atlas_procurement.purchase_order_revisions por
      where por.purchase_order_id=v_purchase_order_id and por.is_current
      for update;
      v_is_stale := atlas_core.school_catering_po_draft_is_stale(
        v_purchase_order_id,v_prior.purchase_order_revision_id);
      if not v_is_stale then continue; end if;
      update atlas_procurement.purchase_order_revisions set is_current=false
      where purchase_order_revision_id=v_prior.purchase_order_revision_id;
      update atlas_procurement.purchase_orders
      set version=version+1,updated_at=transaction_timestamp()
      where purchase_order_id=v_purchase_order_id;
      v_revision_number := v_prior.revision_number+1;
      v_regenerated := v_regenerated || jsonb_build_array(v_purchase_order_id);
    end if;

    select supplier_name into strict v_supplier_name
    from atlas_admin.suppliers where supplier_id=v_supplier.supplier_id;
    insert into atlas_procurement.purchase_order_revisions(
      purchase_order_id,revision_number,revision_kind,revision_status,is_current,
      predecessor_revision_id,service_date,delivery_location_id,
      supplier_name_snapshot,delivery_location_snapshot,released_by_actor_id,
      released_at,reason_note,command_id
    ) values(v_purchase_order_id,v_revision_number,
      case when v_revision_number=1 then 'BASE' else 'SUPERSEDING' end,
      'DRAFT',true,v_prior.purchase_order_revision_id,v_supplier.service_date,null,
      v_supplier_name,'Nhiều điểm giao',null,null,request ->> 'reason_note',
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'))
    returning purchase_order_revision_id into v_purchase_order_revision_id;

    for v_row in
      select f.family_id,f.ingredient_id,f.unit_id,f.delivery_location_id,f.service_date,
        s.supplier_split_id,s.allocated_quantity
      from atlas_procurement.school_catering_allocation_families f
      join atlas_procurement.school_catering_allocation_family_revisions r
        on r.family_id=f.family_id and r.is_current
      join atlas_procurement.school_catering_allocation_supplier_splits s
        on s.family_revision_id=r.family_revision_id
      where f.service_date=v_supplier.service_date and s.supplier_id=v_supplier.supplier_id
      order by f.family_id
    loop
      select pol.purchase_order_line_id into v_purchase_order_line_id
      from atlas_procurement.purchase_order_lines pol
      where pol.purchase_order_id=v_purchase_order_id
        and pol.school_catering_allocation_family_id=v_row.family_id;
      if v_purchase_order_line_id is null then
        insert into atlas_procurement.purchase_order_lines(
          purchase_order_id,school_catering_allocation_family_id
        ) values(v_purchase_order_id,v_row.family_id)
        returning purchase_order_line_id into v_purchase_order_line_id;
      end if;
      select polr.purchase_order_line_revision_id
        into v_predecessor_line_revision_id
      from atlas_procurement.purchase_order_line_revisions polr
      where polr.purchase_order_line_id=v_purchase_order_line_id
      order by polr.created_at desc,polr.purchase_order_line_revision_id desc limit 1;
      insert into atlas_procurement.purchase_order_line_revisions(
        purchase_order_revision_id,purchase_order_line_id,
        school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,
        unit_id,delivery_location_id,service_date,predecessor_revision_id
      ) values(v_purchase_order_revision_id,v_purchase_order_line_id,
        v_row.supplier_split_id,v_row.ingredient_id,v_row.allocated_quantity,
        v_row.unit_id,v_row.delivery_location_id,v_row.service_date,
        v_predecessor_line_revision_id);
    end loop;
  end loop;

  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version,command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary)
  values('SchoolCateringPurchaseOrderDraftsMaterialized','PROCUREMENT','PurchaseOrderSet',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),1,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    transaction_timestamp(),jsonb_build_object('created_purchase_order_ids',v_created,
      'regenerated_purchase_order_ids',v_regenerated,'ready_dates',v_ready_dates,
      'skipped_dates',v_skipped_dates))
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,
    reason_code,reason_note,after_summary,source_interface,occurred_at)
  values('SchoolCateringPurchaseOrderDraftsMaterialized','PROCUREMENT','PurchaseOrderSet',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),1,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    request ->> 'reason_code',request ->> 'reason_note',jsonb_build_object(
      'created_purchase_order_ids',v_created,'regenerated_purchase_order_ids',v_regenerated,
      'ready_dates',v_ready_dates,'skipped_dates',v_skipped_dates),
    'atlas_api',transaction_timestamp())
  returning audit_event_id into v_audit;
  v_response := jsonb_build_object('success',true,
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'command_id',request ->> 'command_id','correlation_id',request ->> 'correlation_id',
    'idempotency_status','COMPLETED','created_purchase_order_ids',v_created,
    'regenerated_purchase_order_ids',v_regenerated,'ready_dates',v_ready_dates,
    'skipped_dates',v_skipped_dates,'emitted_event_ids',jsonb_build_array(v_event),
    'audit_event_ids',jsonb_build_array(v_audit),
    'safe_operator_message','Đã tạo các đơn mua cho ngày sẵn sàng.',
    'warnings','[]'::jsonb,'blockers',v_skipped_dates);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when serialization_failure or deadlock_detected or unique_violation then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'The PO drafts could not acquire a safe transaction state. Retry the exact request.',
    'PROCUREMENT',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'The school-catering PO drafts could not be materialized safely.',
    'PROCUREMENT',v_name);
end;
$$;

revoke execute on function atlas_api.create_school_catering_purchase_order_drafts(jsonb)
  from public,anon,service_role;
grant execute on function atlas_api.create_school_catering_purchase_order_drafts(jsonb)
  to authenticated;
reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_procurement_command_runtime;

reset role;
grant atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set false;
