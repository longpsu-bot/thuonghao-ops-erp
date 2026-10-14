-- Migration 108: align Procurement/PXK authorization with documented relational scope.
-- Product-approved cutover hardening. No business grouping, lifecycle, timeout,
-- public API identity, role membership, or Preparation authorization changes.
reset role;
set role atlas_owner;

create function atlas_core.school_catering_purchase_order_actor_has_full_scope(
  p_actor_id uuid,
  p_purchase_order_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  with scope_rows as (
    select distinct
      confirmed.customer_id,
      confirmed.school_id,
      confirmed.delivery_location_id
    from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions revision
      on revision.purchase_order_id=po.purchase_order_id
     and revision.is_current
    join atlas_procurement.purchase_order_line_revisions line
      on line.purchase_order_revision_id=revision.purchase_order_revision_id
    join atlas_procurement.purchase_order_lines stable
      on stable.purchase_order_line_id=line.purchase_order_line_id
     and stable.purchase_order_id=po.purchase_order_id
    join atlas_procurement.school_catering_allocation_supplier_splits split
      on split.supplier_split_id=line.school_catering_allocation_supplier_split_id
    join atlas_procurement.school_catering_allocation_family_revisions family_revision
      on family_revision.family_revision_id=split.family_revision_id
     and family_revision.family_id=stable.school_catering_allocation_family_id
    join atlas_procurement.school_catering_allocation_family_contributions contribution
      on contribution.family_revision_id=family_revision.family_revision_id
    left join atlas_planning.purchase_handoff_line_revisions handoff
      on handoff.purchase_handoff_line_revision_id=
        contribution.purchase_handoff_line_revision_id
    join atlas_planning.confirmed_need_line_revisions confirmed
      on confirmed.confirmed_need_line_revision_id=
        coalesce(
          contribution.confirmed_need_line_revision_id,
          handoff.confirmed_need_line_revision_id
        )
    where po.purchase_order_id=p_purchase_order_id
      and po.purchase_order_kind='SCHOOL_CATERING'
  )
  select
    atlas_core.school_catering_actor_has_scope(
      p_actor_id,null,null,null
    )
    or (
      exists(select 1 from scope_rows)
      and not exists(
        select 1
        from scope_rows scope
        where not atlas_core.school_catering_actor_has_scope(
          p_actor_id,
          scope.customer_id,
          scope.school_id,
          scope.delivery_location_id
        )
      )
    );
$$;

revoke all on function
  atlas_core.school_catering_purchase_order_actor_has_full_scope(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function
  atlas_core.school_catering_purchase_order_actor_has_full_scope(uuid,uuid)
  to atlas_read_runtime,atlas_procurement_command_runtime;

reset role;

do $generated_review$
declare
  definition text :=
    pg_get_functiondef(
      'atlas_api.get_generated_purchase_review(jsonb)'::regprocedure
    );
  old_text text := '''confirmed_need_review.read''';
begin
  if position(old_text in definition)=0 then
    raise exception '108 generated-review capability anchor missing';
  end if;
  definition:=replace(
    definition,
    old_text,
    '''procurement.school_catering.read'''
  );
  execute definition;
end
$generated_review$;

do $po_read$
declare
  definition text :=
    pg_get_functiondef(
      'atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)'
        ::regprocedure
    );
  old_text text := $old$
      and not exists(
        select 1
        from atlas_procurement.purchase_order_line_revisions scoped_line
        where scoped_line.purchase_order_revision_id=por.purchase_order_revision_id
          and not atlas_core.school_catering_actor_has_scope(
            v_actor_id,null,null,scoped_line.delivery_location_id)
      )
$old$;
  new_text text := $new$
      and atlas_core.school_catering_purchase_order_actor_has_full_scope(
        v_actor_id,po.purchase_order_id
      )
$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '108 PO read scope anchor missing';
  end if;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end
$po_read$;

do $po_release$
declare
  definition text :=
    pg_get_functiondef(
      'atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure
    );
  old_text text := $old$
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;

  -- Receipt acquisition precedes lifecycle checks so an exact completed replay wins.
$old$;
  new_text text := $new$
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'procurement.school_catering.write','PROCUREMENT',v_name,null,null,null);
  if v_auth is not null
     and v_auth->>'error_code'<>'SCOPE_DENIED' then
    return v_auth;
  end if;
  if not atlas_core.school_catering_purchase_order_actor_has_full_scope(
      v_actor_id,v_purchase_order_id) then
    return atlas_core.pa_05b_command_error(
      request,'SCOPE_DENIED',
      'The actor is outside the complete School scope represented by this purchase order.',
      'PROCUREMENT',v_name
    );
  end if;

  -- Receipt acquisition precedes lifecycle checks so an exact completed replay wins.
$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '108 PO release authorization anchor missing';
  end if;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end
$po_release$;

do $dispatch_read$
declare
  definition text :=
    pg_get_functiondef(
      'atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)'
        ::regprocedure
    );
  old_text text := $old$
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.read','DISPATCH',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;
$old$;
  new_text text := $new$
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.read','DISPATCH',v_name,null,null,null);
  if v_auth is not null
     and v_auth->>'error_code'<>'SCOPE_DENIED' then
    return v_auth;
  end if;
$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '108 PXK read authorization anchor missing';
  end if;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end
$dispatch_read$;

do $reconciliation_read$
declare
  definition text :=
    pg_get_functiondef(
      'atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)'
        ::regprocedure
    );
  old_text text := $old$
  v_auth:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.read','DISPATCH',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;
$old$;
  new_text text := $new$
  v_auth:=atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.read','DISPATCH',v_name,null,null,null);
  if v_auth is not null
     and v_auth->>'error_code'<>'SCOPE_DENIED' then
    return v_auth;
  end if;
$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '108 reconciliation authorization anchor missing';
  end if;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end
$reconciliation_read$;

do $dispatch_release$
declare
  definition text :=
    pg_get_functiondef(
      'atlas_api.release_school_dispatch_document(jsonb)'::regprocedure
    );
  old_text text := $old$
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.release','DISPATCH',v_name,null,null,null);
  if v_auth is not null then return v_auth; end if;
  if not atlas_core.school_dispatch_actor_has_scope(
      v_actor_id,v_school_id,v_location_id) then
$old$;
  new_text text := $new$
  v_auth := atlas_core.pa_05b_authorize_actor(request,v_actor_id,
    'dispatch.school_release.release','DISPATCH',v_name,null,null,null);
  if v_auth is not null
     and v_auth->>'error_code'<>'SCOPE_DENIED' then
    return v_auth;
  end if;
  if not atlas_core.school_dispatch_actor_has_scope(
      v_actor_id,v_school_id,v_location_id) then
$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '108 PXK release authorization anchor missing';
  end if;
  definition:=replace(definition,old_text,new_text);
  execute definition;
end
$dispatch_release$;

comment on function
  atlas_core.school_catering_purchase_order_actor_has_full_scope(uuid,uuid)
is
  'ATLAS-AUTH-SCOPE-ALIGNMENT-01: whole-document School/customer/location authorization for one Supplier/date School-catering PO.';
