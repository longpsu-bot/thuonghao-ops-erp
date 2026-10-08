-- 02B-B: complete authenticated command regression proves the Handoff writer
-- silently rounded over-precision. Enforce the existing confirmed-source rule
-- before any numeric(20,6) coercion. Keep writers, locks and lineage separate.
do $exact_splits$
declare
  target regprocedure:='atlas_core.school_catering_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text)'::regprocedure;
  prior pg_catalog.pg_proc%rowtype;
  current_proc pg_catalog.pg_proc%rowtype;
  definition text:=pg_catalog.pg_get_functiondef(target);
  anchor text:=$old$    if (select pg_catalog.count(*) from pg_catalog.jsonb_array_elements(p_splits)) <>$old$;
  validation text:=$new$    if exists(select 1 from jsonb_array_elements(p_splits) s
      where (s->>'allocated_quantity')::numeric >= 100000000000000
        or (s->>'allocated_quantity')::numeric <> round((s->>'allocated_quantity')::numeric,6)) then
      return jsonb_build_object('success',false,'error_code','INVALID_SPLIT_PRECISION');
    end if;
$new$;
begin
  select * into strict prior from pg_catalog.pg_proc where oid=target;
  if pg_catalog.strpos(definition,anchor)=0
     or pg_catalog.strpos(definition,'INVALID_SPLIT_PRECISION')>0
     or pg_catalog.strpos(pg_catalog.pg_get_functiondef(
       'atlas_core.purchase_review_persist_allocation(uuid,uuid,bigint,jsonb,jsonb,text,text)'::regprocedure),
       pg_catalog.btrim(validation))=0 then
    raise exception '02B expected source-specific split validation bodies not found';
  end if;
  execute pg_catalog.replace(definition,anchor,validation||anchor);
  select * into strict current_proc from pg_catalog.pg_proc where oid=target;
  if (pg_catalog.to_jsonb(current_proc)-'prosrc') is distinct from
     (pg_catalog.to_jsonb(prior)-'prosrc') then
    raise exception '02B allocation writer catalog drift';
  end if;
end;
$exact_splits$;
