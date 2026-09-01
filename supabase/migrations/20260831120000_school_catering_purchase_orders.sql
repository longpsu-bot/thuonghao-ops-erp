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

create function atlas_api.release_school_catering_purchase_order(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path=''
as $$
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
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at')>transaction_timestamp()
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
      on r.family_id=f.family_id and r.is_current
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
    on r.family_id=f.family_id and r.is_current
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
$$;

revoke execute on function atlas_api.create_school_catering_purchase_order_drafts(jsonb)
  from public,anon,service_role;
revoke execute on function atlas_api.release_school_catering_purchase_order(jsonb)
  from public,anon,service_role;
grant execute on function atlas_api.create_school_catering_purchase_order_drafts(jsonb)
  to authenticated;
grant execute on function atlas_api.release_school_catering_purchase_order(jsonb)
  to authenticated;
reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_procurement_command_runtime;

grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

create function atlas_api.get_school_catering_purchase_orders(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_name constant text := 'get_school_catering_purchase_orders';
  v_actor jsonb; v_actor_id uuid; v_auth jsonb;
  v_date_start date; v_date_end date; v_search text; v_rows jsonb;
begin
  if request is null or jsonb_typeof(request)<>'object'
     or not (request ?& array['contract_version','requested_by_auth_subject',
       'correlation_id','payload'])
     or request-array['contract_version','requested_by_auth_subject','correlation_id',
       'payload']<>'{}'::jsonb
     or request ->> 'contract_version' is distinct from 'SCHOOL-CATERING-PROCUREMENT.v1'
     or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
     or jsonb_typeof(request -> 'payload')<>'object'
     or (request -> 'payload')-array['date_start','date_end','supplier_ids',
       'statuses','search']<>'{}'::jsonb
     or not (request -> 'payload' ?& array['date_start','date_end','supplier_ids',
       'statuses','search'])
     or jsonb_typeof(request #> '{payload,supplier_ids}')<>'array'
     or jsonb_typeof(request #> '{payload,statuses}')<>'array' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Provide a valid bounded school-catering purchase-order scope.',
      'PROCUREMENT',v_name);
  end if;
  begin
    v_date_start := nullif(btrim(request #>> '{payload,date_start}'),'')::date;
    v_date_end := nullif(btrim(request #>> '{payload,date_end}'),'')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The purchase-order date range is invalid.','PROCUREMENT',v_name);
  end;
  v_search := nullif(btrim(request #>> '{payload,search}'),'');
  if v_date_start is null or v_date_end is null or v_date_end<v_date_start
     or v_date_end-v_date_start>30
     or exists(select 1 from jsonb_array_elements_text(
       request #> '{payload,supplier_ids}') value
       where atlas_core.pa_05b_safe_uuid(value) is null)
     or exists(select 1 from jsonb_array_elements_text(
       request #> '{payload,statuses}') value
       where value not in ('DRAFT','RELEASED_TO_SUPPLIER')) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Use valid supplier/status filters and an inclusive range of at most 31 days.',
      'PROCUREMENT',v_name);
  end if;

  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.read','PROCUREMENT',v_name,null,null,null);
  if v_auth is not null and v_auth ->> 'error_code'<>'SCOPE_DENIED' then return v_auth; end if;

  with base as (
    select po.*,por.purchase_order_revision_id,por.revision_number,
      por.revision_kind,por.revision_status,por.predecessor_revision_id,
      por.supplier_name_snapshot,por.delivery_location_snapshot,
      por.released_by_actor_id,por.released_at,por.reason_note,
      supplier.supplier_name,supplier.supplier_status,
      atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,por.purchase_order_revision_id) stale
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    join atlas_admin.suppliers supplier on supplier.supplier_id=po.supplier_id
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date between v_date_start and v_date_end
      and (jsonb_array_length(request #> '{payload,supplier_ids}')=0
        or po.supplier_id::text in (
          select jsonb_array_elements_text(request #> '{payload,supplier_ids}')))
      and (jsonb_array_length(request #> '{payload,statuses}')=0
        or po.purchase_order_status in (
          select jsonb_array_elements_text(request #> '{payload,statuses}')))
      and not exists(
        select 1
        from atlas_procurement.purchase_order_line_revisions scoped_line
        where scoped_line.purchase_order_revision_id=por.purchase_order_revision_id
          and not atlas_core.school_catering_actor_has_scope(
            v_actor_id,null,null,scoped_line.delivery_location_id)
      )
      and (v_search is null or supplier.supplier_name ilike '%' || v_search || '%'
        or coalesce(po.document_number,'') ilike '%' || v_search || '%'
        or exists(
          select 1
          from atlas_procurement.purchase_order_line_revisions searched_line
          join atlas_admin.ingredients ingredient
            on ingredient.ingredient_id=searched_line.ingredient_id
          join atlas_admin.delivery_locations location
            on location.delivery_location_id=searched_line.delivery_location_id
          where searched_line.purchase_order_revision_id=por.purchase_order_revision_id
            and (ingredient.ingredient_name ilike '%' || v_search || '%'
              or location.location_name ilike '%' || v_search || '%')))
  ), shaped as (
    select b.*,
      coalesce((select jsonb_agg(jsonb_build_object(
        'purchase_order_line_revision_id',line.purchase_order_line_revision_id,
        'purchase_order_line_id',line.purchase_order_line_id,
        'ingredient',jsonb_build_object('ingredient_id',line.ingredient_id,
          'ingredient_name',ingredient.ingredient_name),
        'ordered_quantity',line.ordered_quantity,
        'unit',jsonb_build_object('unit_id',line.unit_id,'unit_code',unit.unit_code),
        'delivery_location',jsonb_build_object(
          'delivery_location_id',line.delivery_location_id,
          'location_name',location.location_name),
        'service_date',line.service_date,
        'source',jsonb_build_object(
          'family_id',family.family_id,
          'family_revision_id',split.family_revision_id,
          'supplier_split_id',line.school_catering_allocation_supplier_split_id)
      ) order by location.location_name,ingredient.ingredient_name,line.purchase_order_line_id)
      from atlas_procurement.purchase_order_line_revisions line
      join atlas_procurement.purchase_order_lines stable
        on stable.purchase_order_line_id=line.purchase_order_line_id
      join atlas_procurement.school_catering_allocation_supplier_splits split
        on split.supplier_split_id=line.school_catering_allocation_supplier_split_id
      join atlas_procurement.school_catering_allocation_families family
        on family.family_id=stable.school_catering_allocation_family_id
      join atlas_admin.ingredients ingredient on ingredient.ingredient_id=line.ingredient_id
      join atlas_admin.units unit on unit.unit_id=line.unit_id
      join atlas_admin.delivery_locations location
        on location.delivery_location_id=line.delivery_location_id
      where line.purchase_order_revision_id=b.purchase_order_revision_id),'[]'::jsonb) lines,
      not exists(
        select 1 from atlas_procurement.purchase_order_line_revisions line
        where line.purchase_order_revision_id=b.purchase_order_revision_id
          and not exists(
            select 1 from atlas_admin.supplier_eligibilities eligibility
            where eligibility.supplier_id=b.supplier_id
              and eligibility.ingredient_id=line.ingredient_id
              and eligibility.eligibility_status='ACTIVE'
              and eligibility.effective_from<=b.school_catering_service_date
              and (eligibility.effective_to is null
                or eligibility.effective_to>b.school_catering_service_date)
          )
      ) eligible
    from base b
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'purchase_order_id',s.purchase_order_id,
    'supplier',jsonb_build_object('supplier_id',s.supplier_id,
      'supplier_name',s.supplier_name,'supplier_status',s.supplier_status),
    'service_date',s.school_catering_service_date,'status',s.purchase_order_status,
    'version',s.version,'document_number',s.document_number,
    'current_revision',jsonb_build_object(
      'purchase_order_revision_id',s.purchase_order_revision_id,
      'revision_number',s.revision_number,'revision_kind',s.revision_kind,
      'revision_status',s.revision_status,
      'predecessor_revision_id',s.predecessor_revision_id,
      'supplier_name_snapshot',s.supplier_name_snapshot,
      'delivery_location_snapshot',s.delivery_location_snapshot,
      'released_by_actor_id',s.released_by_actor_id,'released_at',s.released_at,
      'reason_note',s.reason_note),
    'lines',s.lines,'stale',case when s.purchase_order_status='DRAFT' then s.stale else false end,
    'release_eligible',s.purchase_order_status='DRAFT' and not s.stale
      and s.supplier_status='ACTIVE' and s.eligible and jsonb_array_length(s.lines)>0,
    'export_ready',s.purchase_order_status='RELEASED_TO_SUPPLIER',
    'blockers',case
      when s.purchase_order_status='RELEASED_TO_SUPPLIER' then '[]'::jsonb
      else (case when s.stale then jsonb_build_array('PO_DRAFT_STALE') else '[]'::jsonb end)
        || (case when s.supplier_status<>'ACTIVE' then jsonb_build_array('SUPPLIER_INACTIVE') else '[]'::jsonb end)
        || (case when not s.eligible then jsonb_build_array('SUPPLIER_INELIGIBLE') else '[]'::jsonb end)
        || (case when jsonb_array_length(s.lines)=0 then jsonb_build_array('PO_LINES_MISSING') else '[]'::jsonb end)
      end,
    'warnings','[]'::jsonb,
    'allowed_actions',jsonb_build_object('release',s.purchase_order_status='DRAFT'
      and not s.stale and s.supplier_status='ACTIVE' and s.eligible
      and jsonb_array_length(s.lines)>0,
      'export',s.purchase_order_status='RELEASED_TO_SUPPLIER'),
    'disabled_reasons',case when s.purchase_order_status='RELEASED_TO_SUPPLIER'
      then jsonb_build_array('PO_ALREADY_RELEASED') else
        (case when s.stale then jsonb_build_array('PO_DRAFT_STALE') else '[]'::jsonb end)
        || (case when s.supplier_status<>'ACTIVE' then jsonb_build_array('SUPPLIER_INACTIVE') else '[]'::jsonb end)
        || (case when not s.eligible then jsonb_build_array('SUPPLIER_INELIGIBLE') else '[]'::jsonb end)
      end
  ) order by s.school_catering_service_date,s.supplier_name,s.purchase_order_id),'[]'::jsonb)
  into v_rows from shaped s;
  return jsonb_build_object('success',true,
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'date_start',v_date_start,'date_end',v_date_end,
    'purchase_orders',v_rows,'warnings','[]'::jsonb,'blockers','[]'::jsonb);
exception when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_READ_FAILURE',
    'The school-catering purchase orders could not be read safely.',
    'PROCUREMENT',v_name);
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
grant create on schema atlas_core to atlas_procurement_command_runtime;
set role atlas_procurement_command_runtime;

create function atlas_core.school_catering_handoff_has_released_po(
  p_purchase_handoff_batch_id uuid
) returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id
     and por.is_current and por.revision_status='RELEASED_TO_SUPPLIER'
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.purchase_order_revision_id=por.purchase_order_revision_id
    join atlas_procurement.school_catering_allocation_supplier_splits split
      on split.supplier_split_id=polr.school_catering_allocation_supplier_split_id
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=split.family_revision_id
    join atlas_planning.purchase_handoff_line_revisions handoff_line
      on handoff_line.purchase_handoff_line_revision_id=
        contribution.purchase_handoff_line_revision_id
    join atlas_planning.purchase_handoff_revisions handoff_revision
      on handoff_revision.purchase_handoff_revision_id=handoff_line.purchase_handoff_revision_id
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and handoff_revision.purchase_handoff_batch_id=p_purchase_handoff_batch_id
  );
$$;

revoke execute on function
  atlas_core.school_catering_handoff_has_released_po(uuid) from public;
grant execute on function
  atlas_core.school_catering_handoff_has_released_po(uuid)
to atlas_planning_command_runtime,atlas_confirmed_need_review_runtime,atlas_read_runtime;
reset role;
revoke create on schema atlas_core from atlas_procurement_command_runtime;

create or replace function atlas_core.issue_222_chain_payload(run_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  with chain as (
    select run.need_generation_run_id,run.period_start,run.period_end,run.run_status,
      run.version need_generation_run_version,batch.confirmed_need_batch_id,
      batch.batch_status confirmed_need_status,batch.version confirmed_need_batch_version,
      batch.current_confirmed_need_release_id is not null or batch.released_at is not null
        planning_release_occurred
    from atlas_planning.need_generation_runs run
    left join atlas_planning.confirmed_need_batches batch
      on batch.source_kind='NEED_GENERATION'
     and batch.current_need_generation_run_id=run.need_generation_run_id
    where run.need_generation_run_id=issue_222_chain_payload.run_id
  ), handoff as (
    select
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_purchase_handoff_source_kind(
          h.purchase_handoff_batch_id)='WHOLESALE') active_handoff_exists,
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_purchase_handoff_source_kind(
          h.purchase_handoff_batch_id)='SCHOOL_CATERING')
        active_school_catering_handoff_exists,
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_handoff_has_released_po(
          h.purchase_handoff_batch_id)) released_school_catering_po_exists,
      coalesce(jsonb_agg(jsonb_build_object(
        'purchase_handoff_batch_id',h.purchase_handoff_batch_id,
        'handoff_status',h.handoff_status,'version',h.version,'source_kind',
        atlas_core.school_catering_purchase_handoff_source_kind(
          h.purchase_handoff_batch_id),
        'released_school_catering_po_exists',
        atlas_core.school_catering_handoff_has_released_po(
          h.purchase_handoff_batch_id))
        order by h.created_at,h.purchase_handoff_batch_id)
        filter(where h.purchase_handoff_batch_id is not null),'[]'::jsonb) handoffs
    from chain left join atlas_planning.purchase_handoff_batches h
      on h.confirmed_need_batch_id=chain.confirmed_need_batch_id
  ), downstream as (
    select exists(
      select 1 from chain
      join atlas_planning.purchase_handoff_batches h
        on h.confirmed_need_batch_id=chain.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions hr
        on hr.purchase_handoff_batch_id=h.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.purchase_handoff_revision_id=hr.purchase_handoff_revision_id
      join atlas_procurement.fulfilment_allocations allocation
        on allocation.dispatch_requirement_id=drr.dispatch_requirement_id
    ) wholesale_commitment_exists
  )
  select to_jsonb(chain) || jsonb_build_object(
    'is_legacy_range',chain.period_start<>chain.period_end,
    'active_purchase_handoff_exists',coalesce(handoff.active_handoff_exists,false),
    'active_school_catering_handoff_exists',
      coalesce(handoff.active_school_catering_handoff_exists,false),
    'released_school_catering_po_exists',
      coalesce(handoff.released_school_catering_po_exists,false),
    'purchase_handoffs',handoff.handoffs,
    'later_downstream_commitment_exists',
      downstream.wholesale_commitment_exists
      or coalesce(handoff.released_school_catering_po_exists,false))
  from chain cross join handoff cross join downstream;
$$;

create or replace function atlas_core.issue_222_reopen_confirmed_need(
  confirmed_need_batch_id uuid,expected_version bigint
) returns atlas_planning.confirmed_need_batches
language plpgsql volatile security definer set search_path='' as $$
declare
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_handoff_id uuid;
begin
  select h.purchase_handoff_batch_id into v_handoff_id
  from atlas_planning.purchase_handoff_batches h
  where h.confirmed_need_batch_id=issue_222_reopen_confirmed_need.confirmed_need_batch_id
    and h.handoff_status not in ('INVALIDATED','REOPENED') for update;
  if v_handoff_id is not null then
    if atlas_core.school_catering_purchase_handoff_source_kind(v_handoff_id)
        <> 'SCHOOL_CATERING' then
      raise exception using errcode='P0001',
        message='Wholesale Purchase Handoff correction remains blocked';
    end if;
    if atlas_core.school_catering_handoff_has_released_po(v_handoff_id) then
      raise exception using errcode='P0001',
        message='Released school-catering PO blocks Planning correction';
    end if;
    update atlas_planning.purchase_handoff_revisions
      set revision_status='INVALIDATED',is_current=false
      where purchase_handoff_batch_id=v_handoff_id and is_current;
    update atlas_planning.purchase_handoff_batches
      set handoff_status='INVALIDATED',version=version+1,
        updated_at=transaction_timestamp()
      where purchase_handoff_batch_id=v_handoff_id;
  end if;
  update atlas_planning.confirmed_need_batches batch
    set batch_status='REOPENED',version=batch.version+1,
      current_confirmed_need_validation_attempt_id=null,
      current_confirmed_need_approval_snapshot_id=null,
      current_confirmed_need_release_id=null,updated_at=transaction_timestamp()
    where batch.confirmed_need_batch_id=
      issue_222_reopen_confirmed_need.confirmed_need_batch_id
      and batch.version=issue_222_reopen_confirmed_need.expected_version
      and batch.source_kind='NEED_GENERATION'
      and batch.batch_status not in ('DRAFT_REVIEW','REOPENED')
    returning batch.* into v_batch;
  if v_batch.confirmed_need_batch_id is null then
    raise exception using errcode='P0001',
      message='Confirmed Need reopen precondition failed';
  end if;
  return v_batch;
end;
$$;

grant atlas_procurement_command_runtime,atlas_read_runtime
  to postgres with set false;
