-- The weekly rule is entered from a browser. Preserve strict timestamps for
-- legacy Pantry commands and the original request bytes for receipt replay.
do $migration$
declare
  definition text := pg_get_functiondef('atlas_core.pantry_02_validate_command_request(jsonb,text)'::regprocedure);
  original constant text := $old$or requested_at > pg_catalog.transaction_timestamp()
  then$old$;
  bounded constant text := $new$or requested_at > pg_catalog.transaction_timestamp() + (case
      when command_name = 'save_weekly_pantry_rule' then interval '60 seconds'
      else interval '0 seconds' end)
  then$new$;
begin
  if (length(definition) - length(replace(definition, original, ''))) <> length(original) then
    raise exception 'Expected one Pantry requested_at validation predicate';
  end if;
  execute replace(definition, original, bounded);
end;
$migration$;
