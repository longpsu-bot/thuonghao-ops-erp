begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;
select no_plan();

create function pg_temp.clock_request(at_time timestamptz) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02B.v1',
    'command_id', 'b2990000-0000-4000-8000-000000000001',
    'correlation_id', 'b2990000-0000-4000-8000-000000000002',
    'idempotency_key', 'rmvp02b-clock-skew', 'expected_version', 1,
    'requested_by_auth_subject', 'b2990000-0000-4000-8000-000000000003',
    'requested_at', at_time, 'reason_code', 'OPERATOR_RULE',
    'reason_note', 'Rolled-back clock-skew regression.', 'payload', '{}'::jsonb
  );
$$;

select is(atlas_core.rmvp_02b_validate_command_request(
  pg_temp.clock_request(transaction_timestamp() + skew), command_name), null::jsonb,
  command_name || ': ' || label || ' passes envelope validation')
from (values
  (interval '-1 second', 'minus one second'),
  (interval '1 second', 'plus one second'),
  (interval '60 seconds', 'exact plus sixty seconds')
) times(skew, label)
cross join (values
  ('create_recipe_composition_adjustment'),
  ('supersede_recipe_composition_adjustment'),
  ('cancel_recipe_composition_adjustment')
) commands(command_name);

select is(atlas_core.rmvp_02b_validate_command_request(
  jsonb_set(pg_temp.clock_request(transaction_timestamp()), '{requested_at}', stamp),
  'create_recipe_composition_adjustment')->>'error_code', 'VALIDATION_FAILED',
  label || ' is rejected')
from (values
  (to_jsonb(transaction_timestamp() + interval '61 seconds'), 'plus sixty-one seconds'),
  (to_jsonb(transaction_timestamp() + interval '60.000001 seconds'), 'one microsecond beyond boundary'),
  ('"invalid"'::jsonb, 'invalid timestamp')
) timestamps(stamp, label);

select is(atlas_core.rmvp_02b_validate_command_request(
  jsonb_set(pg_temp.clock_request(transaction_timestamp()), '{requested_at}',
    to_jsonb(transaction_timestamp() + interval '61 seconds')),
  'create_recipe_composition_adjustment') #>> '{field_errors,0,field}',
  'requested_at', 'future timestamp failure identifies requested_at');

select is(atlas_core.pa_05b_request_hash(pg_temp.clock_request(transaction_timestamp())),
  atlas_core.pa_05b_request_hash(pg_temp.clock_request(transaction_timestamp() + interval '1 second')),
  'timestamp skew does not change the established request-hash fields');

select is(atlas_core.rmvp_02b_validate_command_request(
  pg_temp.clock_request(transaction_timestamp()) || patch,
  'create_recipe_composition_adjustment')->>'error_code', 'VALIDATION_FAILED',
  label || ' remains invalid')
from (values
  ('{"contract_version":"wrong"}'::jsonb, 'wrong contract'),
  ('{"command_id":"bad"}'::jsonb, 'invalid command identity'),
  ('{"correlation_id":"bad"}'::jsonb, 'invalid correlation identity'),
  ('{"requested_by_auth_subject":"bad"}'::jsonb, 'invalid subject'),
  ('{"idempotency_key":""}'::jsonb, 'empty idempotency key'),
  ('{"expected_version":0}'::jsonb, 'nonpositive version'),
  ('{"reason_code":""}'::jsonb, 'empty reason code'),
  ('{"reason_note":""}'::jsonb, 'empty reason note'),
  ('{"payload":[]}'::jsonb, 'non-object payload')
) invalid(patch, label);

-- Public entry points must reject excessive skew through the same envelope.
select is(response->>'error_code', 'VALIDATION_FAILED', label || ' rejects excessive skew')
from (values
  ('Create', atlas_api.create_recipe_composition_adjustment(pg_temp.clock_request(transaction_timestamp() + interval '61 seconds'))),
  ('Supersede', atlas_api.supersede_recipe_composition_adjustment(pg_temp.clock_request(transaction_timestamp() + interval '61 seconds'))),
  ('Cancel', atlas_api.cancel_recipe_composition_adjustment(pg_temp.clock_request(transaction_timestamp() + interval '61 seconds')))
) results(label, response);

select is(response #>> '{field_errors,0,field}', 'requested_at',
  label || ' reports excessive skew through the shared timestamp validator')
from (values
  ('Create', atlas_api.create_recipe_composition_adjustment(pg_temp.clock_request(transaction_timestamp() + interval '61 seconds'))),
  ('Supersede', atlas_api.supersede_recipe_composition_adjustment(pg_temp.clock_request(transaction_timestamp() + interval '61 seconds'))),
  ('Cancel', atlas_api.cancel_recipe_composition_adjustment(pg_temp.clock_request(transaction_timestamp() + interval '61 seconds')))
) results(label, response);

select * from finish();
rollback;
