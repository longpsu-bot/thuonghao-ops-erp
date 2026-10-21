-- Sorting and search must reuse each authorized School's shaped result.
begin;
do $read_once$
declare definition text; anchor text := '), visible as (';
begin
  definition := pg_get_functiondef('atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb)'::regprocedure);
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1 then
    raise exception 'Expected one authorized reconciliation visibility boundary';
  end if;
  execute replace(definition,anchor,'), visible as materialized (');
end;
$read_once$;
commit;
