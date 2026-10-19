-- Owner #400 K2: authoritative relational sources, never receipt certificates.
begin;

-- Restore the exact pre-existing authoring posture at transaction end.
create temporary table k2_membership_lease on commit drop as
select roleid,member,grantor,admin_option,inherit_option,set_option from pg_auth_members;
grant atlas_owner,atlas_confirmed_need_review_runtime,atlas_planning_command_runtime,
  atlas_procurement_command_runtime,atlas_read_runtime to postgres with set true;
set local role atlas_owner;
create temporary table k2_schema_lease on commit drop as
select n.nspname,r.rolname,has_schema_privilege(r.rolname,n.oid,'CREATE') had_create
from pg_namespace n cross join pg_roles r
where n.nspname in ('atlas_core','atlas_api') and r.rolname in (
  'atlas_confirmed_need_review_runtime','atlas_planning_command_runtime',
  'atlas_procurement_command_runtime','atlas_read_runtime');
grant create on schema atlas_core,atlas_api to atlas_confirmed_need_review_runtime,
  atlas_planning_command_runtime,atlas_procurement_command_runtime,atlas_read_runtime;
grant select on atlas_planning.purchase_handoff_line_revisions,
  atlas_planning.purchase_demand_references to atlas_confirmed_need_review_runtime;
create policy k2_corrected_source_handoff_read on atlas_planning.purchase_handoff_line_revisions
  for select to atlas_confirmed_need_review_runtime using(true);
create policy k2_corrected_source_demand_read on atlas_planning.purchase_demand_references
  for select to atlas_confirmed_need_review_runtime using(true);
-- Only key-column locking is granted. Forced RLS rejects every actual UPDATE.
grant update(actor_id) on atlas_core.actors to atlas_procurement_command_runtime;
grant update(actor_auth_subject_id) on atlas_core.actor_auth_subjects to atlas_procurement_command_runtime;
grant update(role_id) on atlas_core.roles,atlas_core.role_capabilities to atlas_procurement_command_runtime;
grant update(capability_id) on atlas_core.capabilities to atlas_procurement_command_runtime;
grant update(actor_role_membership_id) on atlas_core.actor_role_memberships to atlas_procurement_command_runtime;
grant update(actor_scope_id) on atlas_core.actor_scopes to atlas_procurement_command_runtime;
create policy k2_actor_lock on atlas_core.actors for update to atlas_procurement_command_runtime using(true) with check(false);
create policy k2_subject_lock on atlas_core.actor_auth_subjects for update to atlas_procurement_command_runtime using(true) with check(false);
create policy k2_role_lock on atlas_core.roles for update to atlas_procurement_command_runtime using(true) with check(false);
create policy k2_capability_lock on atlas_core.capabilities for update to atlas_procurement_command_runtime using(true) with check(false);
create policy k2_role_capability_lock on atlas_core.role_capabilities for update to atlas_procurement_command_runtime using(true) with check(false);
create policy k2_membership_lock on atlas_core.actor_role_memberships for update to atlas_procurement_command_runtime using(true) with check(false);
create policy k2_scope_lock on atlas_core.actor_scopes for update to atlas_procurement_command_runtime using(true) with check(false);
reset role;
set local role atlas_procurement_command_runtime;
-- Stateless lock support, with no public execution or stored authority.
create function atlas_core.school_catering_lock_po_release_actor(p_actor uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
begin
  perform actor_id from atlas_core.actors where actor_id=p_actor for share;
  perform actor_auth_subject_id from atlas_core.actor_auth_subjects
    where actor_id=p_actor order by actor_auth_subject_id for share;
  perform role.role_id from atlas_core.roles role where exists(
    select 1 from atlas_core.actor_role_memberships membership
    where membership.actor_id=p_actor and membership.role_id=role.role_id)
    order by role.role_id for share;
  perform actor_role_membership_id from atlas_core.actor_role_memberships
    where actor_id=p_actor order by actor_role_membership_id for share;
  perform capability.role_id from atlas_core.role_capabilities capability where exists(
    select 1 from atlas_core.actor_role_memberships membership
    where membership.actor_id=p_actor and membership.role_id=capability.role_id)
    order by capability.role_id,capability.capability_id for share;
  perform capability.capability_id from atlas_core.capabilities capability where exists(
    select 1 from atlas_core.role_capabilities binding
    join atlas_core.actor_role_memberships membership using(role_id)
    where membership.actor_id=p_actor and binding.capability_id=capability.capability_id)
    order by capability.capability_id for share;
  perform actor_scope_id from atlas_core.actor_scopes
    where actor_id=p_actor order by actor_scope_id for share;
end;
$$;
revoke all on function atlas_core.school_catering_lock_po_release_actor(uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.school_catering_lock_po_release_actor(uuid)
  to atlas_procurement_command_runtime;
reset role;
set local role atlas_confirmed_need_review_runtime;

-- Extend the existing exact-family projection with a closed post-release proof.
-- Unchanged families keep their original Handoff contribution identities.
create or replace function atlas_core.purchase_review_confirmed_projection(
  p_date date,p_location uuid,p_ingredient uuid,p_unit uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  sources jsonb; p jsonb; b atlas_planning.confirmed_need_batches%rowtype;
  original record; h record; facts jsonb; original_facts jsonb; preflight jsonb;
  current_fact jsonb; original_fact jsonb; changed boolean:=false;
  unavailable jsonb:=jsonb_build_object('complete',false,
    'post_release_correction',true,'corrected_source_eligible',false,
    'blocker','CORRECTED_SOURCE_INVALID');
begin
  select coalesce(jsonb_agg(value),'[]'::jsonb) into sources
  from atlas_core.purchase_review_confirmed_sources(p_date,p_date) source(value)
  where value->>'delivery_location_id'=p_location::text
    and value->>'ingredient_id'=p_ingredient::text and value->>'unit_id'=p_unit::text;
  if jsonb_array_length(sources)<>1 then
    return jsonb_build_object('complete',false,
      'post_release_correction',exists(select 1 from atlas_planning.confirmed_need_batches batch
        join atlas_planning.confirmed_need_lines line using(confirmed_need_batch_id)
        where batch.batch_status='REOPENED' and batch.released_at is not null
          and line.service_date=p_date and line.delivery_location_id=p_location
          and line.ingredient_id=p_ingredient and line.controlled_unit_id=p_unit),
      'blocker','CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING');
  end if;
  p:=sources->0;
  select * into strict b from atlas_planning.confirmed_need_batches
  where confirmed_need_batch_id=(p->>'source_confirmed_need_batch_id')::uuid;
  if b.batch_status<>'REOPENED' or b.released_at is null then return p; end if;
  p:=p||jsonb_build_object('post_release_correction',true,'corrected_source_eligible',false);
  if p->>'complete' is distinct from 'true' or b.period_start<>p_date
    or b.period_end<>p_date then return p||unavailable; end if;

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
  if original.confirmed_need_release_id is null then return p||unavailable; end if;
  select batch.purchase_handoff_batch_id,revision.purchase_handoff_revision_id into h
  from atlas_planning.purchase_handoff_batches batch
  join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
  where batch.confirmed_need_batch_id=b.confirmed_need_batch_id
    and batch.handoff_status='RELEASED_TO_PROCUREMENT' and revision.is_current
    and revision.revision_status='RELEASED_TO_PROCUREMENT';
  if not found or (select count(*) from atlas_planning.purchase_handoff_batches batch
    join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
    where batch.confirmed_need_batch_id=b.confirmed_need_batch_id and revision.is_current)<>1
    then return p||unavailable; end if;

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
      is distinct from true then return p||unavailable; end if;

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
    then return p||unavailable; end if;

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
      then return p||unavailable; end if;
    if current_fact->>'current_confirmed_need_line_revision_id'=
        original_fact->>'current_confirmed_need_line_revision_id' then
      if current_fact->>'current_confirmed_need_line_decision_id' is distinct from
          original_fact->>'current_confirmed_need_line_decision_id'
        then return p||unavailable; end if;
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
        then return p||unavailable; end if;
      if current_fact->>'delivery_location_id'=p_location::text
        and current_fact->>'ingredient_id'=p_ingredient::text
        and current_fact->>'controlled_unit_id'=p_unit::text then changed:=true; end if;
    end if;
  end loop;
  return p||jsonb_build_object('corrected_source_eligible',true,
    'corrected_family',changed,'original_release_id',original.confirmed_need_release_id,
    'original_purchase_handoff_revision_id',h.purchase_handoff_revision_id);
end;
$$;


-- Immutable Planning ancestry; no current flags, permission snapshots or receipt authority.
create function atlas_core.school_catering_corrected_allocation_ancestry(p_source jsonb)
returns boolean language sql stable security definer set search_path='' as $$
  select not exists(
    select 1 from jsonb_to_recordset(p_source->'contributions') c(
      confirmed_need_line_revision_id uuid,confirmed_need_line_decision_id uuid,contribution_quantity numeric)
    left join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_revision_id)
    left join atlas_planning.confirmed_need_line_decisions decision using(confirmed_need_line_decision_id)
    where revision.confirmed_need_line_revision_id is null or decision.confirmed_need_line_decision_id is null
      or not atlas_core.planning_contract_02b_decision_authorizes_revision(
        c.confirmed_need_line_decision_id,revision.confirmed_need_line_id,c.confirmed_need_line_revision_id)
      or decision.confirmed_need_line_id is distinct from revision.confirmed_need_line_id
      or decision.confirmed_need_batch_id is distinct from (p_source->>'source_batch_id')::uuid
      or revision.confirmed_need_batch_id is distinct from (p_source->>'source_batch_id')::uuid
      or revision.source_kind<>'NEED_GENERATION' or decision.source_kind<>'NEED_GENERATION'
      or revision.service_date is distinct from (p_source->>'service_date')::date
      or revision.delivery_location_id is distinct from (p_source->>'delivery_location_id')::uuid
      or revision.ingredient_id is distinct from (p_source->>'ingredient_id')::uuid
      or revision.unit_id is distinct from (p_source->>'unit_id')::uuid
      or c.contribution_quantity is distinct from revision.confirmed_quantity
      or c.contribution_quantity is distinct from decision.confirmed_quantity_after
  ) and exists(
           select 1 from atlas_planning.confirmed_need_releases released
           join atlas_planning.confirmed_need_approval_snapshots snapshot
             on snapshot.confirmed_need_approval_snapshot_id=released.confirmed_need_approval_snapshot_id
           join atlas_planning.confirmed_need_validation_attempts attempt
             on attempt.confirmed_need_validation_attempt_id=snapshot.confirmed_need_validation_attempt_id
             and attempt.outcome='VALIDATED' and attempt.blocking_issue_count=0
           where released.confirmed_need_batch_id=(p_source->>'source_batch_id')::uuid
             and released.source_kind='NEED_GENERATION'
             and released.resulting_released_batch_version<(p_source->>'source_version')::bigint
             and exists(select 1 from jsonb_to_recordset(p_source->'contributions') c(confirmed_need_line_revision_id uuid,confirmed_need_line_decision_id uuid,contribution_quantity numeric)
               join atlas_planning.confirmed_need_line_decisions decision using(confirmed_need_line_decision_id)
               where true
                 and decision.confirmed_need_batch_version>released.resulting_released_batch_version
                 and decision.decision_kind='ADJUSTED_QUANTITY_CONFIRMED')
             and not exists((select member.confirmed_need_line_id
               from jsonb_to_recordset(p_source->'contributions') c(confirmed_need_line_revision_id uuid,confirmed_need_line_decision_id uuid,contribution_quantity numeric)
               join atlas_planning.confirmed_need_line_revisions member using(confirmed_need_line_revision_id)
               where true
               except select member.confirmed_need_line_id
               from atlas_planning.confirmed_need_snapshot_lines original
               join atlas_planning.confirmed_need_line_revisions member using(confirmed_need_line_revision_id)
               where original.confirmed_need_approval_snapshot_id=released.confirmed_need_approval_snapshot_id
                 and member.service_date=(p_source->>'service_date')::date and member.delivery_location_id=(p_source->>'delivery_location_id')::uuid
                 and member.ingredient_id=(p_source->>'ingredient_id')::uuid and member.unit_id=(p_source->>'unit_id')::uuid)
               union all (select member.confirmed_need_line_id
               from atlas_planning.confirmed_need_snapshot_lines original
               join atlas_planning.confirmed_need_line_revisions member using(confirmed_need_line_revision_id)
               where original.confirmed_need_approval_snapshot_id=released.confirmed_need_approval_snapshot_id
                 and member.service_date=(p_source->>'service_date')::date and member.delivery_location_id=(p_source->>'delivery_location_id')::uuid
                 and member.ingredient_id=(p_source->>'ingredient_id')::uuid and member.unit_id=(p_source->>'unit_id')::uuid
               except select member.confirmed_need_line_id
               from jsonb_to_recordset(p_source->'contributions') c(confirmed_need_line_revision_id uuid,confirmed_need_line_decision_id uuid,contribution_quantity numeric)
               join atlas_planning.confirmed_need_line_revisions member using(confirmed_need_line_revision_id)
               where true))
             and not exists(select 1 from jsonb_to_recordset(p_source->'contributions') c(confirmed_need_line_revision_id uuid,confirmed_need_line_decision_id uuid,contribution_quantity numeric)
               join atlas_planning.confirmed_need_line_decisions decision using(confirmed_need_line_decision_id)
               where true and (
                 decision.confirmed_need_batch_version>(p_source->>'source_version')::bigint
                 or exists(select 1 from atlas_planning.confirmed_need_line_decisions later
                   where later.confirmed_need_line_id=decision.confirmed_need_line_id
                     and later.decision_number>decision.decision_number
                     and later.confirmed_need_batch_version<=(p_source->>'source_version')::bigint)
                 or not exists(select 1 from atlas_planning.confirmed_need_validation_lines observation
                   join atlas_planning.confirmed_need_line_decisions ancestor
                     on ancestor.confirmed_need_line_decision_id=observation.current_confirmed_need_line_decision_id
                   join atlas_planning.confirmed_need_snapshot_lines original
                     on original.confirmed_need_approval_snapshot_id=released.confirmed_need_approval_snapshot_id
                     and original.confirmed_need_line_revision_id=observation.current_confirmed_need_line_revision_id
                   join atlas_planning.purchase_demand_references demand using(confirmed_need_snapshot_line_id)
                   join atlas_planning.purchase_handoff_line_revisions handoff using(purchase_handoff_line_revision_id)
                   join atlas_planning.purchase_handoff_revisions handoff_revision using(purchase_handoff_revision_id)
                   where observation.confirmed_need_validation_attempt_id=attempt.confirmed_need_validation_attempt_id
                     and observation.confirmed_need_line_id=decision.confirmed_need_line_id
                     and ancestor.decision_number<=decision.decision_number
                     and decision.unit_id=ancestor.unit_id
                     and decision.planning_quantity_policy_revision_id=ancestor.planning_quantity_policy_revision_id
                     and decision.theoretical_quantity_before=ancestor.theoretical_quantity_before
                     and not exists((select to_jsonb(member)-array[
                       'confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                       from atlas_planning.confirmed_need_line_revision_contributions member
                       where member.confirmed_need_line_revision_id=c.confirmed_need_line_revision_id
                       except select to_jsonb(member)-array[
                       'confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                       from atlas_planning.confirmed_need_line_revision_contributions member
                       where member.confirmed_need_line_revision_id=original.confirmed_need_line_revision_id)
                       union all (select to_jsonb(member)-array[
                       'confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                       from atlas_planning.confirmed_need_line_revision_contributions member
                       where member.confirmed_need_line_revision_id=original.confirmed_need_line_revision_id
                       except select to_jsonb(member)-array[
                       'confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                       from atlas_planning.confirmed_need_line_revision_contributions member
                       where member.confirmed_need_line_revision_id=c.confirmed_need_line_revision_id))
                     and original.approved_quantity=ancestor.confirmed_quantity_after
                     and demand.source_kind='NEED_GENERATION' and demand.approved_quantity=original.approved_quantity
                     and demand.unit_id=original.unit_id
                     and handoff.confirmed_need_line_revision_id=original.confirmed_need_line_revision_id
                     and handoff.handoff_quantity=original.approved_quantity and handoff.unit_id=original.unit_id
                     and handoff_revision.released_at is not null
                     and not exists(select 1 from atlas_planning.confirmed_need_line_decisions successor
                       where successor.confirmed_need_line_id=decision.confirmed_need_line_id
                         and successor.decision_number>ancestor.decision_number
                         and successor.decision_number<=decision.decision_number
                         and (successor.decision_kind<>'ADJUSTED_QUANTITY_CONFIRMED'
                           or successor.confirmed_need_batch_version<=released.resulting_released_batch_version
                           or successor.confirmed_need_batch_version>(p_source->>'source_version')::bigint)))))

  );
$$;
revoke all on function atlas_core.school_catering_corrected_allocation_ancestry(jsonb)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.school_catering_corrected_allocation_ancestry(jsonb)
  to atlas_procurement_command_runtime;

-- Lock the same roots as K1 before re-reading live source evidence.
create or replace function atlas_core.purchase_review_lock_confirmed_source(p_batch uuid)
returns void language plpgsql volatile security definer set search_path='' as $$
declare corrected boolean; preflight jsonb;
begin
  select batch_status='REOPENED' and released_at is not null into corrected
  from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch;
  if corrected then
    perform run.need_generation_run_id from atlas_planning.need_generation_runs run
    join atlas_planning.confirmed_need_batches batch
      on batch.current_need_generation_run_id=run.need_generation_run_id
    where batch.confirmed_need_batch_id=p_batch order by run.need_generation_run_id for share of run;
    perform 1 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch for update;
    select atlas_core.planning_contract_01_preflight_payload(period_start,period_end,null)
      into preflight from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch;
    perform weekly_menu_id from atlas_planning.weekly_menus
      where weekly_menu_id=atlas_core.pa_05b_safe_uuid(preflight#>>'{current_need,weekly_menu_id}') for share;
    perform attendance_batch_id from atlas_planning.attendance_batches
      where attendance_batch_id=atlas_core.pa_05b_safe_uuid(preflight#>>'{current_need,attendance_batch_id}') for share;
    perform pantry_need_batch_id from atlas_planning.pantry_need_batches
      where pantry_need_batch_id=atlas_core.pa_05b_safe_uuid(preflight#>>'{current_need,pantry_need_batch_id}') for share;
  else
    perform 1 from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=p_batch for update;
  end if;
  perform 1 from atlas_planning.confirmed_need_lines where confirmed_need_batch_id=p_batch
    order by confirmed_need_line_id for key share;
  perform 1 from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=p_batch and is_current
    order by confirmed_need_line_revision_id for key share;
  if corrected then
    perform policy.planning_quantity_policy_id from atlas_planning.planning_quantity_policies policy
    where policy.unit_id in(select controlled_unit_id from atlas_planning.confirmed_need_lines
      where confirmed_need_batch_id=p_batch) order by policy.planning_quantity_policy_id for share;
    perform revision.planning_quantity_policy_revision_id from atlas_planning.planning_quantity_policy_revisions revision
    where revision.unit_id in(select controlled_unit_id from atlas_planning.confirmed_need_lines
      where confirmed_need_batch_id=p_batch) order by revision.planning_quantity_policy_revision_id for share;
    perform unit.unit_id from atlas_admin.units unit
    where unit.unit_id in(select controlled_unit_id from atlas_planning.confirmed_need_lines
      where confirmed_need_batch_id=p_batch) order by unit.unit_id for share;
  end if;
end;
$$;

reset role;
set local role atlas_owner;

-- Keep the original Handoff selector verbatim for ordinary families.
do $selector$
declare d text:=pg_get_functiondef('atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)'::regprocedure);
  body text;
begin
  select prosrc into body from pg_proc
  where oid='atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)'::regprocedure;
  if position('with contributions as' in body)=0 then raise exception 'K2 family selector changed'; end if;
  execute 'create or replace function atlas_core.school_catering_family_projection('
    ||'p_service_date date,p_delivery_location_id uuid,p_ingredient_id uuid,p_unit_id uuid) '
    ||'returns jsonb language plpgsql stable security invoker set search_path='''''
    ||' as $body$ declare p jsonb; answer jsonb; begin '
    ||$candidate$if exists(select 1 from atlas_planning.confirmed_need_batches batch
      join atlas_planning.confirmed_need_lines line using(confirmed_need_batch_id)
      where batch.batch_status='REOPENED' and batch.released_at is not null
        and line.service_date=p_service_date and line.delivery_location_id=p_delivery_location_id
        and line.ingredient_id=p_ingredient_id and line.controlled_unit_id=p_unit_id) then
      p:=atlas_core.purchase_review_confirmed_projection(p_service_date,p_delivery_location_id,p_ingredient_id,p_unit_id);
      $candidate$
    ||'if p->>''post_release_correction''=''true'' then '
    ||'if p->>''corrected_source_eligible'' is distinct from ''true'' then '
    ||'return p||jsonb_build_object(''family_quantity'',null,''source_fingerprint'',null); end if; '
    ||$checks$if p->>'corrected_family'='true' then
      if exists(select 1 from atlas_procurement.school_catering_allocation_families f
        join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
        where f.service_date=p_service_date and f.delivery_location_id=p_delivery_location_id
          and f.ingredient_id=p_ingredient_id and f.unit_id=p_unit_id and r.is_current
          and r.source_kind='CONFIRMED_NEED' and (
            r.source_confirmed_need_batch_id::text is distinct from p->>'source_confirmed_need_batch_id'
            or r.source_confirmed_need_batch_version>(p->>'source_confirmed_need_batch_version')::bigint
            or exists((select c.confirmed_need_line_revision_id,c.confirmed_need_line_decision_id,
                c.contribution_quantity from atlas_procurement.school_catering_allocation_family_contributions c
                where c.family_revision_id=r.family_revision_id
              except select (c->>'confirmed_need_line_revision_id')::uuid,
                (c->>'confirmed_need_line_decision_id')::uuid,(c->>'contribution_quantity')::numeric
                from jsonb_array_elements(p->'contributions') c)
              union all (select (c->>'confirmed_need_line_revision_id')::uuid,
                (c->>'confirmed_need_line_decision_id')::uuid,(c->>'contribution_quantity')::numeric
                from jsonb_array_elements(p->'contributions') c
              except select c.confirmed_need_line_revision_id,c.confirmed_need_line_decision_id,
                c.contribution_quantity from atlas_procurement.school_catering_allocation_family_contributions c
                where c.family_revision_id=r.family_revision_id)))) then
        return p||jsonb_build_object('family_quantity',null,'source_fingerprint',null);
      end if;
      return p; end if; end if; end if; $checks$
    ||'select result.value into answer from ('||rtrim(body,E' \r\n;')||') result(value); '
    ||'return answer; end $body$';
end $selector$;

-- KEY SHARE permits non-key Supplier status changes; SHARE serializes them.
reset role;
do $supplier_locks$
declare d text:=pg_get_functiondef('atlas_core.school_catering_lock_supplier_evidence(date,uuid,jsonb,boolean)'::regprocedure);
begin
  if position('order by supplier.supplier_id for key share' in d)=0 then
    raise exception 'K2 Supplier lock anchor changed'; end if;
  execute replace(d,'order by supplier.supplier_id for key share','order by supplier.supplier_id for share');
end $supplier_locks$;

-- Every official consumer still compares exact canonical fingerprints and
-- split identities. Initial CONFIRMED_NEED never matches the Handoff selector.
reset role;
do $consumers$
declare target text; d text;
begin
  foreach target in array array[
    'atlas_core.school_catering_po_date_readiness(date)',
    'atlas_core.school_catering_po_draft_is_stale(uuid,uuid)',
    'atlas_api.create_school_catering_purchase_order_drafts(jsonb)',
    'atlas_api.release_school_catering_purchase_order(jsonb)',
    'atlas_core.purchase_review_po_coverage(date)',
    'atlas_core.purchase_review_preparation_po_frontier(date)'] loop
    d:=pg_get_functiondef(target::regprocedure);
    if position('''PURCHASE_HANDOFF''' in d)=0 then raise exception 'K2 consumer source anchor changed: %',target; end if;
    d:=replace(d,'r.source_kind=''PURCHASE_HANDOFF''','r.source_kind in (''PURCHASE_HANDOFF'',''CONFIRMED_NEED'')');
    d:=replace(d,'r.source_kind<>''PURCHASE_HANDOFF''','r.source_kind not in (''PURCHASE_HANDOFF'',''CONFIRMED_NEED'')');
    execute d;
  end loop;
end $consumers$;

-- Preparation preserves the original released Planning/Handoff. It does not
-- materialize defaults or accept any stale split on the closed correction path.
set local role atlas_confirmed_need_review_runtime;
do $preparation$
declare d text:=pg_get_functiondef('atlas_api.prepare_school_catering_purchase_orders(jsonb)'::regprocedure);
  old text:='    if v_batch.batch_status in (''DRAFT_REVIEW'',''REOPENED'') then';
begin
  if position(old in d)=0 then raise exception 'K2 Preparation source anchor changed'; end if;
  d:=replace(d,'  select * into v_batch from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_batch_id for update;',
    $new$  if exists(select 1 from atlas_planning.confirmed_need_batches batch
    where batch.confirmed_need_batch_id=v_batch_id and batch.batch_status='REOPENED'
      and batch.released_at is not null) then
    perform atlas_core.purchase_review_lock_confirmed_source(v_batch_id);
  end if;
  select * into v_batch from atlas_planning.confirmed_need_batches where confirmed_need_batch_id=v_batch_id for update;$new$);
  d:=replace(d,old,$new$    if v_batch.batch_status='REOPENED' and v_batch.released_at is not null then
      perform atlas_core.purchase_review_lock_allocations(v_batch_id);
      if not exists(select 1 from atlas_core.purchase_review_confirmed_batch_sources(v_batch_id))
        or exists(select 1 from atlas_core.purchase_review_confirmed_batch_sources(v_batch_id) source
          where atlas_core.purchase_review_confirmed_projection(
            (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
            (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid)
            ->>'corrected_source_eligible' is distinct from 'true') then
        v_error:=atlas_core.pa_05b_command_error(request,'CORRECTED_SOURCE_INVALID',
          'The corrected Need source is not current and authentic.','PROCUREMENT',v_name);
        raise exception using errcode='PPR02';
      end if;
      v_release:=jsonb_build_object('success',true,'original_release_preserved',true);
    elsif v_batch.batch_status in ('DRAFT_REVIEW','REOPENED') then$new$);
  execute d;
end $preparation$;

-- Defensive historical shape remains immutable. Live currentness belongs to
-- Draft and explicit Release; a later Need decision must not invalidate history.
reset role;
set local role atlas_owner;
do $po_guard$
declare d text:=pg_get_functiondef('atlas_core.purchase_order_revision_integrity_guard()'::regprocedure);
  old text:=$old$  if exists(select 1 from atlas_procurement.purchase_order_line_revisions l
       join atlas_procurement.school_catering_allocation_supplier_splits s
         on s.supplier_split_id=l.school_catering_allocation_supplier_split_id
       join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
       where l.purchase_order_revision_id=v_revision_id and r.source_kind<>'PURCHASE_HANDOFF') then
       raise exception using errcode='23514',message='Official PO requires Purchase Handoff allocation authority.';
     end if;$old$;
begin
  if position(old in d)=0 then raise exception 'K2 official source guard anchor changed'; end if;
  d:=replace(d,'  v_revision_id uuid;','  v_revision_id uuid; k2_source jsonb; k2_allocation record;');
  d:=replace(d,old,$new$  for k2_allocation in
    select r.* from atlas_procurement.purchase_order_line_revisions l
    join atlas_procurement.school_catering_allocation_supplier_splits s
      on s.supplier_split_id=l.school_catering_allocation_supplier_split_id
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
    where l.purchase_order_revision_id=v_revision_id and r.source_kind<>'PURCHASE_HANDOFF'
  loop
    select to_jsonb(family)||jsonb_build_object(
      'source_batch_id',k2_allocation.source_confirmed_need_batch_id,
      'source_version',k2_allocation.source_confirmed_need_batch_version,
      'contributions',(select jsonb_agg(to_jsonb(c))
        from atlas_procurement.school_catering_allocation_family_contributions c
        where c.family_revision_id=k2_allocation.family_revision_id)) into k2_source
    from atlas_procurement.school_catering_allocation_families family
    where family.family_id=k2_allocation.family_id;
    if k2_allocation.source_kind<>'CONFIRMED_NEED'
      or atlas_core.school_catering_corrected_allocation_ancestry(k2_source) is distinct from true then
      raise exception using errcode='23514',message='Official PO requires Purchase Handoff allocation authority.';
    end if;
  end loop;$new$);
  execute d;
end $po_guard$;
-- Deferred checks may be flushed by a later Planning command in the same transaction.
reset role;
alter function atlas_core.purchase_order_revision_integrity_guard()
  owner to atlas_procurement_command_runtime;

-- Recheck the actual releaser after all source/PO waits. No Planning role is
-- required of this Actor; K1 already established the prior Planning decision.
reset role;
set local role atlas_procurement_command_runtime;
do $release$
declare d text:=pg_get_functiondef('atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure);
  old text:='  v_document_number := format(''PO-%s-%s'',';
begin
  if position(old in d)=0 then raise exception 'K2 final release anchor changed'; end if;
  d:=replace(d,'  perform pg_catalog.pg_advisory_xact_lock(',
    $new$  if exists(select 1 from atlas_planning.confirmed_need_batches batch
    where batch.period_start=v_root.school_catering_service_date
      and batch.period_end=v_root.school_catering_service_date
      and batch.batch_status='REOPENED' and batch.released_at is not null) then
    perform atlas_core.school_catering_lock_po_release_actor(v_actor_id);
    perform atlas_core.purchase_review_lock_confirmed_source(batch.confirmed_need_batch_id)
    from atlas_planning.confirmed_need_batches batch
    where batch.period_start=v_root.school_catering_service_date
      and batch.period_end=v_root.school_catering_service_date
      and batch.batch_status='REOPENED' and batch.released_at is not null
    order by batch.confirmed_need_batch_id;
    for v_row in select f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,
      jsonb_agg(jsonb_build_object('supplier_id',s.supplier_id,
        'allocated_quantity',s.allocated_quantity) order by s.supplier_id) splits
      from atlas_procurement.school_catering_allocation_families f
      join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
      join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
      where f.service_date=v_root.school_catering_service_date and r.is_current
      group by f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id
      order by f.ingredient_id,f.delivery_location_id,f.unit_id loop
      perform atlas_core.school_catering_lock_supplier_evidence(v_row.service_date,
        v_row.ingredient_id,v_row.splits,false);
    end loop;
  end if;
  perform pg_catalog.pg_advisory_xact_lock($new$);
  d:=replace(d,old,$new$  v_actor:=atlas_core.pa_05b_resolve_actor(request,'PROCUREMENT',v_name);
  if v_actor?'error' or (v_actor->>'actor_id')::uuid is distinct from v_actor_id then
    v_error:=coalesce(v_actor->'error',atlas_core.pa_05b_command_error(request,'ACTOR_NOT_AUTHORIZED',
      'The release Actor is no longer active.','PROCUREMENT',v_name));
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  v_auth:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if (v_auth is not null and v_auth->>'error_code'<>'SCOPE_DENIED')
    or not atlas_core.school_catering_purchase_order_actor_has_full_scope(v_actor_id,v_purchase_order_id) then
    v_error:=coalesce(v_auth,atlas_core.pa_05b_command_error(request,'SCOPE_DENIED',
      'The actor no longer covers the complete purchase order.','PROCUREMENT',v_name));
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  if exists(select 1 from atlas_planning.confirmed_need_batches batch
    where batch.period_start=v_root.school_catering_service_date
      and batch.period_end=v_root.school_catering_service_date
      and batch.batch_status='REOPENED' and batch.released_at is not null)
    and atlas_core.purchase_review_preparation_po_frontier(v_root.school_catering_service_date)
      ->>'acceptable' is distinct from 'true' then
    v_error:=atlas_core.pa_05b_command_error(request,'PREPARATION_BLOCKED',
      'Prepare the complete current Supplier/date document set before release.','PROCUREMENT',v_name);
    return atlas_core.pa_05b_finish_command(v_receipt,v_error,false);
  end if;
  v_document_number := format('PO-%s-%s',$new$);
  execute d;
end $release$;

do $replacement_lock_order$
declare d text:=pg_get_functiondef('atlas_api.create_school_catering_purchase_order_replacement(jsonb)'::regprocedure);
  old text:='  perform pg_catalog.pg_advisory_xact_lock(';
begin
  if position(old in d)=0 then raise exception 'K2 replacement lock anchor changed'; end if;
  execute replace(d,old,$new$  perform atlas_core.purchase_review_lock_confirmed_source(batch.confirmed_need_batch_id)
  from atlas_planning.confirmed_need_batches batch
  where batch.period_start=v_replaced.school_catering_service_date
    and batch.period_end=v_replaced.school_catering_service_date
    and batch.batch_status='REOPENED' and batch.released_at is not null
  order by batch.confirmed_need_batch_id;
  perform pg_catalog.pg_advisory_xact_lock($new$);
end $replacement_lock_order$;

do $draft_lock_order$
declare d text:=pg_get_functiondef('atlas_api.create_school_catering_purchase_order_drafts(jsonb)'::regprocedure);
  old text:='  -- Derive complete date readiness before the command receipt or any domain write.';
begin
  if position(old in d)=0 then raise exception 'K2 Draft source-lock anchor changed'; end if;
  execute replace(d,old,$new$  perform atlas_core.purchase_review_lock_confirmed_source(batch.confirmed_need_batch_id)
  from atlas_planning.confirmed_need_batches batch
  where batch.period_start between v_date_start and v_date_end
    and batch.period_end=batch.period_start
    and batch.batch_status='REOPENED' and batch.released_at is not null
  order by batch.confirmed_need_batch_id;
  -- Derive complete date readiness before the command receipt or any domain write.$new$);
end $draft_lock_order$;

reset role;
set local role atlas_read_runtime;
do $school_snapshot$
declare d text:=pg_get_functiondef('atlas_core.school_catering_po_school_breakdown(uuid)'::regprocedure);
  old text:='        handoff_line.confirmed_need_line_revision_id';
begin
  if position(old in d)=0 then raise exception 'K2 School snapshot source anchor changed'; end if;
  d:=replace(d,'    join atlas_planning.purchase_handoff_line_revisions handoff_line',
    '    left join atlas_planning.purchase_handoff_line_revisions handoff_line');
  d:=replace(d,old,'        coalesce(contribution.confirmed_need_line_revision_id,handoff_line.confirmed_need_line_revision_id)');
  execute d;
end $school_snapshot$;

reset role;
set local role atlas_owner;
do $restore_schemas$
declare lease record;
begin
  for lease in select * from k2_schema_lease where not had_create loop
    execute format('revoke create on schema %I from %I',lease.nspname,lease.rolname);
  end loop;
end $restore_schemas$;
reset role;
do $restore_memberships$
declare lease record;
begin
  for lease in select r.rolname,a.set_option from k2_membership_lease a
    join pg_roles r on r.oid=a.roleid
    where a.member=(select oid from pg_roles where rolname='postgres')
      and a.grantor=(select oid from pg_roles where rolname='postgres') loop
    execute format('grant %I to postgres with set %s',lease.rolname,
      case when lease.set_option then 'true' else 'false' end);
  end loop;
end $restore_memberships$;
commit;
