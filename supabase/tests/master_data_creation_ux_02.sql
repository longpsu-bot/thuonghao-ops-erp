begin;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;
select no_plan();

create function pg_temp.creation_request(kind text, at_time timestamptz, payload jsonb)
returns jsonb language sql volatile as $$
  select jsonb_build_object(
    'contract_version', case when kind = 'dish' then 'RMVP-02A.v1' else 'RMVP-01.v1' end,
    'command_id', gen_random_uuid(), 'correlation_id', gen_random_uuid(),
    'idempotency_key', gen_random_uuid()::text, 'expected_version', 1,
    'requested_by_auth_subject', 'cd020000-0000-4000-8000-000000000003',
    'requested_at', at_time, 'reason_code', 'MASTER_DATA_CREATION',
    'reason_note', null, 'payload', payload
  );
$$;
create function pg_temp.validate_creation(kind text, request jsonb)
returns jsonb language sql stable as $$
  select case when kind = 'dish'
    then atlas_core.rmvp_02a_validate_command_request(request, 'create_' || kind)
    else atlas_core.rmvp_01_validate_command_request(request, 'create_' || kind) end;
$$;
create function pg_temp.create_master(kind text, request jsonb)
returns jsonb language plpgsql volatile as $$
begin
  case kind
    when 'dish' then return atlas_api.create_dish(request);
    when 'ingredient' then return atlas_api.create_ingredient(request);
    when 'supplier' then return atlas_api.create_supplier(request);
  end case;
end;
$$;

select is(pg_temp.validate_creation(kind,
  pg_temp.creation_request(kind, transaction_timestamp() + skew, '{}')), null::jsonb,
  'create_' || kind || ': ' || label || ' passes envelope validation')
from (values ('dish'), ('ingredient'), ('supplier')) kinds(kind)
cross join (values
  (interval '-1 second', '-1s'), (interval '1 second', '+1s'),
  (interval '60 seconds', 'exactly +60s')
) times(skew, label);

select is(pg_temp.validate_creation(kind,
  jsonb_set(pg_temp.creation_request(kind, transaction_timestamp(), '{}'), '{requested_at}', stamp)
) #>> '{field_errors,0,field}', 'requested_at',
  'create_' || kind || ': ' || label || ' is rejected at requested_at')
from (values ('dish'), ('ingredient'), ('supplier')) kinds(kind)
cross join (values
  (to_jsonb(transaction_timestamp() + interval '60.000001 seconds'), '+60.000001s'),
  (to_jsonb(transaction_timestamp() + interval '61 seconds'), '+61s'),
  ('"invalid"'::jsonb, 'invalid timestamp')
) times(stamp, label);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  ('cd020000-0000-4000-8000-000000000001', 'HUMAN', 'Creation UX tester');
insert into atlas_core.actor_auth_subjects (actor_auth_subject_id, actor_id, auth_subject_id) values
  ('cd020000-0000-4000-8000-000000000002', 'cd020000-0000-4000-8000-000000000001',
   'cd020000-0000-4000-8000-000000000003');
insert into atlas_core.roles (role_id, role_code, role_name) values
  ('cd020000-0000-4000-8000-000000000004', 'creation_ux_02.tester', 'Creation UX tester');
insert into atlas_core.role_capabilities (role_id, capability_id)
select 'cd020000-0000-4000-8000-000000000004', capability_id
from atlas_core.capabilities where capability_code in (
  'master_data.read', 'master_data.recipes.read', 'master_data.ingredients.write',
  'master_data.suppliers.write', 'master_data.recipes.write'
);
insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  ('cd020000-0000-4000-8000-000000000001', 'cd020000-0000-4000-8000-000000000004');
insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('cd020000-0000-4000-8000-000000000001', 'GLOBAL');
insert into atlas_admin.units (unit_id, unit_code, unit_name, dimension_code, decimal_scale) values
  ('cd020000-0000-4000-8000-000000000010', 'creation-ux-02-kg', 'Creation UX kilogram', 'MASS', 3);
insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values
  (
    'cd020000-0000-4000-8000-000000000011',
    'v1-school-type-1',
    'TIỂU HỌC'
  ),
  (
    'cd020000-0000-4000-8000-000000000012',
    'v1-school-type-2',
    'TRUNG HỌC'
  );

create temporary table creation_cases (kind text primary key, payload jsonb);
insert into creation_cases values
  ('dish', jsonb_build_object('dish_name', 'Creation UX dish', 'dish_type_id',
    (select dish_type_id from atlas_admin.dish_types where dish_type_status = 'ACTIVE' limit 1))),
  ('ingredient', jsonb_build_object('ingredient_name', 'Creation UX ingredient',
    'purchase_unit_id', 'cd020000-0000-4000-8000-000000000010', 'order_step', 1,
    'ingredient_type_id', (select ingredient_type_id from atlas_admin.ingredient_types where ingredient_type_status = 'ACTIVE' limit 1),
    'ingredient_order_group_id', (select ingredient_order_group_id from atlas_admin.ingredient_order_groups where ingredient_order_group_status = 'ACTIVE' limit 1))),
  ('supplier', '{"supplier_name":"Creation UX supplier"}');
create temporary table creation_results (kind text, scenario text, request jsonb, response jsonb);
insert into creation_results (kind, scenario, request)
select kind, label, pg_temp.creation_request(kind, transaction_timestamp() + skew, payload)
from creation_cases cross join (values
  ('past', interval '-1 second'), ('near', interval '1 second'),
  ('boundary', interval '60 seconds'), ('over', interval '60.000001 seconds'),
  ('denied', interval '-1 second')
) scenarios(label, skew);
insert into creation_results (kind, scenario, request)
select kind, 'explicit', pg_temp.creation_request(kind, transaction_timestamp() - interval '1 second',
  payload || jsonb_build_object(kind || '_code', '  CONTROLLED-UX-02-' || kind || '  '))
from creation_cases;
insert into creation_results (kind, scenario, request)
select kind, label, pg_temp.creation_request(kind, transaction_timestamp() - interval '1 second',
  payload || jsonb_build_object(kind || '_code', code))
from creation_cases cross join (values ('empty', '""'::jsonb), ('null', 'null'::jsonb)) invalid(label, code);
grant all on creation_results, creation_cases to authenticated;
grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;
select set_config('request.jwt.claim.sub', 'cd020000-0000-4000-8000-000000000003', true);
set local role authenticated;
update creation_results set response = pg_temp.create_master(kind, request) where scenario <> 'denied';
select is(response->>'success', 'true', kind || ': ' || scenario || ' creates successfully')
from creation_results where scenario in ('past', 'near', 'boundary', 'explicit');
select is(response->>'error_code', 'VALIDATION_FAILED', kind || ': ' || scenario || ' rejects invalid input')
from creation_results where scenario in ('over', 'empty', 'null');
select is(pg_temp.create_master(kind, request), response, kind || ': exact replay returns unchanged result')
from creation_results where scenario in ('past', 'boundary');
select is(pg_temp.create_master(kind, jsonb_set(request, '{payload}', request->'payload' ||
  jsonb_build_object(kind || '_name', 'Changed name')))->>'error_code', 'IDEMPOTENCY_CONFLICT',
  kind || ': changed payload cannot reuse successful idempotency key')
from creation_results where scenario = 'past';
reset role;

-- Revoking the actual capability must stop fresh creation and successful replay.
delete from atlas_core.role_capabilities where role_id = 'cd020000-0000-4000-8000-000000000004';
set local role authenticated;
update creation_results set response = pg_temp.create_master(kind, request) where scenario = 'denied';
select is(response->>'error_code', 'CAPABILITY_DENIED', kind || ': unauthorized creation is denied')
from creation_results where scenario = 'denied';
select is(pg_temp.create_master(kind, request)->>'error_code', 'CAPABILITY_DENIED',
  kind || ': replay rechecks authorization') from creation_results where scenario = 'past';
reset role;

create temporary view created_codes as
select r.kind, r.scenario, r.request, r.response, d.dish_id as id, d.dish_code as code
from creation_results r join atlas_admin.dishes d on d.dish_id::text = r.response #>> '{affected_aggregate_ids,dish_id}'
where r.kind = 'dish'
union all
select r.kind, r.scenario, r.request, r.response, i.ingredient_id, i.ingredient_code
from creation_results r join atlas_admin.ingredients i on i.ingredient_id::text = r.response #>> '{affected_aggregate_ids,ingredient_id}'
where r.kind = 'ingredient'
union all
select r.kind, r.scenario, r.request, r.response, s.supplier_id, s.supplier_code
from creation_results r join atlas_admin.suppliers s on s.supplier_id::text = r.response #>> '{affected_aggregate_ids,supplier_id}'
where r.kind = 'supplier';
select is((select count(*) from created_codes where kind = c.kind), 4::bigint,
  c.kind || ': only three generated objects and one explicit object exist') from creation_cases c;
select ok(code ~ ('^' || kind || '-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
  kind || ': ' || scenario || ' uses full random UUID code')
from created_codes where scenario in ('past', 'near', 'boundary');
select is((select count(distinct code) from created_codes where kind = c.kind and scenario <> 'explicit'),
  3::bigint, c.kind || ': same-name creations have unique opaque codes') from creation_cases c;
select is(code, 'controlled-ux-02-' || kind, kind || ': controlled explicit codes retain normalization')
from created_codes where scenario = 'explicit';
select is((select count(*) from atlas_core.command_receipts receipt
  where receipt.command_id::text = r.request->>'command_id'),
  case when scenario in ('past', 'near', 'boundary', 'explicit') then 1 else 0 end::bigint,
  kind || ': ' || scenario || ' preserves exact receipt count') from creation_results r;
select is(receipt.request_hash, atlas_core.pa_05b_request_hash(r.request),
  kind || ': ' || scenario || ' receipt hashes the original request without generated metadata')
from creation_results r join atlas_core.command_receipts receipt
  on receipt.command_id::text = r.request->>'command_id';
select is(d.operational_notes, null::text, 'Dish without operational notes persists null')
from created_codes c join atlas_admin.dishes d on d.dish_id = c.id where c.kind = 'dish' and c.scenario = 'past';
select ok(s.contact_name is null and s.contact_phone is null and s.contact_email is null,
  'Supplier contact fields remain optional')
from created_codes c join atlas_admin.suppliers s on s.supplier_id = c.id where c.kind = 'supplier' and c.scenario = 'past';

select ok(bool_and(p.prosecdef and p.proconfig = array['search_path=""']::text[]
  and pg_get_userbyid(p.proowner) = 'atlas_master_data_command_runtime'
  and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  and not has_function_privilege('anon', p.oid, 'EXECUTE')
  and not has_function_privilege('service_role', p.oid, 'EXECUTE')),
  'creation retains fixed-search-path runtime ownership and API execution boundary')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'atlas_api' and p.proname in ('create_dish', 'create_ingredient', 'create_supplier');
select * from finish();
rollback;
