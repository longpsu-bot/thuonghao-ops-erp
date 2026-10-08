-- 02B-A: preserve the four callable identities and their exact catalog posture.
-- All original invoker roles can already execute the RMVP-03A implementations.
-- D03 is deliberately retained: its runtime ACL sets do not overlap.
do $helper_reuse$
declare
  target regprocedure;
  prior pg_catalog.pg_proc%rowtype;
  current_proc pg_catalog.pg_proc%rowtype;
  definition text;
  body text;
begin
  foreach target in array array[
    'atlas_core.rmvp_03b_normalize_text(text)'::regprocedure,
    'atlas_core.pantry_02_normalize_text(text)'::regprocedure,
    'atlas_core.rmvp_03b_sha256(jsonb)'::regprocedure,
    'atlas_core.pantry_02_sha256(jsonb)'::regprocedure
  ] loop
    select * into strict prior from pg_catalog.pg_proc where oid=target;
    definition:=pg_catalog.pg_get_functiondef(target);
    if prior.proname like '%normalize_text' then
      body:=E'\n  select atlas_core.rmvp_03a_normalize_text(value);\n';
    elsif prior.prolang=(select oid from pg_catalog.pg_language where lanname='plpgsql') then
      body:=E'\nbegin\n  return atlas_core.rmvp_03a_sha256(value);\nend;\n';
    else
      body:=E'\n  select atlas_core.rmvp_03a_sha256(value);\n';
    end if;
    if prior.prosrc='' or pg_catalog.strpos(definition,prior.prosrc)=0 then
      raise exception '02B helper body not found: %',target;
    end if;
    execute pg_catalog.replace(definition,prior.prosrc,body);
    select * into strict current_proc from pg_catalog.pg_proc where oid=target;
    if (pg_catalog.to_jsonb(current_proc)-'prosrc') is distinct from
       (pg_catalog.to_jsonb(prior)-'prosrc') then
      raise exception '02B helper catalog drift: %',target;
    end if;
  end loop;
end;
$helper_reuse$;
