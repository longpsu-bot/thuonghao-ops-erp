-- Operator C Task2: private immutable evidence and early locking only.
-- No public correction API, backfill, released-status downgrade or new authority.
begin;
create temporary table c_task2_role_before on commit drop as
select r.rolname role_name,a.admin_option,a.inherit_option,a.set_option
from pg_roles r left join pg_auth_members a on a.roleid=r.oid
 and a.member='postgres'::regrole and a.grantor='postgres'::regrole
where r.rolname in('atlas_confirmed_need_review_runtime','atlas_procurement_command_runtime','atlas_need_generation_runtime',
 'atlas_planning_materialization_runtime','atlas_planning_command_runtime','atlas_dispatch_command_runtime');
create temporary table c_task2_schema_before on commit drop as
select role_name,schema_name,has_schema_privilege(role_name,schema_name,'CREATE') had_create
from(values('atlas_confirmed_need_review_runtime','atlas_core'),
 ('atlas_confirmed_need_review_runtime','atlas_planning'),
 ('atlas_procurement_command_runtime','atlas_core'),
 ('atlas_need_generation_runtime','atlas_core'),
 ('atlas_need_generation_runtime','atlas_api'),('atlas_confirmed_need_review_runtime','atlas_api'),
 ('atlas_procurement_command_runtime','atlas_api'),('atlas_planning_command_runtime','atlas_api'),
 ('atlas_planning_materialization_runtime','atlas_core'),('atlas_dispatch_command_runtime','atlas_api'))access(role_name,schema_name);
grant select on c_task2_schema_before to atlas_owner;
grant atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime,atlas_need_generation_runtime,
 atlas_planning_materialization_runtime,atlas_planning_command_runtime,atlas_dispatch_command_runtime
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
-- immutable demand→approval→validation observations, never today's pointers.
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
 -- FOR UPDATE now prevents a KEY SHARE→UPDATE upgrade after family locks,
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
 -- Match direct create_need_generation_run: input-set→evaluation→run, never
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
  -- Direct create_need_generation_run is input-set→evaluation→run.
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
