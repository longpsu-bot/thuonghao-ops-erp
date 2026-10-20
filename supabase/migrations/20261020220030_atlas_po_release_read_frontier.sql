-- Match K2's final release prerequisite in the existing authorized PO read.
-- Advisory only: no writer, lifecycle, historical snapshot or public grant changes.
begin;
create temporary table po_frontier_membership_lease on commit drop as
select roleid,member,grantor,set_option from pg_auth_members;
create temporary table po_frontier_schema_lease on commit drop as
select exists(select 1 from aclexplode(coalesce(nspacl,acldefault('n',nspowner))) acl
  where acl.grantee='atlas_read_runtime'::regrole and acl.grantor=nspowner
    and acl.privilege_type='CREATE') had_create
from pg_namespace where nspname='atlas_api';
create temporary table po_frontier_core_schema_lease on commit drop as
select exists(select 1 from aclexplode(coalesce(nspacl,acldefault('n',nspowner))) acl
  where acl.grantee='atlas_procurement_command_runtime'::regrole and acl.grantor=nspowner
    and acl.privilege_type='CREATE') had_create
from pg_namespace where nspname='atlas_core';
grant select on po_frontier_schema_lease,po_frontier_core_schema_lease to atlas_owner;
grant atlas_owner,atlas_read_runtime,atlas_procurement_command_runtime
  to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime;
grant create on schema atlas_core to atlas_procurement_command_runtime;
reset role;
set local role atlas_procurement_command_runtime;
-- Derive private read variants from the unchanged writer helpers. Only their
-- context construction changes: reuse the authorized request's existing proof.
-- The original frontier would reconstruct the expensive closed-batch proof twice
-- after the read had already built it once. No proof predicate is removed.
do $read_helpers$
declare definition text; anchor text; first_position integer; last_position integer;
begin
  definition:=pg_get_functiondef('atlas_core.purchase_review_po_coverage(date)'::regprocedure);
  anchor:='FUNCTION atlas_core.purchase_review_po_coverage(p_date date)';
  if position(anchor in definition)=0 then raise exception 'PO coverage signature changed'; end if;
  definition:=replace(definition,anchor,
    'FUNCTION atlas_core.procurement_read_purchase_review_po_coverage(p_date date, p_read_context jsonb)');
  first_position:=position('  with context as materialized (select case when exists(' in definition);
  last_position:=position(' expected as materialized (' in definition);
  if first_position=0 or last_position<=first_position then raise exception 'PO coverage context changed'; end if;
  anchor:=substring(definition from first_position for last_position-first_position);
  if position('atlas_core.procurement_read_context(p_date,p_date)' in anchor)=0 then
    raise exception 'PO coverage proof construction changed'; end if;
  definition:=replace(definition,anchor,'  with context as materialized (select p_read_context value),');
  execute definition;

  definition:=pg_get_functiondef('atlas_core.purchase_review_preparation_po_frontier(date)'::regprocedure);
  anchor:='FUNCTION atlas_core.purchase_review_preparation_po_frontier(p_date date)';
  if position(anchor in definition)=0 then raise exception 'PO frontier signature changed'; end if;
  definition:=replace(definition,anchor,
    'FUNCTION atlas_core.procurement_read_purchase_review_preparation_po_frontier(p_date date, p_read_context jsonb)');
  anchor:='atlas_core.purchase_review_po_coverage(p_date)';
  if regexp_count(definition,'atlas_core\.purchase_review_po_coverage\(p_date\)')<>1 then
    raise exception 'PO frontier coverage call changed'; end if;
  definition:=replace(definition,anchor,'atlas_core.procurement_read_purchase_review_po_coverage(p_date,p_read_context)');
  first_position:=position('  v_phase_context:=case when exists(' in definition);
  last_position:=position('  v_readiness :=' in definition);
  if first_position=0 or last_position<=first_position then raise exception 'PO frontier context changed'; end if;
  anchor:=substring(definition from first_position for last_position-first_position);
  if position('atlas_core.procurement_read_context(p_date,p_date)' in anchor)=0 then
    raise exception 'PO frontier proof construction changed'; end if;
  definition:=replace(definition,anchor,E'  v_phase_context:=p_read_context;\n');
  execute definition;
end $read_helpers$;
revoke all on function atlas_core.procurement_read_purchase_review_po_coverage(date,jsonb),
  atlas_core.procurement_read_purchase_review_preparation_po_frontier(date,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.procurement_read_purchase_review_preparation_po_frontier(date,jsonb)
  to atlas_read_runtime;
reset role;
set local role atlas_read_runtime;
do $patch$
declare
  definition text:=pg_get_functiondef('atlas_api.get_school_catering_purchase_orders_v2_base(jsonb)'::regprocedure);
  anchor text;
begin
  if position(E'declare\n' in definition)=0 then raise exception 'PO read declaration changed'; end if;
  definition:=replace(definition,E'declare\n',E'declare\n  v_release_dates jsonb:=\'{}\'::jsonb; v_release_date date;\n  v_frontier jsonb; v_release_blockers jsonb; v_date_messages jsonb:=\'[]\'::jsonb;\n  v_order jsonb; v_orders jsonb:=\'[]\'::jsonb;\n');
  anchor:=$old$  return v_base || jsonb_build_object($old$;
  if position(anchor in definition)=0 then raise exception 'PO authorized row loop changed'; end if;
  definition:=replace(definition,anchor,$new$  -- Authorization and the existing filters have already shaped these rows.
  -- Only dates with visible Drafts and the exact K2 correction branch need proof.
  -- Evaluate once per represented date, independent of Supplier/search filters.
  for v_release_date in
    select distinct (po->>'service_date')::date
    from jsonb_array_elements(v_rows) po
    where po->>'status'='DRAFT' and exists(
      select 1 from atlas_planning.confirmed_need_batches batch
      where batch.period_start=(po->>'service_date')::date
        and batch.period_end=batch.period_start and batch.batch_status='REOPENED'
        and batch.released_at is not null)
    order by 1
  loop
    v_frontier:=atlas_core.procurement_read_purchase_review_preparation_po_frontier(v_release_date,v_read_context);
    if v_frontier->>'acceptable' is distinct from 'true' then
      -- A filtered/scoped Actor must not learn another document's private reason.
      -- Match the writer's generic prerequisite, without disclosing the frontier.
      v_release_blockers:=jsonb_build_array(to_char(v_release_date,'DD/MM/YYYY')||
        ': Cần chuẩn bị đầy đủ đơn mua theo phân bổ hiện tại trước khi phát hành. Kiểm tra các đơn Cần cập nhật hoặc trở lại Phân bổ NCC.');
      v_release_dates:=v_release_dates||jsonb_build_object(v_release_date::text,v_release_blockers);
      v_date_messages:=v_date_messages||v_release_blockers;
    end if;
  end loop;
  for v_order in select value from jsonb_array_elements(v_rows) loop
    v_release_blockers:=v_release_dates->(v_order->>'service_date');
    if v_order->>'status'='DRAFT' and v_release_blockers is not null then
      v_order:=v_order||jsonb_build_object(
        'release_eligible',false,
        'allowed_actions',(v_order->'allowed_actions')||jsonb_build_object('release',false),
        'blockers',coalesce(v_order->'blockers','[]'::jsonb)||v_release_blockers,
        'disabled_reasons',coalesce(v_order->'disabled_reasons','[]'::jsonb)||v_release_blockers);
    end if;
    v_orders:=v_orders||jsonb_build_array(v_order);
  end loop;
  return v_base || jsonb_build_object($new$);
  anchor:=$old$'purchase_orders',v_rows,'procurement_current',v_current,$old$;
  if position(anchor in definition)=0 then raise exception 'PO row result changed'; end if;
  definition:=replace(definition,anchor,$new$'purchase_orders',v_orders,'procurement_current',v_current,$new$);
  anchor:=$old$else jsonb_build_array('PROCUREMENT_NOT_CURRENT') end);$old$;
  if position(anchor in definition)=0 then raise exception 'PO blocker result changed'; end if;
  definition:=replace(definition,anchor,$new$else jsonb_build_array('PROCUREMENT_NOT_CURRENT') end||v_date_messages);$new$);
  execute definition;
end $patch$;
reset role;
set local role atlas_owner;
do $restore$ begin
  if not (select had_create from po_frontier_schema_lease) then
    revoke create on schema atlas_api from atlas_read_runtime;
  end if;
  if not (select had_create from po_frontier_core_schema_lease) then
    revoke create on schema atlas_core from atlas_procurement_command_runtime;
  end if;
end $restore$;
reset role;
do $restore$ declare leased_role text; original_set boolean; begin
  foreach leased_role in array array['atlas_owner','atlas_read_runtime','atlas_procurement_command_runtime'] loop
    select original.set_option into original_set from po_frontier_membership_lease original
    where original.roleid=leased_role::regrole and original.member='postgres'::regrole
      and original.grantor='postgres'::regrole;
    if found then
      execute format('grant %I to postgres with set %s',leased_role,
        case when original_set then 'true' else 'false' end);
    else
      execute format('revoke %I from postgres granted by postgres',leased_role);
    end if;
  end loop;
end $restore$;
commit;
