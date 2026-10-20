-- Reuse the unchanged K2 closed-batch proof within one authenticated read.
-- No persisted cache, public context input, writer, quantity or timeout change.
begin;
create temporary table procurement_read_membership_lease on commit drop as
select roleid,member,grantor,admin_option,inherit_option,set_option from pg_auth_members;
grant atlas_owner,atlas_read_runtime,atlas_confirmed_need_review_runtime,
  atlas_procurement_command_runtime to postgres with set true;
create temporary table procurement_read_schema_lease on commit drop as
select n.nspname,r.rolname,has_schema_privilege(r.rolname,n.oid,'CREATE') had_create
from pg_namespace n cross join pg_roles r
where n.nspname in ('atlas_core','atlas_api') and r.rolname in (
  'postgres','atlas_read_runtime','atlas_confirmed_need_review_runtime','atlas_procurement_command_runtime');
grant select on procurement_read_schema_lease to atlas_owner;
set local role atlas_owner;
grant create on schema atlas_core,atlas_api to postgres,atlas_read_runtime,
  atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime;
reset role;


-- Every original batch, snapshot, partition, contribution and decision-chain predicate is retained.
CREATE OR REPLACE FUNCTION atlas_core.procurement_read_batch_proof(p_source jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
declare
  p jsonb:=p_source; p_date date:=(p_source->>'service_date')::date; b atlas_planning.confirmed_need_batches%rowtype;
  original record; h record; facts jsonb; original_facts jsonb; preflight jsonb;
  current_fact jsonb; original_fact jsonb; changed_families jsonb:='[]'::jsonb;
  unavailable jsonb:=jsonb_build_object('complete',false,
    'post_release_correction',true,'corrected_source_eligible',false,
    'blocker','CORRECTED_SOURCE_INVALID');
begin
  select * into strict b from atlas_planning.confirmed_need_batches
  where confirmed_need_batch_id=(p->>'source_confirmed_need_batch_id')::uuid;
  if b.batch_status<>'REOPENED' or b.released_at is null then return '{}'::jsonb; end if;
  p:=p||jsonb_build_object('post_release_correction',true,'corrected_source_eligible',false);
  if p->>'complete' is distinct from 'true' or b.period_start<>p_date
    or b.period_end<>p_date then return unavailable; end if;

  select release.*,snapshot.confirmed_need_validation_attempt_id,
    snapshot.validated_fact_fingerprint into original
  from atlas_planning.confirmed_need_releases release
  join atlas_planning.confirmed_need_approval_snapshots snapshot
    on snapshot.confirmed_need_approval_snapshot_id=release.confirmed_need_approval_snapshot_id
    and snapshot.confirmed_need_batch_id=release.confirmed_need_batch_id
  join atlas_planning.confirmed_need_validation_attempts attempt
    on attempt.confirmed_need_validation_attempt_id=snapshot.confirmed_need_validation_attempt_id
    and attempt.confirmed_need_batch_id=b.confirmed_need_batch_id
    and attempt.outcome='VALIDATED' and attempt.blocking_issue_count=0
  where release.confirmed_need_batch_id=b.confirmed_need_batch_id
    and release.source_kind='NEED_GENERATION'
  order by release.resulting_released_batch_version desc limit 1;
  if original.confirmed_need_release_id is null then return unavailable; end if;
  select batch.purchase_handoff_batch_id,revision.purchase_handoff_revision_id into h
  from atlas_planning.purchase_handoff_batches batch
  join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
  where batch.confirmed_need_batch_id=b.confirmed_need_batch_id
    and batch.handoff_status='RELEASED_TO_PROCUREMENT' and revision.is_current
    and revision.revision_status='RELEASED_TO_PROCUREMENT';
  if not found or (select count(*) from atlas_planning.purchase_handoff_batches batch
    join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
    where batch.confirmed_need_batch_id=b.confirmed_need_batch_id and revision.is_current)<>1
    then return unavailable; end if;

  preflight:=atlas_core.planning_contract_01_preflight_payload(p_date,p_date,null);
  if preflight->>'readiness_state' is distinct from 'READY'
    or preflight->'blocking_issue_count' is distinct from '0'::jsonb
    or preflight->>'downstream_currentness' is distinct from 'CURRENT'
    or (preflight->'current_need' @> jsonb_build_object(
      'confirmed_need_batch_id',b.confirmed_need_batch_id,
      'confirmed_need_batch_version',b.version,
      'need_generation_run_id',b.current_need_generation_run_id,
      'need_generation_run_version',b.current_need_generation_run_version,
      'need_generation_release_snapshot_id',b.current_need_generation_release_snapshot_id))
      is distinct from true then return unavailable; end if;

  facts:=atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id);
  original_facts:=atlas_core.rmvp_07_validated_facts_projection(
    b.confirmed_need_batch_id,original.confirmed_need_validation_attempt_id);
  if encode(sha256(convert_to(original_facts::text,'UTF8')),'hex')
      is distinct from original.validated_fact_fingerprint
    or jsonb_array_length(facts->'ordered_lines')<>jsonb_array_length(original_facts->'ordered_lines')
    or (select count(*) from atlas_planning.confirmed_need_snapshot_lines member
      where member.confirmed_need_approval_snapshot_id=original.confirmed_need_approval_snapshot_id)
      <>jsonb_array_length(original_facts->'ordered_lines')
    or (select count(*) from atlas_planning.purchase_handoff_line_revisions line
      where line.purchase_handoff_revision_id=h.purchase_handoff_revision_id)
      <>jsonb_array_length(original_facts->'ordered_lines')
    then return unavailable; end if;

  for current_fact in select value from jsonb_array_elements(facts->'ordered_lines') loop
    select value into original_fact from jsonb_array_elements(original_facts->'ordered_lines')
    where value->>'confirmed_need_line_id'=current_fact->>'confirmed_need_line_id';
    if original_fact is null
      or (current_fact-array['line_sort_position','current_confirmed_need_line_revision_id',
        'current_confirmed_need_line_decision_id','confirmed_quantity','planning_tick_count','ordered_source_members'])
        is distinct from (original_fact-array['line_sort_position','current_confirmed_need_line_revision_id',
        'current_confirmed_need_line_decision_id','confirmed_quantity','planning_tick_count','ordered_source_members'])
      or (select count(*) from atlas_planning.confirmed_need_snapshot_lines snapshot_line
        join atlas_planning.purchase_demand_references demand
          using(confirmed_need_snapshot_line_id)
        join atlas_planning.purchase_handoff_line_revisions line
          using(purchase_handoff_line_revision_id)
        where snapshot_line.confirmed_need_approval_snapshot_id=original.confirmed_need_approval_snapshot_id
          and snapshot_line.confirmed_need_line_revision_id=
            (original_fact->>'current_confirmed_need_line_revision_id')::uuid
          and snapshot_line.approved_quantity=(original_fact->>'confirmed_quantity')::numeric
          and demand.source_kind='NEED_GENERATION'
          and demand.approved_quantity=snapshot_line.approved_quantity
          and demand.unit_id=snapshot_line.unit_id
          and line.purchase_handoff_revision_id=h.purchase_handoff_revision_id
          and line.confirmed_need_line_revision_id=snapshot_line.confirmed_need_line_revision_id
          and line.handoff_quantity=snapshot_line.approved_quantity
          and line.unit_id=snapshot_line.unit_id)<>1
      or exists((select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id',
          'confirmed_need_line_revision_id','created_at']
        from atlas_planning.confirmed_need_line_revision_contributions c
        where c.confirmed_need_line_revision_id=(current_fact->>'current_confirmed_need_line_revision_id')::uuid
        except select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id',
          'confirmed_need_line_revision_id','created_at']
        from atlas_planning.confirmed_need_line_revision_contributions c
        where c.confirmed_need_line_revision_id=(original_fact->>'current_confirmed_need_line_revision_id')::uuid)
        union all (select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id',
          'confirmed_need_line_revision_id','created_at']
        from atlas_planning.confirmed_need_line_revision_contributions c
        where c.confirmed_need_line_revision_id=(original_fact->>'current_confirmed_need_line_revision_id')::uuid
        except select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id',
          'confirmed_need_line_revision_id','created_at']
        from atlas_planning.confirmed_need_line_revision_contributions c
        where c.confirmed_need_line_revision_id=(current_fact->>'current_confirmed_need_line_revision_id')::uuid))
      then return unavailable; end if;
    if current_fact->>'current_confirmed_need_line_revision_id'=
        original_fact->>'current_confirmed_need_line_revision_id' then
      if current_fact->>'current_confirmed_need_line_decision_id' is distinct from
          original_fact->>'current_confirmed_need_line_decision_id'
        then return unavailable; end if;
    else
      -- H1B1's immutable contiguous chain proves writer-established human
      -- authority; neither a receipt label nor today's old-Actor grants do so.
      if not exists(
        with recursive chain as (
          select decision.* from atlas_planning.confirmed_need_line_decisions decision
          where decision.confirmed_need_line_decision_id=
            (current_fact->>'current_confirmed_need_line_decision_id')::uuid
          union all select prior.* from chain
          join atlas_planning.confirmed_need_line_decisions prior
            on prior.confirmed_need_line_decision_id=chain.predecessor_decision_id
          where chain.confirmed_need_line_decision_id<>
            (original_fact->>'current_confirmed_need_line_decision_id')::uuid
        )
        select 1 from chain where confirmed_need_line_decision_id=
          (original_fact->>'current_confirmed_need_line_decision_id')::uuid
          and atlas_core.planning_contract_02b_decision_authorizes_revision(
            confirmed_need_line_decision_id,confirmed_need_line_id,
            (original_fact->>'current_confirmed_need_line_revision_id')::uuid)
          and not exists(select 1 from chain successor
            join atlas_planning.confirmed_need_line_revisions revision
              on revision.confirmed_need_line_revision_id=successor.confirmed_need_line_revision_id
            join atlas_planning.confirmed_need_line_decisions prior
              on prior.confirmed_need_line_decision_id=successor.predecessor_decision_id
            where successor.confirmed_need_line_decision_id<>
              (original_fact->>'current_confirmed_need_line_decision_id')::uuid
              and (successor.decision_kind<>'ADJUSTED_QUANTITY_CONFIRMED'
                or successor.confirmed_need_batch_version<=original.resulting_released_batch_version
                or not atlas_core.planning_contract_02b_decision_authorizes_revision(
                  prior.confirmed_need_line_decision_id,prior.confirmed_need_line_id,revision.predecessor_revision_id)
                or successor.proposed_quantity_before is distinct from prior.confirmed_quantity_after)))
        then return unavailable; end if;
      changed_families:=changed_families||jsonb_build_array(concat_ws('/',
        current_fact->>'service_date',current_fact->>'delivery_location_id',
        current_fact->>'ingredient_id',current_fact->>'controlled_unit_id'));
    end if;
  end loop;
  return jsonb_build_object('post_release_correction',true,'corrected_source_eligible',true,
    'corrected_families',changed_families,'original_release_id',original.confirmed_need_release_id,
    'original_purchase_handoff_revision_id',h.purchase_handoff_revision_id);
end;
$function$;

alter function atlas_core.procurement_read_batch_proof(jsonb) owner to atlas_confirmed_need_review_runtime;
revoke all on function atlas_core.procurement_read_batch_proof(jsonb) from public,anon,authenticated,service_role;

create function atlas_core.procurement_read_context(p_start date,p_end date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare raw_sources jsonb; proofs jsonb:='{}'; source jsonb; proof jsonb; batch record; projected jsonb:='[]'; confirmed jsonb;
begin
  select coalesce(jsonb_agg(value),'[]') into raw_sources
  from atlas_core.purchase_review_confirmed_sources(p_start,p_end) value;
  for batch in select distinct value->>'source_confirmed_need_batch_id' id
    from jsonb_array_elements(raw_sources) value loop
    select value into source from jsonb_array_elements(raw_sources) value
    where value->>'source_confirmed_need_batch_id'=batch.id limit 1;
    proof:=atlas_core.procurement_read_batch_proof(source);
    proofs:=proofs||jsonb_build_object(batch.id,proof);
  end loop;
  for source in select value from jsonb_array_elements(raw_sources) value loop
    proof:=proofs->(source->>'source_confirmed_need_batch_id');
    if proof->>'corrected_source_eligible'='true' then
      proof:=proof||jsonb_build_object('corrected_family',proof->'corrected_families' ? concat_ws('/',
        source->>'service_date',source->>'delivery_location_id',source->>'ingredient_id',source->>'unit_id'));
    end if;
    projected:=projected||jsonb_build_array(source||(proof-'corrected_families'));
  end loop;
  select coalesce(jsonb_object_agg(key,items),'{}') into confirmed from (
    select concat_ws('/',value->>'service_date',value->>'delivery_location_id',
      value->>'ingredient_id',value->>'unit_id') key,jsonb_agg(value) items
    from jsonb_array_elements(projected) value group by 1
  ) keyed;
  return jsonb_build_object('sources',raw_sources,'confirmed',confirmed);
end;
$$;
alter function atlas_core.procurement_read_context(date,date) owner to atlas_confirmed_need_review_runtime;
revoke all on function atlas_core.procurement_read_context(date,date) from public,anon,authenticated,service_role;
grant execute on function atlas_core.procurement_read_context(date,date) to atlas_read_runtime;


-- atlas_core.purchase_review_confirmed_projection: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.purchase_review_confirmed_projection(date,uuid,uuid,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.purchase_review_confirmed_projection(p_date date, p_location uuid, p_ingredient uuid, p_unit uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_confirmed_projection'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.purchase_review_confirmed_projection(p_date date, p_location uuid, p_ingredient uuid, p_unit uuid)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_purchase_review_confirmed_projection(p_date date, p_location uuid, p_ingredient uuid, p_unit uuid, p_read_context jsonb)$anchor$);
  if position($anchor$  select coalesce(jsonb_agg(value),'[]'::jsonb) into sources
  from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value)
  where value->>'delivery_location_id'=p_location::text
    and value->>'ingredient_id'=p_ingredient::text and value->>'unit_id'=p_unit::text;
$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_confirmed_projection'; end if;
  d:=replace(d,$anchor$  select coalesce(jsonb_agg(value),'[]'::jsonb) into sources
  from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value)
  where value->>'delivery_location_id'=p_location::text
    and value->>'ingredient_id'=p_ingredient::text and value->>'unit_id'=p_unit::text;
$anchor$,$anchor$  sources:=coalesce(p_read_context->'confirmed'->concat_ws('/',p_date,p_location,p_ingredient,p_unit),'[]'::jsonb);
$anchor$);
  if position('  p:=sources->0;' in d)=0 then raise exception 'Procurement read projection boundary changed'; end if;
  d:=left(d,position('  p:=sources->0;' in d)-1)||E'  return sources->0;\nend;\n$function$\n';
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.purchase_review_confirmed_projection(date,uuid,uuid,uuid)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_purchase_review_confirmed_projection(date,uuid,uuid,uuid,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_purchase_review_confirmed_projection(date,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.purchase_review_confirmed_projection(date,uuid,uuid,uuid)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_purchase_review_confirmed_projection(date,uuid,uuid,uuid,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.school_catering_family_projection: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_catering_family_projection(p_service_date date, p_delivery_location_id uuid, p_ingredient_id uuid, p_unit_id uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_family_projection'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.school_catering_family_projection(p_service_date date, p_delivery_location_id uuid, p_ingredient_id uuid, p_unit_id uuid)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_school_catering_family_projection(p_service_date date, p_delivery_location_id uuid, p_ingredient_id uuid, p_unit_id uuid, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.purchase_review_confirmed_projection(p_service_date,p_delivery_location_id,p_ingredient_id,p_unit_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_family_projection'; end if;
  d:=replace(d,$anchor$atlas_core.purchase_review_confirmed_projection(p_service_date,p_delivery_location_id,p_ingredient_id,p_unit_id)$anchor$,$anchor$atlas_core.procurement_read_purchase_review_confirmed_projection(p_service_date,p_delivery_location_id,p_ingredient_id,p_unit_id,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_school_catering_family_projection(date,uuid,uuid,uuid,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_school_catering_family_projection(date,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_school_catering_family_projection(date,uuid,uuid,uuid,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.school_catering_po_draft_is_stale: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.school_catering_po_draft_is_stale(uuid,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_catering_po_draft_is_stale(p_purchase_order_id uuid, p_purchase_order_revision_id uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_draft_is_stale'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.school_catering_po_draft_is_stale(p_purchase_order_id uuid, p_purchase_order_revision_id uuid)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_school_catering_po_draft_is_stale(p_purchase_order_id uuid, p_purchase_order_revision_id uuid, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection(
      f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_draft_is_stale'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_family_projection(
      f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_family_projection(
      f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.school_catering_po_draft_is_stale(uuid,uuid)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_school_catering_po_draft_is_stale(uuid,uuid,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_school_catering_po_draft_is_stale(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.school_catering_po_draft_is_stale(uuid,uuid)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_school_catering_po_draft_is_stale(uuid,uuid,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.school_catering_po_commitment_state: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.school_catering_po_commitment_state(uuid,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_catering_po_commitment_state(p_purchase_order_id uuid, p_purchase_order_revision_id uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_commitment_state'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.school_catering_po_commitment_state(p_purchase_order_id uuid, p_purchase_order_revision_id uuid)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_school_catering_po_commitment_state(p_purchase_order_id uuid, p_purchase_order_revision_id uuid, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection(
          f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
        )$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_commitment_state'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_family_projection(
          f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
        )$anchor$,$anchor$atlas_core.procurement_read_school_catering_family_projection(
          f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
        ,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_commitment_state'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.school_catering_po_commitment_state(uuid,uuid)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_school_catering_po_commitment_state(uuid,uuid,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_school_catering_po_commitment_state(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.school_catering_po_commitment_state(uuid,uuid)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_school_catering_po_commitment_state(uuid,uuid,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.school_catering_po_date_readiness: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.school_catering_po_date_readiness(date)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_catering_po_date_readiness(p_service_date date)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_date_readiness'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.school_catering_po_date_readiness(p_service_date date)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_school_catering_po_date_readiness(p_service_date date, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection(
        sf.service_date,sf.delivery_location_id,sf.ingredient_id,sf.unit_id
      )$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_po_date_readiness'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_family_projection(
        sf.service_date,sf.delivery_location_id,sf.ingredient_id,sf.unit_id
      )$anchor$,$anchor$atlas_core.procurement_read_school_catering_family_projection(
        sf.service_date,sf.delivery_location_id,sf.ingredient_id,sf.unit_id
      ,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.school_catering_po_date_readiness(date)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_school_catering_po_date_readiness(date,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_school_catering_po_date_readiness(date,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.school_catering_po_date_readiness(date)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_school_catering_po_date_readiness(date,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.school_catering_procurement_date_current: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.school_catering_procurement_date_current(date)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_catering_procurement_date_current(p_service_date date)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_procurement_date_current'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.school_catering_procurement_date_current(p_service_date date)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_school_catering_procurement_date_current(p_service_date date, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      )$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_procurement_date_current'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      )$anchor$,$anchor$atlas_core.procurement_read_school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_procurement_date_current'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_commitment_state(
          po.purchase_order_id,por.purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_procurement_date_current'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_commitment_state(
          po.purchase_order_id,por.purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_commitment_state(
          po.purchase_order_id,por.purchase_order_revision_id,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_date_readiness(p_service_date)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.school_catering_procurement_date_current'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_date_readiness(p_service_date)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_date_readiness(p_service_date,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.school_catering_procurement_date_current(date)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_school_catering_procurement_date_current(date,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_school_catering_procurement_date_current(date,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.school_catering_procurement_date_current(date)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_school_catering_procurement_date_current(date,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.purchase_review_preparation_status: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.purchase_review_preparation_status(date,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.purchase_review_preparation_status(p_date date, p_actor uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_preparation_status'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.purchase_review_preparation_status(p_date date, p_actor uuid)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_purchase_review_preparation_status(p_date date, p_actor uuid, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.purchase_review_confirmed_projection((p->>'service_date')::date,
      (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_preparation_status'; end if;
  d:=replace(d,$anchor$atlas_core.purchase_review_confirmed_projection((p->>'service_date')::date,
      (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)$anchor$,$anchor$atlas_core.procurement_read_purchase_review_confirmed_projection((p->>'service_date')::date,
      (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,revision.purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_preparation_status'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,revision.purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_commitment_state(
            po.purchase_order_id,revision.purchase_order_revision_id,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_date_readiness(p_date)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_preparation_status'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_date_readiness(p_date)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_date_readiness(p_date,p_read_context)$anchor$);
  if position($anchor$from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value);$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.purchase_review_preparation_status'; end if;
  d:=replace(d,$anchor$from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value);$anchor$,$anchor$from jsonb_array_elements(p_read_context->'sources') source(value)
  where (value->>'service_date')::date=p_date;$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.purchase_review_preparation_status(date,uuid)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_purchase_review_preparation_status(date,uuid,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_purchase_review_preparation_status(date,uuid,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.purchase_review_preparation_status(date,uuid)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_purchase_review_preparation_status(date,uuid,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.get_school_catering_procurement_workbench_numeric_compat: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.get_school_catering_procurement_workbench_numeric_compat(jsonb)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.get_school_catering_procurement_workbench_numeric_compat(request jsonb)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.get_school_catering_procurement_workbench_numeric_compat'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.get_school_catering_procurement_workbench_numeric_compat(request jsonb)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_legacy_allocation_rows(request jsonb, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection(
      k.service_date,k.delivery_location_id,k.ingredient_id,k.unit_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.get_school_catering_procurement_workbench_numeric_compat'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_family_projection(
      k.service_date,k.delivery_location_id,k.ingredient_id,k.unit_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_family_projection(
      k.service_date,k.delivery_location_id,k.ingredient_id,k.unit_id,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.get_school_catering_procurement_workbench_numeric_compat(jsonb)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_legacy_allocation_rows(jsonb,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_legacy_allocation_rows(jsonb,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.get_school_catering_procurement_workbench_numeric_compat(jsonb)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_legacy_allocation_rows(jsonb,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_api.get_school_catering_procurement_workbench: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_api.get_school_catering_procurement_workbench(jsonb)'::regprocedure);
  if position($anchor$FUNCTION atlas_api.get_school_catering_procurement_workbench(request jsonb)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_procurement_workbench'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_api.get_school_catering_procurement_workbench(request jsonb)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_get_school_catering_procurement_workbench(request jsonb, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.get_school_catering_procurement_workbench_numeric_compat(request)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_procurement_workbench'; end if;
  d:=replace(d,$anchor$atlas_core.get_school_catering_procurement_workbench_numeric_compat(request)$anchor$,$anchor$atlas_core.procurement_read_legacy_allocation_rows(request,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_api.get_school_catering_procurement_workbench(jsonb)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_get_school_catering_procurement_workbench(jsonb,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_get_school_catering_procurement_workbench(jsonb,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_api.get_school_catering_procurement_workbench(jsonb)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_get_school_catering_procurement_workbench(jsonb,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_core.get_school_catering_purchase_orders_numeric_compat: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.get_school_catering_purchase_orders_numeric_compat(request jsonb)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.get_school_catering_purchase_orders_numeric_compat'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_core.get_school_catering_purchase_orders_numeric_compat(request jsonb)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_po_rows(request jsonb, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,por.purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_core.get_school_catering_purchase_orders_numeric_compat'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,por.purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_draft_is_stale(
        po.purchase_order_id,por.purchase_order_revision_id,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_po_rows(jsonb,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_po_rows(jsonb,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_po_rows(jsonb,jsonb) to %I',grantee_name);
  end loop;

end $read$;

-- atlas_api.get_school_catering_purchase_orders_v1_base: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_api.get_school_catering_purchase_orders_v1_base(jsonb)'::regprocedure);
  if position($anchor$FUNCTION atlas_api.get_school_catering_purchase_orders_v1_base(request jsonb)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v1_base'; end if;
  d:=replace(d,$anchor$FUNCTION atlas_api.get_school_catering_purchase_orders_v1_base(request jsonb)$anchor$,$anchor$FUNCTION atlas_core.procurement_read_get_school_catering_purchase_orders_v1_base(request jsonb, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.get_school_catering_purchase_orders_numeric_compat(request)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v1_base'; end if;
  d:=replace(d,$anchor$atlas_core.get_school_catering_purchase_orders_numeric_compat(request)$anchor$,$anchor$atlas_core.procurement_read_po_rows(request,p_read_context)$anchor$);
  execute d;
  select pg_get_userbyid(proowner) into owner_name from pg_proc where oid='atlas_api.get_school_catering_purchase_orders_v1_base(jsonb)'::regprocedure;
  execute format('alter function atlas_core.procurement_read_get_school_catering_purchase_orders_v1_base(jsonb,jsonb) owner to %I',owner_name);
  revoke all on function atlas_core.procurement_read_get_school_catering_purchase_orders_v1_base(jsonb,jsonb) from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_api.get_school_catering_purchase_orders_v1_base(jsonb)'::regprocedure and acl.privilege_type='EXECUTE'
      and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_get_school_catering_purchase_orders_v1_base(jsonb,jsonb) to %I',grantee_name);
  end loop;

end $read$;

CREATE OR REPLACE FUNCTION atlas_core.procurement_read_orders_context(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  return atlas_core.procurement_read_context(v_date_start,v_date_end);
end;
$function$;
alter function atlas_core.procurement_read_orders_context(jsonb) owner to atlas_read_runtime;
revoke all on function atlas_core.procurement_read_orders_context(jsonb) from public,anon,authenticated,service_role;


-- atlas_api.get_school_catering_purchase_orders_v2_base: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)'::regprocedure);
  if position($anchor$  v_base jsonb;$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v2_base'; end if;
  d:=replace(d,$anchor$  v_base jsonb;$anchor$,$anchor$  v_read_context jsonb; v_base jsonb;$anchor$);
  if position($anchor$  v_base := atlas_api.get_school_catering_purchase_orders_v1_base(request);$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v2_base'; end if;
  d:=replace(d,$anchor$  v_base := atlas_api.get_school_catering_purchase_orders_v1_base(request);$anchor$,$anchor$  v_read_context:=atlas_core.procurement_read_orders_context(request);
  if v_read_context->>'success'='false' then return v_read_context; end if;
  v_base := atlas_core.procurement_read_get_school_catering_purchase_orders_v1_base(request,v_read_context);$anchor$);
  if position($anchor$atlas_core.school_catering_po_draft_is_stale(
            child.purchase_order_id,child_revision.purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v2_base'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_draft_is_stale(
            child.purchase_order_id,child_revision.purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_draft_is_stale(
            child.purchase_order_id,child_revision.purchase_order_revision_id,v_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v2_base'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id)$anchor$,$anchor$atlas_core.procurement_read_school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id,v_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_procurement_date_current(scoped.service_date)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_school_catering_purchase_orders_v2_base'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_procurement_date_current(scoped.service_date)$anchor$,$anchor$atlas_core.procurement_read_school_catering_procurement_date_current(scoped.service_date,v_read_context)$anchor$);
  execute d;

end $read$;

-- atlas_api.get_confirmed_supplier_allocation_workbench: internal read context only.
do $read$
declare d text; owner_name name; grantee_name name;
begin
  d:=pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
  if position($anchor$declare
$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$declare
$anchor$,$anchor$declare
  v_read_context jsonb;
$anchor$);
  if position($anchor$  v_can_write:=v_error is null or v_error->>'error_code'='SCOPE_DENIED';$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$  v_can_write:=v_error is null or v_error->>'error_code'='SCOPE_DENIED';$anchor$,$anchor$  v_can_write:=v_error is null or v_error->>'error_code'='SCOPE_DENIED';
  v_read_context:=atlas_core.procurement_read_context(v_start,v_end);$anchor$);
  if position($anchor$atlas_core.purchase_review_confirmed_sources(v_start,v_end)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$atlas_core.purchase_review_confirmed_sources(v_start,v_end)$anchor$,$anchor$jsonb_array_elements(v_read_context->'sources')$anchor$);
  if position($anchor$atlas_core.purchase_review_confirmed_projection((p->>'service_date')::date,
        (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$atlas_core.purchase_review_confirmed_projection((p->>'service_date')::date,
        (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)$anchor$,$anchor$atlas_core.procurement_read_purchase_review_confirmed_projection((p->>'service_date')::date,
        (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid,v_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection((p->>'service_date')::date,
          (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$atlas_core.school_catering_family_projection((p->>'service_date')::date,
          (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid)$anchor$,$anchor$atlas_core.procurement_read_school_catering_family_projection((p->>'service_date')::date,
          (p->>'delivery_location_id')::uuid,(p->>'ingredient_id')::uuid,(p->>'unit_id')::uuid,v_read_context)$anchor$);
  if position($anchor$atlas_core.purchase_review_preparation_status(v_start,v_actor_id)$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$atlas_core.purchase_review_preparation_status(v_start,v_actor_id)$anchor$,$anchor$atlas_core.procurement_read_purchase_review_preparation_status(v_start,v_actor_id,v_read_context)$anchor$);
  if position($anchor$atlas_api.get_school_catering_procurement_workbench(
      request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1'))$anchor$ in d)=0 then raise exception 'Procurement read anchor changed: atlas_api.get_confirmed_supplier_allocation_workbench'; end if;
  d:=replace(d,$anchor$atlas_api.get_school_catering_procurement_workbench(
      request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1'))$anchor$,$anchor$atlas_core.procurement_read_get_school_catering_procurement_workbench(
      request||jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1'),v_read_context)$anchor$);
  execute d;

end $read$;

-- Reuse the membership plan instead of rebuilding it for each large context.
alter function atlas_core.procurement_read_school_catering_po_draft_is_stale(uuid,uuid,jsonb)
  set plan_cache_mode='force_generic_plan';
-- Avoid repeated order-line scans when new orders have small row estimates.
alter function atlas_core.procurement_read_school_catering_po_draft_is_stale(uuid,uuid,jsonb)
  set enable_nestloop='off';

-- Restore the exact pre-existing authoring privilege/membership posture.
set local role atlas_owner;
do $restore$ declare lease record; begin
  for lease in select * from procurement_read_schema_lease where not had_create loop
    execute format('revoke create on schema %I from %I',lease.nspname,lease.rolname);
  end loop;
end $restore$;
reset role;
do $restore$ declare lease record; begin
  for lease in select r.rolname,a.set_option from procurement_read_membership_lease a
    join pg_roles r on r.oid=a.roleid
    where a.member=(select oid from pg_roles where rolname='postgres')
      and a.grantor=(select oid from pg_roles where rolname='postgres') loop
    execute format('grant %I to postgres with set %s',lease.rolname,
      case when lease.set_option then 'true' else 'false' end);
  end loop;
end $restore$;
commit;
