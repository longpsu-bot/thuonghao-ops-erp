-- Derive preferred-Supplier coverage without persisting on read. Materialize
-- only missing defaults inside the existing one-day purchase preparation.
begin;

reset role;
grant atlas_owner,atlas_procurement_command_runtime,
  atlas_read_runtime,atlas_confirmed_need_review_runtime,
  atlas_master_data_command_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_procurement_command_runtime,
  atlas_master_data_command_runtime;
grant create on schema atlas_api to atlas_read_runtime,
  atlas_confirmed_need_review_runtime;

reset role;
set role atlas_master_data_command_runtime;

-- Procurement owns the preparation transaction, while master data owns the
-- stronger locks on Supplier facts. Ingredient KEY SHARE follows the
-- canonical priority writer's aggregate-first protocol and prevents a new or
-- changed eligibility set from crossing the materialization decision.
create function atlas_core.purchase_review_lock_default_supplier_evidence(
  p_ingredient_ids jsonb
)
returns void
language plpgsql
security definer
set search_path=''
as $$
begin
  perform 1
  from atlas_admin.ingredients ingredient
  where ingredient.ingredient_id in (
    select value::uuid
    from pg_catalog.jsonb_array_elements_text(p_ingredient_ids) ids(value))
  order by ingredient.ingredient_id
  for key share;
  perform 1
  from atlas_admin.suppliers supplier
  where supplier.supplier_id in (
    select distinct eligibility.supplier_id
    from atlas_admin.supplier_eligibilities eligibility
    where eligibility.ingredient_id in (
      select value::uuid
      from pg_catalog.jsonb_array_elements_text(p_ingredient_ids) ids(value)))
  order by supplier.supplier_id
  for share;
  perform 1
  from atlas_admin.supplier_eligibilities eligibility
  where eligibility.ingredient_id in (
    select value::uuid
    from pg_catalog.jsonb_array_elements_text(p_ingredient_ids) ids(value))
  order by eligibility.ingredient_id,eligibility.supplier_id,
    eligibility.supplier_eligibility_id
  for share;
end;
$$;

revoke all on function
  atlas_core.purchase_review_lock_default_supplier_evidence(jsonb)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.purchase_review_lock_default_supplier_evidence(jsonb)
to atlas_procurement_command_runtime;

reset role;
set role atlas_procurement_command_runtime;

-- Strict persisted readiness remains unchanged for Planning release and
-- Handoff promotion. This preparation-only predicate additionally accepts a
-- missing family when current master data has one unique best priority.
create function atlas_core.purchase_review_preparation_allocation_ready(p_batch uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  with source as materialized (
    select value p
    from atlas_core.purchase_review_confirmed_batch_sources(p_batch) source(value)
  )
  select exists(select 1 from source)
    and not exists(
      select 1
      from source
      where p->>'complete' is distinct from 'true'
        or ((p->>'family_quantity')::numeric>0 and not (
          exists(
            select 1
            from atlas_procurement.school_catering_allocation_families family
            join atlas_procurement.school_catering_allocation_family_revisions revision
              using(family_id)
            where family.service_date=(p->>'service_date')::date
              and family.delivery_location_id=(p->>'delivery_location_id')::uuid
              and family.ingredient_id=(p->>'ingredient_id')::uuid
              and family.unit_id=(p->>'unit_id')::uuid
              and revision.is_current
              and revision.source_kind='CONFIRMED_NEED'
              and revision.source_confirmed_need_batch_id=p_batch
              and revision.source_fingerprint=p->>'source_fingerprint'
              and revision.family_quantity=(p->>'family_quantity')::numeric
              and revision.source_confirmed_need_batch_version<=
                (p->>'source_confirmed_need_batch_version')::bigint
              and (select pg_catalog.sum(split.allocated_quantity)
                from atlas_procurement.school_catering_allocation_supplier_splits split
                where split.family_revision_id=revision.family_revision_id)=revision.family_quantity
              and not exists(
                select 1
                from atlas_procurement.school_catering_allocation_supplier_splits split
                where split.family_revision_id=revision.family_revision_id
                  and not exists(
                    select 1
                    from atlas_admin.suppliers supplier
                    join atlas_admin.supplier_eligibilities eligibility using(supplier_id)
                    where supplier.supplier_id=split.supplier_id
                      and supplier.supplier_status='ACTIVE'
                      and eligibility.eligibility_status='ACTIVE'
                      and eligibility.ingredient_id=family.ingredient_id
                      and eligibility.effective_from<=family.service_date
                      and (eligibility.effective_to is null
                        or eligibility.effective_to>family.service_date))))
          or (
            not exists(
              select 1
              from atlas_procurement.school_catering_allocation_families family
              join atlas_procurement.school_catering_allocation_family_revisions revision
                using(family_id)
              where family.service_date=(p->>'service_date')::date
                and family.delivery_location_id=(p->>'delivery_location_id')::uuid
                and family.ingredient_id=(p->>'ingredient_id')::uuid
                and family.unit_id=(p->>'unit_id')::uuid
                and revision.is_current)
            and atlas_core.purchase_review_supplier_advice(
              (p->>'service_date')::date,
              (p->>'ingredient_id')::uuid,
              (p->>'family_quantity')::numeric)->'recommendation' <> 'null'::jsonb)
        )));
$$;

revoke all on function
  atlas_core.purchase_review_preparation_allocation_ready(uuid)
from public,anon,authenticated,service_role;

-- The helper is private and callable only from the authenticated outer
-- preparation command. It emits no per-row receipt or acceptance event.
create function atlas_core.purchase_review_materialize_default_allocations(
  p_batch uuid,
  p_actor uuid,
  p_command uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  source jsonb;
  family_id uuid;
  saved jsonb;
  materialized jsonb := '[]'::jsonb;
  ingredient_ids jsonb;
begin
  if p_batch is null or p_actor is null or p_command is null then
    return jsonb_build_object('success',false,'error_code','VALIDATION_FAILED');
  end if;
  perform atlas_core.purchase_review_lock_confirmed_source(p_batch);
  select coalesce(pg_catalog.jsonb_agg(id order by id),'[]'::jsonb)
    into ingredient_ids
  from (
    select distinct value->>'ingredient_id' id
    from atlas_core.purchase_review_confirmed_batch_sources(p_batch) batch_source(value)
  ) relevant;
  perform atlas_core.purchase_review_lock_default_supplier_evidence(ingredient_ids);
  if not atlas_core.purchase_review_preparation_allocation_ready(p_batch) then
    return jsonb_build_object(
      'success',false,
      'error_code','CONFIRMED_ALLOCATION_NOT_READY');
  end if;
  for source in
    select value
    from atlas_core.purchase_review_confirmed_batch_sources(p_batch) batch_source(value)
    where value->>'complete'='true'
      and (value->>'family_quantity')::numeric>0
    order by value->>'ingredient_id',value->>'service_date',
      value->>'delivery_location_id',value->>'unit_id'
  loop
    select family.family_id into family_id
    from atlas_procurement.school_catering_allocation_families family
    where family.service_date=(source->>'service_date')::date
      and family.delivery_location_id=(source->>'delivery_location_id')::uuid
      and family.ingredient_id=(source->>'ingredient_id')::uuid
      and family.unit_id=(source->>'unit_id')::uuid;
    if family_id is not null then
      continue;
    end if;
    saved:=atlas_core.purchase_review_persist_allocation(
      p_actor,
      p_command,
      0,
      jsonb_build_object(
        'service_date',source->'service_date',
        'delivery_location_id',source->'delivery_location_id',
        'ingredient_id',source->'ingredient_id',
        'unit_id',source->'unit_id',
        'expected_source_fingerprint',source->'source_fingerprint',
        'expected_source_batch_id',source->'source_confirmed_need_batch_id',
        'expected_source_batch_version',source->'source_confirmed_need_batch_version'),
      '[]'::jsonb,
      'PRIORITY_RECOMMENDATION',
      'CONFIRMED_NEED');
    if saved->>'success' is distinct from 'true' then
      return saved;
    end if;
    materialized:=materialized||jsonb_build_array(saved);
  end loop;
  if not atlas_core.purchase_review_allocation_ready(p_batch) then
    return jsonb_build_object(
      'success',false,
      'error_code','CONFIRMED_ALLOCATION_NOT_READY');
  end if;
  return jsonb_build_object('success',true,'materialized',materialized);
end;
$$;

revoke all on function
  atlas_core.purchase_review_materialize_default_allocations(uuid,uuid,uuid)
from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.purchase_review_materialize_default_allocations(uuid,uuid,uuid)
to atlas_confirmed_need_review_runtime;

-- Handoff promotion reuses the same writer with the current family's decision
-- origin. Keep recommendation creation insert-only for Confirmed Need, while
-- allowing the governed current-family successor at PURCHASE_HANDOFF.
do $recommendation_handoff_promotion$
declare
  definition text := pg_catalog.pg_get_functiondef(
    'atlas_core.purchase_review_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text,text)'::regprocedure);
  original text := definition;
begin
  definition:=pg_catalog.replace(definition,
    $old$  if p_decision_origin<>'PRIORITY_RECOMMENDATION' then$old$,
    $new$  if not (p_decision_origin='PRIORITY_RECOMMENDATION'
     and p_source_kind='CONFIRMED_NEED') then$new$);
  definition:=pg_catalog.replace(definition,
    $old$    p_splits,p_decision_origin='PRIORITY_RECOMMENDATION');$old$,
    $new$    p_splits,p_decision_origin='PRIORITY_RECOMMENDATION'
      and p_source_kind='CONFIRMED_NEED');$new$);
  definition:=pg_catalog.replace(definition,
    $old$  if p_decision_origin='PRIORITY_RECOMMENDATION' and v_family_id is not null then$old$,
    $new$  if p_decision_origin='PRIORITY_RECOMMENDATION' and v_family_id is not null
     and p_source_kind<>'PURCHASE_HANDOFF' then$new$);
  definition:=pg_catalog.replace(definition,
    $old$  if p_decision_origin='PRIORITY_RECOMMENDATION' then$old$,
    $new$  if p_decision_origin='PRIORITY_RECOMMENDATION'
     and p_source_kind='CONFIRMED_NEED' then$new$);
  if definition=original
     or pg_catalog.strpos(definition,
       'and p_source_kind<>''PURCHASE_HANDOFF''')=0
     or pg_catalog.strpos(definition,
       'p_splits,p_decision_origin=''PRIORITY_RECOMMENDATION''')=0
     or pg_catalog.strpos(definition,
       'and p_source_kind=''CONFIRMED_NEED''')=0 then
    raise exception 'Expected allocation persistence definition changed';
  end if;
  execute definition;
end;
$recommendation_handoff_promotion$;

create or replace function atlas_core.purchase_review_preparation_status(
  p_date date,
  p_actor uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  sources jsonb;
  p jsonb;
  v_batch uuid;
  v_version bigint;
  v_ready boolean:=false;
  v_allowed boolean:=false;
begin
  select coalesce(jsonb_agg(value),'[]') into sources
  from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value);
  if (select count(distinct value->>'source_confirmed_need_batch_id')
      from jsonb_array_elements(sources))<>1 then
    return jsonb_build_object('ready',false,'allowed',false,'blockers',
      jsonb_build_array('Chọn nhu cầu hiện hành của một ngày phục vụ.'));
  end if;
  if exists(select 1 from jsonb_array_elements(sources) value
    where not atlas_core.school_catering_actor_has_scope(
      p_actor,null,null,(value->>'delivery_location_id')::uuid)) then
    return jsonb_build_object('ready',false,'allowed',false,'blockers',
      jsonb_build_array('Bạn không có quyền với toàn bộ nhu cầu này.'));
  end if;
  p:=sources->0;
  v_batch:=(p->>'source_confirmed_need_batch_id')::uuid;
  v_version:=(p->>'source_confirmed_need_batch_version')::bigint;
  v_allowed:=atlas_core.pa_05b_authorize_actor('{}',p_actor,
    'procurement.school_catering.write','PROCUREMENT',
    'prepare_school_catering_purchase_orders',null,null,null) is null
    and atlas_core.pa_05b_authorize_actor('{}',p_actor,
    'confirmed_need_release.release','PROCUREMENT',
    'prepare_school_catering_purchase_orders',null,null,null) is null;
  v_ready:=atlas_core.purchase_review_preparation_allocation_ready(v_batch)
    or coalesce((atlas_core.school_catering_po_date_readiness(p_date)->>'ready')::boolean,false);
  return jsonb_build_object(
    'service_date',p_date,
    'confirmed_need_batch_id',v_batch,
    'expected_version',v_version,
    'ready',v_ready,
    'allowed',v_allowed,
    'blockers',case when v_ready then '[]'::jsonb else
      jsonb_build_array('Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.') end);
end;
$$;

-- Keep the existing public shape. Only the row blocker and state now reflect
-- the already-exposed NO_ELIGIBLE_SUPPLIER advice.
reset role;
set role atlas_read_runtime;
do $confirmed_allocation_read$
declare
  definition text := pg_catalog.pg_get_functiondef(
    'atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  original text := definition;
begin
  definition:=pg_catalog.replace(definition,
    $old$  v_blockers jsonb:='[]'; v_row jsonb; v_search text:=nullif(request#>>'{payload,search}','');$old$,
    $new$  v_blockers jsonb:='[]'; v_row_blockers jsonb:='[]'; v_row jsonb; v_search text:=nullif(request#>>'{payload,search}','');$new$);
  definition:=pg_catalog.replace(definition,
    $old$  for p in select * from atlas_core.purchase_review_confirmed_sources(v_start,v_end) loop
    if not atlas_core.school_catering_actor_has_scope$old$,
    $new$  for p in select * from atlas_core.purchase_review_confirmed_sources(v_start,v_end) loop
    v_row_blockers:='[]'::jsonb;
    if not atlas_core.school_catering_actor_has_scope$new$);
  definition:=pg_catalog.replace(definition,
    $old$    if not v_complete then v_blockers:='["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."]'; end if;$old$,
    $new$    if not v_complete then
      v_blockers:='["Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC."]';
      v_row_blockers:=v_blockers;
    end if;$new$);
  definition:=pg_catalog.replace(definition,
    $old$    select coalesce(jsonb_agg(jsonb_build_object('supplier_split_id',s.supplier_split_id,$old$,
    $new$    if v_complete and jsonb_array_length(a->'eligible_suppliers')=0 then
      v_row_blockers:=jsonb_build_array('Không có nhà cung ứng đang hoạt động và đủ điều kiện.');
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('supplier_split_id',s.supplier_split_id,$new$);
  definition:=pg_catalog.replace(definition,
    $old$    v_state:=case when not v_complete then 'BLOCKED' when r.family_revision_id is null then 'UNALLOCATED'$old$,
    $new$    v_state:=case when not v_complete then 'BLOCKED'
      when jsonb_array_length(a->'eligible_suppliers')=0 then 'BLOCKED'
      when r.family_revision_id is null then 'UNALLOCATED'$new$);
  definition:=pg_catalog.replace(definition,
    $old$        'confirm_recommendation',false),'disabled_reasons',case when not v_complete then v_blockers else '[]'::jsonb end,
      'blockers',case when not v_complete then v_blockers else '[]'::jsonb end,'warnings',a->'warnings');$old$,
    $new$        'confirm_recommendation',false),'disabled_reasons',v_row_blockers,
      'blockers',v_row_blockers,'warnings',a->'warnings');$new$);
  if definition=original
     or pg_catalog.strpos(definition,'v_row_blockers jsonb')=0
     or pg_catalog.strpos(definition,
       'when jsonb_array_length(a->''eligible_suppliers'')=0 then ''BLOCKED''')=0
     or pg_catalog.strpos(definition,
       'Không có nhà cung ứng đang hoạt động và đủ điều kiện.')=0 then
    raise exception 'Expected confirmed allocation read definition changed';
  end if;
  execute definition;
end;
$confirmed_allocation_read$;

-- Materialize defaults before the existing strict Planning release guard. The
-- surrounding command subtransaction rolls every support write back on error.
reset role;
set role atlas_confirmed_need_review_runtime;
do $prepare_with_defaults$
declare
  definition text := pg_catalog.pg_get_functiondef(
    'atlas_api.prepare_school_catering_purchase_orders(jsonb)'::regprocedure);
  original text := definition;
begin
  definition:=pg_catalog.replace(definition,
    $old$  v_child jsonb;v_release jsonb;v_handoff jsonb;v_drafts jsonb;v_frontier jsonb;v_response jsonb;v_cap text;$old$,
    $new$  v_child jsonb;v_release jsonb;v_handoff jsonb;v_drafts jsonb;v_frontier jsonb;v_defaults jsonb;v_response jsonb;v_cap text;$new$);
  definition:=pg_catalog.replace(definition,
    $old$  begin
    if v_batch.batch_status in ('DRAFT_REVIEW','REOPENED') then$old$,
    $new$  begin
    if not exists(
      select 1
      from atlas_planning.purchase_handoff_batches handoff
      join atlas_planning.purchase_handoff_revisions revision
        using(purchase_handoff_batch_id)
      where handoff.confirmed_need_batch_id=v_batch_id
        and handoff.handoff_status='RELEASED_TO_PROCUREMENT'
        and revision.is_current
        and revision.revision_status='RELEASED_TO_PROCUREMENT') then
      v_defaults:=atlas_core.purchase_review_materialize_default_allocations(
        v_batch_id,v_actor_id,(request->>'command_id')::uuid);
      if v_defaults->>'success' is distinct from 'true' then
        v_error:=atlas_core.pa_05b_command_error(request,
          'CONFIRMED_ALLOCATION_NOT_READY',
          'Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.',
          'PROCUREMENT',v_name)
          ||jsonb_build_object('blockers',jsonb_build_array(
            'Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.'));
        raise exception using errcode='PPR02';
      end if;
    end if;
    if v_batch.batch_status in ('DRAFT_REVIEW','REOPENED') then$new$);
  if definition=original
     or pg_catalog.strpos(definition,'v_defaults jsonb')=0
     or pg_catalog.strpos(definition,
       'purchase_review_materialize_default_allocations')=0 then
    raise exception 'Expected purchase preparation definition changed';
  end if;
  execute definition;
end;
$prepare_with_defaults$;

-- Purchase Preparation is a bounded composite operator command. PostgREST
-- hoists this setting before executing the RPC; other authenticated commands
-- retain the role default. No business function body or lock policy changes.
alter function atlas_api.prepare_school_catering_purchase_orders(jsonb)
  set statement_timeout = '20s';

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_procurement_command_runtime,
  atlas_master_data_command_runtime;
revoke create on schema atlas_api from atlas_read_runtime,
  atlas_confirmed_need_review_runtime;
reset role;
grant atlas_owner to postgres with set true;
grant atlas_procurement_command_runtime,
  atlas_read_runtime,atlas_confirmed_need_review_runtime,
  atlas_master_data_command_runtime to postgres with set false;

commit;
