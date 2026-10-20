-- Accept the same bounded browser clock skew as the existing PO release command.
-- No request rewriting, receipt, privilege, timeout or business-rule change.
begin;
do $migration$
declare
  definition text := pg_get_functiondef('atlas_api.create_school_catering_purchase_order_drafts(jsonb)'::regprocedure);
  anchor constant text := 'or atlas_core.pa_05b_safe_timestamptz(request ->> ''requested_at'')>transaction_timestamp()';
begin
  if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> 1
    or position(anchor||'+' in definition)>0 then
    raise exception 'Expected one draft requested_at validation anchor';
  end if;
  execute replace(definition,anchor,anchor||'+interval ''60 seconds''');
end;
$migration$;
commit;
