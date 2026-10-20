-- Reuse the installed proof in dispatch reads and canonical PO membership checks.
begin;
create temporary table dispatch_proof_membership_lease on commit drop as
select roleid,member,grantor,set_option from pg_auth_members;
create temporary table dispatch_proof_schema_lease on commit drop as
select n.nspname,r.rolname,exists(
  select 1 from aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) acl
  where acl.grantee=r.oid and acl.grantor=n.nspowner
    and acl.privilege_type='CREATE') had_direct_create
from pg_namespace n cross join pg_roles r
where n.nspname in ('atlas_core','atlas_api')
  and r.rolname in ('postgres','atlas_read_runtime','atlas_confirmed_need_review_runtime',
    'atlas_procurement_command_runtime');
grant select on dispatch_proof_schema_lease to atlas_owner;
grant atlas_read_runtime,atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime
  to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_core,atlas_api to postgres,atlas_read_runtime,
  atlas_confirmed_need_review_runtime,atlas_procurement_command_runtime;
reset role;

do $proof$
declare definition text; grantee_name name;
begin
  definition:=pg_get_functiondef('atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure);
  if position($anchor$FUNCTION atlas_core.school_dispatch_release_preview(p_service_date date, p_school_id uuid, p_delivery_location_id uuid)$anchor$ in definition)=0
    then raise exception 'Dispatch preview signature changed'; end if;
  definition:=replace(definition,
    $anchor$FUNCTION atlas_core.school_dispatch_release_preview(p_service_date date, p_school_id uuid, p_delivery_location_id uuid)$anchor$,
    $anchor$FUNCTION atlas_core.procurement_read_school_dispatch_release_preview(p_service_date date, p_school_id uuid, p_delivery_location_id uuid, p_read_context jsonb)$anchor$);
  if position($anchor$atlas_core.school_catering_family_projection(
      family.service_date,family.delivery_location_id,family.ingredient_id,family.unit_id)$anchor$ in definition)=0
    then raise exception 'Dispatch family proof anchor changed'; end if;
  definition:=replace(definition,$anchor$atlas_core.school_catering_family_projection(
      family.service_date,family.delivery_location_id,family.ingredient_id,family.unit_id)$anchor$,
    $anchor$atlas_core.procurement_read_school_catering_family_projection(
      family.service_date,family.delivery_location_id,family.ingredient_id,family.unit_id,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_draft_is_stale(
          po.purchase_order_id,por.purchase_order_revision_id)$anchor$ in definition)=0
    then raise exception 'Dispatch stale-PO proof anchor changed'; end if;
  definition:=replace(definition,$anchor$atlas_core.school_catering_po_draft_is_stale(
          po.purchase_order_id,por.purchase_order_revision_id)$anchor$,
    $anchor$atlas_core.procurement_read_school_catering_po_draft_is_stale(
          po.purchase_order_id,por.purchase_order_revision_id,p_read_context)$anchor$);
  if position($anchor$atlas_core.school_catering_po_commitment_state(
      po.purchase_order_id,po.purchase_order_revision_id)$anchor$ in definition)=0
    then raise exception 'Dispatch commitment proof anchor changed'; end if;
  definition:=replace(definition,$anchor$atlas_core.school_catering_po_commitment_state(
      po.purchase_order_id,po.purchase_order_revision_id)$anchor$,
    $anchor$atlas_core.procurement_read_school_catering_po_commitment_state(
      po.purchase_order_id,po.purchase_order_revision_id,p_read_context)$anchor$);
  execute definition;
  alter function atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)
    owner to atlas_read_runtime;
  revoke all on function atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)
    from public,anon,authenticated,service_role;
  for grantee_name in select distinct role.rolname from pg_proc original
    cross join lateral aclexplode(coalesce(original.proacl,acldefault('f',original.proowner))) acl
    join pg_roles role on role.oid=acl.grantee
    where original.oid='atlas_core.school_dispatch_release_preview(date,uuid,uuid)'::regprocedure
      and acl.privilege_type='EXECUTE' and role.rolname not in ('anon','authenticated','service_role') loop
    execute format('grant execute on function atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb) to %I',grantee_name);
  end loop;

  definition:=pg_get_functiondef('atlas_api.get_school_dispatch_release_workbench_v1_base(jsonb)'::regprocedure);
  if position(E'declare\n' in definition)=0 then raise exception 'Dispatch read declaration changed'; end if;
  definition:=replace(definition,E'declare\n',E'declare\n  v_read_context jsonb;\n');
  if position($anchor$  with scopes as ($anchor$ in definition)=0
    then raise exception 'Dispatch authorized read anchor changed'; end if;
  definition:=replace(definition,$anchor$  with scopes as ($anchor$,
    $anchor$  v_read_context:=atlas_core.procurement_read_context(v_start,v_end);
  with scopes as ($anchor$);
  if position($anchor$atlas_core.school_dispatch_release_preview(
      scope.service_date,scope.school_id,scope.delivery_location_id) value$anchor$ in definition)=0
    then raise exception 'Dispatch preview read anchor changed'; end if;
  definition:=replace(definition,$anchor$atlas_core.school_dispatch_release_preview(
      scope.service_date,scope.school_id,scope.delivery_location_id) value$anchor$,
    $anchor$atlas_core.procurement_read_school_dispatch_release_preview(
      scope.service_date,scope.school_id,scope.delivery_location_id,v_read_context) value$anchor$);
  execute definition;
end $proof$;

-- Keep the original lock and receipt phases; refresh facts after source locks.
do $preparation$
declare definition text; family_pattern text;
begin
  definition:=pg_get_functiondef('atlas_api.prepare_school_catering_purchase_orders(jsonb)'::regprocedure);
  definition:=replace(definition,E'declare\n',E'declare\n  v_phase_context jsonb;\n');
  if position('perform atlas_core.purchase_review_lock_allocations(v_batch_id);' in definition)=0
    then raise exception 'Preparation source-lock anchor changed'; end if;
  definition:=replace(definition,'perform atlas_core.purchase_review_lock_allocations(v_batch_id);',
    'perform atlas_core.purchase_review_lock_allocations(v_batch_id);'||E'\n      v_phase_context:=atlas_core.procurement_read_context(v_date,v_date);');
  if position($anchor$atlas_core.purchase_review_confirmed_projection(
            (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
            (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid)$anchor$ in definition)=0
    then raise exception 'Preparation corrected-proof anchor changed'; end if;
  definition:=replace(definition,$anchor$atlas_core.purchase_review_confirmed_projection(
            (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
            (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid)$anchor$,
    $anchor$atlas_core.procurement_read_purchase_review_confirmed_projection(
            (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
            (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid,v_phase_context)$anchor$);
  execute definition;

  definition:=pg_get_functiondef('atlas_api.create_school_catering_purchase_order_drafts(jsonb)'::regprocedure);
  if regexp_count(definition,'atlas_core.school_catering_po_date_readiness\(v_date\)')<>2
    then raise exception 'Draft date-readiness anchors changed'; end if;
  definition:=replace(definition,'atlas_core.school_catering_po_date_readiness(v_date)',
    '(with context as materialized (select atlas_core.procurement_read_context(v_date,v_date) value)
      select atlas_core.procurement_read_school_catering_po_date_readiness(v_date,context.value) from context)');
  -- A first correction can commit between statements, including after source locks.
  if regexp_count(definition,'from atlas_procurement.school_catering_allocation_families f')<>5
    then raise exception 'Draft statement context anchors changed'; end if;
  definition:=replace(definition,'from atlas_procurement.school_catering_allocation_families f',
    'from atlas_procurement.school_catering_allocation_families f
      cross join (with context as materialized (
        select atlas_core.procurement_read_context(v_date_start,v_date_end) value)
        select value from context) proof_context');
  family_pattern:='atlas_core\.school_catering_family_projection\([[:space:]]*f\.service_date,f\.delivery_location_id,f\.ingredient_id,f\.unit_id[[:space:]]*\)';
  if regexp_count(definition,family_pattern)<>5 then raise exception 'Draft family-proof anchors changed'; end if;
  definition:=regexp_replace(definition,family_pattern,
    'atlas_core.procurement_read_school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,proof_context.value)','g');
  -- Keep the canonical stale check at its existing caller position.
  execute definition;

  definition:=pg_get_functiondef('atlas_core.purchase_review_po_coverage(date)'::regprocedure);
  if position('with expected as materialized (' in definition)=0
    or regexp_count(definition,family_pattern)<>1 then raise exception 'PO coverage proof anchors changed'; end if;
  definition:=replace(definition,'with expected as materialized (',
    'with context as materialized (select atlas_core.procurement_read_context(p_date,p_date) value), expected as materialized (');
  if position('join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)' in definition)=0
    then raise exception 'PO coverage context anchor changed'; end if;
  definition:=replace(definition,'join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)',
    'join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id) cross join context');
  definition:=regexp_replace(definition,family_pattern,
    'atlas_core.procurement_read_school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,context.value)','g');
  execute definition;

  definition:=pg_get_functiondef('atlas_core.purchase_review_preparation_po_frontier(date)'::regprocedure);
  definition:=replace(definition,E'declare\n',E'declare\n  v_phase_context jsonb;\n');
  if position('v_readiness := atlas_core.school_catering_po_date_readiness(p_date);' in definition)=0
    or regexp_count(definition,family_pattern)<>1 then raise exception 'PO frontier proof anchors changed'; end if;
  definition:=replace(definition,'v_readiness := atlas_core.school_catering_po_date_readiness(p_date);',
    E'v_phase_context:=atlas_core.procurement_read_context(p_date,p_date);\n  v_readiness := atlas_core.procurement_read_school_catering_po_date_readiness(p_date,v_phase_context);');
  definition:=regexp_replace(definition,family_pattern,
    'atlas_core.procurement_read_school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id,v_phase_context)','g');
  family_pattern:='atlas_core\.school_catering_po_commitment_state\([[:space:]]*([a-z_]+\.purchase_order_id),[[:space:]]*([a-z_]+\.purchase_order_revision_id)[[:space:]]*\)';
  if regexp_count(definition,family_pattern)<>4 then raise exception 'PO frontier commitment anchors changed'; end if;
  definition:=regexp_replace(definition,family_pattern,
    'atlas_core.procurement_read_school_catering_po_commitment_state(\1,\2,v_phase_context)','g');
  execute definition;
end $preparation$;

-- Existing internal callers already derive these same facts through canonical helpers.
set local role atlas_confirmed_need_review_runtime;
grant execute on function atlas_core.procurement_read_context(date,date)
  to atlas_owner,atlas_procurement_command_runtime;
reset role;

create or replace function atlas_core.school_catering_po_draft_is_stale(
  p_purchase_order_id uuid,p_purchase_order_revision_id uuid)
returns boolean language sql stable set search_path='' as $proof$
  select atlas_core.procurement_read_school_catering_po_draft_is_stale(
    p_purchase_order_id,p_purchase_order_revision_id,
    coalesce((select atlas_core.procurement_read_context(
      po.school_catering_service_date,po.school_catering_service_date)
      from atlas_procurement.purchase_orders po
      where po.purchase_order_id=p_purchase_order_id and po.purchase_order_kind='SCHOOL_CATERING'),
      '{"sources":[],"confirmed":{}}'::jsonb));
$proof$;

create or replace function atlas_core.school_dispatch_release_preview(
  p_service_date date,p_school_id uuid,p_delivery_location_id uuid)
returns jsonb language sql stable security definer set search_path='' as $proof$
  select atlas_core.procurement_read_school_dispatch_release_preview(
    p_service_date,p_school_id,p_delivery_location_id,
    atlas_core.procurement_read_context(p_service_date,p_service_date));
$proof$;

set local role atlas_owner;
do $restore$ declare lease record; begin
  for lease in select * from dispatch_proof_schema_lease where not had_direct_create loop
    execute format('revoke create on schema %I from %I',lease.nspname,lease.rolname);
  end loop;
end $restore$;
-- Remove the redundant owner-granted authoring entries left by the prior lease.
revoke create on schema atlas_core,atlas_api from postgres;
reset role;
do $restore$ declare lease record; begin
  for lease in select role.rolname,original.set_option from dispatch_proof_membership_lease original
    join pg_roles role on role.oid=original.roleid
    where original.member=(select oid from pg_roles where rolname='postgres')
      and original.grantor=(select oid from pg_roles where rolname='postgres')
      and role.rolname in ('atlas_read_runtime','atlas_confirmed_need_review_runtime',
        'atlas_procurement_command_runtime') loop
    execute format('grant %I to postgres with set %s',lease.rolname,
      case when lease.set_option then 'true' else 'false' end);
  end loop;
end $restore$;
commit;
