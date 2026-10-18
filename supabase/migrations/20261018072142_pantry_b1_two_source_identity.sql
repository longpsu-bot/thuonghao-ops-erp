-- B1 / Owner PANTRY-SOURCE-SEPARATION-01. No historical fact is rewritten.
begin;
create temporary table pantry_b1_authoring_lease on commit drop as
select r.rolname, a.set_option from pg_roles r join pg_auth_members a on a.roleid=r.oid
where a.member=(select oid from pg_roles where rolname=current_user)
  and a.grantor=(select oid from pg_roles where rolname=current_user)
  and r.rolname in ('atlas_owner','atlas_read_runtime','atlas_planning_command_runtime');
do $lease$ begin
 if (select count(*) from pantry_b1_authoring_lease)<>3 then
  raise exception 'Expected three pre-existing authoring memberships';
 end if;
end $lease$;
grant atlas_owner, atlas_read_runtime, atlas_planning_command_runtime to postgres with set true;
create temporary table pantry_b1_schema_lease on commit drop as
select n.nspname,r.rolname,has_schema_privilege(r.rolname,n.oid,'CREATE') had_create
from pg_namespace n cross join pg_roles r
where n.nspname in ('atlas_api','atlas_core')
 and r.rolname in ('atlas_read_runtime','atlas_planning_command_runtime');
grant select on pantry_b1_schema_lease to atlas_owner;
set role atlas_owner;
grant create on schema atlas_api,atlas_core to atlas_read_runtime,atlas_planning_command_runtime;

-- All former grains are unique in this wider key. No row or snapshot changes.
alter table atlas_planning.pantry_need_lines
 drop constraint pantry_need_lines_stable_grain_key,
 add constraint pantry_need_lines_stable_grain_key unique (
  pantry_need_batch_id,service_date,school_id,delivery_location_id,ingredient_id,
  pantry_need_purpose_id
 );

-- Fail closed if any inherited definition no longer has the reviewed anchor.
do $patch$
declare patch record; definition text;
begin
 for patch in select * from (values
  ('atlas_core.pantry_02_canonical_rows(date,jsonb)',
   $old$        coalesce(resolved.ingredient_id::text, ''),
        resolved.ordinality$old$,
   $new$        coalesce(resolved.ingredient_id::text, ''),
        coalesce(resolved.pantry_need_purpose_id::text, ''),
        resolved.ordinality$new$),
  ('atlas_core.pantry_02_signature(date,boolean,jsonb)',
   $old$                row ->> 'ingredient_id'
$old$,
   $new$                row ->> 'ingredient_id',
                row ->> 'pantry_need_purpose_id'
$new$),
  ('atlas_core.pantry_02_current_rows(uuid)',
   $old$        line.ingredient_id,
        line.pantry_need_line_id$old$,
   $new$        line.ingredient_id,
        line.pantry_need_purpose_id,
        line.pantry_need_line_id$new$),
  ('atlas_core.pantry_02_issues(date,boolean,jsonb)',
   $old$      value ->> 'ingredient_id'
    having count(*) > 1$old$,
   $new$      value ->> 'ingredient_id',
      value ->> 'pantry_need_purpose_id'
    having count(*) > 1$new$),
  ('atlas_core.pantry_02_issues(date,boolean,jsonb)',
   $old$The proposed Pantry rows repeat the same service date, School, default Delivery Location, and Ingredient.$old$,
   $new$The proposed Pantry rows repeat the same service date, School, default Delivery Location, Ingredient, and Purpose.$new$),
  ('atlas_planning.pantry_02_line_guard()',
   $old$    or new.ingredient_id is distinct from old.ingredient_id$old$,
   $new$    or new.ingredient_id is distinct from old.ingredient_id
    or new.pantry_need_purpose_id is distinct from old.pantry_need_purpose_id$new$)
 ) as changes(signature,old_text,new_text) loop
  definition:=pg_get_functiondef(patch.signature::regprocedure);
  if (length(definition)-length(replace(definition,patch.old_text,'')))/length(patch.old_text)<>1 then
   raise exception 'B1 inherited anchor changed: %',patch.signature;
  end if;
  execute replace(definition,patch.old_text,patch.new_text);
 end loop;
end $patch$;
reset role;
set role atlas_read_runtime;
do $patch$
declare definition text:=pg_get_functiondef('atlas_core.direct_need_legacy_preview_pantry_source(jsonb)'::regprocedure);
 old_text text:=$old$     and proposed.proposed_row ->> 'ingredient_id' =
          existing.existing_row ->> 'ingredient_id'$old$;
begin
 if position(old_text in definition)=0 then raise exception 'B1 Preview join anchor changed'; end if;
 definition:=replace(definition,old_text,old_text||$new$
     and proposed.proposed_row ->> 'pantry_need_purpose_id' =
          existing.existing_row ->> 'pantry_need_purpose_id'$new$);
 -- Each comparison array is stable when the former Ingredient grain ties.
 definition:=replace(definition,
  $old$classified.proposed_row ->> 'ingredient_id'
$old$,
  $new$classified.proposed_row ->> 'ingredient_id',
              classified.proposed_row ->> 'pantry_need_purpose_id'
$new$);
 definition:=replace(definition,
  $old$classified.existing_row ->> 'ingredient_id'
$old$,
  $new$classified.existing_row ->> 'ingredient_id',
              classified.existing_row ->> 'pantry_need_purpose_id'
$new$);
 execute definition;
end $patch$;
reset role;
set role atlas_planning_command_runtime;
do $patch$
declare patch record; definition text;
begin
 for patch in select * from (values
  ($old$      value ->> 'ingredient_id'
  loop$old$,
   $new$      value ->> 'ingredient_id',
      value ->> 'pantry_need_purpose_id'
  loop$new$),
  ($old$      delivery_location_id,
      ingredient_id
    ) do update$old$,
   $new$      delivery_location_id,
      ingredient_id,
      pantry_need_purpose_id
    ) do update$new$),
  ($old$      pantry_need_purpose_id = excluded.pantry_need_purpose_id,
$old$,$new$$new$)
 ) as changes(old_text,new_text) loop
  definition:=pg_get_functiondef('atlas_api.save_pantry_draft(jsonb)'::regprocedure);
  if (length(definition)-length(replace(definition,patch.old_text,'')))/length(patch.old_text)<>1 then
   raise exception 'B1 Save anchor changed: %',patch.old_text;
  end if;
  execute replace(definition,patch.old_text,patch.new_text);
 end loop;
end $patch$;

-- Reuse v4's already-hardened receipt-first path for authored-purpose v3.
-- Hash the ORIGINAL v3 envelope. Mutable impact checks still gate new intents.
do $patch$
declare definition text:=pg_get_functiondef('atlas_api.save_pantry(jsonb)'::regprocedure);
 branch_start integer; branch_end integer; old_branch text; new_branch text;
begin
 branch_start:=position($old$  if request->>'contract_version'='PANTRY-02.v4' then$old$ in definition);
 branch_end:=position('  -- Existing v2 callers remain valid' in definition);
 if branch_start=0 or branch_end<=branch_start then raise exception 'B1 receipt boundary anchor changed'; end if;
 old_branch:=substring(definition from branch_start for branch_end-branch_start);
 new_branch:=replace(old_branch,'''PANTRY-02.v4''','(request->>''contract_version'')');
 new_branch:=replace(new_branch,
  $old$if request->>'contract_version'=(request->>'contract_version') then$old$,
  $new$if request->>'contract_version' in ('PANTRY-02.v3','PANTRY-02.v4') then$new$);
 execute replace(definition,old_branch,new_branch);
end $patch$;
reset role;
set role atlas_owner;
do $restore$ declare lease record; begin
 for lease in select * from pg_temp.pantry_b1_schema_lease where not had_create loop
  execute format('revoke create on schema %I from %I',lease.nspname,lease.rolname);
 end loop;
end $restore$;
reset role;
do $restore$ declare lease record; begin
 for lease in select * from pg_temp.pantry_b1_authoring_lease where not set_option loop
  execute format('grant %I to postgres with set false',lease.rolname);
 end loop;
end $restore$;
commit;
