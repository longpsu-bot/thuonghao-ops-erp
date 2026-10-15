-- Operator C: private immutable proof/fences and closed atomic quantity correction.
-- No backfill, released-status downgrade, automatic document release or new human authority.
begin;
create temporary table c_task2_role_before on commit drop as
select r.rolname role_name,a.admin_option,a.inherit_option,a.set_option
from pg_roles r left join pg_auth_members a on a.roleid=r.oid
 and a.member='postgres'::regrole and a.grantor='postgres'::regrole
where r.rolname in('atlas_confirmed_need_review_runtime','atlas_procurement_command_runtime','atlas_need_generation_runtime',
 'atlas_planning_materialization_runtime','atlas_planning_command_runtime','atlas_dispatch_command_runtime','atlas_read_runtime');
create temporary table c_task2_schema_before on commit drop as
select role_name,schema_name,has_schema_privilege(role_name,schema_name,'CREATE') had_create
from(values('atlas_confirmed_need_review_runtime','atlas_core'),
 ('atlas_confirmed_need_review_runtime','atlas_planning'),
 ('atlas_procurement_command_runtime','atlas_core'),
 ('atlas_need_generation_runtime','atlas_core'),
 ('atlas_need_generation_runtime','atlas_api'),('atlas_confirmed_need_review_runtime','atlas_api'),
 ('atlas_procurement_command_runtime','atlas_api'),('atlas_planning_command_runtime','atlas_api'),
 ('atlas_planning_materialization_runtime','atlas_core'),('atlas_dispatch_command_runtime','atlas_api'),
 ('atlas_read_runtime','atlas_core'))access(role_name,schema_name);
grant select on c_task2_schema_before to atlas_owner;
grant atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime,atlas_need_generation_runtime,
 atlas_planning_materialization_runtime,atlas_planning_command_runtime,atlas_dispatch_command_runtime,atlas_read_runtime
 to postgres with set true;
set role atlas_owner;
do $authoring_create$
declare access record;
begin
 for access in select * from pg_temp.c_task2_schema_before where not had_create loop
  execute format('grant create on schema %I to %I',access.schema_name,access.role_name);
 end loop;
end;$authoring_create$;
reset role;
set role atlas_confirmed_need_review_runtime;

-- One set-based frozen predicate is reused by the bridge and lifecycle guards.
-- No whole-batch JSON projection is executed by the per-row integrity trigger.
create function atlas_core.confirmed_need_historical_validation_complete(p_batch uuid,p_attempt uuid)
returns boolean language sql stable security definer set search_path='' as $complete$
select exists (
    select 1
    from atlas_planning.confirmed_need_validation_attempts attempt
    where attempt.confirmed_need_validation_attempt_id = p_attempt
      and attempt.confirmed_need_batch_id = p_batch
      and attempt.source_kind = 'NEED_GENERATION'
      and attempt.outcome = 'VALIDATED'
      and attempt.blocking_issue_count = 0
      and attempt.line_count > 0
      and attempt.line_count = (select count(distinct o.confirmed_need_line_id)
       from atlas_planning.confirmed_need_validation_lines o
       where o.confirmed_need_validation_attempt_id=p_attempt)
      and attempt.line_count = (
        select count(*)
        from atlas_planning.confirmed_need_validation_lines observation
        where observation.confirmed_need_validation_attempt_id
          = p_attempt
      )
      and attempt.blocking_issue_count = (
        select count(*)
        from atlas_planning.confirmed_need_validation_issues issue
        where issue.confirmed_need_validation_attempt_id
          = p_attempt
          and issue.severity = 'BLOCKING'
      )
      and attempt.warning_count = (
        select count(*)
        from atlas_planning.confirmed_need_validation_issues issue
        where issue.confirmed_need_validation_attempt_id
          = p_attempt
          and issue.severity = 'WARNING'
      )
      and not exists (
        select 1
        from atlas_planning.confirmed_need_validation_lines observation
        left join atlas_planning.confirmed_need_lines line
          on line.confirmed_need_line_id = observation.confirmed_need_line_id
         and line.confirmed_need_batch_id = observation.confirmed_need_batch_id
        left join atlas_planning.confirmed_need_line_revisions revision
          on revision.confirmed_need_line_revision_id
            = observation.current_confirmed_need_line_revision_id
         and revision.confirmed_need_line_id
            = observation.confirmed_need_line_id
        left join atlas_planning.confirmed_need_line_decisions decision
          on decision.confirmed_need_line_decision_id
            = observation.current_confirmed_need_line_decision_id
         and decision.confirmed_need_line_id
            = observation.confirmed_need_line_id
        left join atlas_planning.planning_quantity_policy_revisions policy_revision
          on policy_revision.planning_quantity_policy_revision_id
            = observation.planning_quantity_policy_revision_id
         and policy_revision.planning_quantity_policy_id
            = observation.planning_quantity_policy_id
        where observation.confirmed_need_validation_attempt_id
          = p_attempt
          and (
            observation.confirmed_need_batch_id is distinct from p_batch
            or observation.current_confirmed_need_line_revision_id is null
            or observation.current_confirmed_need_line_decision_id is null
            or observation.controlled_unit_id is null
            or observation.planning_quantity_policy_id is null
            or observation.planning_quantity_policy_revision_id is null
            or observation.need_generation_run_id is null
            or observation.need_generation_run_version is null
            or observation.need_generation_release_snapshot_id is null
            or observation.theoretical_quantity is null
            or observation.confirmed_quantity is null
            or observation.planning_tick_count is null
            or observation.source_membership_total is null
            or observation.validation_outcome is distinct from 'VALIDATED'
            or observation.observed_current_revision_count is distinct from 1
            or observation.observed_current_decision_count is distinct from 1
            or observation.observed_eligible_policy_count is distinct from 1
            or coalesce(observation.observed_source_membership_count,0) < 1
            or line.confirmed_need_line_id is null
            or revision.confirmed_need_line_revision_id is null
            or revision.confirmed_need_batch_id is distinct from p_batch
            or decision.confirmed_need_line_decision_id is null
            or not atlas_core.planning_contract_02b_decision_authorizes_revision(
              decision.confirmed_need_line_decision_id,
              observation.confirmed_need_line_id,
              revision.confirmed_need_line_revision_id
            )
            or policy_revision.planning_quantity_policy_revision_id is null
            or observation.controlled_unit_id is distinct from line.controlled_unit_id
            or observation.controlled_unit_id is distinct from revision.unit_id
            or observation.controlled_unit_id is distinct from decision.unit_id
            or observation.need_generation_run_id
              is distinct from revision.need_generation_run_id
            or observation.need_generation_run_version
              is distinct from revision.need_generation_run_version
            or observation.need_generation_release_snapshot_id
              is distinct from revision.need_generation_release_snapshot_id
            or observation.theoretical_quantity
              is distinct from revision.theoretical_quantity
            or observation.confirmed_quantity
              is distinct from decision.confirmed_quantity_after
            or observation.planning_tick_count
              is distinct from decision.planning_tick_count
            or observation.source_membership_total
              is distinct from revision.theoretical_quantity
            or observation.observed_source_membership_count is distinct from (
              select count(*)
              from atlas_planning.confirmed_need_line_revision_contributions c
              where c.confirmed_need_line_revision_id
                = revision.confirmed_need_line_revision_id
            )
            or observation.source_membership_total is distinct from (
              select sum(c.controlled_contribution_quantity)
              from atlas_planning.confirmed_need_line_revision_contributions c
              where c.confirmed_need_line_revision_id
                = revision.confirmed_need_line_revision_id
            )
          )
      )
  );
$complete$;
revoke all on function atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)
 from public,anon,authenticated,service_role;

create function atlas_core.confirmed_need_historical_validation_evidence(p_batch uuid,p_attempt uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $evidence$
declare complete boolean; projection jsonb; released_snapshots jsonb;
begin
 complete:=atlas_core.confirmed_need_historical_validation_complete(p_batch,p_attempt);
 if not complete then
  return jsonb_build_object('complete',false,'confirmed_need_batch_id',p_batch,
   'validation_attempt_id',p_attempt,'projection',null);
 end if;
 projection:=atlas_core.rmvp_07_validated_facts_projection(p_batch,p_attempt);
 -- Historical identity comes from the captured revision, never current Master data
 -- or the stable line's mutable/current pointer used by the legacy projection.
 select jsonb_set(projection,'{ordered_lines}',coalesce(jsonb_agg(item||jsonb_build_object(
  'service_date',r.service_date,'customer_id',r.customer_id,'school_id',r.school_id,
  'delivery_location_id',r.delivery_location_id,'ingredient_id',r.ingredient_id)
  order by (item->>'line_sort_position')::integer),'[]'::jsonb)) into projection
 from jsonb_array_elements(projection->'ordered_lines') item
 join atlas_planning.confirmed_need_line_revisions r
  on r.confirmed_need_line_revision_id=(item->>'current_confirmed_need_line_revision_id')::uuid;
 -- Release-table authority stays in the review owner boundary; Procurement
 -- receives only matching already-readable approval snapshot identities.
 select coalesce(jsonb_agg(s.confirmed_need_approval_snapshot_id order by s.confirmed_need_approval_snapshot_id),'[]')
 into released_snapshots
 from atlas_planning.confirmed_need_approval_snapshots s
 join atlas_planning.confirmed_need_validation_attempts a
  on a.confirmed_need_validation_attempt_id=s.confirmed_need_validation_attempt_id
  and a.confirmed_need_batch_id=s.confirmed_need_batch_id
 join atlas_planning.confirmed_need_releases rel
  on rel.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
  and rel.confirmed_need_batch_id=s.confirmed_need_batch_id and rel.source_kind=s.source_kind
  and rel.source_approved_batch_version=s.approved_version
  and rel.resulting_released_batch_version=s.approved_version+1
 where s.confirmed_need_batch_id=p_batch and s.confirmed_need_validation_attempt_id=p_attempt
  and s.source_kind='NEED_GENERATION' and s.approved_version=a.resulting_batch_version+1
  and s.validated_fact_fingerprint=atlas_core.rmvp_07_validated_facts_fingerprint(projection)
  and (select count(*)from atlas_planning.confirmed_need_snapshot_lines sl
   where sl.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id)=a.line_count
  and not exists(select 1 from atlas_planning.confirmed_need_validation_lines observation
   where observation.confirmed_need_validation_attempt_id=p_attempt
   and not exists(select 1 from atlas_planning.confirmed_need_snapshot_lines sl
    where sl.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
     and sl.confirmed_need_line_revision_id=observation.current_confirmed_need_line_revision_id
     and sl.unit_id=observation.controlled_unit_id
     and sl.approved_quantity=observation.confirmed_quantity));
 return jsonb_build_object('complete',true,'confirmed_need_batch_id',p_batch,
  'validation_attempt_id',p_attempt,'projection',projection,'released_snapshot_ids',released_snapshots);
end;
$evidence$;
revoke all on function atlas_core.confirmed_need_historical_validation_evidence(uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function atlas_core.confirmed_need_historical_validation_evidence(uuid,uuid)
 to atlas_procurement_command_runtime;

-- A released status alone is not authority. Resolve each prior immutable
-- validation attempt once, then join exact prior successful release/snapshot/R/D.
create function atlas_core.confirmed_need_retained_release_evidence(p_batch uuid)
returns jsonb language sql stable security definer set search_path='' as $retained$
 with attempts as materialized (
  select distinct s.confirmed_need_validation_attempt_id attempt_id
  from atlas_planning.confirmed_need_releases rel
  join atlas_planning.confirmed_need_approval_snapshots s
   on s.confirmed_need_approval_snapshot_id=rel.confirmed_need_approval_snapshot_id
   and s.confirmed_need_batch_id=rel.confirmed_need_batch_id
   and s.source_kind=rel.source_kind
   and s.approved_version=rel.source_approved_batch_version
  where rel.confirmed_need_batch_id=p_batch and rel.source_kind='NEED_GENERATION'
   and rel.resulting_released_batch_version=s.approved_version+1
 ), evidence as materialized (
  select attempt_id,atlas_core.confirmed_need_historical_validation_complete(p_batch,attempt_id) complete
  from attempts
 ), authorized as (
  select r.confirmed_need_line_revision_id revision_id,
   o.current_confirmed_need_line_decision_id decision_id
  from evidence e
  join atlas_planning.confirmed_need_validation_attempts a
   on a.confirmed_need_validation_attempt_id=e.attempt_id and a.confirmed_need_batch_id=p_batch
  join atlas_planning.confirmed_need_approval_snapshots s
   on s.confirmed_need_validation_attempt_id=e.attempt_id and s.confirmed_need_batch_id=p_batch
   and s.source_kind='NEED_GENERATION' and s.approved_version=a.resulting_batch_version+1
  join atlas_planning.confirmed_need_releases rel
   on rel.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
   and rel.confirmed_need_batch_id=p_batch and rel.source_kind='NEED_GENERATION'
   and rel.source_approved_batch_version=s.approved_version
   and rel.resulting_released_batch_version=s.approved_version+1
  join atlas_planning.confirmed_need_snapshot_lines sl
   on sl.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
  join atlas_planning.confirmed_need_line_revisions r
   on r.confirmed_need_line_revision_id=sl.confirmed_need_line_revision_id
   and r.confirmed_need_batch_id=p_batch and r.source_kind='NEED_GENERATION'
  join atlas_planning.confirmed_need_validation_lines o
   on o.confirmed_need_validation_attempt_id=e.attempt_id
   and o.confirmed_need_line_id=r.confirmed_need_line_id
   and o.current_confirmed_need_line_revision_id=r.confirmed_need_line_revision_id
   and o.controlled_unit_id=sl.unit_id and o.confirmed_quantity=sl.approved_quantity
  where e.complete
   and sl.ingredient_id=r.ingredient_id and sl.unit_id=r.unit_id
   and sl.approved_quantity=r.confirmed_quantity
   and s.validated_fact_fingerprint is not null
   and (select count(*)from atlas_planning.confirmed_need_snapshot_lines member
    where member.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id)=a.line_count
   and not exists(select 1 from atlas_planning.confirmed_need_validation_lines observation
    where observation.confirmed_need_validation_attempt_id=e.attempt_id
    and not exists(select 1 from atlas_planning.confirmed_need_snapshot_lines member
     where member.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
      and member.confirmed_need_line_revision_id=observation.current_confirmed_need_line_revision_id
      and member.unit_id=observation.controlled_unit_id
      and member.approved_quantity=observation.confirmed_quantity))
 ), unambiguous as (
  select revision_id,min(decision_id::text) decision_id from authorized
  group by revision_id having count(distinct decision_id)=1 and bool_and(decision_id is not null)
 ) select coalesce(jsonb_object_agg(revision_id::text,decision_id),'{}'::jsonb)
 from unambiguous;
$retained$;
revoke all on function atlas_core.confirmed_need_retained_release_evidence(uuid)
 from public,anon,authenticated,service_role;

-- Preserve every legacy check/owner/ACL. Only the DRAFT-only predicate gets the
-- exact retained-release alternative; compute the batch evidence once.
do $validation_guard$
declare definition text:=pg_get_functiondef('atlas_core.rmvp_07_validation_evidence_complete(uuid,uuid,bigint)'::regprocedure);
 old text:=$old$            or revision.revision_status <> 'DRAFT'$old$;
 new text:=$new$            or not (revision.revision_status='DRAFT' or
              (revision.revision_status='RELEASED' and coalesce(
               retained.facts->>revision.confirmed_need_line_revision_id::text
                = decision.confirmed_need_line_decision_id::text,false)))$new$;
begin
 if position(old in definition)=0 or position('  select exists (' in definition)=0 then
  raise exception 'C retained validation guard anchor missing';end if;
 definition:=replace(definition,'  select exists (',
  '  with retained as materialized (select atlas_core.confirmed_need_retained_release_evidence(batch_id) facts) select exists (');
 definition:=replace(definition,'from atlas_planning.confirmed_need_validation_attempts attempt',
  'from atlas_planning.confirmed_need_validation_attempts attempt cross join retained');
 execute replace(definition,old,new);
end;
$validation_guard$;

do $approval_guard$
declare definition text:=pg_get_functiondef('atlas_planning.rmvp_07_approval_release_integrity()'::regprocedure);
 old text:=$old$            or revision.revision_status <> case
              when v_batch.batch_status = 'APPROVED' then 'APPROVED'
              else 'RELEASED'
            end$old$;
 new text:=$new$            or not (revision.revision_status = case
              when v_batch.batch_status = 'APPROVED' then 'APPROVED'
              else 'RELEASED' end
              or (v_batch.batch_status='APPROVED' and revision.revision_status='RELEASED'
               and coalesce(v_retained->>revision.confirmed_need_line_revision_id::text
                = line.current_confirmed_need_line_decision_id::text,false)))$new$;
begin
 if position(old in definition)=0 or position('  v_release atlas_planning.confirmed_need_releases%rowtype;' in definition)=0 then
  raise exception 'C retained approval guard anchor missing';end if;
 definition:=replace(definition,'  v_release atlas_planning.confirmed_need_releases%rowtype;',
  '  v_release atlas_planning.confirmed_need_releases%rowtype; v_retained jsonb;');
 definition:=replace(definition,'  if v_batch.current_confirmed_need_approval_snapshot_id is not null then',
  '  if v_batch.batch_status=''APPROVED'' then v_retained:=atlas_core.confirmed_need_retained_release_evidence(v_batch_id); end if;
  if v_batch.current_confirmed_need_approval_snapshot_id is not null then');
 execute replace(definition,old,new);
end;
$approval_guard$;
reset role;
set role atlas_owner;

-- All participants acquire contained days in the same ISO-date order, before
-- their pre-existing row/advisory locks. No browser may call this primitive.
create function atlas_core.confirmed_need_correction_lock_days(p_start date,p_end date)
returns void language plpgsql volatile security invoker set search_path='' as $days$
declare day date;
begin
 if p_start is null or p_end is null or not isfinite(p_start)or not isfinite(p_end)
  or p_end<p_start then
  raise exception using errcode='22023',message='Correction fence requires finite ordered dates';
 end if;
 for day in select p_start+offset_day from generate_series(0,p_end-p_start)offset_day
  order by offset_day loop
  perform pg_advisory_xact_lock(hashtextextended('PLANNING-CONTRACT-01:'||
   to_char(day,'YYYY-MM-DD')||':'||to_char(day,'YYYY-MM-DD'),0));
 end loop;
end;
$days$;
revoke all on function atlas_core.confirmed_need_correction_lock_days(date,date)
 from public,anon,authenticated,service_role;
grant execute on function atlas_core.confirmed_need_correction_lock_days(date,date)
 to atlas_need_generation_runtime,atlas_planning_materialization_runtime,
 atlas_planning_command_runtime,atlas_confirmed_need_review_runtime,
 atlas_procurement_command_runtime,atlas_dispatch_command_runtime;


reset role;
set role atlas_procurement_command_runtime;
-- Pure backend source universe. Include incomplete/zero current Need and every
-- retained PH root independently of applicability, Supplier eligibility or UI.
create function atlas_core.purchase_review_correction_context(p_batch uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $context$
declare batches uuid[]:=array[p_batch]; visited uuid[]:='{}'; families uuid[]:='{}';
 target uuid; batch record; sources jsonb:='[]'; items jsonb;
 first_day date; last_day date; allocation_fingerprint text;
begin
 if p_batch is null then return jsonb_build_object('available',false);end if;
 loop
  select id into target from unnest(batches)id where not id=any(visited)order by id limit 1;
  exit when not found;
  select b.period_start,b.period_end into batch from atlas_planning.confirmed_need_batches b
   where b.confirmed_need_batch_id=target and b.source_kind='NEED_GENERATION';
  if not found then return jsonb_build_object('available',false);end if;
  visited:=array_append(visited,target);
  first_day:=least(first_day,batch.period_start);last_day:=greatest(last_day,batch.period_end);
  items:=atlas_core.purchase_review_confirmed_source_universe(target);
  sources:=sources||items;
  select coalesce(array_agg(distinct id order by id),'{}')into batches from(
   select unnest(batches)id union all
   -- Raw batch identities are never filtered through a shaped projection.
   -- Invalidated/zero/incomplete/pending-later-attempt roots still serialize.
   select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
    where b.source_kind='NEED_GENERATION' and b.period_start<=batch.period_end
     and b.period_end>=batch.period_start
   union all
   select (item->>'source_confirmed_need_batch_id')::uuid from jsonb_array_elements(items)item
   union all
   select r.source_confirmed_need_batch_id from atlas_procurement.school_catering_allocation_families f
   join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
   where r.is_current and f.service_date between batch.period_start and batch.period_end
    and r.source_confirmed_need_batch_id is not null
   union all
   select hb.confirmed_need_batch_id from atlas_procurement.school_catering_allocation_families f
   join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
   join atlas_procurement.school_catering_allocation_family_contributions c using(family_revision_id)
   join atlas_planning.purchase_handoff_line_revisions lr using(purchase_handoff_line_revision_id)
   join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_revision_id)
   join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
   where r.is_current and f.service_date between batch.period_start and batch.period_end
  )roots where id is not null;
  select coalesce(array_agg(distinct id order by id),'{}')into families from(
   select unnest(families)id union all
   select f.family_id from atlas_procurement.school_catering_allocation_families f
   where f.service_date between batch.period_start and batch.period_end
    and exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions r
     where r.family_id=f.family_id and r.is_current)
  )represented;
 end loop;
 select coalesce(jsonb_agg(item order by item->>'source_confirmed_need_batch_id',
  item->>'service_date',item->>'delivery_location_id',item->>'ingredient_id',item->>'unit_id'),'[]')
 into sources from(select distinct value item from jsonb_array_elements(sources))canonical;
 select encode(sha256(convert_to(coalesce(jsonb_agg(jsonb_build_object(
  'family_id',f.family_id,'revision_id',r.family_revision_id,'splits',(
   select coalesce(jsonb_agg(jsonb_build_object('split_id',sp.supplier_split_id,
    'supplier_id',sp.supplier_id)order by sp.supplier_split_id),'[]')
   from atlas_procurement.school_catering_allocation_supplier_splits sp
   where sp.family_revision_id=r.family_revision_id))order by f.family_id),'[]')::text,'UTF8')),'hex')
 into allocation_fingerprint from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 where r.is_current and f.family_id=any(families);
 return jsonb_build_object('available',true,'allocation_lock_fingerprint',allocation_fingerprint,'batch_ids',to_jsonb(batches),
  'family_ids',to_jsonb(families),'period_start',first_day,'period_end',last_day,'sources',sources);
end;
$context$;
revoke all on function atlas_core.purchase_review_correction_context(uuid)
 from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_correction_context(uuid)
 to atlas_need_generation_runtime,atlas_confirmed_need_review_runtime,atlas_planning_command_runtime;


-- Resolve each historical (batch,attempt) once. Original decisions come through
-- immutable demandÃ¢â€ â€™approvalÃ¢â€ â€™validation observations, never today's pointers.
create function atlas_core.confirmed_need_handoff_membership(p_revision uuid)
returns jsonb language sql stable security definer set search_path='' as $membership$
 with bindings as materialized (
  select lr.purchase_handoff_line_revision_id,lr.confirmed_need_line_revision_id,
   lr.ingredient_id,lr.unit_id,lr.handoff_quantity,lr.service_date,lr.delivery_location_id,
   hl.confirmed_need_line_id,hb.confirmed_need_batch_id,
   hr.released_at,hr.released_by_actor_id,hr.revision_status,
   sl.confirmed_need_snapshot_line_id,sl.approved_quantity,
   s.confirmed_need_validation_attempt_id,s.confirmed_need_approval_snapshot_id
  from atlas_planning.purchase_handoff_revisions hr
  join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
  join atlas_planning.purchase_handoff_line_revisions lr using(purchase_handoff_revision_id)
  left join atlas_planning.purchase_handoff_lines hl
   on hl.purchase_handoff_line_id=lr.purchase_handoff_line_id
   and hl.purchase_handoff_batch_id=hb.purchase_handoff_batch_id
  left join atlas_planning.purchase_demand_references d
   on d.purchase_handoff_line_revision_id=lr.purchase_handoff_line_revision_id and d.source_kind='NEED_GENERATION'
  left join atlas_planning.confirmed_need_snapshot_lines sl
   on sl.confirmed_need_snapshot_line_id=d.confirmed_need_snapshot_line_id
   and sl.confirmed_need_line_revision_id=lr.confirmed_need_line_revision_id
   and sl.ingredient_id=lr.ingredient_id and sl.unit_id=lr.unit_id
   and sl.approved_quantity=lr.handoff_quantity and d.approved_quantity=lr.handoff_quantity
   and d.unit_id=lr.unit_id
  left join atlas_planning.confirmed_need_approval_snapshots s
   on s.confirmed_need_approval_snapshot_id=sl.confirmed_need_approval_snapshot_id
   and s.confirmed_need_batch_id=hb.confirmed_need_batch_id and s.source_kind='NEED_GENERATION'
  where hr.purchase_handoff_revision_id=p_revision
 ), pairs as materialized (
  select distinct confirmed_need_batch_id,confirmed_need_validation_attempt_id from bindings
  where confirmed_need_batch_id is not null and confirmed_need_validation_attempt_id is not null
 ), evidence as materialized (
  select p.*,atlas_core.confirmed_need_historical_validation_evidence(
   p.confirmed_need_batch_id,p.confirmed_need_validation_attempt_id) facts from pairs p
 ), members as (
  select b.*,e.facts->>'complete'='true' evidence_complete,
   coalesce((e.facts->'released_snapshot_ids') @> jsonb_build_array(b.confirmed_need_approval_snapshot_id),false) prior_release,
   f.value fact
  from bindings b left join evidence e
   on e.confirmed_need_batch_id=b.confirmed_need_batch_id
   and e.confirmed_need_validation_attempt_id=b.confirmed_need_validation_attempt_id
  left join lateral jsonb_array_elements(coalesce(e.facts#>'{projection,ordered_lines}','[]'))f(value)
   on f.value->>'confirmed_need_line_id'=b.confirmed_need_line_id::text
   and f.value->>'current_confirmed_need_line_revision_id'=b.confirmed_need_line_revision_id::text
 ), result as (
  select count(*)>0 and count(*)=count(distinct purchase_handoff_line_revision_id)
   and bool_and(coalesce(evidence_complete and prior_release
    and released_at is not null and released_by_actor_id is not null
    and revision_status in('RELEASED_TO_PROCUREMENT','INVALIDATED')
    and confirmed_need_snapshot_line_id is not null
    and fact->>'school_id' is not null and fact->>'customer_id' is not null
    and fact->>'current_confirmed_need_line_decision_id' is not null
    and fact->>'ingredient_id'=ingredient_id::text
    and fact->>'controlled_unit_id'=unit_id::text
    and fact->>'service_date'=service_date::text
    and fact->>'delivery_location_id'=delivery_location_id::text
    and (fact->>'confirmed_quantity')::numeric=handoff_quantity,false)) complete,
   coalesce(jsonb_agg(fact||jsonb_build_object(
    'purchase_handoff_line_revision_id',purchase_handoff_line_revision_id,
    'purchase_handoff_revision_id',p_revision,'source_confirmed_need_batch_id',confirmed_need_batch_id,
    'confirmed_need_snapshot_line_id',confirmed_need_snapshot_line_id,
    'validation_attempt_id',confirmed_need_validation_attempt_id)
    order by purchase_handoff_line_revision_id),'[]') facts
  from members
 ) select jsonb_build_object('complete',coalesce(complete,false),
  'members',case when complete then facts else '[]'::jsonb end)from result;
$membership$;
revoke all on function atlas_core.confirmed_need_handoff_membership(uuid)
 from public,anon,authenticated,service_role;

-- Existing exact signature/owner/security/ACL are preserved; one additional
-- private EXECUTE delegates row locking to the standalone Need prepare owner.
create or replace function atlas_core.purchase_review_lock_allocations(p_batch uuid)
returns void language plpgsql volatile security definer set search_path='' as $domain_locks$
declare initial jsonb; fresh jsonb; families uuid[]; batches uuid[]; item record;
begin
 initial:=atlas_core.purchase_review_correction_context(p_batch);
 if initial->>'available' is distinct from 'true' then return;end if;
 select array_agg(id::uuid order by id::uuid)into families
 from jsonb_array_elements_text(initial->'family_ids')id;
 select array_agg(id::uuid order by id::uuid)into batches
 from jsonb_array_elements_text(initial->'batch_ids')id;
 -- Lock EVERY Supplier/effective eligibility before any PH/family row, even
 -- retained PH revisions whose source_confirmed_need_batch_id is NULL.
 for item in select f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
  coalesce(jsonb_agg(jsonb_build_object('supplier_id',sp.supplier_id)order by sp.supplier_id)
   filter(where sp.supplier_id is not null),'[]')splits
  from atlas_procurement.school_catering_allocation_families f
  join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
  left join atlas_procurement.school_catering_allocation_supplier_splits sp using(family_revision_id)
  where r.is_current and f.family_id=any(families)
  group by f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
  order by f.ingredient_id::text,f.service_date::text,f.delivery_location_id::text,f.unit_id::text loop
  perform atlas_core.school_catering_lock_supplier_evidence(item.service_date,item.ingredient_id,item.splits,false);
 end loop;
 -- FOR UPDATE now prevents a KEY SHAREÃ¢â€ â€™UPDATE upgrade after family locks,
 -- while an incumbent PH Save holds KEY SHARE and waits for that family.
 perform 1 from atlas_planning.purchase_handoff_batches h
  where h.confirmed_need_batch_id=any(batches)order by h.purchase_handoff_batch_id for update;
 perform 1 from atlas_planning.purchase_handoff_revisions h
  where exists(select 1 from atlas_planning.purchase_handoff_batches b
   where b.purchase_handoff_batch_id=h.purchase_handoff_batch_id and b.confirmed_need_batch_id=any(batches))
  order by h.purchase_handoff_revision_id for update;
 perform 1 from atlas_procurement.school_catering_allocation_families f
  where f.family_id=any(families)order by f.family_id for update;
 fresh:=atlas_core.purchase_review_correction_context(p_batch);
 if fresh->>'available' is distinct from 'true'
  or not ((initial->'batch_ids') @> (fresh->'batch_ids'))
  or not ((initial->'family_ids') @> (fresh->'family_ids'))
  or initial->>'allocation_lock_fingerprint' is distinct from fresh->>'allocation_lock_fingerprint'then
  raise exception using errcode='40001',message='Correction allocation evidence changed while acquiring locks';
 end if;
end;
$domain_locks$;
grant execute on function atlas_core.purchase_review_lock_allocations(uuid)
 to atlas_need_generation_runtime;

reset role;
set role atlas_need_generation_runtime;

create function atlas_core.confirmed_need_correction_lock_roots(p_batch uuid)
returns jsonb language plpgsql volatile security definer set search_path='' as $roots$
declare initial jsonb; fresh jsonb; batches uuid[]; runs uuid[]; sets uuid[];
 source_run uuid; fresh_runs uuid[]; evaluations uuid[]; fresh_sets uuid[]; fresh_evaluations uuid[];
begin
 initial:=atlas_core.purchase_review_correction_context(p_batch);
 if initial->>'available' is distinct from 'true' then return initial;end if;
 select array_agg(id::uuid order by id::uuid)into batches
 from jsonb_array_elements_text(initial->'batch_ids')id;
 select array_agg(distinct input_set order by input_set)into sets from(
  select r.planning_input_set_id input_set from atlas_planning.need_generation_runs r
  where r.need_generation_run_id in(
   select b.current_need_generation_run_id from atlas_planning.confirmed_need_batches b
    where b.confirmed_need_batch_id=any(batches)
   union select b.origin_need_generation_run_id from atlas_planning.confirmed_need_batches b
    where b.confirmed_need_batch_id=any(batches)
   union select revision.need_generation_run_id from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_batch_id=any(batches))
 )input_sets;
 select coalesce(array_agg(r.need_generation_run_id order by r.need_generation_run_id),'{}')into runs
 from atlas_planning.need_generation_runs r where r.planning_input_set_id=any(sets);
 select coalesce(array_agg(e.planning_input_evaluation_id order by e.planning_input_evaluation_id),'{}')into evaluations
 from atlas_planning.planning_input_evaluations e where e.planning_input_set_id=any(sets);
 perform atlas_core.confirmed_need_correction_lock_days((initial->>'period_start')::date,
  (initial->>'period_end')::date);
 foreach source_run in array runs loop
  perform pg_advisory_xact_lock(hashtextextended('atlas:planning-correction:'||source_run::text,0));
 end loop;
 -- Match direct create_need_generation_run: input-setÃ¢â€ â€™evaluationÃ¢â€ â€™run, never
 -- an input/evaluation lock acquired late while holding a target run/CN row.
 perform 1 from atlas_planning.planning_input_sets s where s.planning_input_set_id=any(sets)
  order by s.planning_input_set_id for key share;
 perform 1 from atlas_planning.planning_input_evaluations e where e.planning_input_set_id=any(sets)
  order by e.planning_input_evaluation_id for key share;
 select coalesce(array_agg(r.need_generation_run_id order by r.need_generation_run_id),'{}')into fresh_runs
 from atlas_planning.need_generation_runs r where r.planning_input_set_id=any(sets);
 if fresh_runs is distinct from runs then
  raise exception using errcode='40001',message='Correction source roots changed before lock prefix';
 end if;
 perform 1 from atlas_planning.need_generation_runs r where r.need_generation_run_id=any(runs)
  order by r.need_generation_run_id for update;
 perform 1 from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=any(batches)
  order by b.confirmed_need_batch_id for update;
 -- Never lock immutable Need R/D FOR UPDATE before Supplier evidence: incumbent
 -- PH allocation Save may acquire FK KEY SHARE on them after Supplier locks.
 fresh:=atlas_core.purchase_review_correction_context(p_batch);
 select array_agg(distinct r.planning_input_set_id order by r.planning_input_set_id)into fresh_sets
 from atlas_planning.need_generation_runs r where r.need_generation_run_id in(
  select b.current_need_generation_run_id from atlas_planning.confirmed_need_batches b
   where b.confirmed_need_batch_id in(select id::uuid from jsonb_array_elements_text(fresh->'batch_ids')id)
  union select b.origin_need_generation_run_id from atlas_planning.confirmed_need_batches b
   where b.confirmed_need_batch_id in(select id::uuid from jsonb_array_elements_text(fresh->'batch_ids')id)
  union select revision.need_generation_run_id from atlas_planning.confirmed_need_line_revisions revision
   where revision.confirmed_need_batch_id in(select id::uuid from jsonb_array_elements_text(fresh->'batch_ids')id));
 select coalesce(array_agg(r.need_generation_run_id order by r.need_generation_run_id),'{}')into fresh_runs
 from atlas_planning.need_generation_runs r where r.planning_input_set_id=any(fresh_sets);
 select coalesce(array_agg(e.planning_input_evaluation_id order by e.planning_input_evaluation_id),'{}')into fresh_evaluations
 from atlas_planning.planning_input_evaluations e where e.planning_input_set_id=any(fresh_sets);
 if fresh->>'available' is distinct from 'true'
  or not ((initial->'batch_ids') @> (fresh->'batch_ids'))
  or not ((initial->'family_ids') @> (fresh->'family_ids'))
  or not coalesce(sets @> fresh_sets,false) or not(runs @> fresh_runs)
  or not(evaluations @> fresh_evaluations)
  or (fresh->>'period_start')::date<(initial->>'period_start')::date
  or (fresh->>'period_end')::date>(initial->>'period_end')::date then
  raise exception using errcode='40001',message='Correction source roots expanded after lock waits';
 end if;
 return fresh;
end;
$roots$;
revoke all on function atlas_core.confirmed_need_correction_lock_roots(uuid)
 from public,anon,authenticated,service_role;
grant execute on function atlas_core.confirmed_need_correction_lock_roots(uuid)
 to atlas_confirmed_need_review_runtime,atlas_planning_command_runtime;
reset role;
set role atlas_owner;


-- Exact closed caller list: preserve existing owners, ACLs, path/config and all
-- JWT/capability/scope/replay guards. No ordinary Save or pure shaped-read patch.
reset role;
do $early_prefixes$
declare target record; definition text; prior pg_proc%rowtype; updated pg_proc%rowtype;
begin
 for target in select * from(values
('atlas_api.prepare_planning_source_correction(jsonb)','atlas_need_generation_runtime',$anchor0$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');$anchor0$,$replacement0$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement0$),
('atlas_api.validate_confirmed_needs(jsonb)','atlas_confirmed_need_review_runtime',$anchor1$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');$anchor1$,$replacement1$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement1$),
('atlas_api.approve_confirmed_needs(jsonb)','atlas_confirmed_need_review_runtime',$anchor2$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');$anchor2$,$replacement2$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement2$),
('atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)','atlas_confirmed_need_review_runtime',$anchor3$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');$anchor3$,$replacement3$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement3$),
('atlas_api.release_confirmed_needs(jsonb)','atlas_confirmed_need_review_runtime',$anchor4$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');$anchor4$,$replacement4$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement4$),
('atlas_api.prepare_school_catering_purchase_orders(jsonb)','atlas_confirmed_need_review_runtime',$anchor5$  v_receipt:=(v_begin->>'receipt_id')::uuid;$anchor5$,$replacement5$  v_receipt:=(v_begin->>'receipt_id')::uuid;
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement5$),
('atlas_api.release_school_catering_purchase_handoff(jsonb)','atlas_planning_command_runtime',$anchor6$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');$anchor6$,$replacement6$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  -- C: all earlier source roots and complete domain evidence precede target locks.
  perform atlas_core.confirmed_need_correction_lock_roots(v_batch_id);
  perform atlas_core.purchase_review_lock_allocations(v_batch_id);$replacement6$),
('atlas_core.issue_223_execute_need_generation_v2(jsonb)','atlas_need_generation_runtime',$anchor7$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');$anchor7$,$replacement7$  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform atlas_core.confirmed_need_correction_lock_days(v_start,v_end);
  -- Direct create_need_generation_run is input-setÃ¢â€ â€™evaluationÃ¢â€ â€™run.
  perform 1 from atlas_planning.planning_input_sets source_set
   where source_set.period_start=v_start and source_set.period_end=v_end
   order by source_set.planning_input_set_id for key share;
  perform 1 from atlas_planning.planning_input_evaluations source_evaluation
   where source_evaluation.planning_input_set_id in(
    select source_set.planning_input_set_id from atlas_planning.planning_input_sets source_set
    where source_set.period_start=v_start and source_set.period_end=v_end)
   order by source_evaluation.planning_input_evaluation_id for key share;$replacement7$),
('atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)','atlas_planning_materialization_runtime',$anchor8$  perform pg_catalog.set_config('lock_timeout', '5s', true);$anchor8$,$replacement8$  if v_internal is null then
    perform atlas_core.confirmed_need_correction_lock_days(v_run.period_start,v_run.period_end);
  elsif exists(select 1 from generate_series(0,v_run.period_end-v_run.period_start)day_offset
    where not exists(select 1 from pg_locks held
     where held.pid=pg_backend_pid()and held.locktype='advisory'and held.granted and held.objsubid=1
      and ((held.classid::bigint<<32)|held.objid::bigint)=hashtextextended(
       'PLANNING-CONTRACT-01:'||to_char(v_run.period_start+day_offset,'YYYY-MM-DD')||':'||
       to_char(v_run.period_start+day_offset,'YYYY-MM-DD'),0)))then
    -- A nested parent must hold the entire prefix already; never block on a
    -- new earlier day while its run/input/CN rows are locked.
    raise exception using errcode='40001',message='Materializer parent lacks the complete day prefix';
  end if;

  perform pg_catalog.set_config('lock_timeout', '5s', true);$replacement8$),
('atlas_api.create_school_catering_purchase_order_drafts(jsonb)','atlas_procurement_command_runtime',$anchor9$  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');$anchor9$,$replacement9$  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');
  perform atlas_core.confirmed_need_correction_lock_days(v_date_start,v_date_end);
  v_ready_dates:='[]'::jsonb;v_skipped_dates:='[]'::jsonb;
  for v_date in select generate_series(v_date_start,v_date_end,interval '1 day')::date loop
    v_readiness := atlas_core.school_catering_po_date_readiness(v_date);
    if (v_readiness ->> 'ready')::boolean then
      v_ready_dates := v_ready_dates || jsonb_build_array(to_char(v_date,'YYYY-MM-DD'));
    else
      v_skipped_dates := v_skipped_dates || jsonb_build_array(v_readiness);
    end if;
  end loop;$replacement9$),
('atlas_api.create_school_catering_purchase_order_replacement(jsonb)','atlas_procurement_command_runtime',$anchor10$  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended($anchor10$,$replacement10$  perform atlas_core.confirmed_need_correction_lock_days(v_replaced.school_catering_service_date,v_replaced.school_catering_service_date);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended($replacement10$),
('atlas_api.release_school_catering_purchase_order(jsonb)','atlas_procurement_command_runtime',$anchor11$  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended($anchor11$,$replacement11$  perform atlas_core.confirmed_need_correction_lock_days(v_root.school_catering_service_date,v_root.school_catering_service_date);
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended($replacement11$),
('atlas_api.release_school_dispatch_document(jsonb)','atlas_dispatch_command_runtime',$anchor12$  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin->>'receipt_id');$anchor12$,$replacement12$  v_receipt := atlas_core.pa_05b_safe_uuid(v_begin->>'receipt_id');
  perform atlas_core.confirmed_need_correction_lock_days(v_date,v_date);$replacement12$))entries(signature,owner_name,anchor,replacement)loop
  select * into strict prior from pg_proc where oid=target.signature::regprocedure;
  if pg_get_userbyid(prior.proowner)<>target.owner_name then
   raise exception 'C early-prefix owner mismatch: %',target.signature;end if;
  definition:=pg_get_functiondef(prior.oid);
  if (length(definition)-length(replace(definition,target.anchor,'')))/length(target.anchor)<>1 then
   raise exception 'C early-prefix anchor mismatch: %',target.signature;end if;
  execute format('set local role %I',target.owner_name);
  execute replace(definition,target.anchor,target.replacement);
  reset role;
  select * into strict updated from pg_proc where oid=prior.oid;
  if (to_jsonb(prior)-'prosrc')is distinct from(to_jsonb(updated)-'prosrc')then
   raise exception 'C early-prefix changed catalog posture: %',target.signature;end if;
 end loop;
end;
$early_prefixes$;
set role atlas_procurement_command_runtime;

-- Backend-only resolved context: historical whole-batch evidence is resolved
-- once per Handoff revision, never once per family/line in a bulk consumer.
create function atlas_core.purchase_review_continuity_context(p_batch uuid)
returns jsonb language sql stable security definer set search_path='' as $continuity_context$
 with root as materialized(select atlas_core.purchase_review_correction_context(p_batch) facts)
 select facts||jsonb_build_object('handoffs',coalesce((
  select jsonb_agg(to_jsonb(hr)||jsonb_build_object(
   'confirmed_need_batch_id',hb.confirmed_need_batch_id,'handoff_status',hb.handoff_status,
   'membership',atlas_core.confirmed_need_handoff_membership(hr.purchase_handoff_revision_id))
   order by hr.purchase_handoff_batch_id,hr.revision_number)
  from atlas_planning.purchase_handoff_batches hb
  join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
  where facts->'batch_ids' @> jsonb_build_array(hb.confirmed_need_batch_id)),'[]'::jsonb))from root;
$continuity_context$;
revoke all on function atlas_core.purchase_review_continuity_context(uuid)
 from public,anon,authenticated,service_role;

-- Applicability is separate from every raw writer fingerprint. The optional
-- context is private/backend generated; it is never accepted by a public RPC.
create function atlas_core.purchase_review_family_continuity(p_family_revision uuid,p_mode text,p_context jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $continuity$
declare family record; revision record; source jsonb; sources jsonb; handoff jsonb;
 anchor record; members jsonb; facts jsonb; digest text; expected jsonb;
 actual jsonb; splits jsonb; contributions jsonb; latest jsonb; edge jsonb;
 visited uuid[]; cursor_id uuid; count_edges integer:=0; chain_count integer:=0;
 current_count integer; expected_revision integer; official boolean:=true; exact_current boolean:=true;
 failure jsonb:=jsonb_build_object('applicable',false,'classification','SOURCE_UNAVAILABLE');
begin
 if p_mode is null or p_mode not in('PROSPECTIVE','OFFICIAL')
  or p_context->>'available' is distinct from 'true' then return failure;end if;
 select * into revision from atlas_procurement.school_catering_allocation_family_revisions
  where family_revision_id=p_family_revision and is_current;
 if not found then return failure;end if;
 select * into strict family from atlas_procurement.school_catering_allocation_families
  where family_id=revision.family_id;
 select coalesce(jsonb_agg(s),'[]')into sources from jsonb_array_elements(p_context->'sources')s
 where s->>'service_date'=family.service_date::text
  and s->>'delivery_location_id'=family.delivery_location_id::text
  and s->>'ingredient_id'=family.ingredient_id::text and s->>'unit_id'=family.unit_id::text;
 if jsonb_array_length(sources)<>1 then return failure;end if;
 source:=sources->0;
 if p_mode='OFFICIAL'and source->>'batch_status' is distinct from 'RELEASED_FOR_PURCHASE_HANDOFF' then
  return jsonb_build_object('applicable',false,'classification','CORRECTION_PENDING');end if;
 if source->>'complete' is distinct from 'true'or source->>'family_quantity'is null then return failure;end if;
 if (source->>'family_quantity')::numeric=0 then
  return jsonb_build_object('applicable',false,'classification','AUTHORITATIVE_ZERO');end if;
 if (source->>'family_quantity')::numeric is distinct from revision.family_quantity
  or revision.unit_id is distinct from family.unit_id then return failure;end if;
 select jsonb_agg(to_jsonb(s)order by s.supplier_split_id)into splits
 from atlas_procurement.school_catering_allocation_supplier_splits s
 where s.family_revision_id=p_family_revision;
 if splits is null or(select sum((s->>'allocated_quantity')::numeric)
  from jsonb_array_elements(splits)s)is distinct from revision.family_quantity then return failure;end if;
 select jsonb_agg(to_jsonb(c)order by c.family_contribution_id)into contributions
 from atlas_procurement.school_catering_allocation_family_contributions c
 where c.family_revision_id=p_family_revision;
 if contributions is null then return failure;end if;
 if revision.source_kind='CONFIRMED_NEED'then
  if revision.source_confirmed_need_batch_id::text is distinct from source->>'source_confirmed_need_batch_id'
   or revision.source_fingerprint is distinct from source->>'source_fingerprint'then return failure;end if;
  select jsonb_agg(jsonb_build_array(c->>'confirmed_need_line_revision_id',
   c->>'confirmed_need_line_decision_id',(c->>'contribution_quantity')::numeric)
   order by c->>'confirmed_need_line_revision_id')into expected from jsonb_array_elements(contributions)c;
  select jsonb_agg(jsonb_build_array(c->>'confirmed_need_line_revision_id',
   c->>'confirmed_need_line_decision_id',(c->>'contribution_quantity')::numeric)
   order by c->>'confirmed_need_line_revision_id')into actual from jsonb_array_elements(source->'contributions')c;
  if expected is distinct from actual then return failure;end if;
  -- CN allocations must still have an explicit current released Handoff for
  -- official use. Promotion/retention consumers decide when to use this proof.
  select count(*)into current_count from jsonb_array_elements(p_context->'handoffs')h
   where h->>'confirmed_need_batch_id'=source->>'source_confirmed_need_batch_id'
    and h->>'is_current'='true'and h->>'revision_status'='RELEASED_TO_PROCUREMENT'
    and h->>'handoff_status'='RELEASED_TO_PROCUREMENT';
  official:=current_count=1;
  if official then
   select h into handoff from jsonb_array_elements(p_context->'handoffs')h
    where h->>'confirmed_need_batch_id'=source->>'source_confirmed_need_batch_id'
     and h->>'is_current'='true'and h->>'revision_status'='RELEASED_TO_PROCUREMENT'
     and h->>'handoff_status'='RELEASED_TO_PROCUREMENT';
   if handoff#>>'{membership,complete}'is distinct from 'true'then return failure;end if;
   select jsonb_agg(m-array['line_sort_position','purchase_handoff_line_revision_id',
    'purchase_handoff_revision_id','source_confirmed_need_batch_id','confirmed_need_snapshot_line_id',
    'validation_attempt_id']order by m->>'confirmed_need_line_id')into facts
   from jsonb_array_elements(handoff#>'{membership,members}')m
   where m->>'service_date'=family.service_date::text and m->>'delivery_location_id'=family.delivery_location_id::text
    and m->>'ingredient_id'=family.ingredient_id::text and m->>'controlled_unit_id'=family.unit_id::text;
   digest:=encode(sha256(convert_to(jsonb_build_object('batch_id',
    source->'source_confirmed_need_batch_id','facts',facts)::text,'UTF8')),'hex');
   if digest is distinct from source->>'source_fingerprint'then return failure;end if;
  end if;
 else
  -- The retained contributions must be the complete exact original PH family.
  select jsonb_agg(jsonb_build_array(c->>'purchase_handoff_line_revision_id',
   (c->>'contribution_quantity')::numeric)order by c->>'purchase_handoff_line_revision_id')
  into expected from jsonb_array_elements(contributions)c;
  select jsonb_agg(jsonb_build_array(m->>'purchase_handoff_line_revision_id',
   (m->>'confirmed_quantity')::numeric)order by m->>'purchase_handoff_line_revision_id')into actual
  from jsonb_array_elements(p_context->'handoffs')h
  cross join lateral jsonb_array_elements(h#>'{membership,members}')m
  where exists(select 1 from jsonb_array_elements(contributions)c
   join atlas_planning.purchase_handoff_line_revisions lr
    on lr.purchase_handoff_line_revision_id=(c->>'purchase_handoff_line_revision_id')::uuid
   where lr.purchase_handoff_revision_id=(h->>'purchase_handoff_revision_id')::uuid)
   and m->>'service_date'=family.service_date::text and m->>'delivery_location_id'=family.delivery_location_id::text
   and m->>'ingredient_id'=family.ingredient_id::text and m->>'controlled_unit_id'=family.unit_id::text;
  if expected is distinct from actual then return failure;end if;
  for anchor in select distinct hr.purchase_handoff_revision_id,hr.purchase_handoff_batch_id,hb.confirmed_need_batch_id
   from atlas_procurement.school_catering_allocation_family_contributions c
   join atlas_planning.purchase_handoff_line_revisions lr using(purchase_handoff_line_revision_id)
   join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_revision_id)
   join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
   where c.family_revision_id=p_family_revision loop
   if anchor.confirmed_need_batch_id::text is distinct from source->>'source_confirmed_need_batch_id'then return failure;end if;
   select h into latest from jsonb_array_elements(p_context->'handoffs')h
    where h->>'purchase_handoff_batch_id'=anchor.purchase_handoff_batch_id::text
    order by(h->>'revision_number')::integer desc limit 1;
   if latest is null then return failure;end if;
   official:=official and latest->>'is_current'='true'and latest->>'revision_status'='RELEASED_TO_PROCUREMENT'
    and latest->>'handoff_status'='RELEASED_TO_PROCUREMENT';
   exact_current:=exact_current and latest->>'purchase_handoff_revision_id'=anchor.purchase_handoff_revision_id::text;
   cursor_id:=(latest->>'purchase_handoff_revision_id')::uuid;
   expected_revision:=(latest->>'revision_number')::integer;visited:='{}';
   loop
    if cursor_id is null or cursor_id=any(visited)then return failure;end if;
    visited:=array_append(visited,cursor_id);
    select h into edge from jsonb_array_elements(p_context->'handoffs')h
     where h->>'purchase_handoff_revision_id'=cursor_id::text
      and h->>'purchase_handoff_batch_id'=anchor.purchase_handoff_batch_id::text;
    if edge is null or edge#>>'{membership,complete}'is distinct from 'true'
     or(edge->>'revision_number')::integer is distinct from expected_revision then return failure;end if;
    select jsonb_agg(m-array['line_sort_position','purchase_handoff_line_revision_id',
     'purchase_handoff_revision_id','source_confirmed_need_batch_id','confirmed_need_snapshot_line_id',
     'validation_attempt_id']order by m->>'confirmed_need_line_id')into facts
    from jsonb_array_elements(edge#>'{membership,members}')m
    where m->>'service_date'=family.service_date::text and m->>'delivery_location_id'=family.delivery_location_id::text
     and m->>'ingredient_id'=family.ingredient_id::text and m->>'controlled_unit_id'=family.unit_id::text;
    if facts is null then return failure;end if;
    digest:=encode(sha256(convert_to(jsonb_build_object('batch_id',anchor.confirmed_need_batch_id,'facts',facts)::text,'UTF8')),'hex');
    if digest is distinct from source->>'source_fingerprint'then return failure;end if;
    count_edges:=count_edges+1;
    exit when cursor_id=anchor.purchase_handoff_revision_id;
    cursor_id:=(edge->>'predecessor_revision_id')::uuid;
    expected_revision:=expected_revision-1;
   end loop;
   chain_count:=chain_count+1;
  end loop;
  if chain_count<>1 then return failure;end if;
 end if;
 if p_mode='OFFICIAL'and not coalesce(official,false)then
  return jsonb_build_object('applicable',false,'classification','CORRECTION_PENDING');end if;
 return jsonb_build_object('applicable',true,'classification',case when p_mode='PROSPECTIVE'
  then 'PROSPECTIVE_UNCHANGED'when exact_current then 'EXACT_CURRENT'else 'OFFICIAL_CONTINUITY'end,
  'proof',jsonb_build_object('family_revision_id',p_family_revision,'raw_source_fingerprint',revision.source_fingerprint,
   'confirmed_source_fingerprint',source->'source_fingerprint','contributions',contributions,
   'supplier_splits',splits,'checked_handoff_revisions',count_edges));
end;
$continuity$;
revoke all on function atlas_core.purchase_review_family_continuity(uuid,text,jsonb)
 from public,anon,authenticated,service_role;

create function atlas_core.purchase_review_family_continuity(p_family_revision uuid,p_mode text)
returns jsonb language plpgsql stable security definer set search_path='' as $continuity_entry$
declare batch_id uuid;context jsonb;
begin
 select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)into batch_id
 from atlas_procurement.school_catering_allocation_family_revisions r
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where r.family_revision_id=p_family_revision;
 if batch_id is null then return jsonb_build_object('applicable',false,'classification','SOURCE_UNAVAILABLE');end if;
 context:=atlas_core.purchase_review_continuity_context(batch_id);
 return atlas_core.purchase_review_family_continuity(p_family_revision,p_mode,context);
end;
$continuity_entry$;
revoke all on function atlas_core.purchase_review_family_continuity(uuid,text)
 from public,anon,authenticated,service_role;
reset role;
set role atlas_owner;

-- This bridge is optional disclosure only; no Need proposal/write path binds it.
reset role;
set role atlas_read_runtime;
create function atlas_core.confirmed_need_correction_procurement_details(
 p_actor uuid,p_date date,p_location uuid,p_ingredient uuid,p_unit uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $details$
declare denied jsonb;details jsonb;orders jsonb;
 empty_result jsonb:=jsonb_build_object('procurement_details_coverage','AUTHORIZED_DETAILS_ONLY',
  'procurement_details','[]'::jsonb,'purchase_order_coverage','AUTHORIZED_DOCUMENTS_ONLY','purchase_orders','[]'::jsonb);
begin
 denied:=atlas_core.pa_05b_authorize_actor('{}',p_actor,'procurement.school_catering.read',
  'PROCUREMENT','get_confirmed_need_correction_preview',null,null,null);
 if(denied is not null and denied->>'error_code'is distinct from 'SCOPE_DENIED')
  or not atlas_core.school_catering_actor_has_scope(p_actor,null,null,p_location)then return empty_result;end if;
 select jsonb_agg(jsonb_build_object('family_id',f.family_id,'family_revision_id',r.family_revision_id,
  'family_quantity',r.family_quantity::text,'decision_origin',r.decision_origin,
  'supplier_splits',(select jsonb_agg(jsonb_build_object('supplier_split_id',s.supplier_split_id,
   'supplier_id',s.supplier_id,'supplier_name',sp.supplier_name,'allocated_quantity',s.allocated_quantity::text,
   'split_ratio',s.split_ratio::text,'decision_origin',s.decision_origin,'supplier_note',s.supplier_note)
   order by s.supplier_split_id)from atlas_procurement.school_catering_allocation_supplier_splits s
   join atlas_admin.suppliers sp using(supplier_id)where s.family_revision_id=r.family_revision_id))order by f.family_id)
 into details from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 where r.is_current and row(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)
  =row(p_date,p_location,p_ingredient,p_unit);
 select jsonb_agg(jsonb_build_object('purchase_order_id',po.purchase_order_id,
  'purchase_order_revision_id',rev.purchase_order_revision_id,'document_number',po.document_number,
  'purchase_order_status',po.purchase_order_status,'supplier_id',po.supplier_id,
  'supplier_name',coalesce(nullif(btrim(rev.supplier_name_snapshot),''),'Supplier label unavailable'),
  'lines',(select jsonb_agg(jsonb_build_object('purchase_order_line_id',lr.purchase_order_line_id,
   'ingredient_id',lr.ingredient_id,'unit_id',lr.unit_id,'ordered_quantity',lr.ordered_quantity::text,
   'school_breakdown',lr.school_breakdown_snapshot,'supplier_note',lr.supplier_note_snapshot)
   order by lr.purchase_order_line_revision_id)from atlas_procurement.purchase_order_line_revisions lr
   where lr.purchase_order_revision_id=rev.purchase_order_revision_id))order by po.purchase_order_id)
 into orders from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where rev.is_current and po.purchase_order_kind='SCHOOL_CATERING'
  and atlas_core.school_catering_purchase_order_actor_has_full_scope(p_actor,po.purchase_order_id)
  and exists(select 1 from atlas_procurement.purchase_order_line_revisions lr
   join atlas_procurement.school_catering_allocation_supplier_splits s
    on s.supplier_split_id=lr.school_catering_allocation_supplier_split_id
   join atlas_procurement.school_catering_allocation_family_revisions r on r.family_revision_id=s.family_revision_id
   join atlas_procurement.school_catering_allocation_families f using(family_id)
   where lr.purchase_order_revision_id=rev.purchase_order_revision_id
    and row(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)=row(p_date,p_location,p_ingredient,p_unit));
 return empty_result||jsonb_build_object('procurement_details',coalesce(details,'[]'),
  'purchase_orders',coalesce(orders,'[]'));
end;$details$;
revoke all on function atlas_core.confirmed_need_correction_procurement_details(uuid,date,uuid,uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function atlas_core.confirmed_need_correction_procurement_details(uuid,date,uuid,uuid,uuid)
 to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_read_runtime;
create function atlas_core.confirmed_need_correction_source_current(p_run uuid)
returns boolean language plpgsql stable security definer set search_path='' as $source_current$
declare run atlas_planning.need_generation_runs%rowtype;preflight jsonb;
begin
 select * into run from atlas_planning.need_generation_runs where need_generation_run_id=p_run;
 if not found then return false;end if;
 preflight:=atlas_core.planning_contract_01_preflight_payload(run.period_start,run.period_end,null);
 return coalesce(preflight->>'downstream_currentness'='CURRENT'
  and preflight#>>'{current_need,need_generation_run_id}'=p_run::text
  and preflight#>>'{current_need,need_generation_run_version}'=run.version::text,false);
end;$source_current$;
revoke all on function atlas_core.confirmed_need_correction_source_current(uuid)
 from public,anon,authenticated,service_role;
grant execute on function atlas_core.confirmed_need_correction_source_current(uuid)to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_confirmed_need_review_runtime;

-- Share the exact incumbent evaluator. Ordinary callers retain its lifecycle,
-- errors and hash; only the private correction route admits a released batch.
do $quantity_evaluator$
declare original text:=pg_get_functiondef('atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb)'::regprocedure);
 signature text:='batch_id uuid, expected_batch_version bigint, requested_lines jsonb';
 anchor text:=$old$if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then$old$;
begin
 if strpos(original,signature)=0 or strpos(original,anchor)=0 then
  raise exception 'C canonical quantity evaluator anchor mismatch';end if;
 execute replace(replace(original,signature,signature||', p_correction boolean'),anchor,
  $new$if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
   and not(p_correction and v_batch.batch_status='RELEASED_FOR_PURCHASE_HANDOFF') then$new$);
 execute substring(original from 1 for strpos(original,'AS $function$')-1)||$wrapper$AS $function$
 begin return atlas_core.rmvp_05_canonical_preview(batch_id,expected_batch_version,requested_lines,false);end;
 $function$;$wrapper$;
end;$quantity_evaluator$;
revoke all on function atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb,boolean)
 from public,anon,authenticated,service_role;

create function atlas_core.confirmed_need_correction_request_valid(request jsonb,p_write boolean)
returns boolean language plpgsql immutable set search_path='' as $closed$
declare payload jsonb:=request->'payload';keys text[];field text;
begin
 if request is null or jsonb_typeof(request)<>'object'or jsonb_typeof(payload)is distinct from 'object'then return false;end if;
 keys:=array['contract_version','requested_by_auth_subject','correlation_id','payload'];
 if p_write then keys:=keys||array['command_id','idempotency_key','expected_version','requested_at','reason_code','reason_note'];end if;
 if request-keys<>'{}'::jsonb or not(request?&keys)
  or request->>'contract_version'is distinct from 'CONFIRMED-NEED-CORRECTION.v1'
  or atlas_core.pa_05b_safe_uuid(request->>'requested_by_auth_subject')is null
  or atlas_core.pa_05b_safe_uuid(request->>'correlation_id')is null then return false;end if;
 foreach field in array array['requested_by_auth_subject','correlation_id']loop
  if jsonb_typeof(request->field)is distinct from 'string'then return false;end if;
 end loop;
 keys:=array['need_generation_run_id','expected_need_generation_run_version','confirmed_need_batch_id',
  'expected_confirmed_need_batch_version','confirmed_need_line_id','expected_current_revision_id',
  'expected_current_decision_id','proposed_confirmed_quantity','reason_code','reason_note'];
 if p_write then keys:=keys||'proposal_fingerprint'::text;end if;
 if payload-keys<>'{}'::jsonb or not(payload?&keys)then return false;end if;
 foreach field in array array['need_generation_run_id','confirmed_need_batch_id','confirmed_need_line_id',
  'expected_current_revision_id','expected_current_decision_id']loop
  if jsonb_typeof(payload->field)is distinct from 'string'
   or atlas_core.pa_05b_safe_uuid(payload->>field)is null then return false;end if;
 end loop;
 foreach field in array array['expected_need_generation_run_version','expected_confirmed_need_batch_version']loop
  if jsonb_typeof(payload->field)is distinct from 'number'
   or coalesce(atlas_core.pa_05b_safe_bigint(payload->>field),0)<1 then return false;end if;
 end loop;
 if jsonb_typeof(payload->'proposed_confirmed_quantity')is distinct from 'string'
  or jsonb_typeof(payload->'reason_code')is distinct from 'string'
  or jsonb_typeof(payload->'reason_note')not in('string','null')then return false;end if;
 if p_write and(jsonb_typeof(request->'expected_version')is distinct from 'number'
  or atlas_core.pa_05b_safe_bigint(request->>'expected_version')is distinct from
   atlas_core.pa_05b_safe_bigint(payload->>'expected_confirmed_need_batch_version')
  or jsonb_typeof(request->'command_id')is distinct from 'string'
  or atlas_core.pa_05b_safe_uuid(request->>'command_id')is null
  or jsonb_typeof(request->'requested_at')is distinct from 'string'
  or atlas_core.pa_05b_safe_timestamptz(request->>'requested_at')is null
  or jsonb_typeof(request->'idempotency_key')is distinct from 'string'
  or coalesce(length(btrim(request->>'idempotency_key')),0)not between 1 and 200
  or request->>'reason_code'is distinct from 'CONFIRMED_NEED_CORRECTION_SAVED'
  or jsonb_typeof(request->'reason_note')is distinct from 'string'
  or coalesce(length(btrim(request->>'reason_note')),0)=0
  or jsonb_typeof(payload->'proposal_fingerprint')is distinct from 'string'
  or payload->>'proposal_fingerprint'!~'^[0-9a-f]{64}$')then return false;end if;
 return true;
end;$closed$;
revoke all on function atlas_core.confirmed_need_correction_request_valid(jsonb,boolean)
 from public,anon,authenticated,service_role;

create function atlas_core.confirmed_need_correction_proposal(payload jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $proposal$
declare batch atlas_planning.confirmed_need_batches%rowtype;run atlas_planning.need_generation_runs%rowtype;
 line atlas_planning.confirmed_need_line_revisions%rowtype;preview jsonb;item jsonb;family jsonb;
 proposal jsonb;fingerprint text;sources jsonb;source jsonb;raw_members jsonb;display jsonb;
begin
 select * into batch from atlas_planning.confirmed_need_batches
 where confirmed_need_batch_id=(payload->>'confirmed_need_batch_id')::uuid and source_kind='NEED_GENERATION';
 select * into run from atlas_planning.need_generation_runs
 where need_generation_run_id=(payload->>'need_generation_run_id')::uuid;
 if batch.confirmed_need_batch_id is null or run.need_generation_run_id is null
  or batch.current_need_generation_run_id is distinct from run.need_generation_run_id then
  return jsonb_build_object('success',false,'error_code','CORRECTION_CHAIN_NOT_FOUND');end if;
 if batch.version<>(payload->>'expected_confirmed_need_batch_version')::bigint
  or run.version<>(payload->>'expected_need_generation_run_version')::bigint then
  return jsonb_build_object('success',false,'error_code','STALE_VERSION');end if;
 if batch.batch_status<>'RELEASED_FOR_PURCHASE_HANDOFF'then
  return jsonb_build_object('success',false,'error_code','CORRECTION_NOT_APPLICABLE');end if;
 if run.run_status<>'RELEASED_FOR_CONFIRMATION'or exists(select 1 from atlas_planning.need_generation_runs later
  where later.planning_input_set_id=run.planning_input_set_id and later.attempt_ordinal>run.attempt_ordinal)then
  return jsonb_build_object('success',false,'error_code','STALE_CONFIRMED_NEED_SOURCE');end if;
 if not atlas_core.confirmed_need_correction_source_current(run.need_generation_run_id)then
  return jsonb_build_object('success',false,'error_code','STALE_CONFIRMED_NEED_SOURCE');end if;
 select r.* into line from atlas_planning.confirmed_need_line_revisions r
 join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
 where r.confirmed_need_line_revision_id=(payload->>'expected_current_revision_id')::uuid
  and r.confirmed_need_line_id=(payload->>'confirmed_need_line_id')::uuid and r.is_current
  and r.confirmed_need_batch_id=batch.confirmed_need_batch_id
  and l.current_confirmed_need_line_decision_id=(payload->>'expected_current_decision_id')::uuid;
 if found and payload->>'proposed_confirmed_quantity'~'^(0|[1-9][0-9]{0,13})(\.[0-9]{1,6})?$'
  and(payload->>'proposed_confirmed_quantity')::numeric=line.confirmed_quantity then
  return jsonb_build_object('success',false,'error_code','NO_APPLICABLE_CORRECTION');end if;
 preview:=atlas_core.rmvp_05_canonical_preview(batch.confirmed_need_batch_id,batch.version,
  jsonb_build_array(payload-array['need_generation_run_id','expected_need_generation_run_version',
   'confirmed_need_batch_id','expected_confirmed_need_batch_version','proposal_fingerprint']),true);
 if preview->>'success'is distinct from 'true'then return preview;end if;
 item:=preview#>'{ordered_preview_lines,0}';
 select * into strict line from atlas_planning.confirmed_need_line_revisions
 where confirmed_need_line_revision_id=(item->>'current_revision_id')::uuid;
 if line.confirmed_quantity=(item->>'confirmed_quantity_after')::numeric then
  return jsonb_build_object('success',false,'error_code','NO_APPLICABLE_CORRECTION');end if;
 select coalesce(jsonb_agg(s),'[]')into sources
 from atlas_core.purchase_review_confirmed_sources(line.service_date,line.service_date)s
 where s->>'delivery_location_id'=line.delivery_location_id::text and s->>'ingredient_id'=line.ingredient_id::text
  and s->>'unit_id'=line.unit_id::text;
 if jsonb_array_length(sources)<>1 then
  return jsonb_build_object('success',false,'error_code','CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING');end if;
 source:=sources->0;
 if source->>'complete'is distinct from 'true'or source->>'source_confirmed_need_batch_id'is distinct from batch.confirmed_need_batch_id::text then
  return jsonb_build_object('success',false,'error_code','CONFIRMED_SOURCE_INCOMPLETE');end if;
 select jsonb_build_object('service_date',line.service_date,'delivery_location_id',line.delivery_location_id,
  'ingredient_id',line.ingredient_id,'unit_id',line.unit_id,
  'quantity_before',sum(r.confirmed_quantity)::numeric(20,6)::text,
  'quantity_after',(sum(r.confirmed_quantity)+(item->>'confirmed_quantity_after')::numeric-line.confirmed_quantity)::numeric(20,6)::text,
  'contributions',jsonb_agg(jsonb_build_object('confirmed_need_batch_id',r.confirmed_need_batch_id,
   'confirmed_need_line_id',r.confirmed_need_line_id,'revision_id',r.confirmed_need_line_revision_id,
   'decision_id',l.current_confirmed_need_line_decision_id,'school_id',r.school_id,'customer_id',r.customer_id,
   'delivery_location_id',r.delivery_location_id,'quantity',r.confirmed_quantity::text,
   'source_membership',(select jsonb_agg(to_jsonb(c)order by c.theoretical_need_line_id)
    from atlas_planning.confirmed_need_line_revision_contributions c
    where c.confirmed_need_line_revision_id=r.confirmed_need_line_revision_id))order by r.confirmed_need_line_id))
 into family from atlas_planning.confirmed_need_line_revisions r
 join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
 where r.is_current and r.source_kind='NEED_GENERATION'and r.service_date=line.service_date
  and r.delivery_location_id=line.delivery_location_id and r.ingredient_id=line.ingredient_id and r.unit_id=line.unit_id;
 select jsonb_agg(jsonb_build_array(m->>'revision_id',m->>'decision_id',m->>'school_id',m->>'customer_id',
  (m->>'quantity')::numeric)order by m->>'revision_id')into raw_members from jsonb_array_elements(family->'contributions')m;
 if raw_members is distinct from(select jsonb_agg(jsonb_build_array(m->>'confirmed_need_line_revision_id',
  m->>'confirmed_need_line_decision_id',m->>'school_id',m->>'customer_id',(m->>'contribution_quantity')::numeric)
  order by m->>'confirmed_need_line_revision_id')from jsonb_array_elements(source->'contributions')m)
  or family->>'quantity_before'is distinct from source->>'family_quantity'then
  return jsonb_build_object('success',false,'error_code','CONFIRMED_SOURCE_INCOMPLETE');end if;
 proposal:=jsonb_build_object('payload',payload-'proposal_fingerprint','canonical_preview_hash',preview->'preview_hash','family',family);
 fingerprint:=encode(sha256(convert_to(proposal::text,'UTF8')),'hex');
 select jsonb_build_object('ingredient_name',ingredient.ingredient_name,'delivery_location_name',location.location_name,
  'unit_name',case when nullif(btrim(unit.unit_name),'')is not null
   and unit.unit_name!~*'^(v1[-_]|rmvp[-_]|[0-9a-f]{8}-[0-9a-f]{4}-)'then unit.unit_name else null end,
  'schools',(select jsonb_agg(jsonb_build_object('confirmed_need_line_id',member->'confirmed_need_line_id',
   'school_id',member->'school_id','school_name',school.school_name,'customer_id',member->'customer_id',
   'customer_name',customer.customer_name,'delivery_location_id',member->'delivery_location_id')
   order by member->>'confirmed_need_line_id')from jsonb_array_elements(family->'contributions')member
   join atlas_admin.schools school on school.school_id=(member->>'school_id')::uuid
   join atlas_admin.customers customer on customer.customer_id=(member->>'customer_id')::uuid))
 into display from atlas_admin.ingredients ingredient cross join atlas_admin.delivery_locations location
 cross join atlas_admin.units unit where ingredient.ingredient_id=line.ingredient_id
  and location.delivery_location_id=line.delivery_location_id and unit.unit_id=line.unit_id;
 return jsonb_build_object('success',true,'proposal_fingerprint',fingerprint,'family',family,
  'display',display,
  'quantity',jsonb_build_object('before',line.confirmed_quantity::text,'after',item->'confirmed_quantity_after',
   'delta',((item->>'confirmed_quantity_after')::numeric-line.confirmed_quantity)::numeric(20,6)::text),
  'target',payload-'proposal_fingerprint','canonical_preview',preview);
end;$proposal$;
revoke all on function atlas_core.confirmed_need_correction_proposal(jsonb)
 from public,anon,authenticated,service_role;

create function atlas_api.get_confirmed_need_correction_preview(request jsonb)
returns jsonb language plpgsql stable security definer set search_path='' as $correction_preview$
declare name constant text:='get_confirmed_need_correction_preview';context jsonb;answer jsonb;can_correct boolean:=true;cap text;
begin
 if not atlas_core.confirmed_need_correction_request_valid(request,false)then
  return atlas_core.d037_error(request,'CONFIRMED-NEED-CORRECTION.v1',name,
   'VALIDATION_FAILED','The correction preview request is invalid.')
   ||jsonb_build_object('read_name',name,'write_certainty','NO_WRITE');end if;
 context:=atlas_core.rmvp_05_authorize_global(request,'confirmed_need_review.read',name,true);
 if context?'error'then return(context->'error')||jsonb_build_object('contract_version','CONFIRMED-NEED-CORRECTION.v1');end if;
 answer:=atlas_core.confirmed_need_correction_proposal(request->'payload');
 foreach cap in array array['planning.need_generation.write','confirmed_need_release.release','confirmed_need_quantities.confirm']loop
  if atlas_core.rmvp_05_authorize_global(request,cap,name,true)?'error'then can_correct:=false;end if;
 end loop;
 answer:=answer||jsonb_build_object('contract_version','CONFIRMED-NEED-CORRECTION.v1','read_name',name,
  'write_certainty','NO_WRITE','allowed_actions',jsonb_build_object('correct',can_correct and coalesce(answer->>'success'='true',false)),
  'disabled_reasons',jsonb_build_object('correct',case when not can_correct then 'CORRECTION_AUTHORITY_REQUIRED'
   when answer->>'success'is distinct from 'true'then answer->>'error_code'else null end),
  'procurement_details_coverage','AUTHORIZED_DETAILS_ONLY','procurement_details','[]'::jsonb,
  'purchase_order_coverage','AUTHORIZED_DOCUMENTS_ONLY','purchase_orders','[]'::jsonb);
 if answer->>'success'='true'then
  answer:=answer||atlas_core.confirmed_need_correction_procurement_details((context->>'actor_id')::uuid,
   (answer#>>'{family,service_date}')::date,(answer#>>'{family,delivery_location_id}')::uuid,
   (answer#>>'{family,ingredient_id}')::uuid,(answer#>>'{family,unit_id}')::uuid);
 end if;
 return answer;
end;$correction_preview$;
revoke all on function atlas_api.get_confirmed_need_correction_preview(jsonb)from public,anon,service_role;
grant execute on function atlas_api.get_confirmed_need_correction_preview(jsonb)to authenticated;

create function atlas_api.correct_confirmed_need(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $correct$
declare name constant text:='correct_confirmed_need';contract constant text:='CONFIRMED-NEED-CORRECTION.v1';
 payload jsonb:=request->'payload';context jsonb;actor uuid;cap text;started jsonb;receipt uuid;
 proposal jsonb;prepared jsonb;saved jsonb;child jsonb;failed jsonb;answer jsonb;
 prepare_id uuid;save_id uuid;
begin
 if not atlas_core.confirmed_need_correction_request_valid(request,true)then
  return atlas_core.d037_error(request,contract,name,'VALIDATION_FAILED','The correction command request is invalid.');end if;
 foreach cap in array array['planning.need_generation.write','confirmed_need_release.release','confirmed_need_quantities.confirm']loop
  context:=atlas_core.rmvp_05_authorize_global(request,cap,name,false);
  if context?'error'then return(context->'error')||jsonb_build_object('contract_version',contract);end if;
 end loop;
 actor:=(context->>'actor_id')::uuid;
 started:=atlas_core.pa_05b_begin_command(request,actor,name,'PLANNING','ConfirmedNeedBatch:'||(payload->>'confirmed_need_batch_id'));
 if started->>'status'<>'NEW'then
  return(started->'response')||jsonb_build_object('contract_version',contract)
   ||case when started#>>'{response,success}'='true'then '{}'::jsonb else
    jsonb_build_object('write_certainty','NO_COMMITTED_CHANGE','refresh_read','get_confirmed_need_review')end;
 end if;
 receipt:=(started->>'receipt_id')::uuid;
 perform atlas_core.confirmed_need_correction_lock_roots((payload->>'confirmed_need_batch_id')::uuid);
 perform atlas_core.purchase_review_lock_allocations((payload->>'confirmed_need_batch_id')::uuid);
 proposal:=atlas_core.confirmed_need_correction_proposal(payload);
 if proposal->>'success'is distinct from 'true'or proposal->>'proposal_fingerprint'is distinct from payload->>'proposal_fingerprint'then
  return atlas_core.pa_05b_finish_command(receipt,atlas_core.d037_error(request,contract,name,
   case when proposal->>'success'='true'then 'STALE_CORRECTION_PROPOSAL'else proposal->>'error_code'end,
   'Refresh and review the exact quantity correction before saving.'),false);end if;
 prepare_id:=md5(receipt::text||':prepare')::uuid;save_id:=md5(receipt::text||':save')::uuid;
 begin
  child:=request||jsonb_build_object('contract_version','PLANNING-CORRECTION.v1','command_id',prepare_id,
   'idempotency_key',receipt::text||':prepare','expected_version',payload->'expected_need_generation_run_version',
   'reason_code','PLANNING_SOURCE_CORRECTION_PREPARED','payload',jsonb_build_object(
    'need_generation_run_id',payload->'need_generation_run_id','confirmed_need_batch_id',payload->'confirmed_need_batch_id',
    'expected_confirmed_need_batch_version',payload->'expected_confirmed_need_batch_version'));
  prepared:=atlas_api.prepare_planning_source_correction(child);
  if prepared->>'success'is distinct from 'true'then failed:=prepared;raise exception using errcode='CNC01',message='Correction child rejected';end if;
  child:=request||jsonb_build_object('contract_version','RMVP-05.v2','command_id',save_id,
   'idempotency_key',receipt::text||':save','expected_version',prepared#>'{new_versions,confirmed_need_batch_version}',
   'reason_code','CONFIRMED_NEED_SAVED','reason_note',null,'payload',jsonb_build_object(
    'confirmed_need_batch_id',payload->'confirmed_need_batch_id','lines',jsonb_build_array(payload-array[
     'need_generation_run_id','expected_need_generation_run_version','confirmed_need_batch_id',
     'expected_confirmed_need_batch_version','proposal_fingerprint'])));
  saved:=atlas_api.save_confirmed_needs(child);
  if saved->>'success'is distinct from 'true'then failed:=saved;raise exception using errcode='CNC01',message='Correction child rejected';end if;
  set constraints all immediate;set constraints all deferred;
 exception when sqlstate 'CNC01'then
  if failed->>'error_code'in('RETRYABLE_CONCURRENCY_FAILURE','INTERNAL_COMMAND_FAILURE')then
   raise exception using errcode='40001',message='Correction child outcome requires exact retry';end if;
  return atlas_core.pa_05b_finish_command(receipt,atlas_core.d037_error(request,contract,name,
   coalesce(failed->>'error_code','CORRECTION_CHILD_REJECTED'),'The correction was not saved; all child effects were rolled back.'),false);
 end;
 answer:=jsonb_build_object('success',true,'contract_version',contract,'command_name',name,'command_id',request->'command_id',
  'correlation_id',request->'correlation_id','receipt_id',receipt,'idempotency_status','COMPLETED',
  'need_generation_run_id',payload->'need_generation_run_id','confirmed_need_batch_id',payload->'confirmed_need_batch_id',
  'resulting_batch_version',saved->'resulting_batch_version','created_successor_revision_ids',saved->'created_successor_revision_ids',
  'created_decision_ids',saved->'created_decision_ids','authoritative_readback',saved->'authoritative_readback',
  'child_command_ids',jsonb_build_array(prepare_id,save_id),
  'emitted_event_ids',coalesce(prepared->'emitted_event_ids','[]')||coalesce(saved->'emitted_event_ids',jsonb_build_array(saved->'event_id')),
  'audit_event_ids',coalesce(prepared->'audit_event_ids','[]')||coalesce(saved->'audit_event_ids',jsonb_build_array(saved->'audit_id')),
  'safe_operator_message','The selected Need quantity was corrected. Review downstream changes before any explicit release.');
 return atlas_core.pa_05b_finish_command(receipt,answer,true);
exception when serialization_failure or deadlock_detected or lock_not_available or query_canceled then
 return atlas_core.d037_error(request,contract,name,'RETRYABLE_CONCURRENCY_FAILURE',
  'The correction was not committed. Retry the exact original request.',true);
 when others then return atlas_core.d037_error(request,contract,name,'INTERNAL_COMMAND_FAILURE',
  'The correction failed safely. No changes were committed. Recover using the exact original request.',true);
end;$correct$;
revoke all on function atlas_api.correct_confirmed_need(jsonb)from public,anon,service_role;
grant execute on function atlas_api.correct_confirmed_need(jsonb)to authenticated;
reset role;
set role atlas_need_generation_runtime;
grant execute on function atlas_api.prepare_planning_source_correction(jsonb)to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_owner;

do $restore_schema$
declare access record;
begin
 for access in select * from pg_temp.c_task2_schema_before loop
  if not access.had_create then
   execute format('revoke create on schema %I from %I',access.schema_name,access.role_name);
  end if;
 end loop;
end;$restore_schema$;
reset role;
do $restore_role$
declare access record;
begin
 for access in select * from pg_temp.c_task2_role_before loop
  if access.admin_option is null then
   execute format('revoke %I from postgres granted by postgres',access.role_name);
  else
   execute format('grant %I to postgres with admin %s, inherit %s, set %s',access.role_name,
    case when access.admin_option then 'true' else 'false' end,
    case when access.inherit_option then 'true' else 'false' end,
    case when access.set_option then 'true' else 'false' end);
  end if;
 end loop;
end;
$restore_role$;
commit;
