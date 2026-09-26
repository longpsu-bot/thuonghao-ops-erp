-- Future execution only. No business data, immutable history, timeout, public
-- API, RLS, or permanent grant changes.
set role atlas_owner;
do $membership$
declare d text; before_properties jsonb; after_properties jsonb;
begin
 select pg_get_functiondef(p.oid),jsonb_build_object('owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef)
 into d,before_properties from pg_proc p where p.oid='atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure;
 if position('  v_current_snapshot_id uuid;' in d)=0 or position('    v_revision_id:=null;' in d)=0
    or position('and (v_revision_id is null or exists (' in d)=0 then raise exception 'CLOSEOUT_MEMBERSHIP_BASELINE_MISMATCH'; end if;
 d:=replace(d,'  v_current_snapshot_id uuid;','  v_current_snapshot_id uuid;
  v_retiring boolean := false;');
 d:=replace(d,'  v_revision_id:=new.confirmed_need_line_revision_id;',
 '  v_revision_id:=new.confirmed_need_line_revision_id;
  -- Retiring an immutable revision changes only its current pointer. Its
  -- membership and captured predecessor facts are unchanged; validate this
  -- revision locally, but still prove the complete CURRENT release partition.
  if tg_table_name=''confirmed_need_line_revisions'' and tg_op=''UPDATE'' then
    v_retiring := old.is_current and not new.is_current
      and new.revision_status=''SUPERSEDED''
      and (to_jsonb(old)-array[''is_current'',''revision_status''])
        =(to_jsonb(new)-array[''is_current'',''revision_status'']);
  end if;');
 d:=replace(d,'    v_revision_id:=null;', '    if not v_retiring then v_revision_id:=null; end if;');
 d:=replace(d,'and (v_revision_id is null or exists (','and (v_revision_id is null or v_retiring or exists (');
 execute d;
 select jsonb_build_object('owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef)
 into after_properties from pg_proc p where p.oid='atlas_planning.pa_06e_h0b1b_confirmed_need_revision_membership_total()'::regprocedure;
 if before_properties is distinct from after_properties then raise exception 'CLOSEOUT_MEMBERSHIP_PROPERTIES_CHANGED'; end if;
end $membership$;
-- EXPLAIN on the 304/248 correction: 1047.557 ms planning versus 0.596 ms
-- execution for the exact 16-relation proof. Preserve every joined fact while
-- bounding planner join-order search to the explicit predecessor-first order.
alter function atlas_core.planning_legacy_adoption_unit_transition_allowed(uuid,uuid)
  set join_collapse_limit=1;
reset role;

grant atlas_need_generation_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_need_generation_runtime;
reset role;
set role atlas_need_generation_runtime;
do $retry$
declare d text; before_properties jsonb; after_properties jsonb;
 old_handler text := $old$  exception when sqlstate 'PC104' then
    return atlas_core.planning_contract_01_finish_receipt($old$;
 new_handler text := $new$  exception when sqlstate 'PC104' then
    -- Exit the inner subtransaction AND the outer receipt-owning block.
    -- The outer concurrency handler returns the safe retryable envelope after
    -- PostgreSQL has rolled back the receipt and every nested business write.
    if v_error->>'retryable'='true'
       and v_error->>'error_code'='RETRYABLE_CONCURRENCY_FAILURE' then
      raise serialization_failure using message='Nested Planning transaction must be retried';
    end if;
    return atlas_core.planning_contract_01_finish_receipt($new$;
begin
 select pg_get_functiondef(p.oid),jsonb_build_object('owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef)
 into d,before_properties from pg_proc p where p.oid='atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure;
 if position(old_handler in d)=0 then raise exception 'CLOSEOUT_RETRY_BASELINE_MISMATCH'; end if;
 d:=replace(d,old_handler,new_handler);
 -- On an outer exception the receipt was rolled back already. Do not call a
 -- deterministic-failure finalizer with an ID from the aborted transaction.
 d:=regexp_replace(d,
   '(when serialization_failure or deadlock_detected[\s\S]*?or lock_not_available or query_canceled then)\s+if v_receipt_id is not null then[\s\S]*?end if;',
   '\1');
 d:=replace(d,
 $old$      'Need Generation could not acquire a safe transaction state. Retry the exact request.'
    );$old$,
 $new$      'Need Generation could not acquire a safe transaction state. Retry the exact request.'
    ) || pg_catalog.jsonb_build_object('retryable',true);$new$);
 execute d;
 select jsonb_build_object('owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef)
 into after_properties from pg_proc p where p.oid='atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure;
 if before_properties is distinct from after_properties then raise exception 'CLOSEOUT_RETRY_PROPERTIES_CHANGED'; end if;
end $retry$;
reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_need_generation_runtime;
reset role;
grant atlas_need_generation_runtime to postgres with set false;
