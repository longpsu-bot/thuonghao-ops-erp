-- C K1 only: a closed correction branch in the existing writer. No transfer,
-- Procurement/PXK mutation, new function, role or historical guard change.
-- Patch the installed definitions so ownership, ACL and runtime attributes stay.
-- Owner authorizes canonical preflight reuse and exact source-root locking.
grant execute on function atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)
  to atlas_confirmed_need_review_runtime;

-- RMVP-04 lock-only pattern: keys are readable/lockable; RLS forbids writes.
grant select (weekly_menu_id), update (weekly_menu_id)
  on atlas_planning.weekly_menus to atlas_confirmed_need_review_runtime;
grant select (attendance_batch_id), update (attendance_batch_id)
  on atlas_planning.attendance_batches to atlas_confirmed_need_review_runtime;
grant select (pantry_need_batch_id), update (pantry_need_batch_id)
  on atlas_planning.pantry_need_batches to atlas_confirmed_need_review_runtime;
create policy k1_need_correction_menu_select on atlas_planning.weekly_menus
  for select to atlas_confirmed_need_review_runtime using (true);
create policy k1_need_correction_menu_lock on atlas_planning.weekly_menus
  for update to atlas_confirmed_need_review_runtime using (true) with check (false);
create policy k1_need_correction_attendance_select on atlas_planning.attendance_batches
  for select to atlas_confirmed_need_review_runtime using (true);
create policy k1_need_correction_attendance_lock on atlas_planning.attendance_batches
  for update to atlas_confirmed_need_review_runtime using (true) with check (false);
create policy k1_need_correction_pantry_select on atlas_planning.pantry_need_batches
  for select to atlas_confirmed_need_review_runtime using (true);
create policy k1_need_correction_pantry_lock on atlas_planning.pantry_need_batches
  for update to atlas_confirmed_need_review_runtime using (true) with check (false);
do $k1_validator$
declare definition text;
begin
  if (select md5(prosrc) from pg_proc where oid=
      'atlas_core.d037_validate_command(jsonb,text)'::regprocedure)
      <> '84ea46bfd9785aa013591b0148ca9520' then
    raise exception 'K1 unexpected command validator baseline';
  end if;
  definition:=pg_get_functiondef('atlas_core.d037_validate_command(jsonb,text)'::regprocedure);
  definition:=replace(definition,
    'then ''RMVP-05.v2'' else ''RMVP-07.v2'' end;',
    'then case when request->>''contract_version''=''RMVP-05.v3''
      then ''RMVP-05.v3'' else ''RMVP-05.v2'' end else ''RMVP-07.v2'' end;');
  definition:=replace(definition,'  if v_payload - array[''confirmed_need_batch_id'', ''lines'']',
$new$  if v_contract='RMVP-05.v3' then
    if v_payload - array['confirmed_need_batch_id','lines','correction']<>'{}'::jsonb
      or jsonb_typeof(v_payload->'correction') is distinct from 'object'
      or not((v_payload->'correction') ?& array[
        'expected_confirmed_need_release_id','expected_purchase_handoff_batch_id',
        'expected_purchase_handoff_revision_id','expected_purchase_handoff_version',
        'expected_source_fingerprint'])
      or (v_payload->'correction')-array[
        'expected_confirmed_need_release_id','expected_purchase_handoff_batch_id',
        'expected_purchase_handoff_revision_id','expected_purchase_handoff_version',
        'expected_source_fingerprint']<>'{}'::jsonb
      or atlas_core.pa_05b_safe_uuid(v_payload#>>'{correction,expected_confirmed_need_release_id}') is null
      or coalesce(v_payload#>>'{correction,expected_source_fingerprint}','') !~ '^[0-9a-f]{64}$'
      or not (
        ((v_payload#>'{correction,expected_purchase_handoff_batch_id}')='null'::jsonb
          and (v_payload#>'{correction,expected_purchase_handoff_revision_id}')='null'::jsonb
          and (v_payload#>'{correction,expected_purchase_handoff_version}')='null'::jsonb)
        or (atlas_core.pa_05b_safe_uuid(v_payload#>>'{correction,expected_purchase_handoff_batch_id}') is not null
          and atlas_core.pa_05b_safe_uuid(v_payload#>>'{correction,expected_purchase_handoff_revision_id}') is not null
          and atlas_core.pa_05b_safe_bigint(v_payload#>>'{correction,expected_purchase_handoff_version}')>0))
    then
      return atlas_core.d037_error(request,v_contract,command_name,
        'VALIDATION_FAILED','Provide the exact released correction source.');
    end if;
    v_payload:=v_payload-'correction';
  end if;
  if v_payload - array['confirmed_need_batch_id', 'lines']$new$);
  execute definition;
end $k1_validator$;

do $k1_save$
declare definition text;
begin
  if (select md5(prosrc) from pg_proc where oid=
      'atlas_api.save_confirmed_needs(jsonb)'::regprocedure)
      <> '7c6c3d26180a62a4ea3af19391f4de56' then
    raise exception 'K1 unexpected Save baseline';
  end if;
  definition:=pg_get_functiondef('atlas_api.save_confirmed_needs(jsonb)'::regprocedure);
  definition:=replace(definition,'''RMVP-05.v2''','v_contract');
  definition:=replace(definition,'  v_error jsonb;',
$new$  v_contract text:=case when request->>'contract_version'='RMVP-05.v3'
    then 'RMVP-05.v3' else 'RMVP-05.v2' end;
  v_correction boolean:=request->>'contract_version'='RMVP-05.v3';
  v_extra_capability text;
  v_original record;
  v_handoff record;
  v_facts jsonb;
  v_original_facts jsonb;
  v_evaluation jsonb;
  v_preflight jsonb;
  v_error jsonb;$new$);
  definition:=replace(definition,
    '  v_begin := atlas_core.pa_05b_begin_command(request, v_actor_id, v_name,',
$new$  if v_correction then
    foreach v_extra_capability in array array[
      'planning.need_generation.write','confirmed_need_release.release'] loop
      v_context:=atlas_core.rmvp_05_authorize_global(
        request,v_extra_capability,v_name,false);
      if v_context?'error' then
        return (v_context->'error')||jsonb_build_object('contract_version',v_contract);
      end if;
    end loop;
  end if;
  v_begin := atlas_core.pa_05b_begin_command(request, v_actor_id, v_name,$new$);
  definition:=replace(definition,
    '  select * into v_batch from atlas_planning.confirmed_need_batches batch',
$new$  -- Source correction takes run before batch. Match it without changing v2.
  if v_correction then
    perform run.need_generation_run_id from atlas_planning.need_generation_runs run
    join atlas_planning.confirmed_need_batches batch
      on batch.current_need_generation_run_id=run.need_generation_run_id
    where batch.confirmed_need_batch_id=v_batch_id
    order by run.need_generation_run_id for share of run;
  end if;
  select * into v_batch from atlas_planning.confirmed_need_batches batch$new$);
  definition:=replace(definition,
    '  if v_batch.batch_status not in (''DRAFT_REVIEW'', ''REOPENED'') then',
$new$  if v_correction then
    if v_batch.batch_status not in ('RELEASED_FOR_PURCHASE_HANDOFF','REOPENED') then
      v_error:=atlas_core.d037_error(request,v_contract,v_name,
        'CORRECTION_SOURCE_NOT_AVAILABLE','This batch has no released correction authority.');
      return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
    end if;
  elsif exists (
    select 1 from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_line_decisions decision
      on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
    join atlas_core.command_receipts receipt on receipt.command_id=decision.command_id
    where line.confirmed_need_batch_id=v_batch_id
      and receipt.response_payload->>'contract_version'='RMVP-05.v3') then
    v_error:=atlas_core.d037_error(request,v_contract,v_name,
      'CORRECTION_CONTRACT_REQUIRED','Use the versioned released correction command.');
    return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
  end if;
  if not v_correction and v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then$new$);
  definition:=replace(definition,'  perform line.confirmed_need_line_id',
$new$  if v_correction then
    -- Resolve roots from canonical server evidence, never request candidates.
    v_preflight:=atlas_core.planning_contract_01_preflight_payload(
      v_batch.period_start,v_batch.period_start,null);
    -- Keep RMVP-04's Menu -> Attendance -> Pantry order before Need line/revision
    -- waits. SHARE blocks source writers and is held through transaction end.
    perform menu.weekly_menu_id from atlas_planning.weekly_menus menu
    where menu.weekly_menu_id=atlas_core.pa_05b_safe_uuid(
      v_preflight#>>'{current_need,weekly_menu_id}')
    order by menu.weekly_menu_id for share;
    perform attendance.attendance_batch_id from atlas_planning.attendance_batches attendance
    where attendance.attendance_batch_id=atlas_core.pa_05b_safe_uuid(
      v_preflight#>>'{current_need,attendance_batch_id}')
    order by attendance.attendance_batch_id for share;
    perform pantry.pantry_need_batch_id from atlas_planning.pantry_need_batches pantry
    where pantry.pantry_need_batch_id=atlas_core.pa_05b_safe_uuid(
      v_preflight#>>'{current_need,pantry_need_batch_id}')
    order by pantry.pantry_need_batch_id for share;
  end if;
  perform line.confirmed_need_line_id$new$);
  definition:=replace(definition,
    '  v_preview := atlas_core.rmvp_05_canonical_preview(v_batch_id,',
$new$  if v_correction then
    -- Revalidate the complete current fact set and original release under locks.
    perform line.confirmed_need_line_id from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id=v_batch_id
    order by line.confirmed_need_line_id for update;
    perform policy.planning_quantity_policy_id
    from atlas_planning.planning_quantity_policies policy
    where policy.unit_id in (select line.controlled_unit_id
      from atlas_planning.confirmed_need_lines line where line.confirmed_need_batch_id=v_batch_id)
    order by policy.planning_quantity_policy_id for share;
    perform revision.planning_quantity_policy_revision_id
    from atlas_planning.planning_quantity_policy_revisions revision
    where revision.unit_id in (select line.controlled_unit_id
      from atlas_planning.confirmed_need_lines line where line.confirmed_need_batch_id=v_batch_id)
    order by revision.planning_quantity_policy_revision_id for share;
    perform source.need_generation_release_snapshot_id
    from atlas_planning.need_generation_release_snapshots source
    where source.need_generation_release_snapshot_id=v_batch.current_need_generation_release_snapshot_id for share;
    perform member.need_generation_release_snapshot_line_id
    from atlas_planning.need_generation_release_snapshot_lines member
    where member.need_generation_release_snapshot_id=v_batch.current_need_generation_release_snapshot_id
    order by member.need_generation_release_snapshot_line_id for share;
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
    where release.confirmed_need_release_id=atlas_core.pa_05b_safe_uuid(
        request#>>'{payload,correction,expected_confirmed_need_release_id}')
      and release.confirmed_need_batch_id=v_batch_id and release.source_kind='NEED_GENERATION'
      and release.resulting_released_batch_version=(select max(prior.resulting_released_batch_version)
        from atlas_planning.confirmed_need_releases prior where prior.confirmed_need_batch_id=v_batch_id)
    for share of release,snapshot,attempt;
    select h.purchase_handoff_batch_id,h.version,h.handoff_status,
      revision.purchase_handoff_revision_id,revision.revision_status into v_handoff
    from atlas_planning.purchase_handoff_batches h
    join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
    where h.confirmed_need_batch_id=v_batch_id and revision.is_current
    for share of h,revision;
    if v_original.confirmed_need_release_id is null
      or (v_batch.batch_status='RELEASED_FOR_PURCHASE_HANDOFF'
        and v_batch.current_confirmed_need_release_id is distinct from v_original.confirmed_need_release_id)
      or v_handoff.purchase_handoff_batch_id is distinct from atlas_core.pa_05b_safe_uuid(
        request#>>'{payload,correction,expected_purchase_handoff_batch_id}')
      or v_handoff.purchase_handoff_revision_id is distinct from atlas_core.pa_05b_safe_uuid(
        request#>>'{payload,correction,expected_purchase_handoff_revision_id}')
      or v_handoff.version is distinct from atlas_core.pa_05b_safe_bigint(
        request#>>'{payload,correction,expected_purchase_handoff_version}')
      or (v_handoff.purchase_handoff_batch_id is not null and
        (v_handoff.handoff_status<>'RELEASED_TO_PROCUREMENT'
          or v_handoff.revision_status<>'RELEASED_TO_PROCUREMENT'))
      or (v_handoff.purchase_handoff_batch_id is null and exists(
        select 1 from atlas_planning.purchase_handoff_batches h where h.confirmed_need_batch_id=v_batch_id))
    then
      v_error:=atlas_core.d037_error(request,v_contract,v_name,
        'CORRECTION_RELEASE_MISMATCH','The original release or Handoff evidence changed.');
      return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
    end if;
    -- Fresh statement snapshot after any source-lock wait; roots remain locked.
    v_preflight:=atlas_core.planning_contract_01_preflight_payload(
      v_batch.period_start,v_batch.period_start,null);
    if v_batch.period_start is distinct from v_batch.period_end
      or exists(select 1 from atlas_planning.confirmed_need_lines line
        where line.confirmed_need_batch_id=v_batch_id
          and line.service_date is distinct from v_batch.period_start)
      or v_preflight->>'readiness_state' is distinct from 'READY'
      or v_preflight->'blocking_issue_count' is distinct from '0'::jsonb
      or v_preflight->>'downstream_currentness' is distinct from 'CURRENT'
      or (v_preflight->'current_need' @> jsonb_build_object(
        'confirmed_need_batch_id',v_batch_id,
        'confirmed_need_batch_version',v_batch.version,
        'need_generation_run_id',v_batch.current_need_generation_run_id,
        'need_generation_run_version',v_batch.current_need_generation_run_version,
        'need_generation_release_snapshot_id',v_batch.current_need_generation_release_snapshot_id))
        is distinct from true
    then
      v_error:=atlas_core.d037_error(request,v_contract,v_name,
        'CORRECTION_SOURCE_NOT_CURRENT','The current upstream source is unavailable or changed.');
      return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
    end if;
    v_evaluation:=atlas_core.rmvp_06_canonical_evaluation(v_batch_id);
    v_facts:=atlas_core.rmvp_07_validated_facts_projection(v_batch_id);
    v_original_facts:=atlas_core.rmvp_07_validated_facts_projection(
      v_batch_id,v_original.confirmed_need_validation_attempt_id);
    if v_evaluation->>'outcome' is distinct from 'VALIDATED'
      or encode(sha256(convert_to(v_original_facts::text,'UTF8')),'hex')
        is distinct from v_original.validated_fact_fingerprint
      or jsonb_array_length(v_facts->'ordered_lines')<>jsonb_array_length(v_original_facts->'ordered_lines')
      or exists (
        select 1 from jsonb_array_elements(v_facts->'ordered_lines') current_fact
        left join jsonb_array_elements(v_original_facts->'ordered_lines') original_fact
          on original_fact->>'confirmed_need_line_id'=current_fact->>'confirmed_need_line_id'
        where original_fact is null
          or (current_fact-array['line_sort_position','current_confirmed_need_line_revision_id',
            'current_confirmed_need_line_decision_id','confirmed_quantity','planning_tick_count','ordered_source_members'])
          is distinct from (original_fact-array['line_sort_position','current_confirmed_need_line_revision_id',
            'current_confirmed_need_line_decision_id','confirmed_quantity','planning_tick_count','ordered_source_members'])
          or not exists (
            select 1 from atlas_planning.confirmed_need_snapshot_lines snapshot_line
            where snapshot_line.confirmed_need_approval_snapshot_id=v_original.confirmed_need_approval_snapshot_id
              and snapshot_line.confirmed_need_line_revision_id=(original_fact->>'current_confirmed_need_line_revision_id')::uuid
              and snapshot_line.approved_quantity=(original_fact->>'confirmed_quantity')::numeric)
          or exists ((select to_jsonb(c)-array['confirmed_need_line_revision_contribution_id',
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
      ) then
      v_error:=atlas_core.d037_error(request,v_contract,v_name,
        'CORRECTION_SOURCE_INVALID','The exact original/current decision, policy or source evidence is invalid.');
      return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
    end if;
    if encode(sha256(convert_to(v_facts::text,'UTF8')),'hex') is distinct from
        request#>>'{payload,correction,expected_source_fingerprint}' then
      v_error:=atlas_core.d037_error(request,v_contract,v_name,
        'CORRECTION_SOURCE_CHANGED','Refresh the exact correction source before saving.');
      return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
    end if;
    -- One human Save advances the batch once below; this intermediate working
    -- state and its cleared pointers are never visible outside the transaction.
    update atlas_planning.confirmed_need_batches set batch_status='REOPENED',
      current_confirmed_need_validation_attempt_id=null,
      current_confirmed_need_approval_snapshot_id=null,current_confirmed_need_release_id=null
    where confirmed_need_batch_id=v_batch_id;
  end if;
  v_preview := atlas_core.rmvp_05_canonical_preview(v_batch_id,$new$);
  definition:=replace(definition,'  v_next_version := v_batch.version + 1;',
$new$  if v_correction and exists(select 1 from jsonb_array_elements(
      v_preview->'ordered_preview_lines') item
      where item->>'decision_kind' is distinct from 'ADJUSTED_QUANTITY_CONFIRMED'
        or item->>'current_decision_id' is null) then
    -- Roll back the working-pointer transition as well as all command evidence.
    raise exception using errcode='22023',message='A released correction requires an authentic changed human quantity.';
  end if;
  v_next_version := v_batch.version + 1;$new$);
  -- Any ordinary preview rejection must also roll back the prior working reopen.
  definition:=replace(definition,
    '  if not coalesce((v_preview ->> ''success'')::boolean, false) then',
$new$  if v_correction and not coalesce((v_preview->>'success')::boolean,false) then
    raise exception using errcode='22023',message='The released correction failed exact quantity or reason validation.';
  end if;
  if not coalesce((v_preview ->> 'success')::boolean, false) then$new$);
  definition:=replace(definition,'  v_response := atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);',
$new$  if v_correction then
    v_response:=v_response||jsonb_build_object('downstream_workflow_available',false,
      'supplier_commitment_changed',false,'original_release_id',v_original.confirmed_need_release_id,
      'original_purchase_handoff_revision_id',v_handoff.purchase_handoff_revision_id,
      'safe_operator_message','Đã lưu điều chỉnh nhu cầu. Đơn nhà cung cấp chưa được chuẩn bị hoặc phát hành lại; quy trình hạ nguồn chưa khả dụng.');
  end if;
  v_response := atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);$new$);
  execute definition;
end $k1_save$;

do $k1_readback$
declare definition text;
begin
  if (select md5(prosrc) from pg_proc where oid=
      'atlas_core.d037_extend_workbench(jsonb,uuid)'::regprocedure)
      <> '2b25b7cbe4cfd24b951e8e85411ec72d' then
    raise exception 'K1 unexpected readback baseline';
  end if;
  definition:=pg_get_functiondef('atlas_core.d037_extend_workbench(jsonb,uuid)'::regprocedure);
  definition:=replace(definition,'  return p_workbench || pg_catalog.jsonb_build_object(',
$new$  p_workbench:=p_workbench||jsonb_build_object('need_correction_authority',
    jsonb_build_object('contract_version','RMVP-05.v3','operationally_available',false,
      'downstream_workflow_available',false,'supplier_commitment_changed',false,
      'source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(v_batch_id)::text,'UTF8')),'hex'),
      'original_release',(select to_jsonb(release) from atlas_planning.confirmed_need_releases release
        where release.confirmed_need_batch_id=v_batch_id
        order by release.resulting_released_batch_version desc limit 1),
      'purchase_handoff',(select jsonb_build_object(
        'purchase_handoff_batch_id',h.purchase_handoff_batch_id,'version',h.version,
        'purchase_handoff_revision_id',revision.purchase_handoff_revision_id)
        from atlas_planning.purchase_handoff_batches h
        join atlas_planning.purchase_handoff_revisions revision using(purchase_handoff_batch_id)
        where h.confirmed_need_batch_id=v_batch_id and revision.is_current),
      'current_lines',(select coalesce(jsonb_agg(jsonb_build_object(
        'confirmed_need_line_id',line.confirmed_need_line_id,
        'current_revision_id',revision.confirmed_need_line_revision_id,
        'predecessor_revision_id',revision.predecessor_revision_id,
        'current_decision_id',decision.confirmed_need_line_decision_id,
        'predecessor_decision_id',decision.predecessor_decision_id,
        'old_confirmed_quantity',decision.proposed_quantity_before::text,
        'new_confirmed_quantity',revision.confirmed_quantity::text,
        'difference',(revision.confirmed_quantity-decision.proposed_quantity_before)::text,
        'reason_code',decision.reason_code,'reason_note',decision.reason_note,
        'decided_by_actor_id',decision.decided_by_actor_id,'decided_at',decision.decided_at)
        order by line.confirmed_need_line_id),'[]'::jsonb)
        from atlas_planning.confirmed_need_lines line
        join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_id)
        left join atlas_planning.confirmed_need_line_decisions decision
          on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
        where line.confirmed_need_batch_id=v_batch_id and revision.is_current),
      'pending_obligations',jsonb_build_array('ALLOCATION_REVIEW',
        'PROCUREMENT_TRANSFER_NOT_IMPLEMENTED','REPLACEMENT_REVIEW_AND_EXPLICIT_RELEASE')));
  if exists(select 1 from atlas_planning.confirmed_need_lines line
    join atlas_planning.confirmed_need_line_decisions decision
      on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
    join atlas_core.command_receipts receipt on receipt.command_id=decision.command_id
    where line.confirmed_need_batch_id=v_batch_id and
      (receipt.response_payload->>'contract_version'='RMVP-05.v3'
        or (receipt.outcome='IN_PROGRESS' and v_batch.batch_status='REOPENED'
          and exists(select 1 from atlas_planning.purchase_handoff_batches h
            where h.confirmed_need_batch_id=v_batch_id and h.handoff_status='RELEASED_TO_PROCUREMENT')))) then
    v_save_code:='CORRECTION_CONTRACT_REQUIRED';
    v_save_message:='Điều chỉnh sau phát hành chỉ khả dụng trong kiểm chứng K1; quy trình hạ nguồn chưa khả dụng.';
  end if;
  return p_workbench || pg_catalog.jsonb_build_object($new$);
  execute definition;
end $k1_readback$;
