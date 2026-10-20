-- Owner #400 / 6277838544: advisory correction admission in the existing read.
-- No writer, privilege, ownership, lifecycle, lock or historical fact changes.
begin;
do $k3_read$
declare definition text;
begin
  definition:=pg_get_functiondef('atlas_core.d037_extend_workbench(jsonb,uuid)'::regprocedure);
  if position('''operationally_available'',false' in definition)=0
    or position('''PROCUREMENT_TRANSFER_NOT_IMPLEMENTED''' in definition)=0
    or position('correct_released_confirmed_needs' in definition)>0 then
    raise exception 'K3 unexpected pinned review baseline';
  end if;
  definition:=replace(definition,'  v_release_message text;',
$new$  v_release_message text;
  v_correction_code text:='CORRECTION_SOURCE_NOT_AVAILABLE';
  v_correction_message text;
  v_correction_capable boolean:=false;
  v_correction_facts_valid boolean:=false;
  v_corrected_chain boolean:=false;
  v_correction_handoff_present boolean:=false;
  v_original record;
  v_handoff record;
  v_preflight jsonb;
  v_facts jsonb;
  v_original_facts jsonb;
  v_current_fact jsonb;
  v_original_fact jsonb;$new$);
  definition:=replace(definition,
    '  p_workbench:=p_workbench||jsonb_build_object(''need_correction_authority'',',
$new$  -- The public read has already resolved the active JWT-bound human Actor.
  -- Keep this separate from v2 Save and from Procurement commitment permission.
  select exists(select 1 from atlas_core.actors actor
      where actor.actor_id=p_actor_id and actor.actor_status='ACTIVE' and actor.actor_type='HUMAN')
    and exists(select 1 from atlas_core.actor_scopes scope
      where scope.actor_id=p_actor_id and scope.scope_kind='GLOBAL' and scope.scope_status='ACTIVE'
        and scope.effective_from<=transaction_timestamp()
        and (scope.effective_to is null or scope.effective_to>transaction_timestamp()))
    and not exists(select 1 from unnest(array['confirmed_need_quantities.confirm',
      'planning.need_generation.write','confirmed_need_release.release']) required(code)
      where not exists(select 1 from atlas_core.actor_role_memberships membership
        join atlas_core.roles role_record using(role_id)
        join atlas_core.role_capabilities binding using(role_id)
        join atlas_core.capabilities capability using(capability_id)
        where membership.actor_id=p_actor_id and membership.membership_status='ACTIVE'
          and membership.effective_from<=transaction_timestamp()
          and (membership.effective_to is null or membership.effective_to>transaction_timestamp())
          and role_record.role_status='ACTIVE' and capability.capability_status='ACTIVE'
          and capability.capability_code=required.code)) into v_correction_capable;

  begin
    if v_batch.source_kind<>'NEED_GENERATION' then
      v_correction_code:='CORRECTION_UNSUPPORTED_SOURCE_KIND';
    elsif v_batch.batch_status in ('RELEASED_FOR_PURCHASE_HANDOFF','REOPENED') then
      -- Reuse K1's original release/evaluation and K2's immutable ancestry proof.
      select release.*,snapshot.confirmed_need_validation_attempt_id,
        snapshot.validated_fact_fingerprint into v_original
      from atlas_planning.confirmed_need_releases release
      join atlas_planning.confirmed_need_approval_snapshots snapshot
        on snapshot.confirmed_need_approval_snapshot_id=release.confirmed_need_approval_snapshot_id
          and snapshot.confirmed_need_batch_id=release.confirmed_need_batch_id
      join atlas_planning.confirmed_need_validation_attempts attempt
        on attempt.confirmed_need_validation_attempt_id=snapshot.confirmed_need_validation_attempt_id
          and attempt.confirmed_need_batch_id=release.confirmed_need_batch_id
          and attempt.outcome='VALIDATED' and attempt.blocking_issue_count=0
      where release.confirmed_need_batch_id=v_batch_id and release.source_kind='NEED_GENERATION'
        and release.resulting_released_batch_version=(select max(prior.resulting_released_batch_version)
          from atlas_planning.confirmed_need_releases prior where prior.confirmed_need_batch_id=v_batch_id);
      select h.purchase_handoff_batch_id,h.version,h.handoff_status,
        revision.purchase_handoff_revision_id,revision.revision_status into v_handoff
      from atlas_planning.purchase_handoff_batches h
      join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
      where h.confirmed_need_batch_id=v_batch_id and revision.is_current;
      v_correction_handoff_present:=v_handoff.purchase_handoff_batch_id is not null;
      if v_original.confirmed_need_release_id is null
        or (select count(*) from atlas_planning.confirmed_need_releases release
          where release.confirmed_need_batch_id=v_batch_id
            and release.resulting_released_batch_version=v_original.resulting_released_batch_version)<>1
        or (v_batch.batch_status='RELEASED_FOR_PURCHASE_HANDOFF'
          and v_batch.current_confirmed_need_release_id is distinct from v_original.confirmed_need_release_id)
        or (v_handoff.purchase_handoff_batch_id is not null and
          (v_handoff.handoff_status<>'RELEASED_TO_PROCUREMENT'
            or v_handoff.revision_status<>'RELEASED_TO_PROCUREMENT'
            or (select count(*) from atlas_planning.purchase_handoff_batches h
              join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
              where h.confirmed_need_batch_id=v_batch_id and revision.is_current)<>1))
        or (v_handoff.purchase_handoff_batch_id is null and exists(select 1
          from atlas_planning.purchase_handoff_batches h where h.confirmed_need_batch_id=v_batch_id)) then
        v_correction_code:='CORRECTION_RELEASE_MISMATCH';
      else
        v_preflight:=atlas_core.planning_contract_01_preflight_payload(v_batch.period_start,v_batch.period_start,null);
        if v_batch.period_start is distinct from v_batch.period_end
          or exists(select 1 from atlas_planning.confirmed_need_lines line
            where line.confirmed_need_batch_id=v_batch_id and line.service_date is distinct from v_batch.period_start)
          or v_preflight->>'readiness_state' is distinct from 'READY'
          or v_preflight->'blocking_issue_count' is distinct from '0'::jsonb
          or v_preflight->>'downstream_currentness' is distinct from 'CURRENT'
          or (v_preflight->'current_need' @> jsonb_build_object(
            'confirmed_need_batch_id',v_batch_id,'confirmed_need_batch_version',v_batch.version,
            'need_generation_run_id',v_batch.current_need_generation_run_id,
            'need_generation_run_version',v_batch.current_need_generation_run_version,
            'need_generation_release_snapshot_id',v_batch.current_need_generation_release_snapshot_id)) is distinct from true then
          v_correction_code:='CORRECTION_SOURCE_NOT_CURRENT';
        else
          v_correction_code:='CORRECTION_SOURCE_INVALID';
          v_facts:=atlas_core.rmvp_07_validated_facts_projection(v_batch_id);
          v_original_facts:=atlas_core.rmvp_07_validated_facts_projection(
            v_batch_id,v_original.confirmed_need_validation_attempt_id);
          if atlas_core.rmvp_06_canonical_evaluation(v_batch_id)->>'outcome'='VALIDATED'
            and jsonb_typeof(v_facts->'ordered_lines')='array'
            and jsonb_typeof(v_original_facts->'ordered_lines')='array'
            and jsonb_array_length(v_facts->'ordered_lines')>0
            and jsonb_array_length(v_facts->'ordered_lines')=jsonb_array_length(v_original_facts->'ordered_lines')
            and encode(sha256(convert_to(v_original_facts::text,'UTF8')),'hex')=v_original.validated_fact_fingerprint
            and (select count(*) from atlas_planning.confirmed_need_snapshot_lines member
              where member.confirmed_need_approval_snapshot_id=v_original.confirmed_need_approval_snapshot_id)
                =jsonb_array_length(v_original_facts->'ordered_lines') then
            v_correction_facts_valid:=true;
            for v_current_fact in select value from jsonb_array_elements(v_facts->'ordered_lines') loop
              select value into v_original_fact from jsonb_array_elements(v_original_facts->'ordered_lines')
              where value->>'confirmed_need_line_id'=v_current_fact->>'confirmed_need_line_id';
              if v_original_fact is null
                or (v_current_fact-array['line_sort_position','current_confirmed_need_line_revision_id',
                  'current_confirmed_need_line_decision_id','confirmed_quantity','planning_tick_count','ordered_source_members'])
                  is distinct from (v_original_fact-array['line_sort_position','current_confirmed_need_line_revision_id',
                  'current_confirmed_need_line_decision_id','confirmed_quantity','planning_tick_count','ordered_source_members'])
                or not exists(select 1 from atlas_planning.confirmed_need_snapshot_lines snapshot_line
                  where snapshot_line.confirmed_need_approval_snapshot_id=v_original.confirmed_need_approval_snapshot_id
                    and snapshot_line.confirmed_need_line_revision_id=(v_original_fact->>'current_confirmed_need_line_revision_id')::uuid
                    and snapshot_line.approved_quantity=(v_original_fact->>'confirmed_quantity')::numeric)
                or exists((select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                    from atlas_planning.confirmed_need_line_revision_contributions c
                    where c.confirmed_need_line_revision_id=(v_current_fact->>'current_confirmed_need_line_revision_id')::uuid
                    except select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                    from atlas_planning.confirmed_need_line_revision_contributions c
                    where c.confirmed_need_line_revision_id=(v_original_fact->>'current_confirmed_need_line_revision_id')::uuid)
                  union all (select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                    from atlas_planning.confirmed_need_line_revision_contributions c
                    where c.confirmed_need_line_revision_id=(v_original_fact->>'current_confirmed_need_line_revision_id')::uuid
                    except select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id','confirmed_need_line_revision_id','created_at']
                    from atlas_planning.confirmed_need_line_revision_contributions c
                    where c.confirmed_need_line_revision_id=(v_current_fact->>'current_confirmed_need_line_revision_id')::uuid)) then
                v_correction_facts_valid:=false; exit;
              end if;
              if v_current_fact->>'current_confirmed_need_line_revision_id'=v_original_fact->>'current_confirmed_need_line_revision_id' then
                if v_current_fact->>'current_confirmed_need_line_decision_id' is distinct from
                  v_original_fact->>'current_confirmed_need_line_decision_id' then
                  v_correction_facts_valid:=false; exit;
                end if;
              else
                -- A carried original decision alone is not a new human correction.
                if v_current_fact->>'current_confirmed_need_line_decision_id' is not distinct from
                  v_original_fact->>'current_confirmed_need_line_decision_id' then
                  v_correction_facts_valid:=false; exit;
                end if;
                if not exists(with recursive chain as (
                    select decision.* from atlas_planning.confirmed_need_line_decisions decision
                    where decision.confirmed_need_line_decision_id=(v_current_fact->>'current_confirmed_need_line_decision_id')::uuid
                    union all select prior.* from chain
                    join atlas_planning.confirmed_need_line_decisions prior
                      on prior.confirmed_need_line_decision_id=chain.predecessor_decision_id
                    where chain.confirmed_need_line_decision_id<>(v_original_fact->>'current_confirmed_need_line_decision_id')::uuid)
                  select 1 from chain where confirmed_need_line_decision_id=(v_original_fact->>'current_confirmed_need_line_decision_id')::uuid
                    and atlas_core.planning_contract_02b_decision_authorizes_revision(confirmed_need_line_decision_id,
                      confirmed_need_line_id,(v_original_fact->>'current_confirmed_need_line_revision_id')::uuid)
                    and not exists(select 1 from chain successor
                      join atlas_planning.confirmed_need_line_revisions revision
                        on revision.confirmed_need_line_revision_id=successor.confirmed_need_line_revision_id
                      join atlas_planning.confirmed_need_line_decisions prior
                        on prior.confirmed_need_line_decision_id=successor.predecessor_decision_id
                      where successor.confirmed_need_line_decision_id<>(v_original_fact->>'current_confirmed_need_line_decision_id')::uuid
                        and (successor.decision_kind<>'ADJUSTED_QUANTITY_CONFIRMED'
                          or successor.confirmed_need_batch_version<=v_original.resulting_released_batch_version
                          or not atlas_core.planning_contract_02b_decision_authorizes_revision(prior.confirmed_need_line_decision_id,
                            prior.confirmed_need_line_id,revision.predecessor_revision_id)
                          or successor.proposed_quantity_before is distinct from prior.confirmed_quantity_after))) then
                  v_correction_facts_valid:=false; exit;
                end if;
                v_corrected_chain:=true;
              end if;
            end loop;
            if v_correction_facts_valid and (v_batch.batch_status='RELEASED_FOR_PURCHASE_HANDOFF'
              or (v_batch.released_at is not null and v_corrected_chain)) then
              v_correction_code:=null;
            elsif v_correction_facts_valid then
              v_correction_code:='CORRECTION_HISTORY_INVALID';
              v_correction_facts_valid:=false;
            end if;
          end if;
        end if;
      end if;
    end if;
  exception when others then
    -- Missing, malformed or unreadable evidence never grants advisory admission.
    v_correction_code:='CORRECTION_SOURCE_UNAVAILABLE';
    v_correction_facts_valid:=false;
    v_corrected_chain:=false;
  end;
  if not v_correction_capable then v_correction_code:='CORRECTION_CAPABILITY_REQUIRED'; end if;
  v_correction_message:=case v_correction_code
    when 'CORRECTION_CAPABILITY_REQUIRED' then 'Bạn chưa có đủ quyền điều chỉnh nhu cầu đã phát hành.'
    when 'CORRECTION_SOURCE_NOT_CURRENT' then 'Nguồn nhu cầu đã thay đổi. Tải lại và kiểm tra nguồn trước khi điều chỉnh.'
    when 'CORRECTION_SOURCE_NOT_AVAILABLE' then 'Nhu cầu này chưa có lần phát hành phù hợp để điều chỉnh.'
    when 'CORRECTION_UNSUPPORTED_SOURCE_KIND' then 'Nguồn nhu cầu này không hỗ trợ điều chỉnh sau phát hành.'
    when 'CORRECTION_RELEASE_MISMATCH' then 'Chưa xác minh được lần phát hành và bàn giao gốc. Vui lòng tải lại.'
    when 'CORRECTION_HISTORY_INVALID' then 'Chưa xác minh được lịch sử điều chỉnh sau phát hành. Vui lòng tải lại.'
    when 'CORRECTION_SOURCE_INVALID' then 'Chưa xác minh được đầy đủ nguồn và lịch sử nhu cầu. Vui lòng tải lại.'
    when 'CORRECTION_SOURCE_UNAVAILABLE' then 'Chưa thể kiểm tra quyền điều chỉnh lúc này. Vui lòng tải lại.'
    else null end;
  p_workbench:=p_workbench||jsonb_build_object(
    'allowed_actions',(p_workbench->'allowed_actions')||jsonb_build_object('correct_released_confirmed_needs',v_correction_code is null),
    'disabled_reason_codes',(p_workbench->'disabled_reason_codes')||jsonb_build_object('correct_released_confirmed_needs',v_correction_code),
    'disabled_reasons',(p_workbench->'disabled_reasons')||jsonb_build_object('correct_released_confirmed_needs',v_correction_message));
  p_workbench:=p_workbench||jsonb_build_object('need_correction_authority',$new$);
  definition:=replace(definition,'''operationally_available'',false',
    '''operationally_available'',v_correction_code is null');
  definition:=replace(definition,'''downstream_workflow_available'',false',
    '''downstream_workflow_available'',v_correction_facts_valid and v_corrected_chain and v_correction_handoff_present');
  definition:=replace(definition,
    '''pending_obligations'',jsonb_build_array(''ALLOCATION_REVIEW'',
        ''PROCUREMENT_TRANSFER_NOT_IMPLEMENTED'',''REPLACEMENT_REVIEW_AND_EXPLICIT_RELEASE'')',
    '''pending_obligations'',case when v_corrected_chain then jsonb_build_array(''PROCUREMENT_CURRENTNESS_REVIEW'') else ''[]''::jsonb end');
  definition:=replace(definition,
    'Điều chỉnh sau phát hành chỉ khả dụng trong kiểm chứng K1; quy trình hạ nguồn chưa khả dụng.',
    'Nhu cầu đã được điều chỉnh sau phát hành. Dùng thao tác điều chỉnh nhu cầu đã phát hành.');
  if position('''PROCUREMENT_TRANSFER_NOT_IMPLEMENTED''' in definition)>0
    or position('correct_released_confirmed_needs' in definition)=0 then
    raise exception 'K3 review replacement did not match';
  end if;
  execute definition;
end $k3_read$;
commit;
