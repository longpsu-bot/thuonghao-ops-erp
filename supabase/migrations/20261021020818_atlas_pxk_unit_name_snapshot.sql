-- Freeze human Unit names on future PXKs; never backfill released history.
begin;
create temporary table pxk_unit_schema_lease on commit drop as
select n.nspname,has_schema_privilege('postgres',n.oid,'CREATE') had_create
from pg_namespace n where n.nspname in ('atlas_core','atlas_api');
grant select on pxk_unit_schema_lease to atlas_owner;
set local role atlas_owner;
grant create on schema atlas_core,atlas_api to postgres;
reset role;

alter table atlas_dispatch.school_dispatch_release_lines
  add column unit_name_snapshot text,
  add constraint pxk_unit_name_nonblank check (
    unit_name_snapshot is null or nullif(btrim(unit_name_snapshot),'') is not null);
comment on column atlas_dispatch.school_dispatch_release_lines.unit_name_snapshot is
  'Human Unit name frozen by future releases; historical nulls remain immutable.';

do $migration$
declare patch record; definition text;
begin
  for patch in select * from (values
    ('atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)',
      'key.unit_id,unit.unit_code,', 'key.unit_id,unit.unit_code,unit.unit_name,'),
    ('atlas_core.procurement_read_school_dispatch_release_preview(date,uuid,uuid,jsonb)',
      '''unit_id'',unit_id,''unit_code'',unit_code,',
      '''unit_id'',unit_id,''unit_code'',unit_code,''unit_name'',unit_name,'),
    ('atlas_api.release_school_dispatch_document(jsonb)',
      'ingredient_name_snapshot,unit_code_snapshot',
      'ingredient_name_snapshot,unit_code_snapshot,unit_name_snapshot'),
    ('atlas_api.release_school_dispatch_document(jsonb)',
      'v_line->>''ingredient_name'',v_line->>''unit_code'')',
      'v_line->>''ingredient_name'',v_line->>''unit_code'',nullif(btrim(v_line->>''unit_name''),''''))'),
    ('atlas_core.school_dispatch_release_json(uuid)',
      '''unit_id'',line.unit_id,''unit_code'',line.unit_code_snapshot,',
      '''unit_id'',line.unit_id,''unit_code'',line.unit_code_snapshot,''unit_name'',line.unit_name_snapshot,')
  ) changes(signature,anchor,replacement) loop
    definition:=pg_get_functiondef(patch.signature::regprocedure);
    if (length(definition)-length(replace(definition,patch.anchor,'')))/length(patch.anchor) <> 1 then
      raise exception 'Expected one PXK Unit anchor: %',patch.signature;
    end if;
    execute replace(definition,patch.anchor,patch.replacement);
  end loop;
end;
$migration$;

-- The existing whole-row immutable trigger also protects the new snapshot.
set local role atlas_owner;
do $restore$ declare lease record; begin
  for lease in select * from pxk_unit_schema_lease where not had_create loop
    execute format('revoke create on schema %I from postgres',lease.nspname);
  end loop;
end $restore$;
reset role;
commit;
