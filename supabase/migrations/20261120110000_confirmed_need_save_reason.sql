-- One optional reason per ordinary Need Save, stored on its existing audit event.
begin;
create temporary table need_save_reason_leases on commit drop as
select r.rolname, m.set_option,
       has_schema_privilege(r.oid, 'atlas_core', 'CREATE') as had_create
from pg_roles r left join pg_auth_members m
  on m.roleid = r.oid and m.member = current_user::regrole and m.grantor = current_user::regrole
where r.rolname in ('atlas_owner', 'atlas_confirmed_need_review_runtime');
grant select on need_save_reason_leases to atlas_owner;
grant atlas_owner, atlas_confirmed_need_review_runtime to postgres with set true;

set role atlas_owner;
grant create on schema atlas_core to atlas_confirmed_need_review_runtime;
reset role;
set role atlas_confirmed_need_review_runtime;
do $migration$
declare
  definition text;
  anchor text := $sql$or request -> 'reason_note' <> 'null'::jsonb$sql$;
begin
  definition := pg_get_functiondef('atlas_core.d037_validate_command(jsonb,text)'::regprocedure);
  if cardinality(string_to_array(definition, anchor)) <> 2 then raise exception 'Unexpected Need Save validator'; end if;
  execute replace(definition, anchor, $sql$or (request -> 'reason_note' <> 'null'::jsonb and
      (v_contract <> 'RMVP-05.v2' or jsonb_typeof(request -> 'reason_note') <> 'string'
       or char_length(request ->> 'reason_note') > 500))$sql$);
  definition := pg_get_functiondef('atlas_core.rmvp_05_record_change(jsonb,uuid,uuid,uuid,bigint,bigint,jsonb,jsonb)'::regprocedure);
  anchor := $sql$actor_id, request ->> 'reason_code', null,$sql$;
  if cardinality(string_to_array(definition, anchor)) <> 2 then raise exception 'Unexpected Need audit writer'; end if;
  execute replace(definition, anchor, $sql$actor_id, request ->> 'reason_code', nullif(btrim(request ->> 'reason_note'), ''),$sql$);
end $migration$;
reset role;

set role atlas_owner;
do $$ declare lease record; begin
  for lease in select * from pg_temp.need_save_reason_leases where not had_create and rolname <> 'atlas_owner' loop
    execute format('revoke create on schema atlas_core from %I', lease.rolname);
  end loop;
end $$;
reset role;
do $$ declare lease record; begin
  for lease in select * from pg_temp.need_save_reason_leases loop
    if lease.set_option is null then
      execute format('revoke %I from postgres granted by postgres', lease.rolname);
    elsif not lease.set_option then
      execute format('grant %I to postgres with set false', lease.rolname);
    end if;
  end loop;
end $$;
commit;
