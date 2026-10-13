-- Forward migration 106. Reuse authoritative sources within this read only;
-- keep canonical currentness, Handoff precedence and preparation checks intact.
begin;
grant atlas_read_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime;
reset role;
set role atlas_read_runtime;

do $reuse_workbench_sources$
declare
  target regprocedure := 'atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)'::regprocedure;
  definition text := pg_get_functiondef(target);
  original text;
  replacement text;
  prior pg_proc%rowtype;
  updated pg_proc%rowtype;
  boundary integer;
begin
  select * into strict prior from pg_proc where oid=target;
  for boundary in 1..3 loop
    case boundary
      when 1 then
        original:='p jsonb; a jsonb;';
        replacement:='p jsonb; v_sources jsonb; a jsonb;';
      when 2 then
        original:='for p in select * from atlas_core.purchase_review_confirmed_sources(v_start,v_end) loop';
        replacement:=$new$select coalesce(jsonb_agg(source),'[]'::jsonb) into v_sources
    from atlas_core.purchase_review_confirmed_sources(v_start,v_end) source;
  for p in select value from jsonb_array_elements(v_sources) loop$new$;
      when 3 then
        original:='not exists(select 1 from atlas_core.purchase_review_confirmed_sources(v_start,v_end) source';
        replacement:='not exists(select 1 from jsonb_array_elements(v_sources) source';
    end case;
    if (length(definition)-length(replace(definition,original,'')))/length(original)<>1 then
      raise exception 'Allocation read source reuse boundary mismatch: %',boundary;
    end if;
    definition:=replace(definition,original,replacement);
  end loop;
  execute definition;
  select * into strict updated from pg_proc where oid=target;
  if (to_jsonb(updated)-'prosrc') is distinct from (to_jsonb(prior)-'prosrc') then
    raise exception 'Allocation read source reuse changed function catalog posture';
  end if;
end;
$reuse_workbench_sources$;

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;
reset role;
grant atlas_read_runtime to postgres with set false;
commit;
