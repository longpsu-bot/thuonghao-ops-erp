-- Read the released contributions once in the initial revision INSERT.
-- Keep all source predicates and statement-local authority unchanged.
begin;
create temp table ng_proposal_membership_lease on commit drop as
select roleid,member,grantor,set_option from pg_auth_members;
create temp table ng_proposal_schema_lease on commit drop as
select exists(select 1 from aclexplode(coalesce(nspacl,acldefault('n',nspowner))) acl
 where acl.grantee=(select oid from pg_roles where rolname='atlas_planning_materialization_runtime')
 and acl.grantor=nspowner and acl.privilege_type='CREATE') had_create
from pg_namespace where nspname='atlas_core';
grant select on ng_proposal_schema_lease to atlas_owner;
grant atlas_planning_materialization_runtime to postgres with set true;
set local role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime;
reset role;
set local role atlas_planning_materialization_runtime;
do $proposal_reuse$
declare definition text:=pg_get_functiondef('atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure);
 anchor text:='with proposal_resolution as (';
 source_join text:=$join$    join atlas_planning.need_generation_release_snapshot_lines release_line
      on release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
     and theoretical.line_disposition = 'ACTIVE'
      and theoretical.theoretical_quantity > 0
     and theoretical.service_date = target_line.service_date
     and theoretical.school_id = target_line.school_id
    join atlas_admin.schools school
      on school.school_id = theoretical.school_id
     and target_line.delivery_location_id = case
       when theoretical.contribution_family = 'PANTRY_DIRECT'
         then theoretical.delivery_location_id
       else school.default_delivery_location_id
     end
     and theoretical.ingredient_id = target_line.ingredient_id
     and theoretical.unit_id = target_line.controlled_unit_id$join$;
 released_source text:=$source$with released_contributions as materialized (
      select theoretical.service_date, theoretical.school_id,
        theoretical.ingredient_id, theoretical.unit_id, theoretical.theoretical_quantity,
        case when theoretical.contribution_family = 'PANTRY_DIRECT'
          then theoretical.delivery_location_id
          else school.default_delivery_location_id end delivery_location_id
      from atlas_planning.need_generation_release_snapshot_lines release_line
      join atlas_planning.theoretical_need_lines theoretical
        on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
      join atlas_admin.schools school on school.school_id = theoretical.school_id
      where release_line.need_generation_release_snapshot_id = v_release.need_generation_release_snapshot_id
        and theoretical.line_disposition = 'ACTIVE'
        and theoretical.theoretical_quantity > 0
    ), proposal_resolution as ($source$;
begin
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>2 then
  raise exception 'Expected both original proposal resolution statements'; end if;
 if (length(definition)-length(replace(definition,source_join,'')))/length(source_join)<>1 then
  raise exception 'Expected the exact initial released contribution join'; end if;
 definition:=replace(definition,source_join,$join$    join released_contributions theoretical
      on theoretical.service_date = target_line.service_date
     and theoretical.school_id = target_line.school_id
     and theoretical.ingredient_id = target_line.ingredient_id
     and theoretical.unit_id = target_line.controlled_unit_id
     and theoretical.delivery_location_id = target_line.delivery_location_id$join$);
 definition:=overlay(definition placing released_source from strpos(definition,anchor) for length(anchor));
 execute definition;
end $proposal_reuse$;
reset role;
set local role atlas_owner;
do $restore$ begin
 if not (select had_create from ng_proposal_schema_lease) then
  revoke create on schema atlas_core from atlas_planning_materialization_runtime;
 end if;
end $restore$;
reset role;
do $restore$ declare lease record; begin
 select original.* into lease from ng_proposal_membership_lease original
 where original.roleid=(select oid from pg_roles where rolname='atlas_planning_materialization_runtime')
 and original.member=(select oid from pg_roles where rolname='postgres')
 and original.grantor=(select oid from pg_roles where rolname='postgres');
 if found then
  execute format('grant atlas_planning_materialization_runtime to postgres with set %s',case when lease.set_option then 'true' else 'false' end);
 else revoke atlas_planning_materialization_runtime from postgres;
 end if;
end $restore$;
commit;
