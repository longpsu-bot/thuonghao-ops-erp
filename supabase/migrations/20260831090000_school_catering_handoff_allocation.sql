-- School-catering Purchase Handoff and Allocation Family boundary.

reset role;
grant atlas_planning_command_runtime, atlas_procurement_command_runtime,
  atlas_confirmed_need_review_runtime,atlas_need_generation_runtime,
  atlas_read_runtime,atlas_master_data_command_runtime to postgres with set true;
grant usage on schema extensions to atlas_owner,atlas_planning_command_runtime,
  atlas_procurement_command_runtime,atlas_read_runtime;
set role atlas_owner;
grant create on schema atlas_core to atlas_master_data_command_runtime,atlas_planning_command_runtime;
grant create on schema atlas_core,atlas_api to atlas_procurement_command_runtime;

create function atlas_core.school_catering_actor_has_scope(
  p_actor_id uuid,p_customer_id uuid,p_school_id uuid,p_delivery_location_id uuid
) returns boolean language sql stable security invoker set search_path='' as $$
  select exists(
    select 1
    from atlas_core.actor_scopes scope
    where scope.actor_id=p_actor_id
      and scope.scope_status='ACTIVE'
      and scope.effective_from<=pg_catalog.transaction_timestamp()
      and (scope.effective_to is null or scope.effective_to>pg_catalog.transaction_timestamp())
      and (
        scope.scope_kind='GLOBAL'
        or (scope.scope_kind='DELIVERY_LOCATION'
          and scope.delivery_location_id=p_delivery_location_id)
        or (scope.scope_kind='CUSTOMER' and (scope.customer_id=p_customer_id or exists(
          select 1 from atlas_admin.delivery_locations location
          where location.delivery_location_id=p_delivery_location_id
            and location.customer_id=scope.customer_id)))
        or (scope.scope_kind='SCHOOL' and (scope.school_id=p_school_id or exists(
          select 1 from atlas_admin.schools school
          where school.school_id=scope.school_id
            and school.default_delivery_location_id=p_delivery_location_id)))
      )
  );
$$;
revoke execute on function atlas_core.school_catering_actor_has_scope(uuid,uuid,uuid,uuid) from public;
grant execute on function atlas_core.school_catering_actor_has_scope(uuid,uuid,uuid,uuid)
  to atlas_procurement_command_runtime,atlas_planning_command_runtime,atlas_read_runtime;

reset role;
set role atlas_master_data_command_runtime;

create function atlas_core.school_catering_lock_supplier_evidence(
  p_service_date date,p_ingredient_id uuid,p_splits jsonb,p_recommendation boolean
) returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform 1 from atlas_admin.suppliers supplier
  where supplier.supplier_id in (
    select atlas_core.pa_05b_safe_uuid(split ->> 'supplier_id')
    from pg_catalog.jsonb_array_elements(
      case when p_recommendation then '[]'::jsonb else p_splits end) split
    union
    select eligibility.supplier_id from atlas_admin.supplier_eligibilities eligibility
    where p_recommendation and eligibility.ingredient_id=p_ingredient_id
      and eligibility.eligibility_status='ACTIVE'
      and eligibility.effective_from<=p_service_date
      and (eligibility.effective_to is null or eligibility.effective_to>p_service_date)
  ) order by supplier.supplier_id for key share;
  perform 1 from atlas_admin.supplier_eligibilities eligibility
  where eligibility.ingredient_id=p_ingredient_id
    and eligibility.eligibility_status='ACTIVE'
    and eligibility.effective_from<=p_service_date
    and (eligibility.effective_to is null or eligibility.effective_to>p_service_date)
  order by eligibility.supplier_id,eligibility.supplier_eligibility_id for key share;
end;
$$;
revoke execute on function
  atlas_core.school_catering_lock_supplier_evidence(date,uuid,jsonb,boolean) from public;
grant execute on function
  atlas_core.school_catering_lock_supplier_evidence(date,uuid,jsonb,boolean)
  to atlas_procurement_command_runtime;

reset role;
set role atlas_planning_command_runtime;

create function atlas_core.school_catering_lock_handoff_source(
  p_service_date date,p_delivery_location_id uuid,p_ingredient_id uuid,p_unit_id uuid
) returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform 1 from atlas_planning.purchase_handoff_batches batch
  where exists(select 1 from atlas_planning.purchase_handoff_revisions revision
    join atlas_planning.purchase_handoff_line_revisions line
      on line.purchase_handoff_revision_id=revision.purchase_handoff_revision_id
    join atlas_planning.purchase_demand_references demand
      on demand.purchase_handoff_line_revision_id=line.purchase_handoff_line_revision_id
     and demand.source_kind='NEED_GENERATION'
    where revision.purchase_handoff_batch_id=batch.purchase_handoff_batch_id
      and revision.is_current and revision.revision_status='RELEASED_TO_PROCUREMENT'
      and line.service_date=p_service_date
      and line.delivery_location_id=p_delivery_location_id
      and line.ingredient_id=p_ingredient_id and line.unit_id=p_unit_id)
  order by batch.purchase_handoff_batch_id for key share;
  perform 1 from atlas_planning.purchase_handoff_revisions revision
  where revision.purchase_handoff_revision_id in (
    select line.purchase_handoff_revision_id
    from atlas_planning.purchase_handoff_line_revisions line
    join atlas_planning.purchase_demand_references demand
      on demand.purchase_handoff_line_revision_id=line.purchase_handoff_line_revision_id
     and demand.source_kind='NEED_GENERATION'
    where line.service_date=p_service_date
      and line.delivery_location_id=p_delivery_location_id
      and line.ingredient_id=p_ingredient_id and line.unit_id=p_unit_id)
    and revision.is_current and revision.revision_status='RELEASED_TO_PROCUREMENT'
  order by revision.purchase_handoff_revision_id for key share;
end;
$$;
revoke execute on function
  atlas_core.school_catering_lock_handoff_source(date,uuid,uuid,uuid) from public;
grant execute on function
  atlas_core.school_catering_lock_handoff_source(date,uuid,uuid,uuid)
  to atlas_procurement_command_runtime;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from
  atlas_master_data_command_runtime,atlas_planning_command_runtime;
reset role;
set role atlas_procurement_command_runtime;

create function atlas_core.school_catering_persist_allocation(
  p_actor_id uuid,p_command_id uuid,p_expected_version bigint,
  p_family jsonb,p_splits jsonb,p_decision_origin text
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
    if (select pg_catalog.count(*) from pg_catalog.jsonb_array_elements(p_splits)) <>
       (select pg_catalog.count(distinct s ->> 'supplier_id')
        from pg_catalog.jsonb_array_elements(p_splits) s) then
      return jsonb_build_object('success',false,'error_code','DUPLICATE_SUPPLIER');
    end if;
  end if;

  -- One canonical currentness protocol for both manual and recommendation writes:
  -- suppliers -> eligibility -> current Handoff source -> family/current revision.
  perform atlas_core.school_catering_lock_supplier_evidence(v_service_date,v_ingredient_id,
    p_splits,p_decision_origin='PRIORITY_RECOMMENDATION');
  perform atlas_core.school_catering_lock_handoff_source(
    v_service_date,v_location_id,v_ingredient_id,v_unit_id);

  select f.family_id,f.version into v_family_id,v_version
  from atlas_procurement.school_catering_allocation_families f
  where f.service_date=v_service_date and f.delivery_location_id=v_location_id
    and f.ingredient_id=v_ingredient_id and f.unit_id=v_unit_id for update;
  if v_family_id is not null then
    select r.family_revision_id,r.revision_number into v_prior_revision_id,v_revision_number
    from atlas_procurement.school_catering_allocation_family_revisions r
    where r.family_id=v_family_id and r.is_current for update;
  end if;

  v_projection := atlas_core.school_catering_family_projection(
    v_service_date,v_location_id,v_ingredient_id,v_unit_id);
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
    source_purchase_handoff_revision_id,source_fingerprint,family_quantity,unit_id,
    accepted_by_actor_id,accepted_at,command_id,decision_origin)
  values(v_family_id,v_revision_number,true,v_prior_revision_id,
    atlas_core.pa_05b_safe_uuid(v_projection ->> 'source_purchase_handoff_revision_id'),
    v_fingerprint,v_quantity,v_unit_id,p_actor_id,transaction_timestamp(),p_command_id,p_decision_origin)
  returning family_revision_id into v_revision_id;
  insert into atlas_procurement.school_catering_allocation_family_contributions(
    family_revision_id,purchase_handoff_line_revision_id,contribution_quantity)
  select v_revision_id,atlas_core.pa_05b_safe_uuid(c ->> 'purchase_handoff_line_revision_id'),
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
    'source_fingerprint',v_fingerprint,'family_quantity',v_quantity);
end;
$$;

create function atlas_api.save_school_catering_supplier_allocation(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text := 'save_school_catering_supplier_allocation';
  v_actor jsonb; v_actor_id uuid; v_begin jsonb; v_receipt uuid; v_result jsonb;
  v_event uuid; v_audit uuid; v_response jsonb; v_receipt_request jsonb;
begin
  if request ->> 'contract_version' is distinct from 'SCHOOL-CATERING-PROCUREMENT.v1'
     or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') < 0
     or request ->> 'reason_code' is distinct from 'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED'
     or (request -> 'payload') - array['family','splits'] <> '{}'::jsonb then
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
  v_result := atlas_core.school_catering_persist_allocation(v_actor_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'),
    request #> '{payload,family}',request #> '{payload,splits}',
    coalesce(request #>> '{payload,decision_origin}','MANUAL'));
  if not (v_result ->> 'success')::boolean then
    v_response := atlas_core.pa_05b_command_error(request,v_result ->> 'error_code',
      'The supplier allocation could not be accepted.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_response,false);
  end if;
  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version,command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary)
  values('SchoolCateringSupplierAllocationSaved','PROCUREMENT','AllocationFamily',
    atlas_core.pa_05b_safe_uuid(v_result ->> 'family_id'),(v_result ->> 'family_version')::bigint,
    v_receipt,atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,transaction_timestamp(),v_result)
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,reason_code,
    reason_note,after_summary,source_interface,occurred_at)
  values('SchoolCateringSupplierAllocationSaved','PROCUREMENT','AllocationFamily',
    atlas_core.pa_05b_safe_uuid(v_result ->> 'family_id'),(v_result ->> 'family_version')::bigint,
    v_receipt,atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,request ->> 'reason_code',
    request ->> 'reason_note',v_result,'atlas_api',transaction_timestamp())
  returning audit_event_id into v_audit;
  v_response := jsonb_build_object('success',true,'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
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

create function atlas_api.confirm_school_catering_supplier_recommendations(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_name constant text := 'confirm_school_catering_supplier_recommendations';
  v_actor jsonb; v_actor_id uuid; v_begin jsonb; v_receipt uuid;
  v_candidate jsonb; v_result jsonb; v_service_date date;
  v_location_id uuid; v_ingredient_id uuid; v_unit_id uuid; v_expected_version bigint;
  v_confirmed jsonb := '[]'::jsonb; v_skipped jsonb := '[]'::jsonb;
  v_event uuid; v_audit uuid; v_response jsonb;
begin
  if request ->> 'contract_version' is distinct from 'SCHOOL-CATERING-PROCUREMENT.v1'
     or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
     or coalesce(atlas_core.pa_05b_safe_bigint(request ->> 'expected_version'),0) <= 0
     or request ->> 'reason_code' is distinct from 'SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED'
     or jsonb_typeof(request #> '{payload,candidates}') is distinct from 'array'
     or jsonb_array_length(request #> '{payload,candidates}')=0
     or (request -> 'payload') - array['candidates'] <> '{}'::jsonb then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'The explicit recommendation candidate list is invalid.','PROCUREMENT',v_name);
  end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_response := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_response is not null and v_response ->> 'error_code'<>'SCOPE_DENIED' then
    return v_response;
  end if;
  -- Scope the complete explicit set before opening the command receipt. Invalid
  -- candidates remain safe skips, while any valid out-of-scope candidate fails
  -- the bulk command atomically.
  for v_candidate in select value from pg_catalog.jsonb_array_elements(request #> '{payload,candidates}') loop
    if pg_catalog.jsonb_typeof(v_candidate)='object'
       and v_candidate - array['service_date','delivery_location_id','ingredient_id','unit_id',
         'expected_family_version','expected_source_fingerprint']='{}'::jsonb
       and atlas_core.pa_05b_safe_uuid(v_candidate ->> 'delivery_location_id') is not null
       and not atlas_core.school_catering_actor_has_scope(v_actor_id,null,null,
         atlas_core.pa_05b_safe_uuid(v_candidate ->> 'delivery_location_id')) then
      return coalesce(v_response,atlas_core.pa_05b_command_error(request,'SCOPE_DENIED',
        'The actor is outside one or more requested school-catering scopes.',
        'PROCUREMENT',v_name));
    end if;
  end loop;
  v_begin := atlas_core.pa_05b_begin_command(request,v_actor_id,v_name,'PROCUREMENT',
    'school-catering-recommendations:' || (request ->> 'command_id'));
  if v_begin ->> 'status' in ('REPLAY','ERROR') then return v_begin -> 'response'; end if;
  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  for v_candidate in select value from pg_catalog.jsonb_array_elements(request #> '{payload,candidates}') loop
    v_location_id := atlas_core.pa_05b_safe_uuid(v_candidate ->> 'delivery_location_id');
    v_ingredient_id := atlas_core.pa_05b_safe_uuid(v_candidate ->> 'ingredient_id');
    v_unit_id := atlas_core.pa_05b_safe_uuid(v_candidate ->> 'unit_id');
    v_expected_version := atlas_core.pa_05b_safe_bigint(v_candidate ->> 'expected_family_version');
    begin
      v_service_date := nullif(pg_catalog.btrim(v_candidate ->> 'service_date'),'')::date;
    exception when invalid_datetime_format or datetime_field_overflow then
      v_service_date := null;
    end;
    if pg_catalog.jsonb_typeof(v_candidate)<>'object'
       or v_candidate - array['service_date','delivery_location_id','ingredient_id','unit_id',
          'expected_family_version','expected_source_fingerprint'] <> '{}'::jsonb
       or v_service_date is null or v_location_id is null or v_ingredient_id is null
       or v_unit_id is null or v_expected_version is null
       or v_candidate ->> 'expected_source_fingerprint' is null then
      v_skipped := v_skipped || jsonb_build_array(v_candidate || jsonb_build_object('reason','INVALID_CANDIDATE'));
      continue;
    end if;
    v_result := atlas_core.school_catering_persist_allocation(v_actor_id,
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),v_expected_version,v_candidate,
      '[]'::jsonb,'PRIORITY_RECOMMENDATION');
    if (v_result ->> 'success')::boolean then
      v_confirmed := v_confirmed || jsonb_build_array(v_result);
    else
      v_skipped := v_skipped || jsonb_build_array(v_candidate || jsonb_build_object(
        'reason',v_result ->> 'error_code'));
    end if;
  end loop;
  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version,command_receipt_id,command_id,correlation_id,actor_id,occurred_at,payload_summary)
  values('SchoolCateringSupplierRecommendationsConfirmed','PROCUREMENT','AllocationFamilySet',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),1,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,transaction_timestamp(),jsonb_build_object('confirmed',v_confirmed,'skipped',v_skipped))
  returning domain_event_id into v_event;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,aggregate_id,
    aggregate_version_after,command_receipt_id,command_id,correlation_id,actor_id,reason_code,
    reason_note,after_summary,source_interface,occurred_at)
  values('SchoolCateringSupplierRecommendationsConfirmed','PROCUREMENT','AllocationFamilySet',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),1,v_receipt,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    v_actor_id,request ->> 'reason_code',request ->> 'reason_note',
    jsonb_build_object('confirmed',v_confirmed,'skipped',v_skipped),'atlas_api',transaction_timestamp())
  returning audit_event_id into v_audit;
  v_response := jsonb_build_object('success',true,'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'command_id',request ->> 'command_id','correlation_id',request ->> 'correlation_id',
    'idempotency_status','COMPLETED','confirmed',v_confirmed,'skipped',v_skipped,
    'emitted_event_ids',jsonb_build_array(v_event),'audit_event_ids',jsonb_build_array(v_audit),
    'safe_operator_message','Đã xác nhận các đề xuất còn hiện hành.','warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt,v_response,true);
exception when serialization_failure or deadlock_detected then
  return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
    'The command could not acquire a safe transaction state. Retry the exact request.',
    'PROCUREMENT',v_name,true);
when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
    'The supplier recommendations could not be confirmed safely.','PROCUREMENT',v_name);
end;
$$;

create function atlas_api.get_school_catering_procurement_workbench(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_name constant text := 'get_school_catering_procurement_workbench';
  v_actor jsonb; v_actor_id uuid; v_error jsonb;
  v_start date := atlas_core.pa_05d_safe_date(request #>> '{payload,date_start}');
  v_end date := atlas_core.pa_05d_safe_date(request #>> '{payload,date_end}');
  v_search text := nullif(pg_catalog.btrim(request #>> '{payload,search}'),'');
  v_rows jsonb;
begin
  if request ->> 'contract_version' is distinct from 'SCHOOL-CATERING-PROCUREMENT.v1'
     or v_start is null or v_end is null or v_end < v_start or v_end-v_start > 31
     or (request -> 'payload') - array['date_start','date_end','school_ids','states','search'] <> '{}'::jsonb then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED',
      'Provide a valid bounded school-catering Procurement scope.','PROCUREMENT',v_name);
  end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor ? 'error' then return v_actor -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id');
  v_error := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.read','PROCUREMENT',v_name,null,null,null);
  if v_error is not null and v_error ->> 'error_code'<>'SCOPE_DENIED' then
    return v_error;
  end if;
  with keys as (
    select distinct lr.service_date,lr.delivery_location_id,lr.ingredient_id,lr.unit_id
    from atlas_planning.purchase_handoff_batches b
    join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_batch_id=b.purchase_handoff_batch_id
      and hr.is_current and hr.revision_status='RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_handoff_line_revisions lr on lr.purchase_handoff_revision_id=hr.purchase_handoff_revision_id
    join atlas_planning.purchase_demand_references d on d.purchase_handoff_line_revision_id=lr.purchase_handoff_line_revision_id
      and d.source_kind='NEED_GENERATION'
    where b.handoff_status='RELEASED_TO_PROCUREMENT' and lr.service_date between v_start and v_end
      and atlas_core.school_catering_actor_has_scope(v_actor_id,null,null,lr.delivery_location_id)
  ), data as (
    select k.*,p.projection,f.family_id,f.version,r.family_revision_id,r.source_fingerprint accepted_fingerprint,
      r.family_quantity accepted_quantity,r.decision_origin,
      coalesce((select jsonb_agg(jsonb_build_object('supplier_split_id',s.supplier_split_id,
        'supplier_id',s.supplier_id,'supplier_name',sp.supplier_name,'allocated_quantity',s.allocated_quantity,
        'split_ratio',s.split_ratio) order by sp.supplier_name,s.supplier_id)
        from atlas_procurement.school_catering_allocation_supplier_splits s
        join atlas_admin.suppliers sp on sp.supplier_id=s.supplier_id
        where s.family_revision_id=r.family_revision_id),'[]'::jsonb) splits,
      coalesce((select jsonb_agg(jsonb_build_object('supplier_id',e.supplier_id,
        'supplier_name',sp.supplier_name,'priority',e.priority) order by e.priority,sp.supplier_name,e.supplier_id)
        from atlas_admin.supplier_eligibilities e join atlas_admin.suppliers sp on sp.supplier_id=e.supplier_id
        where e.ingredient_id=k.ingredient_id and e.eligibility_status='ACTIVE' and sp.supplier_status='ACTIVE'
          and e.effective_from<=k.service_date and (e.effective_to is null or e.effective_to>k.service_date)),'[]'::jsonb) eligible
    from keys k cross join lateral (select atlas_core.school_catering_family_projection(
      k.service_date,k.delivery_location_id,k.ingredient_id,k.unit_id) projection) p
    left join atlas_procurement.school_catering_allocation_families f
      on f.service_date=k.service_date and f.delivery_location_id=k.delivery_location_id
      and f.ingredient_id=k.ingredient_id and f.unit_id=k.unit_id
    left join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current
  ), evidence as (
    select d.*,pg_catalog.jsonb_array_length(d.eligible) eligible_count,
      (select pg_catalog.count(*)::integer
       from pg_catalog.jsonb_array_elements(d.eligible) e
       where (e ->> 'priority')::integer=(select pg_catalog.min((x ->> 'priority')::integer)
         from pg_catalog.jsonb_array_elements(d.eligible) x)) best_priority_count
    from data d
  ), shaped as (
    select d.*,dl.location_name,sc.school_id,sc.school_name,i.ingredient_name,u.unit_code,
      case
        when d.family_revision_id is null then 'UNALLOCATED'
        when d.accepted_fingerprint=d.projection ->> 'source_fingerprint' and not exists(
          select 1 from jsonb_array_elements(d.splits) s where not exists(
            select 1 from jsonb_array_elements(d.eligible) e where e ->> 'supplier_id'=s ->> 'supplier_id')) then 'BALANCED'
        when d.accepted_fingerprint<>d.projection ->> 'source_fingerprint' and not exists(
          select 1 from jsonb_array_elements(d.splits) s where not exists(
            select 1 from jsonb_array_elements(d.eligible) e where e ->> 'supplier_id'=s ->> 'supplier_id')) then 'STALE_REBALANCE_AVAILABLE'
        when d.accepted_fingerprint<>d.projection ->> 'source_fingerprint' then 'NEEDS_REALLOCATION'
        else 'BLOCKED'
      end state
    from evidence d join atlas_admin.delivery_locations dl on dl.delivery_location_id=d.delivery_location_id
    left join atlas_admin.schools sc on sc.default_delivery_location_id=dl.delivery_location_id
    join atlas_admin.ingredients i on i.ingredient_id=d.ingredient_id
    join atlas_admin.units u on u.unit_id=d.unit_id
  ), filtered as (
    select s.* from shaped s
    where (jsonb_array_length(coalesce(request #> '{payload,school_ids}','[]'::jsonb))=0
      or s.school_id::text in (select jsonb_array_elements_text(request #> '{payload,school_ids}')))
      and (jsonb_array_length(coalesce(request #> '{payload,states}','[]'::jsonb))=0
        or s.state in (select jsonb_array_elements_text(request #> '{payload,states}')))
      and (v_search is null
        or s.location_name ilike '%' || v_search || '%'
        or coalesce(s.school_name,'') ilike '%' || v_search || '%'
        or s.ingredient_name ilike '%' || v_search || '%'
        or exists(
          select 1
          from atlas_admin.supplier_eligibilities eligibility
          join atlas_admin.suppliers supplier on supplier.supplier_id=eligibility.supplier_id
          where eligibility.ingredient_id=s.ingredient_id
            and eligibility.eligibility_status='ACTIVE'
            and eligibility.effective_from<=s.service_date
            and (eligibility.effective_to is null or eligibility.effective_to>s.service_date)
            and supplier.supplier_status='ACTIVE'
            and supplier.supplier_name ilike '%' || v_search || '%')
        or exists(
          select 1
          from atlas_procurement.school_catering_allocation_supplier_splits split
          join atlas_admin.suppliers supplier on supplier.supplier_id=split.supplier_id
          where split.family_revision_id=s.family_revision_id
            and supplier.supplier_name ilike '%' || v_search || '%'))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'family',jsonb_build_object('service_date',d.service_date,'delivery_location_id',d.delivery_location_id,
      'ingredient_id',d.ingredient_id,'unit_id',d.unit_id,'family_id',d.family_id,'version',coalesce(d.version,0),
      'source_fingerprint',d.projection ->> 'source_fingerprint'),
    'service_date',d.service_date,'delivery_location_id',d.delivery_location_id,'location_name',d.location_name,
    'school_id',d.school_id,'school_name',d.school_name,'ingredient_id',d.ingredient_id,
    'ingredient_name',d.ingredient_name,'unit_id',d.unit_id,'unit_code',d.unit_code,
    'family_quantity',d.projection -> 'family_quantity','contributions',d.projection -> 'contributions',
    'contribution_count',jsonb_array_length(d.projection -> 'contributions'),'splits',d.splits,
    'eligible_suppliers',d.eligible,'state',d.state,
    'recommendation',case when d.family_revision_id is null and d.best_priority_count=1
      then jsonb_build_object('supplier_id',(select e ->> 'supplier_id' from jsonb_array_elements(d.eligible) e
        order by (e ->> 'priority')::int limit 1),'allocated_quantity',d.projection -> 'family_quantity','split_ratio',1)
      else null end,
    'rebalance_proposal',case when d.state='STALE_REBALANCE_AVAILABLE' then (
      select jsonb_agg(jsonb_build_object('supplier_id',q.supplier_id,
        'allocated_quantity',case when q.rn=q.cnt then q.family_quantity-q.prior_rounded_total
          else q.rounded_quantity end,'split_ratio',q.split_ratio) order by q.supplier_id)
      from (
        select x.supplier_id,x.split_ratio,x.family_quantity,x.rounded_quantity,x.rn,x.cnt,
          coalesce(sum(x.rounded_quantity) filter(where x.rn<x.cnt) over(),0::numeric) prior_rounded_total
        from (
          select s ->> 'supplier_id' supplier_id,(s ->> 'split_ratio')::numeric split_ratio,
            (d.projection ->> 'family_quantity')::numeric family_quantity,
            round((d.projection ->> 'family_quantity')::numeric*(s ->> 'split_ratio')::numeric,6) rounded_quantity,
            row_number() over(order by s ->> 'supplier_id') rn,
            count(*) over() cnt
          from jsonb_array_elements(d.splits) s
        ) x
      ) q
    ) else null end,
    'allowed_actions',jsonb_build_object('save_allocation',d.eligible_count>0,
      'confirm_recommendation',d.family_revision_id is null and d.best_priority_count=1),
    'disabled_reasons',case
      when d.eligible_count=0 then jsonb_build_array('NO_ELIGIBLE_SUPPLIER')
      when d.family_revision_id is null and d.best_priority_count=0
        then jsonb_build_array('NO_PRIORITIZED_SUPPLIER')
      when d.family_revision_id is null and d.best_priority_count>1
        then jsonb_build_array('AMBIGUOUS_SUPPLIER_PRIORITY')
      when d.family_revision_id is not null then jsonb_build_array('ALLOCATION_ALREADY_EXISTS')
      else '[]'::jsonb end,
    'blockers',case
      when d.eligible_count=0 then jsonb_build_array('NO_ELIGIBLE_SUPPLIER')
      when d.family_revision_id is null and d.best_priority_count=0
        then jsonb_build_array('NO_PRIORITIZED_SUPPLIER')
      when d.family_revision_id is null and d.best_priority_count>1
        then jsonb_build_array('AMBIGUOUS_SUPPLIER_PRIORITY')
      else '[]'::jsonb end,'warnings','[]'::jsonb)
    order by d.service_date,d.location_name,d.ingredient_name,d.unit_id),'[]'::jsonb) into v_rows
  from filtered d;
  return jsonb_build_object('success',true,'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'date_start',v_start,'date_end',v_end,'rows',v_rows,'warnings','[]'::jsonb,'blockers','[]'::jsonb);
exception when others then
  return atlas_core.pa_05b_command_error(request,'INTERNAL_READ_FAILURE',
    'The school-catering Procurement workbench could not be read safely.','PROCUREMENT',v_name);
end;
$$;
reset role;
set role atlas_owner;

alter table atlas_planning.purchase_demand_references
  add column source_kind text not null default 'WHOLESALE';
alter table atlas_planning.purchase_demand_references
  alter column wholesale_order_line_revision_id drop not null;
alter table atlas_planning.purchase_demand_references
  add constraint purchase_demand_references_source_kind_check
    check (source_kind in ('WHOLESALE', 'NEED_GENERATION')),
  add constraint purchase_demand_references_source_shape_check
    check (
      (source_kind = 'WHOLESALE' and wholesale_order_line_revision_id is not null)
      or (source_kind = 'NEED_GENERATION' and wholesale_order_line_revision_id is null)
    );

create table atlas_procurement.school_catering_allocation_families (
  family_id uuid primary key default gen_random_uuid(),
  service_date date not null,
  delivery_location_id uuid not null references atlas_admin.delivery_locations on delete restrict,
  ingredient_id uuid not null references atlas_admin.ingredients on delete restrict,
  unit_id uuid not null references atlas_admin.units on delete restrict,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint school_catering_allocation_families_key unique
    (service_date,delivery_location_id,ingredient_id,unit_id),
  constraint school_catering_allocation_families_version_check check(version > 0)
);
create table atlas_procurement.school_catering_allocation_family_revisions (
  family_revision_id uuid primary key default gen_random_uuid(),
  family_id uuid not null references atlas_procurement.school_catering_allocation_families on delete restrict,
  revision_number integer not null,
  is_current boolean not null default true,
  predecessor_revision_id uuid references atlas_procurement.school_catering_allocation_family_revisions on delete restrict,
  source_purchase_handoff_revision_id uuid not null references atlas_planning.purchase_handoff_revisions on delete restrict,
  source_fingerprint text not null,
  family_quantity numeric(20,6) not null,
  unit_id uuid not null references atlas_admin.units on delete restrict,
  accepted_by_actor_id uuid not null references atlas_core.actors on delete restrict,
  accepted_at timestamptz not null default transaction_timestamp(),
  command_id uuid not null,
  decision_origin text not null,
  constraint school_catering_allocation_family_revisions_number_check check(revision_number > 0),
  constraint school_catering_allocation_family_revisions_quantity_check check(family_quantity > 0),
  constraint school_catering_allocation_family_revisions_origin_check
    check(decision_origin in ('MANUAL','PRIORITY_RECOMMENDATION','REBALANCED')),
  constraint school_catering_allocation_family_revisions_key unique(family_id,revision_number),
  constraint school_catering_allocation_family_revisions_predecessor_check
    check(predecessor_revision_id is null or predecessor_revision_id <> family_revision_id)
);
create unique index school_catering_allocation_family_revisions_current_key
  on atlas_procurement.school_catering_allocation_family_revisions(family_id)
  where is_current = true;
create table atlas_procurement.school_catering_allocation_family_contributions (
  family_contribution_id uuid primary key default gen_random_uuid(),
  family_revision_id uuid not null references atlas_procurement.school_catering_allocation_family_revisions on delete restrict,
  purchase_handoff_line_revision_id uuid not null references atlas_planning.purchase_handoff_line_revisions on delete restrict,
  contribution_quantity numeric(20,6) not null,
  constraint school_catering_allocation_family_contributions_key
    unique(family_revision_id,purchase_handoff_line_revision_id),
  constraint school_catering_allocation_family_contributions_quantity_check
    check(contribution_quantity > 0)
);
create table atlas_procurement.school_catering_allocation_supplier_splits (
  supplier_split_id uuid primary key default gen_random_uuid(),
  family_revision_id uuid not null references atlas_procurement.school_catering_allocation_family_revisions on delete restrict,
  supplier_id uuid not null references atlas_admin.suppliers on delete restrict,
  allocated_quantity numeric(20,6) not null,
  split_ratio numeric(20,12) not null,
  decision_origin text not null,
  constraint school_catering_allocation_supplier_splits_key unique(family_revision_id,supplier_id),
  constraint school_catering_allocation_supplier_splits_quantity_check check(allocated_quantity > 0),
  constraint school_catering_allocation_supplier_splits_ratio_check check(split_ratio > 0 and split_ratio <= 1),
  constraint school_catering_allocation_supplier_splits_origin_check
    check(decision_origin in ('MANUAL','PRIORITY_RECOMMENDATION','REBALANCED'))
);

alter table atlas_procurement.school_catering_allocation_families enable row level security;
alter table atlas_procurement.school_catering_allocation_families force row level security;
alter table atlas_procurement.school_catering_allocation_family_revisions enable row level security;
alter table atlas_procurement.school_catering_allocation_family_revisions force row level security;
alter table atlas_procurement.school_catering_allocation_family_contributions enable row level security;
alter table atlas_procurement.school_catering_allocation_family_contributions force row level security;
alter table atlas_procurement.school_catering_allocation_supplier_splits enable row level security;
alter table atlas_procurement.school_catering_allocation_supplier_splits force row level security;

reset role;
insert into atlas_core.capabilities(capability_id,capability_code,capability_name,owning_domain,capability_status)
values
  ('02f0e3ac-a7bb-4f90-a2ee-dba59b0b2025','procurement.school_catering.read',
   'Read school-catering Procurement workbench','PROCUREMENT','ACTIVE'),
  ('82ff6cc9-4c0a-4c43-b74a-2a8cb2662026','procurement.school_catering.write',
   'Maintain school-catering supplier allocation','PROCUREMENT','ACTIVE');
set role atlas_owner;

create function atlas_core.school_catering_immutable_revision_guard()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_table_name = 'school_catering_allocation_family_revisions'
     and tg_op = 'UPDATE' and old.is_current and not new.is_current
     and to_jsonb(old) - 'is_current' = to_jsonb(new) - 'is_current' then
    return new;
  end if;
  raise exception using errcode='23514', message='School-catering allocation history is immutable.';
end;
$$;
create trigger school_catering_family_revisions_immutable
  before update or delete on atlas_procurement.school_catering_allocation_family_revisions
  for each row execute function atlas_core.school_catering_immutable_revision_guard();
create trigger school_catering_family_contributions_immutable
  before update or delete on atlas_procurement.school_catering_allocation_family_contributions
  for each row execute function atlas_core.school_catering_immutable_revision_guard();
create trigger school_catering_supplier_splits_immutable
  before update or delete on atlas_procurement.school_catering_allocation_supplier_splits
  for each row execute function atlas_core.school_catering_immutable_revision_guard();

create function atlas_core.school_catering_family_projection(
  p_service_date date,p_delivery_location_id uuid,p_ingredient_id uuid,p_unit_id uuid
) returns jsonb language sql stable security invoker set search_path='' as $$
  with contributions as (
    select lr.purchase_handoff_line_revision_id,lr.purchase_handoff_revision_id,
      lr.handoff_quantity,lr.ingredient_id,lr.unit_id,lr.service_date,lr.delivery_location_id
    from atlas_planning.purchase_handoff_batches b
    join atlas_planning.purchase_handoff_revisions r
      on r.purchase_handoff_batch_id=b.purchase_handoff_batch_id
     and r.is_current and r.revision_status='RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_handoff_line_revisions lr
      on lr.purchase_handoff_revision_id=r.purchase_handoff_revision_id
    join atlas_planning.purchase_demand_references d
      on d.purchase_handoff_line_revision_id=lr.purchase_handoff_line_revision_id
     and d.source_kind='NEED_GENERATION'
    where b.handoff_status='RELEASED_TO_PROCUREMENT'
      and lr.service_date=p_service_date and lr.delivery_location_id=p_delivery_location_id
      and lr.ingredient_id=p_ingredient_id and lr.unit_id=p_unit_id
  ), shaped as (
    select coalesce(sum(handoff_quantity),0)::numeric(20,6) family_quantity,
      (array_agg(purchase_handoff_revision_id order by purchase_handoff_revision_id))[1]
        source_purchase_handoff_revision_id,
      coalesce(jsonb_agg(jsonb_build_object(
        'purchase_handoff_line_revision_id',purchase_handoff_line_revision_id,
        'purchase_handoff_revision_id',purchase_handoff_revision_id,
        'contribution_quantity',handoff_quantity)
        order by purchase_handoff_line_revision_id),'[]'::jsonb) contributions
    from contributions
  )
  select jsonb_build_object('service_date',p_service_date,
    'delivery_location_id',p_delivery_location_id,'ingredient_id',p_ingredient_id,
    'unit_id',p_unit_id,'family_quantity',family_quantity,
    'source_purchase_handoff_revision_id',source_purchase_handoff_revision_id,
    'contributions',contributions,'source_fingerprint',
      encode(extensions.digest(convert_to(jsonb_build_object(
        'service_date',p_service_date,'delivery_location_id',p_delivery_location_id,
        'ingredient_id',p_ingredient_id,'unit_id',p_unit_id,
        'contributions',contributions)::text,'UTF8'),'sha256'),'hex'))
  from shaped;
$$;

grant execute on function atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)
  to atlas_procurement_command_runtime, atlas_read_runtime;

grant select on atlas_procurement.school_catering_allocation_families,
  atlas_procurement.school_catering_allocation_family_revisions,
  atlas_procurement.school_catering_allocation_family_contributions,
  atlas_procurement.school_catering_allocation_supplier_splits
to atlas_procurement_command_runtime,atlas_read_runtime;
grant insert,update on atlas_procurement.school_catering_allocation_families
  to atlas_procurement_command_runtime;
grant insert,update on atlas_procurement.school_catering_allocation_family_revisions
  to atlas_procurement_command_runtime;
grant insert on atlas_procurement.school_catering_allocation_family_contributions,
  atlas_procurement.school_catering_allocation_supplier_splits
to atlas_procurement_command_runtime;

create policy school_catering_family_command_select
  on atlas_procurement.school_catering_allocation_families for select
  to atlas_procurement_command_runtime using(true);
create policy school_catering_family_command_insert
  on atlas_procurement.school_catering_allocation_families for insert
  to atlas_procurement_command_runtime with check(true);
create policy school_catering_family_command_update
  on atlas_procurement.school_catering_allocation_families for update
  to atlas_procurement_command_runtime using(true) with check(true);
create policy school_catering_revision_command_select
  on atlas_procurement.school_catering_allocation_family_revisions for select
  to atlas_procurement_command_runtime using(true);
create policy school_catering_revision_command_insert
  on atlas_procurement.school_catering_allocation_family_revisions for insert
  to atlas_procurement_command_runtime with check(true);
create policy school_catering_revision_command_update
  on atlas_procurement.school_catering_allocation_family_revisions for update
  to atlas_procurement_command_runtime using(true) with check(not is_current);
create policy school_catering_contribution_command_select
  on atlas_procurement.school_catering_allocation_family_contributions for select
  to atlas_procurement_command_runtime using(true);
create policy school_catering_contribution_command_insert
  on atlas_procurement.school_catering_allocation_family_contributions for insert
  to atlas_procurement_command_runtime with check(true);
create policy school_catering_split_command_select
  on atlas_procurement.school_catering_allocation_supplier_splits for select
  to atlas_procurement_command_runtime using(true);
create policy school_catering_split_command_insert
  on atlas_procurement.school_catering_allocation_supplier_splits for insert
  to atlas_procurement_command_runtime with check(true);
create policy school_catering_family_read_select
  on atlas_procurement.school_catering_allocation_families for select
  to atlas_read_runtime using(true);
create policy school_catering_revision_read_select
  on atlas_procurement.school_catering_allocation_family_revisions for select
  to atlas_read_runtime using(true);
create policy school_catering_contribution_read_select
  on atlas_procurement.school_catering_allocation_family_contributions for select
  to atlas_read_runtime using(true);
create policy school_catering_split_read_select
  on atlas_procurement.school_catering_allocation_supplier_splits for select
  to atlas_read_runtime using(true);

grant select on atlas_admin.suppliers,atlas_admin.supplier_eligibilities,
  atlas_admin.delivery_locations,atlas_admin.schools,atlas_admin.ingredients,atlas_admin.units,
  atlas_planning.purchase_handoff_batches,atlas_planning.purchase_handoff_revisions,
  atlas_planning.purchase_handoff_line_revisions,atlas_planning.purchase_demand_references
to atlas_procurement_command_runtime,atlas_read_runtime;
create policy school_catering_procurement_supplier_select on atlas_admin.suppliers
  for select to atlas_procurement_command_runtime using(true);
create policy school_catering_procurement_eligibility_select on atlas_admin.supplier_eligibilities
  for select to atlas_procurement_command_runtime using(true);
create policy school_catering_read_supplier_select on atlas_admin.suppliers
  for select to atlas_read_runtime using(true);
create policy school_catering_read_eligibility_select on atlas_admin.supplier_eligibilities
  for select to atlas_read_runtime using(true);
create policy school_catering_read_handoff_batch_select on atlas_planning.purchase_handoff_batches
  for select to atlas_read_runtime using(true);
create policy school_catering_read_handoff_revision_select on atlas_planning.purchase_handoff_revisions
  for select to atlas_read_runtime using(true);
create policy school_catering_read_handoff_line_revision_select on atlas_planning.purchase_handoff_line_revisions
  for select to atlas_read_runtime using(true);
create policy school_catering_read_demand_reference_select on atlas_planning.purchase_demand_references
  for select to atlas_read_runtime using(true);

grant select on atlas_planning.confirmed_need_releases
  to atlas_planning_command_runtime;
create policy school_catering_handoff_release_select
  on atlas_planning.confirmed_need_releases for select
  to atlas_planning_command_runtime using (true);
create policy school_catering_handoff_batch_update
  on atlas_planning.purchase_handoff_batches for update
  to atlas_planning_command_runtime using (true) with check (true);
create policy school_catering_handoff_revision_update
  on atlas_planning.purchase_handoff_revisions for update
  to atlas_planning_command_runtime using (true) with check (true);

grant create on schema atlas_api to atlas_planning_command_runtime;
reset role;
set role atlas_planning_command_runtime;

create function atlas_api.release_school_catering_purchase_handoff(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_command_name constant text := 'release_school_catering_purchase_handoff';
  v_payload jsonb := request -> 'payload';
  v_error jsonb;
  v_actor_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'confirmed_need_batch_id');
  v_batch record;
  v_handoff record;
  v_prior_revision_id uuid;
  v_revision_number integer;
  v_handoff_revision_id uuid;
  v_handoff_line_id uuid;
  v_handoff_line_revision_id uuid;
  v_reference_id uuid;
  v_line record;
  v_line_count integer;
  v_valid_count integer;
  v_line_ids jsonb := '[]'::jsonb;
  v_line_revision_ids jsonb := '[]'::jsonb;
  v_reference_ids jsonb := '[]'::jsonb;
  v_event_id uuid;
  v_audit_id uuid;
  v_response jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object'
     or request ->> 'contract_version' is distinct from 'SCHOOL-CATERING-HANDOFF.v1'
     or atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null
     or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
     or pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0
     or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at') is null
     or atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at') > pg_catalog.transaction_timestamp()
     or request ->> 'reason_code' is distinct from 'SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED'
     or not (request ? 'reason_note')
     or pg_catalog.jsonb_typeof(v_payload) is distinct from 'object'
     or v_batch_id is null
     or v_payload - array['confirmed_need_batch_id'] <> '{}'::jsonb
     or request - array['contract_version','command_id','correlation_id','idempotency_key',
       'expected_version','requested_by_auth_subject','requested_at','reason_code',
       'reason_note','payload'] <> '{}'::jsonb then
    return atlas_core.pa_05b_command_error(request, 'VALIDATION_FAILED',
      'The school-catering Purchase Handoff request is invalid.',
      'PLANNING', v_command_name);
  end if;

  v_actor_context := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_command_name);
  if v_actor_context ? 'error' then return v_actor_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');

  select b.* into v_batch
  from atlas_planning.confirmed_need_batches b
  where b.confirmed_need_batch_id = v_batch_id;
  if not found or v_batch.source_kind <> 'NEED_GENERATION' then
    return atlas_core.pa_05b_command_error(request, 'NOT_FOUND',
      'The released school-catering Confirmed Need was not found.',
      'PLANNING', v_command_name);
  end if;

  v_error := atlas_core.pa_05b_authorize_actor(request, v_actor_id,
    'confirmed_need_release.release', 'PLANNING', v_command_name,
    null, null, null);
  if v_error is not null and v_error ->> 'error_code'<>'SCOPE_DENIED' then
    return v_error;
  end if;
  if exists(
    select 1 from atlas_planning.confirmed_need_line_revisions line
    where line.confirmed_need_batch_id=v_batch_id and line.is_current
      and not atlas_core.school_catering_actor_has_scope(v_actor_id,
        line.customer_id,line.school_id,line.delivery_location_id)
  ) then
    return coalesce(v_error,atlas_core.pa_05b_command_error(request,'SCOPE_DENIED',
      'The actor is outside one or more school-catering Handoff scopes.',
      'PLANNING',v_command_name));
  end if;

  v_begin := atlas_core.pa_05b_begin_command(request, v_actor_id,
    v_command_name, 'PLANNING', 'confirmed-need-batch:' || v_batch_id::text);
  if v_begin ->> 'status' in ('REPLAY','ERROR') then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  perform 1 from atlas_planning.confirmed_need_batches b
    where b.confirmed_need_batch_id = v_batch_id for update;
  perform 1 from atlas_planning.confirmed_need_lines l
    where l.confirmed_need_batch_id = v_batch_id
    order by l.confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions r
    where r.confirmed_need_batch_id = v_batch_id and r.is_current
    order by r.confirmed_need_line_revision_id for key share;
  perform 1 from atlas_planning.purchase_handoff_batches h
    where h.confirmed_need_batch_id = v_batch_id for update;
  perform 1 from atlas_planning.purchase_handoff_revisions r
    where r.purchase_handoff_batch_id in (
      select h.purchase_handoff_batch_id from atlas_planning.purchase_handoff_batches h
      where h.confirmed_need_batch_id = v_batch_id)
    order by r.revision_number for update;

  select b.* into v_batch from atlas_planning.confirmed_need_batches b
    where b.confirmed_need_batch_id = v_batch_id;
  if v_batch.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.pa_05b_command_error(request, 'STALE_VERSION',
      'The Confirmed Need changed. Refresh before releasing its Handoff.',
      'PLANNING', v_command_name, false, '[]'::jsonb,
      pg_catalog.jsonb_build_array(v_batch_id), v_batch.version);
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  select count(*)::integer into v_line_count
  from atlas_planning.confirmed_need_lines l
  where l.confirmed_need_batch_id = v_batch_id;
  select count(*)::integer into v_valid_count
  from atlas_planning.confirmed_need_lines l
  join atlas_planning.confirmed_need_line_revisions r
    on r.confirmed_need_line_id=l.confirmed_need_line_id
   and r.confirmed_need_batch_id=v_batch_id and r.is_current
   and r.source_kind='NEED_GENERATION' and r.revision_status='RELEASED'
  join atlas_planning.confirmed_need_snapshot_lines sl
    on sl.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id
   and sl.confirmed_need_approval_snapshot_id=v_batch.current_confirmed_need_approval_snapshot_id
  join atlas_planning.confirmed_need_approval_snapshots s
    on s.confirmed_need_approval_snapshot_id=sl.confirmed_need_approval_snapshot_id
   and s.source_kind='NEED_GENERATION'
  join atlas_planning.confirmed_need_releases cr
    on cr.confirmed_need_release_id=v_batch.current_confirmed_need_release_id
   and cr.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
   and cr.source_kind='NEED_GENERATION'
  where l.confirmed_need_batch_id=v_batch_id and l.source_kind='NEED_GENERATION'
    and r.confirmed_quantity > 0 and sl.approved_quantity=r.confirmed_quantity
    and sl.ingredient_id=r.ingredient_id and sl.unit_id=r.unit_id
    and r.service_date between v_batch.period_start and v_batch.period_end
    and r.customer_id is not null and r.school_id is not null
    and r.delivery_location_id is not null;

  select h.* into v_handoff from atlas_planning.purchase_handoff_batches h
    where h.confirmed_need_batch_id=v_batch_id;
  if v_batch.batch_status <> 'RELEASED_FOR_PURCHASE_HANDOFF'
     or v_batch.current_confirmed_need_approval_snapshot_id is null
     or v_batch.current_confirmed_need_release_id is null
     or v_line_count < 1 or v_valid_count <> v_line_count
     or (v_handoff.purchase_handoff_batch_id is not null
         and v_handoff.handoff_status <> 'INVALIDATED') then
    v_error := atlas_core.pa_05b_command_error(request, 'INVARIANT_VIOLATION',
      'Purchase Handoff release requires one complete current released school-catering snapshot.',
      'PLANNING', v_command_name);
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if v_handoff.purchase_handoff_batch_id is null then
    insert into atlas_planning.purchase_handoff_batches(
      confirmed_need_batch_id,period_start,period_end,handoff_status,version,created_by_actor_id)
    values(v_batch_id,v_batch.period_start,v_batch.period_end,
      'RELEASED_TO_PROCUREMENT',1,v_actor_id)
    returning * into v_handoff;
    v_revision_number := 1;
  else
    select r.revision_number,r.purchase_handoff_revision_id
      into v_revision_number,v_prior_revision_id
    from atlas_planning.purchase_handoff_revisions r
    where r.purchase_handoff_batch_id=v_handoff.purchase_handoff_batch_id
    order by r.revision_number desc limit 1;
    v_revision_number := v_revision_number + 1;
    update atlas_planning.purchase_handoff_batches
      set handoff_status='RELEASED_TO_PROCUREMENT', version=version+1,
          period_start=v_batch.period_start, period_end=v_batch.period_end,
          updated_at=pg_catalog.transaction_timestamp()
      where purchase_handoff_batch_id=v_handoff.purchase_handoff_batch_id
      returning * into v_handoff;
  end if;

  insert into atlas_planning.purchase_handoff_revisions(
    purchase_handoff_batch_id,revision_number,revision_kind,revision_status,
    is_current,predecessor_revision_id,released_by_actor_id,released_at,reason_note,command_id)
  values(v_handoff.purchase_handoff_batch_id,v_revision_number,
    case when v_revision_number=1 then 'BASE' else 'SUPERSEDING' end,
    'RELEASED_TO_PROCUREMENT',true,v_prior_revision_id,v_actor_id,
    pg_catalog.transaction_timestamp(),request ->> 'reason_note',
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'))
  returning purchase_handoff_revision_id into v_handoff_revision_id;

  for v_line in
    select l.confirmed_need_line_id,r.confirmed_need_line_revision_id,
      r.ingredient_id,r.confirmed_quantity,r.unit_id,r.service_date,
      r.delivery_location_id,sl.confirmed_need_snapshot_line_id
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r
      on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
    join atlas_planning.confirmed_need_snapshot_lines sl
      on sl.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id
     and sl.confirmed_need_approval_snapshot_id=v_batch.current_confirmed_need_approval_snapshot_id
    where l.confirmed_need_batch_id=v_batch_id order by l.confirmed_need_line_id
  loop
    select l.purchase_handoff_line_id into v_handoff_line_id
    from atlas_planning.purchase_handoff_lines l
    where l.purchase_handoff_batch_id=v_handoff.purchase_handoff_batch_id
      and l.confirmed_need_line_id=v_line.confirmed_need_line_id;
    if v_handoff_line_id is null then
      insert into atlas_planning.purchase_handoff_lines(
        purchase_handoff_batch_id,confirmed_need_line_id)
      values(v_handoff.purchase_handoff_batch_id,v_line.confirmed_need_line_id)
      returning purchase_handoff_line_id into v_handoff_line_id;
    end if;
    v_line_ids := v_line_ids || pg_catalog.jsonb_build_array(v_handoff_line_id);

    insert into atlas_planning.purchase_handoff_line_revisions(
      purchase_handoff_revision_id,purchase_handoff_line_id,
      confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,
      service_date,delivery_location_id,predecessor_revision_id,command_id)
    values(v_handoff_revision_id,v_handoff_line_id,
      v_line.confirmed_need_line_revision_id,v_line.ingredient_id,
      v_line.confirmed_quantity,v_line.unit_id,v_line.service_date,
      v_line.delivery_location_id,
      (select old.purchase_handoff_line_revision_id
       from atlas_planning.purchase_handoff_line_revisions old
       where old.purchase_handoff_line_id=v_handoff_line_id
         and old.purchase_handoff_revision_id=v_prior_revision_id),
      atlas_core.pa_05b_safe_uuid(request ->> 'command_id'))
    returning purchase_handoff_line_revision_id into v_handoff_line_revision_id;
    v_line_revision_ids := v_line_revision_ids || pg_catalog.jsonb_build_array(v_handoff_line_revision_id);

    insert into atlas_planning.purchase_demand_references(
      purchase_handoff_line_revision_id,confirmed_need_snapshot_line_id,
      wholesale_order_line_revision_id,approved_quantity,unit_id,source_kind)
    values(v_handoff_line_revision_id,v_line.confirmed_need_snapshot_line_id,
      null,v_line.confirmed_quantity,v_line.unit_id,'NEED_GENERATION')
    returning purchase_demand_reference_id into v_reference_id;
    v_reference_ids := v_reference_ids || pg_catalog.jsonb_build_array(v_reference_id);
  end loop;

  insert into atlas_audit.domain_events(event_type,source_domain,aggregate_type,
    aggregate_id,aggregate_version,command_receipt_id,command_id,correlation_id,
    actor_id,occurred_at,payload_summary)
  values('SchoolCateringPurchaseHandoffReleased','PLANNING','PurchaseHandoff',
    v_handoff.purchase_handoff_batch_id,v_handoff.version,v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    pg_catalog.transaction_timestamp(),pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id',v_batch_id,'purchase_handoff_revision_id',v_handoff_revision_id,
      'revision_number',v_revision_number,'line_count',v_line_count))
  returning domain_event_id into v_event_id;
  insert into atlas_audit.audit_events(event_type,source_domain,aggregate_type,
    aggregate_id,aggregate_version_after,command_receipt_id,command_id,correlation_id,
    actor_id,reason_code,reason_note,after_summary,source_interface,occurred_at)
  values('SchoolCateringPurchaseHandoffReleased','PLANNING','PurchaseHandoff',
    v_handoff.purchase_handoff_batch_id,v_handoff.version,v_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),v_actor_id,
    request ->> 'reason_code',request ->> 'reason_note',
    pg_catalog.jsonb_build_object('status','RELEASED_TO_PROCUREMENT','line_count',v_line_count),
    'atlas_api',pg_catalog.transaction_timestamp())
  returning audit_event_id into v_audit_id;

  v_response := pg_catalog.jsonb_build_object('success',true,
    'contract_version','SCHOOL-CATERING-HANDOFF.v1','command_id',request ->> 'command_id',
    'correlation_id',request ->> 'correlation_id','idempotency_status','COMPLETED',
    'affected_aggregate_ids',pg_catalog.jsonb_build_object(
      'confirmed_need_batch_id',v_batch_id,
      'purchase_handoff_batch_id',v_handoff.purchase_handoff_batch_id,
      'purchase_handoff_revision_id',v_handoff_revision_id,
      'purchase_handoff_line_ids',v_line_ids,
      'purchase_handoff_line_revision_ids',v_line_revision_ids,
      'purchase_demand_reference_ids',v_reference_ids),
    'new_versions',pg_catalog.jsonb_build_object('purchase_handoff_version',v_handoff.version),
    'emitted_event_ids',pg_catalog.jsonb_build_array(v_event_id),
    'audit_event_ids',pg_catalog.jsonb_build_array(v_audit_id),
    'safe_operator_message','Đã chuyển nhu cầu suất ăn sang Thu mua.',
    'warnings','[]'::jsonb,'blockers','[]'::jsonb);
  return atlas_core.pa_05b_finish_command(v_receipt_id,v_response,true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(request,'RETRYABLE_CONCURRENCY_FAILURE',
      'The command could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',v_command_name,true);
  when others then
    return atlas_core.pa_05b_command_error(request,'INTERNAL_COMMAND_FAILURE',
      'The school-catering Purchase Handoff could not be released safely.',
      'PLANNING',v_command_name);
end;
$$;

revoke execute on function atlas_api.release_school_catering_purchase_handoff(jsonb)
  from public, anon, service_role;
grant execute on function atlas_api.release_school_catering_purchase_handoff(jsonb)
  to authenticated;
reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_planning_command_runtime;
reset role;

grant create on schema atlas_api to atlas_read_runtime;
alter function atlas_api.get_school_catering_procurement_workbench(jsonb)
  owner to atlas_read_runtime;
revoke create on schema atlas_api from atlas_read_runtime;
revoke execute on function
  atlas_api.save_school_catering_supplier_allocation(jsonb),
  atlas_api.confirm_school_catering_supplier_recommendations(jsonb),
  atlas_api.get_school_catering_procurement_workbench(jsonb)
from public,anon,service_role;
grant execute on function
  atlas_api.save_school_catering_supplier_allocation(jsonb),
  atlas_api.confirm_school_catering_supplier_recommendations(jsonb),
  atlas_api.get_school_catering_procurement_workbench(jsonb)
to authenticated;
set role atlas_owner;
revoke create on schema atlas_core,atlas_api from atlas_procurement_command_runtime;
reset role;

set role atlas_owner;
grant create on schema atlas_core to atlas_planning_command_runtime;
reset role;
set role atlas_planning_command_runtime;

create function atlas_core.school_catering_purchase_handoff_source_kind(p_handoff_batch_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select case when count(*) > 0 and bool_and(d.source_kind='NEED_GENERATION')
    then 'SCHOOL_CATERING' else 'WHOLESALE' end
  from atlas_planning.purchase_handoff_revisions r
  join atlas_planning.purchase_handoff_line_revisions lr
    on lr.purchase_handoff_revision_id=r.purchase_handoff_revision_id
  join atlas_planning.purchase_demand_references d
    on d.purchase_handoff_line_revision_id=lr.purchase_handoff_line_revision_id
  where r.purchase_handoff_batch_id=p_handoff_batch_id;
$$;
grant execute on function atlas_core.school_catering_purchase_handoff_source_kind(uuid)
  to atlas_confirmed_need_review_runtime,atlas_need_generation_runtime,atlas_read_runtime;

create or replace function atlas_core.issue_222_chain_payload(run_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  with chain as (
    select run.need_generation_run_id,run.period_start,run.period_end,run.run_status,
      run.version need_generation_run_version,batch.confirmed_need_batch_id,
      batch.batch_status confirmed_need_status,batch.version confirmed_need_batch_version,
      batch.current_confirmed_need_release_id is not null or batch.released_at is not null planning_release_occurred
    from atlas_planning.need_generation_runs run
    left join atlas_planning.confirmed_need_batches batch
      on batch.source_kind='NEED_GENERATION' and batch.current_need_generation_run_id=run.need_generation_run_id
    where run.need_generation_run_id=issue_222_chain_payload.run_id
  ), handoff as (
    select
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_purchase_handoff_source_kind(h.purchase_handoff_batch_id)='WHOLESALE')
        active_handoff_exists,
      bool_or(h.handoff_status not in ('INVALIDATED','REOPENED') and
        atlas_core.school_catering_purchase_handoff_source_kind(h.purchase_handoff_batch_id)='SCHOOL_CATERING')
        active_school_catering_handoff_exists,
      coalesce(jsonb_agg(jsonb_build_object('purchase_handoff_batch_id',h.purchase_handoff_batch_id,
        'handoff_status',h.handoff_status,'version',h.version,'source_kind',
        atlas_core.school_catering_purchase_handoff_source_kind(h.purchase_handoff_batch_id))
        order by h.created_at,h.purchase_handoff_batch_id)
        filter(where h.purchase_handoff_batch_id is not null),'[]'::jsonb) handoffs
    from chain left join atlas_planning.purchase_handoff_batches h
      on h.confirmed_need_batch_id=chain.confirmed_need_batch_id
  ), downstream as (
    select exists(select 1 from chain
      join atlas_planning.purchase_handoff_batches h on h.confirmed_need_batch_id=chain.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_batch_id=h.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr on drr.purchase_handoff_revision_id=hr.purchase_handoff_revision_id
      join atlas_procurement.fulfilment_allocations a on a.dispatch_requirement_id=drr.dispatch_requirement_id)
      later_downstream_commitment_exists
  )
  select to_jsonb(chain) || jsonb_build_object('is_legacy_range',chain.period_start<>chain.period_end,
    'active_purchase_handoff_exists',coalesce(handoff.active_handoff_exists,false),
    'active_school_catering_handoff_exists',coalesce(handoff.active_school_catering_handoff_exists,false),
    'purchase_handoffs',handoff.handoffs,'later_downstream_commitment_exists',
    downstream.later_downstream_commitment_exists)
  from chain cross join handoff cross join downstream;
$$;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_planning_command_runtime;
grant select,update on atlas_planning.purchase_handoff_batches,
  atlas_planning.purchase_handoff_revisions to atlas_confirmed_need_review_runtime;
create policy school_catering_correction_handoff_batch_select on atlas_planning.purchase_handoff_batches
  for select to atlas_confirmed_need_review_runtime using(true);
create policy school_catering_correction_handoff_batch_update on atlas_planning.purchase_handoff_batches
  for update to atlas_confirmed_need_review_runtime using(true) with check(true);
create policy school_catering_correction_handoff_revision_select on atlas_planning.purchase_handoff_revisions
  for select to atlas_confirmed_need_review_runtime using(true);
create policy school_catering_correction_handoff_revision_update on atlas_planning.purchase_handoff_revisions
  for update to atlas_confirmed_need_review_runtime using(true) with check(true);
grant create on schema atlas_core to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_confirmed_need_review_runtime;

create or replace function atlas_core.issue_222_reopen_confirmed_need(
  confirmed_need_batch_id uuid,expected_version bigint
) returns atlas_planning.confirmed_need_batches language plpgsql volatile security definer set search_path='' as $$
declare
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_handoff_id uuid;
begin
  select h.purchase_handoff_batch_id into v_handoff_id
  from atlas_planning.purchase_handoff_batches h
  where h.confirmed_need_batch_id=issue_222_reopen_confirmed_need.confirmed_need_batch_id
    and h.handoff_status not in ('INVALIDATED','REOPENED') for update;
  if v_handoff_id is not null then
    if atlas_core.school_catering_purchase_handoff_source_kind(v_handoff_id) <> 'SCHOOL_CATERING' then
      raise exception using errcode='P0001',message='Wholesale Purchase Handoff correction remains blocked';
    end if;
    update atlas_planning.purchase_handoff_revisions
      set revision_status='INVALIDATED',is_current=false
      where purchase_handoff_batch_id=v_handoff_id and is_current;
    update atlas_planning.purchase_handoff_batches
      set handoff_status='INVALIDATED',version=version+1,updated_at=transaction_timestamp()
      where purchase_handoff_batch_id=v_handoff_id;
  end if;
  update atlas_planning.confirmed_need_batches batch
    set batch_status='REOPENED',version=batch.version+1,
      current_confirmed_need_validation_attempt_id=null,
      current_confirmed_need_approval_snapshot_id=null,current_confirmed_need_release_id=null,
      updated_at=transaction_timestamp()
    where batch.confirmed_need_batch_id=issue_222_reopen_confirmed_need.confirmed_need_batch_id
      and batch.version=issue_222_reopen_confirmed_need.expected_version
      and batch.source_kind='NEED_GENERATION' and batch.batch_status not in ('DRAFT_REVIEW','REOPENED')
    returning batch.* into v_batch;
  if v_batch.confirmed_need_batch_id is null then
    raise exception using errcode='P0001',message='Confirmed Need reopen precondition failed';
  end if;
  return v_batch;
end;
$$;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_confirmed_need_review_runtime;
reset role;
revoke execute on function
  atlas_core.school_catering_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text),
  atlas_core.school_catering_family_projection(date,uuid,uuid,uuid),
  atlas_core.school_catering_immutable_revision_guard(),
  atlas_core.school_catering_purchase_handoff_source_kind(uuid)
from public;

reset role;
grant atlas_planning_command_runtime, atlas_procurement_command_runtime,
  atlas_confirmed_need_review_runtime,atlas_need_generation_runtime,
  atlas_read_runtime,atlas_master_data_command_runtime to postgres with set false;
