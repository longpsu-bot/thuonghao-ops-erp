-- ATLAS-PXK-EXACT-SCHOOL-SCOPE-01, Product-approved 2026-10-14.
-- CREATE OR REPLACE preserves the existing read-runtime owner and exact ACL.
create or replace function atlas_core.school_dispatch_actor_has_scope(
  p_actor_id uuid,p_school_id uuid,p_delivery_location_id uuid
) returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(
    select 1 from atlas_core.actor_scopes scope
    where scope.actor_id=p_actor_id
      and scope.scope_status='ACTIVE'
      and scope.effective_from<=pg_catalog.transaction_timestamp()
      and (scope.effective_to is null or scope.effective_to>pg_catalog.transaction_timestamp())
      and (
        scope.scope_kind='GLOBAL'
        or (scope.scope_kind='SCHOOL' and scope.school_id=p_school_id)
        or (scope.scope_kind='DELIVERY_LOCATION'
          and scope.delivery_location_id=p_delivery_location_id)
        or (scope.scope_kind='CUSTOMER' and exists(
          select 1 from atlas_admin.delivery_locations location
          where location.delivery_location_id=p_delivery_location_id
            and location.customer_id=scope.customer_id))
      )
  );
$$;

do $dispatch_read$
declare
  definition text:=pg_get_functiondef(
    'atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)'::regprocedure);
  old_text text:=$old$atlas_core.school_catering_actor_has_scope(
      v_actor_id,null,scope.school_id,scope.delivery_location_id)$old$;
  new_text text:=$new$atlas_core.school_dispatch_actor_has_scope(
      v_actor_id,scope.school_id,scope.delivery_location_id)$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '109 PXK read scope anchor missing';
  end if;
  execute replace(definition,old_text,new_text);
end
$dispatch_read$;

do $reconciliation_read$
declare
  definition text:=pg_get_functiondef(
    'atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)'::regprocedure);
  old_text text:=$old$atlas_core.school_catering_actor_has_scope(v_actor_id,null,scope.school_id,scope.delivery_location_id)$old$;
  new_text text:=$new$atlas_core.school_dispatch_actor_has_scope(v_actor_id,scope.school_id,scope.delivery_location_id)$new$;
begin
  if position(old_text in definition)=0 then
    raise exception '109 reconciliation scope anchor missing';
  end if;
  execute replace(definition,old_text,new_text);
end
$reconciliation_read$;
