-- Reuse one private request-local authority across the authorized School scopes.
begin;
create temporary table reconciliation_context_membership_lease on commit drop as
select roleid,member,grantor,set_option from pg_auth_members;
create temporary table reconciliation_context_schema_lease on commit drop as
select n.nspname,exists(
  select 1 from aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) acl
  where acl.grantee=(select oid from pg_roles where rolname='atlas_read_runtime')
    and acl.grantor=n.nspowner and acl.privilege_type='CREATE') had_direct_create
from pg_namespace n where n.nspname in ('atlas_core','atlas_api');
grant select on reconciliation_context_schema_lease to atlas_owner;

grant atlas_read_runtime to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_core,atlas_api to atlas_read_runtime;
reset role;
set local role atlas_read_runtime;

do $reconciliation$
declare definition text;
begin
  definition:=pg_get_functiondef('atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_fulfilment_reconciliation_scope(p_service_date date, p_school_id uuid, p_delivery_location_id uuid)$anchor$ in definition)=0
    then raise exception 'Reconciliation scope signature changed'; end if;
  definition:=replace(definition,
    $anchor$FUNCTION atlas_core.school_fulfilment_reconciliation_scope(p_service_date date, p_school_id uuid, p_delivery_location_id uuid)$anchor$,
    $anchor$FUNCTION atlas_core.procurement_read_school_fulfilment_reconciliation_scope(p_service_date date, p_school_id uuid, p_delivery_location_id uuid, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_dispatch_release_preview(
    p_service_date,p_school_id,p_delivery_location_id)$anchor$ in definition)=0
    then raise exception 'Reconciliation preview anchor changed'; end if;
  definition:=replace(definition,
    $anchor$atlas_core.school_dispatch_release_preview(
    p_service_date,p_school_id,p_delivery_location_id)$anchor$,
    $anchor$atlas_core.procurement_read_school_dispatch_release_preview(
    p_service_date,p_school_id,p_delivery_location_id,p_read_context)$anchor$);
  execute definition;
  revoke all on function atlas_core.procurement_read_school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)
    from public,anon,authenticated,service_role;

  definition:=pg_get_functiondef('atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)'::regprocedure);
  if regexp_count(definition,E'declare\n')<>1
    or position('atlas_core.school_dispatch_actor_has_scope(v_actor_id,scope.school_id,scope.delivery_location_id)' in definition)=0
    or position($anchor$and v_auth->>'error_code'<>'SCOPE_DENIED'$anchor$ in definition)=0
    then raise exception 'Reconciliation authorization baseline changed'; end if;
  definition:=replace(definition,E'declare\n',E'declare\n  v_read_context jsonb;\n');
  if position($anchor$  with confirmed_scopes as ($anchor$ in definition)=0
    then raise exception 'Reconciliation authorized read anchor changed'; end if;
  definition:=replace(definition,$anchor$  with confirmed_scopes as ($anchor$,
    $anchor$  v_read_context:=atlas_core.procurement_read_context(v_start,v_end);
  with confirmed_scopes as ($anchor$);
  if position($anchor$from atlas_core.purchase_review_confirmed_sources(v_start,v_end) source(value)$anchor$ in definition)=0
    then raise exception 'Reconciliation confirmed scope anchor changed'; end if;
  definition:=replace(definition,
    $anchor$from atlas_core.purchase_review_confirmed_sources(v_start,v_end) source(value)$anchor$,
    $anchor$from jsonb_array_elements(v_read_context->'sources') source(value)$anchor$);
  if position($anchor$atlas_core.school_fulfilment_reconciliation_scope(scope.service_date,
        scope.school_id,scope.delivery_location_id)$anchor$ in definition)=0
    then raise exception 'Reconciliation per-School read anchor changed'; end if;
  definition:=replace(definition,
    $anchor$atlas_core.school_fulfilment_reconciliation_scope(scope.service_date,
        scope.school_id,scope.delivery_location_id)$anchor$,
    $anchor$atlas_core.procurement_read_school_fulfilment_reconciliation_scope(scope.service_date,
        scope.school_id,scope.delivery_location_id,v_read_context)$anchor$);
  execute definition;
end $reconciliation$;

reset role;
set local role atlas_owner;
do $restore$ declare lease record; begin
  for lease in select * from reconciliation_context_schema_lease where not had_direct_create loop
    execute format('revoke create on schema %I from atlas_read_runtime',lease.nspname);
  end loop;
end $restore$;
reset role;
do $restore$ declare lease record; begin
  select original.* into lease from reconciliation_context_membership_lease original
  where original.roleid=(select oid from pg_roles where rolname='atlas_read_runtime')
    and original.member=(select oid from pg_roles where rolname='postgres')
    and original.grantor=(select oid from pg_roles where rolname='postgres');
  if found then
    execute format('grant atlas_read_runtime to postgres with set %s',
      case when lease.set_option then 'true' else 'false' end);
  else
    revoke atlas_read_runtime from postgres;
  end if;
end $restore$;
commit;
