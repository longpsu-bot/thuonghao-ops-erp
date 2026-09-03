-- PURCHASE-REVIEW-CONFIRM-RELEASE-01. No hosted execution authorized.
-- Same bounded clock tolerance as Issue #215, applied only to this Handoff.
-- Keep original request bytes for receipt hashing; operational time is server-owned.
do $migration$
declare
  definition text := pg_get_functiondef('atlas_api.release_school_catering_purchase_handoff(jsonb)'::regprocedure);
  old_check text := 'atlas_core.pa_05b_safe_timestamptz(request ->> ''requested_at'') > pg_catalog.transaction_timestamp()';
begin
  if position(old_check || ' + interval ''60 seconds''' in definition)>0 then return; end if;
  if position(old_check in definition)=0 then
    raise exception 'Expected Handoff timestamp validation was not found';
  end if;
  execute replace(definition,old_check,old_check || ' + interval ''60 seconds''');
end;
$migration$;

reset role;
grant atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime,
  atlas_planning_command_runtime,atlas_read_runtime to postgres with set true;
set role atlas_owner;

-- ADD COLUMN's constant default classifies retained evidence without UPDATEs
-- through the immutable-history guard.
alter table atlas_procurement.school_catering_allocation_family_revisions
  add column source_kind text not null default 'PURCHASE_HANDOFF',
  add column source_confirmed_need_batch_id uuid references atlas_planning.confirmed_need_batches,
  add column source_confirmed_need_batch_version bigint,
  alter column source_purchase_handoff_revision_id drop not null,
  add constraint school_catering_revision_source_xor check (
    (source_kind='PURCHASE_HANDOFF' and source_purchase_handoff_revision_id is not null
      and source_confirmed_need_batch_id is null and source_confirmed_need_batch_version is null)
    or (source_kind='CONFIRMED_NEED' and source_purchase_handoff_revision_id is null
      and source_confirmed_need_batch_id is not null and source_confirmed_need_batch_version is not null
      and source_confirmed_need_batch_version>0));
alter table atlas_procurement.school_catering_allocation_family_contributions
  alter column purchase_handoff_line_revision_id drop not null,
  add column confirmed_need_line_revision_id uuid references atlas_planning.confirmed_need_line_revisions,
  add column confirmed_need_line_decision_id uuid references atlas_planning.confirmed_need_line_decisions,
  add constraint school_catering_contribution_source_xor check (
    (purchase_handoff_line_revision_id is not null and confirmed_need_line_revision_id is null
      and confirmed_need_line_decision_id is null)
    or (purchase_handoff_line_revision_id is null and confirmed_need_line_revision_id is not null
      and confirmed_need_line_decision_id is not null)),
  add constraint school_catering_contribution_confirmed_key
    unique(family_revision_id,confirmed_need_line_revision_id);
create index school_catering_revision_confirmed_batch_idx
  on atlas_procurement.school_catering_allocation_family_revisions(source_confirmed_need_batch_id)
  where source_kind='CONFIRMED_NEED';
create index school_catering_contribution_confirmed_revision_idx
  on atlas_procurement.school_catering_allocation_family_contributions(confirmed_need_line_revision_id)
  where confirmed_need_line_revision_id is not null;
create index school_catering_contribution_confirmed_decision_idx
  on atlas_procurement.school_catering_allocation_family_contributions(confirmed_need_line_decision_id)
  where confirmed_need_line_decision_id is not null;

grant create on schema atlas_core,atlas_api to atlas_confirmed_need_review_runtime,
  atlas_procurement_command_runtime,atlas_read_runtime;
grant execute on function atlas_core.school_catering_actor_has_scope(uuid,uuid,uuid,uuid)
  to atlas_confirmed_need_review_runtime;
grant execute on function atlas_core.pa_05d_safe_date(text)
  to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_read_runtime;

-- Same unique-lowest-non-null-priority semantics as the existing Handoff read.
create function atlas_core.purchase_review_supplier_advice(p_date date,p_ingredient uuid,p_quantity numeric)
returns jsonb language sql stable security definer set search_path='' as $$
  with eligible as (
    select e.supplier_id,s.supplier_name,e.priority
    from atlas_admin.supplier_eligibilities e
    join atlas_admin.suppliers s on s.supplier_id=e.supplier_id and s.supplier_status='ACTIVE'
    where e.ingredient_id=p_ingredient and e.eligibility_status='ACTIVE'
      and e.effective_from<=p_date and (e.effective_to is null or e.effective_to>p_date)
  ), best as (select * from eligible where priority=(select min(priority) from eligible))
  select jsonb_build_object(
    'eligible_suppliers',coalesce((select jsonb_agg(to_jsonb(e) order by priority,supplier_id) from eligible e),'[]'::jsonb),
    'recommendation',case when (select count(*) from best)=1 then
      (select jsonb_build_object('supplier_id',supplier_id,'supplier_name',supplier_name,
        'allocated_quantity',p_quantity::numeric(20,6)::text,'split_ratio','1.000000000000') from best) else null end,
    'warnings',case when not exists(select 1 from eligible) then '["NO_ELIGIBLE_SUPPLIER"]'::jsonb
      when (select count(*) from best)=0 then '["NO_PRIORITIZED_SUPPLIER"]'::jsonb
      when (select count(*) from best)>1 then '["AMBIGUOUS_SUPPLIER_PRIORITY"]'::jsonb
      else '[]'::jsonb end);
$$;
revoke all on function atlas_core.purchase_review_supplier_advice(date,uuid,numeric) from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_supplier_advice(date,uuid,numeric)
  to atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime;

reset role;
set role atlas_confirmed_need_review_runtime;

-- Narrow cross-domain read bridge; no Planning table grants to Procurement.
create function atlas_core.purchase_review_confirmed_sources(p_start date,p_end date)
returns setof jsonb language sql stable security definer set search_path='' as $$
  with batches as materialized (
    select b.*,atlas_core.rmvp_06_canonical_evaluation(b.confirmed_need_batch_id) evaluation,
      atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id) facts
    from atlas_planning.confirmed_need_batches b
    where b.source_kind='NEED_GENERATION' and b.period_start<=p_end and b.period_end>=p_start
      and exists(select 1 from atlas_planning.need_generation_runs run
        where run.need_generation_run_id=b.current_need_generation_run_id
          and run.run_status='RELEASED_FOR_CONFIRMATION'
          and not exists(select 1 from atlas_planning.need_generation_runs later
            where later.planning_input_set_id=run.planning_input_set_id and later.attempt_ordinal>run.attempt_ordinal))
  ), lines as (
    select b.confirmed_need_batch_id,b.version,b.batch_status,b.evaluation,
      (fact->>'service_date')::date service_date,(fact->>'delivery_location_id')::uuid delivery_location_id,
      (fact->>'ingredient_id')::uuid ingredient_id,(fact->>'controlled_unit_id')::uuid unit_id,
      (fact->>'school_id')::uuid school_id,(fact->>'customer_id')::uuid customer_id,
      fact, (fact->>'confirmed_quantity')::numeric confirmed_quantity
    from batches b cross join lateral jsonb_array_elements(b.facts->'ordered_lines') fact
    where (fact->>'service_date')::date between p_start and p_end
  ), families as (
    select confirmed_need_batch_id,version,batch_status,service_date,delivery_location_id,ingredient_id,unit_id,
      evaluation->>'outcome'='VALIDATED' complete,
      sum(confirmed_quantity)::numeric(20,6) quantity,
      jsonb_agg(fact - 'line_sort_position' order by fact->>'confirmed_need_line_id') facts,
      jsonb_agg(jsonb_build_object(
        'confirmed_need_line_revision_id',fact->'current_confirmed_need_line_revision_id',
        'confirmed_need_line_decision_id',fact->'current_confirmed_need_line_decision_id',
        'confirmed_need_line_id',fact->'confirmed_need_line_id',
        'school_id',school_id,'customer_id',customer_id,
        'contribution_quantity',confirmed_quantity::numeric(20,6)::text)
        order by fact->>'confirmed_need_line_id') contributions
    from lines group by confirmed_need_batch_id,version,batch_status,service_date,
      delivery_location_id,ingredient_id,unit_id,evaluation->>'outcome'
  )
  select jsonb_build_object('source_kind','CONFIRMED_NEED',
    'source_confirmed_need_batch_id',confirmed_need_batch_id,'source_confirmed_need_batch_version',version,
    'batch_status',batch_status,'service_date',service_date,'delivery_location_id',delivery_location_id,
    'ingredient_id',ingredient_id,'unit_id',unit_id,'complete',complete,
    'family_quantity',case when complete then quantity::text else null end,
    'contributions',contributions,'source_fingerprint',encode(sha256(convert_to(
      jsonb_build_object('batch_id',confirmed_need_batch_id,'facts',facts)::text,'UTF8')),'hex'))
  from families;
$$;

create function atlas_core.purchase_review_confirmed_projection(p_date date,p_location uuid,p_ingredient uuid,p_unit uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select case when count(*)=1 then (jsonb_agg(p))->0 else
    jsonb_build_object('complete',false,'blocker','CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING') end
  from atlas_core.purchase_review_confirmed_sources(p_date,p_date) p
  where p->>'delivery_location_id'=p_location::text and p->>'ingredient_id'=p_ingredient::text
    and p->>'unit_id'=p_unit::text;
$$;
revoke all on function atlas_core.purchase_review_confirmed_sources(date,date),
  atlas_core.purchase_review_confirmed_projection(date,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_confirmed_sources(date,date),
  atlas_core.purchase_review_confirmed_projection(date,uuid,uuid,uuid)
  to atlas_procurement_command_runtime,atlas_read_runtime,atlas_planning_command_runtime;

create function atlas_core.purchase_review_confirmed_batch_sources(p_batch uuid)
returns setof jsonb language sql stable security definer set search_path='' as $$
  select source.value from atlas_planning.confirmed_need_batches b
    cross join lateral atlas_core.purchase_review_confirmed_sources(b.period_start,b.period_end) source(value)
    where b.confirmed_need_batch_id=p_batch and source.value->>'source_confirmed_need_batch_id'=p_batch::text;
$$;
revoke all on function atlas_core.purchase_review_confirmed_batch_sources(uuid) from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_confirmed_batch_sources(uuid)
  to atlas_procurement_command_runtime,atlas_read_runtime,atlas_planning_command_runtime;

create function atlas_api.get_generated_purchase_review(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_date date:=atlas_core.pa_05d_safe_date(request#>>'{payload,service_date}');
  v_actor jsonb; v_actor_id uuid; v_error jsonb; v_rows jsonb;
begin
  if jsonb_typeof(request) is distinct from 'object' or jsonb_typeof(request->'payload') is distinct from 'object'
    or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
    or request->>'contract_version' is distinct from 'PURCHASE-REVIEW.v1' or v_date is null
    or (request->'payload')-array['service_date']<>'{}'::jsonb then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Chọn một ngày phục vụ hợp lệ.',
      'PLANNING','get_generated_purchase_review');
  end if;
  v_actor:=atlas_core.pa_05b_resolve_actor(request,'PLANNING','get_generated_purchase_review');
  if v_actor?'error' then return v_actor->'error'; end if;
  v_actor_id:=(v_actor->>'actor_id')::uuid;
  v_error:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,'confirmed_need_review.read',
    'PLANNING','get_generated_purchase_review',null,null,null);
  if v_error is not null and v_error->>'error_code'<>'SCOPE_DENIED' then return v_error; end if;
  with source as (
    select line.*,school.customer_id,school.school_name,
      coalesce(line.delivery_location_id,school.default_delivery_location_id) location_id
    from atlas_planning.need_generation_runs run
    join atlas_planning.need_generation_release_snapshots snap on snap.need_generation_run_id=run.need_generation_run_id
    join atlas_planning.need_generation_release_snapshot_lines member
      on member.need_generation_release_snapshot_id=snap.need_generation_release_snapshot_id
    join atlas_planning.theoretical_need_lines line on line.theoretical_need_line_id=member.theoretical_need_line_id
    join atlas_admin.schools school on school.school_id=line.school_id
    where run.run_status='RELEASED_FOR_CONFIRMATION' and line.line_disposition='ACTIVE'
      and line.service_date=v_date and not exists(select 1 from atlas_planning.need_generation_runs later
        where later.planning_input_set_id=run.planning_input_set_id and later.attempt_ordinal>run.attempt_ordinal)
  ), grouped as (
    select service_date,location_id,ingredient_id,unit_id,school_id,school_name,customer_id,
      sum(theoretical_quantity)::numeric(20,6) quantity,
      jsonb_agg(jsonb_build_object('theoretical_need_line_id',theoretical_need_line_id,
        'need_generation_run_id',need_generation_run_id,
        'contribution_quantity',theoretical_quantity::numeric(20,6)::text) order by theoretical_need_line_id) contributions
    from source where atlas_core.school_catering_actor_has_scope(v_actor_id,customer_id,school_id,location_id)
    group by service_date,location_id,ingredient_id,unit_id,school_id,school_name,customer_id
  ) select coalesce(jsonb_agg(jsonb_build_object(
      'service_date',g.service_date,'school_id',g.school_id,'school_name',g.school_name,
      'delivery_location_id',g.location_id,'location_name',l.location_name,
      'ingredient_id',g.ingredient_id,'ingredient_name',i.ingredient_name,'unit_id',g.unit_id,'unit_code',u.unit_code,
      'family_quantity',g.quantity::text,'contributions',g.contributions)
      || atlas_core.purchase_review_supplier_advice(g.service_date,g.ingredient_id,g.quantity)
      order by g.school_name,i.ingredient_name),'[]'::jsonb) into v_rows
    from grouped g join atlas_admin.delivery_locations l on l.delivery_location_id=g.location_id
    join atlas_admin.ingredients i on i.ingredient_id=g.ingredient_id join atlas_admin.units u on u.unit_id=g.unit_id;
  return jsonb_build_object('success',true,'contract_version','PURCHASE-REVIEW.v1','service_date',v_date,
    'document_label','DỰ KIẾN — CHƯA XÁC NHẬN','rows',v_rows,'blockers','[]'::jsonb,'warnings','[]'::jsonb);
end;
$$;
revoke all on function atlas_api.get_generated_purchase_review(jsonb) from public,anon,service_role;
grant execute on function atlas_api.get_generated_purchase_review(jsonb) to authenticated;

reset role;
set role atlas_read_runtime;
create function atlas_api.get_confirmed_supplier_allocation_workbench(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_start date:=atlas_core.pa_05d_safe_date(request#>>'{payload,date_start}');
  v_end date:=atlas_core.pa_05d_safe_date(request#>>'{payload,date_end}');
  v_actor jsonb; v_actor_id uuid; v_error jsonb; v_can_write boolean;
  p jsonb; a jsonb; v_splits jsonb; v_rebalance jsonb; v_state text; v_rows jsonb:='[]';
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
    v_row:=p || to_jsonb(d) || jsonb_build_object('family',jsonb_build_object(
      'service_date',p->'service_date','delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','family_id',f.family_id,'version',coalesce(f.version,0),
      'source_fingerprint',p->'source_fingerprint','source_kind',p->'source_kind',
      'source_confirmed_need_batch_id',p->'source_confirmed_need_batch_id',
      'source_confirmed_need_batch_version',p->'source_confirmed_need_batch_version'),
      'family_quantity',p->'family_quantity','schools',v_schools,'splits',v_splits,'state',v_state,
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
$$;
revoke all on function atlas_api.get_confirmed_supplier_allocation_workbench(jsonb) from public,anon,service_role;
grant execute on function atlas_api.get_confirmed_supplier_allocation_workbench(jsonb) to authenticated;
reset role;

set role atlas_confirmed_need_review_runtime;
create function atlas_core.purchase_review_lock_confirmed_source(p_batch uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform 1 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch for update;
  perform 1 from atlas_planning.confirmed_need_lines where confirmed_need_batch_id=p_batch
    order by confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=p_batch and is_current
    order by confirmed_need_line_revision_id for key share;
end;
$$;
revoke all on function atlas_core.purchase_review_lock_confirmed_source(uuid) from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_lock_confirmed_source(uuid)
  to atlas_procurement_command_runtime,atlas_planning_command_runtime;
reset role;

reset role;
set role atlas_procurement_command_runtime;
create function atlas_core.purchase_review_persist_allocation(
  p_actor_id uuid,p_command_id uuid,p_expected_version bigint,
  p_family jsonb,p_splits jsonb,p_decision_origin text,p_source_kind text
) returns jsonb language plpgsql volatile set search_path='' as $$
declare
  v_service_date date;
  v_location_id uuid := atlas_core.pa_05b_safe_uuid(p_family ->> 'delivery_location_id');
  v_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(p_family ->> 'ingredient_id');
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(p_family ->> 'unit_id');
  v_projection jsonb;
  v_quantity numeric(20,6);
  v_fingerprint text;
  v_family_id uuid;
  v_version bigint;
  v_prior_revision_id uuid;
  v_revision_id uuid;
  v_revision_number integer;
  v_split jsonb;
  v_effective_splits jsonb := p_splits;
  v_sum numeric(20,6);
  v_supplier_id uuid;
  v_best_priority smallint;
  v_best_count integer;
begin
  if p_source_kind not in ('CONFIRMED_NEED','PURCHASE_HANDOFF') then
    return jsonb_build_object('success',false,'error_code','VALIDATION_FAILED');
  end if;
  begin
    v_service_date := nullif(pg_catalog.btrim(p_family ->> 'service_date'),'')::date;
  exception when invalid_datetime_format or datetime_field_overflow then
    return jsonb_build_object('success',false,'error_code','VALIDATION_FAILED');
  end;
  if v_service_date is null or v_location_id is null or v_ingredient_id is null
     or v_unit_id is null or p_family ->> 'expected_source_fingerprint' is null
     or p_decision_origin not in ('MANUAL','PRIORITY_RECOMMENDATION','REBALANCED') then
    return jsonb_build_object('success',false,'error_code','VALIDATION_FAILED');
  end if;
  if p_decision_origin<>'PRIORITY_RECOMMENDATION' then
    if pg_catalog.jsonb_typeof(p_splits) is distinct from 'array'
       or pg_catalog.jsonb_array_length(p_splits)=0 then
      return jsonb_build_object('success',false,'error_code','VALIDATION_FAILED');
    end if;
    if exists(select 1 from pg_catalog.jsonb_array_elements(p_splits) s
      where s - array['supplier_id','allocated_quantity'] <> '{}'::jsonb
         or atlas_core.pa_05b_safe_uuid(s ->> 'supplier_id') is null
         or atlas_core.pa_05b_safe_numeric(s ->> 'allocated_quantity') is null
         or atlas_core.pa_05b_safe_numeric(s ->> 'allocated_quantity') <= 0) then
      return jsonb_build_object('success',false,'error_code','NON_POSITIVE_SPLIT');
    end if;
    if exists(select 1 from jsonb_array_elements(p_splits) s
      where (s->>'allocated_quantity')::numeric >= 100000000000000
        or (s->>'allocated_quantity')::numeric <> round((s->>'allocated_quantity')::numeric,6)) then
      return jsonb_build_object('success',false,'error_code','INVALID_SPLIT_PRECISION');
    end if;
    if (select pg_catalog.count(*) from pg_catalog.jsonb_array_elements(p_splits)) <>
       (select pg_catalog.count(distinct s ->> 'supplier_id')
        from pg_catalog.jsonb_array_elements(p_splits) s) then
      return jsonb_build_object('success',false,'error_code','DUPLICATE_SUPPLIER');
    end if;
  end if;

  -- One canonical currentness protocol for both manual and recommendation writes:
  -- Ingredient aggregate -> suppliers -> eligibility -> current Handoff source
  -- -> family/current revision.
  if p_source_kind='CONFIRMED_NEED' then
    perform atlas_core.purchase_review_lock_confirmed_source(
      atlas_core.pa_05b_safe_uuid(p_family->>'expected_source_batch_id'));
  end if;
  perform atlas_core.school_catering_lock_supplier_evidence(v_service_date,v_ingredient_id,
    p_splits,p_decision_origin='PRIORITY_RECOMMENDATION');
  if p_source_kind='PURCHASE_HANDOFF' then
    perform atlas_core.school_catering_lock_handoff_source(
      v_service_date,v_location_id,v_ingredient_id,v_unit_id);
  end if;

  select f.family_id,f.version into v_family_id,v_version
  from atlas_procurement.school_catering_allocation_families f
  where f.service_date=v_service_date and f.delivery_location_id=v_location_id
    and f.ingredient_id=v_ingredient_id and f.unit_id=v_unit_id for update;
  if v_family_id is not null then
    select r.family_revision_id,r.revision_number into v_prior_revision_id,v_revision_number
    from atlas_procurement.school_catering_allocation_family_revisions r
    where r.family_id=v_family_id and r.is_current for update;
  end if;

  if p_source_kind='CONFIRMED_NEED' then
    v_projection := atlas_core.purchase_review_confirmed_projection(v_service_date,v_location_id,v_ingredient_id,v_unit_id);
    if v_projection->>'complete' is distinct from 'true' then
      return jsonb_build_object('success',false,'error_code','CONFIRMED_NEED_INCOMPLETE');
    end if;
    if v_projection->>'source_confirmed_need_batch_id' is distinct from p_family->>'expected_source_batch_id'
      or v_projection->>'source_confirmed_need_batch_version' is distinct from p_family->>'expected_source_batch_version' then
      return jsonb_build_object('success',false,'error_code','SOURCE_CHANGED');
    end if;
    -- Compatibility recovery: an already released Need without a real Handoff
    -- may still receive an explicit supplier decision. Need itself is immutable.
    if v_projection->>'batch_status' not in ('DRAFT_REVIEW','REOPENED','RELEASED_FOR_PURCHASE_HANDOFF')
      or (v_projection->>'batch_status'='RELEASED_FOR_PURCHASE_HANDOFF' and
        atlas_core.school_catering_family_projection(v_service_date,v_location_id,v_ingredient_id,v_unit_id)
          ->>'source_purchase_handoff_revision_id' is not null) then
      return jsonb_build_object('success',false,'error_code','SOURCE_NOT_EDITABLE');
    end if;
  else
    v_projection := atlas_core.school_catering_family_projection(v_service_date,v_location_id,v_ingredient_id,v_unit_id);
  end if;
  v_quantity := atlas_core.pa_05b_safe_numeric(v_projection ->> 'family_quantity');
  v_fingerprint := v_projection ->> 'source_fingerprint';
  if v_quantity is null or v_quantity <= 0 then
    return jsonb_build_object('success',false,'error_code','SOURCE_NOT_AVAILABLE');
  end if;
  if v_fingerprint is distinct from p_family ->> 'expected_source_fingerprint' then
    return jsonb_build_object('success',false,'error_code','SOURCE_CHANGED',
      'source_fingerprint',v_fingerprint);
  end if;
  if p_decision_origin='PRIORITY_RECOMMENDATION' and v_family_id is not null then
    return jsonb_build_object('success',false,'error_code','STALE_OR_EDITED');
  end if;
  if coalesce(v_version,0) <> p_expected_version then
    return jsonb_build_object('success',false,'error_code','STALE_VERSION',
      'actual_version',coalesce(v_version,0));
  end if;

  if p_decision_origin='PRIORITY_RECOMMENDATION' then
    select pg_catalog.min(e.priority) into v_best_priority
    from atlas_admin.supplier_eligibilities e
    join atlas_admin.suppliers sp
      on sp.supplier_id=e.supplier_id and sp.supplier_status='ACTIVE'
    where e.ingredient_id=v_ingredient_id and e.eligibility_status='ACTIVE'
      and e.priority is not null and e.effective_from<=v_service_date
      and (e.effective_to is null or e.effective_to>v_service_date);
    select pg_catalog.count(*)::integer,
      (pg_catalog.array_agg(e.supplier_id order by e.supplier_id))[1]
      into v_best_count,v_supplier_id
    from atlas_admin.supplier_eligibilities e
    join atlas_admin.suppliers sp
      on sp.supplier_id=e.supplier_id and sp.supplier_status='ACTIVE'
    where e.ingredient_id=v_ingredient_id and e.eligibility_status='ACTIVE'
      and e.priority=v_best_priority and e.effective_from<=v_service_date
      and (e.effective_to is null or e.effective_to>v_service_date);
    if v_best_count<>1 then
      return jsonb_build_object('success',false,'error_code',
        case when v_best_count=0 then 'NO_ELIGIBLE_SUPPLIER'
             else 'AMBIGUOUS_SUPPLIER_PRIORITY' end);
    end if;
    v_effective_splits := pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'supplier_id',v_supplier_id,'allocated_quantity',v_quantity));
  end if;

  select pg_catalog.sum(atlas_core.pa_05b_safe_numeric(s ->> 'allocated_quantity'))::numeric(20,6)
    into v_sum from pg_catalog.jsonb_array_elements(v_effective_splits) s;
  if v_sum is distinct from v_quantity then
    return jsonb_build_object('success',false,'error_code','ALLOCATION_IMBALANCED',
      'family_quantity',v_quantity,'allocated_quantity',v_sum);
  end if;
  if exists(select 1 from pg_catalog.jsonb_array_elements(v_effective_splits) s
    left join atlas_admin.suppliers sp
      on sp.supplier_id=atlas_core.pa_05b_safe_uuid(s ->> 'supplier_id')
    where sp.supplier_id is null or sp.supplier_status<>'ACTIVE') then
    return jsonb_build_object('success',false,'error_code','SUPPLIER_INACTIVE');
  end if;
  if exists(select 1 from pg_catalog.jsonb_array_elements(v_effective_splits) s
    where not exists(select 1 from atlas_admin.supplier_eligibilities e
      where e.supplier_id=atlas_core.pa_05b_safe_uuid(s ->> 'supplier_id')
        and e.ingredient_id=v_ingredient_id and e.eligibility_status='ACTIVE'
        and e.effective_from<=v_service_date
        and (e.effective_to is null or e.effective_to>v_service_date))) then
    return jsonb_build_object('success',false,'error_code','SUPPLIER_INELIGIBLE');
  end if;

  if v_family_id is null then
    insert into atlas_procurement.school_catering_allocation_families(
      service_date,delivery_location_id,ingredient_id,unit_id,version)
    values(v_service_date,v_location_id,v_ingredient_id,v_unit_id,1)
    returning family_id,version into v_family_id,v_version;
    v_revision_number := 1;
  else
    update atlas_procurement.school_catering_allocation_family_revisions
      set is_current=false where family_revision_id=v_prior_revision_id;
    update atlas_procurement.school_catering_allocation_families
      set version=version+1,updated_at=transaction_timestamp()
      where family_id=v_family_id returning version into v_version;
    v_revision_number := coalesce(v_revision_number,0)+1;
  end if;
  insert into atlas_procurement.school_catering_allocation_family_revisions(
    family_id,revision_number,is_current,predecessor_revision_id,
    source_purchase_handoff_revision_id,source_kind,source_confirmed_need_batch_id,
    source_confirmed_need_batch_version,source_fingerprint,family_quantity,unit_id,
    accepted_by_actor_id,accepted_at,command_id,decision_origin)
  values(v_family_id,v_revision_number,true,v_prior_revision_id,
    atlas_core.pa_05b_safe_uuid(v_projection ->> 'source_purchase_handoff_revision_id'),
    p_source_kind,
    case when p_source_kind='CONFIRMED_NEED' then (v_projection->>'source_confirmed_need_batch_id')::uuid end,
    case when p_source_kind='CONFIRMED_NEED' then (v_projection->>'source_confirmed_need_batch_version')::bigint end,
    v_fingerprint,v_quantity,v_unit_id,p_actor_id,transaction_timestamp(),p_command_id,p_decision_origin)
  returning family_revision_id into v_revision_id;
  insert into atlas_procurement.school_catering_allocation_family_contributions(
    family_revision_id,purchase_handoff_line_revision_id,confirmed_need_line_revision_id,
    confirmed_need_line_decision_id,contribution_quantity)
  select v_revision_id,atlas_core.pa_05b_safe_uuid(c ->> 'purchase_handoff_line_revision_id'),
    atlas_core.pa_05b_safe_uuid(c->>'confirmed_need_line_revision_id'),
    atlas_core.pa_05b_safe_uuid(c->>'confirmed_need_line_decision_id'),
    atlas_core.pa_05b_safe_numeric(c ->> 'contribution_quantity')
  from jsonb_array_elements(v_projection -> 'contributions') c;
  for v_split in select value from pg_catalog.jsonb_array_elements(v_effective_splits) loop
    v_supplier_id := atlas_core.pa_05b_safe_uuid(v_split ->> 'supplier_id');
    insert into atlas_procurement.school_catering_allocation_supplier_splits(
      family_revision_id,supplier_id,allocated_quantity,split_ratio,decision_origin)
    values(v_revision_id,v_supplier_id,
      atlas_core.pa_05b_safe_numeric(v_split ->> 'allocated_quantity'),
      round(atlas_core.pa_05b_safe_numeric(v_split ->> 'allocated_quantity')/v_quantity,12),
      p_decision_origin);
  end loop;
  return jsonb_build_object('success',true,'family_id',v_family_id,
    'family_revision_id',v_revision_id,'family_version',v_version,
    'source_kind',p_source_kind,'source_fingerprint',v_fingerprint,'family_quantity',v_quantity::text);
end;
$$;
revoke all on function atlas_core.purchase_review_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text,text)
  from public,anon,authenticated,service_role;
create function atlas_api.save_confirmed_supplier_allocation(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text := 'save_confirmed_supplier_allocation';
  v_actor jsonb; v_actor_id uuid; v_begin jsonb; v_receipt uuid; v_result jsonb;
  v_event uuid; v_audit uuid; v_response jsonb; v_receipt_request jsonb;
begin
  if request ->> 'contract_version' is distinct from 'CONFIRMED-SUPPLIER-ALLOCATION.v1'
     or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') < 0
     or request ->> 'reason_code' is distinct from 'CONFIRMED_SUPPLIER_ALLOCATION_SAVED'
     or (request -> 'payload') - array['family','splits'] <> '{}'::jsonb
     or not(request ?& array['contract_version','command_id','correlation_id','idempotency_key','expected_version',
       'requested_by_auth_subject','requested_at','reason_code','reason_note','payload'])
     or request - array['contract_version','command_id','correlation_id','idempotency_key','expected_version',
       'requested_by_auth_subject','requested_at','reason_code','reason_note','payload'] <> '{}'::jsonb
     or jsonb_typeof(request->'payload') is distinct from 'object'
     or jsonb_typeof(request#>'{payload,family}') is distinct from 'object'
     or (request#>'{payload,family}') - array['service_date','delivery_location_id','ingredient_id','unit_id',
       'expected_source_fingerprint','expected_source_batch_id','expected_source_batch_version'] <> '{}'::jsonb
     or atlas_core.pa_05b_safe_uuid(request#>>'{payload,family,expected_source_batch_id}') is null
     or atlas_core.pa_05b_safe_bigint(request#>>'{payload,family,expected_source_batch_version}') is null
     or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
     or nullif(btrim(request->>'idempotency_key'),'') is null or length(request->>'idempotency_key')>200
     or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at') is null
     or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at')>transaction_timestamp()+interval '60 seconds' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The school-catering supplier allocation request is invalid.','PROCUREMENT',v_name);
  end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_response := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_response is not null and v_response ->> 'error_code'<>'SCOPE_DENIED' then
    return v_response;
  end if;
  if not atlas_core.school_catering_actor_has_scope(v_actor_id,null,null,
      atlas_core.pa_05b_safe_uuid(request #>> '{payload,family,delivery_location_id}')) then
    return coalesce(v_response,atlas_core.pa_05b_command_error(request,'SCOPE_DENIED',
      'The actor is outside the requested school-catering scope.','PROCUREMENT',v_name));
  end if;
  v_receipt_request := case
    when atlas_core.pa_05b_safe_bigint(request ->> 'expected_version')=0
      then pg_catalog.jsonb_set(request,'{expected_version}','null'::jsonb)
    else request
  end;
  v_begin := atlas_core.pa_05b_begin_command(v_receipt_request,v_actor_id,v_name,'PROCUREMENT',
    'school-catering-family:' || coalesce(request #>> '{payload,family,service_date}','') || ':' ||
    coalesce(request #>> '{payload,family,delivery_location_id}','') || ':' ||
    coalesce(request #>> '{payload,family,ingredient_id}','') || ':' ||
    coalesce(request #>> '{payload,family,unit_id}',''));
  if v_begin ->> 'status' in ('REPLAY','ERROR') then return v_begin -> 'response'; end if;
  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  v_result := atlas_core.purchase_review_persist_allocation(v_actor_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'),
    request #> '{payload,family}',request #> '{payload,splits}',
    'MANUAL','CONFIRMED_NEED');
  if not (v_result ->> 'success')::boolean then
    v_response := atlas_core.pa_05b_command_error(request,v_result ->> 'error_code',
      case when v_result->>'error_code'='CONFIRMED_NEED_INCOMPLETE'
        then 'Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.'
        else 'Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.' end,'PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_response,false);
  end if;
  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version,command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary)
  values('ConfirmedSupplierAllocationSaved','PROCUREMENT','AllocationFamily',
    atlas_core.pa_05b_safe_uuid(v_result ->> 'family_id'),(v_result ->> 'family_version')::bigint,
    v_receipt,atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,transaction_timestamp(),v_result)
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,reason_code,
    reason_note,after_summary,source_interface,occurred_at)
  values('ConfirmedSupplierAllocationSaved','PROCUREMENT','AllocationFamily',
    atlas_core.pa_05b_safe_uuid(v_result ->> 'family_id'),(v_result ->> 'family_version')::bigint,
    v_receipt,atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,request ->> 'reason_code',
    request ->> 'reason_note',v_result,'atlas_api',transaction_timestamp())
  returning audit_event_id into v_audit;
  v_response := jsonb_build_object('success',true,'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'command_id',request ->> 'command_id','correlation_id',request ->> 'correlation_id',
    'idempotency_status','COMPLETED','family',v_result,'emitted_event_ids',jsonb_build_array(v_event),
    'audit_event_ids',jsonb_build_array(v_audit),'safe_operator_message','Đã lưu phân bổ nhà cung ứng.',
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'The command could not acquire a safe transaction state. Retry the exact request.',
    'PROCUREMENT',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'The supplier allocation could not be saved safely.','PROCUREMENT',v_name);
end;
$$;
revoke all on function atlas_api.save_confirmed_supplier_allocation(jsonb) from public,anon,service_role;
grant execute on function atlas_api.save_confirmed_supplier_allocation(jsonb) to authenticated;
reset role;

set role atlas_procurement_command_runtime;
create function atlas_core.purchase_review_allocation_ready(p_batch uuid)
returns boolean language sql stable security definer set search_path='' as $$
  with source as materialized (
    select p from atlas_core.purchase_review_confirmed_batch_sources(p_batch) p
  )
  select exists(select 1 from source) and not exists(
    select 1 from source where p->>'complete' is distinct from 'true'
      or ((p->>'family_quantity')::numeric>0 and not exists(
        select 1 from atlas_procurement.school_catering_allocation_families f
        join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
        where f.service_date=(p->>'service_date')::date and f.delivery_location_id=(p->>'delivery_location_id')::uuid
          and f.ingredient_id=(p->>'ingredient_id')::uuid and f.unit_id=(p->>'unit_id')::uuid
          and r.is_current and r.source_kind='CONFIRMED_NEED' and r.source_confirmed_need_batch_id=p_batch
          and r.source_fingerprint=p->>'source_fingerprint' and r.family_quantity=(p->>'family_quantity')::numeric
          and r.source_confirmed_need_batch_version<=(p->>'source_confirmed_need_batch_version')::bigint
          and (select sum(s.allocated_quantity) from atlas_procurement.school_catering_allocation_supplier_splits s
            where s.family_revision_id=r.family_revision_id)=r.family_quantity
          and not exists(select 1 from atlas_procurement.school_catering_allocation_supplier_splits s
            where s.family_revision_id=r.family_revision_id and not exists(
              select 1 from atlas_admin.suppliers sp join atlas_admin.supplier_eligibilities e using(supplier_id)
              where sp.supplier_id=s.supplier_id and sp.supplier_status='ACTIVE' and e.eligibility_status='ACTIVE'
                and e.ingredient_id=f.ingredient_id and e.effective_from<=f.service_date
                and (e.effective_to is null or e.effective_to>f.service_date))))));
$$;
create function atlas_core.purchase_review_lock_allocations(p_batch uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
declare p jsonb; v_splits jsonb;
begin
  -- Caller holds the Confirmed Need batch first. Same order as confirmed Save.
  for p in select source.value from atlas_core.purchase_review_confirmed_batch_sources(p_batch) source(value)
    order by source.value->>'ingredient_id',source.value->>'service_date',source.value->>'delivery_location_id',source.value->>'unit_id' loop
    select coalesce(jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id)),'[]') into v_splits
      from atlas_procurement.school_catering_allocation_families f
      join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
      join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
      where r.is_current and f.service_date=(p->>'service_date')::date
        and f.delivery_location_id=(p->>'delivery_location_id')::uuid
        and f.ingredient_id=(p->>'ingredient_id')::uuid and f.unit_id=(p->>'unit_id')::uuid;
    perform atlas_core.school_catering_lock_supplier_evidence((p->>'service_date')::date,
      (p->>'ingredient_id')::uuid,v_splits,false);
  end loop;
  perform 1 from atlas_procurement.school_catering_allocation_families f
    where exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions r
      where r.family_id=f.family_id and r.is_current and r.source_confirmed_need_batch_id=p_batch)
    order by f.family_id for update;
end;
$$;
revoke all on function atlas_core.purchase_review_allocation_ready(uuid),atlas_core.purchase_review_lock_allocations(uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_allocation_ready(uuid),atlas_core.purchase_review_lock_allocations(uuid)
  to atlas_confirmed_need_review_runtime,atlas_planning_command_runtime;
reset role;

set role atlas_confirmed_need_review_runtime;
create function atlas_core.purchase_review_release_guard()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform atlas_core.purchase_review_lock_allocations(new.confirmed_need_batch_id);
  if not atlas_core.purchase_review_allocation_ready(new.confirmed_need_batch_id) then
    raise exception using errcode='PPR01',message='Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.';
  end if;
  return new;
end;
$$;
revoke all on function atlas_core.purchase_review_release_guard() from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_release_guard() to atlas_owner;
reset role;
set role atlas_owner;
create trigger purchase_review_confirmed_need_release_readiness
  before update of batch_status on atlas_planning.confirmed_need_batches for each row
  when (new.source_kind='NEED_GENERATION' and new.batch_status='RELEASED_FOR_PURCHASE_HANDOFF'
    and old.batch_status is distinct from new.batch_status)
  execute function atlas_core.purchase_review_release_guard();
reset role;

-- Preserve complete existing release bodies/replay paths. Expected readiness
-- rejection uses its own SQLSTATE and rolls back all validation/approval writes.
do $release_readiness$
declare definition text; api_name text;
begin
  foreach api_name in array array['release_confirmed_needs','release_confirmed_needs_for_purchase_handoff'] loop
    definition:=pg_get_functiondef(('atlas_api.'||api_name||'(jsonb)')::regprocedure);
    if position('when others then' in definition)=0 then raise exception 'Release error boundary changed'; end if;
    definition:=replace(definition,'when others then',
      'when sqlstate ''PPR01'' then return atlas_core.pa_05b_command_error(request,''CONFIRMED_ALLOCATION_NOT_READY'',''Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.'',''PLANNING'','''||api_name||'''); when others then');
    execute definition;
  end loop;
  definition:=pg_get_functiondef('atlas_core.d037_extend_workbench(jsonb,uuid)'::regprocedure);
  definition:=replace(definition,'  v_release_message := case v_release_code',
    '  if v_release_code is null and not atlas_core.purchase_review_allocation_ready(v_batch_id) then
       v_release_code := ''CONFIRMED_ALLOCATION_NOT_READY'';
     end if;
     v_release_message := case v_release_code
       when ''CONFIRMED_ALLOCATION_NOT_READY'' then ''Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.''');
  execute definition;
end;
$release_readiness$;

set role atlas_procurement_command_runtime;
create function atlas_core.purchase_review_promote_allocations(p_batch uuid,p_actor uuid,p_command uuid,p_correlation uuid,p_receipt uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  p jsonb; h jsonb; f record; r record; v_splits jsonb; v_saved jsonb;
  v_expected jsonb; v_actual jsonb; v_event uuid; v_audit uuid;
  v_events jsonb:='[]';v_audits jsonb:='[]';v_revisions jsonb:='[]';
begin
  if not atlas_core.purchase_review_allocation_ready(p_batch) then
    raise exception using errcode='PPR01',message='Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.';
  end if;
  for p in select source.value from atlas_core.purchase_review_confirmed_batch_sources(p_batch) source(value)
    where (source.value->>'family_quantity')::numeric>0
    order by source.value->>'service_date',source.value->>'delivery_location_id',source.value->>'ingredient_id',source.value->>'unit_id' loop
    select x.* into strict f from atlas_procurement.school_catering_allocation_families x
      where x.service_date=(p->>'service_date')::date and x.delivery_location_id=(p->>'delivery_location_id')::uuid
        and x.ingredient_id=(p->>'ingredient_id')::uuid and x.unit_id=(p->>'unit_id')::uuid for update;
    select x.* into strict r from atlas_procurement.school_catering_allocation_family_revisions x
      where x.family_id=f.family_id and x.is_current for update;
    h:=atlas_core.school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id);
    select jsonb_agg(jsonb_build_array(c->>'confirmed_need_line_revision_id',(c->>'contribution_quantity')::numeric)
      order by c->>'confirmed_need_line_revision_id') into v_expected from jsonb_array_elements(p->'contributions') c;
    select jsonb_agg(jsonb_build_array(l.confirmed_need_line_revision_id::text,l.handoff_quantity)
      order by l.confirmed_need_line_revision_id) into v_actual
      from jsonb_array_elements(h->'contributions') c join atlas_planning.purchase_handoff_line_revisions l
        on l.purchase_handoff_line_revision_id=(c->>'purchase_handoff_line_revision_id')::uuid;
    if v_actual is distinct from v_expected or (h->>'family_quantity')::numeric<>r.family_quantity then
      raise exception using errcode='PPR01',message='Nhu cầu bàn giao không khớp phân bổ đã xác nhận.';
    end if;
    select jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,'allocated_quantity',s.allocated_quantity::text)
      order by s.supplier_id) into v_splits from atlas_procurement.school_catering_allocation_supplier_splits s
      where s.family_revision_id=r.family_revision_id;
    v_saved:=atlas_core.purchase_review_persist_allocation(p_actor,p_command,f.version,
      jsonb_build_object('service_date',f.service_date,'delivery_location_id',f.delivery_location_id,
        'ingredient_id',f.ingredient_id,'unit_id',f.unit_id,'expected_source_fingerprint',h->>'source_fingerprint'),
      v_splits,r.decision_origin,'PURCHASE_HANDOFF');
    if v_saved->>'success' is distinct from 'true' then
      raise exception using errcode='PPR01',message='Không thể chuyển phân bổ đã xác nhận sang nhu cầu bàn giao.';
    end if;
    insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,aggregate_version,
      command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary)
    values('ConfirmedSupplierAllocationPromotedToHandoff','PROCUREMENT','AllocationFamily',f.family_id,
      (v_saved->>'family_version')::bigint,p_receipt,p_command,p_correlation,p_actor,transaction_timestamp(),
      v_saved||jsonb_build_object('predecessor_revision_id',r.family_revision_id)) returning domain_event_id into v_event;
    insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,aggregate_version_after,
      command_receipt_id,command_id,correlation_id,actor_id,reason_code,after_summary,source_interface,occurred_at)
    values('ConfirmedSupplierAllocationPromotedToHandoff','PROCUREMENT','AllocationFamily',f.family_id,
      (v_saved->>'family_version')::bigint,p_receipt,p_command,p_correlation,p_actor,'ALLOCATION_HANDOFF_PROMOTED',
      v_saved||jsonb_build_object('predecessor_revision_id',r.family_revision_id),'atlas_api',transaction_timestamp())
      returning audit_event_id into v_audit;
    v_events:=v_events||jsonb_build_array(v_event);v_audits:=v_audits||jsonb_build_array(v_audit);
    v_revisions:=v_revisions||jsonb_build_array(v_saved);
  end loop;
  return jsonb_build_object('revisions',v_revisions,'emitted_event_ids',v_events,'audit_event_ids',v_audits);
end;
$$;
revoke all on function atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid) to atlas_planning_command_runtime;
reset role;

do $handoff_promotion$
declare definition text:=pg_get_functiondef('atlas_api.release_school_catering_purchase_handoff(jsonb)'::regprocedure);
begin
  definition:=replace(definition,'  v_response jsonb;','  v_response jsonb; v_promotions jsonb;');
  definition:=replace(definition,'  if v_handoff.purchase_handoff_batch_id is null then',
    '  perform atlas_core.purchase_review_lock_allocations(v_batch_id);
       if not atlas_core.purchase_review_allocation_ready(v_batch_id) then
         return atlas_core.pa_05b_finish_command(v_receipt_id,atlas_core.pa_05b_command_error(request,
           ''CONFIRMED_ALLOCATION_NOT_READY'',''Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.'',
           ''PLANNING'',v_command_name),false);
       end if;
       if v_handoff.purchase_handoff_batch_id is null then');
  definition:=replace(definition,'  v_response := pg_catalog.jsonb_build_object(''success'',true,',
    '  v_promotions:=atlas_core.purchase_review_promote_allocations(v_batch_id,v_actor_id,
       atlas_core.pa_05b_safe_uuid(request->>''command_id''),atlas_core.pa_05b_safe_uuid(request->>''correlation_id''),v_receipt_id);
       v_response := pg_catalog.jsonb_build_object(''success'',true,');
  definition:=replace(definition,'''emitted_event_ids'',pg_catalog.jsonb_build_array(v_event_id),',
    '''allocation_promotions'',v_promotions->''revisions'',
     ''emitted_event_ids'',pg_catalog.jsonb_build_array(v_event_id)||(v_promotions->''emitted_event_ids''),');
  definition:=replace(definition,'''audit_event_ids'',pg_catalog.jsonb_build_array(v_audit_id),',
    '''audit_event_ids'',pg_catalog.jsonb_build_array(v_audit_id)||(v_promotions->''audit_event_ids''),');
  definition:=replace(definition,'  when others then',
    '  when sqlstate ''PPR01'' then return atlas_core.pa_05b_command_error(request,''CONFIRMED_ALLOCATION_NOT_READY'',
       ''Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.'',''PLANNING'',v_command_name);
       when others then');
  execute definition;
end;
$handoff_promotion$;

-- One transaction owns preparation. Every child still checks its existing
-- capability/scope, creates its own durable receipt and returns authoritative
-- evidence. Any child rejection rolls back all newly performed child commands.
set role atlas_confirmed_need_review_runtime;
create function atlas_api.prepare_school_catering_purchase_orders(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text:='prepare_school_catering_purchase_orders';
  v_batch_id uuid:=atlas_core.pa_05b_safe_uuid(request#>>'{payload,confirmed_need_batch_id}');
  v_date date:=atlas_core.pa_05d_safe_date(request#>>'{payload,service_date}');
  v_actor jsonb;v_actor_id uuid;v_error jsonb;v_begin jsonb;v_receipt uuid;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_child jsonb;v_release jsonb;v_handoff jsonb;v_drafts jsonb;v_response jsonb;v_cap text;
begin
  if jsonb_typeof(request) is distinct from 'object'
    or request->>'contract_version' is distinct from 'PURCHASE-COMMITMENT.v1'
    or request->>'reason_code' is distinct from 'PURCHASE_ORDERS_PREPARED'
    or not(request ?& array['contract_version','command_id','correlation_id','idempotency_key','expected_version',
      'requested_by_auth_subject','requested_at','reason_code','reason_note','payload'])
    or request-array['contract_version','command_id','correlation_id','idempotency_key','expected_version',
      'requested_by_auth_subject','requested_at','reason_code','reason_note','payload']<>'{}'::jsonb
    or jsonb_typeof(request->'payload') is distinct from 'object'
    or (request->'payload')-array['confirmed_need_batch_id','service_date']<>'{}'::jsonb
    or v_batch_id is null or v_date is null
    or atlas_core.pa_05b_safe_uuid(request->>'command_id') is null
    or atlas_core.pa_05b_safe_uuid(request->>'correlation_id') is null
    or coalesce(atlas_core.pa_05b_safe_bigint(request->>'expected_version'),0)<=0
    or nullif(btrim(request->>'idempotency_key'),'') is null or length(request->>'idempotency_key')>200
    or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at') is null
    or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at')>transaction_timestamp()+interval '60 seconds' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Yêu cầu chuẩn bị đơn mua không hợp lệ.','PROCUREMENT',v_name);
  end if;
  v_actor:=atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor?'error' then return v_actor->'error'; end if;
  v_actor_id:=(v_actor->>'actor_id')::uuid;
  foreach v_cap in array array['confirmed_need_release.release','procurement.school_catering.write'] loop
    v_error:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,v_cap,'PROCUREMENT',v_name,null,null,null);
    if v_error is not null and v_error->>'error_code'<>'SCOPE_DENIED' then return v_error; end if;
  end loop;
  if exists(select 1 from atlas_planning.confirmed_need_line_revisions r
    where r.confirmed_need_batch_id=v_batch_id and r.is_current
      and not atlas_core.school_catering_actor_has_scope(v_actor_id,r.customer_id,r.school_id,r.delivery_location_id)) then
    return atlas_core.pa_05b_command_error(request,'SCOPE_DENIED','Bạn không có quyền với toàn bộ nhu cầu này.','PROCUREMENT',v_name);
  end if;
  v_begin:=atlas_core.pa_05b_begin_command(request,v_actor_id,v_name,'PROCUREMENT','PurchasePreparation:'||v_batch_id);
  if v_begin->>'status'<>'NEW' then return v_begin->'response'; end if;
  v_receipt:=(v_begin->>'receipt_id')::uuid;
  select * into v_batch from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_batch_id for update;
  if not found or v_batch.source_kind<>'NEED_GENERATION' or v_batch.period_start<>v_date or v_batch.period_end<>v_date then
    v_error:=atlas_core.pa_05b_command_error(request,'SOURCE_NOT_AVAILABLE','Chọn nhu cầu hiện hành của đúng một ngày phục vụ.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if v_batch.version<>(request->>'expected_version')::bigint then
    v_error:=atlas_core.pa_05b_command_error(request,'STALE_VERSION','Nhu cầu đã thay đổi. Tải lại trước khi chuẩn bị đơn mua.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  begin
    if v_batch.batch_status in ('DRAFT_REVIEW','REOPENED') then
      v_child:=request||jsonb_build_object('contract_version','RMVP-07.v2','command_id',gen_random_uuid(),
        'idempotency_key',v_receipt::text||':release','requested_at',transaction_timestamp()-interval '1 second',
        'reason_code','CONFIRMED_NEED_RELEASED','reason_note',null,
        'payload',jsonb_build_object('confirmed_need_batch_id',v_batch_id));
      v_release:=atlas_api.release_confirmed_needs(v_child);
      if v_release->>'success' is distinct from 'true' then v_error:=v_release; raise exception using errcode='PPR02'; end if;
      select * into strict v_batch from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_batch_id;
    elsif v_batch.batch_status='RELEASED_FOR_PURCHASE_HANDOFF' then
      v_release:=jsonb_build_object('success',true,'already_released',true,'confirmed_need_batch_id',v_batch_id,'version',v_batch.version);
    else
      v_error:=atlas_core.pa_05b_command_error(request,'SOURCE_NOT_AVAILABLE','Nhu cầu chưa sẵn sàng để chuẩn bị đơn mua.','PROCUREMENT',v_name);
      raise exception using errcode='PPR02';
    end if;
    if exists(select 1 from atlas_planning.purchase_handoff_batches h
      join atlas_planning.purchase_handoff_revisions r using(purchase_handoff_batch_id)
      where h.confirmed_need_batch_id=v_batch_id and h.handoff_status='RELEASED_TO_PROCUREMENT'
        and r.is_current and r.revision_status='RELEASED_TO_PROCUREMENT') then
      v_handoff:=jsonb_build_object('success',true,'already_released',true);
    else
      v_child:=request||jsonb_build_object('contract_version','SCHOOL-CATERING-HANDOFF.v1','command_id',gen_random_uuid(),
        'idempotency_key',v_receipt::text||':handoff','requested_at',transaction_timestamp()-interval '1 second',
        'expected_version',v_batch.version,'reason_code','SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED','reason_note',null,
        'payload',jsonb_build_object('confirmed_need_batch_id',v_batch_id));
      v_handoff:=atlas_api.release_school_catering_purchase_handoff(v_child);
      if v_handoff->>'success' is distinct from 'true' then v_error:=v_handoff; raise exception using errcode='PPR02'; end if;
    end if;
    v_child:=request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1','command_id',gen_random_uuid(),
      'idempotency_key',v_receipt::text||':drafts','requested_at',transaction_timestamp()-interval '1 second',
      'expected_version',1,'reason_code','SCHOOL_CATERING_PO_DRAFTS_CREATED','reason_note',null,
      'payload',jsonb_build_object('date_start',v_date,'date_end',v_date));
    v_drafts:=atlas_api.create_school_catering_purchase_order_drafts(v_child);
    if v_drafts->>'success' is distinct from 'true' then v_error:=v_drafts; raise exception using errcode='PPR02'; end if;
    if not coalesce(v_drafts->'ready_dates' @> jsonb_build_array(v_date),false)
      or jsonb_array_length(coalesce(v_drafts->'skipped_dates','[]'::jsonb))>0
      or jsonb_array_length(coalesce(v_drafts->'blockers','[]'::jsonb))>0
      or not atlas_core.purchase_review_po_coverage(v_date) then
      v_error:=atlas_core.pa_05b_command_error(request,'PREPARATION_BLOCKED',
        'Phân bổ nhà cung ứng chưa khớp hoặc chưa đủ điều kiện tạo đơn mua.','PROCUREMENT',v_name)
        ||jsonb_build_object('blockers',v_drafts->'blockers');
      raise exception using errcode='PPR02';
    end if;
  exception when sqlstate 'PPR02' then
    if coalesce((v_error->>'retryable')::boolean,false) then
      raise exception using errcode='PPR03';
    end if;
    v_response:=atlas_core.pa_05b_command_error(request,coalesce(v_error->>'error_code','PREPARATION_BLOCKED'),
      coalesce(v_error->>'safe_message','Chưa thể chuẩn bị đơn mua. Tải lại để kiểm tra nhu cầu và phân bổ.'),'PROCUREMENT',v_name)
      ||jsonb_build_object('blockers',coalesce(v_error->'blockers','[]'::jsonb));
    return atlas_core.pa_05b_finish_command(v_receipt,v_response,false);
  end;
  v_response:=jsonb_build_object('success',true,'contract_version','PURCHASE-COMMITMENT.v1',
    'command_id',request->'command_id','correlation_id',request->'correlation_id','service_date',v_date,
    'confirmed_need_batch_id',v_batch_id,'confirmed_need_batch_version',v_batch.version,
    'planning_release',v_release,'handoff',v_handoff,'purchase_order_drafts',v_drafts,
    'blockers','[]'::jsonb,'warnings','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when sqlstate 'PPR03' then
  return atlas_core.pa_05b_command_error(request,coalesce(v_error->>'error_code','RETRYABLE_CONCURRENCY_FAILURE'),
    coalesce(v_error->>'safe_message','Chưa thể khóa dữ liệu an toàn. Bạn có thể thử lại đúng yêu cầu này.'),'PROCUREMENT',v_name,true);
when serialization_failure or deadlock_detected or unique_violation then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'Chưa thể khóa dữ liệu an toàn. Bạn có thể thử lại đúng yêu cầu này.','PROCUREMENT',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'Không thể chuẩn bị đơn mua an toàn. Tải lại để kiểm tra trạng thái.','PROCUREMENT',v_name);
end;
$$;
revoke all on function atlas_api.prepare_school_catering_purchase_orders(jsonb) from public,anon,service_role;
grant execute on function atlas_api.prepare_school_catering_purchase_orders(jsonb) to authenticated;
reset role;
grant execute on function atlas_api.release_school_catering_purchase_handoff(jsonb),
  atlas_api.create_school_catering_purchase_order_drafts(jsonb) to atlas_confirmed_need_review_runtime;

set role atlas_confirmed_need_review_runtime;
create function atlas_core.purchase_review_confirmed_contribution_valid(
  p_batch uuid,p_date date,p_location uuid,p_ingredient uuid,p_unit uuid,p_revision uuid,p_decision uuid,p_quantity numeric
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from atlas_planning.confirmed_need_line_revisions r
    join atlas_planning.confirmed_need_line_decisions d on d.confirmed_need_line_decision_id=p_decision
    where r.confirmed_need_line_revision_id=p_revision and r.confirmed_need_batch_id=p_batch
      and r.service_date=p_date and r.delivery_location_id=p_location and r.ingredient_id=p_ingredient and r.unit_id=p_unit
      and d.confirmed_need_batch_id=p_batch and d.confirmed_quantity_after=p_quantity
      and r.confirmed_quantity=p_quantity
      and atlas_core.planning_contract_02b_decision_authorizes_revision(p_decision,r.confirmed_need_line_id,p_revision));
$$;
revoke all on function atlas_core.purchase_review_confirmed_contribution_valid(uuid,date,uuid,uuid,uuid,uuid,uuid,numeric)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_confirmed_contribution_valid(uuid,date,uuid,uuid,uuid,uuid,uuid,numeric)
  to atlas_procurement_command_runtime;
reset role;
set role atlas_procurement_command_runtime;
create function atlas_core.purchase_review_allocation_integrity_guard()
returns trigger language plpgsql security definer set search_path='' as $$
declare r record;f record;
begin
  select * into r from atlas_procurement.school_catering_allocation_family_revisions where family_revision_id=new.family_revision_id;
  if not found then return new; end if;
  select * into strict f from atlas_procurement.school_catering_allocation_families where family_id=r.family_id;
  if r.unit_id<>f.unit_id
    or (select sum(contribution_quantity) from atlas_procurement.school_catering_allocation_family_contributions
      where family_revision_id=r.family_revision_id) is distinct from r.family_quantity
    or (select sum(allocated_quantity) from atlas_procurement.school_catering_allocation_supplier_splits
      where family_revision_id=r.family_revision_id) is distinct from r.family_quantity
    or (r.source_kind='PURCHASE_HANDOFF' and r.source_purchase_handoff_revision_id is distinct from (
      select h.purchase_handoff_revision_id from atlas_procurement.school_catering_allocation_family_contributions c
      join atlas_planning.purchase_handoff_line_revisions h using(purchase_handoff_line_revision_id)
      where c.family_revision_id=r.family_revision_id order by h.purchase_handoff_revision_id limit 1))
    or exists(select 1 from atlas_procurement.school_catering_allocation_family_contributions c
      where c.family_revision_id=r.family_revision_id and case r.source_kind
        when 'CONFIRMED_NEED' then c.purchase_handoff_line_revision_id is not null
          or not atlas_core.purchase_review_confirmed_contribution_valid(r.source_confirmed_need_batch_id,
            f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
            c.confirmed_need_line_revision_id,c.confirmed_need_line_decision_id,c.contribution_quantity)
        when 'PURCHASE_HANDOFF' then c.confirmed_need_line_revision_id is not null or not exists(
          select 1 from atlas_planning.purchase_handoff_line_revisions h
          where h.purchase_handoff_line_revision_id=c.purchase_handoff_line_revision_id
            and h.service_date=f.service_date and h.delivery_location_id=f.delivery_location_id
            and h.ingredient_id=f.ingredient_id and h.unit_id=f.unit_id and h.handoff_quantity=c.contribution_quantity)
        else true end) then
    raise exception using errcode='23514',message='Allocation evidence must match its typed source and exact totals.';
  end if;
  return new;
end;
$$;
revoke all on function atlas_core.purchase_review_allocation_integrity_guard() from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_allocation_integrity_guard() to atlas_owner;
reset role;
set role atlas_owner;
create constraint trigger purchase_review_revision_integrity
  after insert or update on atlas_procurement.school_catering_allocation_family_revisions
  deferrable initially deferred for each row execute function atlas_core.purchase_review_allocation_integrity_guard();
create constraint trigger purchase_review_contribution_integrity
  after insert on atlas_procurement.school_catering_allocation_family_contributions
  deferrable initially deferred for each row execute function atlas_core.purchase_review_allocation_integrity_guard();
create constraint trigger purchase_review_split_integrity
  after insert on atlas_procurement.school_catering_allocation_supplier_splits
  deferrable initially deferred for each row execute function atlas_core.purchase_review_allocation_integrity_guard();
reset role;

-- PO readiness, draft selection, stale checks and release selection explicitly
-- require committed Handoff authority; a coincident fingerprint is insufficient.
do $po_authority$
declare definition text;name text;
begin
  foreach name in array array[
    'atlas_core.school_catering_po_date_readiness(date)',
    'atlas_core.school_catering_po_draft_is_stale(uuid,uuid)',
    'atlas_api.create_school_catering_purchase_order_drafts(jsonb)',
    'atlas_api.release_school_catering_purchase_order(jsonb)'] loop
    definition:=pg_get_functiondef(name::regprocedure);
    if position('r.family_id=f.family_id and r.is_current' in definition)=0 then
      raise exception 'Expected PO allocation join changed: %',name;
    end if;
    definition:=replace(definition,'r.family_id=f.family_id and r.is_current',
      'r.family_id=f.family_id and r.is_current and r.source_kind=''PURCHASE_HANDOFF''');
    definition:=replace(definition,'and (not r.is_current',
      'and (r.source_kind<>''PURCHASE_HANDOFF'' or not r.is_current');
    execute definition;
  end loop;
  definition:=pg_get_functiondef('atlas_core.purchase_order_revision_integrity_guard()'::regprocedure);
  definition:=replace(definition,'  if v_root.purchase_order_kind=''SUPPLIER_DIRECT_WHOLESALE'' then',
    '  if exists(select 1 from atlas_procurement.purchase_order_line_revisions l
       join atlas_procurement.school_catering_allocation_supplier_splits s
         on s.supplier_split_id=l.school_catering_allocation_supplier_split_id
       join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
       where l.purchase_order_revision_id=v_revision_id and r.source_kind<>''PURCHASE_HANDOFF'') then
       raise exception using errcode=''23514'',message=''Official PO requires Purchase Handoff allocation authority.'';
     end if;
     if v_root.purchase_order_kind=''SUPPLIER_DIRECT_WHOLESALE'' then');
  execute definition;
end;
$po_authority$;

set role atlas_procurement_command_runtime;
create function atlas_core.purchase_review_po_coverage(p_date date)
returns boolean language sql stable security definer set search_path='' as $$
  with expected as materialized (
    select f.*,s.supplier_split_id,s.supplier_id,s.allocated_quantity
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
    join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
    where f.service_date=p_date and r.is_current and r.source_kind='PURCHASE_HANDOFF'
      and r.source_fingerprint=atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint'
  ), actual as materialized (
    select po.supplier_id,po.purchase_order_status,r.revision_status,l.*
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
    join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
    where po.purchase_order_kind='SCHOOL_CATERING' and po.school_catering_service_date=p_date and r.is_current
  )
  select exists(select 1 from expected)
    and (select count(*) from expected)=(select count(*) from actual)
    and not exists(select 1 from expected e where not exists(
      select 1 from actual l where l.supplier_id=e.supplier_id
        and l.purchase_order_status=l.revision_status and l.revision_status in ('DRAFT','RELEASED_TO_SUPPLIER')
        and l.school_catering_allocation_supplier_split_id=e.supplier_split_id
        and l.ordered_quantity=e.allocated_quantity and l.delivery_location_id=e.delivery_location_id
        and l.ingredient_id=e.ingredient_id and l.unit_id=e.unit_id and l.service_date=e.service_date));
$$;
create function atlas_core.purchase_review_preparation_status(p_date date,p_actor uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare sources jsonb;p jsonb;v_batch uuid;v_version bigint;v_ready boolean:=false;v_allowed boolean:=false;
begin
  select coalesce(jsonb_agg(value),'[]') into sources from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value);
  if (select count(distinct value->>'source_confirmed_need_batch_id') from jsonb_array_elements(sources))<>1 then
    return jsonb_build_object('ready',false,'allowed',false,'blockers',jsonb_build_array('Chọn nhu cầu hiện hành của một ngày phục vụ.'));
  end if;
  if exists(select 1 from jsonb_array_elements(sources) value
    where not atlas_core.school_catering_actor_has_scope(p_actor,null,null,(value->>'delivery_location_id')::uuid)) then
    return jsonb_build_object('ready',false,'allowed',false,'blockers',jsonb_build_array('Bạn không có quyền với toàn bộ nhu cầu này.'));
  end if;
  p:=sources->0;v_batch:=(p->>'source_confirmed_need_batch_id')::uuid;v_version:=(p->>'source_confirmed_need_batch_version')::bigint;
  v_allowed:=atlas_core.pa_05b_authorize_actor('{}',p_actor,'procurement.school_catering.write','PROCUREMENT',
    'prepare_school_catering_purchase_orders',null,null,null) is null
    and atlas_core.pa_05b_authorize_actor('{}',p_actor,'confirmed_need_release.release','PROCUREMENT',
    'prepare_school_catering_purchase_orders',null,null,null) is null;
  v_ready:=atlas_core.purchase_review_allocation_ready(v_batch)
    or coalesce((atlas_core.school_catering_po_date_readiness(p_date)->>'ready')::boolean,false);
  return jsonb_build_object('service_date',p_date,'confirmed_need_batch_id',v_batch,'expected_version',v_version,
    'ready',v_ready,'allowed',v_allowed,'blockers',case when v_ready then '[]'::jsonb else
      jsonb_build_array('Phân bổ nhà cung ứng chưa khớp với nhu cầu đã xác nhận.') end);
end;
$$;
revoke all on function atlas_core.purchase_review_po_coverage(date),atlas_core.purchase_review_preparation_status(date,uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_po_coverage(date) to atlas_confirmed_need_review_runtime;
grant execute on function atlas_core.purchase_review_preparation_status(date,uuid) to atlas_read_runtime;
reset role;

-- Runtime schema creation and SET membership are migration-only privileges.
set role atlas_owner;
revoke create on schema atlas_core,atlas_api from atlas_confirmed_need_review_runtime,
  atlas_procurement_command_runtime,atlas_read_runtime;
reset role;
grant atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime,
  atlas_planning_command_runtime,atlas_read_runtime to postgres with set false;
