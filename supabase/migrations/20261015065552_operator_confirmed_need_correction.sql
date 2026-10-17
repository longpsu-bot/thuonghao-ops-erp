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
 ('atlas_read_runtime','atlas_core'),('atlas_read_runtime','atlas_api'))access(role_name,schema_name);
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
with observations as materialized (
 select * from atlas_planning.confirmed_need_validation_lines
 where confirmed_need_validation_attempt_id=p_attempt
), observation_counts as materialized (
 select count(*) total_count,count(distinct confirmed_need_line_id) distinct_line_count
 from observations
), issue_counts as materialized (
 select count(*)filter(where severity='BLOCKING') blocking_count,
  count(*)filter(where severity='WARNING') warning_count
 from atlas_planning.confirmed_need_validation_issues
 where confirmed_need_validation_attempt_id=p_attempt
)
select exists (
    select 1
    from atlas_planning.confirmed_need_validation_attempts attempt
    cross join observation_counts counts cross join issue_counts issues
    where attempt.confirmed_need_validation_attempt_id = p_attempt
      and attempt.confirmed_need_batch_id = p_batch
      and attempt.source_kind = 'NEED_GENERATION'
      and attempt.outcome = 'VALIDATED'
      and attempt.blocking_issue_count = 0
      and attempt.line_count > 0
      and attempt.line_count = counts.distinct_line_count
      and attempt.line_count = counts.total_count
      and attempt.blocking_issue_count = issues.blocking_count
      and attempt.warning_count = issues.warning_count
      and not exists (
        select 1
        from observations observation
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
        -- The captured revision has an existing contribution index. Aggregate
        -- that exact key, avoiding a 250-row totals rescan for each observation.
        -- No members still means count 0 / sum NULL; raw multiplicity is retained.
        left join lateral (
          select count(*) member_count,
            sum(c.controlled_contribution_quantity) member_total
          from atlas_planning.confirmed_need_line_revision_contributions c
          where c.confirmed_need_line_revision_id=revision.confirmed_need_line_revision_id
        ) membership on true
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
            or observation.observed_source_membership_count is distinct from coalesce(membership.member_count,0)
            or observation.source_membership_total is distinct from membership.member_total
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
 ), eligible_snapshots as materialized (
  select s.*
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
  where e.complete and s.validated_fact_fingerprint is not null
   and (select count(*)from atlas_planning.confirmed_need_snapshot_lines member
    where member.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id)=a.line_count
   and not exists(select 1 from atlas_planning.confirmed_need_validation_lines observation
    where observation.confirmed_need_validation_attempt_id=e.attempt_id
    and not exists(select 1 from atlas_planning.confirmed_need_snapshot_lines member
     where member.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
      and member.confirmed_need_line_revision_id=observation.current_confirmed_need_line_revision_id
      and member.unit_id=observation.controlled_unit_id
      and member.approved_quantity=observation.confirmed_quantity))
 ), authorized as (
  select r.confirmed_need_line_revision_id revision_id,
   o.current_confirmed_need_line_decision_id decision_id
  from eligible_snapshots s
  join atlas_planning.confirmed_need_snapshot_lines sl
   on sl.confirmed_need_approval_snapshot_id=s.confirmed_need_approval_snapshot_id
  join atlas_planning.confirmed_need_line_revisions r
   on r.confirmed_need_line_revision_id=sl.confirmed_need_line_revision_id
   and r.confirmed_need_batch_id=p_batch and r.source_kind='NEED_GENERATION'
  join atlas_planning.confirmed_need_validation_lines o
   on o.confirmed_need_validation_attempt_id=s.confirmed_need_validation_attempt_id
   and o.confirmed_need_line_id=r.confirmed_need_line_id
   and o.current_confirmed_need_line_revision_id=r.confirmed_need_line_revision_id
   and o.controlled_unit_id=sl.unit_id and o.confirmed_quantity=sl.approved_quantity
  where sl.ingredient_id=r.ingredient_id and sl.unit_id=r.unit_id
   and sl.approved_quantity=r.confirmed_quantity
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
create function atlas_core.purchase_review_correction_roots(p_batch uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $raw_roots$
declare batches uuid[]:=array[p_batch]; visited uuid[]:='{}'; families uuid[]:='{}';
 target uuid; batch record;
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
  select coalesce(array_agg(distinct id order by id),'{}')into batches from(
   select unnest(batches)id union all
   -- Raw batch identities are never filtered through a shaped projection.
   -- Invalidated/zero/incomplete/pending-later-attempt roots still serialize.
   select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
    where b.source_kind='NEED_GENERATION' and b.period_start<=batch.period_end
     and b.period_end>=batch.period_start
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
  'family_ids',to_jsonb(families),'period_start',first_day,'period_end',last_day);
end;
$raw_roots$;
revoke all on function atlas_core.purchase_review_correction_roots(uuid)from public,anon,authenticated,service_role;
grant execute on function atlas_core.purchase_review_correction_roots(uuid)to atlas_need_generation_runtime;
create function atlas_core.purchase_review_correction_context(p_batch uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $context$
declare facts jsonb;batch uuid;sources jsonb:='[]';
begin
 facts:=atlas_core.purchase_review_correction_roots(p_batch);
 if facts->>'available'is distinct from 'true'then return facts;end if;
 for batch in select value::uuid from jsonb_array_elements_text(facts->'batch_ids')loop
  sources:=sources||atlas_core.purchase_review_confirmed_source_universe(batch);
 end loop;
 select coalesce(jsonb_agg(item order by item->>'source_confirmed_need_batch_id',
  item->>'service_date',item->>'delivery_location_id',item->>'ingredient_id',item->>'unit_id'),'[]')
 into sources from(select distinct value item from jsonb_array_elements(sources))canonical;
 return facts||jsonb_build_object('sources',sources);
end;$context$;
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
 ), expanded_facts as materialized (
  select e.confirmed_need_batch_id,e.confirmed_need_validation_attempt_id,f.value fact,
   f.value->>'confirmed_need_line_id' line_id,
   f.value->>'current_confirmed_need_line_revision_id' revision_id
  from evidence e
  cross join lateral jsonb_array_elements(coalesce(e.facts#>'{projection,ordered_lines}','[]'))f(value)
 ), evidence_metadata as materialized (
  select e.confirmed_need_batch_id,e.confirmed_need_validation_attempt_id,
   e.facts->>'complete'='true' evidence_complete,
   e.facts->'released_snapshot_ids' released_snapshot_ids
  from evidence e
 ), members as (
  select b.*,e.evidence_complete,
   coalesce(e.released_snapshot_ids @> jsonb_build_array(b.confirmed_need_approval_snapshot_id),false) prior_release,
   f.fact
  from bindings b left join evidence_metadata e
   on e.confirmed_need_batch_id=b.confirmed_need_batch_id
   and e.confirmed_need_validation_attempt_id=b.confirmed_need_validation_attempt_id
  left join expanded_facts f
   on f.confirmed_need_batch_id=b.confirmed_need_batch_id
   and f.confirmed_need_validation_attempt_id=b.confirmed_need_validation_attempt_id
   and f.line_id=b.confirmed_need_line_id::text
   and f.revision_id=b.confirmed_need_line_revision_id::text
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
 initial:=atlas_core.purchase_review_correction_roots(p_batch);
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
 fresh:=atlas_core.purchase_review_correction_roots(p_batch);
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
 initial:=atlas_core.purchase_review_correction_roots(p_batch);
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
 fresh:=atlas_core.purchase_review_correction_roots(p_batch);
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
   'Refresh and review the exact quantity correction before saving.')||jsonb_build_object('receipt_id',receipt,'idempotency_status','FAILED_NON_RETRYABLE'),false);end if;
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
   coalesce(failed->>'error_code','CORRECTION_CHILD_REJECTED'),'The correction was not saved; all child effects were rolled back.')||jsonb_build_object('receipt_id',receipt,'idempotency_status','FAILED_NON_RETRYABLE'),false);
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

-- Task4: derived applicability supplements raw support identity only.
reset role;
set role atlas_procurement_command_runtime;
grant execute on function atlas_core.purchase_review_continuity_context(uuid),atlas_core.purchase_review_family_continuity(uuid,text,jsonb)to atlas_read_runtime;
reset role;
set role atlas_procurement_command_runtime;
do $consumer$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_allocation_ready(uuid)'::regprocedure);
begin
 if strpos(definition,$old0$
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
$old0$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_allocation_ready(uuid)/0';end if;
 definition:=replace(definition,$old0$
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
$old0$,$new0$
 select atlas_core.purchase_review_allocation_ready(p_batch,atlas_core.purchase_review_confirmed_source_universe(p_batch));
$new0$);
 execute definition;
end;$consumer$;

reset role;
set role atlas_procurement_command_runtime;
do $consumer$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_preparation_allocation_ready(uuid)'::regprocedure);
begin
 if strpos(definition,$old0$
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
$old0$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_preparation_allocation_ready(uuid)/0';end if;
 definition:=replace(definition,$old0$
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
$old0$,$new0$
 select atlas_core.purchase_review_preparation_allocation_ready(p_batch,atlas_core.purchase_review_confirmed_source_universe(p_batch));
$new0$);
 execute definition;
end;$consumer$;

reset role;
set role atlas_procurement_command_runtime;
do $consumer$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_allocation_ready(uuid,jsonb)'::regprocedure);
begin
 if strpos(definition,$old0$  with source as materialized ($old0$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_allocation_ready(uuid,jsonb)/0';end if;
 definition:=replace(definition,$old0$  with source as materialized ($old0$,$new0$  with continuity as materialized(select atlas_core.purchase_review_continuity_context(p_batch) value), source as materialized ($new0$);
 if strpos(definition,$old1$and r.source_kind='CONFIRMED_NEED' and r.source_confirmed_need_batch_id=p_batch
          and r.source_fingerprint=p->>'source_fingerprint' and r.family_quantity=(p->>'family_quantity')::numeric
          and r.source_confirmed_need_batch_version<=(p->>'source_confirmed_need_batch_version')::bigint$old1$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_allocation_ready(uuid,jsonb)/1';end if;
 definition:=replace(definition,$old1$and r.source_kind='CONFIRMED_NEED' and r.source_confirmed_need_batch_id=p_batch
          and r.source_fingerprint=p->>'source_fingerprint' and r.family_quantity=(p->>'family_quantity')::numeric
          and r.source_confirmed_need_batch_version<=(p->>'source_confirmed_need_batch_version')::bigint$old1$,$new1$and ((r.source_kind='CONFIRMED_NEED' and r.source_confirmed_need_batch_id=p_batch
          and r.source_fingerprint=p->>'source_fingerprint' and r.family_quantity=(p->>'family_quantity')::numeric
          and r.source_confirmed_need_batch_version<=(p->>'source_confirmed_need_batch_version')::bigint) or (r.source_kind='PURCHASE_HANDOFF' and atlas_core.purchase_review_family_continuity(r.family_revision_id,'PROSPECTIVE',(select value from continuity))->>'applicable'='true'))$new1$);
 execute definition;
end;$consumer$;

reset role;
set role atlas_procurement_command_runtime;
do $consumer$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_preparation_allocation_ready(uuid,jsonb)'::regprocedure);
begin
 if strpos(definition,$old0$  with source as materialized ($old0$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_preparation_allocation_ready(uuid,jsonb)/0';end if;
 definition:=replace(definition,$old0$  with source as materialized ($old0$,$new0$  with continuity as materialized(select atlas_core.purchase_review_continuity_context(p_batch) value), source as materialized ($new0$);
 if strpos(definition,$old1$and revision.source_kind='CONFIRMED_NEED'
              and revision.source_confirmed_need_batch_id=p_batch
              and revision.source_fingerprint=p->>'source_fingerprint'
              and revision.family_quantity=(p->>'family_quantity')::numeric
              and revision.source_confirmed_need_batch_version<=
                (p->>'source_confirmed_need_batch_version')::bigint$old1$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_preparation_allocation_ready(uuid,jsonb)/1';end if;
 definition:=replace(definition,$old1$and revision.source_kind='CONFIRMED_NEED'
              and revision.source_confirmed_need_batch_id=p_batch
              and revision.source_fingerprint=p->>'source_fingerprint'
              and revision.family_quantity=(p->>'family_quantity')::numeric
              and revision.source_confirmed_need_batch_version<=
                (p->>'source_confirmed_need_batch_version')::bigint$old1$,$new1$and ((revision.source_kind='CONFIRMED_NEED'
              and revision.source_confirmed_need_batch_id=p_batch
              and revision.source_fingerprint=p->>'source_fingerprint'
              and revision.family_quantity=(p->>'family_quantity')::numeric
              and revision.source_confirmed_need_batch_version<=
                (p->>'source_confirmed_need_batch_version')::bigint) or (revision.source_kind='PURCHASE_HANDOFF' and atlas_core.purchase_review_family_continuity(revision.family_revision_id,'PROSPECTIVE',(select value from continuity))->>'applicable'='true'))$new1$);
 execute definition;
end;$consumer$;

reset role;
set role atlas_procurement_command_runtime;
do $consumer$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid)'::regprocedure);
begin
 if strpos(definition,$old0$  v_expected jsonb; v_actual jsonb; v_event uuid; v_audit uuid;$old0$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid)/0';end if;
 definition:=replace(definition,$old0$  v_expected jsonb; v_actual jsonb; v_event uuid; v_audit uuid;$old0$,$new0$  v_expected jsonb; v_actual jsonb; v_event uuid; v_audit uuid; continuity jsonb;$new0$);
 if strpos(definition,$old1$  for p in select source.value$old1$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid)/1';end if;
 definition:=replace(definition,$old1$  for p in select source.value$old1$,$new1$  continuity:=atlas_core.purchase_review_continuity_context(p_batch);
  for p in select source.value$new1$);
 if strpos(definition,$old2$    h:=atlas_core.school_catering_family_projection$old2$)=0 then raise exception 'C consumer anchor missing: atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid)/2';end if;
 definition:=replace(definition,$old2$    h:=atlas_core.school_catering_family_projection$old2$,$new2$    if r.source_kind='PURCHASE_HANDOFF' and atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',continuity)->>'applicable'='true'then continue;end if;
    h:=atlas_core.school_catering_family_projection$new2$);
 execute definition;
end;$consumer$;

reset role;
set role atlas_read_runtime;
do $consumer$
declare definition text:=pg_get_functiondef('atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure);
begin
 if strpos(definition,$old0$  v_blockers jsonb:=$old0$)=0 then raise exception 'C consumer anchor missing: atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)/0';end if;
 definition:=replace(definition,$old0$  v_blockers jsonb:=$old0$,$new0$  continuity_contexts jsonb; continuity jsonb;
  v_blockers jsonb:=$new0$);
 if strpos(definition,$old1$  for p in select value from jsonb_array_elements(v_sources) loop$old1$)=0 then raise exception 'C consumer anchor missing: atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)/1';end if;
 definition:=replace(definition,$old1$  for p in select value from jsonb_array_elements(v_sources) loop$old1$,$new1$  select coalesce(jsonb_object_agg(batch_id,atlas_core.purchase_review_continuity_context(batch_id::uuid)),'{}') into continuity_contexts from(select distinct value->>'source_confirmed_need_batch_id' batch_id from jsonb_array_elements(v_sources))batches where batch_id is not null;
  for p in select value from jsonb_array_elements(v_sources) loop$new1$);
 if strpos(definition,$old2$    -- Once promoted, retain the real Handoff source for currentness and legacy Save.$old2$)=0 then raise exception 'C consumer anchor missing: atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)/2';end if;
 definition:=replace(definition,$old2$    -- Once promoted, retain the real Handoff source for currentness and legacy Save.$old2$,$new2$    continuity:=atlas_core.purchase_review_family_continuity(r.family_revision_id,case when p->>'batch_status'='RELEASED_FOR_PURCHASE_HANDOFF'then 'OFFICIAL'else 'PROSPECTIVE'end,continuity_contexts->(p->>'source_confirmed_need_batch_id'));
    -- Keep raw source identity for every explicit legacy Save.$new2$);
 if strpos(definition,$old3$when r.source_fingerprint=p->>'source_fingerprint' and v_eligible$old3$)=0 then raise exception 'C consumer anchor missing: atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)/3';end if;
 definition:=replace(definition,$old3$when r.source_fingerprint=p->>'source_fingerprint' and v_eligible$old3$,$new3$when (r.source_fingerprint=p->>'source_fingerprint' or continuity->>'applicable'='true') and v_eligible$new3$);
 execute definition;
end;$consumer$;


-- Task4 official date/PO applicability; no raw fingerprint substitution.
reset role;
set role atlas_owner;
do $official$
declare definition text:=pg_get_functiondef('atlas_core.school_catering_po_date_readiness(date)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  with source_families as (
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
$old0$,'')))/length($old0$  with source_families as (
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
$old0$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_date_readiness(date)/0';end if;
 definition:=replace(definition,$old0$  with source_families as (
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
$old0$,$new0$  with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=p_service_date and b.period_end>=p_service_date
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date=p_service_date and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date=p_service_date and r.is_current
 ), source_families as (
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

    union select nr.service_date,nr.delivery_location_id,nr.ingredient_id,nr.unit_id
    from atlas_planning.confirmed_need_line_revisions nr
    join atlas_planning.confirmed_need_batches nb using(confirmed_need_batch_id)
    where nr.is_current and nr.service_date=p_service_date and nb.source_kind='NEED_GENERATION'
$new0$);
 if (length(definition)-length(replace(definition,$old1$when f.family_id is null$old1$,'')))/length($old1$when f.family_id is null$old1$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_date_readiness(date)/1';end if;
 definition:=replace(definition,$old1$when f.family_id is null$old1$,$new1$when exists(select 1 from atlas_planning.confirmed_need_line_revisions nr
          join atlas_planning.confirmed_need_batches nb using(confirmed_need_batch_id)
          where nr.is_current and nb.source_kind='NEED_GENERATION'
           and row(nr.service_date,nr.delivery_location_id,nr.ingredient_id,nr.unit_id)=row(sf.service_date,sf.delivery_location_id,sf.ingredient_id,sf.unit_id)
           and nb.batch_status<>'RELEASED_FOR_PURCHASE_HANDOFF')then 'CORRECTION_PENDING'
        when f.family_id is null$new1$);
 if (length(definition)-length(replace(definition,$old2$r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
          or r.family_quantity is distinct from
            atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old2$,'')))/length($old2$r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
          or r.family_quantity is distinct from
            atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old2$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_date_readiness(date)/2';end if;
 definition:=replace(definition,$old2$r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
          or r.family_quantity is distinct from
            atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old2$,$new2$(r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
          or r.family_quantity is distinct from
            atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) and not coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false)$new2$);
 execute definition;
end;$official$;

reset role;
set role atlas_owner;
do $official$
declare definition text:=pg_get_functiondef('atlas_core.school_catering_po_draft_is_stale(uuid,uuid)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  ), expected as ($old0$,'')))/length($old0$  ), expected as ($old0$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_draft_is_stale(uuid,uuid)/0';end if;
 definition:=replace(definition,$old0$  ), expected as ($old0$,$new0$  ), continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=(select school_catering_service_date from root) and b.period_end>=(select school_catering_service_date from root)
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date=(select school_catering_service_date from root) and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date=(select school_catering_service_date from root) and r.is_current
 ), expected as ($new0$);
 if (length(definition)-length(replace(definition,$old1$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old1$,'')))/length($old1$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old1$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_draft_is_stale(uuid,uuid)/1';end if;
 definition:=replace(definition,$old1$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old1$,$new1$((r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false))$new1$);
 if (length(definition)-length(replace(definition,$old2$r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
        or r.family_quantity is distinct from
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old2$,'')))/length($old2$r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
        or r.family_quantity is distinct from
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old2$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_draft_is_stale(uuid,uuid)/2';end if;
 definition:=replace(definition,$old2$r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
        or r.family_quantity is distinct from
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old2$,$new2$((r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
        or r.family_quantity is distinct from
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) and not coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false))$new2$);
 execute definition;
end;$official$;

reset role;
set role atlas_read_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_core.school_catering_po_commitment_state(uuid,uuid)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  select case$old0$,'')))/length($old0$  select case$old0$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_commitment_state(uuid,uuid)/0';end if;
 definition:=replace(definition,$old0$  select case$old0$,$new0$  with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and b.period_end>=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id)
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and r.is_current
 ) select case$new0$);
 if (length(definition)-length(replace(definition,$old1$    when po.purchase_order_status='RELEASED_TO_SUPPLIER' and exists(
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
$old1$,'')))/length($old1$    when po.purchase_order_status='RELEASED_TO_SUPPLIER' and exists(
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
$old1$)<>1 then raise exception 'C official anchor missing: atlas_core.school_catering_po_commitment_state(uuid,uuid)/1';end if;
 definition:=replace(definition,$old1$    when po.purchase_order_status='RELEASED_TO_SUPPLIER' and exists(
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
$old1$,$new1$    when po.purchase_order_status='RELEASED_TO_SUPPLIER' and exists(
      select 1 from atlas_procurement.purchase_order_line_revisions line
      where line.purchase_order_revision_id=p_purchase_order_revision_id)
      and not exists(
       select 1 from atlas_procurement.purchase_order_line_revisions line
       join atlas_procurement.school_catering_allocation_supplier_splits old_split
        on old_split.supplier_split_id=line.school_catering_allocation_supplier_split_id
       join atlas_procurement.school_catering_allocation_family_revisions old_revision
        on old_revision.family_revision_id=old_split.family_revision_id
       left join atlas_procurement.school_catering_allocation_family_revisions r
        on r.family_id=old_revision.family_id and r.is_current
       where line.purchase_order_revision_id=p_purchase_order_revision_id and not (
        coalesce((select value->>'classification'='AUTHORITATIVE_ZERO'from continuity_families
          where family_revision_id=r.family_revision_id),false)
        or (coalesce((select value->>'applicable'='true'from continuity_families
          where family_revision_id=r.family_revision_id),false)
         and not exists(select 1 from atlas_procurement.school_catering_allocation_supplier_splits s
          where s.family_revision_id=r.family_revision_id and s.supplier_id=po.supplier_id))))
      then 'CANCELLATION_REQUIRED'
    when po.purchase_order_status='RELEASED_TO_SUPPLIER' then 'REPLACEMENT_REQUIRED'
$new1$);
 execute definition;
end;$official$;

reset role;
set role atlas_procurement_command_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_po_coverage(date)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  with expected as materialized ($old0$,'')))/length($old0$  with expected as materialized ($old0$)<>1 then raise exception 'C official anchor missing: atlas_core.purchase_review_po_coverage(date)/0';end if;
 definition:=replace(definition,$old0$  with expected as materialized ($old0$,$new0$  with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=p_date and b.period_end>=p_date
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date=p_date and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date=p_date and r.is_current
 ), expected as materialized ($new0$);
 if (length(definition)-length(replace(definition,$old1$r.source_fingerprint=atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint'$old1$,'')))/length($old1$r.source_fingerprint=atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint'$old1$)<>1 then raise exception 'C official anchor missing: atlas_core.purchase_review_po_coverage(date)/1';end if;
 definition:=replace(definition,$old1$r.source_fingerprint=atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint'$old1$,$new1$(r.source_fingerprint=atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint' or coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false))$new1$);
 definition:=replace(definition,'select exists(select 1 from expected)',
  'select coalesce((atlas_core.school_catering_po_date_readiness(p_date)->>''ready'')::boolean,false) and exists(select 1 from expected)');
 execute definition;
end;$official$;


-- Task4 resolved PO consumers: caller-owned maps, never public request fields.
reset role;
set role atlas_owner;
CREATE OR REPLACE FUNCTION atlas_core.school_catering_po_draft_is_stale(p_purchase_order_id uuid, p_purchase_order_revision_id uuid, p_continuity jsonb)
RETURNS boolean LANGUAGE sql STABLE SET search_path TO '' AS $function$
with root as (
 select po.supplier_id,po.school_catering_service_date
 from atlas_procurement.purchase_orders po
 where po.purchase_order_id=p_purchase_order_id and po.purchase_order_kind='SCHOOL_CATERING'
), continuity_families as materialized (
 select key::uuid family_revision_id,value from jsonb_each(coalesce(p_continuity,'{}'::jsonb))
), expected_base as materialized (
 select s.supplier_split_id,r.family_revision_id,r.source_fingerprint,r.family_quantity,
 f.family_id,f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
 from root join atlas_procurement.school_catering_allocation_families f
 on f.service_date=root.school_catering_service_date
 join atlas_procurement.school_catering_allocation_family_revisions r
 on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
 join atlas_procurement.school_catering_allocation_supplier_splits s
 on s.family_revision_id=r.family_revision_id and s.supplier_id=root.supplier_id
), actual as materialized (
 select polr.school_catering_allocation_supplier_split_id supplier_split_id
 from atlas_procurement.purchase_order_line_revisions polr
 where polr.purchase_order_revision_id=p_purchase_order_revision_id
), actual_source as materialized (
 select r.family_revision_id,r.source_kind,r.is_current,r.source_fingerprint,r.family_quantity,
 f.family_id,f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
 from actual join atlas_procurement.school_catering_allocation_supplier_splits s using(supplier_split_id)
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
 join atlas_procurement.school_catering_allocation_families f using(family_id)
), projection_keys as materialized (
 select family_id,service_date,delivery_location_id,ingredient_id,unit_id from expected_base
 union select family_id,service_date,delivery_location_id,ingredient_id,unit_id from actual_source
), family_projections as materialized (
 select family_id,atlas_core.school_catering_family_projection(service_date,delivery_location_id,ingredient_id,unit_id)value
 from projection_keys
), expected as (
 select r.supplier_split_id from expected_base r join family_projections projection using(family_id)
 where ((r.source_fingerprint=projection.value->>'source_fingerprint'
 and r.family_quantity=atlas_core.pa_05b_safe_numeric(projection.value->>'family_quantity'))
 or coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false))
)
select exists(select from actual_source r join family_projections projection using(family_id)
 where r.source_kind<>'PURCHASE_HANDOFF' or not r.is_current
 or ((r.source_fingerprint is distinct from projection.value->>'source_fingerprint'
 or r.family_quantity is distinct from atlas_core.pa_05b_safe_numeric(projection.value->>'family_quantity'))
 and not coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false)))
 or exists((select supplier_split_id from expected except select supplier_split_id from actual))
 or exists((select supplier_split_id from actual except select supplier_split_id from expected));
$function$;
revoke all on function atlas_core.school_catering_po_draft_is_stale(uuid,uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function atlas_core.school_catering_po_draft_is_stale(uuid,uuid,jsonb)to atlas_read_runtime,atlas_procurement_command_runtime;

reset role;
set role atlas_owner;
CREATE OR REPLACE FUNCTION atlas_core.school_catering_po_draft_is_stale(p_purchase_order_id uuid, p_purchase_order_revision_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select atlas_core.school_catering_po_draft_is_stale(p_purchase_order_id,p_purchase_order_revision_id,(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and b.period_end>=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id)
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families));
$function$
;

reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_catering_po_commitment_state(p_purchase_order_id uuid, p_purchase_order_revision_id uuid, p_continuity jsonb)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with continuity_families as materialized(select key::uuid family_revision_id,value from jsonb_each(coalesce(p_continuity,'{}'::jsonb))) select case
    when po.purchase_order_status='SUPERSEDED' then 'SUPERSEDED'
    when po.purchase_order_status='DRAFT' then
      case when atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id,p_continuity)
        then 'DRAFT_STALE' else 'DRAFT_CURRENT' end
    when po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and not atlas_core.school_catering_po_draft_is_stale(
        po.purchase_order_id,p_purchase_order_revision_id,p_continuity) then 'CURRENT'
    when po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and not exists(select 1 from atlas_procurement.school_catering_allocation_families current_family
       join atlas_procurement.school_catering_allocation_family_revisions current_revision using(family_id)
       join atlas_procurement.school_catering_allocation_supplier_splits current_split using(family_revision_id)
       where current_family.service_date=po.school_catering_service_date and current_revision.is_current
        and current_split.supplier_id=po.supplier_id and current_split.allocated_quantity>0
        and not coalesce((select value->>'classification'='AUTHORITATIVE_ZERO'from continuity_families
         where family_revision_id=current_revision.family_revision_id),false))
      and exists(
      select 1 from atlas_procurement.purchase_order_line_revisions line
      where line.purchase_order_revision_id=p_purchase_order_revision_id)
      and not exists(
       select 1 from atlas_procurement.purchase_order_line_revisions line
       join atlas_procurement.school_catering_allocation_supplier_splits old_split
        on old_split.supplier_split_id=line.school_catering_allocation_supplier_split_id
       join atlas_procurement.school_catering_allocation_family_revisions old_revision
        on old_revision.family_revision_id=old_split.family_revision_id
       join atlas_procurement.school_catering_allocation_families old_family on old_family.family_id=old_revision.family_id
       left join atlas_procurement.school_catering_allocation_family_revisions r
        on r.family_id=old_revision.family_id and r.is_current
       where line.purchase_order_revision_id=p_purchase_order_revision_id and not (
        coalesce((select value->>'classification'='AUTHORITATIVE_ZERO'from continuity_families
          where family_revision_id=r.family_revision_id),false)
        or ((r.source_kind='PURCHASE_HANDOFF'and (
          exists(select 1 from atlas_planning.purchase_handoff_revisions c_hr
           cross join lateral(select atlas_core.school_catering_family_projection(
            old_family.service_date,old_family.delivery_location_id,old_family.ingredient_id,old_family.unit_id)value)c_projection
           where c_hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
            and c_hr.is_current and c_hr.revision_status='RELEASED_TO_PROCUREMENT'
            and r.source_fingerprint=c_projection.value->>'source_fingerprint'
            and r.family_quantity=atlas_core.pa_05b_safe_numeric(c_projection.value->>'family_quantity'))
          or coalesce((select value->>'applicable'='true'from continuity_families
           where family_revision_id=r.family_revision_id),false)))
         and not exists(select 1 from atlas_procurement.school_catering_allocation_supplier_splits s
          where s.family_revision_id=r.family_revision_id and s.supplier_id=po.supplier_id))))
      then 'CANCELLATION_REQUIRED'
    when po.purchase_order_status='RELEASED_TO_SUPPLIER' then 'REPLACEMENT_REQUIRED'
    else po.purchase_order_status
  end
  from atlas_procurement.purchase_orders po
  where po.purchase_order_id=p_purchase_order_id
    and po.purchase_order_kind='SCHOOL_CATERING';
$function$
;
revoke all on function atlas_core.school_catering_po_commitment_state(uuid,uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function atlas_core.school_catering_po_commitment_state(uuid,uuid,jsonb)to atlas_procurement_command_runtime;

reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_catering_po_commitment_state(p_purchase_order_id uuid, p_purchase_order_revision_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select atlas_core.school_catering_po_commitment_state(p_purchase_order_id,p_purchase_order_revision_id,(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and b.period_end>=(select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id)
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and (select school_catering_service_date from atlas_procurement.purchase_orders where purchase_order_id=p_purchase_order_id) and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families));
$function$
;

reset role;
set role atlas_read_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  with base as ($old0$,'')))/length($old0$  with base as ($old0$)<>1 then raise exception 'C official anchor missing: atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)/0';end if;
 definition:=replace(definition,$old0$  with base as ($old0$,$new0$  with continuity_map as materialized(select (with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_date_end and b.period_end>=v_date_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families) value), base as ($new0$);
 if (length(definition)-length(replace(definition,$old1$po.purchase_order_id,por.purchase_order_revision_id) stale$old1$,'')))/length($old1$po.purchase_order_id,por.purchase_order_revision_id) stale$old1$)<>1 then raise exception 'C official anchor missing: atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)/1';end if;
 definition:=replace(definition,$old1$po.purchase_order_id,por.purchase_order_revision_id) stale$old1$,$new1$po.purchase_order_id,por.purchase_order_revision_id,(select value from continuity_map)) stale$new1$);
 execute definition;
end;$official$;

reset role;
set role atlas_read_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  v_base jsonb;$old0$,'')))/length($old0$  v_base jsonb;$old0$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/0';end if;
 definition:=replace(definition,$old0$  v_base jsonb;$old0$,$new0$  continuity_map jsonb;
  v_base jsonb;$new0$);
 if (length(definition)-length(replace(definition,$old1$  with shaped as ($old1$,'')))/length($old1$  with shaped as ($old1$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/1';end if;
 definition:=replace(definition,$old1$  with shaped as ($old1$,$new1$  continuity_map:=(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_date_end and b.period_end>=v_date_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families);
  with date_states as materialized(select service_date,atlas_core.school_catering_po_date_readiness(service_date) value from(select distinct school_catering_service_date service_date from atlas_procurement.purchase_orders where school_catering_service_date between v_date_start and v_date_end)dates), shaped as ($new1$);
 if (length(definition)-length(replace(definition,$old2$      po.replaces_purchase_order_id,por.purchase_order_revision_id,$old2$,'')))/length($old2$      po.replaces_purchase_order_id,por.purchase_order_revision_id,$old2$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/2';end if;
 definition:=replace(definition,$old2$      po.replaces_purchase_order_id,por.purchase_order_revision_id,$old2$,$new2$      po.replaces_purchase_order_id,por.purchase_order_revision_id,
      coalesce((select value->>'ready'='true'from date_states where service_date=po.school_catering_service_date),false) official_ready,$new2$);
 if (length(definition)-length(replace(definition,$old3$po.purchase_order_id,por.purchase_order_revision_id) commitment_state$old3$,'')))/length($old3$po.purchase_order_id,por.purchase_order_revision_id) commitment_state$old3$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/3';end if;
 definition:=replace(definition,$old3$po.purchase_order_id,por.purchase_order_revision_id) commitment_state$old3$,$new3$po.purchase_order_id,por.purchase_order_revision_id,continuity_map) commitment_state$new3$);
 if (length(definition)-length(replace(definition,$old4$child.purchase_order_id,child_revision.purchase_order_revision_id)$old4$,'')))/length($old4$child.purchase_order_id,child_revision.purchase_order_revision_id)$old4$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/4';end if;
 definition:=replace(definition,$old4$child.purchase_order_id,child_revision.purchase_order_revision_id)$old4$,$new4$child.purchase_order_id,child_revision.purchase_order_revision_id,continuity_map)$new4$);
 if (length(definition)-length(replace(definition,$old5$when 'REPLACEMENT_REQUIRED' then jsonb_build_array('PO_REPLACEMENT_REQUIRED')$old5$,'')))/length($old5$when 'REPLACEMENT_REQUIRED' then jsonb_build_array('PO_REPLACEMENT_REQUIRED')$old5$)<>2 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/5';end if;
 definition:=replace(definition,$old5$when 'REPLACEMENT_REQUIRED' then jsonb_build_array('PO_REPLACEMENT_REQUIRED')$old5$,$new5$when 'REPLACEMENT_REQUIRED' then jsonb_build_array(case when s.official_ready then 'PO_REPLACEMENT_REQUIRED'else 'PO_SOURCE_NOT_READY'end)$new5$);
 if (length(definition)-length(replace(definition,$old6$'create_replacement',s.commitment_state='REPLACEMENT_REQUIRED'$old6$,'')))/length($old6$'create_replacement',s.commitment_state='REPLACEMENT_REQUIRED'$old6$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)/6';end if;
 definition:=replace(definition,$old6$'create_replacement',s.commitment_state='REPLACEMENT_REQUIRED'$old6$,$new6$'create_replacement',s.commitment_state='REPLACEMENT_REQUIRED' and s.official_ready$new6$);
 execute definition;
end;$official$;

reset role;
set role atlas_procurement_command_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_api.create_school_catering_purchase_order_replacement(jsonb)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  v_name constant text$old0$,'')))/length($old0$  v_name constant text$old0$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_replacement(jsonb)/0';end if;
 definition:=replace(definition,$old0$  v_name constant text$old0$,$new0$  continuity_map jsonb;
  v_name constant text$new0$);
 if (length(definition)-length(replace(definition,$old1$  if not atlas_core.school_catering_po_draft_is_stale($old1$,'')))/length($old1$  if not atlas_core.school_catering_po_draft_is_stale($old1$)<>2 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_replacement(jsonb)/1';end if;
 definition:=replace(definition,$old1$  if not atlas_core.school_catering_po_draft_is_stale($old1$,$new1$  continuity_map:=(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_replaced.school_catering_service_date and b.period_end>=v_replaced.school_catering_service_date
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_replaced.school_catering_service_date and v_replaced.school_catering_service_date and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_replaced.school_catering_service_date and v_replaced.school_catering_service_date and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families);
  if not atlas_core.school_catering_po_draft_is_stale($new1$);
 if (length(definition)-length(replace(definition,$old2$v_replaced_id,v_expected_revision_id) then$old2$,'')))/length($old2$v_replaced_id,v_expected_revision_id) then$old2$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_replacement(jsonb)/2';end if;
 definition:=replace(definition,$old2$v_replaced_id,v_expected_revision_id) then$old2$,$new2$v_replaced_id,v_expected_revision_id,continuity_map) then$new2$);
 if (length(definition)-length(replace(definition,$old3$  if not exists(
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
  ) then$old3$,'')))/length($old3$  if not exists(
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
  ) then$old3$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_replacement(jsonb)/3';end if;
 definition:=replace(definition,$old3$  if not exists(
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
  ) then$old3$,$new3$  if atlas_core.school_catering_po_commitment_state(v_replaced_id,v_expected_revision_id,continuity_map)='CANCELLATION_REQUIRED'then$new3$);
 if (length(definition)-length(replace(definition,$old4$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old4$,'')))/length($old4$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old4$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_replacement(jsonb)/4';end if;
 definition:=replace(definition,$old4$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old4$,$new4$((r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))$new4$);
 execute definition;
end;$official$;

reset role;
set role atlas_procurement_command_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_api.create_school_catering_purchase_order_drafts(jsonb)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  v_name constant text$old0$,'')))/length($old0$  v_name constant text$old0$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_drafts(jsonb)/0';end if;
 definition:=replace(definition,$old0$  v_name constant text$old0$,$new0$  continuity_map jsonb;
  v_name constant text$new0$);
 if (length(definition)-length(replace(definition,$old1$  -- Match release ordering:$old1$,'')))/length($old1$  -- Match release ordering:$old1$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_drafts(jsonb)/1';end if;
 definition:=replace(definition,$old1$  -- Match release ordering:$old1$,$new1$  continuity_map:=(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_date_end and b.period_end>=v_date_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families);
  -- Match release ordering:$new1$);
 if (length(definition)-length(replace(definition,$old2$  -- Recompute readiness under the deterministic source locks.$old2$,'')))/length($old2$  -- Recompute readiness under the deterministic source locks.$old2$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_drafts(jsonb)/2';end if;
 definition:=replace(definition,$old2$  -- Recompute readiness under the deterministic source locks.$old2$,$new2$  continuity_map:=(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_date_end and b.period_end>=v_date_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families);
  -- Recompute readiness under the deterministic source locks.$new2$);
 if (length(definition)-length(replace(definition,$old3$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old3$,'')))/length($old3$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old3$)<>3 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_drafts(jsonb)/3';end if;
 definition:=replace(definition,$old3$r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old3$,$new3$((r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))$new3$);
 if (length(definition)-length(replace(definition,$old4$r.source_fingerprint=projection.value ->> 'source_fingerprint'
    and r.family_quantity=
      atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old4$,'')))/length($old4$r.source_fingerprint=projection.value ->> 'source_fingerprint'
    and r.family_quantity=
      atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old4$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_drafts(jsonb)/4';end if;
 definition:=replace(definition,$old4$r.source_fingerprint=projection.value ->> 'source_fingerprint'
    and r.family_quantity=
      atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old4$,$new4$((r.source_fingerprint=projection.value ->> 'source_fingerprint'
    and r.family_quantity=
      atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))$new4$);
 if (length(definition)-length(replace(definition,$old5$r.source_fingerprint=projection.value ->> 'source_fingerprint'
        and r.family_quantity=
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old5$,'')))/length($old5$r.source_fingerprint=projection.value ->> 'source_fingerprint'
        and r.family_quantity=
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old5$)<>1 then raise exception 'C official anchor missing: atlas_api.create_school_catering_purchase_order_drafts(jsonb)/5';end if;
 definition:=replace(definition,$old5$r.source_fingerprint=projection.value ->> 'source_fingerprint'
        and r.family_quantity=
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')$old5$,$new5$((r.source_fingerprint=projection.value ->> 'source_fingerprint'
        and r.family_quantity=
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))$new5$);
 execute definition;
end;$official$;


-- Task4 School resolved consumers preserve complete intervals and frozen provenance.
reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_dispatch_release_preview(p_service_date date, p_school_id uuid, p_delivery_location_id uuid, p_continuity jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with scope as (
    select school.school_id,school.school_name,location.delivery_location_id,
      location.location_name,location.address_text
    from atlas_admin.schools school
    join atlas_admin.delivery_locations location
      on location.delivery_location_id=p_delivery_location_id
     and location.customer_id=school.customer_id
    where school.school_id=p_school_id
  ), contributions as materialized (
    select contribution.family_contribution_id,
      contribution.contribution_quantity,revision.family_revision_id,
      revision.source_fingerprint,revision.family_quantity,
      family.ingredient_id,family.unit_id,confirmed_revision.school_id,
      handoff_line.confirmed_need_line_revision_id,
      confirmed_line.current_confirmed_need_line_decision_id
        confirmed_need_line_decision_id
    from atlas_procurement.school_catering_allocation_families family
    join atlas_procurement.school_catering_allocation_family_revisions revision
      on revision.family_id=family.family_id and revision.is_current
     and revision.source_kind='PURCHASE_HANDOFF'
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=revision.family_revision_id
     and contribution.purchase_handoff_line_revision_id is not null
    join atlas_planning.purchase_handoff_line_revisions handoff_line
      on handoff_line.purchase_handoff_line_revision_id=
        contribution.purchase_handoff_line_revision_id
    join atlas_planning.purchase_handoff_revisions handoff_revision
      on handoff_revision.purchase_handoff_revision_id=
        handoff_line.purchase_handoff_revision_id
     and ((handoff_revision.is_current and handoff_revision.revision_status='RELEASED_TO_PROCUREMENT') or coalesce(p_continuity->(revision.family_revision_id::text)->>'applicable'='true',false))
    join atlas_planning.purchase_handoff_batches handoff_batch
      on handoff_batch.purchase_handoff_batch_id=
        handoff_revision.purchase_handoff_batch_id
     and handoff_batch.handoff_status='RELEASED_TO_PROCUREMENT'
    join atlas_planning.purchase_demand_references demand
      on demand.purchase_handoff_line_revision_id=
        handoff_line.purchase_handoff_line_revision_id
     and demand.source_kind='NEED_GENERATION'
    join atlas_planning.confirmed_need_line_revisions confirmed_revision
      on confirmed_revision.confirmed_need_line_revision_id=
        handoff_line.confirmed_need_line_revision_id
    join atlas_planning.confirmed_need_lines confirmed_line
      on confirmed_line.confirmed_need_line_id=confirmed_revision.confirmed_need_line_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        family.service_date,family.delivery_location_id,
        family.ingredient_id,family.unit_id) value
    ) projection
    where family.service_date=p_service_date
      and family.delivery_location_id=p_delivery_location_id
      and confirmed_revision.service_date=p_service_date
      and confirmed_revision.delivery_location_id=p_delivery_location_id
      and confirmed_line.current_confirmed_need_line_decision_id is not null
      and ((revision.source_fingerprint=projection.value->>'source_fingerprint'
      and revision.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value->>'family_quantity')) or coalesce(p_continuity->(revision.family_revision_id::text)->>'applicable'='true',false))
  ), contribution_ranges as materialized (
    select contribution.*,
      coalesce(sum(contribution.contribution_quantity) over(
        partition by contribution.family_revision_id
        order by contribution.family_contribution_id
        rows between unbounded preceding and 1 preceding),0)::numeric(20,6)
        contribution_start,
      sum(contribution.contribution_quantity) over(
        partition by contribution.family_revision_id
        order by contribution.family_contribution_id
        rows between unbounded preceding and current row)::numeric(20,6)
        contribution_end
    from contributions contribution
  ), split_ranges as materialized (
    select split.*,
      coalesce(sum(split.allocated_quantity) over(
        partition by split.family_revision_id
        order by split.supplier_id
        rows between unbounded preceding and 1 preceding),0)::numeric(20,6)
        split_start,
      sum(split.allocated_quantity) over(
        partition by split.family_revision_id
        order by split.supplier_id
        rows between unbounded preceding and current row)::numeric(20,6)
        split_end
    from atlas_procurement.school_catering_allocation_supplier_splits split
    where split.family_revision_id in (
      select distinct contribution.family_revision_id from contributions contribution
    )
  ), coverage as materialized (
    select contribution.*,split.supplier_split_id,split.supplier_id,
      (least(contribution.contribution_end,split.split_end)-
        greatest(contribution.contribution_start,split.split_start))::numeric(20,6)
        covered_quantity,
      purchase.purchase_order_id,purchase.purchase_order_revision_id,
      purchase.purchase_order_line_revision_id
    from contribution_ranges contribution
    join split_ranges split
      on split.family_revision_id=contribution.family_revision_id
    left join lateral (
      select po.purchase_order_id,por.purchase_order_revision_id,
        line.purchase_order_line_revision_id
      from atlas_procurement.purchase_orders po
      join atlas_procurement.purchase_order_revisions por
        on por.purchase_order_id=po.purchase_order_id and por.is_current
       and por.revision_status='RELEASED_TO_SUPPLIER'
      join atlas_procurement.purchase_order_line_revisions line
        on line.purchase_order_revision_id=por.purchase_order_revision_id
       and line.school_catering_allocation_supplier_split_id=
         split.supplier_split_id
      where po.purchase_order_kind='SCHOOL_CATERING'
        and po.purchase_order_status='RELEASED_TO_SUPPLIER'
        and po.school_catering_service_date=p_service_date
        and po.supplier_id=split.supplier_id
        and not atlas_core.school_catering_po_draft_is_stale(
          po.purchase_order_id,por.purchase_order_revision_id,p_continuity)
      order by po.created_at desc limit 1
    ) purchase on true
    where contribution.school_id=p_school_id
      and least(contribution.contribution_end,split.split_end)>
        greatest(contribution.contribution_start,split.split_start)
  ), line_keys as (
    select ingredient_id,unit_id,sum(contribution_quantity)::numeric(20,6) quantity
    from contribution_ranges where school_id=p_school_id
    group by ingredient_id,unit_id
  ), lines as (
    select key.ingredient_id,ingredient.ingredient_name,key.unit_id,unit.unit_code,
      key.quantity,
      coalesce((select jsonb_agg(jsonb_build_object(
        'confirmed_need_line_revision_id',source.confirmed_need_line_revision_id,
        'confirmed_need_line_decision_id',source.confirmed_need_line_decision_id,
        'allocation_family_revision_id',source.family_revision_id,
        'allocation_family_contribution_id',source.family_contribution_id,
        'allocation_supplier_split_id',source.supplier_split_id,
        'purchase_order_id',source.purchase_order_id,
        'purchase_order_revision_id',source.purchase_order_revision_id,
        'purchase_order_line_revision_id',source.purchase_order_line_revision_id,
        'covered_quantity',source.covered_quantity::text
      ) order by source.family_contribution_id,source.supplier_split_id)
      from coverage source
      where source.ingredient_id=key.ingredient_id and source.unit_id=key.unit_id),
      '[]'::jsonb) sources
    from line_keys key
    join atlas_admin.ingredients ingredient on ingredient.ingredient_id=key.ingredient_id
    join atlas_admin.units unit on unit.unit_id=key.unit_id
  ), facts as (
    select coalesce(string_agg(concat_ws('|',
      confirmed_need_line_revision_id,confirmed_need_line_decision_id,
      family_revision_id,family_contribution_id,supplier_split_id,
      covered_quantity,purchase_order_id,purchase_order_revision_id,
      purchase_order_line_revision_id),';' order by family_contribution_id,
      supplier_split_id),'') value from coverage
  ), historical_commitments as materialized (
    select distinct atlas_core.school_catering_po_commitment_state(
      po.purchase_order_id,por.purchase_order_revision_id,p_continuity) commitment_state
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    join atlas_procurement.purchase_order_line_revisions po_line
      on po_line.purchase_order_revision_id=por.purchase_order_revision_id
    join atlas_procurement.school_catering_allocation_supplier_splits historical_split
      on historical_split.supplier_split_id=
        po_line.school_catering_allocation_supplier_split_id
    join atlas_procurement.school_catering_allocation_family_revisions
      historical_family_revision
      on historical_family_revision.family_revision_id=historical_split.family_revision_id
    join atlas_procurement.school_catering_allocation_family_contributions
      historical_contribution
      on historical_contribution.family_revision_id=
        historical_family_revision.family_revision_id
    join atlas_planning.purchase_handoff_line_revisions historical_handoff_line
      on historical_handoff_line.purchase_handoff_line_revision_id=
        historical_contribution.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions historical_need_revision
      on historical_need_revision.confirmed_need_line_revision_id=
        historical_handoff_line.confirmed_need_line_revision_id
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_service_date
      and po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and po_line.service_date=p_service_date
      and po_line.delivery_location_id=p_delivery_location_id
      and historical_need_revision.service_date=p_service_date
      and historical_need_revision.school_id=p_school_id
      and historical_need_revision.delivery_location_id=p_delivery_location_id
  ), state_base as (
    select exists(select 1 from contribution_ranges where school_id=p_school_id)
        has_need,
      exists(select 1 from atlas_planning.confirmed_need_line_revisions expected
       join atlas_planning.confirmed_need_batches expected_batch using(confirmed_need_batch_id)
       join atlas_planning.confirmed_need_lines expected_line using(confirmed_need_line_id)
       where expected.is_current and expected_batch.source_kind='NEED_GENERATION'
        and expected.school_id=p_school_id and expected.service_date=p_service_date
        and expected.delivery_location_id=p_delivery_location_id
        and (expected.confirmed_quantity is null or expected_line.current_confirmed_need_line_decision_id is null
         or expected_batch.batch_status<>'RELEASED_FOR_PURCHASE_HANDOFF'
         or (expected.confirmed_quantity>0 and not exists(select 1 from contribution_ranges actual
         where actual.confirmed_need_line_revision_id=expected.confirmed_need_line_revision_id
          and actual.confirmed_need_line_decision_id=expected_line.current_confirmed_need_line_decision_id
         group by actual.confirmed_need_line_revision_id
         having sum(actual.contribution_quantity)=expected.confirmed_quantity)))) source_incomplete,
      exists(select 1 from coverage where purchase_order_id is null) missing_po,
      exists(select 1 from historical_commitments
        where commitment_state='CANCELLATION_REQUIRED') relevant_cancellation_required,
      exists(select 1 from historical_commitments
        where commitment_state='REPLACEMENT_REQUIRED') relevant_replacement_required
  ), state as (
    select state_base.*,
      not state_base.source_incomplete and not state_base.missing_po
        and not state_base.relevant_cancellation_required
        and not state_base.relevant_replacement_required procurement_current
    from state_base
  )
  select jsonb_build_object(
    'service_date',p_service_date,'school_id',p_school_id,
    'delivery_location_id',p_delivery_location_id,
    'school_name',(select school_name from scope),
    'delivery_location_name',(select location_name from scope),
    'delivery_address',(select address_text from scope),
    'source_fingerprint',encode(extensions.digest(
      convert_to((select value from facts),'UTF8'),'sha256'),'hex'),
    'ready',(select has_need and not missing_po and procurement_current
      and exists(select 1 from scope) from state),
    'lines',coalesce((select jsonb_agg(jsonb_build_object(
      'ingredient_id',ingredient_id,'ingredient_name',ingredient_name,
      'unit_id',unit_id,'unit_code',unit_code,'quantity',quantity::text,
      'sources',sources) order by ingredient_name,ingredient_id,unit_id) from lines),
      '[]'::jsonb),
    'blockers',(select
      (case when not exists(select 1 from scope)
        then jsonb_build_array('SCHOOL_SCOPE_INVALID') else '[]'::jsonb end)
      || (case when not has_need
        then jsonb_build_array('NO_CURRENT_NEED') else '[]'::jsonb end)
      || (case when relevant_cancellation_required
        then jsonb_build_array('CANCELLATION_REQUIRED') else '[]'::jsonb end)
      || (case when source_incomplete then jsonb_build_array('SOURCE_CHANGED')else '[]'::jsonb end)
      || (case when missing_po
        then jsonb_build_array('PO_COVERAGE_INCOMPLETE') else '[]'::jsonb end)
      || (case when relevant_replacement_required
        then jsonb_build_array('PROCUREMENT_NOT_CURRENT') else '[]'::jsonb end)
      from state),
    'warnings','[]'::jsonb);
$function$
;
revoke all on function atlas_core.school_dispatch_release_preview(date,uuid,uuid,jsonb)from public,anon,authenticated,service_role;

reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_dispatch_release_preview(p_service_date date, p_school_id uuid, p_delivery_location_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select atlas_core.school_dispatch_release_preview(p_service_date,p_school_id,p_delivery_location_id,(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=p_service_date and b.period_end>=p_service_date
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between p_service_date and p_service_date and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between p_service_date and p_service_date and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families));
$function$
;

reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_fulfilment_reconciliation_scope(p_service_date date, p_school_id uuid, p_delivery_location_id uuid, p_continuity jsonb)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with preview as materialized (select atlas_core.school_dispatch_release_preview(
    p_service_date,p_school_id,p_delivery_location_id,p_continuity) value),
  current_release as materialized (
    select release.* from atlas_dispatch.school_dispatch_releases release
    where release.service_date=p_service_date and release.school_id=p_school_id
      and release.delivery_location_id=p_delivery_location_id and release.release_status='RELEASED'
  ), po_lines as materialized (
    select jsonb_build_object('ingredient_id',line->>'ingredient_id',
      'ingredient_name',line->>'ingredient_name','unit_id',line->>'unit_id',
      'unit_code',line->>'unit_code','quantity',
      sum((source->>'covered_quantity')::numeric)::numeric(20,6)::text) value
    from preview cross join lateral jsonb_array_elements(preview.value->'lines') line
    cross join lateral jsonb_array_elements(line->'sources') source
    where source->>'purchase_order_id' is not null
    group by line->>'ingredient_id',line->>'ingredient_name',line->>'unit_id',line->>'unit_code'
  ), pxk_lines as materialized (
    select jsonb_build_object('ingredient_id',line.ingredient_id,
      'ingredient_name',line.ingredient_name_snapshot,'unit_id',line.unit_id,
      'unit_code',line.unit_code_snapshot,'quantity',line.quantity::text) value
    from current_release release join atlas_dispatch.school_dispatch_release_lines line
      on line.school_dispatch_release_id=release.school_dispatch_release_id
  ), comparison as materialized (select atlas_core.school_fulfilment_compare(
    coalesce((select jsonb_agg(value) from po_lines),'[]'::jsonb),
    coalesce((select jsonb_agg(value) from pxk_lines),'[]'::jsonb)) value),
  enriched_details as materialized (
    select coalesce(jsonb_agg(detail||jsonb_build_object(
      'purchase_order_ids',coalesce((select jsonb_agg(document.purchase_order_id
        order by document.document_number) from (
          select distinct po.purchase_order_id,po.document_number
          from preview
          cross join lateral jsonb_array_elements(preview.value->'lines') preview_line
          cross join lateral jsonb_array_elements(preview_line->'sources') source
          join atlas_procurement.purchase_orders po
            on po.purchase_order_id=(source->>'purchase_order_id')::uuid
          where preview_line->>'ingredient_id'=detail->>'ingredient_id'
            and preview_line->>'unit_id'=detail->>'unit_id') document),'[]'::jsonb),
      'school_dispatch_release_line_id',(select line.school_dispatch_release_line_id
        from current_release release
        join atlas_dispatch.school_dispatch_release_lines line
          on line.school_dispatch_release_id=release.school_dispatch_release_id
        where line.ingredient_id=(detail->>'ingredient_id')::uuid
          and line.unit_id=(detail->>'unit_id')::uuid)
    ) order by detail->>'ingredient_name',detail->>'ingredient_id',detail->>'unit_id'),
    '[]'::jsonb) value
    from comparison cross join lateral jsonb_array_elements(comparison.value->'details') detail
  ),
  po_documents as materialized (
    select distinct po.purchase_order_id,po.document_number
    from preview cross join lateral jsonb_array_elements(preview.value->'lines') line
    cross join lateral jsonb_array_elements(line->'sources') source
    join atlas_procurement.purchase_orders po
      on po.purchase_order_id=(source->>'purchase_order_id')::uuid
  ), operational as (
    select case when not (preview.value->>'ready')::boolean then 'BLOCKED'
      when not exists(select 1 from current_release) then 'READY'
      when (select source_fingerprint from current_release)=preview.value->>'source_fingerprint'
        then 'CURRENT' else 'REPLACEMENT_REQUIRED' end pxk_state from preview
  )
  select jsonb_build_object('service_date',p_service_date,'school_id',p_school_id,
    'school_name',preview.value->>'school_name','delivery_location_id',p_delivery_location_id,
    'delivery_location_name',preview.value->>'delivery_location_name',
    'comparison_status',comparison.value->>'comparison_status',
    'quantity_totals_by_unit',comparison.value->'quantity_totals_by_unit',
    'purchase_order_numbers',coalesce((select jsonb_agg(document_number order by document_number)
      from po_documents),'[]'::jsonb),
    'purchase_order_ids',coalesce((select jsonb_agg(purchase_order_id order by document_number)
      from po_documents),'[]'::jsonb),
    'pxk_document_number',(select document_number from current_release),
    'school_dispatch_release_id',(select school_dispatch_release_id from current_release),
    'pxk_state',(select pxk_state from operational),
    'blockers',preview.value->'blockers'||case
      when (select pxk_state from operational)='REPLACEMENT_REQUIRED'
        then jsonb_build_array('PXK_REPLACEMENT_REQUIRED') else '[]'::jsonb end,
    'warnings',preview.value->'warnings','details',enriched_details.value,
    'history',coalesce((select jsonb_agg(atlas_core.school_dispatch_release_json(
      history.school_dispatch_release_id) order by history.released_at desc)
      from atlas_dispatch.school_dispatch_releases history
      where history.service_date=p_service_date and history.school_id=p_school_id
        and history.delivery_location_id=p_delivery_location_id),'[]'::jsonb))
  from preview cross join comparison cross join enriched_details;
$function$
;
revoke all on function atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)from public,anon,authenticated,service_role;

reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_fulfilment_reconciliation_scope(p_service_date date, p_school_id uuid, p_delivery_location_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select atlas_core.school_fulfilment_reconciliation_scope(p_service_date,p_school_id,p_delivery_location_id,(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=p_service_date and b.period_end>=p_service_date
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between p_service_date and p_service_date and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between p_service_date and p_service_date and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families));
$function$
;

reset role;
set role atlas_read_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  with scopes as ($old0$,'')))/length($old0$  with scopes as ($old0$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)/0';end if;
 definition:=replace(definition,$old0$  with scopes as ($old0$,$new0$  with continuity_map as materialized(select (with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_end and b.period_end>=v_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_start and v_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_start and v_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families) value), scopes as ($new0$);
 if (length(definition)-length(replace(definition,$old1$scope.service_date,scope.school_id,scope.delivery_location_id) value) preview$old1$,'')))/length($old1$scope.service_date,scope.school_id,scope.delivery_location_id) value) preview$old1$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)/1';end if;
 definition:=replace(definition,$old1$scope.service_date,scope.school_id,scope.delivery_location_id) value) preview$old1$,$new1$scope.service_date,scope.school_id,scope.delivery_location_id,(select value from continuity_map)) value) preview$new1$);
 if (length(definition)-length(replace(definition,'), visible as (','')))/length('), visible as (')<>1 then raise exception 'C PXK visible materialization anchor missing';end if;
 definition:=replace(definition,'), visible as (','), visible as materialized (');
 execute definition;
end;$official$;

reset role;
set role atlas_read_runtime;
do $official$
declare definition text:=pg_get_functiondef('atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)'::regprocedure);
begin
 if (length(definition)-length(replace(definition,$old0$  with confirmed_scopes as ($old0$,'')))/length($old0$  with confirmed_scopes as ($old0$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)/0';end if;
 definition:=replace(definition,$old0$  with confirmed_scopes as ($old0$,$new0$  with continuity_map as materialized(select (with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_end and b.period_end>=v_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_start and v_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_start and v_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families) value), confirmed_scopes as ($new0$);
 if (length(definition)-length(replace(definition,$old1$scope.school_id,scope.delivery_location_id) value) row$old1$,'')))/length($old1$scope.school_id,scope.delivery_location_id) value) row$old1$)<>1 then raise exception 'C official anchor missing: atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)/1';end if;
 definition:=replace(definition,$old1$scope.school_id,scope.delivery_location_id) value) row$old1$,$new1$scope.school_id,scope.delivery_location_id,(select value from continuity_map)) value) row$new1$);
 execute definition;
end;$official$;


-- Preserve the incumbent ordinary-source reconstruction budget. Resolve frozen
-- history only for a retained PH revision whose raw supporting identity changed.
reset role;
do $lazy_continuity$
declare target record;definition text;condition text:=$condition$exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions c_revision
 join atlas_procurement.school_catering_allocation_families c_family using(family_id)
 left join atlas_planning.purchase_handoff_revisions c_handoff
  on c_handoff.purchase_handoff_revision_id=c_revision.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches c_batch using(purchase_handoff_batch_id)
 cross join lateral(select atlas_core.school_catering_family_projection(c_family.service_date,
  c_family.delivery_location_id,c_family.ingredient_id,c_family.unit_id)value)c_projection
 where c_revision.is_current and c_revision.source_kind='PURCHASE_HANDOFF'
  and coalesce(c_revision.source_confirmed_need_batch_id,c_batch.confirmed_need_batch_id)=BATCH
  and(c_revision.source_fingerprint is distinct from c_projection.value->>'source_fingerprint'
   or c_revision.family_quantity is distinct from atlas_core.pa_05b_safe_numeric(c_projection.value->>'family_quantity')))$condition$;
begin
 for target in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('atlas_core','atlas_api')and p.prokind='f'and(
  p.prosrc like '%from continuity_roots where confirmed_need_batch_id is not null%'
  or p.prosrc like '%with continuity as materialized(select atlas_core.purchase_review_continuity_context(p_batch) value)%'
  or(p.proname='get_confirmed_supplier_allocation_workbench'and p.prosrc like '%into continuity_contexts%'))loop
  definition:=pg_get_functiondef(target.oid);
  definition:=replace(definition,'from continuity_roots where confirmed_need_batch_id is not null',
   'from continuity_roots where confirmed_need_batch_id is not null and '||replace(condition,'BATCH','continuity_roots.confirmed_need_batch_id'));
  definition:=replace(definition,'with continuity as materialized(select atlas_core.purchase_review_continuity_context(p_batch) value)',
   'with continuity as materialized(select atlas_core.purchase_review_continuity_context(p_batch) value where '||replace(condition,'BATCH','p_batch')||')');
  definition:=replace(definition,'batches where batch_id is not null;',
   'batches where batch_id is not null and '||replace(condition,'BATCH','batch_id::uuid')||';');
  execute definition;
 end loop;
end;$lazy_continuity$;


reset role;
do $lazy_promotion$
declare definition text:=pg_get_functiondef('atlas_core.purchase_review_promote_allocations(uuid,uuid,uuid,uuid,uuid)'::regprocedure);
begin
 if strpos(definition,'continuity:=atlas_core.purchase_review_continuity_context(p_batch);')=0 then raise exception 'C promotion lazy anchor missing';end if;
 definition:=replace(definition,'continuity:=atlas_core.purchase_review_continuity_context(p_batch);',
 $guard$if exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions c_lazy_revision
 join atlas_procurement.school_catering_allocation_families c_lazy_family using(family_id)
 join atlas_planning.purchase_handoff_revisions c_lazy_handoff on c_lazy_handoff.purchase_handoff_revision_id=c_lazy_revision.source_purchase_handoff_revision_id
 join atlas_planning.purchase_handoff_batches c_lazy_batch using(purchase_handoff_batch_id)
 cross join lateral(select atlas_core.school_catering_family_projection(c_lazy_family.service_date,c_lazy_family.delivery_location_id,c_lazy_family.ingredient_id,c_lazy_family.unit_id)value)c_lazy_projection
 where c_lazy_revision.is_current and c_lazy_revision.source_kind='PURCHASE_HANDOFF'and c_lazy_batch.confirmed_need_batch_id=p_batch
 and(c_lazy_revision.source_fingerprint is distinct from c_lazy_projection.value->>'source_fingerprint'
 or c_lazy_revision.family_quantity is distinct from atlas_core.pa_05b_safe_numeric(c_lazy_projection.value->>'family_quantity')))then continuity:=atlas_core.purchase_review_continuity_context(p_batch);end if;$guard$);
 execute definition;
end;$lazy_promotion$;

-- Task7 fresh phase-local proofs preserve every pre/post-wait readiness gate.

reset role;
set role atlas_procurement_command_runtime;
CREATE FUNCTION atlas_core.purchase_review_official_continuity_map(p_date_start date,p_date_end date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=p_date_end and b.period_end>=p_date_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between p_date_start and p_date_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null and exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions c_revision
 join atlas_procurement.school_catering_allocation_families c_family using(family_id)
 left join atlas_planning.purchase_handoff_revisions c_handoff
  on c_handoff.purchase_handoff_revision_id=c_revision.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches c_batch using(purchase_handoff_batch_id)
 cross join lateral(select atlas_core.school_catering_family_projection(c_family.service_date,
  c_family.delivery_location_id,c_family.ingredient_id,c_family.unit_id)value)c_projection
 where c_revision.is_current and c_revision.source_kind='PURCHASE_HANDOFF'
  and coalesce(c_revision.source_confirmed_need_batch_id,c_batch.confirmed_need_batch_id)=continuity_roots.confirmed_need_batch_id
  and(c_revision.source_fingerprint is distinct from c_projection.value->>'source_fingerprint'
   or c_revision.family_quantity is distinct from atlas_core.pa_05b_safe_numeric(c_projection.value->>'family_quantity')))
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between p_date_start and p_date_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families;
$function$;

ALTER FUNCTION atlas_core.purchase_review_official_continuity_map(date,date) OWNER TO atlas_procurement_command_runtime;
REVOKE ALL ON FUNCTION atlas_core.purchase_review_official_continuity_map(date,date) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION atlas_core.purchase_review_official_continuity_map(date,date) TO atlas_read_runtime;


reset role;
set role atlas_owner;
CREATE FUNCTION atlas_core.school_catering_po_date_readiness(p_service_date date,p_continuity jsonb) RETURNS jsonb LANGUAGE sql STABLE SET search_path TO '' AS $function$
  with continuity_families as materialized(
    select key::uuid family_revision_id,value from jsonb_each(coalesce(p_continuity,'{}'::jsonb))
  ), source_families as (
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

    union select nr.service_date,nr.delivery_location_id,nr.ingredient_id,nr.unit_id
    from atlas_planning.confirmed_need_line_revisions nr
    join atlas_planning.confirmed_need_batches nb using(confirmed_need_batch_id)
    where nr.is_current and nr.service_date=p_service_date and nb.source_kind='NEED_GENERATION'
  ), states as (
    select sf.*,f.family_id,r.family_revision_id,r.source_fingerprint,
      projection.value projection,
      (select count(*) from atlas_procurement.school_catering_allocation_supplier_splits s
        where s.family_revision_id=r.family_revision_id) split_count,
      (select coalesce(sum(s.allocated_quantity),0)
        from atlas_procurement.school_catering_allocation_supplier_splits s
        where s.family_revision_id=r.family_revision_id) split_quantity,
      case
        when exists(select 1 from atlas_planning.confirmed_need_line_revisions nr
          join atlas_planning.confirmed_need_batches nb using(confirmed_need_batch_id)
          where nr.is_current and nb.source_kind='NEED_GENERATION'
           and row(nr.service_date,nr.delivery_location_id,nr.ingredient_id,nr.unit_id)=row(sf.service_date,sf.delivery_location_id,sf.ingredient_id,sf.unit_id)
           and nb.batch_status<>'RELEASED_FOR_PURCHASE_HANDOFF')then 'CORRECTION_PENDING'
        when f.family_id is null or r.family_revision_id is null then 'ALLOCATION_MISSING'
        when (r.source_fingerprint is distinct from projection.value ->> 'source_fingerprint'
          or r.family_quantity is distinct from
            atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) and not coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false)
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
      on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
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
$function$;

ALTER FUNCTION atlas_core.school_catering_po_date_readiness(date,jsonb) OWNER TO atlas_owner;
REVOKE ALL ON FUNCTION atlas_core.school_catering_po_date_readiness(date,jsonb) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION atlas_core.school_catering_po_date_readiness(date,jsonb) TO atlas_read_runtime,atlas_procurement_command_runtime;


reset role;
set role atlas_procurement_command_runtime;
CREATE FUNCTION atlas_core.purchase_review_po_coverage(p_date date,p_continuity jsonb) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
  with continuity_families as materialized(
    select key::uuid family_revision_id,value from jsonb_each(coalesce(p_continuity,'{}'::jsonb))
  ), expected as materialized (
    select f.*,s.supplier_split_id,s.supplier_id,s.allocated_quantity
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
    join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
    where f.service_date=p_date and r.is_current and r.source_kind='PURCHASE_HANDOFF'
      and (r.source_fingerprint=atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->>'source_fingerprint' or coalesce((select value->>'applicable'='true'from continuity_families where family_revision_id=r.family_revision_id),false))
  ), actual as materialized (
    select po.supplier_id,po.purchase_order_status,r.revision_status,l.*
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
    join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
    where po.purchase_order_kind='SCHOOL_CATERING' and po.school_catering_service_date=p_date and r.is_current
  )
  select coalesce((atlas_core.school_catering_po_date_readiness(p_date,p_continuity)->>'ready')::boolean,false) and exists(select 1 from expected)
    and (select count(*) from expected)=(select count(*) from actual)
    and not exists(select 1 from expected e where not exists(
      select 1 from actual l where l.supplier_id=e.supplier_id
        and l.purchase_order_status=l.revision_status and l.revision_status in ('DRAFT','RELEASED_TO_SUPPLIER')
        and l.school_catering_allocation_supplier_split_id=e.supplier_split_id
        and l.ordered_quantity=e.allocated_quantity and l.delivery_location_id=e.delivery_location_id
        and l.ingredient_id=e.ingredient_id and l.unit_id=e.unit_id and l.service_date=e.service_date));
$function$;

ALTER FUNCTION atlas_core.purchase_review_po_coverage(date,jsonb) OWNER TO atlas_procurement_command_runtime;
REVOKE ALL ON FUNCTION atlas_core.purchase_review_po_coverage(date,jsonb) FROM PUBLIC,anon,authenticated,service_role;


reset role;
set role atlas_owner;
CREATE OR REPLACE FUNCTION atlas_core.school_catering_po_date_readiness(p_service_date date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 select atlas_core.school_catering_po_date_readiness(p_service_date,
   atlas_core.purchase_review_official_continuity_map(p_service_date,p_service_date));
$function$;


reset role;
set role atlas_procurement_command_runtime;
CREATE OR REPLACE FUNCTION atlas_core.purchase_review_po_coverage(p_date date)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select atlas_core.purchase_review_po_coverage(p_date,
   atlas_core.purchase_review_official_continuity_map(p_date,p_date));
$function$;


reset role;
set role atlas_procurement_command_runtime;
CREATE OR REPLACE FUNCTION atlas_core.purchase_review_preparation_po_frontier(p_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_readiness jsonb;
  continuity_map jsonb;
  v_has_requirement boolean := false;
  v_has_replacement boolean := false;
  v_has_missing boolean := false;
begin
  continuity_map:=atlas_core.purchase_review_official_continuity_map(p_date,p_date);
  if atlas_core.purchase_review_po_coverage(p_date,continuity_map) then
    return jsonb_build_object(
      'acceptable',true,
      'frontier','EXACT_COVERAGE',
      'blockers','[]'::jsonb
    );
  end if;

  v_readiness := atlas_core.school_catering_po_date_readiness(p_date,continuity_map);
  if not coalesce((v_readiness ->> 'ready')::boolean,false) then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','OTHER_INVALID_STATE',
      'blockers',jsonb_build_array(
        'Phân bổ nhà cung ứng chưa khớp với nhu cầu bàn giao hiện hành.'
      )
    );
  end if;

  if exists(
    select 1
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_date
      and po.purchase_order_status='RELEASED_TO_SUPPLIER'
      and atlas_core.school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id,continuity_map
      )='CANCELLATION_REQUIRED'
  ) then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','CANCELLATION_REQUIRED',
      'blockers',jsonb_build_array(
        'Có đơn mua đã phát hành cần quy trình hủy trước khi tiếp tục.'
      )
    );
  end if;

  if exists(
    select 1
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_date
      and po.purchase_order_status='DRAFT'
      and (
        por.revision_status<>'DRAFT'
        or (
          po.replaces_purchase_order_id is null
          and (
            atlas_core.school_catering_po_commitment_state(
              po.purchase_order_id,por.purchase_order_revision_id,continuity_map
            )<>'DRAFT_CURRENT'
            or exists(
              select 1
              from atlas_procurement.purchase_orders released
              where released.purchase_order_kind='SCHOOL_CATERING'
                and released.supplier_id=po.supplier_id
                and released.school_catering_service_date=p_date
                and released.purchase_order_status='RELEASED_TO_SUPPLIER'
            )
          )
        )
        or (
          po.replaces_purchase_order_id is not null
          and not exists(
            select 1
            from atlas_procurement.purchase_orders predecessor
            join atlas_procurement.purchase_order_revisions predecessor_revision
              on predecessor_revision.purchase_order_id=predecessor.purchase_order_id
             and predecessor_revision.is_current
            where predecessor.purchase_order_id=po.replaces_purchase_order_id
              and predecessor.purchase_order_kind='SCHOOL_CATERING'
              and predecessor.supplier_id=po.supplier_id
              and predecessor.school_catering_service_date=p_date
              and predecessor.purchase_order_status='RELEASED_TO_SUPPLIER'
              and atlas_core.school_catering_po_commitment_state(
                predecessor.purchase_order_id,
                predecessor_revision.purchase_order_revision_id,continuity_map
              )='REPLACEMENT_REQUIRED'
          )
        )
      )
  ) then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','OTHER_INVALID_STATE',
      'blockers',jsonb_build_array(
        'Đơn mua nháp hiện có không còn khớp với phân bổ nhà cung ứng hiện hành. Hãy làm mới hoặc xử lý đơn nháp trước khi tiếp tục.'
      )
    );
  end if;

  with expected as materialized (
    select f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      s.supplier_split_id,s.supplier_id,s.allocated_quantity
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
    where f.service_date=p_date
      and r.source_kind='PURCHASE_HANDOFF'
      and r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=atlas_core.pa_05b_safe_numeric(
        projection.value ->> 'family_quantity'
      )
  ), active_actual as materialized (
    select po.supplier_id,po.purchase_order_status,por.revision_status,polr.*
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions por
      on por.purchase_order_id=po.purchase_order_id and por.is_current
    join atlas_procurement.purchase_order_line_revisions polr
      on polr.purchase_order_revision_id=por.purchase_order_revision_id
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.school_catering_service_date=p_date
      and po.purchase_order_status in ('DRAFT','RELEASED_TO_SUPPLIER')
  ), supplier_frontiers as (
    select supplier.supplier_id,
      (
        (select count(*) from expected e
          where e.supplier_id=supplier.supplier_id)=
        (select count(*) from active_actual a
          where a.supplier_id=supplier.supplier_id)
        and not exists(
          select 1
          from expected e
          where e.supplier_id=supplier.supplier_id
            and not exists(
              select 1
              from active_actual a
              where a.supplier_id=e.supplier_id
                and a.purchase_order_status=a.revision_status
                and a.revision_status in ('DRAFT','RELEASED_TO_SUPPLIER')
                and a.school_catering_allocation_supplier_split_id=e.supplier_split_id
                and a.ordered_quantity=e.allocated_quantity
                and a.delivery_location_id=e.delivery_location_id
                and a.ingredient_id=e.ingredient_id
                and a.unit_id=e.unit_id
                and a.service_date=e.service_date
            )
        )
      ) exact_coverage,
      exists(
        select 1
        from atlas_procurement.purchase_orders po
        join atlas_procurement.purchase_order_revisions por
          on por.purchase_order_id=po.purchase_order_id and por.is_current
        where po.purchase_order_kind='SCHOOL_CATERING'
          and po.school_catering_service_date=p_date
          and po.supplier_id=supplier.supplier_id
          and po.purchase_order_status='RELEASED_TO_SUPPLIER'
          and atlas_core.school_catering_po_commitment_state(
            po.purchase_order_id,por.purchase_order_revision_id,continuity_map
          )='REPLACEMENT_REQUIRED'
      ) replacement_frontier
    from (select distinct e.supplier_id from expected e) supplier
  )
  select exists(select 1 from supplier_frontiers),
    coalesce(bool_or(replacement_frontier),false),
    coalesce(bool_or(not exact_coverage and not replacement_frontier),true)
  into v_has_requirement,v_has_replacement,v_has_missing
  from supplier_frontiers;

  if not v_has_requirement or v_has_missing then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','MISSING_COVERAGE',
      'blockers',jsonb_build_array(
        'Thiếu bao phủ đơn mua hiện hành cho một hoặc nhiều nhà cung ứng.'
      )
    );
  end if;

  if not v_has_replacement then
    return jsonb_build_object(
      'acceptable',false,
      'frontier','OTHER_INVALID_STATE',
      'blockers',jsonb_build_array(
        'Trạng thái đơn mua hiện hành chưa phù hợp để tiếp tục.'
      )
    );
  end if;

  return jsonb_build_object(
    'acceptable',true,
    'frontier','REPLACEMENT_FRONTIER',
    'blockers','[]'::jsonb
  );
end;
$function$;


reset role;
set role atlas_procurement_command_runtime;
CREATE OR REPLACE FUNCTION atlas_api.create_school_catering_purchase_order_drafts(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  continuity_map jsonb;
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
  perform atlas_core.confirmed_need_correction_lock_days(v_date_start,v_date_end);
  continuity_map:=atlas_core.purchase_review_official_continuity_map(v_date_start,v_date_end);
  v_ready_dates:='[]'::jsonb;v_skipped_dates:='[]'::jsonb;
  for v_date in select generate_series(v_date_start,v_date_end,interval '1 day')::date loop
    v_readiness := atlas_core.school_catering_po_date_readiness(v_date,continuity_map);
    if (v_readiness ->> 'ready')::boolean then
      v_ready_dates := v_ready_dates || jsonb_build_array(to_char(v_date,'YYYY-MM-DD'));
    else
      v_skipped_dates := v_skipped_dates || jsonb_build_array(v_readiness);
    end if;
  end loop;

  -- Match release ordering: uniqueness guard, source evidence, then family rows.
  for v_supplier in
    select distinct f.service_date,s.supplier_id
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date between v_date_start and v_date_end
      and ((r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))
    order by f.service_date,s.supplier_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'school-catering-po:' || v_supplier.service_date::text || ':' || v_supplier.supplier_id::text,0));
  end loop;

  for v_row in
    select f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,
        'allocated_quantity',s.allocated_quantity) order by s.supplier_id) splits
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r
      on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date between v_date_start and v_date_end
      and ((r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))
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
    on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
  cross join lateral (
    select atlas_core.school_catering_family_projection(
      f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
    ) value
  ) projection
  where f.service_date between v_date_start and v_date_end
    and ((r.source_fingerprint=projection.value ->> 'source_fingerprint'
    and r.family_quantity=
      atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))
  order by f.family_id for update of f,r;

  continuity_map:=atlas_core.purchase_review_official_continuity_map(v_date_start,v_date_end);
  -- Recompute readiness under the deterministic source locks.
  v_ready_dates := '[]'::jsonb; v_skipped_dates := '[]'::jsonb;
  for v_date in select generate_series(v_date_start,v_date_end,interval '1 day')::date loop
    v_readiness := atlas_core.school_catering_po_date_readiness(v_date,continuity_map);
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
      on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.family_revision_id=r.family_revision_id
    cross join lateral (
      select atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      ) value
    ) projection
    where f.service_date between v_date_start and v_date_end
      and to_char(f.service_date,'YYYY-MM-DD') in (
      select value #>> '{}' from jsonb_array_elements(v_ready_dates)
    )
      and ((r.source_fingerprint=projection.value ->> 'source_fingerprint'
      and r.family_quantity=
        atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))
    order by f.service_date,s.supplier_id
  loop
    select null::uuid purchase_order_revision_id,0::integer revision_number into v_prior;

    perform 1
    from atlas_procurement.purchase_orders po
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.supplier_id=v_supplier.supplier_id
      and po.school_catering_service_date=v_supplier.service_date
      and po.purchase_order_status='RELEASED_TO_SUPPLIER'
    for update;
    if found then continue; end if;

    perform 1
    from atlas_procurement.purchase_orders po
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.supplier_id=v_supplier.supplier_id
      and po.school_catering_service_date=v_supplier.service_date
      and po.purchase_order_status='DRAFT'
      and po.replaces_purchase_order_id is not null
    for update;
    if found then continue; end if;

    select po.purchase_order_id,po.purchase_order_status,po.version
      into v_root
    from atlas_procurement.purchase_orders po
    where po.purchase_order_kind='SCHOOL_CATERING'
      and po.supplier_id=v_supplier.supplier_id
      and po.school_catering_service_date=v_supplier.service_date
      and po.purchase_order_status='DRAFT'
      and po.replaces_purchase_order_id is null
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
        on r.family_id=f.family_id and r.is_current and r.source_kind='PURCHASE_HANDOFF'
      join atlas_procurement.school_catering_allocation_supplier_splits s
        on s.family_revision_id=r.family_revision_id
      cross join lateral (
        select atlas_core.school_catering_family_projection(
          f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
        ) value
      ) projection
      where f.service_date=v_supplier.service_date and s.supplier_id=v_supplier.supplier_id
        and ((r.source_fingerprint=projection.value ->> 'source_fingerprint'
        and r.family_quantity=
          atlas_core.pa_05b_safe_numeric(projection.value ->> 'family_quantity')) or coalesce(continuity_map->(r.family_revision_id::text)->>'applicable'='true',false))
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
    'authoritative_readback',jsonb_build_object(
      'purchase_order_ids',v_created || v_regenerated,
      'created_purchase_order_ids',v_created,
      'regenerated_purchase_order_ids',v_regenerated,
      'ready_dates',v_ready_dates,'skipped_dates',v_skipped_dates),
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
$function$;

-- Task7 share only a fresh backend evaluation within this projection statement.
reset role;
set role atlas_confirmed_need_review_runtime;
CREATE FUNCTION atlas_core.rmvp_07_validated_facts_projection(batch_id uuid, validation_attempt_id uuid, p_evaluation jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_items jsonb;
  v_issue_items jsonb;
  v_item jsonb;
  v_line atlas_planning.confirmed_need_lines%rowtype;
  v_revision atlas_planning.confirmed_need_line_revisions%rowtype;
  v_members jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_evaluation jsonb;
begin
  if validation_attempt_id is null then
    v_evaluation := coalesce(p_evaluation, atlas_core.rmvp_06_canonical_evaluation(batch_id));
    v_items := v_evaluation -> 'ordered_lines';
    v_issue_items := v_evaluation -> 'ordered_issues';
  else
    if not exists (
      select 1
      from atlas_planning.confirmed_need_validation_attempts attempt
      where attempt.confirmed_need_validation_attempt_id = validation_attempt_id
        and attempt.confirmed_need_batch_id = batch_id
    ) then
      raise exception using
        errcode = '22023',
        message = 'The RMVP-07 validation projection source is unavailable';
    end if;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'confirmed_need_line_id', observation.confirmed_need_line_id,
      'controlled_unit_id', observation.controlled_unit_id,
      'observed_current_revision_count',
        observation.observed_current_revision_count,
      'observed_current_decision_count',
        observation.observed_current_decision_count,
      'observed_eligible_policy_count',
        observation.observed_eligible_policy_count,
      'observed_source_membership_count',
        observation.observed_source_membership_count,
      'line_sort_position', observation.line_sort_position,
      'current_confirmed_need_line_revision_id',
        observation.current_confirmed_need_line_revision_id,
      'current_confirmed_need_line_decision_id',
        observation.current_confirmed_need_line_decision_id,
      'planning_quantity_policy_id', observation.planning_quantity_policy_id,
      'planning_quantity_policy_revision_id',
        observation.planning_quantity_policy_revision_id,
      'need_generation_run_id', observation.need_generation_run_id,
      'need_generation_run_version', observation.need_generation_run_version,
      'need_generation_release_snapshot_id',
        observation.need_generation_release_snapshot_id,
      'theoretical_quantity', observation.theoretical_quantity,
      'confirmed_quantity', observation.confirmed_quantity,
      'planning_tick_count', observation.planning_tick_count,
      'source_membership_total', observation.source_membership_total
    ) order by observation.line_sort_position), '[]'::jsonb)
    into v_items
    from atlas_planning.confirmed_need_validation_lines observation
    where observation.confirmed_need_validation_attempt_id
      = validation_attempt_id;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'issue_sort_position', issue.issue_sort_position,
      'confirmed_need_line_id', issue.confirmed_need_line_id,
      'severity', issue.severity,
      'issue_code', issue.issue_code
    ) order by issue.issue_sort_position), '[]'::jsonb)
    into v_issue_items
    from atlas_planning.confirmed_need_validation_issues issue
    where issue.confirmed_need_validation_attempt_id = validation_attempt_id;
  end if;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(coalesce(v_items, '[]'::jsonb))
    order by (value ->> 'line_sort_position')::integer
  loop
    v_line := null;
    v_revision := null;

    select line.*
    into strict v_line
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_line_id
      = atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id')
      and line.confirmed_need_batch_id = batch_id;

    select revision.*
    into v_revision
    from atlas_planning.confirmed_need_line_revisions revision
    where revision.confirmed_need_line_revision_id
      = atlas_core.pa_05b_safe_uuid(
        v_item ->> 'current_confirmed_need_line_revision_id'
      )
      and revision.confirmed_need_line_id = v_line.confirmed_need_line_id;

    perform 1
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_line_decision_id
      = atlas_core.pa_05b_safe_uuid(
        v_item ->> 'current_confirmed_need_line_decision_id'
      )
      and decision.confirmed_need_line_id = v_line.confirmed_need_line_id;

    select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'confirmed_need_line_revision_contribution_id',
        contribution.confirmed_need_line_revision_contribution_id,
      'need_generation_release_snapshot_line_id',
        contribution.need_generation_release_snapshot_line_id,
      'theoretical_need_line_id', contribution.theoretical_need_line_id,
      'source_theoretical_quantity',
        atlas_core.rmvp_07_canonical_decimal(
          contribution.source_theoretical_quantity
        ),
      'controlled_contribution_quantity',
        atlas_core.rmvp_07_canonical_decimal(
          contribution.controlled_contribution_quantity
        )
    ) order by contribution.confirmed_need_line_revision_contribution_id),
    '[]'::jsonb)
    into v_members
    from atlas_planning.confirmed_need_line_revision_contributions contribution
    where contribution.confirmed_need_line_revision_id
      = v_revision.confirmed_need_line_revision_id;

    v_lines := v_lines || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'line_sort_position', (v_item ->> 'line_sort_position')::integer,
        'confirmed_need_line_id', v_line.confirmed_need_line_id,
        'service_date', v_line.service_date,
        'customer_id', v_line.customer_id,
        'school_id', v_line.school_id,
        'delivery_location_id', v_line.delivery_location_id,
        'ingredient_id', v_line.ingredient_id,
        'current_confirmed_need_line_revision_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'current_confirmed_need_line_revision_id'
          ),
        'current_confirmed_need_line_decision_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'current_confirmed_need_line_decision_id'
          ),
        'controlled_unit_id',
          atlas_core.pa_05b_safe_uuid(v_item ->> 'controlled_unit_id'),
        'planning_quantity_policy_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'planning_quantity_policy_id'
          ),
        'planning_quantity_policy_revision_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'planning_quantity_policy_revision_id'
          ),
        'need_generation_run_id',
          atlas_core.pa_05b_safe_uuid(v_item ->> 'need_generation_run_id'),
        'need_generation_run_version',
          nullif(v_item ->> 'need_generation_run_version', '')::bigint,
        'need_generation_release_snapshot_id',
          atlas_core.pa_05b_safe_uuid(
            v_item ->> 'need_generation_release_snapshot_id'
          ),
        'theoretical_quantity', case
          when v_item ->> 'theoretical_quantity' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'theoretical_quantity')::numeric
          ) end,
        'confirmed_quantity', case
          when v_item ->> 'confirmed_quantity' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'confirmed_quantity')::numeric
          ) end,
        'planning_tick_count', case
          when v_item ->> 'planning_tick_count' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'planning_tick_count')::numeric
          ) end,
        'source_membership_count',
          (v_item ->> 'observed_source_membership_count')::integer,
        'source_membership_total', case
          when v_item ->> 'source_membership_total' is null then null
          else atlas_core.rmvp_07_canonical_decimal(
            (v_item ->> 'source_membership_total')::numeric
          ) end,
        'ordered_source_members', v_members
      )
    );
  end loop;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'issue_sort_position', (item ->> 'issue_sort_position')::integer,
    'confirmed_need_line_id',
      atlas_core.pa_05b_safe_uuid(item ->> 'confirmed_need_line_id'),
    'severity', item ->> 'severity',
    'issue_code', item ->> 'issue_code'
  ) order by (item ->> 'issue_sort_position')::integer), '[]'::jsonb)
  into v_issues
  from pg_catalog.jsonb_array_elements(
    coalesce(v_issue_items, '[]'::jsonb)
  ) item;

  return pg_catalog.jsonb_build_object(
    'projection_version', 'RMVP-07-VALIDATED-FACTS.v1',
    'confirmed_need_batch_id', batch_id,
    'ordered_lines', v_lines,
    'ordered_issues', v_issues
  );
end;
$function$;

ALTER FUNCTION atlas_core.rmvp_07_validated_facts_projection(uuid,uuid,jsonb) OWNER TO atlas_confirmed_need_review_runtime;
REVOKE ALL ON FUNCTION atlas_core.rmvp_07_validated_facts_projection(uuid,uuid,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION atlas_core.rmvp_07_validated_facts_projection(batch_id uuid, validation_attempt_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  return atlas_core.rmvp_07_validated_facts_projection(batch_id,validation_attempt_id,null::jsonb);
end;
$function$;

CREATE OR REPLACE FUNCTION atlas_core.purchase_review_confirmed_sources(p_start date, p_end date)
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with evaluated_batches as materialized (
    select b.*,atlas_core.rmvp_06_canonical_evaluation(b.confirmed_need_batch_id) evaluation
    from atlas_planning.confirmed_need_batches b
    where b.source_kind='NEED_GENERATION' and b.period_start<=p_end and b.period_end>=p_start
      and exists(select 1 from atlas_planning.need_generation_runs run
        where run.need_generation_run_id=b.current_need_generation_run_id
          and run.run_status='RELEASED_FOR_CONFIRMATION'
          and not exists(select 1 from atlas_planning.need_generation_runs later
            where later.planning_input_set_id=run.planning_input_set_id and later.attempt_ordinal>run.attempt_ordinal))
  ), batches as materialized (
    select b.confirmed_need_batch_id,b.version,b.batch_status,b.evaluation->>'outcome' outcome,
      atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id,null::uuid,b.evaluation) facts
    from evaluated_batches b
  ), lines as (
    select b.confirmed_need_batch_id,b.version,b.batch_status,b.outcome,
      (fact->>'service_date')::date service_date,(fact->>'delivery_location_id')::uuid delivery_location_id,
      (fact->>'ingredient_id')::uuid ingredient_id,(fact->>'controlled_unit_id')::uuid unit_id,
      (fact->>'school_id')::uuid school_id,(fact->>'customer_id')::uuid customer_id,
      fact, (fact->>'confirmed_quantity')::numeric confirmed_quantity
    from batches b cross join lateral jsonb_array_elements(b.facts->'ordered_lines') fact
    where (fact->>'service_date')::date between p_start and p_end
  ), families as (
    select confirmed_need_batch_id,version,batch_status,service_date,delivery_location_id,ingredient_id,unit_id,
      outcome='VALIDATED' complete,
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
      delivery_location_id,ingredient_id,unit_id,outcome
  )
  select jsonb_build_object('source_kind','CONFIRMED_NEED',
    'source_confirmed_need_batch_id',confirmed_need_batch_id,'source_confirmed_need_batch_version',version,
    'batch_status',batch_status,'service_date',service_date,'delivery_location_id',delivery_location_id,
    'ingredient_id',ingredient_id,'unit_id',unit_id,'complete',complete,
    'family_quantity',case when complete then quantity::text else null end,
    'contributions',contributions,'source_fingerprint',encode(sha256(convert_to(
      jsonb_build_object('batch_id',confirmed_need_batch_id,'facts',facts)::text,'UTF8')),'hex'))
  from families;
$function$;

-- Task7 reuse one fresh official map only within the current date read.
reset role;
set role atlas_read_runtime;
CREATE OR REPLACE FUNCTION atlas_core.school_catering_procurement_date_current(p_service_date date)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with official_map as materialized (
    select atlas_core.purchase_review_official_continuity_map(p_service_date,p_service_date) value
  ), current_suppliers as (
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
  select (atlas_core.school_catering_po_date_readiness(p_service_date,(select value from official_map))
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
            po.purchase_order_id,por.purchase_order_revision_id,(select value from official_map))='CURRENT'
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
          po.purchase_order_id,por.purchase_order_revision_id,(select value from official_map))<>'CURRENT'
    );
$function$;

reset role;
set role atlas_owner;


reset role;
set role atlas_read_runtime;
CREATE FUNCTION atlas_core.school_catering_procurement_date_current(p_service_date date,p_continuity jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with official_map as materialized (
    select coalesce(p_continuity,'{}'::jsonb) value
  ), current_suppliers as (
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
  select (atlas_core.school_catering_po_date_readiness(p_service_date,(select value from official_map))
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
            po.purchase_order_id,por.purchase_order_revision_id,(select value from official_map))='CURRENT'
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
          po.purchase_order_id,por.purchase_order_revision_id,(select value from official_map))<>'CURRENT'
    );
$function$;

ALTER FUNCTION atlas_core.school_catering_procurement_date_current(date,jsonb) OWNER TO atlas_read_runtime;
REVOKE ALL ON FUNCTION atlas_core.school_catering_procurement_date_current(date,jsonb) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION atlas_core.school_catering_procurement_date_current(p_service_date date)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select atlas_core.school_catering_procurement_date_current(p_service_date,
    atlas_core.purchase_review_official_continuity_map(p_service_date,p_service_date));
$function$;

CREATE OR REPLACE FUNCTION atlas_api.get_school_catering_purchase_orders_v2_base(request jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  continuity_map jsonb;
  v_base jsonb; v_rows jsonb; v_current boolean; v_date_start date; v_date_end date;
begin
  v_base := atlas_api.get_school_catering_purchase_orders_v1_base(request);
  if not coalesce((v_base ->> 'success')::boolean,false) then return v_base; end if;
  v_date_start := (v_base ->> 'date_start')::date;
  v_date_end := (v_base ->> 'date_end')::date;

  continuity_map:=(with continuity_roots as materialized (
 select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
 where b.source_kind='NEED_GENERATION' and b.period_start<=v_date_end and b.period_end>=v_date_start
 union select coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ), continuity_contexts as materialized (
 select confirmed_need_batch_id,atlas_core.purchase_review_continuity_context(confirmed_need_batch_id) value
 from continuity_roots where confirmed_need_batch_id is not null and exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions c_revision
 join atlas_procurement.school_catering_allocation_families c_family using(family_id)
 left join atlas_planning.purchase_handoff_revisions c_handoff
  on c_handoff.purchase_handoff_revision_id=c_revision.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches c_batch using(purchase_handoff_batch_id)
 cross join lateral(select atlas_core.school_catering_family_projection(c_family.service_date,
  c_family.delivery_location_id,c_family.ingredient_id,c_family.unit_id)value)c_projection
 where c_revision.is_current and c_revision.source_kind='PURCHASE_HANDOFF'
  and coalesce(c_revision.source_confirmed_need_batch_id,c_batch.confirmed_need_batch_id)=continuity_roots.confirmed_need_batch_id
  and(c_revision.source_fingerprint is distinct from c_projection.value->>'source_fingerprint'
   or c_revision.family_quantity is distinct from atlas_core.pa_05b_safe_numeric(c_projection.value->>'family_quantity')))
 ), continuity_families as materialized (
 select r.family_revision_id,atlas_core.purchase_review_family_continuity(r.family_revision_id,'OFFICIAL',context.value) value
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 left join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_revision_id=r.source_purchase_handoff_revision_id
 left join atlas_planning.purchase_handoff_batches hb using(purchase_handoff_batch_id)
 join continuity_contexts context on context.confirmed_need_batch_id=coalesce(r.source_confirmed_need_batch_id,hb.confirmed_need_batch_id)
 where f.service_date between v_date_start and v_date_end and r.is_current
 ) select coalesce(jsonb_object_agg(family_revision_id::text,value),'{}')from continuity_families);
  with date_states as materialized(select service_date,atlas_core.school_catering_po_date_readiness(service_date,continuity_map) value from(select distinct school_catering_service_date service_date from atlas_procurement.purchase_orders where school_catering_service_date between v_date_start and v_date_end)dates), shaped as (
    select item.value original,po.purchase_order_id,po.purchase_order_status,
      po.replaces_purchase_order_id,por.purchase_order_revision_id,
      coalesce((select value->>'ready'='true'from date_states where service_date=po.school_catering_service_date),false) official_ready,
      atlas_core.school_catering_po_commitment_state(
        po.purchase_order_id,por.purchase_order_revision_id,continuity_map) commitment_state,
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
            child.purchase_order_id,child_revision.purchase_order_revision_id,continuity_map)
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
        when 'REPLACEMENT_REQUIRED' then jsonb_build_array(case when s.official_ready then 'PO_REPLACEMENT_REQUIRED'else 'PO_SOURCE_NOT_READY'end)
        when 'CANCELLATION_REQUIRED' then jsonb_build_array('CANCELLATION_REQUIRED')
        else s.original -> 'blockers' end,
      'allowed_actions',(s.original -> 'allowed_actions') || jsonb_build_object(
        'release',s.commitment_state='DRAFT_CURRENT',
        'export',s.purchase_order_status in ('RELEASED_TO_SUPPLIER','SUPERSEDED'),
        'create_replacement',s.commitment_state='REPLACEMENT_REQUIRED' and s.official_ready
          and (s.replaced_by_purchase_order_id is null
            or s.replacement_draft_stale)),
      'disabled_reasons',case s.commitment_state
        when 'REPLACEMENT_REQUIRED' then jsonb_build_array(case when s.official_ready then 'PO_REPLACEMENT_REQUIRED'else 'PO_SOURCE_NOT_READY'end)
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
    where not atlas_core.school_catering_procurement_date_current(scoped.service_date,continuity_map)
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
$function$;

reset role;
set role atlas_owner;

reset role;
set role atlas_procurement_command_runtime;

-- SOURCE-ONLY two existing definitions, identity-bound groups and original filters.
-- Issue 395: one phase-local relational membership assembly. No proof survives
-- this STABLE statement; all historical predicates and raw multiplicity remain.

CREATE OR REPLACE FUNCTION atlas_core.purchase_review_continuity_context(p_batch uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 with root as materialized(select atlas_core.purchase_review_correction_context(p_batch) facts),
 handoff_revisions as materialized (
  select hr.*,hb.confirmed_need_batch_id,hb.handoff_status,
   to_jsonb(hr)||jsonb_build_object('confirmed_need_batch_id',hb.confirmed_need_batch_id,
    'handoff_status',hb.handoff_status) metadata,
   row_number()over(order by hr.purchase_handoff_batch_id,hr.revision_number)::text member_group_key
  from root
  join atlas_planning.purchase_handoff_batches hb
   on facts->'batch_ids' @>jsonb_build_array(hb.confirmed_need_batch_id)
  join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
 ), bindings as materialized (
  select hr.purchase_handoff_revision_id,
   lr.purchase_handoff_line_revision_id,lr.confirmed_need_line_revision_id,
   lr.ingredient_id,lr.unit_id,lr.handoff_quantity,lr.service_date,lr.delivery_location_id,
   hl.confirmed_need_line_id,hr.confirmed_need_batch_id,
   hr.released_at,hr.released_by_actor_id,hr.revision_status,
   sl.confirmed_need_snapshot_line_id,sl.approved_quantity,
   s.confirmed_need_validation_attempt_id,s.confirmed_need_approval_snapshot_id
  from handoff_revisions hr
  join atlas_planning.purchase_handoff_line_revisions lr using(purchase_handoff_revision_id)
  left join atlas_planning.purchase_handoff_lines hl
   on hl.purchase_handoff_line_id=lr.purchase_handoff_line_id
   and hl.purchase_handoff_batch_id=hr.purchase_handoff_batch_id
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
   and s.confirmed_need_batch_id=hr.confirmed_need_batch_id and s.source_kind='NEED_GENERATION'
 ), pairs as materialized (
  select distinct confirmed_need_batch_id,confirmed_need_validation_attempt_id from bindings
  where confirmed_need_batch_id is not null and confirmed_need_validation_attempt_id is not null
 ), evidence as materialized (
  select p.*,atlas_core.confirmed_need_historical_validation_evidence(
   p.confirmed_need_batch_id,p.confirmed_need_validation_attempt_id) facts from pairs p
 ), expanded_facts as materialized (
  select e.confirmed_need_batch_id,e.confirmed_need_validation_attempt_id,f.value fact,
   f.value->>'confirmed_need_line_id' line_id,
   f.value->>'current_confirmed_need_line_revision_id' revision_id
  from evidence e
  cross join lateral jsonb_array_elements(coalesce(e.facts#>'{projection,ordered_lines}','[]'))f(value)
 ), evidence_metadata as materialized (
  select e.confirmed_need_batch_id,e.confirmed_need_validation_attempt_id,
   e.facts->>'complete'='true' evidence_complete,
   e.facts->'released_snapshot_ids' released_snapshot_ids
  from evidence e
 ), members as materialized (
  select b.*,e.evidence_complete,
   coalesce(e.released_snapshot_ids @> jsonb_build_array(b.confirmed_need_approval_snapshot_id),false) prior_release,
   f.fact
  from bindings b left join evidence_metadata e
   on e.confirmed_need_batch_id=b.confirmed_need_batch_id
   and e.confirmed_need_validation_attempt_id=b.confirmed_need_validation_attempt_id
  left join expanded_facts f
   on f.confirmed_need_batch_id=b.confirmed_need_batch_id
   and f.confirmed_need_validation_attempt_id=b.confirmed_need_validation_attempt_id
   and f.line_id=b.confirmed_need_line_id::text
   and f.revision_id=b.confirmed_need_line_revision_id::text
 ), member_results as materialized (
  select purchase_handoff_revision_id,
   count(*)>0 and count(*)=count(distinct purchase_handoff_line_revision_id)
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
    'purchase_handoff_revision_id',purchase_handoff_revision_id,'source_confirmed_need_batch_id',confirmed_need_batch_id,
    'confirmed_need_snapshot_line_id',confirmed_need_snapshot_line_id,
    'validation_attempt_id',confirmed_need_validation_attempt_id)
    order by purchase_handoff_line_revision_id),'[]') facts
  from members group by purchase_handoff_revision_id
 ), handoff_evidence as materialized (
  select hr.metadata,hr.member_group_key,
   jsonb_build_object('complete',coalesce(m.complete,false),
    'members',case when m.complete then m.facts else '[]'::jsonb end) membership
  from handoff_revisions hr left join member_results m using(purchase_handoff_revision_id)
 ), raw_member_groups as materialized (
  select h.metadata->>'purchase_handoff_revision_id' handoff_revision_key,h.member_group_key,
   jsonb_build_array(m.member->>'service_date',m.member->>'delivery_location_id',
    m.member->>'ingredient_id',m.member->>'controlled_unit_id')::text family_key,
   jsonb_agg(m.member order by m.ordinality) members
  from handoff_evidence h
  cross join lateral jsonb_array_elements(h.membership->'members')with ordinality m(member,ordinality)
  group by h.metadata->>'purchase_handoff_revision_id',h.member_group_key,jsonb_build_array(m.member->>'service_date',m.member->>'delivery_location_id',
   m.member->>'ingredient_id',m.member->>'controlled_unit_id')::text
 ), per_handoff_groups as materialized (
  select handoff_revision_key,member_group_key,jsonb_object_agg(family_key,members) families
  from raw_member_groups group by handoff_revision_key,member_group_key
 ), per_revision_groups as materialized (
  select handoff_revision_key,jsonb_object_agg(member_group_key,families) ordinals
  from per_handoff_groups group by handoff_revision_key
 )
 select facts||jsonb_build_object('handoffs',coalesce((
  select jsonb_agg(metadata||jsonb_build_object('member_group_key',member_group_key,
   'membership',membership-'members')order by member_group_key::bigint)
  from handoff_evidence),'[]'::jsonb),'handoff_members',coalesce((
  select jsonb_object_agg(handoff_revision_key,ordinals)from per_revision_groups),'{}'::jsonb))
 from root;
$function$;

CREATE OR REPLACE FUNCTION atlas_core.purchase_review_family_continuity(p_family_revision uuid, p_mode text, p_context jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
   from jsonb_array_elements(p_context#>array['handoff_members',handoff->>'purchase_handoff_revision_id',handoff->>'member_group_key',jsonb_build_array(family.service_date::text,family.delivery_location_id::text,
     family.ingredient_id::text,family.unit_id::text)::text])m
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
  cross join lateral jsonb_array_elements(p_context#>array['handoff_members',h->>'purchase_handoff_revision_id',h->>'member_group_key',jsonb_build_array(family.service_date::text,family.delivery_location_id::text,
     family.ingredient_id::text,family.unit_id::text)::text])m
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
    from jsonb_array_elements(p_context#>array['handoff_members',edge->>'purchase_handoff_revision_id',edge->>'member_group_key',jsonb_build_array(family.service_date::text,family.delivery_location_id::text,
     family.ingredient_id::text,family.unit_id::text)::text])m
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
$function$;

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
