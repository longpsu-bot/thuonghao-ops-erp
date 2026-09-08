-- RMVP-05.v2 already guarantees NO_COMMITTED_CHANGE for safe error envelopes.
-- Keep the exception message consistent with that authoritative transaction fact.
do $scenario_c_write_certainty$
declare
  v_definition text;
  v_old_message constant text :=
    'The Save outcome is unknown. Refresh before continuing.';
  v_new_message constant text :=
    'The Save failed safely. No changes were committed.';
begin
  v_definition := pg_catalog.pg_get_functiondef(
    'atlas_api.save_confirmed_needs(jsonb)'::regprocedure
  );
  if (
    pg_catalog.length(v_definition)
      - pg_catalog.length(pg_catalog.replace(
          v_definition, v_old_message, ''
        ))
  ) / pg_catalog.length(v_old_message) <> 1 then
    raise exception
      'Scenario C write-certainty migration found an unexpected Save definition';
  end if;
  execute pg_catalog.replace(v_definition, v_old_message, v_new_message);
end;
$scenario_c_write_certainty$;
