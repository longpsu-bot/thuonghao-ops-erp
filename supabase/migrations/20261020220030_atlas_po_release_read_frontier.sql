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
grant select on po_frontier_schema_lease to atlas_owner;
grant atlas_owner,atlas_read_runtime,atlas_procurement_command_runtime
  to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime;
reset role;
set local role atlas_procurement_command_runtime;
-- The existing guarded read may consume this private, read-only summary.
grant execute on function atlas_core.purchase_review_preparation_po_frontier(date)
  to atlas_read_runtime;
reset role;
set local role atlas_read_runtime;
do $patch$
declare
  definition text:=pg_get_functiondef('atlas_api.get_school_catering_purchase_orders(jsonb)'::regprocedure);
  anchor text;
begin
  if position(E'declare\n' in definition)=0 then raise exception 'PO read declaration changed'; end if;
  definition:=replace(definition,E'declare\n',E'declare\n  v_release_dates jsonb:=\'{}\'::jsonb; v_release_date date;\n  v_frontier jsonb; v_release_blockers jsonb; v_date_messages jsonb:=\'[]\'::jsonb;\n');
  anchor:=$old$  for v_order in select value from jsonb_array_elements(v_response->'purchase_orders') loop$old$;
  if position(anchor in definition)=0 then raise exception 'PO authorized row loop changed'; end if;
  definition:=replace(definition,anchor,$new$  -- Authorization and the existing filters have already shaped these rows.
  -- Only dates with visible Drafts and the exact K2 correction branch need proof.
  -- Evaluate once per represented date, independent of Supplier/search filters.
  for v_release_date in
    select distinct (po->>'service_date')::date
    from jsonb_array_elements(v_response->'purchase_orders') po
    where po->>'status'='DRAFT' and exists(
      select 1 from atlas_planning.confirmed_need_batches batch
      where batch.period_start=(po->>'service_date')::date
        and batch.period_end=batch.period_start and batch.batch_status='REOPENED'
        and batch.released_at is not null)
    order by 1
  loop
    v_frontier:=atlas_core.purchase_review_preparation_po_frontier(v_release_date);
    if v_frontier->>'acceptable' is distinct from 'true' then
      -- A filtered/scoped Actor must not learn another document's private reason.
      -- Match the writer's generic prerequisite, without disclosing the frontier.
      v_release_blockers:=jsonb_build_array(to_char(v_release_date,'DD/MM/YYYY')||
        ': Cần chuẩn bị đầy đủ đơn mua theo phân bổ hiện tại trước khi phát hành. Kiểm tra các đơn Cần cập nhật hoặc trở lại Phân bổ NCC.');
      v_release_dates:=v_release_dates||jsonb_build_object(v_release_date::text,v_release_blockers);
      v_date_messages:=v_date_messages||v_release_blockers;
    end if;
  end loop;
  for v_order in select value from jsonb_array_elements(v_response->'purchase_orders') loop$new$);
  anchor:=$old$    v_orders:=v_orders||jsonb_build_array(v_order);$old$;
  if position(anchor in definition)=0 then raise exception 'PO document append changed'; end if;
  definition:=replace(definition,anchor,$new$    v_release_blockers:=v_release_dates->(v_order->>'service_date');
    if v_order->>'status'='DRAFT' and v_release_blockers is not null then
      v_order:=v_order||jsonb_build_object(
        'release_eligible',false,
        'allowed_actions',(v_order->'allowed_actions')||jsonb_build_object('release',false),
        'blockers',coalesce(v_order->'blockers','[]'::jsonb)||v_release_blockers,
        'disabled_reasons',coalesce(v_order->'disabled_reasons','[]'::jsonb)||v_release_blockers);
    end if;
    v_orders:=v_orders||jsonb_build_array(v_order);$new$);
  anchor:=$old$  return jsonb_set(v_response,'{purchase_orders}',v_orders);$old$;
  if position(anchor in definition)=0 then raise exception 'PO response return changed'; end if;
  definition:=replace(definition,anchor,$new$  return jsonb_set(v_response||jsonb_build_object(
    'blockers',coalesce(v_response->'blockers','[]'::jsonb)||v_date_messages),
    '{purchase_orders}',v_orders);$new$);
  execute definition;
end $patch$;
reset role;
set local role atlas_owner;
do $restore$ begin
  if not (select had_create from po_frontier_schema_lease) then
    revoke create on schema atlas_api from atlas_read_runtime;
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
