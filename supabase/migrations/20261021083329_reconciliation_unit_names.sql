-- Descriptive Unit names follow captured PXK evidence, never comparison keys.
begin;
create temp table reconciliation_unit_membership_lease on commit drop as
select roleid,member,grantor,set_option from pg_auth_members;
create temp table reconciliation_unit_schema_lease on commit drop as
select exists(select 1 from aclexplode(coalesce(nspacl,acldefault('n',nspowner))) acl
 where acl.grantee=(select oid from pg_roles where rolname='atlas_read_runtime')
 and acl.grantor=nspowner and acl.privilege_type='CREATE') had_create
from pg_namespace where nspname='atlas_core';
grant select on reconciliation_unit_schema_lease to atlas_owner;
grant atlas_read_runtime to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_core to atlas_read_runtime;
reset role;
set local role atlas_read_runtime;

create or replace function atlas_core.school_fulfilment_compare(p_po_lines jsonb,p_pxk_lines jsonb)
returns jsonb language sql immutable security definer set search_path='' as $$
  with po as (
    select (line->>'ingredient_id')::uuid ingredient_id,max(line->>'ingredient_name') ingredient_name,
      (line->>'unit_id')::uuid unit_id,max(line->>'unit_code') unit_code,
      case when count(distinct line->>'unit_name')=1 then max(line->>'unit_name') end unit_name,
      sum((line->>'quantity')::numeric)::numeric(20,6) quantity
    from jsonb_array_elements(coalesce(p_po_lines,'[]'::jsonb)) line
    group by (line->>'ingredient_id')::uuid,(line->>'unit_id')::uuid
  ), pxk as (
    select (line->>'ingredient_id')::uuid ingredient_id,max(line->>'ingredient_name') ingredient_name,
      (line->>'unit_id')::uuid unit_id,max(line->>'unit_code') unit_code,
      case when count(distinct line->>'unit_name')=1 then max(line->>'unit_name') end unit_name,
      sum((line->>'quantity')::numeric)::numeric(20,6) quantity
    from jsonb_array_elements(coalesce(p_pxk_lines,'[]'::jsonb)) line
    group by (line->>'ingredient_id')::uuid,(line->>'unit_id')::uuid
  ), detail as (
    select coalesce(po.ingredient_id,pxk.ingredient_id) ingredient_id,
      coalesce(po.ingredient_name,pxk.ingredient_name) ingredient_name,
      coalesce(po.unit_id,pxk.unit_id) unit_id,coalesce(po.unit_code,pxk.unit_code) unit_code,
      case when pxk.unit_id is not null then pxk.unit_name else po.unit_name end unit_name,
      coalesce(po.quantity,0)::numeric(20,6) po_quantity,
      coalesce(pxk.quantity,0)::numeric(20,6) pxk_quantity,
      (coalesce(po.quantity,0)-coalesce(pxk.quantity,0))::numeric(20,6) delta_quantity,
      po.ingredient_id is not null po_present,pxk.ingredient_id is not null pxk_present
    from po full join pxk using(ingredient_id,unit_id)
  ), status as (
    select case when not exists(select 1 from po) then 'NO_PO'
      when not exists(select 1 from pxk) then 'NO_PXK'
      when exists(select 1 from detail where not po_present or not pxk_present)
        then 'INGREDIENT_CHANGED'
      when exists(select 1 from detail where po_quantity<>pxk_quantity) then 'MISMATCH'
      else 'OK' end comparison_status
  ), unit_names as (
    select (line->>'unit_id')::uuid unit_id,
      case when bool_or(issued) then
        case when count(distinct line->>'unit_name') filter(where issued)=1
          then max(line->>'unit_name') filter(where issued) end
      else case when count(distinct line->>'unit_name')=1 then max(line->>'unit_name') end
      end unit_name
    from (
      select line,false issued from jsonb_array_elements(coalesce(p_po_lines,'[]'::jsonb)) line
      union all
      select line,true issued from jsonb_array_elements(coalesce(p_pxk_lines,'[]'::jsonb)) line
    ) names
    group by (line->>'unit_id')::uuid
  ), totals as (
    select unit_id,max(unit_code) unit_code,
      (select names.unit_name from unit_names names where names.unit_id=detail.unit_id) unit_name,
      sum(po_quantity)::numeric(20,6) po_quantity,
      sum(pxk_quantity)::numeric(20,6) pxk_quantity,
      sum(delta_quantity)::numeric(20,6) delta_quantity from detail group by unit_id
  )
  select jsonb_build_object('comparison_status',(select comparison_status from status),
    'quantity_totals_by_unit',coalesce((select jsonb_agg(jsonb_build_object(
      'unit_id',unit_id,'unit_code',unit_code,'unit_name',unit_name,'po_quantity',po_quantity::text,
      'pxk_quantity',pxk_quantity::text,'delta_quantity',delta_quantity::text)
      order by unit_code,unit_id) from totals),'[]'::jsonb),
    'details',coalesce((select jsonb_agg(jsonb_build_object(
      'ingredient_id',ingredient_id,'ingredient_name',ingredient_name,'unit_id',unit_id,
      'unit_code',unit_code,'unit_name',unit_name,'po_quantity',po_quantity::text,
      'pxk_quantity',pxk_quantity::text,'delta_quantity',delta_quantity::text)
      order by ingredient_name,ingredient_id,unit_id) from detail),'[]'::jsonb));
$$;

do $scope_names$
declare signature regprocedure; definition text;
 po_anchor text:=$anchor$'unit_code',line->>'unit_code','quantity',$anchor$;
 pxk_anchor text:=$anchor$'unit_code',line.unit_code_snapshot,'quantity',$anchor$;
begin
 foreach signature in array array[
  'atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid)'::regprocedure,
  'atlas_core.procurement_read_school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)'::regprocedure
 ] loop
  definition:=pg_get_functiondef(signature);
  if (length(definition)-length(replace(definition,po_anchor,'')))/length(po_anchor)<>1
    or (length(definition)-length(replace(definition,pxk_anchor,'')))/length(pxk_anchor)<>1 then
   raise exception 'Expected exact PO and PXK Unit projections in %',signature; end if;
  definition:=replace(definition,po_anchor,$anchor$'unit_code',line->>'unit_code','unit_name',max(line->>'unit_name'),'quantity',$anchor$);
  definition:=replace(definition,pxk_anchor,$anchor$'unit_code',line.unit_code_snapshot,'unit_name',line.unit_name_snapshot,'quantity',$anchor$);
  execute definition;
 end loop;
end $scope_names$;
reset role;
set local role atlas_owner;
do $restore$ begin
 if not (select had_create from reconciliation_unit_schema_lease) then
  revoke create on schema atlas_core from atlas_read_runtime;
 end if;
end $restore$;
reset role;
do $restore$ declare lease record; begin
 select original.* into lease from reconciliation_unit_membership_lease original
 where original.roleid=(select oid from pg_roles where rolname='atlas_read_runtime')
 and original.member=(select oid from pg_roles where rolname='postgres')
 and original.grantor=(select oid from pg_roles where rolname='postgres');
 if found then
  execute format('grant atlas_read_runtime to postgres with set %s',case when lease.set_option then 'true' else 'false' end);
 else revoke atlas_read_runtime from postgres;
 end if;
end $restore$;
commit;
