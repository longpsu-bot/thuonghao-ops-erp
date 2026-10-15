-- Operator C Task2: private immutable evidence and early locking only.
-- No public correction API, backfill, released-status downgrade or new authority.
begin;
create temporary table c_task2_role_before on commit drop as
select roleid,admin_option,inherit_option,set_option from pg_auth_members
where member='postgres'::regrole and grantor='postgres'::regrole
 and roleid='atlas_confirmed_need_review_runtime'::regrole;
create temporary table c_task2_schema_before on commit drop as
select schema_name,has_schema_privilege('atlas_confirmed_need_review_runtime',schema_name,'CREATE') had_create
from unnest(array['atlas_core','atlas_planning'])schema_name;
grant select on c_task2_schema_before to atlas_owner;
grant atlas_confirmed_need_review_runtime to postgres with set true;
set role atlas_owner;
do $authoring_create$
declare access record;
begin
 for access in select * from pg_temp.c_task2_schema_before where not had_create loop
  execute format('grant create on schema %I to atlas_confirmed_need_review_runtime',access.schema_name);
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
declare complete boolean; projection jsonb;
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
 return jsonb_build_object('complete',true,'confirmed_need_batch_id',p_batch,
  'validation_attempt_id',p_attempt,'projection',projection);
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
do $restore_schema$
declare access record;
begin
 for access in select * from pg_temp.c_task2_schema_before loop
  if not access.had_create then
   execute format('revoke create on schema %I from atlas_confirmed_need_review_runtime',access.schema_name);
  end if;
 end loop;
end;$restore_schema$;
reset role;
do $restore_role$
declare access record;
begin
 select * into access from pg_temp.c_task2_role_before;
 if not found then
  revoke atlas_confirmed_need_review_runtime from postgres granted by postgres;
 else
  execute format('grant atlas_confirmed_need_review_runtime to postgres with admin %s, inherit %s, set %s',
   case when access.admin_option then 'true' else 'false' end,
   case when access.inherit_option then 'true' else 'false' end,
   case when access.set_option then 'true' else 'false' end);
 end if;
end;
$restore_role$;
commit;
